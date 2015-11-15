#
# Be sure to run `pod lib lint BXCodeScanner.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "BXCodeScanner"
  s.version          = "0.1.0"
  s.summary          = " BXCodeScanner is QRCode and BarCode Scanner,and A Simple Example Picture Capture"

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      = <<-DESC
                        BXCodeScanner 是一个简单的扫码工具类，支持自定义扫描区域，自定义要扫描的编码类型，
                        同时有一个支持简单的适用于凭证拍照的 ViewController。
                       DESC

  s.homepage         = "https://github.com/banxi1988/BXCodeScanner"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "banxi1988" => "banxi1988@gmail.com" }
  s.source           = { :git => "https://github.com/banxi1988/BXCodeScanner.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/banxi198'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'BXCodeScanner' => ['Pod/Assets/*.png','Pod/Assets/*.mp3']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
    s.dependency 'PinAutoLayout'
end
