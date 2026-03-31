//
//  HCaptchaView.swift
//  hCaptcha verification component using official SDK
//

import SwiftUI
import HCaptcha

// MARK: - HCaptcha Manager

/// Manages the shared HCaptcha instance and validation flow
@MainActor
class HCaptchaManager: ObservableObject {
    static let shared = HaptchaManager()
    
    private var hcaptcha: HCaptcha?
    private var isConfigured = false
    
    /// Configure the HCaptcha instance with a site key
    func configure(siteKey: String) {
        guard !isConfigured || hcaptcha == nil else { return }
        
        hcaptcha = try? HCaptcha(
            apiKey: siteKey,
            baseURL: nil,
            locale: nil,
            size: .compact
        )
        isConfigured = true
    }
    
    /// Reset configuration when switching instances
    func reset() {
        hcaptcha = nil
        isConfigured = false
    }
    
    /// Validate and get token
    func validate(on viewController: UIViewController, completion: @escaping (Result<String, Error>) -> Void) {
        guard let hcaptcha = hcaptcha else {
            completion(.failure(HCaptchaError.notConfigured))
            return
        }
        
        hcaptcha.validate(on: viewController) { result in
            switch result {
            case .token(let token):
                completion(.success(token))
            case .error(let error):
                completion(.failure(error))
            }
        }
    }
}

enum HCaptchaError: LocalizedError {
    case notConfigured
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "hCaptcha not configured"
        case .validationFailed(let message):
            return message
        }
    }
}

// MARK: - HCaptcha SwiftUI View

struct HCaptchaView: UIViewControllerRepresentable {
    let siteKey: String
    let onToken: (String) -> Void
    let onError: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onToken: onToken, onError: onError)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = HCaptchaViewController()
        viewController.siteKey = siteKey
        viewController.onToken = onToken
        viewController.onError = onError
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
    
    class Coordinator {
        let onToken: (String) -> Void
        let onError: (String) -> Void
        
        init(onToken: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onToken = onToken
            self.onError = onError
        }
    }
}

// MARK: - HCaptcha View Controller

/// UIViewController that hosts the hCaptcha challenge
class HCaptchaViewController: UIViewController {
    var siteKey: String?
    var onToken: ((String) -> Void)?
    var onError: ((String) -> Void)?
    
    private var hcaptcha: HCaptcha?
    private var hasPresentedCaptcha = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        // Add a loading indicator
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard !hasPresentedCaptcha else { return }
        hasPresentedCaptcha = true
        
        guard let siteKey = siteKey else {
            onError?("Site key not provided")
            return
        }
        
        // Initialize hCaptcha with site key
        do {
            hcaptcha = try HCaptcha(
                apiKey: siteKey,
                baseURL: nil,
                locale: nil,
                size: .compact
            )
            
            // Configure webview appearance
            hcaptcha?.configureWebView { webview in
                webview.frame = self.view.bounds
                webview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                webview.backgroundColor = .clear
                webview.isOpaque = false
            }
            
            // Validate and present
            hcaptcha?.validate(on: self) { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    switch result {
                    case .token(let token):
                        self.onToken?(token)
                    case .error(let error):
                        self.onError?(self.errorMessage(for: error))
                    }
                }
            }
            
        } catch {
            onError?("Failed to initialize hCaptcha: \(error.localizedDescription)")
        }
    }
    
    private func errorMessage(for error: HCaptchaError) -> String {
        switch error {
        case .invalidAPIKey:
            return "Invalid site key"
        case .invalidLocale:
            return "Invalid locale configuration"
        case .invalidCallback:
            return "Invalid callback configuration"
        case .badURL:
            return "Failed to load challenge"
        case .challengeClosed:
            return "Verification was cancelled"
        case .challengeExpired:
            return "Verification expired, please try again"
        case .tokenExpired:
            return "Token expired, please try again"
        case .retryLimitReached:
            return "Too many attempts, please try again later"
        case .networkError:
            return "Network error, please check your connection"
        @unknown default:
            return "Verification failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - HCaptcha Sheet View

struct HCaptchaSheetView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    let siteKey: String
    let onCompleted: (String) -> Void
    
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Complete the verification below to continue.")
                    .font(.system(size: 15))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                HCaptchaView(
                    siteKey: siteKey,
                    onToken: { token in
                        onCompleted(token)
                        dismiss()
                    },
                    onError: { error in
                        errorMessage = "Verification failed: \(error). Please try again."
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                }
            }
        }
    }
}
