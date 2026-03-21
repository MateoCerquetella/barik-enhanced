import Combine
import CoreGraphics
import Foundation
import IOKit
import IOKit.graphics

final class BrightnessManager: ObservableObject {
    @Published var brightness: Float = 1.0
    private var timer: Timer?

    init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        updateBrightness()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateBrightness()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateBrightness() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            var brightness: Float = 1.0
            var iterator: io_iterator_t = 0
            let result = IOServiceGetMatchingServices(
                kIOMainPortDefault,
                IOServiceMatching("IODisplayConnect"),
                &iterator
            )
            guard result == kIOReturnSuccess else { return }

            var service = IOIteratorNext(iterator)
            while service != 0 {
                var level: Float = 0
                let kr = IODisplayGetFloatParameter(
                    service, 0,
                    kIODisplayBrightnessKey as CFString,
                    &level
                )
                if kr == kIOReturnSuccess {
                    brightness = level
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)

            DispatchQueue.main.async {
                let newBrightness = max(0.0, min(1.0, brightness))
                if self.brightness != newBrightness {
                    self.brightness = newBrightness
                }
            }
        }
    }

    func setBrightness(_ level: Float) {
        let clamped = max(0.0, min(1.0, level))

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        )
        guard result == kIOReturnSuccess else { return }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            IODisplaySetFloatParameter(
                service, 0,
                kIODisplayBrightnessKey as CFString,
                clamped
            )
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)

        DispatchQueue.main.async {
            self.brightness = clamped
        }
    }
}
