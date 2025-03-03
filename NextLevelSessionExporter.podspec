Pod::Spec.new do |s|
  s.name = 'NextLevelSessionExporter'
  s.version = '0.4.5'
  s.license = 'MIT'
  s.summary = 'Export and transcode media in Swift'
  s.homepage = 'https://github.com/nextlevel/NextLevelSessionExporter'
  s.authors = { 'patrick piemonte' => 'patrick.piemonte@gmail.com' }
  s.source = { :git => 'https://github.com/nextlevel/NextLevelSessionExporter.git', :tag => s.version }
  s.ios.deployment_target = '13.0'
  s.source_files = 'Sources/*.swift'
  s.requires_arc = true
  s.swift_version = '5.0'
end
