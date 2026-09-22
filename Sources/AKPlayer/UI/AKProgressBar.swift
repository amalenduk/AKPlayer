//
//   AKProgressBar.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

#if canImport(SwiftUI)
import SwiftUI

// MARK: - AKProgressBarConfiguration

/// Configuration styling parameters for `AKProgressBar`.
public struct AKProgressBarConfiguration: Sendable, Equatable {
    /// The height of the default inactive progress track.
    public var trackHeight: CGFloat
    /// The height of the progress track while scrubbing.
    public var activeTrackHeight: CGFloat
    /// The diameter of the circular scrubber thumb.
    public var thumbDiameter: CGFloat
    /// The background fill color of the progress track.
    public var trackBackgroundColor: Color
    /// The fill color representing buffered playback progress.
    public var bufferTrackColor: Color
    /// The fill color representing active playback progress.
    public var progressTrackColor: Color
    /// The tint color for unplayed interstitial cue point markers.
    public var unplayedMarkerColor: Color
    /// The tint color for the currently active interstitial marker.
    public var activeMarkerColor: Color
    /// The tint color for already completed interstitial markers.
    public var playedMarkerColor: Color
    /// The fill color for ad duration ranges along the track.
    public var fillMarkerColor: Color
    /// The diameter of individual cue point marker dots.
    public var markerDiameter: CGFloat
    /// The fractional scrubbing distance threshold for magnetic snapping to ad cue points.
    public var snapThresholdFraction: Double
    /// Whether scrubbing automatically snaps to nearby ad cue markers.
    public var enableSnapping: Bool
    /// Whether forward scrubbing restrictions past unplayed interstitials are enforced.
    public var enforceRestrictions: Bool
    
    /// Initializes a progress bar configuration with custom styling parameters.
    /// - Parameters:
    ///   - trackHeight: The height of the default inactive progress track.
    ///   - activeTrackHeight: The height of the progress track while scrubbing.
    ///   - thumbDiameter: The diameter of the circular scrubber thumb.
    ///   - trackBackgroundColor: The background fill color of the progress track.
    ///   - bufferTrackColor: The fill color representing buffered playback progress.
    ///   - progressTrackColor: The fill color representing active playback progress.
    ///   - unplayedMarkerColor: The tint color for unplayed interstitial cue point markers.
    ///   - activeMarkerColor: The tint color for the currently active interstitial marker.
    ///   - playedMarkerColor: The tint color for already completed interstitial markers.
    ///   - fillMarkerColor: The fill color for ad duration ranges along the track.
    ///   - markerDiameter: The diameter of individual cue point marker dots.
    ///   - snapThresholdFraction: The fractional scrubbing distance threshold for magnetic snapping.
    ///   - enableSnapping: Whether scrubbing automatically snaps to nearby ad cue markers.
    ///   - enforceRestrictions: Whether forward scrubbing restrictions past unplayed interstitials are enforced.
    public init(
        trackHeight: CGFloat = 4,
        activeTrackHeight: CGFloat = 6,
        thumbDiameter: CGFloat = 14,
        trackBackgroundColor: Color = Color(.systemGray5),
        bufferTrackColor: Color = Color(.systemGray3),
        progressTrackColor: Color = .accentColor,
        unplayedMarkerColor: Color = Color(red: 0.98, green: 0.76, blue: 0.03),
        activeMarkerColor: Color = Color(red: 0.98, green: 0.55, blue: 0.0),
        playedMarkerColor: Color = Color.gray.opacity(0.5),
        fillMarkerColor: Color = Color(red: 0.98, green: 0.76, blue: 0.03).opacity(0.70),
        markerDiameter: CGFloat = 6,
        snapThresholdFraction: Double = 0.02,
        enableSnapping: Bool = true,
        enforceRestrictions: Bool = true
    ) {
        self.trackHeight = trackHeight
        self.activeTrackHeight = activeTrackHeight
        self.thumbDiameter = thumbDiameter
        self.trackBackgroundColor = trackBackgroundColor
        self.bufferTrackColor = bufferTrackColor
        self.progressTrackColor = progressTrackColor
        self.unplayedMarkerColor = unplayedMarkerColor
        self.activeMarkerColor = activeMarkerColor
        self.playedMarkerColor = playedMarkerColor
        self.fillMarkerColor = fillMarkerColor
        self.markerDiameter = markerDiameter
        self.snapThresholdFraction = snapThresholdFraction
        self.enableSnapping = enableSnapping
        self.enforceRestrictions = enforceRestrictions
    }
}

// MARK: - AKProgressBar

/// A modern, interactive progress bar for playback scrubbing with interactive ad cue markers.
public struct AKProgressBar: View {
    
    // MARK: - Inputs
    
    /// The current playback timestamp in seconds.
    private let currentTime: Double
    /// The total media duration in seconds.
    private let duration: Double
    /// The loaded buffer fraction between 0.0 and 1.0.
    private let bufferProgress: Double
    /// Collection of interstitial cue markers to display along the track.
    private let markers: [AKInterstitialMarker]
    /// Styling and behavior configuration for the progress bar.
    private let configuration: AKProgressBarConfiguration
    /// Closure invoked with the targeted playback timestamp when scrubbing commits.
    private let onSeek: @MainActor (Double) -> Void
    
