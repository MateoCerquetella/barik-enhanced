import AppKit
import Foundation

/// One window as reported by `omniwmctl query windows`.
///
/// OmniWM identifies windows with an opaque session id (`ow_…`), while Barik's
/// model layer keys windows by `Int`. We keep the opaque id for actions and
/// derive a stable `Int` from it so the widget can compare identities.
struct OmniWMWindow: WindowModel {
    let id: Int
    let title: String
    let appName: String?
    var isFocused: Bool
    var appIcon: NSImage?
    let workspace: String?
    let opaqueId: String
    let isScratchpad: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case app
        case isFocused
        case workspace
        case isScratchpad
    }

    private enum AppKeys: String, CodingKey {
        case name
    }

    private enum WorkspaceKeys: String, CodingKey {
        case rawName
    }

    init(
        opaqueId: String, title: String, appName: String?, isFocused: Bool,
        workspace: String?, isScratchpad: Bool
    ) {
        self.opaqueId = opaqueId
        self.id = OmniWMWindow.stableId(for: opaqueId)
        self.title = title
        self.appName = appName
        self.isFocused = isFocused
        self.workspace = workspace
        self.isScratchpad = isScratchpad
        self.appIcon = appName.flatMap { IconCache.shared.icon(for: $0) }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let opaque = try container.decode(String.self, forKey: .id)

        let appContainer = try? container.nestedContainer(
            keyedBy: AppKeys.self, forKey: .app)
        let appNameValue = try appContainer?.decodeIfPresent(
            String.self, forKey: .name)

        let workspaceContainer = try? container.nestedContainer(
            keyedBy: WorkspaceKeys.self, forKey: .workspace)
        let workspaceValue = try workspaceContainer?.decodeIfPresent(
            String.self, forKey: .rawName)

        let decodedTitle = try container.decodeIfPresent(
            String.self, forKey: .title)
        let focused =
            try container.decodeIfPresent(Bool.self, forKey: .isFocused) ?? false
        let scratchpad =
            try container.decodeIfPresent(Bool.self, forKey: .isScratchpad)
            ?? false

        // OmniWM 0.5.x does not emit window titles; fall back to the app name.
        self.init(
            opaqueId: opaque,
            title: decodedTitle ?? appNameValue ?? "Window",
            appName: appNameValue,
            isFocused: focused,
            workspace: workspaceValue,
            isScratchpad: scratchpad
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(opaqueId, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(isFocused, forKey: .isFocused)
        var appContainer = container.nestedContainer(
            keyedBy: AppKeys.self, forKey: .app)
        try appContainer.encodeIfPresent(appName, forKey: .name)
    }

    /// FNV-1a keeps the derived id stable across launches, unlike `hashValue`.
    static func stableId(for opaqueId: String) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in opaqueId.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x1000_0000_01b3
        }
        return Int(bitPattern: UInt(hash ^ (hash >> 32)))
    }
}

/// One workspace as reported by `omniwmctl query workspaces`.
struct OmniWMSpace: SpaceModel {
    typealias WindowType = OmniWMWindow

    let workspace: String
    let number: Int?
    var id: String { workspace }
    var isFocused: Bool = false
    var windows: [OmniWMWindow] = []

    enum CodingKeys: String, CodingKey {
        case workspace = "rawName"
        case number
        case isFocused
    }

    init(workspace: String, number: Int?, isFocused: Bool) {
        self.workspace = workspace
        self.number = number
        self.isFocused = isFocused
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workspace = try container.decode(String.self, forKey: .workspace)
        number = try container.decodeIfPresent(Int.self, forKey: .number)
        isFocused =
            try container.decodeIfPresent(Bool.self, forKey: .isFocused) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workspace, forKey: .workspace)
        try container.encodeIfPresent(number, forKey: .number)
        try container.encode(isFocused, forKey: .isFocused)
    }
}
