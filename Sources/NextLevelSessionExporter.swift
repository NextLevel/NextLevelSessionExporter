//
//  NextLevelSessionExporter.swift
//  NextLevelSessionExporter (http://nextlevel.engineering/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation
import AVFoundation

// MARK: - types

/// Session export errors.
public enum NextLevelSessionExporterError: Error, CustomStringConvertible {
    case setupFailure
    
    public var description: String {
        switch self {
        case .setupFailure:
            return "Setup failure"
        }
    }
    
}

// MARK: - NextLevelSessionExporter

private let NextLevelSessionExporterInputQueue = "NextLevelSessionExporterInputQueue"

/// 🔄 NextLevelSessionExporter, export and transcode media in Swift
public class NextLevelSessionExporter: NSObject {
    
    /// Input asset for export, provided when initialized.
    public let asset: AVAsset
    
    /// Enables video composition and parameters for the session.
    public var videoComposition: AVVideoComposition?
    
    /// Enables audio mixing and parameters for the session.
    public var audioMix: AVAudioMix?
    
    /// Output file location for the session.
    public var outputURL: URL?
    
    /// Output file type. UTI string defined in `AVMediaFormat.h`.
    public var outputFileType: AVFileType? = AVFileType.mp4
    
    /// Time range or limit of an export from `kCMTimeZero` to `kCMTimePositiveInfinity`
    public var timeRange: CMTimeRange
    
    /// Indicates if an export session should expect media data in real time.
    public var expectsMediaDataInRealTime = false
    
    /// Indicates if an export should be optimized for network use.
    public var optimizeForNetworkUse = false
    
    /// Metadata to be added to an export.
    public var metadata: [AVMetadataItem]?
    
    /// Video input configuration dictionary, using keys defined in `<CoreVideo/CVPixelBuffer.h>`
    public var videoInputConfiguration: [String : Any]?
    
    /// Video output configuration dictionary, using keys defined in `<AVFoundation/AVVideoSettings.h>`
    public var videoOutputConfiguration: [String : Any]?
    
    /// Audio output configuration dictionary, using keys defined in `<AVFoundation/AVAudioSettings.h>`
    public var audioOutputConfiguration: [String : Any]?
    
    /// Export session status state.
    public var status: AVAssetExportSession.Status {
        if let writer = _writer {
            switch writer.status {
            case .writing:
                return .exporting
            case .failed:
                return .failed
            case .completed:
                return .completed
            case.cancelled:
                return .cancelled
            case .unknown:
                break
            }
        }
        return .unknown
    }
    
    /// Session exporting progress from 0 to 1.
    public var progress: Float {
        return _progress
    }
    
    // private instance vars
    
    internal var _writer: AVAssetWriter!
    internal var _reader: AVAssetReader!
    internal var _pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    internal let _inputQueue = DispatchQueue(label: NextLevelSessionExporterInputQueue, autoreleaseFrequency: .workItem, target: .global())
    
    internal var _videoOutput: AVAssetReaderVideoCompositionOutput?
    internal var _audioOutput: AVAssetReaderAudioMixOutput?
    internal var _videoInput: AVAssetWriterInput?
    internal var _audioInput: AVAssetWriterInput?
    
    internal var _progress: Float = 0
    
    internal var _progressHandler: ProgressHandler?
    internal var _renderHandler: RenderHandler?
    internal var _completionHandler: CompletionHandler?
    
    internal var _duration: TimeInterval = 0
    internal var _lastSamplePresentationTime = CMTime.invalid
    
    // MARK: - object lifecycle
    
    /// Initializes a session with an asset to export.
    
    public init(withAsset asset: AVAsset) {
        self.asset = asset
        timeRange = CMTimeRange(start: .zero, end: .positiveInfinity)
        super.init()
    }
    
}

// MARK: - export

extension NextLevelSessionExporter {
    
    /// Completion handler type for when an export finishes.
    public typealias CompletionHandler = (_ status: AVAssetExportSession.Status, _ error: Error?) -> Void
    
    /// Progress handler type
    public typealias ProgressHandler = (_ progress: Float) -> Void
    
    /// Render handler type for frame processing
    public typealias RenderHandler = (_ renderFrame: CVPixelBuffer, _ presentationTime: CMTime, _ resultingBuffer: CVPixelBuffer) -> Void
    
