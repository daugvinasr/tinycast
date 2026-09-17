import Foundation

@main
struct RecentProjectTest {
    static func main() {
        var failures = 0

        func check(_ description: String, _ condition: @autoclosure () -> Bool) {
            if condition() {
                print("PASS  \(description)")
            } else {
                print("FAIL  \(description)")
                failures += 1
            }
        }

        let home = "/Users/ada"

        // The shape VS Code writes under `history.recentlyOpenedPathsList`, entries newest first.
        let recents = Data(
            """
            {"entries":[
              {"folderUri":"file:///Users/ada/Projects/tinycast"},
              {"workspace":{"id":"9f","configPath":"file:///Users/ada/work/site.code-workspace"}},
              {"fileUri":"file:///Users/ada/notes/todo%20list.md","label":"todo"},
              {"folderUri":"vscode-remote://ssh-remote%2Bbuild01/srv/api","remoteAuthority":"ssh-remote+build01"},
              {"fileUri":"untitled:Untitled-1"},
              {"label":"orphan"}
            ]}
            """.utf8)

        let parsed = RecentProject.parse(entriesIn: recents)
        check("every openable entry is read", parsed.count == 3)
        check(
            "an untitled buffer and a shapeless entry fall out",
            !parsed.contains { $0.uri.hasPrefix("untitled:") })
        check(
            "a project on another Mac names nothing to open here",
            !parsed.contains { $0.uri.hasPrefix("vscode-remote://") })
        check("a folder is a folder", parsed.first?.kind == .folder)
        check("a workspace comes from its configPath", parsed[1].kind == .workspace)
        check("a file is a file", parsed[2].kind == .file)

        check("the name is the last component", parsed.first?.name == "tinycast")
        check("a workspace drops the extension the editor hides", parsed[1].name == "site")
        check("a percent-escaped name is decoded", parsed[2].name == "todo list.md")
        check("the subtitle is the parent folder", parsed.first?.subtitle(home: home) == "~/Projects")
        check(
            "the home folder itself is just a tilde",
            RecentProject.parse(entriesIn: Data(#"{"entries":[{"folderUri":"file:///Users/ada/src"}]}"#.utf8))
                .first?.subtitle(home: home) == "~")
        check(
            "a path outside home keeps its own spelling",
            RecentProject.parse(entriesIn: Data(#"{"entries":[{"folderUri":"file:///opt/src/api"}]}"#.utf8))
                .first?.subtitle(home: home) == "/opt/src")

        // `storage.json` is the only record of a window a running build still has open.
        let storage = Data(
            """
            {"backupWorkspaces":{
              "folders":[{"folderUri":"file:///Users/ada/Projects/fresh"}],
              "workspaces":[{"id":"9f","configURIPath":"file:///Users/ada/work/site.code-workspace"}]
            }}
            """.utf8)
        let open = RecentProject.parse(openWindowsIn: storage)
        check("an open window is read too", open.count == 2)
        check("a flat workspace is still a workspace", open.contains { $0.kind == .workspace })
        check("the window opened last comes first", open.first?.name == "fresh")

        let merged = RecentProject.merge([parsed, open])
        check("a project listed twice appears once", merged.count == 4)
        check("the first list decides the order", merged.first?.name == "tinycast")
        check("what only the second list knows is kept", merged.last?.name == "fresh")

        let project = parsed[0]
        check("a project is identified by its uri", project.id == project.uri)
        check("a folder draws a folder", project.symbol == "folder")
        check("a workspace draws a stack", parsed[1].symbol == "rectangle.stack")

        print(failures == 0 ? "\nALL PASSED" : "\n\(failures) failed")
        if failures > 0 { exit(1) }
    }
}
