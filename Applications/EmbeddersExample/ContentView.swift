//
//  ContentView.swift
//  EmbeddersExample
//
//  Created by Sachin Desai on 12/4/24.
//

import SwiftUI
import MLX
import Embedders

struct ContentView: View {
    @State private var query: String = ""
    @State private var embedding: [[Float]] = []
    
    var body: some View {
        VStack {
            TextField("Enter query", text: $query)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            Button("Generate Embedding") {
                hideKeyboard()
                Task {
                    embedding = try await generateEmbedding(text: query)
                }
            }
            
            Text("Generated Embedding: \(embedding)")
        }
        .padding()
    }
    
    func generateEmbedding(text: String) async throws -> [[Float]] {
        print(query)
        let modelContainer = try await Embedders.loadModelContainer(
            configuration: ModelConfiguration.nomic_text_v1_5)
        
        let start = Date.timeIntervalSinceReferenceDate
        let result = await modelContainer.perform {
            (model: EmbeddingModel, tokenizer, pooling) -> [[Float]] in
            let inputs = [
                "search_document: \(text)",
            ].map {
                tokenizer.encode(text: $0, addSpecialTokens: true)
            }
            // Pad to longest
            let maxLength = inputs.reduce(into: 16) { acc, elem in
                acc = max(acc, elem.count)
            }

            let padded = stacked(
                inputs.map { elem in
                    MLXArray(
                        elem
                            + Array(
                                repeating: tokenizer.eosTokenId ?? 0,
                                count: maxLength - elem.count))
                })
            let mask = (padded .!= tokenizer.eosTokenId ?? 0)
            let tokenTypes = MLXArray.zeros(like: padded)
            let result = pooling(
                model(padded, positionIds: nil, tokenTypeIds: tokenTypes, attentionMask: mask),
                normalize: true, applyLayerNorm: true
            )
            result.eval()
            return result.map { $0.asArray(Float.self) }
        }
        let now = Date.timeIntervalSinceReferenceDate
        let generateTime = now - start
        print("Embedding generate time: \(generateTime) seconds")
        return result
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
