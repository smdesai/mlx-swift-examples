// Copyright © 2024 Apple Inc.

import LLM
import MLX
import MLXRandom
import MarkdownUI
import Metal
import SwiftUI
import Tokenizers

struct ContentView: View {
    @State var prompt = ""
    @State var userPrompt = ""
    @State var system = ""
    @State var llm = LLMEvaluator()
    
    @State private var showingMemoryInfo = false
    @Environment(DeviceStat.self) private var deviceStat
    
    @State private var generationTask: Task<Void, Never>?

    enum DisplayStyle: String, CaseIterable, Identifiable {
        case plain, markdown
        var id: Self { self }
    }
    
    enum AudioError: Error {
        case unableToLoadAudioFile
        case unableToSaveAudioFile
    }

    @State private var selectedDisplayStyle = DisplayStyle.markdown
    @State private var selectedPromptHeader = ""

    @FocusState private var isFocused: Bool
    @State private var modelName = ""
    @State private var modelConfig: ModelConfiguration =
        ModelConfiguration.configuration(id: "mlx-community/SmolLM-135M-Instruct-4bit")

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                configurationSection
                modelInfoSection
                outputSection
                inputSection
            }
            .padding()
        }
    }

    private var configurationSection: some View {
        NavigationStack {
            NavigationStack {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        modelPicker
                        Spacer()
                        NavigationLink(destination: DocumentsListView()) {
                            Image(systemName: "gear")
                                .font(.body)  // Changed from .title to .body for smaller size
                                .foregroundColor(.blue)
                        }
                    }
                    promptPicker
                }
                .padding()
            }
        }
    }

    private var modelPicker: some View {
        HStack {
            Picker("Model", selection: $modelName) {
                ForEach(Array(ModelConfiguration.registry.keys.sorted()), id: \.self) { key in
                    Text(key.components(separatedBy: "/").last ?? key).tag(key)
                }
            }
            .onAppear {
                modelConfig = ModelConfiguration.configuration(id: "mlx-community/SmolLM-135M-Instruct-4bit")
                modelName = modelConfig.name
            }
            .onChange(of: modelName) { _, newValue in
                if newValue != modelConfig.name {
                    llm.loadState = .idle
                }
                modelConfig = ModelConfiguration.configuration(id: newValue)
                modelName = modelConfig.name
            }
        }
    }

    private var promptPicker: some View {
        HStack {
            Picker("Prompt", selection: $selectedPromptHeader) {
                ForEach(Prompt.promptKeys, id: \.self) { key in
                    Text(key).tag(key)
                }
            }
            .onAppear {
                selectedPromptHeader = Prompt.promptKeys.first ?? ""
            }
            .onChange(of: selectedPromptHeader) { _, newValue in
                selectedPromptHeader = newValue
            }
        }
    }

    private var modelInfoSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(llm.modelInfo).font(.system(size: 14))
                Spacer()
                Text(llm.stat).font(.system(size: 14))
            }
            HStack {
                Text(llm.timeToFirstToken).font(.system(size: 14))
                Spacer()
                Text(llm.totalTime).font(.system(size: 14))
            }
        }
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                if llm.running {
                    ProgressView().frame(maxHeight: 20)
                    Spacer()
                }
                displayStylePicker
            }
            ScrollViewReader { sp in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 15) {
                        userInputSection
                        llmOutputSection
                    }
                    Spacer().frame(width: 1, height: 1).id("bottom")
                }
                .onChange(of: llm.output) { _, _ in
                    sp.scrollTo("bottom")
                }
            }
        }
    }

    private var displayStylePicker: some View {
        Picker("", selection: $selectedDisplayStyle) {
            ForEach(DisplayStyle.allCases, id: \.self) { option in
                Text(option.rawValue.capitalized).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 150)
    }

    private var userInputSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            if userPrompt.count > 0 {
                Text("User").font(.headline)
                Text(userPrompt)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }

    private var llmOutputSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            if userPrompt.count > 0 {
                Text("LLM").font(.headline)
                Group {
                    if selectedDisplayStyle == .plain {
                        Text(llm.output)
                    } else {
                        Markdown(llm.output)
                    }
                }
                .textSelection(.enabled)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
        }
    }

    private var inputSection: some View {
        HStack {
            TextField("Type something", text: $prompt, axis: .vertical)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.gray, lineWidth: 1)
                )
                .foregroundColor(.white)
                .lineLimit(3)
                .focused($isFocused)
            
            Button(action: {
                Task {
                    await generate()
                }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.white)
                    .padding(.trailing, 8)
            }
