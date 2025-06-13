//
//  NextLevelSessionExporter.swift
//  NextLevelSessionExporter
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
@preconcurrency import AVFoundation

// MARK: - Sendable types

/// Progress information for async export operations.
public struct ExportProgress: Sendable {
    public let progress: Float
    public let estimatedTimeRemaining: TimeInterval?
    
    public init(progress: Float, estimatedTimeRemaining: TimeInterval? = nil) {
        self.progress = progress
        self.estimatedTimeRemaining = estimatedTimeRemaining
    }
}

/// Render frame data for async operations.
/// Note: CVPixelBuffer doesn't conform to Sendable, so we use @unchecked
public struct RenderFrameData: @unchecked Sendable {
    public let renderFrame: CVPixelBuffer
    public let presentationTime: CMTime
    public let resultingBuffer: CVPixelBuffer
    
    public init(renderFrame: CVPixelBuffer, presentationTime: CMTime, resultingBuffer: CVPixelBuffer) {
        self.renderFrame = renderFrame
        self.presentationTime = presentationTime
        self.resultingBuffer = resultingBuffer
    }
}

// MARK: - types

/// Session export errors.
public enum NextLevelSessionExporterError: Error, CustomStringConvertible, Sendable {
    case setupFailure
    case readingFailure
    case writingFailure
    case cancelled

    public var description: String {
        get {
            switch self {
            case .setupFailure:
                return "Setup failure"
            case .readingFailure:
                return "Reading failure"
            case .writingFailure:
                return "Writing failure"
            case .cancelled:
                return "Cancelled"
            }
        }
    }
}

// MARK: - ExportState Actor

/// Actor to encapsulate mutable state for thread safety in Swift 6
actor ExportState {
    var writer: AVAssetWriter?
    var reader: AVAssetReader?
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    var videoOutput: AVAssetReaderVideoCompositionOutput?
    var audioOutput: AVAssetReaderAudioMixOutput?
    var videoInput: AVAssetWriterInput?
    var audioInput: AVAssetWriterInput?
    
    var progress: Float = 0
    var duration: TimeInterval = 0
    var lastSamplePresentationTime: CMTime = .invalid
    
    var progressHandler: (@Sendable (Float) -> Void)?
    var renderHandler: (@Sendable (CVPixelBuffer, CMTime, CVPixelBuffer) -> Void)?
    var completionHandler: (@Sendable (Swift.Result<AVAssetExportSession.Status, Error>) -> Void)?
    
    func reset() {
        self.progress = 0
        self.writer = nil
        self.reader = nil
        self.pixelBufferAdaptor = nil
        
        self.videoOutput = nil
        self.audioOutput = nil
        self.videoInput = nil
        self.audioInput = nil
        
        self.progressHandler = nil
        self.renderHandler = nil
        self.completionHandler = nil
    }
    
    func clearCompletionHandler() {
        self.completionHandler = nil
    }
    
    func setLastSamplePresentationTime(_ time: CMTime) {
        self.lastSamplePresentationTime = time
    }
    
    func setHandlers(progress: (@Sendable (Float) -> Void)? = nil,
                    render: (@Sendable (CVPixelBuffer, CMTime, CVPixelBuffer) -> Void)? = nil,
                    completion: (@Sendable (Swift.Result<AVAssetExportSession.Status, Error>) -> Void)? = nil) {
        self.progressHandler = progress
        self.renderHandler = render
        self.completionHandler = completion
    }
    
    func setWriter(_ writer: AVAssetWriter?) {
        self.writer = writer
    }
    
    func setReader(_ reader: AVAssetReader?) {
        self.reader = reader
    }
    
    func setDuration(_ duration: TimeInterval) {
        self.duration = duration
    }
    
    func setVideoInputOutput(input: AVAssetWriterInput?, output: AVAssetReaderVideoCompositionOutput?, adaptor: AVAssetWriterInputPixelBufferAdaptor?) {
        self.videoInput = input
        self.videoOutput = output
        self.pixelBufferAdaptor = adaptor
    }
    
    func setAudioInputOutput(input: AVAssetWriterInput?, output: AVAssetReaderAudioMixOutput?) {
        self.audioInput = input
        self.audioOutput = output
    }
    
    func setAudioInput(_ input: AVAssetWriterInput?) {
        self.audioInput = input
    }
    
    func updateProgress(_ newProgress: Float) {
        self.progress = newProgress
        self.progressHandler?(newProgress)
    }
}

