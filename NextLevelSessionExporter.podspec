Pod::Spec.new do |s|
  s.name = 'NextLevelSessionExporter'
  s.version = '0.0.1'
  s.license = 'MIT'
  s.summary = 'Export and transcode media in Swift'
  s.homepage = 'https://github.com/nextlevel/NextLevelSessionExporter'
  s.authors = { 'patrick piemonte' => 'piemonte@alumni.cmu.edu' }
  s.source = { :git => 'https://github.com/nextlevel/NextLevelSessionExporter.git', :tag => s.version }
  s.ios.deployment_target = '10.0'
  s.source_files = 'Sources/*.swift'
  s.requires_arc = true
end
