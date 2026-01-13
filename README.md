
## NextLevelSessionExporter 🔄

`NextLevelSessionExporter` is an export and transcode media library for iOS written in [Swift](https://developer.apple.com/swift/).

[![Swift Version](https://img.shields.io/badge/language-swift%206.0-brightgreen.svg)](https://developer.apple.com/swift) [![Platform](https://img.shields.io/badge/platform-iOS%2015.0%2B-blue.svg)](https://developer.apple.com/ios/) [![SPM Compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://swift.org/package-manager/) [![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://github.com/NextLevel/NextLevelSessionExporter/blob/master/LICENSE)

The library provides customizable audio and video encoding options unlike `AVAssetExportSession` and without having to learn the intricacies of AVFoundation. It was a port of [SDAVAssetExportSession](https://github.com/rs/SDAVAssetExportSession) with inspiration from [SCAssetExportSession](https://github.com/rFlex/SCRecorder/blob/master/Library/Sources/SCAssetExportSession.h) – which are great obj-c alternatives.

### ✨ What's New in Swift 6

- **🚀 Modern Async/Await API** - Native Swift concurrency support with `async/await` and `AsyncSequence`
- **🌈 HDR Video Support** - Automatic detection and preservation of HLG and HDR10 content with 10-bit HEVC
- **⚡ Better Performance** - Proper memory management with autoreleasepool in encoding loop
- **🎯 QoS Configuration** - Control export priority to prevent thread priority inversion (PR #44)
- **🔒 Swift 6 Strict Concurrency** - Full `Sendable` conformance and thread-safety
- **📝 Enhanced Error Messages** - Contextual error descriptions with recovery suggestions
- **♻️ Task Cancellation** - Proper cancellation support for modern Swift concurrency
- **🛡️ Better Error Handling** - Fixed silent failures causing audio-only exports (#38)
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

### HDR Video Support

NextLevelSessionExporter automatically detects and preserves HDR content (HLG and HDR10) from source videos:

```swift
// Automatic HDR preservation (default behavior)
let exporter = NextLevelSessionExporter(withAsset: hdrAsset)
exporter.outputURL = outputURL
exporter.videoOutputConfiguration = [
    AVVideoWidthKey: 1920,
    AVVideoHeightKey: 1080
]
// HDR properties automatically detected and preserved ✨

let result = try await exporter.export()
// Output maintains HDR color space, transfer function, and 10-bit encoding
```

**Features:**
- **Automatic Detection**: Detects HLG (Hybrid Log-Gamma) and HDR10 (PQ) transfer functions
- **10-bit HEVC**: Automatically configures Main10 profile for 10-bit encoding
- **Color Properties**: Preserves ITU-R BT.2020 color primaries and YCbCr matrix
- **HDR Metadata**: Automatically inserts and preserves HDR metadata (iOS 14+)

#### Force SDR Output

To convert HDR to SDR, disable HDR preservation:

```swift
exporter.preserveHDR = false
// Output will be 8-bit SDR
```

#### Explicit HDR Configuration

Force HDR encoding even for SDR source, or override detected transfer function:

```swift
// Configure for HLG HDR
exporter.configureForHDR(transferFunction: .hlg)

// Or configure for HDR10 (PQ)
exporter.configureForHDR(transferFunction: .hdr10)

// Note: HEVC codec and appropriate dimensions required
exporter.videoOutputConfiguration = [
    AVVideoCodecKey: AVVideoCodecType.hevc,
    AVVideoWidthKey: 1920,
    AVVideoHeightKey: 1080
]
```

**Requirements:**
- iOS 15.0+ or macOS 12.0+
- HEVC (H.265) codec required for HDR
- Device must support 10-bit HEVC encoding

**Supported HDR Formats:**
- HLG (Hybrid Log-Gamma) - Broadcast standard, better for wide compatibility
- HDR10 (PQ/SMPTE ST 2084) - Consumer HDR standard with static metadata

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

### Working with Photos Library

When exporting videos from the user's photo library, copy the file to your app's directory first to avoid permission issues:

```swift
// ⚠️ NOT RECOMMENDED: Direct PHAsset access may cause cancelled errors
let phAsset = // ... from photo library
let avAsset = AVAsset(url: phAsset.url) // May fail!

// ✅ RECOMMENDED: Copy to app directory first
let tempURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("video.mov")

// Export PHAsset to temp file, then create AVAsset
let avAsset = AVAsset(url: tempURL)
let exporter = NextLevelSessionExporter(withAsset: avAsset)
```

See the [Troubleshooting section](#export-fails-with-cancelled-error-issue-37) for complete implementation.

## Troubleshooting

### Error -11819 "Cannot Complete Action" (iOS 14.5+)

**Problem:** Export fails with `AVFoundationErrorDomain Code=-11819 "Cannot Complete Action"`, especially on iOS 14.5.

**Cause:** This is an **iOS system-level bug** where media daemons crash during export operations. It's not a library issue but an Apple bug that affects `AVAssetReader`/`AVAssetWriter` operations.

**Solutions:**

1. **Implement Retry Logic** (recommended):
```swift
func exportWithRetry(maxAttempts: Int = 3) async throws -> URL {
    var lastError: Error?

    for attempt in 1...maxAttempts {
        do {
            let url = try await exporter.export()
            return url
        } catch let error as NSError where error.code == -11819 {
            lastError = error
            print("Attempt \(attempt) failed with -11819, retrying...")
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
            continue
        } catch {
            throw error // Other errors, don't retry
        }
    }

    throw lastError ?? NextLevelSessionExporterError.writingFailure("Export failed after \(maxAttempts) attempts")
}
```

2. **Reduce Complexity**: Lower resolution, bitrate, or remove video composition if using CoreAnimation tools

3. **Update iOS**: The issue is less frequent on iOS 15+

4. **Report to Apple**: File a Feedback Assistant report with sysdiagnose if this occurs frequently

**References:**
- [Apple Forums Thread](https://developer.apple.com/forums/thread/679862)
- [Radar: FB8815719](https://openradar.appspot.com/FB8815719)

### Export Fails with "Cancelled" Error (Issue #37)

**Problem:** Some videos fail to compress with a cancelled/canceled error message, especially when selecting videos directly from the photo library.

**Cause:** File access permissions or buffering issues when reading from certain storage locations.

**Solution:** Copy the video to your app's writable directory before exporting:

```swift
func exportVideoFromLibrary(asset: PHAsset) async throws -> URL {
    // 1. Export to temporary file first
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("mov")

    // 2. Request video resource from Photos library
    let options = PHVideoRequestOptions()
    options.version = .current
    options.deliveryMode = .highQualityFormat

    try await withCheckedThrowingContinuation { continuation in
        PHImageManager.default().requestExportSession(
            forVideo: asset,
            options: options,
            exportPreset: AVAssetExportPresetPassthrough
        ) { exportSession, _ in
            guard let session = exportSession else {
                continuation.resume(throwing: NSError(domain: "Export", code: -1))
                return
            }

            session.outputURL = tempURL
            session.outputFileType = .mov
            session.exportAsynchronously {
                if session.status == .completed {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: session.error ?? NSError(domain: "Export", code: -1))
                }
            }
        }
    }

    // 3. Now export with NextLevelSessionExporter
    let avAsset = AVAsset(url: tempURL)
    let exporter = NextLevelSessionExporter(withAsset: avAsset)

    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("mp4")

    exporter.outputURL = outputURL
    exporter.videoOutputConfiguration = [/* your config */]
    exporter.audioOutputConfiguration = [/* your config */]

    let result = try await exporter.export()

    // 4. Clean up temp file
    try? FileManager.default.removeItem(at: tempURL)

    return result
}
```

**Alternative (simpler):** Use `AVAsset(url:)` with a file URL rather than `PHAsset` directly:

```swift
// Copy to caches directory first
let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("video.mov")

// ... copy file to cacheURL ...

let asset = AVAsset(url: cacheURL)
let exporter = NextLevelSessionExporter(withAsset: asset)
```

### Export Fails with "Reading Failure"

**Problem:** Export fails when reading the source asset.

**Solutions:**
- Verify the source asset is not corrupted
- Check that the asset is a supported format (MP4, MOV, M4V, etc.)
- Ensure the asset is accessible and not protected by DRM
- If reading from Photos library, see "Cancelled Error" above

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