// MARK: - NextLevelSessionExporter

/// 🔄 NextLevelSessionExporter, export and transcode media in Swift
/// Note: Using @unchecked Sendable as the configuration dictionaries cannot be made Sendable.
/// Thread safety is ensured through immutable properties and actor isolation of mutable state.
public final class NextLevelSessionExporter: NSObject, @unchecked Sendable {

    /// Input asset for export, provided when initialized.
    public let asset: AVAsset?

    /// Enables video composition and parameters for the session.
    public let videoComposition: AVVideoComposition?

    /// Enables audio mixing and parameters for the session.
    public let audioMix: AVAudioMix?

    /// Output file location for the session.
    public let outputURL: URL?

    /// Output file type. UTI string defined in `AVMediaFormat.h`.
    public let outputFileType: AVFileType?

    /// Time range or limit of an export from `kCMTimeZero` to `kCMTimePositiveInfinity`
    public let timeRange: CMTimeRange

    /// Indicates if an export session should expect media data in real time.
    public let expectsMediaDataInRealTime: Bool

    /// Indicates if an export should be optimized for network use.
    public let optimizeForNetworkUse: Bool

    /// Metadata to be added to an export.
    public let metadata: [AVMetadataItem]?

    /// Video input configuration dictionary, using keys defined in `<CoreVideo/CVPixelBuffer.h>`
    public let videoInputConfiguration: [String : Any]?

    /// Video output configuration dictionary, using keys defined in `<AVFoundation/AVVideoSettings.h>`
    public let videoOutputConfiguration: [String : Any]?

    /// Audio output configuration dictionary, using keys defined in `<AVFoundation/AVAudioSettings.h>`
    public let audioOutputConfiguration: [String : Any]?

    // private instance vars
    private let exportState = ExportState()
    private let inputQueue: DispatchQueue
    
    private static let inputQueueLabel = "NextLevelSessionExporterInputQueue"

