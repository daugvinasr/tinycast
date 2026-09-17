import Foundation

/// One row of VS Code's recently-opened list: a folder, a `.code-workspace`, or a single file.
struct RecentProject: Identifiable, Hashable, Sendable {
    enum Kind: Sendable {
        case folder
        case workspace
        case file
    }

    static let sfSymbol = "clock.arrow.circlepath"

    let uri: String
    let kind: Kind
    let path: String

    var id: String { uri }

    var symbol: String {
        switch kind {
        case .folder: return "folder"
        case .workspace: return "rectangle.stack"
        case .file: return "doc"
        }
    }

    /// The last path component, minus the extension the editor hides on a workspace too.
    var name: String {
        let component = location.lastPathComponent
        guard kind == .workspace, component.hasSuffix(Self.workspaceExtension) else {
            return component
        }
        return String(component.dropLast(Self.workspaceExtension.count))
    }

    /// The containing folder, tilde-shortened.
    func subtitle(home: String) -> String {
        let parent = parentPath
        guard parent == home || parent.hasPrefix(home + "/") else { return parent }
        return "~" + parent.dropFirst(home.count)
    }

    private var location: URL { URL(fileURLWithPath: path) }

    /// `URL` keeps the trailing slash a parent directory ends in; a subtitle reads better without.
    private var parentPath: String {
        let parent = location.deletingLastPathComponent().path(percentEncoded: false)
        guard parent.count > 1, parent.hasSuffix("/") else { return parent }
        return String(parent.dropLast())
    }

    // MARK: - Parsing

    /// Decodes the `entries` array the editor stores under its recently-opened key.
    static func parse(entriesIn data: Data) -> [RecentProject] {
        guard let list = try? JSONDecoder().decode(StoredList.self, from: data) else { return [] }
        return list.entries.compactMap(project(from:))
    }

    /// Decodes `storage.json`, which records the windows a running build still has open.
    static func parse(openWindowsIn data: Data) -> [RecentProject] {
        guard let state = try? JSONDecoder().decode(StoredState.self, from: data),
            let backups = state.backupWorkspaces
        else { return [] }
        let stored = (backups.workspaces ?? []) + (backups.folders ?? [])
        // Both lists end with the window opened last, which is the one worth offering first.
        return stored.reversed().compactMap(project(from:))
    }

    /// First mention wins, so the freshest list decides where a project sits.
    static func merge(_ lists: [[RecentProject]]) -> [RecentProject] {
        var seen: Set<String> = []
        return lists.flatMap { $0 }.filter { seen.insert($0.uri).inserted }
    }

    private static let workspaceExtension = ".code-workspace"

    private struct StoredList: Decodable {
        let entries: [StoredEntry]
    }

    private struct StoredState: Decodable {
        struct Backups: Decodable {
            let folders: [StoredEntry]?
            let workspaces: [StoredEntry]?
        }
        let backupWorkspaces: Backups?
    }

    private struct StoredEntry: Decodable {
        struct Workspace: Decodable {
            let configPath: String
        }
        let folderUri: String?
        let fileUri: String?
        let workspace: Workspace?
        /// `storage.json` writes a workspace flat, under its own spelling of the field.
        let configURIPath: String?

        var workspacePath: String? { workspace?.configPath ?? configURIPath }
    }

    private static func project(from entry: StoredEntry) -> RecentProject? {
        let uri: String
        let kind: Kind
        if let workspacePath = entry.workspacePath {
            uri = workspacePath
            kind = .workspace
        } else if let folderUri = entry.folderUri {
            uri = folderUri
            kind = .folder
        } else if let fileUri = entry.fileUri {
            uri = fileUri
            kind = .file
        } else {
            return nil
        }
        // An `untitled:`, `vscode-userdata:` or `vscode-remote://` entry names no file here.
        guard let url = URL(string: uri), url.isFileURL else { return nil }
        return RecentProject(uri: uri, kind: kind, path: url.path(percentEncoded: false))
    }
}
