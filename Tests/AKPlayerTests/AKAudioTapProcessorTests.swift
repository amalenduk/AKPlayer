//
//   AKAudioTapProcessorTests.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

@testable import AKPlayer
import AVFoundation
import Testing

@MainActor
struct AKAudioTapProcessorTests {
    @Test func audioTapProcessorConfigurationAndClamping() {
        let processor = AKAudioTapProcessor()

        #expect(processor.audioBoost == 1.0)
        #expect(!processor.isSmartSpeedEnabled)
        #expect(processor.silenceThresholdRMS == 0.01)
        #expect(processor.silenceDurationThreshold == 0.15)
        #expect(processor.currentSpectrum.count == 32)
        #expect(!processor.isSilence)

        // Boost clamping: 1.0 ... 2.0
        processor.audioBoost = 1.75
        #expect(processor.audioBoost == 1.75)

        processor.audioBoost = 0.5
        #expect(processor.audioBoost == 1.0)

        processor.audioBoost = 2.5
        #expect(processor.audioBoost == 2.0)

        // Dialogue Clarity toggle
        #expect(!processor.isDialogueClarityEnabled)
        processor.isDialogueClarityEnabled = true
        #expect(processor.isDialogueClarityEnabled)

        // Smart Speed toggle
        processor.isSmartSpeedEnabled = true
        #expect(processor.isSmartSpeedEnabled)

        processor.silenceThresholdRMS = 0.025
        #expect(processor.silenceThresholdRMS == 0.025)

        processor.silenceDurationThreshold = 0.20
        #expect(processor.silenceDurationThreshold == 0.20)
    }

    @Test func playerConfigurationAudioTapDefaults() {
        let config = AKPlayerConfiguration()

        #expect(config.isAudioTapEnabled)
        #expect(config.audioBoost == 1.0)
        #expect(!config.isSmartSpeedEnabled)
        #expect(!config.isDialogueClarityEnabled)
        #expect(config.smartSpeedRate == 2.0)
        #expect(config.silenceThresholdRMS == 0.01)
        #expect(config.silenceDurationThreshold == 0.15)
    }

    @Test func playerControllerAudioProcessingPropertiesAndEvents() throws {
        let player = AVPlayer()
        var config = AKPlayerConfiguration()
        config.isAudioTapEnabled = true
        config.audioBoost = 1.25

        let controller = AKPlayerController(player: player, configuration: config)
        try controller.prepare()

        #expect(controller.audioTapProcessor != nil)
        #expect(controller.audioBoost == 1.25)
        #expect(!controller.isSmartSpeedEnabled)
        #expect(controller.smartSpeedRate == 2.0)
        #expect(controller.smartSpeedSavedTime == 0)
        #expect(controller.spectrumBands.isEmpty)

        // Dynamic adjustment
        controller.audioBoost = 1.80
        #expect(controller.audioBoost == 1.80)
        #expect(controller.audioTapProcessor?.audioBoost == 1.80)

        controller.isSmartSpeedEnabled = true
        #expect(controller.isSmartSpeedEnabled)
        #expect(controller.audioTapProcessor?.isSmartSpeedEnabled == true)

        controller.isDialogueClarityEnabled = true
        #expect(controller.isDialogueClarityEnabled)
        #expect(controller.audioTapProcessor?.isDialogueClarityEnabled == true)

        controller.smartSpeedRate = 2.5
        #expect(controller.smartSpeedRate == 2.5)
    }

    @Test func playerObservableAudioProcessingIntegration() {
        let player = AKPlayer()
        let observable = AKPlayerObservable(player: player)

        #expect(observable.audioBoost == 1.0)
        #expect(!observable.isSmartSpeedEnabled)
        #expect(observable.smartSpeedRate == 2.0)
        #expect(observable.smartSpeedSavedTime == 0)
        #expect(observable.spectrumBands.isEmpty)

        observable.setAudioBoost(1.5)
        #expect(player.audioBoost == 1.5)

        observable.setSmartSpeedEnabled(true)
        #expect(player.isSmartSpeedEnabled)

        observable.setDialogueClarityEnabled(true)
        #expect(player.isDialogueClarityEnabled)
        #expect(observable.isDialogueClarityEnabled)

        observable.setSmartSpeedRate(2.25)
        #expect(player.smartSpeedRate == 2.25)
    }

