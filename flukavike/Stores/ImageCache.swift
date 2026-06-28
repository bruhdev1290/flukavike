//
//  ImageCache.swift
//  Lightweight in-memory image cache for avatars and server icons.
//

import UIKit

actor ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 300
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func image(for url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        if let existing = inFlightTasks[key as String] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            defer { self.removeTask(for: url.absoluteString) }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return nil }
                self.cache.setObject(image, forKey: key, cost: data.count)
                return image
            } catch {
                return nil
            }
        }

        inFlightTasks[url.absoluteString] = task
        return await task.value
    }

    func clear() {
        cache.removeAllObjects()
    }

    private func removeTask(for key: String) {
        inFlightTasks.removeValue(forKey: key)
    }
}
