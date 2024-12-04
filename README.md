# Swift Ads Package

## Installation

### GitHub

1. Go to Project Settings -> General -> Frameworks, Libraries, and Embedded Content:

2. Click on the + button and select Add Other... -> Add Package Dependency...:

3. On the search bar, type the URL of this repository:

    ```shell
    https://github.com/CleverAdvertising/swift-ads-package.git
    ```
    


### CocoaPods

1. Add the following line to your `Podfile`:

    ```ruby
    pod 'swift-ads-package', '~> 1.0.8'
    ```

2. Run the following command to install the Swift Ads Package:

    ```shell
    pod install
    ```
## Usage with SwiftUI

1. Create a file named AdsWebView.swift

2. Insert the following code

```swift
import Foundation
import SwiftUI
import WebKit
import swift_ads_package
import Combine

struct AdsWebView: UIViewRepresentable {
    let scriptId: Int
    let onError: (() -> Void)?
    let alternative: (() -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let webView = SwiftAdsPackage(
            frame: .zero,
            configuration: WKWebViewConfiguration(),
            scriptId: scriptId,
            onError: {
                onError?() 
            },
            alternative: {
                alternative?() 
            }
        )
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Handle updates if necessary
    }
}
```

3. Add the following code anywhere in your project to display the ad

```swift
    AdsWebView(
        scriptId: script id here, 
        onError: {
            print("onError do something")
        },
        alternative: {
            print("alternative do something")
        }
    ).frame(width: 320, height: 50)
```

## Usage with UIKit

1. Create a file named AdsWebViewController.swift

2. Insert the following code

```swift
import UIKit
import WebKit
import swift_ads_package

class AdsWebViewController: UIViewController {

    var scriptId: Int
    var webViewWidth: CGFloat
    var webViewHeight: CGFloat
    var onError: (() -> Void)?
    var alternative: (() -> Void)?

    init(scriptId: Int, width: CGFloat, height: CGFloat, onError: (() -> Void)?, alternative: (() -> Void)?) {
        self.scriptId = scriptId
        self.webViewWidth = width
        self.webViewHeight = height
        self.onError = onError
        self.alternative = alternative
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let webView = SwiftAdsPackage(
            frame: .zero, 
            configuration: WKWebViewConfiguration(), 
            scriptId: scriptId, 
            onError: { 
                [weak self] in
                self?.onError?()
            }, 
            alternative: { 
                [weak self] in
                self?.alternative?()
            }
        )

        // Adjusting the frame to the specified dimensions
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        // Configuring constraints for the WebView layout
        NSLayoutConstraint.activate([
            webView.widthAnchor.constraint(equalToConstant: webViewWidth),
            webView.heightAnchor.constraint(equalToConstant: webViewHeight),
            webView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            webView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

```

3. Add the following code in your SceneDelegate project to display the ad

```swift
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Manually initialize the UIViewController
        let window = UIWindow(windowScene: windowScene)
        let adsWebViewController = AdsWebViewController(
            scriptId: script id here,    
            width: 320, 
            height: 350, 
            onError: {
                print("onError do something")
            },
            alternative: {
                print("alternative do something")
            })
        window.rootViewController = adsWebViewController
        window.makeKeyAndVisible()

        self.window = window
    }
}

```