    /// Initiates an export session.
    ///
    /// - Parameter completionHandler: Handler called when an export session completes.
    /// - Throws: Failure indication thrown when an error has occurred during export.
    public func export(renderHandler: RenderHandler? = nil, progressHandler: ProgressHandler? = nil, completionHandler: CompletionHandler? = nil) throws {
        cancelExport()
        
        _progressHandler = progressHandler
        _renderHandler = renderHandler
        _completionHandler = completionHandler
        
        guard let outputURL = outputURL, let outputFileType = outputFileType else {
            throw NextLevelSessionExporterError.setupFailure
        }
        
        do {
            _reader = try AVAssetReader(asset: asset)
        } catch {
            print("NextLevelSessionExporter, could not setup a reader for the provided asset \(asset)")
            debugPrint("Error", error)
            throw error
        }
        
        do {
            _writer = try AVAssetWriter(outputURL: outputURL, fileType: outputFileType)
        } catch {
            print("NextLevelSessionExporter, could not setup a writer for the provided asset \(asset)")
            debugPrint("Error", error)
            throw error
        }
        
        if validateVideoOutputConfiguration() == false {
            print("NextLevelSessionExporter, could not setup with the specified video output configuration")
            throw NextLevelSessionExporterError.setupFailure
        }
        
        _reader.timeRange = timeRange
        _writer.shouldOptimizeForNetworkUse = optimizeForNetworkUse
        
        if let metadata = metadata {
            _writer.metadata = metadata
        }
        
        if timeRange.duration.isValid && timeRange.duration.isPositiveInfinity == false {
            _duration = CMTimeGetSeconds(timeRange.duration)
        } else {
            _duration = CMTimeGetSeconds(asset.duration)
        }
        
        if videoOutputConfiguration?.keys.contains(AVVideoCodecKey) == false {
            print("NextLevelSessionExporter, warning a video output configuration codec wasn't specified")
            if #available(iOS 11.0, *) {
                videoOutputConfiguration?[AVVideoCodecKey] = AVVideoCodecType.h264
            } else {
                videoOutputConfiguration?[AVVideoCodecKey] = AVVideoCodecH264
            }
        }
        
        setupVideoOutput(asset)
        setupAudioOutput(asset)
        setupAudioInput()
        
        // export
        export(asset)
    }
    
    private func setupVideoOutput(_ asset: AVAsset) {
        let videoTracks = asset.tracks(withMediaType: .video)
        guard videoTracks.count > 0 else {
            _videoOutput = nil
            return
        }
        _videoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: videoTracks, videoSettings: videoInputConfiguration)
        _videoOutput?.alwaysCopiesSampleData = false
        
        if let videoComposition = videoComposition {
            _videoOutput?.videoComposition = videoComposition
        } else {
            _videoOutput?.videoComposition = createVideoComposition()
        }
        
        if let videoOutput = _videoOutput, let reader = _reader, reader.canAdd(videoOutput) {
            reader.add(videoOutput)
        }
        
        // video input
        if _writer?.canApply(outputSettings: videoOutputConfiguration, forMediaType: .video) == true {
            _videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoOutputConfiguration)
            _videoInput?.expectsMediaDataInRealTime = expectsMediaDataInRealTime
        } else {
            fatalError("Unsupported output configuration")
        }
        
        if let writer = _writer, let videoInput = _videoInput {
            if writer.canAdd(videoInput) {
                writer.add(videoInput)
            }
            
            // setup pixelbuffer adaptor
            
            var pixelBufferAttrib: [String : Any] = [:]
            pixelBufferAttrib[kCVPixelBufferPixelFormatTypeKey as String] = NSNumber(value: Int(kCVPixelFormatType_32RGBA))
            if let videoComposition = _videoOutput?.videoComposition {
                pixelBufferAttrib[kCVPixelBufferWidthKey as String] = NSNumber(value: Int(videoComposition.renderSize.width))
                pixelBufferAttrib[kCVPixelBufferHeightKey as String] = NSNumber(value: Int(videoComposition.renderSize.height))
            }
            pixelBufferAttrib["IOSurfaceOpenGLESTextureCompatibility"] = NSNumber(value:  true)
            pixelBufferAttrib["IOSurfaceOpenGLESFBOCompatibility"] = NSNumber(value: true)
            
            _pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: pixelBufferAttrib)
        }
    }
    
    private func setupAudioOutput(_ asset: AVAsset) {
        let audioTracks = asset.tracks(withMediaType: .audio)
        guard audioTracks.count > 0 else {
            _audioOutput = nil
            return
        }
        _audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
        _audioOutput?.alwaysCopiesSampleData = false
        _audioOutput?.audioMix = audioMix
        if let reader = _reader, let audioOutput = _audioOutput, reader.canAdd(audioOutput) {
            reader.add(audioOutput)
        }
    }
    
    private func setupAudioInput() {
        if _audioOutput != nil {
            _audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputConfiguration)
            _audioInput?.expectsMediaDataInRealTime = expectsMediaDataInRealTime
            if let writer = _writer, let audioInput = _audioInput, writer.canAdd(audioInput) {
                writer.add(audioInput)
            }
        }
    }
    
    private func export(_ asset: AVAsset) {
        _writer?.startWriting()
        _reader?.startReading()
        _writer?.startSession(atSourceTime: timeRange.start)
        
        let audioSemaphore = DispatchSemaphore(value: 0)
        let videoSemaphore = DispatchSemaphore(value: 0)
        
        let videoTracks = asset.tracks(withMediaType: .video)
        if let videoInput = _videoInput, let videoOutput = _videoOutput, videoTracks.count > 0 {
            videoInput.requestMediaDataWhenReady(on: _inputQueue, using: {
                if self.encode(readySamplesFromReaderOutput: videoOutput, toWriterInput: videoInput) == false {
                    videoSemaphore.signal()
                }
            })
        } else {
            videoSemaphore.signal()
        }
        
        if let audioInput = _audioInput, let audioOutput = _audioOutput {
            audioInput.requestMediaDataWhenReady(on: _inputQueue, using: {
                if self.encode(readySamplesFromReaderOutput: audioOutput, toWriterInput: audioInput) == false {
                    audioSemaphore.signal()
                }
            })
        } else {
            audioSemaphore.signal()
        }
        
        DispatchQueue.global().async {
            audioSemaphore.wait()
            videoSemaphore.wait()
            DispatchQueue.main.sync {
                self.finish()
            }
        }
    }
    
    /// Cancels any export in progress.
    public func cancelExport() {
        _inputQueue.sync {
            if self._writer?.status == .writing {
                self._writer?.cancelWriting()
            }
            
            if self._reader?.status == .reading {
                self._reader?.cancelReading()
            }
            
            self.complete()
            self.reset()
        }
    }
    
}

