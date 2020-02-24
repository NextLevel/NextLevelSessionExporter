
## NextLevelSessionExporter 🔄

`NextLevelSessionExporter` is an export and transcode media library for iOS written in [Swift](https://developer.apple.com/swift/).

[![Build Status](https://travis-ci.org/NextLevel/NextLevelSessionExporter.svg?branch=master)](https://travis-ci.org/NextLevel/NextLevelSessionExporter) [![Pod Version](https://img.shields.io/cocoapods/v/NextLevelSessionExporter.svg?style=flat)](http://cocoadocs.org/docsets/NextLevelSessionExporter/) [![Swift Version](https://img.shields.io/badge/language-swift%205.0-brightgreen.svg)](https://developer.apple.com/swift) [![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://github.com/NextLevel/NextLevelSessionExporter/blob/master/LICENSE)

The library provides customizable audio and video encoding options unlike `AVAssetExportSession` and without having to learn the intricacies of AVFoundation. It was a port of [SDAVAssetExportSession](https://github.com/rs/SDAVAssetExportSession) with inspiration from [SCAssetExportSession](https://github.com/rFlex/SCRecorder/blob/master/Library/Sources/SCAssetExportSession.h) – which are great obj-c alternatives.

- Looking for a capture library? Check out [NextLevel](https://github.com/NextLevel/NextLevel).
- Looking for a video player? Check out [Player](https://github.com/piemonte/player)

Need a different version of Swift?
* `5.0` - Target your Podfile to the latest release or master
* `4.2` - Target your Podfile to the `swift4.2` branch
* `4.0` - Target your Podfile to the `swift4.0` branch

## Quick Start

```ruby

# CocoaPods

pod "NextLevelSessionExporter", "~> 0.4.5"

# Carthage

github "nextlevel/NextLevelSessionExporter" ~> 0.4.5

# Swift PM

let package = Package(
    dependencies: [
        .Package(url: "https://github.com/nextlevel/NextLevelSessionExporter", majorVersion: 0)
    ]
)

```

Alternatively, drop the [source files](https://github.com/NextLevel/NextLevelSessionExporter/tree/master/Sources) into your Xcode project.

## Example

Simply use the `AVAsset` extension or create and use an instance of `NextLevelSessionExporter` directly.

```Swift
let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    .appendingPathComponent(ProcessInfo().globallyUniqueString)
    .appendingPathExtension("mp4")
exporter.outputURL = tmpURL

let compressionDict: [String: Any] = [
    AVVideoAverageBitRateKey: NSNumber(integerLiteral: 6000000),
    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel as String,
]
let videoOutputConfig = [
    AVVideoCodecKey: AVVideoCodec.h264,
    AVVideoWidthKey: NSNumber(integerLiteral: 1920),
    AVVideoHeightKey: NSNumber(integerLiteral: 1080),
    AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
    AVVideoCompressionPropertiesKey: compressionDict
]
let audioOutputConfig = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVEncoderBitRateKey: NSNumber(integerLiteral: 128000),
    AVNumberOfChannelsKey: NSNumber(integerLiteral: 2),
    AVSampleRateKey: NSNumber(value: Float(44100))
]

let asset = AVAsset(url: Bundle.main.url(forResource: "TestVideo", withExtension: "mov")!)
asset.nextlevel_export(outputURL: tmpURL, videoOutputConfiguration: videoOutputConfig, audioOutputConfiguration: audioOutputConfig)
```

Alternatively, you can use `NextLevelSessionExporter` directly.

``` Swift
let exporter = NextLevelSessionExporter(withAsset: asset)
exporter.outputFileType = AVFileType.mp4
let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    .appendingPathComponent(ProcessInfo().globallyUniqueString)
    .appendingPathExtension("mp4")
exporter.outputURL = tmpURL

let compressionDict: [String: Any] = [
    AVVideoAverageBitRateKey: NSNumber(integerLiteral: 6000000),
    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel as String,
]
exporter.videoOutputConfiguration = [
    AVVideoCodecKey: AVVideoCodec.h264,
    AVVideoWidthKey: NSNumber(integerLiteral: 1920),
    AVVideoHeightKey: NSNumber(integerLiteral: 1080),
    AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
    AVVideoCompressionPropertiesKey: compressionDict
]
exporter.audioOutputConfiguration = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVEncoderBitRateKey: NSNumber(integerLiteral: 128000),
    AVNumberOfChannelsKey: NSNumber(integerLiteral: 2),
    AVSampleRateKey: NSNumber(value: Float(44100))
]

exporter.export(progressHandler: { (progress) in
    print(progress)
}, completionHandler: { result in
    switch result {
    case .success(let status):
        switch status {
        case .completed:
            print("NextLevelSessionExporter, export completed, \(exporter.outputURL?.description ?? "")")
            break
        default:
            print("NextLevelSessionExporter, did not complete")
            break
        }
        break
    case .failure(let error):
        print("NextLevelSessionExporter, failed to export \(error)")
        break
    }
})
```

## Documentation

You can find [the docs here](https://nextlevel.github.io/NextLevelSessionExporter). Documentation is generated with [jazzy](https://github.com/realm/jazzy) and hosted on [GitHub-Pages](https://pages.github.com).

## Community

- Found a bug? Open an [issue](https://github.com/NextLevel/NextLevelSessionExporter/issues).
- Feature idea? Open an [issue](https://github.com/NextLevel/NextLevelSessionExporter/issues).
- Want to contribute? Submit a [pull request](https://github.com/NextLevel/NextLevelSessionExporter/pulls).

## Resources

* [AV Foundation Programming Guide](https://developer.apple.com/library/ios/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/00_Introduction.html)
* [AV Foundation Framework Reference](https://developer.apple.com/library/ios/documentation/AVFoundation/Reference/AVFoundationFramework/)
* [NextLevel](https://github.com/NextLevel/NextLevel), Rad Media Capture in Swift
* [GPUImage2](https://github.com/BradLarson/GPUImage2), image processing library in Swift
* [SDAVAssetExportSession](https://github.com/rs/SDAVAssetExportSession), media transcoding library in obj-c

## License

`NextLevelSessionExporter` is available under the MIT license, see the [LICENSE](https://github.com/NextLevel/NextLevelSessionExporter/blob/master/LICENSE) file for more information.
