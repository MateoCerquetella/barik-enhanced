import AVFoundation
import Combine
import CoreAudio
import Foundation

final class MicrophoneManager: ObservableObject {
    static let shared = MicrophoneManager()

    @Published var isActive: Bool = false
    @Published var isMuted: Bool = false
    @Published var inputLevel: Float = 0.0

    private var timer: Timer?

    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        updateStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateStatus() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            var deviceID: AudioDeviceID = kAudioObjectUnknown
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)

            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            let result = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address, 0, nil, &size, &deviceID
            )

            guard result == noErr, deviceID != kAudioObjectUnknown else {
                DispatchQueue.main.async {
                    if self.isActive { self.isActive = false }
                }
                return
            }

            // Check mute status
            var muteValue: UInt32 = 0
            size = UInt32(MemoryLayout<UInt32>.size)
            address.mSelector = kAudioDevicePropertyMute
            address.mScope = kAudioObjectPropertyScopeInput
            address.mElement = kAudioObjectPropertyElementMain

            let muteResult = AudioObjectGetPropertyData(
                deviceID, &address, 0, nil, &size, &muteValue
            )

            // Check input volume as activity indicator
            var volume: Float32 = 0.0
            size = UInt32(MemoryLayout<Float32>.size)
            address.mSelector = kAudioDevicePropertyVolumeScalar
            address.mScope = kAudioObjectPropertyScopeInput

            let volResult = AudioObjectGetPropertyData(
                deviceID, &address, 0, nil, &size, &volume
            )

            DispatchQueue.main.async {
                let newActive = true
                let newMuted = muteResult == noErr ? muteValue != 0 : false
                let newLevel = volResult == noErr ? max(0.0, min(1.0, volume)) : 0.5

                if self.isActive != newActive { self.isActive = newActive }
                if self.isMuted != newMuted { self.isMuted = newMuted }
                if self.inputLevel != newLevel { self.inputLevel = newLevel }
            }
        }
    }

    func toggleMute() {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        guard result == noErr else { return }

        let newMute: UInt32 = isMuted ? 0 : 1
        var muteValue = newMute
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyMute
        address.mScope = kAudioObjectPropertyScopeInput
        address.mElement = kAudioObjectPropertyElementMain

        AudioObjectSetPropertyData(
            deviceID, &address, 0, nil, size, &muteValue
        )

        DispatchQueue.main.async {
            self.isMuted = newMute != 0
        }
    }
}
