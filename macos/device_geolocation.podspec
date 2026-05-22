#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint device_geolocation.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'device_geolocation'
  s.version          = '1.0.0'
  s.summary          = 'Cross-platform geolocation plugin for Flutter.'
  s.description      = <<-DESC
A cross-platform Flutter geolocation plugin that provides easy access to platform
specific location services.
                       DESC
  s.homepage         = 'https://github.com/arcas0803/device_geolocation'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'device_geolocation contributors' => 'noreply@example.com' }

  s.source           = { :path => '.' }
  s.source_files = 'device_geolocation/Sources/device_geolocation/**/*'

  s.resource_bundles = {
    'device_geolocation_privacy' => ['device_geolocation/Sources/device_geolocation/PrivacyInfo.xcprivacy']
  }

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '11.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
end
