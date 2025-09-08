# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

NextLevelSessionExporter is a Swift library for iOS that provides customizable audio and video encoding options for exporting and transcoding media. It's a more flexible alternative to AVAssetExportSession without requiring deep AVFoundation knowledge.

## Build & Development Commands

### Building the Framework
```bash
# Build using Xcode command line tools
xcodebuild -scheme NextLevelSessionExporter -configuration Debug build

# Build for release
xcodebuild -scheme NextLevelSessionExporter -configuration Release build

# Build using Swift Package Manager
swift build
```

### Documentation
```bash
# Generate documentation with jazzy
./build_docs.sh
```

### Package Management
```bash
# CocoaPods - validate podspec
pod lib lint NextLevelSessionExporter.podspec

# Swift Package Manager - test package
swift test
```

## Architecture

### Core Component
- **NextLevelSessionExporter** (Sources/NextLevelSessionExporter.swift): Main exporter class that handles the entire export pipeline
  - Uses AVAssetReader for reading source media
  - Uses AVAssetWriter for writing output media
  - Manages video/audio input/output configurations
  - Provides progress callbacks and completion handlers
  - Supports custom render handlers for frame processing

### Key Features
- Custom video/audio encoding configurations
- Real-time progress tracking
- Frame-by-frame video processing capability via render handlers
- Automatic handling of video orientation and transforms
- Support for audio mixing and video composition
- APAC audio track filtering (prevents export failures)

### Export Pipeline
1. Setup reader (AVAssetReader) and writer (AVAssetWriter)
2. Configure video/audio outputs based on provided configurations
3. Create appropriate video composition if needed
4. Process samples using dispatch queues for concurrent video/audio encoding
5. Handle completion with proper cleanup

### Configuration Dictionaries
- **videoOutputConfiguration**: Uses AVFoundation video settings keys (AVVideoCodecKey, AVVideoWidthKey, etc.)
- **audioOutputConfiguration**: Uses AVFoundation audio settings keys (AVFormatIDKey, AVSampleRateKey, etc.)
- **videoInputConfiguration**: Uses CoreVideo pixel buffer keys for input format

### Error Handling
The library defines NextLevelSessionExporterError enum with cases:
- setupFailure: Configuration or initialization issues
- readingFailure: Problems reading source asset
- writingFailure: Problems writing output file
- cancelled: Export was cancelled

## Important Implementation Details

- Minimum iOS deployment target: iOS 13.0
- Swift version: 5.0
- The library automatically filters out APAC audio tracks to prevent export failures
- Video composition handles proper transform and orientation adjustments
- Export operations use dispatch groups for coordinating concurrent video/audio processing
- Progress is calculated based on presentation timestamps relative to duration