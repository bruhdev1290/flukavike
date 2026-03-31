//
//  HCaptchaView.swift
//  hCaptcha verification component using official SDK
//

import SwiftUI
import HCaptcha

// MARK: - HCaptcha View Controller

/// UIViewController that hosts the hCaptcha challenge
class HCaptchaViewController: UIViewController {
    var siteKey: String?
    var baseURL: URL?
    var hostDomain: String?
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
        
        // Log the parameters for debugging
        print("[HCaptcha] baseURL: \(baseURL?.absoluteString ?? "nil")")
        print("[HCaptcha] hostDomain: \(hostDomain ?? "nil")")
        print("[HCaptcha] siteKey prefix: \(String(siteKey.prefix(8)))...")
        
        // Initialize hCaptcha with site key, base URL, and host for proper origin
        do {
            hcaptcha = try HCaptcha(
                apiKey: siteKey,
                baseURL: baseURL,
                locale: nil,
                size: .compact,
                host: hostDomain
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
                        print("[HCaptcha] Token received successfully")
                        self.onToken?(token)
                    case .error(let error):
                        let message = self.errorMessage(for: error)
                        print("[HCaptcha] Error: \(message)")
                        self.onError?(message)
                    }
                }
            }
            
        } catch {
            print("[HCaptcha] Init error: \(error)")
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

// MARK: - HCaptcha SwiftUI View

struct HCaptchaView: UIViewControllerRepresentable {
    let siteKey: String
    let baseURL: URL?
    let hostDomain: String?
    let onToken: (String) -> Void
    let onError: (String) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = HCaptchaViewController()
        viewController.siteKey = siteKey
        viewController.baseURL = baseURL
        viewController.hostDomain = hostDomain
        viewController.onToken = onToken
        viewController.onError = onError
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
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
                    baseURL: captchaBaseURL(),
                    hostDomain: captchaHostDomain(),
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
    
    /// Returns the base URL for hCaptcha origin validation
    private func captchaBaseURL() -> URL? {
        let webBaseURL = APIService.shared.webBaseURL
        print("[HCaptcha] APIService.webBaseURL: \(webBaseURL)")
        
        if !webBaseURL.isEmpty, let url = URL(string: webBaseURL) {
            print("[HCaptcha] Using baseURL: \(url)")
            return url
        }
        
        let instance = APIService.shared.currentInstance
        if !instance.isEmpty, let url = URL(string: "https://\(instance)") {
            print("[HCaptcha] Using instance baseURL: \(url)")
            return url
        }
        
        // DEBUG: Hardcode your domain here to test
        // return URL(string: "https://your-actual-domain.com")
        
        print("[HCaptcha] WARNING: No baseURL available")
        return nil
    }
    
    /// Returns the host domain for hCaptcha host parameter
    private func captchaHostDomain() -> String? {
        // Use the host from webBaseURL if available
        let webBaseURL = APIService.shared.webBaseURL
        if !webBaseURL.isEmpty, let url = URL(string: webBaseURL) {
            let host = url.host
            print("[HCaptcha] Using hostDomain: \(host ?? "nil")")
            return host
        }
        
        // Fallback to current instance
        let instance = APIService.shared.currentInstance
        if !instance.isEmpty {
            print("[HCaptcha] Using instance hostDomain: \(instance)")
            return instance
        }
        
        return nil
    }
}