    /// Export session status state.
    public var status: AVAssetExportSession.Status {
        get async {
            if let writer = await exportState.writer {
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
                    fallthrough
                @unknown default:
                    break
                }
            }
            return .unknown
        }
    }

    /// Session exporting progress from 0 to 1.
    public var progress: Float {
        get async {
            return await exportState.progress
        }
    }

    // MARK: - object lifecycle

    /// Initializes a session with an asset to export.
    ///
    /// - Parameter asset: The asset to export.
    public convenience init(withAsset asset: AVAsset) {
        self.init(
            asset: asset,
            videoComposition: nil,
            audioMix: nil,
            outputURL: nil,
            outputFileType: .mp4,
            timeRange: CMTimeRange(start: CMTime.zero, end: CMTime.positiveInfinity),
            expectsMediaDataInRealTime: false,
            optimizeForNetworkUse: false,
            metadata: nil,
            videoInputConfiguration: nil,
            videoOutputConfiguration: nil,
            audioOutputConfiguration: nil
        )
    }

    public init(
        asset: AVAsset? = nil,
        videoComposition: AVVideoComposition? = nil,
        audioMix: AVAudioMix? = nil,
        outputURL: URL? = nil,
        outputFileType: AVFileType? = .mp4,
        timeRange: CMTimeRange = CMTimeRange(start: CMTime.zero, end: CMTime.positiveInfinity),
        expectsMediaDataInRealTime: Bool = false,
        optimizeForNetworkUse: Bool = false,
        metadata: [AVMetadataItem]? = nil,
        videoInputConfiguration: [String : Any]? = nil,
        videoOutputConfiguration: [String : Any]? = nil,
        audioOutputConfiguration: [String : Any]? = nil
    ) {
        self.asset = asset
        self.videoComposition = videoComposition
        self.audioMix = audioMix
        self.outputURL = outputURL
        self.outputFileType = outputFileType
        self.timeRange = timeRange
        self.expectsMediaDataInRealTime = expectsMediaDataInRealTime
        self.optimizeForNetworkUse = optimizeForNetworkUse
        self.metadata = metadata
        self.videoInputConfiguration = videoInputConfiguration
        self.videoOutputConfiguration = videoOutputConfiguration
        self.audioOutputConfiguration = audioOutputConfiguration
        self.inputQueue = DispatchQueue(label: Self.inputQueueLabel, autoreleaseFrequency: .workItem, target: DispatchQueue.global())
        super.init()
    }
    
    /// Creates a configured exporter from the current instance's properties.
    /// Use this method when you need to create a new exporter with updated configuration.
    public func makeConfiguredExporter(
        outputURL: URL? = nil,
        outputFileType: AVFileType? = nil,
        videoOutputConfiguration: [String : Any]? = nil,
        audioOutputConfiguration: [String : Any]? = nil
    ) -> NextLevelSessionExporter {
        return NextLevelSessionExporter(
            asset: self.asset,
            videoComposition: self.videoComposition,
            audioMix: self.audioMix,
            outputURL: outputURL ?? self.outputURL,
            outputFileType: outputFileType ?? self.outputFileType,
            timeRange: self.timeRange,
            expectsMediaDataInRealTime: self.expectsMediaDataInRealTime,
            optimizeForNetworkUse: self.optimizeForNetworkUse,
            metadata: self.metadata,
            videoInputConfiguration: self.videoInputConfiguration,
            videoOutputConfiguration: videoOutputConfiguration ?? self.videoOutputConfiguration,
            audioOutputConfiguration: audioOutputConfiguration ?? self.audioOutputConfiguration
        )
    }
}

// MARK: - export

extension NextLevelSessionExporter {

    /// Completion handler type for when an export finishes.
    public typealias CompletionHandler = @Sendable (Swift.Result<AVAssetExportSession.Status, Error>) -> Void

    /// Progress handler type
    public typealias ProgressHandler = @Sendable (_ progress: Float) -> Void

    /// Render handler type for frame processing
    public typealias RenderHandler = @Sendable (_ renderFrame: CVPixelBuffer, _ presentationTime: CMTime, _ resultingBuffer: CVPixelBuffer) -> Void

    // MARK: - Modern async/await export methods
    
    /// Initiates an async export session with progress reporting.
    /// 
    /// - Parameter renderHandler: Optional closure for custom frame rendering
    /// - Returns: AsyncThrowingStream of ExportProgress updates
    /// - Throws: NextLevelSessionExporterError on export failure
    @available(iOS 15.0, macOS 12.0, *)
    @discardableResult
    public func export(renderHandler: (@Sendable (RenderFrameData) async -> Void)? = nil) -> AsyncThrowingStream<ExportProgress, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await _performAsyncExport(progressContinuation: continuation, renderHandler: renderHandler)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Simplified async export method that returns only the final status.
    /// 
    /// - Parameter renderHandler: Optional closure for custom frame rendering
    /// - Returns: Final export status
    /// - Throws: NextLevelSessionExporterError on export failure
    @available(iOS 15.0, macOS 12.0, *)
    public func exportAsync(renderHandler: (@Sendable (RenderFrameData) async -> Void)? = nil) async throws -> AVAssetExportSession.Status {
        for try await progress in export(renderHandler: renderHandler) {
            // We only care about the final result, so we continue until completion
            if progress.progress >= 1.0 {
                break
            }
        }
        return await self.status
    }
    
    // MARK: - Legacy completion handler methods
    
