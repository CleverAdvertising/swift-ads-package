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
## Usage

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

    func makeUIView(context: Context) -> WKWebView {
        let webView = SwiftAdsPackage(frame: .zero, configuration: WKWebViewConfiguration(), scriptId: scriptId)
        
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Handle updates if necessary
    }
}
```

3. Add the following code anywhere in your project to display the ad

```swift
    AdsWebView(scriptId: script id here).frame(width: 320, height: 50)
```
