#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint frdp.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  freerdp_prefix = ENV['FREERDP_PREFIX']
  if freerdp_prefix.nil? || freerdp_prefix.empty?
    freerdp_prefix = '/opt/homebrew/opt/freerdp'
  end

  include_flags = "-I#{freerdp_prefix}/include/freerdp3 -I#{freerdp_prefix}/include/winpr3"
  ld_flags = "-L#{freerdp_prefix}/lib -Wl,-rpath,#{freerdp_prefix}/lib -lfreerdp3 -lfreerdp-client3 -lwinpr3"

  s.name             = 'frdp'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for RDP connections'
  s.description      = 'A Flutter plugin for RDP connections.'
  s.homepage         = 'https://github.com/riccardo-tralli/frdp'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Riccardo Tralli' => '' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'frdp_privacy' => ['Resources/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_CPLUSPLUSFLAGS' => "$(inherited) #{include_flags}",
    'OTHER_LDFLAGS' => "$(inherited) #{ld_flags}",
    'HEADER_SEARCH_PATHS' => "$(inherited) #{freerdp_prefix}/include",
    'EXCLUDED_ARCHS[sdk=macosx*]' => 'x86_64'
  }
  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=macosx*]' => 'x86_64'
  }
  s.swift_version = '5.0'
end
