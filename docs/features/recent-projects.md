# Recent Projects

**Search Recent Projects** lists what VS Code already has in its own recently-opened menu — folders,
`.code-workspace` files and single files — and reopens one in VS Code. Tinycast keeps no list of its
own: it reads VS Code's, and nothing else.

The feature carries no switch and no pane. The command is an ordinary launcher command, listed under
**Settings → Commands** like any other, where it takes an alias, a hotkey, or gets hidden.

## Invariants

- **VS Code owns the list.** Every read is read-only — `SQLITE_OPEN_READONLY`, and `immutable=1` on
  the retry. Tinycast never writes to VS Code's store, and never persists a copy of its own.
- **`open(_:)` is the single funnel** for the browser, its ⌘K menu and ↵ alike.
- **A project has a path on this Mac, always.** Anything else VS Code lists — an `untitled:` buffer,
  a `vscode-remote://` host — is dropped at parse, so no row can name a file that isn't here.
- **Nothing is persisted.** No setting, no cache, no backup field: the list is read on demand and
  held in memory only.
- **`Model/` stays Foundation-only and pure** for `recent-project-test`.

## Reading the list

`RecentProjectReader` reads, newest source first:

| Source | Holds |
| --- | --- |
| `~/.vscode-shared/sharedStorage/state.vscdb` | the current list, shared across profiles |
| `…/Application Support/Code/User/globalStorage/state.vscdb` | the older per-profile list |
| `…/User/globalStorage/storage.json` | windows the running editor still has open |

Both databases are queried for `history.recentlyOpenedPathsList`. A running editor leaves a WAL that
no read-only connection may open, so a failed open retries against a `file:…?immutable=1` URI.

`RecentProject.merge` keeps the first mention of each URI, so the freshest source decides the order,
and a project whose path no longer exists is dropped — VS Code never prunes those itself.

`RecentProjectCoordinator.refresh()` runs on every browser open, off-main, because VS Code rewrites
its list as each window closes. `applicationURL` asks Launch Services first, so a copy kept outside
the search scopes is still found, and falls back to `AppIndex`'s cached scan.

## Rows

↵ opens through `NSWorkspace` against the resolved application, ⌘↵ reveals in Finder, ⌃⌘C copies the
path.

## Standalone harness

```sh
./Scripts/run-tests.sh recent-project-test
```
