//
//  ShareViewController.swift
//  Fluxer Share Extension - Share content to Fluxer
//

import UIKit
import SwiftUI
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    private var hostingController: UIHostingController<ShareExtensionView>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check if user is authenticated
        guard SharedAuthService.shared.isAuthenticated else {
            showLoginRequired()
            return
        }
        
        // Extract shared items
        extractSharedItems { [weak self] items in
            DispatchQueue.main.async {
                self?.setupShareView(with: items)
            }
        }
    }
    
    private func setupShareView(with items: [ShareItem]) {
        let shareView = ShareExtensionView(
            items: items,
            onCancel: { [weak self] in
                self?.cancelShare()
            },
            onShare: { [weak self] serverId, channelId, message in
                self?.performShare(serverId: serverId, channelId: channelId, message: message)
            }
        )
        
        hostingController = UIHostingController(rootView: shareView)
        guard let hostingController = hostingController else { return }
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hostingController.didMove(toParent: self)
    }
    
    private func extractSharedItems(completion: @escaping ([ShareItem]) -> Void) {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            completion([])
            return
        }
        
        var items: [ShareItem] = []
        let group = DispatchGroup()
        
        // Handle text
        if let attachments = extensionItem.attachments {
            for provider in attachments {
                // Text
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { text, error in
                        if let text = text as? String {
                            items.append(.text(text))
                        }
                        group.leave()
                    }
                }
                
                // URL
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { url, error in
                        if let url = url as? URL {
                            items.append(.url(url))
                        }
                        group.leave()
                    }
                }
                
                // Image
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { image, error in
                        if let image = image as? UIImage {
                            items.append(.image(image))
                        }
                        group.leave()
                    }
                }
                
                // Video
                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { url, error in
                        if let url = url as? URL {
                            items.append(.video(url))
                        }
                        group.leave()
                    }
                }
                
                // File
                if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { url, error in
                        if let url = url as? URL {
                            items.append(.file(url))
                        }
                        group.leave()
                    }
                }
            }
        }
        
        // Handle subject line if present
        if let subject = extensionItem.attributedContentText?.string {
            items.insert(.subject(subject), at: 0)
        }
        
        group.notify(queue: .main) {
            completion(items)
        }
    }
    
    private func performShare(serverId: String, channelId: String, message: String) {
        // Upload items and send message
        Task {
            do {
                // Upload any attachments
                var attachmentIds: [String] = []
                for item in hostingController?.rootView.items ?? [] {
                    if case .image(let image) = item {
                        let id = try await uploadImage(image, channelId: channelId)
                        attachmentIds.append(id)
                    } else if case .video(let url) = item {
                        let id = try await uploadVideo(url, channelId: channelId)
                        attachmentIds.append(id)
                    } else if case .file(let url) = item {
                        let id = try await uploadFile(url, channelId: channelId)
                        attachmentIds.append(id)
                    }
                }
                
                // Build message content
                var content = message
                for item in hostingController?.rootView.items ?? [] {
                    switch item {
                    case .text(let text):
                        content += "\n" + text
                    case .url(let url):
                        content += "\n" + url.absoluteString
                    default:
                        break
                    }
                }
                
                // Send message
                _ = try await SharedAPIService.shared.sendMessage(
                    channelId: channelId,
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                await MainActor.run {
                    self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                }
            } catch {
                await MainActor.run {
                    self.showError(error)
                }
            }
        }
    }
    
    private func uploadImage(_ image: UIImage, channelId: String) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw ShareError.failedToProcessImage
        }
        return try await SharedAPIService.shared.uploadAttachment(
            data: data,
            filename: "image_\(UUID().uuidString).jpg",
            mimeType: "image/jpeg",
            channelId: channelId
        )
    }
    
    private func uploadVideo(_ url: URL, channelId: String) async throws -> String {
        let data = try Data(contentsOf: url)
        return try await SharedAPIService.shared.uploadAttachment(
            data: data,
            filename: url.lastPathComponent,
            mimeType: "video/mp4",
            channelId: channelId
        )
    }
    
    private func uploadFile(_ url: URL, channelId: String) async throws -> String {
        let data = try Data(contentsOf: url)
        return try await SharedAPIService.shared.uploadAttachment(
            data: data,
            filename: url.lastPathComponent,
            mimeType: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream",
            channelId: channelId
        )
    }
    
    private func cancelShare() {
        extensionContext?.cancelRequest(withError: NSError(domain: "com.fluxer.share", code: 0))
    }
    
    private func showLoginRequired() {
        let alert = UIAlertController(
            title: "Login Required",
            message: "Please open the Fluxer app and sign in to share content.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open Fluxer", style: .default) { _ in
            // Open the main app
            if let url = URL(string: "fluxer://") {
                self.extensionContext?.open(url, completionHandler: nil)
            }
            self.cancelShare()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.cancelShare()
        })
        present(alert, animated: true)
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Share Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Share Item Types
enum ShareItem: Identifiable {
    case text(String)
    case url(URL)
    case image(UIImage)
    case video(URL)
    case file(URL)
    case subject(String)
    
    var id: String {
        switch self {
        case .text(let str): return "text_\(str.hashValue)"
        case .url(let url): return "url_\(url.absoluteString)"
        case .image: return "image_\(UUID().uuidString)"
        case .video(let url): return "video_\(url.absoluteString)"
        case .file(let url): return "file_\(url.absoluteString)"
        case .subject(let str): return "subject_\(str)"
        }
    }
}

