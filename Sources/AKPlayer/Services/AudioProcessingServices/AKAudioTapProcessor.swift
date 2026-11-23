//
//   AKAudioTapProcessor.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Accelerate
import AVFoundation
import Foundation
import MediaToolbox

// MARK: - AKAudioTapProcessorDelegate

/// Delegate protocol receiving real-time audio spectrum magnitudes and silence events.
@MainActor
public protocol AKAudioTapProcessorDelegate: AnyObject, Sendable {
    /// Notifies the delegate of real-time FFT frequency spectrum levels.
    /// - Parameters:
    ///   - processor: The audio tap processor instance.
    ///   - spectrum: Array of normalized frequency band magnitudes (`0.0 ... 1.0`).
    func audioTapProcessor(_ processor: AKAudioTapProcessor, didUpdateSpectrum spectrum: [Float])

    /// Notifies the delegate when silence state transitions occur.
    /// - Parameters:
    ///   - processor: The audio tap processor instance.
    ///   - isSilent: `true` if sustained silence is detected, `false` when active sound resumes.
    ///   - rms: The current root-mean-square audio energy level.
    func audioTapProcessor(
        _ processor: AKAudioTapProcessor,
        didDetectSilence isSilent: Bool,
        rms: Float
    )
}

// MARK: - AKAudioTapContext (Internal CoreAudio Thread Storage)

private final class AKAudioTapContext: @unchecked Sendable {
    // Parameters (accessed across threads via synchronized locks or direct read)
    var boostFactor: Float = 1.0
    var isSmartSpeedEnabled = false
    var silenceThresholdRMS: Float = 0.01
    var silenceDurationThreshold: TimeInterval = 0.15

    // FFT & Spectrum Configuration
    let fftSize = 1024
    let bandCount = 32
    var fftSetup: vDSP_DFT_Setup?
    var window: [Float]
    var inputReal: [Float]
    var inputImag: [Float]
    var outputReal: [Float]
    var outputImag: [Float]
    var magnitudes: [Float]
    var smoothedBands: [Float]

    // Sample rate & silence tracking
    var sampleRate = 44100.0
    var silenceFramesAccumulated = 0
    var isCurrentlySilent = false

    /// Throttled UI dispatch (~40 Hz)
    var lastDispatchTimestamp: TimeInterval = 0

    weak var delegate: (any AKAudioTapProcessorDelegate)?
    weak var processor: AKAudioTapProcessor?

    init() {
        let size = 1024
        let bands = 32
        self.fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(size), .FORWARD)

        // Precompute Hann window
        var win = [Float](repeating: 0, count: size)
        vDSP_hann_window(&win, vDSP_Length(size), Int32(vDSP_HANN_NORM))
        self.window = win

        self.inputReal = [Float](repeating: 0, count: size)
        self.inputImag = [Float](repeating: 0, count: size)
        self.outputReal = [Float](repeating: 0, count: size)
        self.outputImag = [Float](repeating: 0, count: size)
        self.magnitudes = [Float](repeating: 0, count: size / 2)
        self.smoothedBands = [Float](repeating: 0, count: bands)
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
}

// MARK: - AKAudioTapProcessor

/// Real-time audio digital signal processing engine attached to `AVPlayerItem` via
/// `MTAudioProcessingTap`.
///
/// Powers three core media enhancements:
/// 1. **Audio Boost (Up to 200%)**: Software volume gain scaling float PCM samples with smooth
/// soft-clipping limiter.
/// 2. **Smart Speed (Auto-Skip Silence)**: Sub-millisecond RMS silence detection for accelerating
/// through lecture/podcast pauses.
/// 3. **Real-time Frequency Spectrum Visualizer**: Fast Fourier Transform (vDSP DFT) calculating
/// live frequency bins.
public final class AKAudioTapProcessor: @unchecked Sendable {
    // MARK: - Public Properties

