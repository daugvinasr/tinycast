import AppKit

/// Owns the recent-projects flow: the read behind Search Recent Projects, and the one open funnel.
@MainActor
@Observable
final class RecentProjectCoordinator {
    /// The editor's own list, as last read; the screen and the open funnel both resolve against it.
    private(set) var projects: [RecentProject] = []
    /// Where each installed build lives, resolved once: every render asks whether one is installed.
    private(set) var installed: [EditorBuild.ID: URL] = [:]

    private let settings: AppSettings
    private let appIndex: AppIndex
    private let paletteCoordinator: PaletteCoordinator
    private unowned let core: AppCore
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init(
        settings: AppSettings, appIndex: AppIndex, paletteCoordinator: PaletteCoordinator,
        core: AppCore
    ) {
        self.settings = settings
        self.appIndex = appIndex
        self.paletteCoordinator = paletteCoordinator
        self.core = core
    }

    /// The chosen build, or the first one installed while the preference is still unset.
    var build: EditorBuild {
        EditorBuild.named(settings.recentProjectsEditor) ?? installedBuilds.first
            ?? .visualStudioCode
    }

    /// The builds found on this Mac, which is what Settings offers to choose between.
    var installedBuilds: [EditorBuild] { EditorBuild.all.filter { installed[$0.id] != nil } }

    var applicationURL: URL? { installed[build.id] }

    var isBuildInstalled: Bool { applicationURL != nil }

    // MARK: - Feature presence

    /// Off means the editor's database is never opened again, not merely that the command is gone.
    func applyPresence() {
        appIndex.setCommandsVisible([.searchRecentProjects], settings.recentProjectsEnabled)
        guard settings.recentProjectsEnabled else {
            projects = []
            return
        }
        refreshInstalledBuilds()
        refresh()
    }

    /// Re-read on every launcher open: the editor rewrites its list as each window closes.
    func refresh() {
        guard settings.recentProjectsEnabled, refreshTask == nil else { return }
        let build = build
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let applicationURL = applicationURL
        refreshTask = Task {
            let found = await Task.detached {
                RecentProjectReader.read(
                    build: build, home: home, applicationURL: applicationURL)
            }.value
            refreshTask = nil
            guard settings.recentProjectsEnabled else { return }
            // The picker moved while the read ran, so what came back is the wrong editor's list.
            guard build == self.build else { return refresh() }
            guard found != projects else { return }
            projects = found
        }
    }

    /// An editor installed or removed while Tinycast ran still has to reach the picker.
    func refreshInstalledBuilds() {
        installed = EditorBuild.all.reduce(into: [:]) { found, build in
            found[build.id] = applicationURL(for: build)
        }
    }

    // MARK: - Browsing and opening

    /// The switch gates the browser, the way Search Snippets re-checks its own before opening.
    func showProjects() {
        guard settings.recentProjectsEnabled else { return }
        refresh()
        paletteCoordinator.togglePalette(mode: .recentProjects)
    }

    /// The one funnel the screen and its menu reach, so a project always opens in the chosen build.
    func open(_ project: RecentProject) {
        guard settings.recentProjectsEnabled else { return }
        paletteCoordinator.hidePalette(restoreFocus: false)
        let build = build
        guard let application = applicationURL else {
            Task {
                await core.showNotice(
                    title: "\(build.name) Isn’t Installed",
                    message: "Choose the editor you use under Settings ▸ Recent Projects.",
                    symbol: RecentProject.sfSymbol, tone: .danger)
            }
            return
        }
        Task {
            do {
                try await Self.open(project, build: build, application: application)
            } catch {
                await core.showNotice(
                    title: "Couldn’t Open \(project.name)", message: error.localizedDescription,
                    symbol: RecentProject.sfSymbol, tone: .danger)
            }
        }
    }

    /// Only a local project has something to reveal; a remote one names no file on this Mac.
    func showInFinder(_ project: RecentProject) {
        guard let path = project.path else { return }
        paletteCoordinator.hidePalette(restoreFocus: false)
        AppLauncher.showInFinder(URL(fileURLWithPath: path))
    }

    /// The path as the editor stored it, so a remote project copies its `vscode-remote://` URI.
    func copyPath(_ project: RecentProject) {
        Paster.copyPlainText(project.path ?? project.uri)
        core.showMessage("Copied path")
    }

    private static func open(
        _ project: RecentProject, build: EditorBuild, application: URL
    ) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        if let path = project.path {
            _ = try await NSWorkspace.shared.open(
                [URL(fileURLWithPath: path)], withApplicationAt: application,
                configuration: configuration)
            return
        }
        // Nothing on this Mac to hand over: the build's own scheme is what reaches the remote.
        guard let url = remoteHandoff(project, build: build) else { return }
        _ = try await NSWorkspace.shared.open(url, configuration: configuration)
    }

    /// `vscode://vscode-remote/…` is the shape the editor's URL handler expects a remote in.
    private static func remoteHandoff(_ project: RecentProject, build: EditorBuild) -> URL? {
        let rest = project.uri.dropFirst("vscode-remote://".count)
        return URL(string: "\(build.urlScheme)://vscode-remote/\(rest)")
    }

    /// Launch Services first, so a build registering no scheme still turns up in the index's scan.
    private func applicationURL(for build: EditorBuild) -> URL? {
        if let scheme = URL(string: build.urlScheme + "://"),
            let handler = NSWorkspace.shared.urlForApplication(toOpen: scheme)
        {
            return handler
        }
        return appIndex.apps.first {
            $0.kind == .application && $0.url.lastPathComponent == build.bundleFileName
        }?.url
    }

    func openEditor() {
        guard let application = applicationURL else { return }
        AppLauncher.launch(application)
    }
}
