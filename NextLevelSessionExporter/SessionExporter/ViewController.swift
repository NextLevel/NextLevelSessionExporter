//
//  ViewController.swift
//  NextLevelSessionExporter
//
//  Copyright (c) 2016-present patrick piemonte (http://patrickpiemonte.com)
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

import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController {
    
    private var exportTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start async export using modern API
        exportTask = Task {
            await performModernExport()
        }
    }
    
    deinit {
        exportTask?.cancel()
    }
    
    // Modern async/await export example
    private func performModernExport() async {
        guard let testVideoURL = Bundle.main.url(forResource: "TestVideo", withExtension: "mov") else {
            print("Test video not found")
            return
        }
        
        let asset = AVAsset(url: testVideoURL)
        
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(ProcessInfo().globallyUniqueString)
            .appendingPathExtension("mp4")
            
        let compressionDict: [String: Any] = [
            AVVideoAverageBitRateKey: NSNumber(integerLiteral: 6000000),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel as String,
        ]
        
        let videoOutputConfiguration = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: NSNumber(integerLiteral: 1920),
            AVVideoHeightKey: NSNumber(integerLiteral: 1080),
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
            AVVideoCompressionPropertiesKey: compressionDict
        ] as [String : Any]
        
        let audioOutputConfiguration = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVEncoderBitRateKey: NSNumber(integerLiteral: 128000),
            AVNumberOfChannelsKey: NSNumber(integerLiteral: 2),
            AVSampleRateKey: NSNumber(value: Float(44100))
        ] as [String : Any]
        
        do {
            // Method 1: Using the convenient AVAsset extension with async/await
            if #available(iOS 15.0, *) {
                print("Starting modern async export...")
                
                let status = try await asset.nextlevel_exportAwait(
                    outputURL: tmpURL,
                    videoOutputConfiguration: videoOutputConfiguration,
                    audioOutputConfiguration: audioOutputConfiguration
                )
                
                switch status {
                case .completed:
                    print("NextLevelSessionExporter, export completed, \(tmpURL.description)")
                    await saveVideo(withURL: tmpURL)
                default:
                    print("NextLevelSessionExporter, did not complete \(status)")
                }
            } else {
                // Fallback to legacy API for older iOS versions
                await performLegacyExport(asset: asset, outputURL: tmpURL, 
                                        videoConfig: videoOutputConfiguration, 
                                        audioConfig: audioOutputConfiguration)
            }
        } catch {
            print("NextLevelSessionExporter, failed to export \(error)")
        }
    }
    
    // Example using async progress monitoring
    private func performExportWithProgress() async {
        guard let testVideoURL = Bundle.main.url(forResource: "TestVideo", withExtension: "mov") else {
            print("Test video not found")
            return
        }
        
        let asset = AVAsset(url: testVideoURL)
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(ProcessInfo().globallyUniqueString)
            .appendingPathExtension("mp4")
            
        let videoOutputConfiguration = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: NSNumber(integerLiteral: 1920),
            AVVideoHeightKey: NSNumber(integerLiteral: 1080)
        ] as [String : Any]
        
        let audioOutputConfiguration = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVEncoderBitRateKey: NSNumber(integerLiteral: 128000)
        ] as [String : Any]
        
        if #available(iOS 15.0, *) {
            do {
                // Method 2: Using AsyncThrowingStream for progress monitoring
                for try await progress in asset.nextlevel_exportAsync(
                    outputURL: tmpURL,
                    videoOutputConfiguration: videoOutputConfiguration,
                    audioOutputConfiguration: audioOutputConfiguration
                ) {
                    print("Export progress: \(progress.progress * 100)%")
                    
                    // Update UI on main thread if needed
                    await MainActor.run {
                        // Update progress UI here
                    }
                    
                    if progress.progress >= 1.0 {
                        print("Export completed!")
                        await saveVideo(withURL: tmpURL)
                        break
                    }
                }
            } catch {
                print("Export failed: \(error)")
            }
        }
    }
    
    // Legacy export method for backwards compatibility
    private func performLegacyExport(asset: AVAsset, outputURL: URL, videoConfig: [String: Any], audioConfig: [String: Any]) async {
        await withCheckedContinuation { continuation in
            let exporter = NextLevelSessionExporter(
                asset: asset,
                outputURL: outputURL,
                outputFileType: .mp4,
                videoOutputConfiguration: videoConfig,
                audioOutputConfiguration: audioConfig
            )
            
            exporter.export(progressHandler: { (progress) in
                print("Legacy export progress: \(progress)")
            }, completionHandler: { result in
                switch result {
                case .success(let status):
                    switch status {
                    case .completed:
                        print("Legacy export completed")
                        Task {
                            await self.saveVideo(withURL: outputURL)
                        }
                    default:
                        print("Legacy export did not complete \(status)")
                    }
                case .failure(let error):
                    print("Legacy export failed \(error)")
                }
                continuation.resume()
            })
        }
    }
    
    private func saveVideo(withURL url: URL) async {
        do {
            // Modern async photo library operations
            try await PHPhotoLibrary.shared().performChanges {
                // Create album if it doesn't exist
                if self.albumAssetCollection(withTitle: "Next Level") == nil {
                    PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "Next Level")
                }
            }
            
            // Add video to album
            if let albumAssetCollection = self.albumAssetCollection(withTitle: "Next Level") {
                try await PHPhotoLibrary.shared().performChanges {
                    if let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) {
                        let assetCollectionChangeRequest = PHAssetCollectionChangeRequest(for: albumAssetCollection)
                        assetCollectionChangeRequest?.addAssets([assetChangeRequest.placeholderForCreatedAsset!] as NSArray)
                    }
                }
                
                await showAlert(title: "Video Saved!", message: "Saved to the camera roll.")
            }
        } catch {
            print("Failed to save video: \(error)")
            await showAlert(title: "Something failed!", message: "Failed to save video: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }

    private func albumAssetCollection(withTitle title: String) -> PHAssetCollection? {
        let predicate = NSPredicate(format: "localizedTitle = %@", title)
        let options = PHFetchOptions()
        options.predicate = predicate
        let result = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
        if result.count > 0 {
            return result.firstObject
        }
        return nil
    }
    
}
