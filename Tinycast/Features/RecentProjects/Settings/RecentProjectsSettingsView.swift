import SwiftUI

/// The editor whose recently-opened list Search Recent Projects reads, and what a row opens in.
struct RecentProjectsSettingsView: View {
    @Environment(AppCore.self) private var core
    @Environment(AppSettings.self) private var settings

    private var coordinator: RecentProjectCoordinator { core.recentProjectCoordinator }

    var body: some View {
        @Bindable var settings = settings
        return Form {
            Section {
                Toggle(isOn: $settings.recentProjectsEnabled) {
                    SettingsRowTitle(.recentProjectsRecentProjects, "Open recent projects")
                    Text(
                        "Reads the recently-opened list your editor already keeps. Nothing leaves "
                            + "this Mac.")
                }
            } header: {
                SettingsSectionHeader(.recentProjectsRecentProjects)
            }

            FeatureCommandsSection(owner: .recentProjects, anchor: .recentProjectsCommands)
                .settingsEnabled(settings.recentProjectsEnabled)

            Section {
                Picker(selection: editorSelection) {
                    ForEach(editors) { editor in
                        Text(editor.name).tag(editor.id)
                    }
                } label: {
                    SettingsRowTitle(.recentProjectsEditor, "Editor")
                    Text("Which build's list is read, and what a project opens in.")
                }
                Button("Open \(coordinator.build.name)") { coordinator.openEditor() }
                    .settingsEnabled(coordinator.isBuildInstalled)
            } header: {
                SettingsSectionHeader(.recentProjectsEditor)
            } footer: {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .settingsEnabled(settings.recentProjectsEnabled)
        }
        .formStyle(.grouped)
        .settingsScrollTarget(.recentProjects)
        .releasesFocusOnOutsideClick()
        // An editor can be installed or removed while Settings sits closed.
        .task(id: settings.recentProjectsEnabled) {
            coordinator.refreshInstalledBuilds()
            coordinator.refresh()
        }
    }

    /// An unset preference still shows the build being read, which is the first one installed.
    private var editorSelection: Binding<String> {
        Binding(get: { coordinator.build.id }, set: { settings.recentProjectsEditor = $0 })
    }

    /// The installed builds, plus whatever is already chosen so a picker never shows blank.
    private var editors: [EditorBuild] {
        let installed = coordinator.installedBuilds
        guard let chosen = EditorBuild.named(settings.recentProjectsEditor),
            !installed.contains(chosen)
        else { return installed.isEmpty ? [coordinator.build] : installed }
        return installed + [chosen]
    }

    private var footer: String {
        guard coordinator.isBuildInstalled else {
            return "\(coordinator.build.name) isn't installed on this Mac."
        }
        let count = coordinator.projects.count
        return count == 1 ? "1 recent project found." : "\(count) recent projects found."
    }
}