// MARK: - internal funcs

extension NextLevelSessionExporter {
    
    // called on the inputQueue
    internal func encode(readySamplesFromReaderOutput output: AVAssetReaderOutput, toWriterInput input: AVAssetWriterInput) -> Bool {
        while input.isReadyForMoreMediaData {
            if let sampleBuffer = output.copyNextSampleBuffer() {
                var handled = false
                var error = false
                
                if _reader?.status != .reading || _writer?.status != .writing {
                    handled = true
                    error = true
                }
                
                if handled == false && _videoOutput == output {
                    // determine progress
                    _lastSamplePresentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) - timeRange.start
                    let progress = _duration == 0 ? 1 : Float(CMTimeGetSeconds(_lastSamplePresentationTime) / _duration)
                    updateProgress(progress: progress)
                    
                    // prepare progress frames
                    if let pixelBufferAdaptor = _pixelBufferAdaptor,
                        let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool,
                        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        
                        var toRenderBuffer: CVPixelBuffer?
                        let result = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &toRenderBuffer)
                        if result == kCVReturnSuccess {
                            if let toBuffer = toRenderBuffer {
                                _renderHandler?(pixelBuffer, _lastSamplePresentationTime, toBuffer)
                                if pixelBufferAdaptor.append(toBuffer, withPresentationTime:_lastSamplePresentationTime) == false {
                                    error = true
                                }
                                handled = true
                            }
                        }
                    }
                }
                
                if handled == false && input.append(sampleBuffer) == false {
                    error = true
                }
                