//            .disabled(llm.running)
        }
    }

    private var memoryUsageButton: some View {
        Text("Memory Usage: \(deviceStat.gpuUsage.activeMemory.formatted(.byteCount(style: .memory)))")
    }

    private var copyOutputButton: some View {
        Button {
            Task {
                copyToClipboard(llm.output)
            }
        } label: {
            Label("Copy Output", systemImage: "doc.on.doc.fill")
        }
        .disabled(llm.output.isEmpty)
        .labelStyle(.titleAndIcon)
    }

    private var memoryUsageInfo: String {
        """
        Active Memory: \(deviceStat.gpuUsage.activeMemory.formatted(.byteCount(style: .memory)))/\(GPU.memoryLimit.formatted(.byteCount(style: .memory)))
        Cache Memory: \(deviceStat.gpuUsage.cacheMemory.formatted(.byteCount(style: .memory)))/\(GPU.cacheLimit.formatted(.byteCount(style: .memory)))
        Peak Memory: \(deviceStat.gpuUsage.peakMemory.formatted(.byteCount(style: .memory)))
        """
    }
    
    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
    }

    private func generate() async {
        if llm.running {
            cancelGeneration()
            return
        }

        isFocused = false
        resetStats()
        
        if prompt.isEmpty {
            let p = Prompt.prompt(id: selectedPromptHeader)
            prompt = p.prompt
        }
        
        userPrompt = prompt
        prompt = ""
        
        generationTask?.cancel()
        generationTask = Task {
            do {
                try await withTaskCancellationHandler(
                    operation: {
                        try Task.checkCancellation()
                        await llm.generate(prompt: userPrompt, modelConfiguration: modelConfig)
                    },
                    onCancel: {
                        print("Generation was cancelled")
                        // Any cleanup needed
                    }
                )
            } catch {
                print("Task was cancelled: \(error)")
            }
        }
        
//        try? Task.checkCancellation()
//        await withTaskCancellationHandler {
//            do {
//                await llm.generate(prompt: userPrompt, modelConfiguration: modelConfig)
//            }
//        } onCancel: {
//            // Cleanup code when cancelled
//        }
        
//
//        generationTask?.cancel()
//        generationTask = Task {
//            try? Task.checkCancellation()
//            await llm.generate(prompt: userPrompt, modelConfiguration: modelConfig)
//        }

//        Task {
//            await llm.generate(prompt: userPrompt, modelConfiguration: modelConfig)
//        }
    }

    private func copyToClipboard(_ string: String) {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        #else
            UIPasteboard.general.string = string
        #endif
    }

    private func resetStats() {
        llm.stat = ""
        llm.timeToFirstToken = ""
        llm.totalTime = ""
    }
    
//    private func playAudio(buffer: MLXArray) throws {
//        let samples = buffer.asArray(Float.self)
//        
//        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24000, channels: 1, interleaved: false),
//              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
//            throw AudioError.unableToSaveAudioFile
//        }
//        
//        guard let channelData = buffer.floatChannelData?[0] else {
//            throw AudioError.unableToSaveAudioFile
//        }
//        
//        samples.enumerated().forEach { channelData[$0.offset] = $0.element }
//        buffer.frameLength = buffer.frameCapacity
//        
//        playBuffer(buffer)
//    }
    
//    private func playBuffer(_ buffer: AVAudioPCMBuffer) {
//        let audioEngine = AVAudioEngine()
//        let playerNode = AVAudioPlayerNode()
//        
//        audioEngine.attach(playerNode)
//        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: buffer.format)
//        
//        playerNode.scheduleBuffer(buffer)
//        
//        do {
//            try audioEngine.start()
//            playerNode.play()
//        } catch {
//            print("Error starting audio engine: \(error.localizedDescription)")
//        }
//    }
}

@Observable
@MainActor
class LLMEvaluator {

    var running = false

    var output = ""
    var modelInfo = ""
    var stat = ""
    var timeToFirstToken = ""
    var totalTime = ""
    
    var userTerminated = false


    /// This controls which model loads. `phi3_5_4bit` is one of the smaller ones, so this will fit on
    /// more devices.
//    let modelConfiguration = ModelConfiguration.llama3_2_1B_4bit
//    let modelConfiguration = ModelConfiguration.smolLM_135M_4bit


    /// parameters controlling the output
    let generateParameters = GenerateParameters(temperature: 0.6)
    let maxTokens = 4096

    /// update the display every N tokens -- 4 looks like it updates continuously
    /// and is low overhead.  observed ~15% reduction in tokens/s when updating
    /// on every token
    let displayEveryNTokens = 4

    public enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    var loadState = LoadState.idle

    /// load and return the model -- can be called multiple times, subsequent calls will
    /// just return the loaded model
    func load(modelConfiguration: ModelConfiguration) async throws -> ModelContainer {
        switch loadState {
        case .idle:
            // limit the buffer cache
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

            let modelContainer = try await LLM.loadModelContainer(configuration: modelConfiguration)
            {
                [modelConfiguration] progress in
                Task { @MainActor in
                    let simpleName = modelConfiguration.name.components(separatedBy: "/").last ?? modelConfiguration.name
                    self.modelInfo = "Downloading \(simpleName): \(Int(progress.fractionCompleted * 100))%"
                }
            }
            
            let numParams = await modelContainer.perform {
                [] model, _ in
                return model.numParameters()
            }

            self.modelInfo = "Model Weights: \(numParams / 1024 / 1024)M"
            loadState = .loaded(modelContainer)
            return modelContainer

        case .loaded(let modelContainer):
            return modelContainer
        }
    }
    