    /// Real-time audio tap delegate receiving spectrum and silence updates.
    public weak var delegate: (any AKAudioTapProcessorDelegate)? {
        didSet {
            context.delegate = delegate
        }
    }

    /// Software volume boost factor.
    /// Ranges from `1.0` (100% standard hardware volume) up to `2.0` (200% volume boost).
    public var audioBoost: Float {
        get { context.boostFactor }
        set { context.boostFactor = max(1.0, min(2.0, newValue)) }
    }

    /// Flag enabling or disabling Smart Speed silence detection.
    public var isSmartSpeedEnabled: Bool {
        get { context.isSmartSpeedEnabled }
        set {
            context.isSmartSpeedEnabled = newValue
            if !newValue {
                context.isCurrentlySilent = false
                context.silenceFramesAccumulated = 0
            }
        }
    }

    /// The root-mean-square (RMS) amplitude threshold below which audio is classified as silent.
    /// Defaults to `0.01` (~ -40 dBFS).
    public var silenceThresholdRMS: Float {
        get { context.silenceThresholdRMS }
        set { context.silenceThresholdRMS = max(0.0001, newValue) }
    }

    /// Minimum continuous duration of silence (in seconds) required before triggering silence
    /// transition.
    /// Defaults to `0.15` seconds (150 ms).
    public var silenceDurationThreshold: TimeInterval {
        get { context.silenceDurationThreshold }
        set { context.silenceDurationThreshold = max(0.05, newValue) }
    }

    /// Current frequency spectrum band magnitudes (`0.0 ... 1.0`).
    public private(set) var currentSpectrum = [Float](repeating: 0, count: 32)

    /// Indicates whether audio is currently detected as silent.
    public var isSilence: Bool {
        context.isCurrentlySilent
    }

    // MARK: - Internal Storage

    private let context: AKAudioTapContext
    private var tap: MTAudioProcessingTap?
    private var activeItem: AVPlayerItem?

    // MARK: - Initialization

    /// Initializes a new audio tap processor.
    public init() {
        self.context = AKAudioTapContext()
        self.context.processor = self
        setupTap()
    }

    deinit {
        tearDownTap()
    }

    // MARK: - Tap Lifecycle

