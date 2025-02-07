//
//  QwenVLProcessor.swift
//  mlx-swift-examples
//
//  Created by Sachin Desai on 2/6/25.
//

import CoreImage
import Foundation
import MLX
import MLXLMCommon
import Tokenizers

public protocol QwenVLProcessorConfiguration: Codable, Sendable {
    var imageMean: [CGFloat] { get }
    var imageStd: [CGFloat] { get }
    var maxPixels: Int { get }
    var minPixels: Int { get }
    var mergeSize: Int { get }
    var patchSize: Int { get }
    var temporalPatchSize: Int { get }

    var imageMeanTuple: (CGFloat, CGFloat, CGFloat) { get }
    var imageStdTuple: (CGFloat, CGFloat, CGFloat) { get }
}

// Default implementation for common properties
extension QwenVLProcessorConfiguration {
    public var imageMeanTuple: (CGFloat, CGFloat, CGFloat) {
        (imageMean[0], imageMean[1], imageMean[2])
    }
    public var imageStdTuple: (CGFloat, CGFloat, CGFloat) {
        (imageStd[0], imageStd[1], imageStd[2])
    }
}

// Base processor class
public class QwenVLProcessor<Config: QwenVLProcessorConfiguration>: UserInputProcessor {
    private let config: Config
    private let tokenizer: any Tokenizer

    public init(_ config: Config, tokenizer: any Tokenizer) {
        self.config = config
        self.tokenizer = tokenizer
    }

    private func targetSize(height: Int, width: Int, factor: Int, minPixels: Int, maxPixels: Int)
        throws -> (Int, Int)
    {
        if height < factor {
            throw VLMError.imageProcessingFailure(
                "height: \(height) must be larger than factor: \(factor)")
        }
        if width < factor {
            throw VLMError.imageProcessingFailure(
                "width: \(width) must be larger than factor: \(factor)")
        }
        if max(height, width) / min(height, width) > 200 {
            throw VLMError.imageProcessingFailure(
                "absolute aspect ratio must be smaller than 200: \(width)x\(height)")
        }

        var hBar = Int(round(Float(height) / Float(factor))) * factor
        var wBar = Int(round(Float(width) / Float(factor))) * factor

        if hBar * wBar > maxPixels {
            let beta = sqrt(Float(height * width) / Float(maxPixels))
            hBar = Int(floor(Float(height) / beta / Float(factor))) * factor
            wBar = Int(floor(Float(width) / beta / Float(factor))) * factor
        } else if hBar * wBar < minPixels {
            let beta = sqrt(Float(minPixels) / Float(height * width))
            hBar = Int(floor(Float(height) * beta / Float(factor))) * factor
            wBar = Int(floor(Float(width) * beta / Float(factor))) * factor
        }
        return (hBar, wBar)
    }

    public func preprocess(images: [CIImage], processing: UserInput.Processing?) throws -> (
        MLXArray, THW
    ) {
        let images = images.map { MediaProcessing.apply($0, processing: processing) }

        let size = images[0].extent.size
        let (resizedHeight, resizedWidth) = try targetSize(
            height: Int(size.height), width: Int(size.width),
            factor: config.patchSize * config.mergeSize,
            minPixels: config.minPixels, maxPixels: config.maxPixels)
        let resizedSize = CGSize(width: resizedWidth, height: resizedHeight)

        let processedImages =
            try images
            .map { MediaProcessing.inSRGBToneCurveSpace($0) }
            .map { MediaProcessing.resampleBicubic($0, to: resizedSize) }
            .map {
                MediaProcessing.normalize(
                    $0, mean: config.imageMeanTuple, std: config.imageStdTuple)
            }
            .map { MediaProcessing.asMLXArray($0) }

        var patches = concatenated(processedImages)
        let mod = patches.dim(0) % config.temporalPatchSize
        if mod != 0 {
            let lastPatch = patches[-1, .ellipsis]
            let lastPatchRepeated = tiled(
                lastPatch, repetitions: [config.temporalPatchSize - mod, 1, 1, 1])
            patches = concatenated([patches, lastPatchRepeated])
        }
        let channel = patches.dim(1)
        let gridT = patches.dim(0) / self.config.temporalPatchSize
        let gridH = resizedHeight / self.config.patchSize
        let gridW = resizedWidth / self.config.patchSize

        patches = patches.reshaped(
            gridT,
            config.temporalPatchSize,
            channel,
            gridH / config.mergeSize,
            config.mergeSize,
            config.patchSize,
            gridW / config.mergeSize,
            config.mergeSize,
            config.patchSize
        )
        patches = patches.transposed(0, 3, 6, 4, 7, 2, 1, 5, 8)

        let flattenedPatches = patches.reshaped(
            gridT * gridH * gridW,
            channel * config.temporalPatchSize * config.patchSize * config.patchSize
        )

        return (flattenedPatches, .init(gridT, gridH, gridW))
    }

