import SwiftUI

struct ReleaseDetailView: View {
    @ObservedObject var store: ReleaseStore
    let item: ReleaseItem

    private var explanation: DetailedReleaseExplanation {
        DetailedExplanationBuilder.explanation(for: item)
    }

    private var digest: FriendlyReleaseDigest {
        FriendlyReleaseDigestBuilder.digest(for: item)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    explanationSection
                    changeSummarySection
                    allChangesSection
                    securityBugSection
                    impactSection
                    highlightsSection
                    rawNotesSection
                }
                .padding(22)
            }
        }
        .frame(minWidth: 560, minHeight: 520)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.impactLevel == .critical ? "exclamationmark.shield.fill" : "doc.text.magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(item.impactLevel == .critical ? .red : .accentColor)

            VStack(alignment: .leading, spacing: 5) {
                Text(explanation.headline)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Text("\(ReleaseFormatters.date.string(from: item.publishedAt)) · \(item.source.displayName)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.open(item.url)
            } label: {
                Label("원문 열기", systemImage: "arrow.up.right.square")
            }

            Button {
                item.isRead ? store.markUnread(item) : store.markRead(item)
            } label: {
                Label(item.isRead ? "읽지 않음" : "읽음", systemImage: item.isRead ? "circle" : "checkmark.circle")
            }
        }
        .padding(20)
    }

    private var explanationSection: some View {
        DetailSection(title: "풀어쓴 설명") {
            Text(explanation.plainLanguageSummary)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            Text("외부 LLM이나 계정 연동 없이, 공개 릴리즈 원문을 로컬 규칙으로 풀어쓴 설명입니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var changeSummarySection: some View {
        DetailSection(title: "한눈에 보기") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(digest.changes.prefix(5).enumerated()), id: \.element.id) { index, change in
                    FriendlyChangeRow(index: index + 1, change: change, showsEvidence: false)
                }
            }
        }
    }

    private var allChangesSection: some View {
        DetailSection(title: "세부 변경 전체") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(digest.changes.enumerated()), id: \.element.id) { index, change in
                    FriendlyChangeRow(index: index + 1, change: change, showsEvidence: true, showsUsage: true)
                }
            }
        }
    }

    private var securityBugSection: some View {
        DetailSection(title: "어떤 보안이고, 어떤 버그인가") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("보안/권한 관련", systemImage: "lock.shield")
                        .font(.subheadline.weight(.semibold))

                    if digest.securityRelatedChanges.isEmpty {
                        Text("이 릴리즈 노트에서는 명확한 보안 수정 항목이 감지되지 않았습니다.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(digest.securityRelatedChanges.enumerated()), id: \.element.id) { index, change in
                            FriendlyChangeRow(index: index + 1, change: change, showsEvidence: true, showsUsage: true)
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label("버그 수정 관련", systemImage: "wrench.and.screwdriver")
                        .font(.subheadline.weight(.semibold))

                    if digest.bugFixChanges.isEmpty {
                        Text("이 릴리즈 노트에서는 명확한 버그 수정 항목이 감지되지 않았습니다.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(digest.bugFixChanges.enumerated()), id: \.element.id) { index, change in
                            FriendlyChangeRow(index: index + 1, change: change, showsEvidence: true, showsUsage: true)
                        }
                    }
                }
            }
        }
    }

    private var impactSection: some View {
        DetailSection(title: "사용자에게 무슨 의미인가") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(explanation.userImpactBullets, id: \.self) { bullet in
                    BulletText(bullet)
                }
            }
        }
    }

    private var highlightsSection: some View {
        DetailSection(title: "주의할 점") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(item.impactLevel.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

                    ForEach(item.categories.prefix(5), id: \.self) { category in
                        Label(category.displayName, systemImage: category.systemImage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(explanation.attentionBullets, id: \.self) { bullet in
                    BulletText(bullet)
                }
            }
        }
    }

    private var rawNotesSection: some View {
        DetailSection(title: "원문 릴리즈 노트") {
            if item.rawBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("GitHub release 본문이 비어 있습니다. 원문 링크 또는 OpenAI changelog를 확인하세요.")
                    .foregroundStyle(.secondary)
            } else {
                Text(item.rawBody)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct FriendlyChangeRow: View {
    let index: Int
    let change: FriendlyChange
    let showsEvidence: Bool
    var showsUsage = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(index). \(change.areaTitle) 업데이트: \(change.kindTitle)")
                .font(.callout.weight(.semibold))
            Text(change.plainDetail)
                .fixedSize(horizontal: false, vertical: true)

            if showsUsage {
                VStack(alignment: .leading, spacing: 5) {
                    Text("왜 중요한가")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(change.whyItMatters)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("어떻게 써보나")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    ForEach(Array(change.howToUse.enumerated()), id: \.offset) { stepIndex, step in
                        Text("\(stepIndex + 1). \(step)")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("확인 위치: \(change.whereToCheck)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 3)
                }
                .padding(10)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            }

            if showsEvidence {
                Text("원문 근거: \(change.evidence)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct BulletText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .padding(.top, 7)
                .foregroundStyle(.secondary)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
