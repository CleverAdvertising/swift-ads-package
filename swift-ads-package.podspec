
Pod::Spec.new do |spec|

  spec.name         = "swift-ads-package"
  spec.version      = "1.0.8"
  spec.summary      = "A short description of swift-ads-package."
  spec.description  = "Library for displaying ads in Swift."
  spec.homepage     = "https://cleveradvertising.com"
  spec.license      = "MIT"
  spec.author       = { "CleverAdvertising" => "development@cleveradvertising.com" }
  spec.source       = { :git => "https://github.com/CleverAdvertising/swift-ads-package.git", :tag => "#{spec.version}" }
  spec.ios.deployment_target = '13.0'
  spec.osx.deployment_target = '10.15'
  spec.source_files = 'Sources/**/*.{swift}'

  spec.frameworks =  'WebKit'
  spec.swift_version = '5.0'
end
