#
# Be sure to run `pod lib lint WriteFileSupportSpec.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'DDDownloaderManager'
  s.version          = '1.0.3'
  s.summary          = 'iOS 下载库'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/DDstrongman/DDDownloaderManager'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'DDStrongman' => 'lishengshu232@gmail.com' }
  s.source           = { :git => 'https://github.com/DDstrongman/DDDownloaderManager.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.source_files = 'DDDownloaderManager/Classes/**/*'
#s.frameworks = 'sys', 'arpa', 'Foundation', 'ifaddrs'

end
