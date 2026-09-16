import Foundation
import SQLite3

// Spelled as the C macro in sqlite3.h, which isn't imported into Swift.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Reads an editor's own recently-opened list. Read-only throughout: Tinycast never writes there.
enum RecentProjectReader {
    /// A current build writes the first key, a build from before shared storage the second.
    private static let storageKeys = ["recently.opened", "history.recentlyOpenedPathsList"]

    nonisolated static func read(
        build: EditorBuild, home: URL, applicationURL: URL?
    ) -> [RecentProject] {
        var lists: [[RecentProject]] = []
        for database in databases(build: build, home: home, applicationURL: applicationURL) {
            for key in storageKeys {
                guard let data = value(of: key, in: database) else { continue }
                lists.append(RecentProject.parse(entriesIn: data))
            }
        }
        if let data = try? Data(contentsOf: build.storageFile(home: home)) {
            lists.append(RecentProject.parse(openWindowsIn: data))
        }
        return RecentProject.merge(lists).filter(exists)
    }

    /// Shared first: the per-profile store is the older copy wherever both exist.
    private static func databases(
        build: EditorBuild, home: URL, applicationURL: URL?
    ) -> [URL] {
        let shared = build.sharedStateDatabase(
            home: home, folderName: applicationURL.flatMap(sharedFolderName(applicationURL:)))
        return [shared, build.stateDatabase(home: home)].filter {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }

    private static func sharedFolderName(applicationURL: URL) -> String? {
        guard let data = try? Data(contentsOf: EditorBuild.productFile(applicationURL: applicationURL))
        else { return nil }
        return try? JSONDecoder().decode(ProductInfo.self, from: data).sharedDataFolderName
    }

    /// A project deleted or on an unmounted volume is dead weight the editor never prunes.
    private static func exists(_ project: RecentProject) -> Bool {
        guard let path = project.path else { return true }
        return FileManager.default.fileExists(atPath: path)
    }

    private struct ProductInfo: Decodable {
        let sharedDataFolderName: String?
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
