Pod::Spec.new do |spec|
  spec.name         = "Knock"
  spec.version      = "0.0.5"
  spec.summary      = "A short description of Knock."

  spec.description  = <<-DESC
  We have a fake version of the SDK
  We are using a sinonym for this reason in the name
  DESC

  spec.homepage     = "https://knock.app"
  spec.license      = { :type => 'MIT', :file => 'LICENSE.md' }
  spec.author             = { "Knock" => "faraday.timid_0g@icloud.com" }
  spec.source       = { :git => "git@github.com:ghecho/knock-swift.git", :tag => "#{spec.version}" }
  spec.ios.deployment_target = '16.0'
  spec.swift_version = '5.0'
  spec.source_files  = "Sources/**/*"
end
