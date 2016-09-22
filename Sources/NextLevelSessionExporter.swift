//
//  NextLevelSessionExporter.swift
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

import Foundation
import AVFoundation

// MARK: - types

// MARK: - NextLevelSessionExporterDelegate

public protocol NextLevelSessionExporterDelegate: NSObjectProtocol {
    func sessionExporter(_ sessionExporter: NextLevelSessionExporter, didUpdateProgress progress: Float)
    func sessionExporter(_ sessionExporter: NextLevelSessionExporter, didRenderFrame renderFrame: CVPixelBuffer, withPresentationTime presentationTime: CMTime, toRenderBuffer renderBuffer: CVPixelBuffer)
}

// MARK: - NextLevelSessionExporter

public class NextLevelSessionExporter: NSObject {
    
    public weak var delegate: NextLevelSessionExporterDelegate?
    
    // MARK: - object lifecycle
    
    override init() {
        super.init()
        
    }
    
    convenience init(withAsset asset: AVAsset) {
        self.init()
       
    }
    
    deinit {
    }
    
    // MARK: - functions
    
}
