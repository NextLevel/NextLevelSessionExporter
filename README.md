
## NextLevelSessionExporter 🔄

`NextLevelSessionExporter` is an export and transcode media library for iOS written in [Swift](https://developer.apple.com/swift/).

[![Build Status](https://travis-ci.org/NextLevel/NextLevelSessionExporter.svg?branch=master)](https://travis-ci.org/NextLevel/NextLevelSessionExporter) [![Pod Version](https://img.shields.io/cocoapods/v/NextLevelSessionExporter.svg?style=flat)](http://cocoadocs.org/docsets/NextLevelSessionExporter/)

The library provides customizable audio and video encoding options unlike `AVAssetExportSession` and without having to learn the intricacies of AVFoundation. It was a port of [SDAVAssetExportSession](https://github.com/rs/SDAVAssetExportSession) with inspiration from [SCAssetExportSession](https://github.com/rFlex/SCRecorder/blob/master/Library/Sources/SCAssetExportSession.h) – which are great obj-c alternatives.

- Looking for a capture library? Check out [Next Level](https://github.com/NextLevel/NextLevel).
- Looking for a video player? Check out [Player](https://github.com/piemonte/player)

## Quick Start

```ruby

# CocoaPods

pod "NextLevelSessionExporter", "~> 0.0.1"

# Carthage

github "nextlevel/NextLevelSessionExporter" ~> 0.0.1

# Swift PM

let package = Package(
    dependencies: [
        .Package(url: "https://github.com/nextlevel/NextLevelSessionExporter", majorVersion: 0)
    ]
)

```

Alternatively, drop the [source files](https://github.com/NextLevel/NextLevelSessionExporter/tree/master/Sources) into your Xcode project.

## Example

``` Swift
let encoder = NextLevelSessionExporter(withAsset: asset)
encoder.delegate = self
encoder.outputFileType = AVFileTypeMPEG4
encoder.outputURL = URL(fileURLWithPath: NSHomeDirectory() + "video.mp4")
// add target configuration
//encoder.videoOutputConfiguration
//encoder.audioOutputConfiguration

do {
    try encoder.export(withCompletionHandler: { () in                
        switch encoder.status {
        case .completed:
            print("video export completed")
            break
        case .cancelled:
            print("video export cancelled")
            break
        default:
            break
        }
    })
} catch {
    print("failed to export")
}
```

## Community

- Found a bug? Open an [issue](https://github.com/NextLevel/NextLevelSessionExporter/issues).
- Feature idea? Open an [issue](https://github.com/NextLevel/NextLevelSessionExporter/issues).
- Want to contribute? Submit a [pull request](https://github.com/NextLevel/NextLevelSessionExporter/pulls).

## Resources

* [Swift Evolution](https://github.com/apple/swift-evolution)
* [AV Foundation Programming Guide](https://developer.apple.com/library/ios/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/00_Introduction.html)
* [AV Foundation Framework Reference](https://developer.apple.com/library/ios/documentation/AVFoundation/Reference/AVFoundationFramework/)
* [NextLevel](https://github.com/NextLevel/NextLevel), Rad Media Capture in Swift
* [GPUImage2](https://github.com/BradLarson/GPUImage2), image processing library in Swift
* [SDAVAssetExportSession](https://github.com/rs/SDAVAssetExportSession), media transcoding library in obj-c

## License

NextLevelSessionExporter is available under the MIT license, see the [LICENSE](https://github.com/NextLevel/NextLevelSessionExporter/blob/master/LICENSE) file for more information.
