import AppKit
import SwiftUI

struct CurrentVersionView: View {
    @ObservedObject var store: ReleaseStore
    var compact = false
    @State private var copiedUpdateCommand = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 8) {
                Label("Codex Mac 앱 버전", systemImage: "macwindow")
                    .font(compact ? .caption.weight(.semibold) : .headline)

                Spacer()

                if store.isCheckingVersions {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.75)
                }

                Button {
                    Task { await store.refreshCurrentVersions() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(store.isCheckingVersions)
                .help("설치된 Codex 버전 다시 확인")
            }

            VersionLine(
                title: "앱 배포",
                value: store.currentInstallation?.appDisplayVersion ?? "확인 중",
                path: store.currentInstallation?.appPath,
                icon: "macwindow",
                note: macAppNote,
                noteTone: macAppNoteTone
            )

            VersionLine(
                title: "관련 릴리즈",
                value: store.latestMacAppRelatedRelease?.version ?? "확인 중",
                path: nil,
                icon: "tag",
                note: macRelatedReleaseNote
            )

            if let release = store.latestMacAppRelatedRelease {
                Button {
                    store.open(release.url)
                } label: {
                    Label("Mac 앱 관련 릴리즈 보기", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            if shouldShowMacAppUpdateActions {
                HStack(spacing: 8) {
                    Button {
                        openMacAppUpdate()
                    } label: {
                        Label("Mac 앱 업데이트", systemImage: "arrow.down.circle")
                    }

                    Button {
                        openCodexApp()
                    } label: {
                        Label("Codex 열기", systemImage: "arrow.up.forward.app")
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            VersionLine(
                title: "CLI 보조",
                value: store.currentInstallation?.cliDisplayVersion ?? "확인 중",
                path: store.currentInstallation?.cliPath,
                icon: "terminal",
                note: cliNote,
                noteTone: cliNoteTone
            )

            if shouldShowCLIUpdateActions {
                HStack(spacing: 8) {
                    Button {
                        copyCLIUpdateCommand()
                    } label: {
                        Label(copiedUpdateCommand ? "복사됨" : "업데이트 명령 복사", systemImage: copiedUpdateCommand ? "checkmark" : "doc.on.doc")
                    }

                    if let releaseURL = (store.latestCLIRelease ?? store.latestGitHubRelease)?.url {
                        Button {
                            store.open(releaseURL)
                        } label: {
                            Label("최신 릴리즈 열기", systemImage: "arrow.up.right.square")
                        }
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)

                if let command = store.currentInstallation?.cliUpdateCommand {
                    Text(command)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if let checkedAt = store.currentInstallation?.checkedAt {
                Text("확인 시각: \(ReleaseFormatters.dateTime.string(from: checkedAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(compact ? 8 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var macAppNote: String? {
        guard let snapshot = store.currentInstallation else {
            return "Mac 앱 버전 확인 중"
        }

        if snapshot.appUpdateCheckFailed {
            return "Mac 앱 최신 여부를 확인하지 못했습니다. 네트워크 상태를 확인한 뒤 새로고침하세요."
        }

        switch snapshot.appUpdateState {
        case .updateAvailable:
            return "업데이트 가능: 최신 \(snapshot.appLatestDisplayVersion)"
        case .upToDate:
            return "최신 상태: \(snapshot.appLatestDisplayVersion)"
        case .newerThanFeed:
            return "설치 버전이 공개 업데이트 피드보다 높습니다."
        case .unknown:
            return "Mac 앱 최신 버전을 아직 비교하지 못했습니다."
        }
    }

    private var macRelatedReleaseNote: String? {
        guard let release = store.latestMacAppRelatedRelease else {
            return "GitHub 릴리즈를 불러오면 Mac 앱에 영향 있는 릴리즈를 따로 표시합니다."
        }

        return "\(ReleaseFormatters.date.string(from: release.publishedAt)) · GitHub 릴리즈 번호입니다. Mac 앱 배포 버전과 번호 체계가 다릅니다."
    }

    private var macAppNoteTone: VersionNoteTone {
        guard let snapshot = store.currentInstallation else {
            return .secondary
        }

        switch snapshot.appUpdateState {
        case .updateAvailable:
            return .warning
        case .upToDate:
            return .success
        case .newerThanFeed, .unknown:
            return .secondary
        }
    }

    private var shouldShowMacAppUpdateActions: Bool {
        store.currentInstallation?.isMacAppUpdateAvailable == true
    }

    private var cliNote: String? {
        guard let currentVersion = store.currentInstallation?.cliVersion else {
            return "CLI 버전 확인 중"
        }
        guard let latestRelease = store.latestCLIRelease ?? store.latestGitHubRelease else {
            return "GitHub 릴리즈를 불러오면 최신 여부를 비교합니다."
        }
        guard let latestVersion = CodexVersionParser.semanticVersion(from: latestRelease.version) else {
            return "최신 릴리즈 버전을 해석하지 못했습니다: \(latestRelease.version)"
        }

        switch CodexVersionParser.compareSemanticVersions(currentVersion, latestRelease.version) {
        case .orderedAscending:
            let installMethod = store.currentInstallation?.cliInstallMethod ?? "설치 방식 확인 불가"
            return "최신보다 낮음: GitHub 최신 \(latestVersion) · \(installMethod)"
        case .orderedSame:
            return "최신: GitHub 최신 \(latestVersion)와 같음"
        case .orderedDescending:
            return "설치 버전이 GitHub 최신 \(latestVersion)보다 높음"
        case nil:
            return "현재 CLI와 GitHub 릴리즈의 버전 형식을 비교하지 못했습니다."
        @unknown default:
            return nil
        }
    }

    private var shouldShowCLIUpdateActions: Bool {
        guard
            let currentVersion = store.currentInstallation?.cliVersion,
            let latestRelease = store.latestCLIRelease ?? store.latestGitHubRelease,
            CodexVersionParser.compareSemanticVersions(currentVersion, latestRelease.version) == .orderedAscending,
            store.currentInstallation?.cliUpdateCommand != nil
        else {
            return false
        }

        return true
    }

    private var cliNoteTone: VersionNoteTone {
        guard
            let currentVersion = store.currentInstallation?.cliVersion,
            let latestRelease = store.latestCLIRelease ?? store.latestGitHubRelease,
            let comparison = CodexVersionParser.compareSemanticVersions(currentVersion, latestRelease.version)
        else {
            return .secondary
        }

        switch comparison {
        case .orderedAscending:
            return .warning
        case .orderedSame:
            return .success
        case .orderedDescending:
            return .secondary
        }
    }

    private func openMacAppUpdate() {
        let url = store.currentInstallation?.appUpdateDownloadURL ?? AppConstants.codexMacDownloadURL
        store.open(url)
    }

    private func openCodexApp() {
        guard let appPath = store.currentInstallation?.appPath else {
            return
        }

        store.open(URL(fileURLWithPath: appPath))
    }

    private func copyCLIUpdateCommand() {
        guard let command = store.currentInstallation?.cliUpdateCommand else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        copiedUpdateCommand = true

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                copiedUpdateCommand = false
            }
        }
    }
}

private enum VersionNoteTone {
    case secondary
    case success
    case warning
}

private struct VersionLine: View {
    let title: String
    let value: String
    let path: String?
    let icon: String
    var note: String?
    var noteTone: VersionNoteTone = .secondary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let path, !path.isEmpty {
                    Text(path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(noteColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .font(.caption)
    }

    private var noteColor: Color {
        switch noteTone {
        case .secondary:
            .secondary
        case .success:
            .green
        case .warning:
            .orange
        }
    }
}
