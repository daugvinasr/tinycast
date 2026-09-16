import SwiftUI

struct RecentProjectsList: View {

    @Environment(\.metrics) private var metrics
    let results: [RecentProject]
    let home: String
    let selectedID: RecentProject.ID?
    let scroll: ScrollIntent
    let onSelect: (RecentProject) -> Void
    let onActivate: () -> Void
    let onActions: (RecentProject) -> Void

    private var firstRowSelected: Bool {
        selectedID != nil && selectedID == results.first?.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { project in
                        RecentProjectRow(
                            project: project, home: home, selected: project.id == selectedID
                        )
                        .selectionFrame(project.id == selectedID)
                        .contentShape(Rectangle())
                        .onRowClick(select: { onSelect(project) }, activate: onActivate)
                        .onRightClick { onActions(project) }
                    }
                }
                .padding(.horizontal, metrics.spacing.md)
                .padding(.top, metrics.spacing.xs)
                .padding(.bottom, metrics.spacing.md)
                .hideNativeScrollers()
                .scrollOriginAnchor()
            }
            .edgeDissolve()
            .thinScrollbar()
            .scrollFollowsSelection(
                scroll, row: selectedID, atOrigin: firstRowSelected, proxy: proxy)
        }
    }
}

private struct RecentProjectRow: View {

    @Environment(\.metrics) private var metrics
    let project: RecentProject
    let home: String
    let selected: Bool
    @State private var hovered = false

    private var fill: Color {
        if selected { return Theme.Colors.selection }
        if hovered { return Theme.Colors.rowHover }
        return .clear
    }

    var body: some View {
        HStack(spacing: metrics.spacing.lg) {
            RoundedRectangle(cornerRadius: metrics.radius.thumbnail, style: .continuous)
                .fill(Theme.Colors.controlSurface)
                .frame(width: metrics.size.rowIcon, height: metrics.size.rowIcon)
                .overlay(
                    Image(systemName: project.symbol)
                        .font(.system(size: 12))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary))
            Text(project.name)
                .font(metrics.typography.rowTitle)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: metrics.spacing.lg)
            Text(project.subtitle(home: home))
                .font(metrics.typography.rowTrailing)
                .foregroundStyle(Theme.Colors.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, metrics.spacing.md)
        .padding(.vertical, metrics.spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: metrics.radius.row, style: .continuous).fill(fill)
        )
        .armedHover($hovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(project.name)
        .accessibilityValue(project.subtitle(home: home))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
