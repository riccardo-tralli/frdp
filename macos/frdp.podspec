#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint frdp.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  freerdp_prefix = File.expand_path('.freerdp/install', __dir__)
  freerdp_deps_prefix = File.expand_path('.freerdp/deps/install', __dir__)
  freerdp_arch = ENV.fetch('FREERDP_ARCH', `uname -m`.to_s.strip)
  deployment_target = ENV.fetch('FRDP_MACOS_DEPLOYMENT_TARGET', '10.15')

  # Auto-detect missing architecture slice from the local FreeRDP dylib.
  has_arm64 = freerdp_arch.include?('arm64')
  has_x86_64 = freerdp_arch.include?('x86_64')

  if has_arm64 && !has_x86_64
    excluded_archs = 'x86_64'
  elsif has_x86_64 && !has_arm64
    excluded_archs = 'arm64'
  else
    excluded_archs = ''
  end

  include_flags = "-I#{freerdp_prefix}/include/freerdp3 -I#{freerdp_prefix}/include/winpr3"
  ld_flags = "-L#{freerdp_prefix}/lib -L#{freerdp_deps_prefix}/lib -Wl,-rpath,#{freerdp_prefix}/lib -Wl,-rpath,#{freerdp_deps_prefix}/lib -Wl,-force_load,#{freerdp_prefix}/lib/libfreerdp-client3.a -lfreerdp3 -lfreerdp-client3 -lwinpr3 -lssl -lcrypto -ljansson -lz -framework Carbon -framework AVFoundation -framework AudioToolbox -framework AudioUnit -framework CoreAudio"

  s.name             = 'frdp'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for Remote Desktop Protocol (RDP) connections'
  s.description      = 'A Flutter plugin for Remote Desktop Protocol (RDP) connections.'
  s.homepage         = 'https://github.com/riccardo-tralli/frdp'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Riccardo Tralli' => '' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'

  # Build and cache FreeRDP locally from the official repository so plugin
  # consumers do not need a system-wide FreeRDP installation.
  s.prepare_command = <<-CMD
    bash ./scripts/ensure_embedded_freerdp.sh
  CMD

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'frdp_privacy' => ['Resources/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, deployment_target
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_CPLUSPLUSFLAGS' => "$(inherited) #{include_flags}",
    'OTHER_LDFLAGS' => "$(inherited) #{ld_flags}",
    'HEADER_SEARCH_PATHS' => "$(inherited) #{freerdp_prefix}/include",
    'MACOSX_DEPLOYMENT_TARGET' => deployment_target,
    'EXCLUDED_ARCHS[sdk=macosx*]' => excluded_archs
  }
  s.user_target_xcconfig = {
    'MACOSX_DEPLOYMENT_TARGET' => deployment_target,
    'EXCLUDED_ARCHS[sdk=macosx*]' => excluded_archs
  }
  s.swift_version = '5.0'
end
