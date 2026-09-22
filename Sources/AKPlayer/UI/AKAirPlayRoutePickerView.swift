//
//   AKAirPlayRoutePickerView.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVKit
import SwiftUI

#if canImport(UIKit)
    import UIKit

    // MARK: - AKAirPlayRoutePickerView

    /// A SwiftUI wrapper around `AVRoutePickerView` that displays the standard system
    /// AirPlay route picker button.
    ///
    /// Tapping this view triggers the native iOS AirPlay route selection menu to
    /// route audio/video to external AirPlay, Bluetooth, or wireless speaker endpoints.
    public struct AKAirPlayRoutePickerView: UIViewRepresentable {
        // MARK: - Properties

        /// The unselected/normal tint color of the AirPlay button.
        public var tintColor: UIColor

        /// The active tint color applied when an external route (e.g. AirPlay) is connected.
        public var activeTintColor: UIColor

        /// Whether the route picker prioritizes video routing endpoints.
        public var prioritizesVideoDevices: Bool

        // MARK: - Initialization

        /// Creates a new AirPlay route picker view.
        /// - Parameters:
        ///   - tintColor: The unselected tint color. Defaults to `.white`.
        ///   - activeTintColor: The active tint color when connected. Defaults to `.systemYellow`.
        ///   - prioritizesVideoDevices: Whether video devices should be prioritized. Defaults to
        /// `false`.
        public init(
            tintColor: UIColor = .white,
            activeTintColor: UIColor = .systemYellow,
            prioritizesVideoDevices: Bool = false
        ) {
            self.tintColor = tintColor
            self.activeTintColor = activeTintColor
            self.prioritizesVideoDevices = prioritizesVideoDevices
        }

        // MARK: - UIViewRepresentable

        public func makeUIView(context _: Context) -> AVRoutePickerView {
            let picker = AVRoutePickerView()
            picker.tintColor = tintColor
            picker.activeTintColor = activeTintColor
            picker.prioritizesVideoDevices = prioritizesVideoDevices
            picker.backgroundColor = .clear
            return picker
        }

        public func updateUIView(_ uiView: AVRoutePickerView, context _: Context) {
            uiView.tintColor = tintColor
            uiView.activeTintColor = activeTintColor
            uiView.prioritizesVideoDevices = prioritizesVideoDevices
        }
    }
#endif
