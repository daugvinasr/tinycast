import SwiftUI

/// Search Recent Projects: the editor's own recently-opened list, filtered by the search field.
struct RecentProjectsScreen: PaletteScreen {
    let coordinator: RecentProjectCoordinator
    let core: AppCore
    let vm: PaletteState
    let openActions: () -> Void

    private var home: String { NSHomeDirectory() }

    var rows: [RecentProject] {
        let query = vm.query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return coordinator.projects }
        return coordinator.projects.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.path ?? $0.uri).localizedCaseInsensitiveContains(query)
        }
    }

    let primaryActionTitle = "Open Project"

    private func project(at selection: Int) -> RecentProject? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection] : nil
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        guard let project = project(at: selection) else { return nil }
        return RecentProjectActionsMenu.content(
            project: project, build: coordinator.build, core: core)
    }

    func activate(at selection: Int) {
        guard let project = project(at: selection) else { return }
        coordinator.open(project)
    }

    /// ⌘↵ reveals, as it does in file search; a remote project has nothing here to reveal.
    func secondary(at selection: Int) -> Bool {
        guard let project = project(at: selection), !project.isRemote else { return false }
        coordinator.showInFinder(project)
        return true
    }

    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        guard shortcut == .copyPath, let project = project(at: selection) else { return false }
        coordinator.copyPath(project)
        return true
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        AnyView(content(selection: selection, scroll: scroll))
    }

    @ViewBuilder
    private func content(selection: Int, scroll: ScrollIntent) -> some View {
        let rows = rows
        if rows.isEmpty {
            EmptyResults(text: emptyMessage)
        } else {
            RecentProjectsList(
                results: rows, home: home,
                selectedID: project(at: selection)?.id, scroll: scroll,
                onSelect: { project in
                    if let index = rows.firstIndex(of: project) { vm.selection = index }
                },
                onActivate: { activate(at: vm.selection) },
                onActions: { project in
                    if let index = rows.firstIndex(of: project) { vm.selection = index }
                    openActions()
                })
        }
    }

    /// A missing editor, an empty list and an over-narrow filter are three different problems.
    private var emptyMessage: String {
        guard coordinator.isBuildInstalled else {
            return "\(coordinator.build.name) isn’t installed"
        }
        return coordinator.projects.isEmpty ? "No recent projects" : "No matching projects"
    }
}

/// The ⌘K menu for a recent-project row.
@MainActor
enum RecentProjectActionsMenu {
    static func content(
        project: RecentProject, build: EditorBuild, core: AppCore
    ) -> PopoverMenuContent {
        let coordinator = core.recentProjectCoordinator
        var items = [
            PopoverMenuItem(
                title: "Open in \(build.name)", systemImage: project.symbol, shortcut: "↵"
            ) { coordinator.open(project) }
        ]
        if !project.isRemote {
            items.append(
                PopoverMenuItem(
                    title: "Show in Finder", systemImage: "folder", startsSection: true,
                    shortcut: "⌘↵"
                ) { coordinator.showInFinder(project) })
        }
        items.append(
            PopoverMenuItem(
                title: "Copy Path", systemImage: "doc.on.clipboard",
                startsSection: project.isRemote, shortcut: "⌃⌘C"
            ) { coordinator.copyPath(project) })
        return PopoverMenuContent(header: project.name, items: items)
    }
}