    // MARK: - Internal State
    
    @State private var isDragging: Bool = false
    @State private var dragFraction: Double = 0.0
    @State private var hoveredMarker: AKInterstitialMarker?
    @State private var isRestrictedAtMarker: Bool = false
    
    /// Initializes an interactive playback progress bar.
    /// - Parameters:
    ///   - currentTime: The current playback timestamp in seconds.
    ///   - duration: The total media duration in seconds.
    ///   - bufferProgress: The loaded buffer fraction between 0.0 and 1.0.
    ///   - markers: Collection of interstitial cue markers to display along the track.
    ///   - configuration: Styling and behavior configuration for the progress bar.
    ///   - onSeek: Closure invoked with the targeted playback timestamp when scrubbing commits.
    public init(
        currentTime: Double,
        duration: Double,
        bufferProgress: Double = 0.0,
        markers: [AKInterstitialMarker] = [],
        configuration: AKProgressBarConfiguration = AKProgressBarConfiguration(),
        onSeek: @escaping @MainActor (Double) -> Void
    ) {
        self.currentTime = currentTime
        self.duration = max(0, duration)
        self.bufferProgress = max(0, min(1, bufferProgress))
        self.markers = markers
        self.configuration = configuration
        self.onSeek = onSeek
    }
    
    // MARK: - Body
    
    /// The body view rendering the interactive progress bar track, buffer, ad markers, chapters, and thumb.
    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let currentFraction = duration > 0 ? max(0, min(1, currentTime / duration)) : 0.0
            let effectiveFraction = isDragging ? dragFraction : currentFraction
            let currentHeight = isDragging ? configuration.activeTrackHeight : configuration.trackHeight
            
