import Foundation

/// A VS Code–family editor, named the way its own build names itself on disk.
struct EditorBuild: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// The bundle name, which finds a build no URL scheme is registered for.
    let applicationName: String
    /// The `Application Support` folder the build keeps `User/globalStorage` in.
    let supportFolder: String
    /// `dataFolderName` from the build's `product.json`; the shared store sits beside it.
    let dataFolder: String
    let urlScheme: String

    /// What an unset preference means, and the build every other one is a fork of.
    static let visualStudioCode = EditorBuild(
        id: "code", name: "Visual Studio Code", applicationName: "Visual Studio Code",
        supportFolder: "Code", dataFolder: ".vscode", urlScheme: "vscode")

    static let all: [EditorBuild] = [
        visualStudioCode,
        EditorBuild(
            id: "code-insiders", name: "VS Code Insiders",
            applicationName: "Visual Studio Code - Insiders", supportFolder: "Code - Insiders",
            dataFolder: ".vscode-insiders", urlScheme: "vscode-insiders"),
        EditorBuild(
            id: "vscodium", name: "VSCodium", applicationName: "VSCodium",
            supportFolder: "VSCodium", dataFolder: ".vscode-oss", urlScheme: "vscodium"),
        EditorBuild(
            id: "cursor", name: "Cursor", applicationName: "Cursor", supportFolder: "Cursor",
            dataFolder: ".cursor", urlScheme: "cursor"),
        EditorBuild(
            id: "windsurf", name: "Windsurf", applicationName: "Windsurf",
            supportFolder: "Windsurf", dataFolder: ".windsurf", urlScheme: "windsurf"),
        EditorBuild(
            id: "trae", name: "Trae", applicationName: "Trae", supportFolder: "Trae",
            dataFolder: ".trae", urlScheme: "trae"),
        EditorBuild(
            id: "positron", name: "Positron", applicationName: "Positron",
            supportFolder: "Positron", dataFolder: ".positron", urlScheme: "positron"),
        EditorBuild(
            id: "kiro", name: "Kiro", applicationName: "Kiro", supportFolder: "Kiro",
            dataFolder: ".kiro", urlScheme: "kiro")
    ]

    static func named(_ id: String) -> EditorBuild? { all.first { $0.id == id } }

    var bundleFileName: String { applicationName + ".app" }

    /// The shared folder's name when the installed build isn't there for `product.json` to name it.
    var sharedFolderFallback: String { dataFolder + "-shared" }

    func globalStorage(home: URL) -> URL {
        home.appending(path: "Library/Application Support/\(supportFolder)/User/globalStorage")
    }

    /// The per-profile store, which older builds and profiles other than the default still write.
    func stateDatabase(home: URL) -> URL {
        globalStorage(home: home).appending(path: "state.vscdb")
    }

    /// Windows a build still has open, recorded outside the recents list it writes on quit.
    func storageFile(home: URL) -> URL {
        globalStorage(home: home).appending(path: "storage.json")
    }

    /// Where a current build keeps the list, shared across every profile and window.
    func sharedStateDatabase(home: URL, folderName: String) -> URL {
        home.appending(path: "\(folderName)/sharedStorage/state.vscdb")
    }
}
