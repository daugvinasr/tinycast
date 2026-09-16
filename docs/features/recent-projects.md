# Recent Projects

**Search Recent Projects** lists what a VS Code–family editor already has in its own
recently-opened menu — folders, `.code-workspace` files, single files and SSH remotes — and reopens
one in that editor. Tinycast keeps no list of its own: it reads the editor's, and nothing else.

The feature ships **off**. **Settings → Recent Projects** carries the switch and the editor picker.
Off is fully off: the editor's databases are never opened, `projects` is emptied, the command leaves
the launcher, and `RecentProjectCoordinator.open(_:)` refuses to open anything.

## Invariants

- **The editor owns the list.** Every read is read-only — `SQLITE_OPEN_READONLY`, and `immutable=1`
  on the retry. Tinycast never writes to an editor's store, and never persists a copy of its own.
- **`open(_:)` is the single funnel** for the browser, its ⌘K menu and ↵ alike, so the switch can't
  be bypassed and a project always opens in the chosen build.
- **`build` is derived, never stored twice.** The preference holds an `EditorBuild.id`, and empty
  means the first build installed. `installed` is the one resolved map of build → application URL;
  `installedBuilds`, `applicationURL` and `isBuildInstalled` all read it rather than touching disk.
- **A read names its build.** The picker can move while a read is in flight, so `refresh()` discards
  a result whose build no longer matches and re-reads instead of publishing another editor's list.
- **`recentProjectsEditor` is excluded from settings backups.** It names an editor installed on this
  Mac; `recentProjectsEnabled` rides along, since reading a list the editor already wrote grants no
  permission class of its own.
- **`Model/` stays Foundation-only and pure** for `recent-project-test`.

## Finding the editor

`EditorBuild.all` is the table of supported builds — VS Code and Insiders, VSCodium, Cursor,
Windsurf, Trae, Positron, Kiro — each naming its bundle, its `Application Support` folder, its data
folder and its URL scheme. A fork keeps VS Code's on-disk shapes, so one table serves them all.

`refreshInstalledBuilds()` resolves every build once, on the switch, on an editor change and when the
Settings pane appears. Launch Services answers first, so a build kept outside the search scopes is
still found; otherwise the build's bundle name is matched against `AppIndex`'s cached scan, which
costs nothing and honours the user's own search scopes. Nothing re-resolves per render.

## Reading the list

`RecentProjectReader` reads, newest source first:

| Source | Holds |
| --- | --- |
| `~/<dataFolder>-shared/sharedStorage/state.vscdb` | the current list, shared across profiles |
| `…/Application Support/<build>/User/globalStorage/state.vscdb` | the older per-profile list |
| `…/User/globalStorage/storage.json` | windows the running build still has open |

Both databases are queried for `recently.opened` and, for a build from before shared storage,
`history.recentlyOpenedPathsList`. `product.json` names the shared folder outright — a fork renames
it without warning — so the installed bundle is consulted and `<dataFolder>-shared` is only the
fallback for a build that isn't installed. A running editor leaves a WAL that no read-only connection
may open, so a failed open retries against a `file:…?immutable=1` URI.

`RecentProject.merge` keeps the first mention of each URI, so the freshest source decides the order,
and a project whose path no longer exists is dropped — the editor never prunes those itself.

## Rows

A `vscode-remote://ssh-remote+host/…` entry names no file on this Mac: it has no `path`, draws the
network glyph instead of its kind, leads its subtitle with the host, and has no Show in Finder. ↵
hands it to the build's own URL scheme as `vscode://vscode-remote/…`; every local project opens
through `NSWorkspace` against the resolved application. ⌘↵ reveals, ⌃⌘C copies the path — the URI
itself for a remote.

## Standalone harness

```sh
./Scripts/run-tests.sh recent-project-test
```
