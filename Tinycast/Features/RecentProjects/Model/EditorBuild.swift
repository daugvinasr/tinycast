import Foundation

/// A VS Code–family editor, named the way its own build names itself on disk.
struct EditorBuild: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// The bundle under `/Applications`, which finds a build no URL scheme is registered for.
    let applicationName: String
    /// The `Application Support` folder the build keeps `User/globalStorage` in.
    let supportFolder: String
    /// `dataFolderName` from the build's `product.json`; the shared store sits beside it.
    let dataFolder: String
    let urlScheme: String

    static let all: [EditorBuild] = [
        EditorBuild(
            id: "code", name: "Visual Studio Code", applicationName: "Visual Studio Code",
            supportFolder: "Code", dataFolder: ".vscode", urlScheme: "vscode"),
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

    /// What an unset preference means, and the build every other one is a fork of.
    static let visualStudioCode = all[0]

    static func named(_ id: String) -> EditorBuild? { all.first { $0.id == id } }

    func applicationPath(inside folder: String) -> String {
        folder + "/" + applicationName + ".app"
    }

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
    func sharedStateDatabase(home: URL, folderName: String? = nil) -> URL {
        home.appending(path: "\(folderName ?? dataFolder + "-shared")/sharedStorage/state.vscdb")
    }

    /// `product.json` names the shared folder outright, which a fork renames without warning.
    static func productFile(applicationURL: URL) -> URL {
        applicationURL.appending(path: "Contents/Resources/app/product.json")
    }
}
