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
    public var trackHeight: CGFloat
    public var activeTrackHeight: CGFloat
    public var thumbDiameter: CGFloat
    public var trackBackgroundColor: Color
    public var bufferTrackColor: Color
    public var progressTrackColor: Color
    public var unplayedMarkerColor: Color
    public var activeMarkerColor: Color
    public var playedMarkerColor: Color
    public var fillMarkerColor: Color
    public var markerDiameter: CGFloat
    public var snapThresholdFraction: Double
    public var enableSnapping: Bool
    public var enforceRestrictions: Bool
    
    public init(
        trackHeight: CGFloat = 4,
        activeTrackHeight: CGFloat = 6,
        thumbDiameter: CGFloat = 14,
        trackBackgroundColor: Color = Color(.systemGray5),
        bufferTrackColor: Color = Color(.systemGray3),
        progressTrackColor: Color = .accentColor,
        unplayedMarkerColor: Color = Color.yellow,
        activeMarkerColor: Color = Color.orange,
        playedMarkerColor: Color = Color.gray.opacity(0.6),
        fillMarkerColor: Color = Color.yellow.opacity(0.35),
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
    
    private let currentTime: Double
    private let duration: Double
    private let bufferProgress: Double
    private let markers: [AKInterstitialMarker]
    private let configuration: AKProgressBarConfiguration
    private let onSeek: @MainActor (Double) -> Void
    
    // MARK: - Internal State
    
    @State private var isDragging: Bool = false
    @State private var dragFraction: Double = 0.0
    @State private var hoveredMarker: AKInterstitialMarker?
    @State private var isRestrictedAtMarker: Bool = false
    
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
                        return configuration.activeMarkerColor.opacity(0.6)
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
                        .frame(
                            width: marker.isCurrent ? configuration.markerDiameter + 2 : configuration.markerDiameter,
                            height: marker.isCurrent ? configuration.markerDiameter + 2 : configuration.markerDiameter
                        )
                        .shadow(
                            color: markerColor.opacity(marker.isPlayed ? 0.0 : 0.6),
                            radius: marker.isCurrent ? 4 : 2
                        )
                }
                .position(x: xPosition, y: 16)
            }
        }
    }
    
    // MARK: - Scrubber Thumb
    
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
    
    private func handleDragEnded() {
        isDragging = false
        isRestrictedAtMarker = false
        hoveredMarker = nil
        let targetSeconds = dragFraction * duration
        onSeek(targetSeconds)
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else { return "--:--" }
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
#endif
