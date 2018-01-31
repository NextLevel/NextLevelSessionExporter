//
//  ViewController.swift
//  NextLevelSessionExporter (http://nextlevel.engineering/)
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

    override func viewDidLoad() {
        super.viewDidLoad()

        // TODO setup session exporter test
        let asset = AVAsset(url: Bundle.main.url(forResource: "TestVideo", withExtension: "mov")!)
        
        let encoder = NextLevelSessionExporter(withAsset: asset)
        encoder.delegate = self
        encoder.outputFileType = AVFileType.mp4.rawValue
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(ProcessInfo().globallyUniqueString)
            .appendingPathExtension("mp4")
        encoder.outputURL = tmpURL
        
        let compressionDict: [String: Any] = [
            AVVideoAverageBitRateKey: NSNumber(integerLiteral: 6000000),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel as String,
        ]
        encoder.videoOutputConfiguration = [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoWidthKey: NSNumber(integerLiteral: 1920),
            AVVideoHeightKey: NSNumber(integerLiteral: 1080),
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
            AVVideoCompressionPropertiesKey: compressionDict
        ]
        encoder.audioOutputConfiguration = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVEncoderBitRateKey: NSNumber(integerLiteral: 128000),
            AVNumberOfChannelsKey: NSNumber(integerLiteral: 2),
            AVSampleRateKey: NSNumber(value: Float(44100))
        ]
        
        do {
            try encoder.export(withCompletionHandler: { () in
                switch encoder.status {
                case .completed:
                    print("NextLevelSessionExporter, export completed, \(encoder.outputURL?.description ?? "")")
                    self.saveVideo(withURL: encoder.outputURL!)
                    break
                case .cancelled:
                    print("NextLevelSessionExporter, export cancelled")
                    break
                case .failed:
                    print("NextLevelSessionExporter, failed to export")
                    break
                case .exporting:
                    fallthrough
                case .waiting:
                    fallthrough
                default:
                    print("NextLevelSessionExporter, did not complete")
                    break
                }
            })
        } catch {
            print("NextLevelSessionExporter, failed to export")
        }
    }
    
    private func saveVideo(withURL url: URL) {
        PHPhotoLibrary.shared().performChanges({
            let albumAssetCollection = self.albumAssetCollection(withTitle: "Next Level")
            if albumAssetCollection == nil {
                let changeRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "Next Level")
                let _ = changeRequest.placeholderForCreatedAssetCollection
            }}, completionHandler: { (success1: Bool, error1: Error?) in
                if let albumAssetCollection = self.albumAssetCollection(withTitle: "Next Level") {
                    PHPhotoLibrary.shared().performChanges({
                        if let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) {
                            let assetCollectionChangeRequest = PHAssetCollectionChangeRequest(for: albumAssetCollection)
                            let enumeration: NSArray = [assetChangeRequest.placeholderForCreatedAsset!]
                            assetCollectionChangeRequest?.addAssets(enumeration)
                        }
                    }, completionHandler: { (success2: Bool, error2: Error?) in
                        if success2 == true {
                            // prompt that the video has been saved
                            let alertController = UIAlertController(title: "Video Saved!", message: "Saved to the camera roll.", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                            alertController.addAction(okAction)
                            self.present(alertController, animated: true, completion: nil)
                        } else {
                            // prompt that the video has been saved
                            let alertController = UIAlertController(title: "Something failed!", message: "Something failed!", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                            alertController.addAction(okAction)
                            self.present(alertController, animated: true, completion: nil)
                        }
                    })
                }
        })
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

// MARK: - NextLevelSessionExporterDelegate

extension ViewController: NextLevelSessionExporterDelegate {
    func sessionExporter(_ sessionExporter: NextLevelSessionExporter, didUpdateProgress progress: Float) {
        print("progress: \(progress)")
    }
    
    func sessionExporter(_ sessionExporter: NextLevelSessionExporter, didRenderFrame renderFrame: CVPixelBuffer, withPresentationTime presentationTime: CMTime, toRenderBuffer renderBuffer: CVPixelBuffer) {
    }
}

