//
//  AnimatedImageView.swift
//  Remote image view that plays animated GIF / WebP (server icons and banners).
//

import ImageIO
import SwiftUI
import UIKit

// MARK: - Loader

/// Downloads an image and, when it has several frames, decodes it into an animated UIImage.
actor AnimatedImageLoader {
    static let shared = AnimatedImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    func image(for url: URL, maxPixelSize: CGFloat = 800) async -> UIImage? {
        let key = url.absoluteString
        if let cached = cache.object(forKey: key as NSString) { return cached }
        if let existing = inFlight[key] { return await existing.value }

        let task = Task<UIImage?, Never> {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = Self.decode(data, maxPixelSize: maxPixelSize) else { return nil }
            self.store(image, key: key, cost: data.count)
            return image
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }

    private func store(_ image: UIImage, key: String, cost: Int) {
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    private static func decode(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return UIImage(data: data) }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        var frames: [UIImage] = []
        var total: TimeInterval = 0
        for index in 0..<count {
            guard let cg = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else { continue }
            frames.append(UIImage(cgImage: cg))
            total += frameDelay(source: source, index: index)
        }
        guard !frames.isEmpty else { return UIImage(data: data) }
        return UIImage.animatedImage(with: frames, duration: max(total, 0.1))
    }

    private static func frameDelay(source: CGImageSource, index: Int) -> TimeInterval {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] else { return 0.1 }
        let dicts: [CFString] = [kCGImagePropertyGIFDictionary, kCGImagePropertyWebPDictionary]
        for dictKey in dicts {
            guard let dict = props[dictKey] as? [CFString: Any] else { continue }
            let unclamped = dict[kCGImagePropertyGIFUnclampedDelayTime] as? Double
            let clamped = dict[kCGImagePropertyGIFDelayTime] as? Double
            if let delay = unclamped ?? clamped, delay > 0 { return max(delay, 0.02) }
        }
        return 0.1
    }
}

// MARK: - UIKit bridge

private struct AnimatedImageRepresentable: UIViewRepresentable {
    let image: UIImage
    let contentMode: UIView.ContentMode

    func makeUIView(context: Context) -> UIView {
        // Container has no intrinsic size, so SwiftUI's frame fully controls layout.
        let container = UIView()
        container.clipsToBounds = true
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        imageView.tag = 1
        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let imageView = container.viewWithTag(1) as? UIImageView else { return }
        imageView.contentMode = contentMode
        if imageView.image !== image {
            imageView.image = image
        }
        if image.images != nil, !imageView.isAnimating {
            imageView.startAnimating()
        }
    }
}

// MARK: - SwiftUI view

struct AnimatedRemoteImage<Placeholder: View>: View {
    let url: URL?
    var contentMode: UIView.ContentMode = .scaleAspectFill
    var maxPixelSize: CGFloat = 800
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                AnimatedImageRepresentable(image: image, contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { image = nil; return }
            image = await AnimatedImageLoader.shared.image(for: url, maxPixelSize: maxPixelSize)
        }
    }
}
