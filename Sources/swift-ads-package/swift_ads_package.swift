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
    
    // Triggered when an error occurs during the WebView's operation, such as failing to load content.
    // This is called if the banner does not exist in the WebView.
    private var onErrorCallback: (() -> Void)?
    
    // Triggered when an alternative action is needed, such as displaying a fallback banner or alternative content.
    // This is called if the banner does not exist in the WebView.
    private var onAlternativeCallback: (() -> Void)?
    
    // Triggered when a custom data callback is executed by the JavaScript running in the WebView.
    // This is called if the banner exists in the WebView.
    private var onDataCallback: (() -> Void)?
    
    // Triggered when a user clicks on a specific element in the WebView that activates the "data-callback-url-click" event.
    private var onDataUrlClickCallback: (() -> Void)?
    
    // Triggered when a view-related event occurs in the WebView, associated with the "data-callback-url-view" event.
    private var onDataUrlViewCallback: (() -> Void)?
    
    // Triggered when the WebView finishes loading its content.
    // The parameter indicates whether an iframe was detected in the loaded content, which can help verify if the banner is successfully loaded.
    // Note: Detecting an iframe is not an official method to confirm banner loading, but it can be used as a supplementary check
    // alongside onDataCallback, onAlternativeCallback, onErrorCallback, and onDestroyCallback.
    private var onFinishedLoadingCallback: ((Bool) -> Void)?
    
    // Triggered when the WebView is destroyed, such as when it is removed from the view hierarchy or no longer needed.
    private var onDestroyCallback: (() -> Void)?
    
    // New initializer with the custom integer parameter
    @objc public init(
        frame: CGRect,
        configuration: WKWebViewConfiguration,
        scriptId: Int,
        onErrorCallback: (() -> Void)? = nil,
        onAlternativeCallback: (() -> Void)? = nil,
        onDataCallback: (() -> Void)? = nil,
        onDataUrlClickCallback: (() -> Void)? = nil,
        onDataUrlViewCallback: (() -> Void)? = nil,
        onFinishedLoadingCallback: ((Bool) -> Void)? = nil,
        onDestroyCallback: (() -> Void)? = nil
    ) {
        self.scriptId = scriptId
        self.onErrorCallback = onErrorCallback
        self.onAlternativeCallback = onAlternativeCallback
        self.onDataCallback = onDataCallback
        self.onDataUrlClickCallback = onDataUrlClickCallback
        self.onDataUrlViewCallback = onDataUrlViewCallback
        self.onFinishedLoadingCallback = onFinishedLoadingCallback
        self.onDestroyCallback = onDestroyCallback
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
        print("chega interno:")
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
        
        let callbackJs = """
               (function() {
                   let script = document.getElementById('CleverCoreLoader\(scriptId)');
                   if (script) {
                       script.setAttribute('data-callback', 'dataCallbackFunction');
                       script.setAttribute('data-callback-url-click', 'dataUrlClickFunction');
                       script.setAttribute('data-callback-url-view', 'dataUrlViewFunction');
           
                       window.dataCallbackFunction = function() {
                           window.webkit.messageHandlers.SwiftAdsMessageHandler.postMessage('data-callback');
                       };
           
                       window.dataUrlClickFunction = function() {
                           window.webkit.messageHandlers.SwiftAdsMessageHandler.postMessage('data-callback-url-click');
                       };
           
                       window.dataUrlViewFunction = function() {
                           window.webkit.messageHandlers.SwiftAdsMessageHandler.postMessage('data-callback-url-view');
                       };
           
                       console.log('Custom callbacks and attributes injected');
                   } else {
                       console.log('Script element not found');
                   }
               })();
           """
        let callbackUserScript = WKUserScript(source: callbackJs, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        self.configuration.userContentController.addUserScript(callbackUserScript)
        
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
        self.onDestroyCallback?()
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
        
        // Check the WebView's HTML content
        webView.evaluateJavaScript("document.documentElement.outerHTML") { result, error in
            if let html = result as? String {
                print("HTML Content: \(html)")
            } else if let error = error {
                print("Failed to retrieve HTML content: \(error.localizedDescription)")
            }
        }
        
        // Check if the page contains any <iframe> elements
        let js = """
                (function() {
                    return document.getElementsByTagName('iframe').length > 0;
                })();
            """
        
        webView.evaluateJavaScript(js) { [weak self] result, error in
            if let hasIframe = result as? Bool, hasIframe {
                print("Iframe found on the page")
                // Execute the callback to indicate that the banner is loaded
                self?.onFinishedLoadingCallback?(true)
            } else if let error = error {
                print("Failed to check for iframes: \(error.localizedDescription)")
                self?.onFinishedLoadingCallback?(false)
            } else {
                print("No iframe found on the page")
                self?.onFinishedLoadingCallback?(false)
            }
        }
        
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
            if (splittedMessage.first == "clever-redirect") {
#if os(iOS)
                if let urlString = splittedMessage.last.map(String.init), let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
#endif
            }
            
            if (splittedMessage.last == "callback") {
                print("callback triggered")
                self.onErrorCallback?()
            }
            
            if (splittedMessage.last == "alternative") {
                print("alternative triggered")
                self.onAlternativeCallback?()
            }
            
            if splittedMessage.last == "data-callback" {
                print("data-callback triggered")
                self.onDataCallback?()
            }
            
            if splittedMessage.last == "data-callback-url-click" {
                print("data-callback-url-click triggered")
                self.onDataUrlClickCallback?()
            }
            
            if splittedMessage.last == "data-callback-url-view" {
                print("data-callback-url-view triggered")
                self.onDataUrlViewCallback?()
            }
        }
    }
}
