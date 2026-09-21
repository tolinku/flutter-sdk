#
# Tolinku Flutter SDK, iOS side.
#
# This exists only to report the device signals Dart cannot express in the form
# deferred link matching compares against. There is no iOS equivalent of the Play
# Install Referrer, so signal matching is the whole mechanism on this platform.
#
Pod::Spec.new do |s|
  s.name             = 'tolinku'
  s.version          = '0.6.2'
  s.summary          = 'Tolinku SDK for deep linking, analytics, referrals, and in-app messages.'
  s.description      = <<-DESC
Reports the timezone and OS version used to match a deferred deep link back to
the click that caused the install.
                       DESC
  s.homepage         = 'https://tolinku.com'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Tolinku' => 'support@tolinku.com' }
  # Never fetched. A Flutter plugin is resolved from the local pub cache, and
  # Flutter's podhelper points CocoaPods at that directory, so this attribute
  # exists only to name where the source lives. `:path => '.'` failed
  # `pod lib lint`, which requires one of git, hg, http or svn, which is why
  # every plugin in flutter/packages names its repository here instead.
  s.source           = { :http => 'https://github.com/tolinku/flutter-sdk/tree/main/ios' }
  s.documentation_url = 'https://pub.dev/packages/tolinku'
  # Shared with tolinku/Package.swift, which builds the same files for apps on
  # Swift Package Manager. The sources moved under tolinku/Sources so the Swift
  # package could see them: a package cannot reference files outside its own
  # directory. If this path and the files ever part company, every CocoaPods
  # build gets an empty pod rather than an error, so test/ios_package_test.dart
  # checks that this glob still matches something.
  s.source_files     = 'tolinku/Sources/tolinku/**/*.swift'
  # The same privacy manifest Package.swift processes, reaching CocoaPods apps
  # the way a pod ships a resource. One file, two build systems.
  s.resource_bundles = { 'tolinku_privacy' => ['tolinku/Sources/tolinku/PrivacyInfo.xcprivacy'] }
  # Lets a Swift static library pod find the Swift runtime when the host app
  # target is not itself Swift. Every pure Swift plugin in flutter/packages
  # carries this; the Objective-C ones do not, so it tracks the language rather
  # than the plugin. CocoaPods only: Swift Package Manager builds are unaffected.
  s.xcconfig = {
    'LIBRARY_SEARCH_PATHS' => '$(TOOLCHAIN_DIR)/usr/lib/swift/$(PLATFORM_NAME)/ $(SDKROOT)/usr/lib/swift',
    'LD_RUNPATH_SEARCH_PATHS' => '/usr/lib/swift',
  }
  # Stays. Plugins are expected to support both dependency managers until
  # CocoaPods is gone, and every flutter/packages plugin still declares it.
  s.dependency 'Flutter'
  # Flutter's own floor. See the note in tolinku/Package.swift.
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
