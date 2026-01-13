
## NextLevelSessionExporter 🔄

`NextLevelSessionExporter` is an export and transcode media library for iOS written in [Swift](https://developer.apple.com/swift/).

[![Swift Version](https://img.shields.io/badge/language-swift%206.0-brightgreen.svg)](https://developer.apple.com/swift) [![Platform](https://img.shields.io/badge/platform-iOS%2015.0%2B-blue.svg)](https://developer.apple.com/ios/) [![SPM Compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://swift.org/package-manager/) [![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://github.com/NextLevel/NextLevelSessionExporter/blob/master/LICENSE)

The library provides customizable audio and video encoding options unlike `AVAssetExportSession` and without having to learn the intricacies of AVFoundation. It was a port of [SDAVAssetExportSession](https://github.com/rs/SDAVAssetExportSession) with inspiration from [SCAssetExportSession](https://github.com/rFlex/SCRecorder/blob/master/Library/Sources/SCAssetExportSession.h) – which are great obj-c alternatives.

### ✨ What's New in Swift 6

- **🚀 Modern Async/Await API** - Native Swift concurrency support with `async/await` and `AsyncSequence`
- **⚡ Better Performance** - Proper memory management with autoreleasepool in encoding loop
- **🎯 QoS Configuration** - Control export priority to prevent thread priority inversion (PR #44)
- **🔒 Swift 6 Strict Concurrency** - Full `Sendable` conformance and thread-safety
- **📝 Enhanced Error Messages** - Contextual error descriptions with recovery suggestions
- **♻️ Task Cancellation** - Proper cancellation support for modern Swift concurrency
- **🔙 Backwards Compatible** - Legacy completion handler API still works for iOS 13+

### Requirements

- **iOS 15.0+** for async/await APIs (iOS 13.0+ for legacy completion handler API)
- **Swift 6.0**
- **Xcode 16.0+**

### Related Projects

- Looking for a capture library? Check out [NextLevel](https://github.com/NextLevel/NextLevel).
- Looking for a video player? Check out [Player](https://github.com/piemonte/player)

## Quick Start

### Swift Package Manager (Recommended)

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nextlevel/NextLevelSessionExporter", from: "1.0.1")
]
```

Or add it directly in Xcode: **File → Add Package Dependencies...**

### CocoaPods

```ruby
pod "NextLevelSessionExporter", "~> 1.0.1"
```

### Manual Integration

Alternatively, drop the [source files](https://github.com/NextLevel/NextLevelSessionExporter/tree/master/Sources) into your Xcode project.

## Example

### Modern Async/Await API (iOS 15+)

The modern Swift 6 async/await API provides clean, cancellable exports with progress updates:

```Swift
let exporter = NextLevelSessionExporter(withAsset: asset)
exporter.outputFileType = .mp4

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

// Option 1: Simple async export with progress callback
do {
    let outputURL = try await exporter.export { progress in
        print("Progress: \(progress * 100)%")
    }
    print("Export completed: \(outputURL)")
} catch {
    print("Export failed: \(error)")
}

// Option 2: AsyncSequence for real-time progress updates
Task {
    do {
        for try await event in exporter.exportAsync() {
            switch event {
            case .progress(let progress):
                await MainActor.run {
                    progressBar.progress = progress
                }
            case .completed(let url):
                print("Export completed: \(url)")
            }
        }
    } catch {
        print("Export failed: \(error)")
    }
}
```

### Legacy Completion Handler API

For compatibility with older iOS versions, you can use the completion handler API.

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

## Migration Guide

### Migrating from 0.x to 1.0 (Swift 6)

The 1.0 release introduces Swift 6 with modern async/await APIs while maintaining full backward compatibility. Here's how to migrate:

#### Option 1: Adopt Modern Async/Await (Recommended)

**Before (0.x):**
```swift
exporter.export(progressHandler: { progress in
    print("Progress: \(progress)")
}, completionHandler: { result in
    switch result {
    case .success:
        print("Export completed")
    case .failure(let error):
        print("Export failed: \(error)")
    }
})
```

**After (1.0):**
```swift
do {
    let outputURL = try await exporter.export { progress in
        print("Progress: \(progress)")
    }
    print("Export completed: \(outputURL)")
} catch {
    print("Export failed: \(error)")
}
```

#### Option 2: Keep Using Completion Handlers

**No changes required!** The completion handler API works exactly the same. However, note that error cases now include descriptive messages:

```swift
// Errors now have helpful context
case .failure(let error):
    print(error.localizedDescription)  // e.g., "Failed to read media: Asset is corrupted"
    print(error.recoverySuggestion)    // e.g., "Verify the source asset is not corrupted"
```

#### Breaking Changes

None! The 1.0 release is fully backward compatible. New async/await APIs are additive.

#### Behavioral Changes

1. **Memory Management** - Fixed memory leak in long video exports (no code changes needed)
2. **Error Messages** - Errors now include contextual information and recovery suggestions
3. **Safety** - Removed force unwraps; fallback to safe defaults

## Features

### Custom Video Encoding

Unlike `AVAssetExportSession`, NextLevelSessionExporter gives you complete control over encoding parameters:

```swift
exporter.videoOutputConfiguration = [
    AVVideoCodecKey: AVVideoCodecType.hevc,  // H.265 for better compression
    AVVideoWidthKey: 1920,
    AVVideoHeightKey: 1080,
    AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 6_000_000,  // 6 Mbps
        AVVideoMaxKeyFrameIntervalKey: 30,     // Keyframe every 30 frames
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
    ]
]
```

### Custom Audio Encoding

Fine-tune audio settings for optimal file size and quality:

```swift
exporter.audioOutputConfiguration = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVEncoderBitRateKey: 128_000,      // 128 kbps
    AVNumberOfChannelsKey: 2,           // Stereo
    AVSampleRateKey: 44100              // 44.1 kHz
]
```

### Video Composition & Audio Mix

Apply complex video compositions and audio mixing:

```swift
// Custom video composition
let composition = AVMutableVideoComposition()
composition.instructions = [/* your instructions */]
exporter.videoComposition = composition

// Custom audio mix
let audioMix = AVMutableAudioMix()
audioMix.inputParameters = [/* your parameters */]
exporter.audioMix = audioMix
```

### Frame-by-Frame Processing

Process each video frame during export with a render handler:

```swift
exporter.export { renderFrame, presentationTime, resultBuffer in
    // Apply custom effects, filters, overlays, etc.
    // Process renderFrame and write to resultBuffer
    applyWatermark(to: resultBuffer)
} progress: { progress in
    print("Progress: \(progress)")
}
```

### Time Range Trimming

Export only a portion of the video:

```swift
let startTime = CMTime(seconds: 10, preferredTimescale: 600)
let endTime = CMTime(seconds: 30, preferredTimescale: 600)
exporter.timeRange = CMTimeRange(start: startTime, end: endTime)
```

### Metadata Support

Embed custom metadata in exported videos:

```swift
let metadata: [AVMetadataItem] = [
    createMetadataItem(key: .commonKeyTitle, value: "My Video"),
    createMetadataItem(key: .commonKeyDescription, value: "Exported with NextLevelSessionExporter"),
]
exporter.metadata = metadata
```

## Performance & Best Practices

### Quality of Service (QoS) Configuration

Control the priority of export operations to prevent thread priority inversion and optimize performance:

```swift
// High priority for user-initiated exports (default)
let exporter = NextLevelSessionExporter(withAsset: asset, qos: .userInitiated)

// Medium priority for background processing
let exporter = NextLevelSessionExporter(withAsset: asset, qos: .utility)

// Low priority for deferrable work
let exporter = NextLevelSessionExporter(withAsset: asset, qos: .background)
```

**When to use different QoS levels:**
- **`.userInitiated`** (default) - User tapped export, expects quick results
- **`.utility`** - Background export that can take longer
- **`.background`** - Batch processing, lowest priority

This resolves thread priority inversion warnings (Issues [#48](https://github.com/NextLevel/NextLevelSessionExporter/issues/48), [#41](https://github.com/NextLevel/NextLevelSessionExporter/issues/41)) and is especially important when calling from async/await contexts.

### Memory Management

The library automatically manages memory during export using autoreleasepool, preventing memory accumulation during long exports. This fix resolved [Issue #56](https://github.com/NextLevel/NextLevelSessionExporter/issues/56) where exports would crash after ~10 minutes.

### Task Cancellation

With the modern async API, exports are properly cancelled when the Task is cancelled:

```swift
let exportTask = Task {
    try await exporter.export()
}

// Cancel export
exportTask.cancel()  // Properly stops export and cleans up resources
```

### Progress Updates

For optimal UI responsiveness, update progress on the main actor:

```swift
for try await event in exporter.exportAsync() {
    switch event {
    case .progress(let progress):
        await MainActor.run {
            progressView.progress = progress
        }
    case .completed(let url):
        await handleCompletion(url)
    }
}
```

### Background Exports

For long exports, consider using background tasks:

```swift
let taskID = await UIApplication.shared.beginBackgroundTask()
defer { await UIApplication.shared.endBackgroundTask(taskID) }

try await exporter.export()
```

## Troubleshooting

### Export Fails with "Reading Failure"

**Problem:** Export fails when reading the source asset.

**Solutions:**
- Verify the source asset is not corrupted
- Check that the asset is a supported format (MP4, MOV, M4V, etc.)
- Ensure the asset is accessible and not protected by DRM

### Memory Issues on Long Videos

**Fixed in 1.0!** Previous versions had a memory leak causing crashes on videos longer than 10 minutes. Update to 1.0 or later.

### Export is Slow

**Tips:**
- Lower the video bitrate and resolution for faster exports
- Use H.264 instead of HEVC for better encoding speed
- Avoid frame-by-frame processing if not needed
- Test on a physical device (simulator performance varies)

### Video Orientation is Wrong

The library automatically handles video orientation and transforms. If you're experiencing issues:
- Let the library create the video composition automatically (don't set `videoComposition`)
- Ensure your video output configuration includes proper width/height

### Audio Track Missing

**Issue:** Some videos export without audio.

**Solution:** This was fixed in 1.0. The library now properly filters APAC audio tracks that cause export failures. Update to the latest version.

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