    private func setupTap() {
        let unmanagedContext = Unmanaged.passRetained(context)

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: unmanagedContext.toOpaque(),
            init: { _, clientInfo, tapStorageOut in
                tapStorageOut.pointee = clientInfo
            },
            finalize: { tap in
                let clientInfo = MTAudioProcessingTapGetStorage(tap)
                Unmanaged<AKAudioTapContext>.fromOpaque(clientInfo).release()
            },
            prepare: { tap, _, processingFormat in
                let clientInfo = MTAudioProcessingTapGetStorage(tap)
                let ctx = Unmanaged<AKAudioTapContext>.fromOpaque(clientInfo).takeUnretainedValue()
                ctx.sampleRate = processingFormat.pointee.mSampleRate > 0 ? processingFormat.pointee
                    .mSampleRate : 44100.0
            },
            unprepare: { tap in
                // Clean state on audio stop
                let clientInfo = MTAudioProcessingTapGetStorage(tap)
                let ctx = Unmanaged<AKAudioTapContext>.fromOpaque(clientInfo).takeUnretainedValue()
                ctx.isCurrentlySilent = false
                ctx.silenceFramesAccumulated = 0
            },
            process: { tap, numberFrames, _, bufferListInOut, numberFramesOut, flagsOut in
                let clientInfo = MTAudioProcessingTapGetStorage(tap)
                let ctx = Unmanaged<AKAudioTapContext>.fromOpaque(clientInfo).takeUnretainedValue()

                // Fetch source audio PCM samples
                let status = MTAudioProcessingTapGetSourceAudio(
                    tap,
                    numberFrames,
                    bufferListInOut,
                    flagsOut,
                    nil,
                    numberFramesOut
                )
                guard status == noErr else { return }

                let frameCount = Int(numberFrames)
                guard frameCount > 0 else { return }

                let buffers = UnsafeMutableAudioBufferListPointer(bufferListInOut)
                guard !buffers.isEmpty else { return }

                var totalRMS: Float = 0.0
                var activeChannels = 0

                // 1. Audio Boost (Software Gain + Limiter)
                let boost = ctx.boostFactor
                for buffer in buffers {
                    guard let mData = buffer.mData else { continue }
                    let samples = mData.assumingMemoryBound(to: Float.self)

                    if boost > 1.0 {
                        var factor = boost
                        vDSP_vsmul(samples, 1, &factor, samples, 1, vDSP_Length(frameCount))

                        // Soft-clipping limiter to avoid harsh digital square clipping
                        for i in 0 ..< frameCount {
                            let s = samples[i]
                            if s > 0.95 {
                                samples[i] = 0.95 + 0.05 * tanhf((s - 0.95) / 0.05)
                            } else if s < -0.95 {
                                samples[i] = -0.95 + 0.05 * tanhf((s + 0.95) / 0.05)
                            }
                        }
                    }

                    // 2. RMS Energy calculation
                    var rms: Float = 0.0
                    vDSP_rmsqv(samples, 1, &rms, vDSP_Length(frameCount))
                    totalRMS += rms
                    activeChannels += 1
                }

                // Smart Speed Silence Detection
                let avgRMS = activeChannels > 0 ? (totalRMS / Float(activeChannels)) : 0.0
                if ctx.isSmartSpeedEnabled {
                    if avgRMS < ctx.silenceThresholdRMS {
                        ctx.silenceFramesAccumulated += frameCount
                        let durationInSilence = Double(ctx.silenceFramesAccumulated) / ctx
                            .sampleRate
                        if durationInSilence >= ctx.silenceDurationThreshold,
                           !ctx.isCurrentlySilent
                        {
                            ctx.isCurrentlySilent = true
                            DispatchQueue.main.async { [weak ctx] in
                                guard let ctx, let processor = ctx.processor else { return }
                                ctx.delegate?.audioTapProcessor(
                                    processor,
                                    didDetectSilence: true,
                                    rms: avgRMS
                                )
                            }
                        }
                    } else {
                        ctx.silenceFramesAccumulated = 0
                        if ctx.isCurrentlySilent {
                            ctx.isCurrentlySilent = false
                            DispatchQueue.main.async { [weak ctx] in
                                guard let ctx, let processor = ctx.processor else { return }
                                ctx.delegate?.audioTapProcessor(
                                    processor,
                                    didDetectSilence: false,
                                    rms: avgRMS
                                )
                            }
                        }
                    }
                }

                // 3. FFT Frequency Spectrum Analysis
                if let firstBuffer = buffers.first, let mData = firstBuffer.mData,
                   let fftSetup = ctx.fftSetup
                {
                    let samples = mData.assumingMemoryBound(to: Float.self)
                    let fftSize = ctx.fftSize
                    let processLength = min(frameCount, fftSize)

                    if processLength >= 64 {
                        // Apply Hann window
                        vDSP_vmul(
                            samples,
                            1,
                            ctx.window,
                            1,
                            &ctx.inputReal,
                            1,
                            vDSP_Length(processLength)
                        )
                        if processLength < fftSize {
                            for i in processLength ..< fftSize {
                                ctx.inputReal[i] = 0
                            }
                        }
                        vDSP_vclr(&ctx.inputImag, 1, vDSP_Length(fftSize))

                        // Compute Forward DFT
                        vDSP_DFT_Execute(
                            fftSetup,
                            &ctx.inputReal,
                            &ctx.inputImag,
                            &ctx.outputReal,
                            &ctx.outputImag
                        )

                        // Calculate magnitudes
                        let halfSize = fftSize / 2
                        for i in 0 ..< halfSize {
                            let r = ctx.outputReal[i]
                            let im = ctx.outputImag[i]
                            ctx.magnitudes[i] = sqrtf(r * r + im * im) / Float(halfSize)
                        }

                        // Aggregate into 32 logarithmic frequency bands
                        let bandCount = ctx.bandCount
                        for b in 0 ..< bandCount {
                            let startBin = Int(pow(Double(halfSize), Double(b) / Double(bandCount)))
                            let endBin = max(
                                startBin + 1,
                                Int(pow(Double(halfSize), Double(b + 1) / Double(bandCount)))
                            )
                            let actualEnd = min(endBin, halfSize)
                            let binSpan = max(1, actualEnd - startBin)

                            var sum: Float = 0
                            for k in startBin ..< actualEnd {
                                sum += ctx.magnitudes[k]
                            }
                            let rawBand = min(1.0, (sum / Float(binSpan)) * 3.5)

                            // Fast attack (1.0), smooth decay (0.80)
                            ctx.smoothedBands[b] = max(rawBand, ctx.smoothedBands[b] * 0.80)
                        }

                        // Throttled UI dispatch (~40 updates per second)
                        let now = ProcessInfo.processInfo.systemUptime
                        if now - ctx.lastDispatchTimestamp >= 0.025 {
                            ctx.lastDispatchTimestamp = now
                            let bandsSnapshot = ctx.smoothedBands
                            DispatchQueue.main.async { [weak ctx] in
                                guard let ctx, let processor = ctx.processor else { return }
                                processor.currentSpectrum = bandsSnapshot
                                ctx.delegate?.audioTapProcessor(
                                    processor,
                                    didUpdateSpectrum: bandsSnapshot
                                )
                            }
                        }
                    }
                }
            }
        )

