//
//  HCaptchaView.swift
//  hCaptcha verification component
//

import SwiftUI
import WebKit

// MARK: - HCaptcha WebView

struct HCaptchaView: UIViewRepresentable {
    let siteKey: String
    let hostURL: URL
    let onToken: (String) -> Void
    let onError: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onToken: onToken, onError: onError)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "captcha")
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard !context.coordinator.hasLoaded else { return }
        context.coordinator.hasLoaded = true

        guard let captchaHost = Self.captchaHost(from: hostURL) else {
            onError("Failed to determine captcha host from \(hostURL.absoluteString)")
            return
        }

        let html = Self.captchaHTML(siteKey: siteKey, host: captchaHost)
        webView.loadHTMLString(html, baseURL: Self.localBaseURL)
    }
    
    private static let localBaseURL = URL(string: "http://localhost")!

    private static func captchaHost(from url: URL) -> String? {
        url.host()
    }

    static func captchaHTML(siteKey: String, host: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    min-height: 100vh;
                    margin: 0;
                    background: transparent;
                }
            </style>
        </head>
        <body>
            <div id="captcha-container"></div>
            <script src="https://js.hcaptcha.com/1/api.js?onload=onHCaptchaLoad&render=explicit&host=\(host)" async defer></script>
            <script>
                function onSuccess(token) {
                    window.webkit.messageHandlers.captcha.postMessage(
                        JSON.stringify({ type: "token", value: token })
                    );
                }
                function onError(err) {
                    window.webkit.messageHandlers.captcha.postMessage(
                        JSON.stringify({ type: "error", value: String(err) })
                    );
                }
                function onExpired() {
                    window.webkit.messageHandlers.captcha.postMessage(
                        JSON.stringify({ type: "expired", value: "Captcha expired" })
                    );
                }
                function onHCaptchaLoad() {
                    hcaptcha.render('captcha-container', {
                        sitekey: '\(siteKey)',
                        callback: onSuccess,
                        'error-callback': onError,
                        'expired-callback': onExpired
                    });
                }
            </script>
        </body>
        </html>
        """
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var hasLoaded = false
        let onToken: (String) -> Void
        let onError: (String) -> Void
        
        init(onToken: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onToken = onToken
            self.onError = onError
        }
        
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? String,
                  let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let type = json["type"],
                  let value = json["value"] else { return }
            
            DispatchQueue.main.async {
                switch type {
                case "token":
                    self.onToken(value)
                case "error", "expired":
                    self.onError(value)
                default:
                    break
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onError("Failed to load captcha: \(error.localizedDescription)")
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            onError("Failed to load captcha: \(error.localizedDescription)")
        }
    }
}

// MARK: - HCaptcha Sheet View

struct HCaptchaSheetView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    let siteKey: String
    let hostURL: URL
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
                    hostURL: hostURL,
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