    public func prepare(prompt: UserInput.Prompt, imageTHW: [THW]?, videoTHW: [THW]?) -> String {
        var messages = prompt.asMessages()
        if messages[0]["role"] != "system" {
            messages.insert(["role": "system", "content": "You are a helpful assistant."], at: 0)
        }

        let lastIndex = messages.count - 1
        var lastMessage = messages[lastIndex]["content"] ?? ""

        let mergeLength = config.mergeSize * config.mergeSize
        for thw in imageTHW ?? [] {
            lastMessage += "<|vision_start|>"
            lastMessage += Array(repeating: "<|image_pad|>", count: thw.product / mergeLength)
                .joined()
            lastMessage += "<|vision_end|>"
        }

        for thw in videoTHW ?? [] {
            lastMessage += "<|vision_start|>"
            lastMessage += Array(repeating: "<|video_pad|>", count: thw.product / mergeLength)
                .joined()
            lastMessage += "<|vision_end|>"
        }

        messages[lastIndex]["content"] = lastMessage

        return
            messages
            .map { "<|im_start|>\($0["role"] ?? "user")\n\($0["content"] ?? "")<|im_end|>" }
            .joined(separator: "\n")
            + "\n<|im_start|>assistant\n"
    }

    public func prepare(input: UserInput) async throws -> LMInput {
        if input.images.isEmpty && input.videos.isEmpty {
            let prompt = prepare(prompt: input.prompt, imageTHW: nil, videoTHW: nil)
            let promptTokens = try tokenizer.encode(text: prompt)
            return LMInput(tokens: MLXArray(promptTokens))
        }

        let images = try input.images.map {
            try preprocess(images: [$0.asCIImage()], processing: input.processing)
        }

        var videosAsImageSequences = [[CIImage]]()
        for video in input.videos {
            if let imageSequence = try? await MediaProcessing.asCIImageSequence(
                video.asAVAsset(), samplesPerSecond: 2)
            {
                videosAsImageSequences.append(imageSequence)
            }
        }
        let videos = try videosAsImageSequences.map {
            try preprocess(images: $0, processing: input.processing)
        }

        let imagePixels: MLXArray?
        let image: LMInput.ProcessedImage?
        if !images.isEmpty {
            imagePixels = concatenated(images.map { $0.0 })
            image = LMInput.ProcessedImage(pixels: imagePixels!, imageGridThw: images.map { $0.1 })
        } else {
            imagePixels = nil
            image = nil
        }

        let videoPixels: MLXArray?
        let video: LMInput.ProcessedVideo?
        if !videos.isEmpty {
            videoPixels = concatenated(videos.map { $0.0 })
            video = LMInput.ProcessedVideo(pixels: videoPixels!, videoGridThw: videos.map { $0.1 })
        } else {
            videoPixels = nil
            video = nil
        }

        let prompt = prepare(
            prompt: input.prompt, imageTHW: image?.imageGridThw, videoTHW: video?.videoGridThw)
        let promptTokens = try tokenizer.encode(text: prompt)
        let promptArray = MLXArray(promptTokens).expandedDimensions(axis: 0)
        let mask = ones(like: promptArray).asType(.int8)

        return LMInput(text: .init(tokens: promptArray, mask: mask), image: image, video: video)
    }
}
