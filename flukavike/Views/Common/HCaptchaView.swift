//
//  HCaptchaView.swift
//  hCaptcha verification component using official SDK
//

import SwiftUI
import WebKit

// MARK: - HCaptcha View Controller

/// UIViewController that hosts the hCaptcha challenge without the external SDK.
final class HCaptchaViewController: UIViewController {
    var siteKey: String?
    var baseURL: URL?
    var hostDomain: String?
    var onToken: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private var webView: WKWebView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        guard let siteKey, !siteKey.isEmpty else {
            onError?("Site key not provided")
            return
        }

        print("[HCaptcha] baseURL: \(baseURL?.absoluteString ?? "nil")")
        print("[HCaptcha] hostDomain: \(hostDomain ?? "nil")")
        print("[HCaptcha] siteKey prefix: \(String(siteKey.prefix(8)))...")
        let contentController = WKUserContentController()
        contentController.add(WeakScriptMessageHandler(delegate: self), name: "hcaptchaToken")
        contentController.add(WeakScriptMessageHandler(delegate: self), name: "hcaptchaError")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        self.webView = webView
        webView.loadHTMLString(html(for: siteKey), baseURL: baseURL)
    }

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "hcaptchaToken")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "hcaptchaError")
    }

    private func html(for siteKey: String) -> String {
        let escapedSiteKey = siteKey
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        return """
        <!doctype html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
            <style>
                html, body {
                    margin: 0;
                    padding: 0;
                    background: transparent;
                    overflow: hidden;
                }
                body {
                    min-height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                #captcha-container {
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
            </style>
            <script src="https://js.hcaptcha.com/1/api.js?render=explicit" async defer></script>
            <script>
                function postError(message) {
                    window.webkit.messageHandlers.hcaptchaError.postMessage(message);
                }

                function onSolve(token) {
                    window.webkit.messageHandlers.hcaptchaToken.postMessage(token);
                }

                function onError(error) {
                    postError(error || "Verification failed");
                }

                function onExpired() {
                    postError("Verification expired, please try again");
                }

                function onLoad() {
                    if (!window.hcaptcha) {
                        postError("Failed to load challenge");
                        return;
                    }

                    window.hcaptcha.render("captcha-container", {
                        sitekey: "\(escapedSiteKey)",
                        callback: onSolve,
                        "error-callback": onError,
                        "expired-callback": onExpired
                    });
                }
            </script>
        </head>
        <body onload="onLoad()">
            <div id="captcha-container"></div>
        </body>
        </html>
        """
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

extension HCaptchaViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? String, !body.isEmpty else {
            onError?("Verification failed")
            return
        }

        switch message.name {
        case "hcaptchaToken":
            print("[HCaptcha] Token received successfully")
            onToken?(body)
        case "hcaptchaError":
            print("[HCaptcha] Error: \(body)")
            onError?(body)
        default:
            break
        }
    }
}

extension HCaptchaViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onError?("Failed to load challenge: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onError?("Failed to load challenge: \(error.localizedDescription)")
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

struct HCaptchaWidgetCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let siteKey: String
    let token: String?
    let onToken: (String) -> Void
    let onReset: () -> Void

    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Verification")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(themeManager.textSecondary(colorScheme))

                    Text(token == nil ? "Complete the hCaptcha challenge to continue." : "Verification completed.")
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                }

                Spacer()

                if token != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
            }

            HCaptchaView(
                siteKey: siteKey,
                baseURL: captchaBaseURL(),
                hostDomain: captchaHostDomain(),
                onToken: { value in
                    errorMessage = nil
                    onToken(value)
                },
                onError: { error in
                    errorMessage = "Verification failed: \(error)"
                    onReset()
                }
            )
            .frame(height: 132)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if token != nil {
                Button("Reset verification") {
                    errorMessage = nil
                    onReset()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(themeManager.accentColor.color)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(themeManager.backgroundSecondary(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(themeManager.separator(colorScheme), lineWidth: 1)
        )
    }

    private func captchaBaseURL() -> URL? {
        let webBaseURL = APIService.shared.webBaseURL
        if !webBaseURL.isEmpty, let url = URL(string: webBaseURL) {
            return url
        }

        let instance = APIService.shared.currentInstance
        if !instance.isEmpty, let url = URL(string: "https://\(instance)") {
            return url
        }

        return nil
    }

    private func captchaHostDomain() -> String? {
        let webBaseURL = APIService.shared.webBaseURL
        if !webBaseURL.isEmpty, let url = URL(string: webBaseURL) {
            return url.host
        }

        let instance = APIService.shared.currentInstance
        if !instance.isEmpty {
            return instance
        }

        return nil
    }
}
