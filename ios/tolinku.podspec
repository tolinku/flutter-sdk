#
# Tolinku Flutter SDK, iOS side.
#
# This exists only to report the device signals Dart cannot express in the form
# deferred link matching compares against. There is no iOS equivalent of the Play
# Install Referrer, so signal matching is the whole mechanism on this platform.
#
Pod::Spec.new do |s|
  s.name             = 'tolinku'
  s.version          = '0.4.1'
  s.summary          = 'Tolinku SDK for deep linking, analytics, referrals, and in-app messages.'
  s.description      = <<-DESC
Reports the timezone and OS version used to match a deferred deep link back to
the click that caused the install.
                       DESC
  s.homepage         = 'https://tolinku.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Tolinku' => 'support@tolinku.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
