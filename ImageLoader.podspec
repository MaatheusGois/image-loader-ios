Pod::Spec.new do |s|
  s.name = 'ImageLoader'
  s.version = '1.0.0'

  s.osx.deployment_target = '10.11'
  s.ios.deployment_target = '11.0'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'

  s.license = 'MIT'
  s.summary = 'Asynchronous image downloader with cache support with an UIImageView category.'
  s.homepage = 'https://github.com/maatheusgois/image-loader-ios'
  s.author = { 'Matheus Gois' => 'maatheusgois@icloud.com' }
  s.source = { :git => 'https://github.com/maatheusgois/image-loader-ios.git', :tag => s.version.to_s }

  s.description = 'This library provides a category for UIImageView with support for remote '      \
                  'images coming from the web. It provides an UIImageView category adding web '    \
                  'image and cache management to the Cocoa Touch framework, an asynchronous '      \
                  'image downloader, an asynchronous memory + disk image caching with automatic '  \
                  'cache expiration handling, a guarantee that the same URL won\'t be downloaded ' \
                  'several times, a guarantee that bogus URLs won\'t be retried again and again, ' \
                  'and performances!'

  s.requires_arc = true
  s.framework = 'ImageIO'
  
  s.default_subspec = 'Core'

  s.pod_target_xcconfig = {
    'SUPPORTS_MACCATALYST' => 'YES',
    'DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER' => 'NO'
  }

  s.subspec 'Core' do |core|
    core.source_files = 'ImageLoader/Core/*.{h,m}', 'WebImage/ImageLoader.h', 'ImageLoader/Private/*.{h,m}'
    core.private_header_files = 'ImageLoader/Private/*.h'
  end
end