    /// Legacy export method using completion handlers.
    /// - Note: This method is deprecated. Use `export(renderHandler:)` or `exportAsync(renderHandler:)` instead.
    /// 
    /// - Parameters:
    ///   - renderHandler: optional render process handler
    ///   - progressHandler: optional export progress handler
    ///   - completionHandler: completion handler, called when the export fails or succeeds
    @available(*, deprecated, message: "Use async export methods instead")
    public func export(renderHandler: RenderHandler? = nil,
                       progressHandler: ProgressHandler? = nil,
                       completionHandler: CompletionHandler? = nil) {
        Task {
            await _performLegacyExport(renderHandler: renderHandler, progressHandler: progressHandler, completionHandler: completionHandler)
        }
    }
    
    private func _performLegacyExport(renderHandler: RenderHandler? = nil,
                                     progressHandler: ProgressHandler? = nil,
                                     completionHandler: CompletionHandler? = nil) async {
        guard let asset = self.asset,
              let outputURL = self.outputURL,
              let outputFileType = self.outputFileType else {
            print("NextLevelSessionExporter, an asset and output URL are required for encoding")
            await MainActor.run {
                completionHandler?(.failure(NextLevelSessionExporterError.setupFailure))
            }
            return
        }

        // Reset any existing export
        await exportState.reset()
        
        // Store handlers
        await exportState.setHandlers(progress: progressHandler, render: renderHandler, completion: completionHandler)

        do {
            let reader = try AVAssetReader(asset: asset)
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: outputFileType)
            
            await exportState.setReader(reader)
            await exportState.setWriter(writer)
            
            // Cancel any existing operations
            if writer.status == .writing {
                writer.cancelWriting()
            }
            if reader.status == .reading {
                reader.cancelReading()
            }

            reader.timeRange = self.timeRange
            writer.shouldOptimizeForNetworkUse = self.optimizeForNetworkUse
            writer.metadata = self.metadata ?? []

            // video output
            await self.setupVideoOutput(withAsset: asset, reader: reader, writer: writer)
            await self.setupAudioOutput(withAsset: asset, reader: reader)
            await self.setupAudioInput(writer: writer)

            // export
            writer.startWriting()
            reader.startReading()
            writer.startSession(atSourceTime: self.timeRange.start)

            let videoSemaphore = DispatchSemaphore(value: 0)
            let audioSemaphore = DispatchSemaphore(value: 0)

            let duration = CMTimeGetSeconds(self.timeRange.duration)
            await exportState.setDuration((duration.isFinite && duration > 0) ? duration : CMTimeGetSeconds(asset.duration))

            // video encoding
            if let videoInput = await exportState.videoInput,
               let videoOutput = await exportState.videoOutput {
                videoInput.requestMediaDataWhenReady(on: self.inputQueue, using: {
                    Task {
                        let success = await self.encodeReadySamples(fromOutput: videoOutput, toInput: videoInput)
                        if !success {
                            videoSemaphore.signal()
                        }
                    }
                })
            } else {
                videoSemaphore.signal()
            }

            // audio encoding
            if let audioInput = await exportState.audioInput,
               let audioOutput = await exportState.audioOutput {
                audioInput.requestMediaDataWhenReady(on: self.inputQueue, using: {
                    Task {
                        let success = await self.encodeReadySamples(fromOutput: audioOutput, toInput: audioInput)
                        if !success {
                            audioSemaphore.signal()
                        }
                    }
                })
            } else {
                audioSemaphore.signal()
            }

            // wait for encoding to finish using non-async context
            await Task { @MainActor in }.value // switch to main actor
            
            _ = await withUnsafeContinuation { continuation in
                DispatchQueue.global().async {
                    videoSemaphore.wait()
                    audioSemaphore.wait()
                    continuation.resume(returning: ())
                }
            }

            await self.finish()
        } catch {
            print("NextLevelSessionExporter, failed to setup \(error)")
            await MainActor.run {
                completionHandler?(.failure(NextLevelSessionExporterError.setupFailure))
            }
        }
    }
    
    @available(iOS 15.0, macOS 12.0, *)
    private func _performAsyncExport(progressContinuation: AsyncThrowingStream<ExportProgress, Error>.Continuation, renderHandler: (@Sendable (RenderFrameData) async -> Void)?) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                // Store the continuation for completion callback
                let completionHandler: CompletionHandler = { result in
                    switch result {
                    case .success(_):
                        progressContinuation.finish()
                        continuation.resume(returning: ())
                    case .failure(let error):
                        progressContinuation.finish(throwing: error)
                        continuation.resume(throwing: error)
                    }
                }
                
                // Convert async render handler to sync for legacy system
                let syncRenderHandler: RenderHandler?
                if let handler = renderHandler {
                    syncRenderHandler = { renderFrame, presentationTime, resultingBuffer in
                        let frameData = RenderFrameData(renderFrame: renderFrame, presentationTime: presentationTime, resultingBuffer: resultingBuffer)
                        Task {
                            await handler(frameData)
                        }
                    }
                } else {
                    syncRenderHandler = nil
                }
                
                // Progress handler that feeds the AsyncStream
                let progressHandler: ProgressHandler = { progress in
                    let exportProgress = ExportProgress(progress: progress)
                    progressContinuation.yield(exportProgress)
                }
                
                // Call the legacy export method
                await self._performLegacyExport(renderHandler: syncRenderHandler, progressHandler: progressHandler, completionHandler: completionHandler)
            }
        }
    }

    /// Cancels any export in progress.
    public func cancelExport() async {
        let writer = await exportState.writer
        let reader = await exportState.reader
        
        self.inputQueue.async {
            if writer?.status == .writing {
                writer?.cancelWriting()
            }
            if reader?.status == .reading {
                reader?.cancelReading()
            }
        }
        
        await self.complete()
        await exportState.reset()
    }

}