    @Test func playerEventAudioCasesEquality() {
        let boost1 = AKPlayerEvent.audioBoostDidChange(1.5)
        let boost2 = AKPlayerEvent.audioBoostDidChange(1.5)
        let boost3 = AKPlayerEvent.audioBoostDidChange(2.0)

        #expect(boost1 == boost2)
        #expect(boost1 != boost3)

        let smartSpeed1 = AKPlayerEvent.smartSpeedStatusDidChange(isEnabled: true)
        let smartSpeed2 = AKPlayerEvent.smartSpeedStatusDidChange(isEnabled: true)
        let smartSpeed3 = AKPlayerEvent.smartSpeedStatusDidChange(isEnabled: false)

        #expect(smartSpeed1 == smartSpeed2)
        #expect(smartSpeed1 != smartSpeed3)

        let clarity1 = AKPlayerEvent.dialogueClarityStatusDidChange(isEnabled: true)
        let clarity2 = AKPlayerEvent.dialogueClarityStatusDidChange(isEnabled: true)
        let clarity3 = AKPlayerEvent.dialogueClarityStatusDidChange(isEnabled: false)

        #expect(clarity1 == clarity2)
        #expect(clarity1 != clarity3)

        let spectrum1 = AKPlayerEvent.spectrumLevelsDidChange([0.1, 0.5])
        let spectrum2 = AKPlayerEvent.spectrumLevelsDidChange([0.1, 0.5])
        let spectrum3 = AKPlayerEvent.spectrumLevelsDidChange([0.2, 0.4])

        #expect(spectrum1 == spectrum2)
        #expect(spectrum1 != spectrum3)
    }

    @Test func smartSpeedSilenceRateAdjustmentSimulation() throws {
        let player = AVPlayer()
        let controller = AKPlayerController(player: player, configuration: AKPlayerConfiguration())
        try controller.prepare()

        #expect(controller.audioTapProcessor != nil)

        controller.isSmartSpeedEnabled = true
        controller.smartSpeedRate = 2.0

        // Transition to playing state
        controller.change(AKPlayingState(playerController: controller))
        player.rate = 1.0

        // Simulate silence detected
        controller.handleSilenceDetection(isSilent: true, rms: 0.002)
        #expect(player.rate == 2.0)

        // Simulate voice resumes
        controller.handleSilenceDetection(isSilent: false, rms: 0.15)
        #expect(player.rate == 1.0)
        #expect(controller.smartSpeedSavedTime >= 0)
    }

    @Test func configurationRemainsImmutableWhenDynamicPropertiesChange() throws {
        let player = AVPlayer()
        var config = AKPlayerConfiguration()
        config.audioBoost = 1.0
        config.isSmartSpeedEnabled = false
        config.smartSpeedRate = 2.0

        let controller = AKPlayerController(player: player, configuration: config)
        try controller.prepare()

        // Modify runtime dynamic properties
        controller.audioBoost = 1.8
        controller.isSmartSpeedEnabled = true
        controller.smartSpeedRate = 3.0

        // Verify runtime properties updated
        #expect(controller.audioBoost == 1.8)
        #expect(controller.isSmartSpeedEnabled == true)
        #expect(controller.smartSpeedRate == 3.0)

        // Verify configuration remains untouched at its initial preset values
        #expect(controller.configuration.audioBoost == 1.0)
        #expect(controller.configuration.isSmartSpeedEnabled == false)
        #expect(controller.configuration.smartSpeedRate == 2.0)
    }
}
