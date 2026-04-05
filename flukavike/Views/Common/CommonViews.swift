//
//  CommonViews.swift
//  Shared UI components
//

import SwiftUI

// MARK: - Avatar View
struct AvatarView: View {
    let user: User
    let size: CGFloat
    var showStatus: Bool = true

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    private var resolvedURL: URL? {
        APIService.shared.avatarURL(userId: user.id, hash: user.avatarUrl)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let url = resolvedURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }

            if showStatus {
                Circle()
                    .fill(user.status.color)
                    .frame(width: size * 0.3, height: size * 0.3)
                    .overlay(Circle().stroke(themeManager.backgroundPrimary(colorScheme), lineWidth: 2))
                    .offset(x: 2, y: 2)
            }
        }
        .frame(width: size, height: size)
    }

    private var placeholder: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [themeManager.accentColor.color.opacity(0.7),
                             themeManager.accentColor.color.opacity(0.3)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            Text(user.formattedName.prefix(1).uppercased())
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
        }
        .clipShape(Circle())
        .frame(width: size, height: size)
    }
}

// MARK: - Server Icon View
struct ServerIconView: View {
    let server: Server
    let size: CGFloat
    var cornerRadius: CGFloat = 12

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    private var resolvedURL: URL? {
        APIService.shared.serverIconURL(serverId: server.id, hash: server.iconUrl)
    }

    var body: some View {
        Group {
            if let url = resolvedURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(themeManager.accentColor.color.opacity(0.2))
            Text(server.name.prefix(1).uppercased())
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(themeManager.accentColor.color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Loading View
struct LoadingView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            HexagonShape()
                .stroke(themeManager.accentColor.color.opacity(0.3), lineWidth: 2)
                .frame(width: 60, height: 60)
            
            HexagonShape()
                .fill(themeManager.accentColor.color)
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 2)
                    .repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(themeManager.accentColor.color.opacity(0.6))
            
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(themeManager.textPrimary(colorScheme))
            
            Text(message)
                .font(.system(size: 16))
                .foregroundStyle(themeManager.textSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(themeManager.accentColor.color)
                        )
                }
                .padding(.top, 12)
            }
            
            Spacer()
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
            
            TextField(placeholder, text: $text)
                .font(.system(size: 17))
                .foregroundStyle(themeManager.textPrimary(colorScheme))
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(themeManager.backgroundTertiary(colorScheme))
        )
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let showArrow: Bool
    let action: () -> Void
    
    init(
        icon: String,
        iconColor: Color? = nil,
        title: String,
        subtitle: String? = nil,
        showArrow: Bool = true,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor ?? .accentColor
        self.title = title
        self.subtitle = subtitle
        self.showArrow = showArrow
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                    }
                }
                
                Spacer()
                
                if showArrow {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Toggle Row
struct ToggleRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: themeManager.accentColor.color))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Hexagon Shape (Flukavike brand element)
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let side = min(width, height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        for i in 0..<6 {
            let angle = Double(i) * 60.0 - 30.0
            let x = center.x + side/2 * CGFloat(cos(angle * .pi / 180))
            let y = center.y + side/2 * CGFloat(sin(angle * .pi / 180))
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    let title: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil
    
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
            
            Spacer()
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(themeManager.accentColor.color)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        AvatarView(user: User.preview, size: 60)
        LoadingView()
        SearchBar(text: .constant(""), placeholder: "Search")
        SettingsRow(icon: "gear", title: "Settings", subtitle: "Appearance & more") {}
    }
    .padding()
    .environment(ThemeManager())
}
