import SwiftUI

struct ReleaseCardView: View {
    @ObservedObject var store: ReleaseStore
    let item: ReleaseItem
    let openDetails: () -> Void

    private var digest: FriendlyReleaseDigest {
        FriendlyReleaseDigestBuilder.digest(for: item)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.version)
                            .font(.headline)
                        if !item.isRead {
                            Circle()
                                .fill(.blue)
                                .frame(width: 7, height: 7)
                        }
                    }

                    Text(ReleaseFormatters.date.string(from: item.publishedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ImpactBadge(level: item.impactLevel)
            }

            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(digest.changes.prefix(4).enumerated()), id: \.element.id) { index, change in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(index + 1). \(change.areaTitle) 업데이트: \(change.kindTitle)")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(change.plainDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            categoryChips

            HStack(spacing: 10) {
                Button(action: openDetails) {
                    Label("상세", systemImage: "doc.text.magnifyingglass")
                }

                Button {
                    store.open(item.url)
                } label: {
                    Label("원문", systemImage: "arrow.up.right.square")
                }

                Button {
                    item.isRead ? store.markUnread(item) : store.markRead(item)
                } label: {
                    Label(item.isRead ? "읽지 않음" : "읽음 처리", systemImage: item.isRead ? "circle" : "checkmark.circle")
                }

                Spacer()

                Text(item.source.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(item.isRead ? .clear : Color.blue.opacity(0.35), lineWidth: 1)
        )
    }

    private var categoryChips: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(item.categories.prefix(5)), id: \.self) { category in
                Label(category.displayName, systemImage: category.systemImage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

private struct ImpactBadge: View {
    let level: ImpactLevel

    var body: some View {
        Text(level.displayName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(level.foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(level.tintColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
    }
}

private extension ImpactLevel {
    var tintColor: Color {
        switch self {
        case .low:
            .secondary
        case .medium:
            .blue
        case .high:
            .orange
        case .critical:
            .red
        }
    }

    var foregroundColor: Color {
        switch self {
        case .low:
            .secondary
        case .medium:
            .blue
        case .high:
            .orange
        case .critical:
            .red
        }
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) {
                content
            }

            VStack(alignment: .leading, spacing: spacing) {
                content
            }
        }
    }
}
