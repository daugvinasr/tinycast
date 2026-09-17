import Foundation
import SQLite3

// Spelled as the C macro in sqlite3.h, which isn't imported into Swift.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Reads VS Code's own recently-opened list. Read-only throughout: Tinycast never writes there.
enum RecentProjectReader {
    private static let storageKey = "history.recentlyOpenedPathsList"

    nonisolated static func read(home: URL) -> [RecentProject] {
        var lists: [[RecentProject]] = []
        for database in databases(home: home) {
            guard let data = value(of: storageKey, in: database) else { continue }
            lists.append(RecentProject.parse(entriesIn: data))
        }
        if let data = try? Data(contentsOf: storageFile(home: home)) {
            lists.append(RecentProject.parse(openWindowsIn: data))
        }
        return RecentProject.merge(lists).filter(exists)
    }

    /// Shared first: the per-profile store is the older copy wherever both exist.
    private static func databases(home: URL) -> [URL] {
        let shared = home.appending(path: ".vscode-shared/sharedStorage/state.vscdb")
        return [shared, globalStorage(home: home).appending(path: "state.vscdb")].filter {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }

    private static func globalStorage(home: URL) -> URL {
        home.appending(path: "Library/Application Support/Code/User/globalStorage")
    }

    /// Windows VS Code still has open, recorded outside the recents list it writes on quit.
    private static func storageFile(home: URL) -> URL {
        globalStorage(home: home).appending(path: "storage.json")
    }

    /// A project deleted or on an unmounted volume is dead weight the editor never prunes.
    private static func exists(_ project: RecentProject) -> Bool {
        FileManager.default.fileExists(atPath: project.path)
    }

    // MARK: - SQLite

    /// A running editor leaves a WAL no read-only connection may open, so that read retries frozen.
    private static func value(of key: String, in database: URL) -> Data? {
        value(of: key, at: database.path, flags: SQLITE_OPEN_READONLY)
            ?? value(
                of: key, at: database.absoluteString + "?immutable=1",
                flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI)
    }

    private static func value(of key: String, at path: String, flags: Int32) -> Data? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK else {
            sqlite3_close_v2(db)
            return nil
        }
        defer { sqlite3_close_v2(db) }
        var statement: OpaquePointer?
        let sql = "SELECT value FROM ItemTable WHERE key = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, key, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(statement) == SQLITE_ROW,
            let bytes = sqlite3_column_blob(statement, 0)
        else { return nil }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
    }
}
