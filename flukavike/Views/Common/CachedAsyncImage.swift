//
//  CachedAsyncImage.swift
//  Async image loader backed by the shared in-memory ImageCache.
//

import SwiftUI

enum CachedImagePhase {
    case empty
    case success(Image)
    case failure
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var phase: CachedImagePhase = .empty

    var body: some View {
        Group {
            switch phase {
            case .empty:
                placeholder()
            case .success(let image):
                content(image)
            case .failure:
                placeholder()
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        guard let url else {
            phase = .failure
            return
        }
        if let uiImage = await ImageCache.shared.image(for: url) {
            phase = .success(Image(uiImage: uiImage))
        } else {
            phase = .failure
        }
    }
}