                if error {
                    return false
                }
            } else {
                input.markAsFinished()
                return false
            }
        }
        return true
    }
    
    internal func createVideoComposition() -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        guard let videoTrack = asset.tracks(withMediaType: .video).first else { return videoComposition
        }
        
        // determine the framerate
        
        var frameRate: Float = 0
        if let videoConfiguration = videoOutputConfiguration {
            if let videoCompressionConfiguration = videoConfiguration[AVVideoCompressionPropertiesKey] as? [String: Any] {
                if let trackFrameRate = videoCompressionConfiguration[AVVideoAverageNonDroppableFrameRateKey] as? NSNumber {
                    frameRate = trackFrameRate.floatValue
                }
            }
        } else {
            frameRate = videoTrack.nominalFrameRate
        }
        
        if frameRate == 0 {
            frameRate = 30
        }
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
        
        // determine the appropriate size and transform
        
        if let videoConfiguration = videoOutputConfiguration {
            let videoWidth = videoConfiguration[AVVideoWidthKey] as? NSNumber
            let videoHeight = videoConfiguration[AVVideoHeightKey] as? NSNumber
            
            // validated to be non-nil byt this point
            let width = videoWidth!.intValue
            let height = videoHeight!.intValue
            
            let targetSize = CGSize(width: width, height: height)
            var naturalSize = videoTrack.naturalSize
            
            var transform = videoTrack.preferredTransform
            
            let rect = CGRect(x: 0, y: 0, width: naturalSize.width, height: naturalSize.height)
            let transformedRect = rect.applying(transform)
            // transformedRect should have origin at 0 if correct; otherwise add offset to correct it
            transform.tx -= transformedRect.origin.x
            transform.ty -= transformedRect.origin.y
            
            let videoAngleInDegrees = atan2(transform.b, transform.a) * 180 / .pi
            if videoAngleInDegrees == 90 || videoAngleInDegrees == -90 {
                let tempWidth = naturalSize.width
                naturalSize.width = naturalSize.height
                naturalSize.height = tempWidth
            }
            videoComposition.renderSize = naturalSize
            
            // center the video
            
            var ratio: CGFloat = 0
            let xRatio = targetSize.width / naturalSize.width
            let yRatio = targetSize.height / naturalSize.height
            ratio = min(xRatio, yRatio)
            
            let postWidth = naturalSize.width * ratio
            let postHeight = naturalSize.height * ratio
            let transX = (targetSize.width - postWidth) * 0.5
            let transY = (targetSize.height - postHeight) * 0.5
            
            var matrix = CGAffineTransform(translationX: (transX / xRatio), y: (transY / yRatio))
            matrix = matrix.scaledBy(x: (ratio / xRatio), y: (ratio / yRatio))
            transform = transform.concatenating(matrix)
            
            // make the composition
            
            let compositionInstruction = AVMutableVideoCompositionInstruction()
            compositionInstruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            layerInstruction.setTransform(transform, at: .zero)
            
            compositionInstruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [compositionInstruction]
        }
        
        return videoComposition
    }
    
    internal func updateProgress(progress: Float) {
        willChangeValue(forKey: "progress")
        _progress = progress
        didChangeValue(forKey: "progress")
        _progressHandler?(progress)
    }
    
    internal func finish() {
        if _reader?.status == .cancelled || _writer?.status == .cancelled {
            return
        }
        
        if _writer?.status == .failed {
            if let error = _writer?.error {
                debugPrint("NextLevelSessionExporter, writing failed, \(error)")
            }
            complete()
        } else if _reader?.status == .failed {
            if let error = _writer?.error {
                debugPrint("NextLevelSessionExporter, reading failed, \(error)")
            }
            _writer?.cancelWriting()
            complete()
        } else {
            _writer?.finishWriting {
                self.complete()
            }
        }
    }
    
    internal func complete() {
        if _writer?.status == .failed || _writer?.status == .cancelled {
            if let outputURL = outputURL {
                if FileManager.default.fileExists(atPath: outputURL.absoluteString) {
                    do {
                        try FileManager.default.removeItem(at: outputURL)
                    } catch {
                        debugPrint("NextLevelSessionExporter, failed to delete file at \(outputURL)", error)
                    }
                }
            }
        }
        
        _completionHandler?(status, _writer?.error)
        _completionHandler = nil
    }
    
    internal func validateVideoOutputConfiguration() -> Bool {
        if let videoOutputConfiguration = videoOutputConfiguration {
            let videoWidth = videoOutputConfiguration[AVVideoWidthKey] as? NSNumber
            let videoHeight = videoOutputConfiguration[AVVideoHeightKey] as? NSNumber
            if videoWidth == nil || videoHeight == nil {
                return false
            }
            
            return true
        }
        return false
    }
    
    internal func reset() {
        _progress = 0
        _writer = nil
        _reader = nil
        _pixelBufferAdaptor = nil
        
        _videoOutput = nil
        _audioOutput = nil
        _videoInput = nil
        _audioInput = nil
        
        _progressHandler = nil
        _renderHandler = nil
        _completionHandler = nil
    }
    
}

// MARK: - AVAsset extension

extension AVAsset {
    
    /// Initiates a NextLevelSessionExport on the asset
    ///
    /// - Parameters:
    ///   - outputFileType: type of resulting file to create
    ///   - outputURL: location of resulting file
    ///   - metadata: data to embed in the result
    ///   - videoInputConfiguration: video input configuration
    ///   - videoOutputConfiguration: video output configuration
    ///   - audioOutputConfiguration: audio output configuration
    ///   - progressHandler: progress fraction handler
    ///   - completionHandler: completion handler
    public func nextlevel_export(outputFileType: AVFileType? = .mp4,
                                 outputURL: URL,
                                 metadata: [AVMetadataItem]? = nil,
                                 videoInputConfiguration: [String : Any]? = nil,
                                 videoOutputConfiguration: [String : Any],
                                 audioOutputConfiguration: [String : Any],
                                 progressHandler: NextLevelSessionExporter.ProgressHandler? = nil,
                                 completionHandler: NextLevelSessionExporter.CompletionHandler? = nil) {
        let exporter = NextLevelSessionExporter(withAsset: self)
        exporter.outputFileType = outputFileType
        exporter.outputURL = outputURL
        exporter.videoOutputConfiguration = videoOutputConfiguration
        exporter.audioOutputConfiguration = audioOutputConfiguration
        try? exporter.export(progressHandler: progressHandler, completionHandler: completionHandler)
    }
    
}
