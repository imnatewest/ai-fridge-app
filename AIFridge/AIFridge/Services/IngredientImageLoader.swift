//
//  IngredientImageLoader.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import Foundation
import Combine

@MainActor
final class IngredientImageLoader: ObservableObject {
    @Published private(set) var imageURLs: [String: URL?] = [:]

    private var tasks: [String: Task<Void, Never>] = [:]

    func prepare(with items: [Item]) {
        for item in items {
            loadIfNeeded(for: item)
        }
    }

    func url(for item: Item) -> URL? {
        imageURLs[key(for: item)] ?? nil
    }

    func loadIfNeeded(for item: Item) {
        let key = key(for: item)
        if imageURLs[key] != nil || tasks[key] != nil {
            return
        }

        let query = bestQuery(for: item)

        let task = Task { [weak self] in
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                await MainActor.run {
                    self?.imageURLs[key] = nil
                    self?.tasks[key] = nil
                }
                return
            }

            do {
                let url = try await PexelsImageService.shared.thumbnailURL(for: query)
                await MainActor.run {
                    self?.imageURLs[key] = url
                    self?.tasks[key] = nil
                }
            } catch {
                if !(error is CancellationError) {
                    print("⚠️ Image fetch failed for \(query): \(error)")
                }
                await MainActor.run {
                    self?.imageURLs[key] = nil
                    self?.tasks[key] = nil
                }
            }
        }

        tasks[key] = task
    }

    func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    private func key(for item: Item) -> String {
        item.name.lowercased()
    }

    private func bestQuery(for item: Item) -> String {
        if let category = item.category, !category.isEmpty {
            return "\(item.name) \(category)"
        } else {
            return item.name
        }
    }
}
