import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ReleaseStore

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                title
                versionSection
                behaviorSection
                interestSection
                dataSection
                noticeSection
            }
            .padding(22)
        }
        .frame(minWidth: 500, minHeight: 560)
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Codex Update Companion")
                .font(.title2.weight(.semibold))
            Text("공개 업데이트 정보만 확인하는 비공식 메뉴바 앱")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var versionSection: some View {
        SettingsSection(title: "현재 설치 버전") {
            CurrentVersionView(store: store)

            Text("Mac 앱 버전은 설치된 Codex.app에서, CLI 버전은 터미널의 codex --version 결과에서 확인합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var behaviorSection: some View {
        SettingsSection(title: "동작") {
            Toggle(
                "새 릴리즈 알림",
                isOn: Binding(
                    get: { store.notificationsEnabled },
                    set: { store.setNotificationsEnabled($0) }
                )
            )

            Toggle(
                "Mac 로그인 시 자동 실행",
                isOn: Binding(
                    get: { store.launchAtLoginEnabled },
                    set: { store.setLaunchAtLoginEnabled($0) }
                )
            )

            Toggle(
                "Codex 실행 중일 때만 메뉴바 아이콘 표시",
                isOn: Binding(
                    get: { store.onlyShowWhenCodexRuns },
                    set: { store.setOnlyShowWhenCodexRuns($0) }
                )
            )

            Text("이 옵션을 켜면 Codex가 꺼져 있을 때 메뉴바 아이콘도 숨겨집니다. 다시 설정하려면 Codex를 먼저 실행하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let message = store.settingsErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var interestSection: some View {
        SettingsSection(title: "관심 영역") {
            HStack {
                Button("전체 선택") {
                    Category.allCases.forEach { store.toggleCategory($0, enabled: true) }
                }
                Button("전체 해제") {
                    Category.allCases.forEach { store.toggleCategory($0, enabled: false) }
                }
                Spacer()
            }
            .buttonStyle(.borderless)
            .font(.caption)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(Category.allCases) { category in
                    Toggle(
                        isOn: Binding(
                            get: { store.enabledCategories.contains(category) },
                            set: { store.toggleCategory(category, enabled: $0) }
                        )
                    ) {
                        Label(category.displayName, systemImage: category.systemImage)
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }

    private var dataSection: some View {
        SettingsSection(title: "데이터") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("캐시된 릴리즈 \(store.releases.count)개")
                    if let lastRefreshAt = store.lastRefreshAt {
                        Text("마지막 새로고침: \(ReleaseFormatters.dateTime.string(from: lastRefreshAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    Task { await store.refresh(sendNotifications: false) }
                } label: {
                    Label("새로고침", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)

                Button(role: .destructive) {
                    store.clearCache()
                } label: {
                    Label("캐시 삭제", systemImage: "trash")
                }
            }

            HStack {
                Button {
                    store.open(store.githubReleasesWebURL)
                } label: {
                    Label("GitHub releases", systemImage: "arrow.up.right.square")
                }

                Button {
                    store.open(store.changelogURL)
                } label: {
                    Label("OpenAI changelog", systemImage: "safari")
                }
            }
            .buttonStyle(.borderless)
        }
    }

    private var noticeSection: some View {
        SettingsSection(title: "보안 및 개인정보") {
            Text("OpenAI 계정, GitHub 토큰, Codex 내부 파일, 사용자 프로젝트 폴더, Accessibility, Screen Recording 권한을 요구하지 않습니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Unofficial companion app. Not affiliated with OpenAI.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
