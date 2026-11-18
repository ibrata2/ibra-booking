Pod::Spec.new do |s|
  s.name             = 'ibra_native'
  s.version          = '1.0.0'
  s.summary          = 'IBRA BOOKING native integrations'
  s.description      = 'Audio conversion/trimming for notification sounds, preview playback and time zone.'
  s.homepage         = 'https://ibraprogram.netlify.app/'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'IBRA' => 'ibraprogram' }
  s.source           = { :path => '.' }
  s.source_files     = 'ibra_native/Sources/ibra_native/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.frameworks       = 'AVFoundation', 'UserNotifications'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