        var newTap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PreEffects,
            &newTap
        )
        if status == noErr {
            self.tap = newTap
        }
    }

    private func tearDownTap() {
        tap = nil
        activeItem = nil
    }

    // MARK: - PlayerItem Attachment

    /// Attaches the audio tap processor to an `AVPlayerItem` across all available audio tracks.
    /// - Parameters:
    ///   - playerItem: The target player item.
    ///   - asset: The underlying asset for audio track resolution.
    @MainActor
    public func attach(to playerItem: AVPlayerItem, for asset: AVAsset) {
        guard let tap else { return }
        self.activeItem = playerItem

        // Asynchronously load tracks and bind audio mix parameters
        Task { [weak self, weak playerItem] in
            guard let self, let playerItem else { return }
            do {
                let loadedTracks = try await asset.loadTracks(withMediaType: .audio)
                await MainActor.run {
                    guard self.activeItem == playerItem else { return }
                    self.applyMix(to: playerItem, tracks: loadedTracks, tap: tap)
                }
            } catch {
                await MainActor.run {
                    guard self.activeItem == playerItem else { return }
                    self.applyMix(to: playerItem, tracks: [], tap: tap)
                }
            }
        }
    }

    @MainActor
    private func applyMix(
        to playerItem: AVPlayerItem,
        tracks: [AVAssetTrack],
        tap: MTAudioProcessingTap
    ) {
        let inputParameters: [AVMutableAudioMixInputParameters]
        if !tracks.isEmpty {
            inputParameters = tracks.map { track in
                let params = AVMutableAudioMixInputParameters(track: track)
                params.audioTapProcessor = tap
                return params
            }
        } else {
            let params = AVMutableAudioMixInputParameters()
            params.audioTapProcessor = tap
            inputParameters = [params]
        }

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = inputParameters
        playerItem.audioMix = audioMix
    }

    /// Detaches the audio tap processor from the player item.
    @MainActor
    public func detach(from playerItem: AVPlayerItem) {
        if playerItem.audioMix != nil {
            playerItem.audioMix = nil
        }
        if activeItem == playerItem {
            activeItem = nil
        }
    }
}
