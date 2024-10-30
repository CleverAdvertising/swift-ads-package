import Foundation
import WebKit
#if os(iOS)
import UIKit
#endif
import Combine

@available(iOS 13.0, *)
@objc public class SwiftAdsPackage: WKWebView {

    private var finishedLoading: Bool = false;
    private var scriptId: Int
    private var cancellables = Set<AnyCancellable>()
    private let counterStorage = CounterStorage()

    // New initializer with the custom integer parameter
    @objc public init(frame: CGRect, configuration: WKWebViewConfiguration, scriptId: Int) {
        self.scriptId = scriptId
        super.init(frame: frame, configuration: configuration)
        setup()
    }

    // Overriding the existing initializer
    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        self.scriptId = 0 // Provide a default value if needed
        super.init(frame: frame, configuration: configuration)
        setup()
    }
    
    required init?(coder: NSCoder) {
        self.scriptId = 0 // Provide a default value if needed
        super.init(coder: coder)
        setup()
    }
    private func setup() {
        print("Checking counter data")
        counterStorage.getCounterData(scriptId: "\(scriptId)")
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { _ in }) { [weak self] result in
                        if result != false {
                            print("Counter data existed, leaving")
                            self?.destroy()
                        } else {
                            print("Initialize webview")
                            self?.initWebView()
                        }
                    }
                    .store(in: &cancellables)
    }
    
    private func initWebView() {
        // Add your WebView configuration here
        self.navigationDelegate = self
        self.uiDelegate = self
        
        // Configure WebView settings
        let scriptUrl = "https://script.cleverwebserver.com/v1/html/\(scriptId)?app=\(Bundle.main.bundleIdentifier ?? "")&sdk=swift"

        let request = URLRequest(url: URL(string: scriptUrl)!)
        self.load(request)
        
        self.configuration.preferences.javaScriptEnabled = true
        self.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        self.configuration.userContentController.add(self, name: "SwiftAdsMessageHandler")
        let js = """
            let oldPostMessage = window.postMessage;
            window.postMessage = function(message) {
                window.webkit.messageHandlers.SwiftAdsMessageHandler.postMessage(message);
                oldPostMessage(message);
            };
            """
            let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            self.configuration.userContentController.addUserScript(userScript)

        let lastTrackerCookieKey = "clever-last-tracker-\(self.scriptId)"
        let lastTracker = self.counterStorage.getFromStorage(key: lastTrackerCookieKey);
        if let lastTracker = lastTracker {
            let cookieProperties: [HTTPCookiePropertyKey: Any] = [
                .path: "/",
                .name: lastTrackerCookieKey,
                .value: lastTracker,
                .secure: "TRUE",
                .expires: NSDate(timeIntervalSinceNow: 2.628e+6)
            ]

            if let cookie = HTTPCookie(properties: cookieProperties) {
                // Add the cookie to the web view
                let websiteDataStore = WKWebsiteDataStore.default()
                websiteDataStore.httpCookieStore.setCookie(cookie, completionHandler: nil)
            }
        }
        //self.configuration.preferences.setValue(true, forKey: "domStorageEnabled")
        
    }
    private func destroy() {
            self.navigationDelegate = nil
            self.uiDelegate = nil
            self.stopLoading()
            self.removeFromSuperview()
            self.load(URLRequest(url: URL(string: "about:blank")!))
        }
}
@available(iOS 13.0, *)
extension SwiftAdsPackage: WKNavigationDelegate, WKUIDelegate {
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            #if os(iOS)
            UIApplication.shared.open(navigationAction.request.url!, options: [:])
            #elseif os(macOS)
            NSWorkspace.shared.open(navigationAction.request.url!)
            #endif
        }
        return nil
    }
    // WKNavigationDelegate methods
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Check if the URL is intended to be opened in an external browser
            if (!finishedLoading) {
                decisionHandler(.allow)
                return;
            }
        
            if shouldBeOpenedInBrowser(url: navigationAction.request.url?.absoluteString ?? "") {
            // Intent to open link in the default browser
            if let url = navigationAction.request.url {
                #if os(iOS)
                UIApplication.shared.open(url)
                #elseif os(macOS)
                NSWorkspace.shared.open(url)
                #endif
            }
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.finishedLoading = true;
        let scriptUrl = "https://script.cleverwebserver.com/v1/html/\(scriptId)?app=\(Bundle.main.bundleIdentifier ?? "")&sdk=swift"
        self.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                let key = cookie.name
                let value = cookie.value
                
                let lastTrackerCookieKey = "clever-last-tracker-\(self.scriptId)"
                if key == lastTrackerCookieKey {
                    let _ = self.counterStorage.saveToStorage(key: lastTrackerCookieKey, value: value)
                    return
                }
                
                let counterCookieKey = "clever-counter-\(self.scriptId)"
                if key == counterCookieKey {
                    DispatchQueue.main.async {
                        let _ = self.counterStorage.storeCounterData(scriptId: self.scriptId)
                        let __ = self.counterStorage.deleteFromStorage(key: lastTrackerCookieKey)
                    }
                    return
                }
            }
        }

    }
    
    // WKUIDelegate methods if needed
}
@available(iOS 13.0, *)
extension SwiftAdsPackage {
    // Helper methods
    
    private func shouldBeOpenedInBrowser(url: String) -> Bool {
        return !url.starts(with: "https://script.cleverwebserver.com")
    }
    
}
@available(iOS 13.0, *)
extension SwiftAdsPackage: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "SwiftAdsMessageHandler", let messageBody = message.body as? String {
            let splittedMessage = messageBody.split(separator: "|")
            if(splittedMessage.first != "clever-redirect") {
                return
            }
            if let urlString = splittedMessage.last.map(String.init), let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}