            ZStack(alignment: .leading) {
                // 1. Background Track
                Capsule()
                    .fill(configuration.trackBackgroundColor)
                    .frame(height: currentHeight)
                
                // 2. Buffer Track
                if bufferProgress > 0 {
                    Capsule()
                        .fill(configuration.bufferTrackColor)
                        .frame(width: max(0, width * CGFloat(bufferProgress)), height: currentHeight)
                }
                
                // 3. Ad Fill Ranges
                adFillRangesView(width: width, height: currentHeight)
                
                // 4. Progress Track
                Capsule()
                    .fill(configuration.progressTrackColor)
                    .frame(width: max(0, width * CGFloat(effectiveFraction)), height: currentHeight)
                
                // 5. Ad Cue Point Markers
                adCueMarkersView(width: width)
                
                // 6. Scrubber Thumb
                scrubberThumbView(width: width, fraction: effectiveFraction)
                
                // 7. Preview Tooltip when Dragging
                if isDragging {
                    previewTooltip(width: width, fraction: effectiveFraction)
                }
            }
            .frame(height: 32)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChanged(value: value, width: width)
                    }
                    .onEnded { _ in
                        handleDragEnded()
                    }
            )
        }
        .frame(height: 32)
    }
    
    // MARK: - Ad Fill Ranges
    
    /// Generates views representing interstitial ad range fill blocks on the track.
    /// - Parameters:
    ///   - width: The total pixel width of the progress bar track.
    ///   - height: The pixel height of the track.
    /// - Returns: A view displaying filled rectangles across ad duration intervals.
    @ViewBuilder
    private func adFillRangesView(width: CGFloat, height: CGFloat) -> some View {
        if duration > 0 {
            ForEach(markers.filter { $0.isFill }) { marker in
                let startFraction = max(0, min(1, marker.time / duration))
                let segmentDuration = marker.duration ?? 0
                let endFraction = max(startFraction, min(1, (marker.time + segmentDuration) / duration))
                let segmentWidth = max(2, width * CGFloat(endFraction - startFraction))
                let offset = width * CGFloat(startFraction)
                
                let fillColor: Color = {
                    if marker.isCurrent {
                        return configuration.activeMarkerColor.opacity(0.85)
                    } else if marker.isPlayed {
                        return configuration.playedMarkerColor.opacity(0.4)
                    } else {
                        return configuration.fillMarkerColor
                    }
                }()
                
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(fillColor)
                    .frame(width: segmentWidth, height: height)
                    .offset(x: offset)
            }
        }
    }
    
    // MARK: - Ad Cue Point Markers
    
    /// Generates views representing discrete interstitial cue point dots along the track.
    /// - Parameter width: The total pixel width of the progress bar track.
    /// - Returns: A view rendering circular cue point indicators.
    @ViewBuilder
    private func adCueMarkersView(width: CGFloat) -> some View {
        if duration > 0 {
            ForEach(markers.filter { $0.isSinglePoint }) { marker in
                let markerFraction = max(0, min(1, marker.time / duration))
                let xPosition = width * CGFloat(markerFraction)
                let markerColor: Color = {
                    if marker.isCurrent {
                        return configuration.activeMarkerColor
                    } else if marker.isPlayed {
                        return configuration.playedMarkerColor
                    } else {
                        return configuration.unplayedMarkerColor
                    }
                }()
                
                ZStack {
                    Circle()
                        .fill(markerColor)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.2), lineWidth: 0.75)
                        )
                        .frame(
                            width: marker.isCurrent ? configuration.markerDiameter + 2 : configuration.markerDiameter,
                            height: marker.isCurrent ? configuration.markerDiameter + 2 : configuration.markerDiameter
                        )
                        .shadow(
                            color: markerColor.opacity(marker.isPlayed ? 0.0 : 0.8),
                            radius: marker.isCurrent ? 4 : 2
                        )
                }
                .position(x: xPosition, y: 16)
            }
        }
    }
    
    // MARK: - Scrubber Thumb
    
    /// Generates the circular scrubber thumb positioned at the current or dragged playback fraction.
    /// - Parameters:
    ///   - width: The total pixel width of the progress bar track.
    ///   - fraction: The fractional position between 0.0 and 1.0.
    /// - Returns: A view representing the interactive draggable scrubber handle.
    @ViewBuilder
    private func scrubberThumbView(width: CGFloat, fraction: Double) -> some View {
        let xPosition = width * CGFloat(fraction)
        
        Circle()
            .fill(isRestrictedAtMarker ? Color.orange : Color.white)
            .frame(
                width: isDragging ? configuration.thumbDiameter + 4 : configuration.thumbDiameter,
                height: isDragging ? configuration.thumbDiameter + 4 : configuration.thumbDiameter
            )
            .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
            .position(x: xPosition, y: 16)
            .animation(.easeInOut(duration: 0.1), value: isDragging)
    }
    
    // MARK: - Preview Tooltip
    
    /// Generates a floating timestamp and restriction preview badge above the scrubber thumb.
    /// - Parameters:
    ///   - width: The total pixel width of the progress bar track.
    ///   - fraction: The current fractional position.
    /// - Returns: A view presenting timestamp and ad warning badge.
    @ViewBuilder
    private func previewTooltip(width: CGFloat, fraction: Double) -> some View {
        let targetSeconds = fraction * duration
        let xPosition = max(35, min(width - 35, width * CGFloat(fraction)))
        
        VStack(spacing: 2) {
            Text(formatTime(targetSeconds))
                .font(.caption2.bold())
                .foregroundColor(.white)
            
            if isRestrictedAtMarker {
                HStack(spacing: 2) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                    Text("Ad Required")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(.yellow)
            } else if let marker = hoveredMarker {
                Text(marker.title ?? "Ad Break")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.yellow)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.85))
        .cornerRadius(6)
        .position(x: xPosition, y: -16)
    }
    
    // MARK: - Gesture Handling
    
    /// Processes drag gesture updates, applying seeking constraints and snapping logic.
    /// - Parameters:
    ///   - value: The drag gesture location update.
    ///   - width: The total width of the track.
    private func handleDragChanged(value: DragGesture.Value, width: CGFloat) {
        guard width > 0, duration > 0 else { return }
        isDragging = true
        
        var rawFraction = max(0, min(1, Double(value.location.x / width)))
        var restricted = false
        var matchedMarker: AKInterstitialMarker?
        
        // 1. Check restrictions: Cannot seek past unplayed ad with .constrainsSeekingForwardInPrimaryContent
        if configuration.enforceRestrictions {
            let currentSec = currentTime
            let targetSec = rawFraction * duration
            
            if targetSec > currentSec {
                // Moving forward: Find first unplayed constrained marker between currentSec and targetSec
                let blockingMarker = markers.first { marker in
                    !marker.isPlayed &&
                    !marker.canSeek &&
                    marker.time > currentSec &&
                    marker.time <= targetSec
                }
                
                if let blockingMarker {
                    let markerFraction = blockingMarker.time / duration
                    rawFraction = markerFraction
                    restricted = true
                    matchedMarker = blockingMarker
                }
            }
        }
        
        // 2. Snapping: Snap to nearby ad markers within threshold
        if configuration.enableSnapping && !restricted {
            for marker in markers {
                let markerFraction = marker.time / duration
                if abs(rawFraction - markerFraction) <= configuration.snapThresholdFraction {
                    rawFraction = markerFraction
                    matchedMarker = marker
                    break
                }
            }
        }
        
        dragFraction = rawFraction
        hoveredMarker = matchedMarker
        isRestrictedAtMarker = restricted
    }
    
    /// Commits final scrubbing position and invokes the seek completion callback.
    private func handleDragEnded() {
        isDragging = false
        isRestrictedAtMarker = false
        hoveredMarker = nil
        let targetSeconds = dragFraction * duration
        onSeek(targetSeconds)
    }
    
    // MARK: - Helpers
    
    /// Formats numeric seconds into MM:SS display time strings.
    /// - Parameter seconds: The time in seconds to format.
    /// - Returns: A formatted string `MM:SS`.
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else { return "--:--" }
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
#endif
