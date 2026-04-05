//
//  ProfileView.swift
//  Discord-style user profile
//

import SwiftUI

struct ProfileView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    
    @State private var user: User?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showEditNote = false
    @State private var noteText = ""
    
    private var displayUser: User {
        user ?? appState.currentUser ?? User.preview
    }
    
    private var isAuthenticated: Bool {
        appState.isAuthenticated || appState.currentUser != nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        // Purple Banner
                        bannerSection
                        
                        // Profile Info Card
                        profileInfoCard
                        
                        // Member Since Info
                        memberSinceCard
                        
                        // Note Card (private)
                        noteCard
                        
                        Spacer(minLength: 100)
                    }
                }
                .background(themeManager.backgroundPrimary(colorScheme))
                
                // Loading overlay
                if isLoading && user == nil && appState.currentUser == nil {
                    loadingOverlay
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditNote) {
                NoteEditSheet(noteText: $noteText)
            }
        }
        .onAppear {
            loadUser()
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Spacer()
        }
        .background(themeManager.backgroundPrimary(colorScheme))
    }
    
    // MARK: - Banner Section
    private var bannerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Purple Banner (or user banner if available)
            if let bannerUrl = displayUser.bannerUrl {
                AsyncImage(url: URL(string: bannerUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        themeManager.accentColor.color
                    }
                }
                .frame(height: 120)
                .clipped()
            } else {
                themeManager.accentColor.color
                    .frame(height: 120)
            }
            
            // Avatar overlapping banner
            AvatarView(user: displayUser, size: 90)
                .overlay(
                    Circle()
                        .stroke(themeManager.backgroundPrimary(colorScheme), lineWidth: 4)
                )
                .offset(x: 20, y: 45)
        }
        .frame(height: 120)
    }
    
    // MARK: - Profile Info Card
    private var profileInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Username and Handle
            VStack(alignment: .leading, spacing: 4) {
                Text(displayUser.formattedName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                
                Text(displayUser.displayUsername)
                    .font(.system(size: 16))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
            }
            
            // Status indicator if available
            if let customStatus = displayUser.customStatus, !customStatus.isEmpty {
                HStack(spacing: 6) {
                    Circle()
                        .fill(displayUser.status.color)
                        .frame(width: 8, height: 8)
                    Text(customStatus)
                        .font(.system(size: 14))
                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                }
            } else if displayUser.status != .offline {
                HStack(spacing: 6) {
                    Circle()
                        .fill(displayUser.status.color)
                        .frame(width: 8, height: 8)
                    Text(displayUser.status.rawValue.capitalized)
                        .font(.system(size: 14))
                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                }
            }
            
            // Edit Profile Button (only if authenticated)
            if isAuthenticated {
                Button(action: {}) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Edit Profile")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.accentColor.color)
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.backgroundSecondary(colorScheme))
        )
        .padding(.horizontal, 16)
        .padding(.top, 50)
    }
    
    // MARK: - Member Since Card
    private var memberSinceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // About Me
            if let bio = displayUser.bio {
                VStack(alignment: .leading, spacing: 4) {
                    Text("About me")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                        .textCase(.uppercase)
                    
                    Text(bio)
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                        .lineSpacing(2)
                }
            }
            
            // Member Since
            VStack(alignment: .leading, spacing: 4) {
                Text("Fluxer Member Since")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .textCase(.uppercase)
                
                Text(displayUser.createdAt, style: .date)
                    .font(.system(size: 15))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.backgroundSecondary(colorScheme))
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - Note Card
    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Note")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                        .textCase(.uppercase)
                    
                    Text("(only visible to you)")
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                }
                
                Spacer()
                
                Button(action: {
                    showEditNote = true
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                }
            }
            
            if noteText.isEmpty {
                Text("No note yet.")
                    .font(.system(size: 15))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
            } else {
                Text(noteText)
                    .font(.system(size: 15))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.backgroundSecondary(colorScheme))
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - Data Loading
    private func loadUser() {
        // First check if we already have the user in AppState
        if let currentUser = appState.currentUser {
            self.user = currentUser
            self.isLoading = false
            return
        }
        
        // Check WebAuthService
        if let authUser = WebAuthService.shared.currentUser {
            self.user = authUser
            self.isLoading = false
            return
        }
        
        // If authenticated but no user data, fetch from API
        if isAuthenticated {
            Task {
                await fetchCurrentUser()
            }
        } else {
            // Not authenticated, use preview data
            self.isLoading = false
        }
    }
    
    private func fetchCurrentUser() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedUser = try await APIService.shared.getCurrentUser()
            await MainActor.run {
                self.user = fetchedUser
                self.appState.currentUser = fetchedUser
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Note Edit Sheet
struct NoteEditSheet: View {
    @Binding var noteText: String
    @Environment(\.dismiss) private var dismiss
    @State private var tempText: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $tempText)
                    .font(.system(size: 16))
                    .padding()
                    .scrollContentBackground(.hidden)
                
                Spacer()
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        noteText = tempText
                        dismiss()
                    }
                }
            }
            .onAppear {
                tempText = noteText
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ProfileView()
        .environment(ThemeManager())
        .environment(AppState())
}
