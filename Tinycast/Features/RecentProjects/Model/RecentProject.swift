import Foundation

/// One row of an editor's recently-opened list: a folder, a `.code-workspace`, or a single file.
struct RecentProject: Identifiable, Hashable, Sendable {
    enum Kind: Sendable {
        case folder
        case workspace
        case file
    }

    static let sfSymbol = "clock.arrow.circlepath"
    /// A project on another machine has no file here, so its row draws this instead of an icon.
    static let remoteSymbol = "network"

    let uri: String
    let kind: Kind
    /// Nil for a project on a remote authority, which names no path on this Mac.
    let path: String?
    let remoteAuthority: String?

    var id: String { uri }
    var isRemote: Bool { remoteAuthority != nil }

    /// A remote project draws its host, not its kind: the file it names is on another machine.
    var symbol: String {
        guard !isRemote else { return Self.remoteSymbol }
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

    /// The containing folder, tilde-shortened; a remote project names its host first.
    func subtitle(home: String) -> String {
        guard let remoteAuthority else { return Self.tildified(parentPath, home: home) }
        return Self.hostName(of: remoteAuthority) + " · " + parentPath
    }

    private var location: URL { URL(fileURLWithPath: path ?? Self.remotePath(of: uri)) }

    /// `URL` keeps the trailing slash a parent directory ends in; a subtitle reads better without.
    private var parentPath: String {
        let parent = location.deletingLastPathComponent().path(percentEncoded: false)
        guard parent.count > 1, parent.hasSuffix("/") else { return parent }
        return String(parent.dropLast())
    }

    private static func tildified(_ parent: String, home: String) -> String {
        guard parent == home || parent.hasPrefix(home + "/") else { return parent }
        return "~" + parent.dropFirst(home.count)
    }

    /// `ssh-remote+host` is how the editor spells an SSH target; anything else is shown as-is.
    private static func hostName(of authority: String) -> String {
        guard let plus = authority.firstIndex(of: "+") else { return authority }
        return String(authority[authority.index(after: plus)...])
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
    private static let remotePrefix = "vscode-remote://"

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
        /// `storage.json` writes a workspace flat, and renamed the field along the way.
        let configURIPath: String?
        let configPath: String?
        let remoteAuthority: String?

        var workspacePath: String? { workspace?.configPath ?? configURIPath ?? configPath }
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
        if let authority = entry.remoteAuthority ?? remoteAuthority(of: uri) {
            return RecentProject(uri: uri, kind: kind, path: nil, remoteAuthority: authority)
        }
        // An `untitled:` or `vscode-userdata:` entry names nothing openable: drop it.
        guard let url = URL(string: uri), url.isFileURL else { return nil }
        return RecentProject(
            uri: uri, kind: kind, path: url.path(percentEncoded: false), remoteAuthority: nil)
    }

    /// Read by hand: `ssh-remote+host` is not an authority `URL` hands back as a host.
    private static func remoteAuthority(of uri: String) -> String? {
        guard uri.hasPrefix(remotePrefix) else { return nil }
        let authority = uri.dropFirst(remotePrefix.count).prefix { $0 != "/" }
        return authority.isEmpty ? nil : String(authority)
    }

    private static func remotePath(of uri: String) -> String {
        let rest = uri.dropFirst(remotePrefix.count)
        guard uri.hasPrefix(remotePrefix), let slash = rest.firstIndex(of: "/") else { return uri }
        let path = String(rest[slash...])
        return path.removingPercentEncoding ?? path
    }
}
