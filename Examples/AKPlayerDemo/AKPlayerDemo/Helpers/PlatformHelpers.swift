//
//   PlatformHelpers.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AKPlayer
import SwiftUI

public extension View {
    @ViewBuilder
    func adaptiveInlineNavigationBarTitle() -> some View {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            self.navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }

    @ViewBuilder
    func adaptiveLargeNavigationBarTitle() -> some View {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            self.navigationBarTitleDisplayMode(.large)
        #else
            self
        #endif
    }

    @ViewBuilder
    func adaptiveFullScreenCover<Item: Identifiable>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> some View
    ) -> some View {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            self.fullScreenCover(item: item, onDismiss: onDismiss, content: content)
        #else
            self.sheet(item: item, onDismiss: onDismiss) { item in
                content(item)
                    .frame(minWidth: 700, minHeight: 600)
            }
        #endif
    }

    @ViewBuilder
    func adaptiveFullScreenCover(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            self.fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #else
            self.sheet(isPresented: isPresented, onDismiss: onDismiss) {
                content()
                    .frame(minWidth: 700, minHeight: 600)
            }
        #endif
    }

    @ViewBuilder
    func adaptiveAutocapitalizationNever() -> some View {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            self.textInputAutocapitalization(.never)
        #else
            self
        #endif
    }
}

public extension Image {
    init(platformImage: AKPlatformImage) {
        #if canImport(UIKit)
            self.init(uiImage: platformImage)
        #elseif canImport(AppKit)
            self.init(nsImage: platformImage)
        #endif
    }
}
