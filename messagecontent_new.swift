struct MessageContentView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let content: String
    var font: Font = .system(size: 15)

    @State private var userNames: [String: String] = [:]
    @State private var selectedMentionURL: URL?

    var body: some View {
        attributedText
            .font(font)
            .lineSpacing(2)
            .environment(\.openURL, OpenURLAction { url in
                selectedMentionURL = url
                return .handled
            })
            .sheet(item: $selectedMentionURL) { url in
                mentionSheet(for: url)
            }
            .task(id: mentionUserIds) {
                await resolveUserNames()
            }
    }

    // MARK: - Mention parsing

    private enum MentionKind {
        case user(id: String)
        case channel(id: String)
        case role(id: String)
        case everyone
        case here
    }

    private struct Segment {
        let text: String
        let mention: MentionKind?
    }

    private var segments: [Segment] {
        let patterns: [(kind: (String) -> MentionKind?, regex: NSRegularExpression)] = [
            ({ .user(id: $0) }, try! NSRegularExpression(pattern: "<@!?(\\d+)>", options: [])),
            ({ .channel(id: $0) }, try! NSRegularExpression(pattern: "<#(\\d+)>", options: [])),
            ({ .role(id: $0) }, try! NSRegularExpression(pattern: "<@&(\\d+)>", options: [])),
            ({ _ in .everyone }, try! NSRegularExpression(pattern: "@everyone", options: [])),
            ({ _ in .here }, try! NSRegularExpression(pattern: "@here", options: [])),
        ]

        let nsRange = NSRange(content.startIndex..., in: content)
        var allMatches: [(range: Range<String.Index>, kind: MentionKind, replacement: String)] = []

        for (kindFactory, regex) in patterns {
            for match in regex.matches(in: content, options: [], range: nsRange) {
                guard let range = Range(match.range, in: content) else { continue }
                let idOrEmpty: String
                if match.numberOfRanges > 1, let idRange = Range(match.range(at: 1), in: content) {
                    idOrEmpty = String(content[idRange])
                } else {
                    idOrEmpty = ""
                }
                guard let kind = kindFactory(idOrEmpty) else { continue }
                let replacement: String
                switch kind {
                case .user: replacement = "@\(userNames[idOrEmpty] ?? idOrEmpty)"
                case .channel: replacement = "#\(channelName(for: idOrEmpty) ?? idOrEmpty)"
                case .role: replacement = "@role"
                case .everyone: replacement = "@everyone"
                case .here: replacement = "@here"
                }
                allMatches.append((range, kind, replacement))
            }
        }

        let sorted = allMatches.sorted { $0.range.lowerBound < $1.range.lowerBound }
        var filtered: [(range: Range<String.Index>, kind: MentionKind, replacement: String)] = []
        for match in sorted {
            if filtered.last?.range.overlaps(match.range) == true { continue }
            filtered.append(match)
        }

        var result: [Segment] = []
        var lastEnd = content.startIndex
        for match in filtered {
            if match.range.lowerBound > lastEnd {
                result.append(Segment(text: String(content[lastEnd..<match.range.lowerBound]), mention: nil))
            }
            result.append(Segment(text: match.replacement, mention: match.kind))
            lastEnd = match.range.upperBound
        }
        if lastEnd < content.endIndex {
            result.append(Segment(text: String(content[lastEnd..<content.endIndex]), mention: nil))
        }
        return result
    }

    private var mentionUserIds: [String] {
        segments.compactMap {
            if case .user(let id) = $0.mention { return id }
            return nil
        }
    }

    private var attributedText: Text {
        let md = markdownString()
        do {
            let attr = try AttributedString(
                markdown: md,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            )
            return Text(attr)
        } catch {
            return Text(content)
        }
    }

    private func markdownString() -> String {
        var md = ""
        for segment in segments {
            if let mention = segment.mention {
                switch mention {
                case .user(let id):
                    let name = escapeMarkdown(userNames[id] ?? id)
                    md += "[@\(name)](mention://user/\(id))"
                case .channel(let id):
                    let name = escapeMarkdown(channelName(for: id) ?? id)
                    md += "[#\(name)](mention://channel/\(id))"
                case .role(let id):
                    md += "[@role](mention://role/\(id))"
                case .everyone:
                    md += "[@everyone](mention://everyone)"
                case .here:
                    md += "[@here](mention://here)"
                }
            } else {
                md += escapeMarkdown(segment.text)
            }
        }
        return md
    }

    private func escapeMarkdown(_ text: String) -> String {
        var result = text
        for char in ["\\", "[", "]", "(", ")", "`", "*", "_", "~"] {
            result = result.replacingOccurrences(of: char, with: "\\\\\(char)")
        }
        return result
    }

    private func channelName(for id: String) -> String? {
        for server in appState.gatewayGuilds {
            if let channel = server.channels.first(where: { $0.id == id }) {
                return channel.name
            }
        }
        return nil
    }

    private func resolveUserNames() async {
        await withTaskGroup(of: (String, String?).self) { group in
            for id in mentionUserIds {
                group.addTask {
                    if let user = await UserCache.shared.user(withId: id) {
                        return (id, user.formattedName)
                    }
                    return (id, nil)
                }
            }
            var names: [String: String] = [:]
            for await (id, name) in group {
                if let name { names[id] = name }
            }
            if !names.isEmpty {
                await MainActor.run { userNames.merge(names) { _, new in new } }
            }
        }
    }

    // MARK: - Interaction

    @ViewBuilder
    private func mentionSheet(for url: URL) -> some View {
        switch url.host {
        case "user":
            if let id = url.pathComponents.last {
                UserMentionSheet(userId: id)
            }
        case "channel":
            if let id = url.pathComponents.last, let channel = findChannel(id: id) {
                NavigationStack {
                    ChatView(channel: channel)
                }
            }
        default:
            EmptyView()
        }
    }

    private func findChannel(id: String) -> Channel? {
        for server in appState.gatewayGuilds {
            if let channel = server.channels.first(where: { $0.id == id }) {
                return channel
            }
        }
        return nil
    }
}

// MARK: - User Mention Sheet
struct UserMentionSheet: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let userId: String

    @State private var user: User?

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundPrimary(colorScheme).ignoresSafeArea()
                VStack(spacing: 20) {
                    if let user {
                        AvatarView(user: user, size: 100)
                        Text(user.formattedName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                        Text(user.displayUsername)
                            .font(.system(size: 16))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                    } else {
                        ProgressView()
                    }
                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationTitle("User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                user = await UserCache.shared.user(withId: userId)
            }
        }
    }
}

// MARK: - Reply Preview View
