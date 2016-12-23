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

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // TODO setup session exporter test
        let asset = AVAsset(url: Bundle.main.url(forResource: "TestVideo", withExtension: "mov")!)
        
        let encoder = NextLevelSessionExporter(withAsset: asset)
        encoder.delegate = self
        encoder.outputFileType = AVFileTypeMPEG4
        let tmpURL = try! URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(ProcessInfo().globallyUniqueString)
            .appendingPathExtension("mp4")
        encoder.outputURL = tmpURL
        
        var compressionDict: [String : Any] = [:]
        compressionDict[AVVideoAverageBitRateKey] = NSNumber(value: Int(40000))
        compressionDict[AVVideoAllowFrameReorderingKey] = NSNumber(value: false)
        compressionDict[AVVideoExpectedSourceFrameRateKey] = NSNumber(value: Int(30))
        
        encoder.videoOutputConfiguration = [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoHeightKey: NSNumber(value: 640),
            AVVideoWidthKey: NSNumber(value: 352),
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
            AVVideoCompressionPropertiesKey: compressionDict
        ]
        encoder.audioOutputConfiguration = [
            AVEncoderBitRateKey: NSNumber(value: Int(40000)),
            AVNumberOfChannelsKey: NSNumber(value: Int(1)),
            AVSampleRateKey: NSNumber(value: Int(16000))
        ]
        
        do {
            try encoder.export(withCompletionHandler: { () in
                switch encoder.status {
                case .completed:
                    print("NextLevelSessionExporter, export completed, \(encoder.outputURL)")
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
}

// MARK: - NextLevelSessionExporterDelegate

extension ViewController: NextLevelSessionExporterDelegate {
    func sessionExporter(_ sessionExporter: NextLevelSessionExporter, didUpdateProgress progress: Float) {
        print("progress: \(progress)")
    }
    
    func sessionExporter(_ sessionExporter: NextLevelSessionExporter, didRenderFrame renderFrame: CVPixelBuffer, withPresentationTime presentationTime: CMTime, toRenderBuffer renderBuffer: CVPixelBuffer) {
    }
}