enum ShareError: Error {
    case failedToProcessImage
    case uploadFailed
}

// MARK: - Share Extension View (SwiftUI)
struct ShareExtensionView: View {
    let items: [ShareItem]
    let onCancel: () -> Void
    let onShare: (String, String, String) -> Void
    
    @State private var selectedServer: SharedServer?
    @State private var selectedChannel: SharedChannel?
    @State private var messageText: String = ""
    @State private var servers: [SharedServer] = []
    @State private var isLoading: Bool = true
    @State private var isSharing: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview of shared content
                sharePreview
                
                Divider()
                
                // Destination selector
                destinationSection
                
                Divider()
                
                // Message input
                messageInputSection
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Share to Fluxer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: shareAction) {
                        if isSharing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Share")
                        }
                    }
                    .disabled(selectedChannel == nil || isSharing)
                }
            }
        }
        .task {
            await loadServers()
        }
    }
    
    private var sharePreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items) { item in
                    ShareItemPreview(item: item)
                }
            }
            .padding()
        }
        .frame(height: 120)
        .background(Color(uiColor: .secondarySystemBackground))
    }
    
    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DESTINATION")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 12)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                // Server selector
                Menu {
                    ForEach(servers) { server in
                        Button(server.name) {
                            selectedServer = server
                            selectedChannel = nil
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.accent)
                        Text(selectedServer?.name ?? "Select Server")
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal)
                
                // Channel selector
                if let server = selectedServer {
                    Menu {
                        ForEach(server.channels) { channel in
                            Button("#\(channel.name)") {
                                selectedChannel = channel
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "number")
                                .foregroundStyle(.accent)
                            Text(selectedChannel != nil ? "#\(selectedChannel!.name)" : "Select Channel")
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.bottom, 12)
    }
    
    private var messageInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MESSAGE (OPTIONAL)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 12)
            
            TextEditor(text: $messageText)
                .font(.system(size: 16))
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
        }
        .padding(.bottom, 16)
    }
    
    private func loadServers() async {
        do {
            let fetched = try await SharedAPIService.shared.getUserGuilds()
            await MainActor.run {
                self.servers = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func shareAction() {
        guard let serverId = selectedServer?.id,
              let channelId = selectedChannel?.id else { return }
        
        isSharing = true
        onShare(serverId, channelId, messageText)
    }
}

// MARK: - Share Item Preview
struct ShareItemPreview: View {
    let item: ShareItem
    
    var body: some View {
        Group {
            switch item {
            case .text(let text):
                TextPreview(text: text)
            case .url(let url):
                URLPreview(url: url)
            case .image(let image):
                ImagePreview(image: image)
            case .video(let url):
                VideoPreview(url: url)
            case .file(let url):
                FilePreview(url: url)
            case .subject(let subject):
                SubjectPreview(subject: subject)
            }
        }
    }
}

struct TextPreview: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .lineLimit(3)
            .frame(width: 120, height: 80)
            .padding(8)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 1)
    }
}

struct URLPreview: View {
    let url: URL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "link")
                .font(.system(size: 24))
                .foregroundStyle(.accent)
            Text(url.host ?? url.absoluteString)
                .font(.system(size: 11))
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 100, height: 80)
        .padding(8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 1)
    }
}

struct ImagePreview: View {
    let image: UIImage
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 1)
    }
}

struct VideoPreview: View {
    let url: URL
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.1))
            
            VStack {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.accent)
                Text("Video")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 80, height: 80)
        .shadow(radius: 1)
    }
}

struct FilePreview: View {
    let url: URL
    
    var body: some View {
        VStack {
            Image(systemName: "doc.fill")
                .font(.system(size: 32))
                .foregroundStyle(.accent)
            Text(url.pathExtension.uppercased())
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(width: 80, height: 80)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 1)
    }
}

struct SubjectPreview: View {
    let subject: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Subject")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.accent)
            Text(subject)
                .font(.system(size: 12))
                .lineLimit(2)
        }
        .frame(width: 120, height: 60)
        .padding(8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 1)
    }
}

// MARK: - Shared Models
struct SharedServer: Identifiable {
    let id: String
    let name: String
    let channels: [SharedChannel]
}

struct SharedChannel: Identifiable {
    let id: String
    let name: String
}

// MARK: - Shared API Service (Extension Version)
class SharedAPIService {
    static let shared = SharedAPIService()
    
    private let baseURL = "https://api.fluxer.app/v1"
    private var authToken: String? {
        KeychainTokenStore.getToken()
    }
    
    func getUserGuilds() async throws -> [SharedServer] {
        // Would make actual API call
        // GET /users/@me/guilds
        return [
            SharedServer(
                id: "1",
                name: "Fluxer HQ",
                channels: [
                    SharedChannel(id: "c1", name: "general"),
                    SharedChannel(id: "c2", name: "random")
                ]
            )
        ]
    }
    
    func sendMessage(channelId: String, content: String) async throws {
        // POST /channels/{id}/messages
    }
    
    func uploadAttachment(data: Data, filename: String, mimeType: String, channelId: String) async throws -> String {
        // POST /channels/{id}/messages with multipart form
        return UUID().uuidString
    }
}

// MARK: - Shared Auth Service
class SharedAuthService {
    static let shared = SharedAuthService()
    
    var isAuthenticated: Bool {
        KeychainTokenStore.getToken() != nil
    }
}
