import Combine
import Foundation
import Carbon
import InputMethodKit

/// Manages keyboard input source monitoring and switching.
class KeyboardLayoutManager: ObservableObject {
    static let shared = KeyboardLayoutManager()

    @Published var currentInputSource: String = "EN"
    @Published var availableInputSources: [String] = []
    
    private var timer: Timer?
    private var inputSources: [TISInputSource] = []
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        updateInputSources()
        
        // Update every 10 seconds to detect changes
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.updateCurrentInputSource()
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Updates the list of available input sources
    private func updateInputSources() {
        let inputSourceProperties = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource]
        
        guard let sources = TISCreateInputSourceList(inputSourceProperties as CFDictionary, false)?.takeRetainedValue() else {
            return
        }
        
        let sourceCount = CFArrayGetCount(sources)
        inputSources = []
        var sourceNames: [String] = []
        
        for i in 0..<sourceCount {
            let inputSource = CFArrayGetValueAtIndex(sources, i)
            let source = Unmanaged<TISInputSource>.fromOpaque(inputSource!).takeUnretainedValue()
            
            // Check if the input source is selectable (enabled)
            if let selectable = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable) {
                let isSelectable = Unmanaged<CFBoolean>.fromOpaque(selectable).takeUnretainedValue()
                if CFBooleanGetValue(isSelectable) {
                    inputSources.append(source)
                    
                    if let nameRef = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
                        let name = Unmanaged<CFString>.fromOpaque(nameRef).takeUnretainedValue() as String
                        sourceNames.append(name)
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.availableInputSources = sourceNames
        }
        
        updateCurrentInputSource()
    }
    
    /// Updates the current active input source
    private func updateCurrentInputSource() {
        let currentSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        
        if let nameRef = TISGetInputSourceProperty(currentSource, kTISPropertyLocalizedName) {
            let name = Unmanaged<CFString>.fromOpaque(nameRef).takeUnretainedValue() as String
            let abbreviated = self.abbreviateInputSourceName(name)

            DispatchQueue.main.async {
                if self.currentInputSource != abbreviated {
                    self.currentInputSource = abbreviated
                }
            }
        }
    }
    
    /// Abbreviates input source names for compact display
    private func abbreviateInputSourceName(_ name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("english"):
            return "EN"
        case let n where n.contains("spanish"):
            return "ES"
        case let n where n.contains("french"):
            return "FR"
        case let n where n.contains("german"):
            return "DE"
        case let n where n.contains("italian"):
            return "IT"
        case let n where n.contains("portuguese"):
            return "PT"
        case let n where n.contains("russian"):
            return "RU"
        case let n where n.contains("chinese"):
            return "中文"
        case let n where n.contains("japanese"):
            return "日本語"
        case let n where n.contains("korean"):
            return "한국어"
        case let n where n.contains("arabic"):
            return "العربية"
        case let n where n.contains("emoji"):
            return "😀"
        case let n where n.contains("symbol"):
            return "⌘"
        default:
            // Return first 3 characters for unknown layouts
            return String(name.prefix(3)).uppercased()
        }
    }
    
    /// Switches to a specific input source by name
    func switchToInputSource(name: String) {
        // Find the input source matching the name
        for source in inputSources {
            if let nameRef = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
                let sourceName = Unmanaged<CFString>.fromOpaque(nameRef).takeUnretainedValue() as String
                if sourceName == name {
                    TISSelectInputSource(source)
                    
                    // Update current status after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.updateCurrentInputSource()
                    }
                    break
                }
            }
        }
    }
    
    /// Cycles to the next available input source
    func switchToNextInputSource() {
        guard !inputSources.isEmpty else { return }
        
        let currentSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        
        // Find current source index
        var currentIndex = 0
        for (index, source) in inputSources.enumerated() {
            if CFEqual(source, currentSource) {
                currentIndex = index
                break
            }
        }
        
        // Switch to next source (cycling back to 0 if at end)
        let nextIndex = (currentIndex + 1) % inputSources.count
        TISSelectInputSource(inputSources[nextIndex])
        
        // Update current status after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateCurrentInputSource()
        }
    }
} 