    func generate(prompt: String, modelConfiguration: ModelConfiguration) async {
        guard !running else { return }

        running = true
        self.output = ""
        
        userTerminated = false

        do {
            let modelContainer = try await load(modelConfiguration: modelConfiguration)

            let messages = [["role": "user", "content": prompt]]
            let promptTokens = try await modelContainer.perform { _, tokenizer in
                try tokenizer.applyChatTemplate(messages: messages)
            }

            // each time you generate you will get something new
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            let result = await modelContainer.perform { model, tokenizer in
                LLM.generate(
                    promptTokens: promptTokens, parameters: generateParameters, model: model,
                    tokenizer: tokenizer, extraEOSTokens: modelConfiguration.extraEOSTokens
                ) { tokens in
                    // update the output -- this will make the view show the text as it generates
                    if tokens.count % displayEveryNTokens == 0 {
                        let text = tokenizer.decode(tokens: tokens)
                        Task { @MainActor in
                            self.output = text
                        }
                    }

                    if tokens.count >= maxTokens {
                        return .stop
                    } else {
                        return .more
                    }
                }
            }

            // update the text if needed, e.g. we haven't displayed because of displayEveryNTokens
            if result.output != self.output {
                self.output = result.output
            }
            self.stat = " Tokens/second: \(String(format: "%.3f", result.tokensPerSecond))"
            self.timeToFirstToken = "Time to first token: \(String(format: "%.3fs", result.promptTime))"
            self.totalTime = " Generate time: \(String(format: "%.3fs", result.generateTime))"

        } catch {
            output = "Failed: \(error)"
        }

        running = false
    }
}

struct DirectoryItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let displayName: String
    let size: Int64  // Size in bytes
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DirectoryItem, rhs: DirectoryItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct DocumentsListView: View {
    @State private var directories: [DirectoryItem] = []
    @State private var showingDeleteAlert = false
    @State private var directoryToDelete: String?
    
    var body: some View {
        List {
            ForEach(directories) { directory in
                HStack {
                    Text(directory.displayName)
                    Spacer()
                    Text(formatSize(directory.size))
                        .foregroundColor(.secondary)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        directoryToDelete = directory.name
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .navigationTitle("Models")
        .onAppear {
            loadDirectories()
        }
        .alert("Delete Directory Contents", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let directory = directoryToDelete {
                    deleteDirectory(directory)
                }
            }
        } message: {
            Text("Are you sure you want to delete all contents in this directory?")
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let gigabyte = Double(bytes) / 1_000_000_000.0
        if gigabyte < 0.01 {
            let megabyte = Double(bytes) / 1_000_000.0
            return String(format: "%.1f MB", megabyte)
        }
        return String(format: "%.2f GB", gigabyte)
    }
    
    private func calculateDirectorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
            
            for fileURL in contents {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                   let isDirectory = resourceValues.isDirectory {
                    if isDirectory {
                        totalSize += calculateDirectorySize(at: fileURL)
                    } else if let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }
        } catch {
            print("Error calculating size: \(error)")
        }
        
        return totalSize
    }
    
    private func loadDirectories() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
//        let modelsPathURL = documentsPath.appendingPathComponent("huggingface").appendingPathComponent("models").appendingPathComponent("mlx-community")
//        
//        do {
//            let contents = try FileManager.default.contentsOfDirectory(
//                at: modelsPathURL,
//                includingPropertiesForKeys: nil,
//                options: [.skipsHiddenFiles]
//            )
//            directories = contents.map { url in
//                let size = calculateDirectorySize(at: url)
//                return DirectoryItem(name: url.lastPathComponent, size: size)
//            }
//        } catch {
//            print("Error loading directories: \(error)")
//        }
        
        let modelsPathURL = documentsPath.appendingPathComponent("huggingface").appendingPathComponent("models")
                
        do {
            // First get all organization directories under models
            let orgDirectories = try FileManager.default.contentsOfDirectory(
                at: modelsPathURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            var allModelDirectories: [DirectoryItem] = []
            
            for orgDir in orgDirectories {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: orgDir,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )
                    
                    // Create DirectoryItems for each model directory, including org prefix
                    let orgDirItems = contents.map { url in
                        let size = calculateDirectorySize(at: url)
                        let orgName = orgDir.lastPathComponent
                        let modelName = url.lastPathComponent
                        return DirectoryItem(name: "\(orgName)/\(modelName)", displayName: "\(modelName)",  size: size)
                    }
                    
                    allModelDirectories.append(contentsOf: orgDirItems)
                } catch {
                    print("Error loading directories for \(orgDir.lastPathComponent): \(error)")
                }
            }
            
            directories = allModelDirectories
            
        } catch {
            print("Error loading organization directories: \(error)")
        }
    }
    
    private func deleteDirectory(_ directory: String) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let modelsPathURL = documentsPath
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent(directory)
        
        do {
            if isDirectory(modelsPathURL) {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: modelsPathURL,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
                
                for url in contents {
                    try FileManager.default.removeItem(at: url)
                }
            }
            
            try FileManager.default.removeItem(at: modelsPathURL)
            
            loadDirectories()
        } catch {
            print("Error deleting file/directory: \(error)")
        }
    }
    
    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        _ = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