// MARK: - setup funcs

extension NextLevelSessionExporter {

    private func setupVideoOutput(withAsset asset: AVAsset, reader: AVAssetReader, writer: AVAssetWriter) async {
        let videoTracks = asset.tracks(withMediaType: AVMediaType.video)

        guard videoTracks.count > 0 else {
            return
        }

        let videoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: videoTracks, videoSettings: self.videoInputConfiguration)
        videoOutput.alwaysCopiesSampleData = false

        if let videoComposition = self.videoComposition {
            videoOutput.videoComposition = videoComposition
        } else {
            videoOutput.videoComposition = self.createVideoComposition()
        }

        if reader.canAdd(videoOutput) {
            reader.add(videoOutput)
        }

        // video input
        guard let videoOutputConfiguration = self.videoOutputConfiguration,
              writer.canApply(outputSettings: videoOutputConfiguration, forMediaType: AVMediaType.video) else {
            print("Unsupported output configuration")
            return
        }
        
        let videoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoOutputConfiguration)
        videoInput.expectsMediaDataInRealTime = self.expectsMediaDataInRealTime

        if writer.canAdd(videoInput) {
            writer.add(videoInput)
        }

        // setup pixelbuffer adaptor
        var pixelBufferAttrib: [String : Any] = [:]
        pixelBufferAttrib[kCVPixelBufferPixelFormatTypeKey as String] = NSNumber(integerLiteral: Int(kCVPixelFormatType_32RGBA))
        if let videoComposition = videoOutput.videoComposition {
            pixelBufferAttrib[kCVPixelBufferWidthKey as String] = NSNumber(integerLiteral: Int(videoComposition.renderSize.width))
            pixelBufferAttrib[kCVPixelBufferHeightKey as String] = NSNumber(integerLiteral: Int(videoComposition.renderSize.height))
        }
        pixelBufferAttrib["IOSurfaceOpenGLESTextureCompatibility"] = NSNumber(booleanLiteral:  true)
        pixelBufferAttrib["IOSurfaceOpenGLESFBOCompatibility"] = NSNumber(booleanLiteral:  true)

        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: pixelBufferAttrib)
        
        await exportState.setVideoInputOutput(input: videoInput, output: videoOutput, adaptor: pixelBufferAdaptor)
    }

    private func setupAudioOutput(withAsset asset: AVAsset, reader: AVAssetReader) async {
        let audioTracks = asset.tracks(withMediaType: AVMediaType.audio)

        guard audioTracks.count > 0 else {
            return
        }

        var audioTracksToUse: [AVAssetTrack] = []
        // Remove APAC tracks (See Issue #49)
        for audioTrack in audioTracks {
            let mediaSubtypes = audioTrack.formatDescriptions.filter { CMFormatDescriptionGetMediaType($0 as! CMFormatDescription) == kCMMediaType_Audio }.map { CMFormatDescriptionGetMediaSubType($0 as! CMFormatDescription) }
            for mediaSubtype in mediaSubtypes where mediaSubtype != kAudioFormatAPAC {
                audioTracksToUse.append(audioTrack)
            }
        }

        let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracksToUse, audioSettings: nil)
        audioOutput.alwaysCopiesSampleData = false
        audioOutput.audioMix = self.audioMix
        
        if reader.canAdd(audioOutput) {
            reader.add(audioOutput)
        }
        
        await exportState.setAudioInputOutput(input: nil, output: audioOutput)
    }

    private func setupAudioInput(writer: AVAssetWriter) async {
        guard await exportState.audioOutput != nil else {
            return
        }

        let audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: self.audioOutputConfiguration)
        audioInput.expectsMediaDataInRealTime = self.expectsMediaDataInRealTime
        
        if writer.canAdd(audioInput) {
            writer.add(audioInput)
        }
        
        await exportState.setAudioInput(audioInput)
    }

    private func encodeReadySamples(fromOutput output: AVAssetReaderOutput, toInput input: AVAssetWriterInput) async -> Bool {
        while input.isReadyForMoreMediaData {
            let complete = await self.encode(readySamplesFromOutput: output, toInput: input)
            if !complete {
                return false
            }
        }
        return true
    }

    private func encode(readySamplesFromOutput output: AVAssetReaderOutput, toInput input: AVAssetWriterInput) async -> Bool {
        guard let sampleBuffer = output.copyNextSampleBuffer() else {
            input.markAsFinished()
            return false
        }

        var handled = false
        var error = false
        
        let videoOutput = await exportState.videoOutput
        let pixelBufferAdaptor = await exportState.pixelBufferAdaptor
        let renderHandler = await exportState.renderHandler
        
        if videoOutput === output {
            // determine progress
            let lastSamplePresentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) - self.timeRange.start
            await exportState.setLastSamplePresentationTime(lastSamplePresentationTime)
            
            let duration = await exportState.duration
            let progress = duration == 0 ? 1 : Float(CMTimeGetSeconds(lastSamplePresentationTime) / duration)
            await self.updateProgress(progress: progress)

            // prepare progress frames
            if let pixelBufferAdaptor = pixelBufferAdaptor,
               let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool,
               let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {

                var toRenderBuffer: CVPixelBuffer? = nil
                let result = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &toRenderBuffer)
                if result == kCVReturnSuccess {
                    if let toBuffer = toRenderBuffer {
                        renderHandler?(pixelBuffer, lastSamplePresentationTime, toBuffer)
                        if pixelBufferAdaptor.append(toBuffer, withPresentationTime: lastSamplePresentationTime) == false {
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
        
        return true
    }

    internal func createVideoComposition() -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()

        if let asset = self.asset,
            let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first {

            // determine the framerate

            var frameRate: Float = 0
            if let videoConfiguration = self.videoOutputConfiguration {
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

            if let videoConfiguration = self.videoOutputConfiguration {

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
                transform.tx -= transformedRect.origin.x;
                transform.ty -= transformedRect.origin.y;


                let videoAngleInDegrees = atan2(transform.b, transform.a) * 180 / .pi
                if videoAngleInDegrees == 90 || videoAngleInDegrees == -90 {
                    let tempWidth = naturalSize.width
                    naturalSize.width = naturalSize.height
                    naturalSize.height = tempWidth
                }
                videoComposition.renderSize = naturalSize

                // center the video

                var ratio: CGFloat = 0
                let xRatio: CGFloat = targetSize.width / naturalSize.width
                let yRatio: CGFloat = targetSize.height / naturalSize.height
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
                compositionInstruction.timeRange = CMTimeRange(start: CMTime.zero, duration: asset.duration)

                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                layerInstruction.setTransform(transform, at: CMTime.zero)

                compositionInstruction.layerInstructions = [layerInstruction]
                videoComposition.instructions = [compositionInstruction]

            }
        }

        return videoComposition
    }

    internal func updateProgress(progress: Float) async {
        await exportState.updateProgress(progress)
    }

    // always called on the main thread
    internal func finish() async {
        let reader = await exportState.reader
        let writer = await exportState.writer
        
        if reader?.status == .cancelled || writer?.status == .cancelled {
            await self.complete()
        } else if writer?.status == .failed {
            reader?.cancelReading()
            await self.complete()
        } else if reader?.status == .failed {
            writer?.cancelWriting()
            await self.complete()
        } else {
            await withCheckedContinuation { continuation in
                writer?.finishWriting {
                    Task {
                        await self.complete()
                        continuation.resume()
                    }
                }
            }
        }
    }

    // always called on the main thread
    internal func complete() async {
        let reader = await exportState.reader
        let writer = await exportState.writer
        let completionHandler = await exportState.completionHandler
        
        if reader?.status == .cancelled || writer?.status == .cancelled {
            guard let outputURL = self.outputURL else {
                await MainActor.run {
                    completionHandler?(.failure(NextLevelSessionExporterError.cancelled))
                }
                return
            }
            if FileManager.default.fileExists(atPath: outputURL.absoluteString) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            await MainActor.run {
                completionHandler?(.failure(NextLevelSessionExporterError.cancelled))
            }
            return
        }

        guard let reader = reader else {
            await MainActor.run {
                completionHandler?(.failure(NextLevelSessionExporterError.setupFailure))
            }
            await exportState.clearCompletionHandler()
            return
        }

        guard let writer = writer else {
            await MainActor.run {
                completionHandler?(.failure(NextLevelSessionExporterError.setupFailure))
            }
            await exportState.clearCompletionHandler()
            return
        }

        switch reader.status {
        case .failed:
            guard let outputURL = self.outputURL else {
                await MainActor.run {
                    completionHandler?(.failure(reader.error ?? NextLevelSessionExporterError.readingFailure))
                }
                return
            }
            if FileManager.default.fileExists(atPath: outputURL.absoluteString) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            await MainActor.run {
                completionHandler?(.failure(reader.error ?? NextLevelSessionExporterError.readingFailure))
            }
            return
        default:
            // do nothing
            break
        }

        switch writer.status {
        case .failed:
            guard let outputURL = self.outputURL else {
                await MainActor.run {
                    completionHandler?(.failure(writer.error ?? NextLevelSessionExporterError.writingFailure))
                }
                return
            }
            if FileManager.default.fileExists(atPath: outputURL.absoluteString) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            await MainActor.run {
                completionHandler?(.failure(writer.error ?? NextLevelSessionExporterError.writingFailure))
            }
            return
        default:
            // do nothing
            break
        }

        let finalStatus = await self.status
        await MainActor.run {
            completionHandler?(.success(finalStatus))
        }
            await exportState.clearCompletionHandler()
    }

    // subclass and add more checks, if needed
    public func validateVideoOutputConfiguration() -> Bool {
        guard let videoOutputConfiguration = self.videoOutputConfiguration else {
            return false
        }

        let videoWidth = videoOutputConfiguration[AVVideoWidthKey] as? NSNumber
        let videoHeight = videoOutputConfiguration[AVVideoHeightKey] as? NSNumber
        if videoWidth == nil || videoHeight == nil {
            return false
        }

        return true
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
    @available(*, deprecated, message: "Use async export methods instead")
    public func nextlevel_export(outputFileType: AVFileType? = AVFileType.mp4,
                                   outputURL: URL,
                                   metadata: [AVMetadataItem]? = nil,
                                   videoInputConfiguration: [String : Any]? = nil,
                                   videoOutputConfiguration: [String : Any],
                                   audioOutputConfiguration: [String : Any],
                                   progressHandler: NextLevelSessionExporter.ProgressHandler? = nil,
                                   completionHandler: NextLevelSessionExporter.CompletionHandler? = nil) {
        let exporter = NextLevelSessionExporter(
            asset: self,
            outputURL: outputURL,
            outputFileType: outputFileType,
            metadata: metadata,
            videoInputConfiguration: videoInputConfiguration,
            videoOutputConfiguration: videoOutputConfiguration,
            audioOutputConfiguration: audioOutputConfiguration
        )
        exporter.export(progressHandler: progressHandler, completionHandler: completionHandler)
    }
    
    // MARK: - Modern async/await convenience methods
    
    /// Initiates an async NextLevelSessionExport on the asset with progress reporting.
    ///
    /// - Parameters:
    ///   - outputFileType: type of resulting file to create
    ///   - outputURL: location of resulting file
    ///   - metadata: data to embed in the result
    ///   - videoInputConfiguration: video input configuration
    ///   - videoOutputConfiguration: video output configuration
    ///   - audioOutputConfiguration: audio output configuration
    ///   - renderHandler: optional closure for custom frame rendering
    /// - Returns: AsyncThrowingStream of ExportProgress updates
    /// - Throws: NextLevelSessionExporterError on export failure
    @available(iOS 15.0, macOS 12.0, *)
    @discardableResult
    public func nextlevel_exportAsync(
        outputFileType: AVFileType? = AVFileType.mp4,
        outputURL: URL,
        metadata: [AVMetadataItem]? = nil,
        videoInputConfiguration: [String : Any]? = nil,
        videoOutputConfiguration: [String : Any],
        audioOutputConfiguration: [String : Any],
        renderHandler: (@Sendable (RenderFrameData) async -> Void)? = nil
    ) -> AsyncThrowingStream<ExportProgress, Error> {
        let exporter = NextLevelSessionExporter(
            asset: self,
            outputURL: outputURL,
            outputFileType: outputFileType,
            metadata: metadata,
            videoInputConfiguration: videoInputConfiguration,
            videoOutputConfiguration: videoOutputConfiguration,
            audioOutputConfiguration: audioOutputConfiguration
        )
        return exporter.export(renderHandler: renderHandler)
    }
    
    /// Simplified async NextLevelSessionExport that returns only the final status.
    ///
    /// - Parameters:
    ///   - outputFileType: type of resulting file to create
    ///   - outputURL: location of resulting file
    ///   - metadata: data to embed in the result
    ///   - videoInputConfiguration: video input configuration
    ///   - videoOutputConfiguration: video output configuration
    ///   - audioOutputConfiguration: audio output configuration
    ///   - renderHandler: optional closure for custom frame rendering
    /// - Returns: Final export status
    /// - Throws: NextLevelSessionExporterError on export failure
    @available(iOS 15.0, macOS 12.0, *)
    public func nextlevel_exportAwait(
        outputFileType: AVFileType? = AVFileType.mp4,
        outputURL: URL,
        metadata: [AVMetadataItem]? = nil,
        videoInputConfiguration: [String : Any]? = nil,
        videoOutputConfiguration: [String : Any],
        audioOutputConfiguration: [String : Any],
        renderHandler: (@Sendable (RenderFrameData) async -> Void)? = nil
    ) async throws -> AVAssetExportSession.Status {
        let exporter = NextLevelSessionExporter(
            asset: self,
            outputURL: outputURL,
            outputFileType: outputFileType,
            metadata: metadata,
            videoInputConfiguration: videoInputConfiguration,
            videoOutputConfiguration: videoOutputConfiguration,
            audioOutputConfiguration: audioOutputConfiguration
        )
        return try await exporter.exportAsync(renderHandler: renderHandler)
    }

}
