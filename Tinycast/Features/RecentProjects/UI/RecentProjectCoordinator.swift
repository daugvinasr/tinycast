import AppKit

/// Owns the recent-projects flow: the read behind Search Recent Projects, and the one open funnel.
@MainActor
@Observable
final class RecentProjectCoordinator {
    /// VS Code's own list, as last read; the screen and the open funnel both resolve against it.
    private(set) var projects: [RecentProject] = []

    private let appIndex: AppIndex
    private let paletteCoordinator: PaletteCoordinator
    private unowned let core: AppCore
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init(appIndex: AppIndex, paletteCoordinator: PaletteCoordinator, core: AppCore) {
        self.appIndex = appIndex
        self.paletteCoordinator = paletteCoordinator
        self.core = core
    }

    /// Launch Services first, so a copy kept outside the search scopes still turns up.
    var applicationURL: URL? {
        if let scheme = URL(string: "vscode://"),
            let handler = NSWorkspace.shared.urlForApplication(toOpen: scheme)
        {
            return handler
        }
        return appIndex.apps.first {
            $0.kind == .application && $0.url.lastPathComponent == "Visual Studio Code.app"
        }?.url
    }

    var isInstalled: Bool { applicationURL != nil }

    /// Re-read on every browser open: VS Code rewrites its list as each window closes.
    func refresh() {
        guard refreshTask == nil else { return }
        let home = URL(fileURLWithPath: NSHomeDirectory())
        refreshTask = Task {
            let found = await Task.detached { RecentProjectReader.read(home: home) }.value
            refreshTask = nil
            guard found != projects else { return }
            projects = found
        }
    }

    func showProjects() {
        refresh()
        paletteCoordinator.togglePalette(mode: .recentProjects)
    }

    /// The one funnel the screen and its menu reach.
    func open(_ project: RecentProject) {
        paletteCoordinator.hidePalette(restoreFocus: false)
        guard let application = applicationURL else {
            Task {
                await core.showNotice(
                    title: "Visual Studio Code Isn’t Installed",
                    message: "Install it to open a recent project.",
                    symbol: RecentProject.sfSymbol, tone: .danger)
            }
            return
        }
        Task {
            do {
                _ = try await NSWorkspace.shared.open(
                    [URL(fileURLWithPath: project.path)], withApplicationAt: application,
                    configuration: NSWorkspace.OpenConfiguration())
            } catch {
                await core.showNotice(
                    title: "Couldn’t Open \(project.name)", message: error.localizedDescription,
                    symbol: RecentProject.sfSymbol, tone: .danger)
            }
        }
    }

    func showInFinder(_ project: RecentProject) {
        paletteCoordinator.hidePalette(restoreFocus: false)
        AppLauncher.showInFinder(URL(fileURLWithPath: project.path))
    }

    func copyPath(_ project: RecentProject) {
        Paster.copyPlainText(project.path)
        core.showMessage("Copied path")
    }
}
