import AppKit
import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: ReleaseStore
    let openSettings: () -> Void
    let openDetails: (ReleaseItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let errorMessage = store.errorMessage, store.releases.isEmpty {
                ErrorStateView(message: errorMessage) {
                    Task { await store.refresh(sendNotifications: false) }
                }
            } else {
                content
            }

            Divider()
            footer
        }
        .frame(width: 430, height: 620)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: store.isCodexRunning ? "bolt.circle.fill" : "bolt.circle")
                    .foregroundStyle(store.isCodexRunning ? .green : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Codex Update Companion")
                        .font(.headline)
                    Text(store.isCodexRunning ? "Codex 실행 중" : "Codex 대기 중")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await store.refresh(sendNotifications: false) }
                } label: {
                    Image(systemName: store.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("새로고침")
                .disabled(store.isLoading)

                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("설정")
            }

            HStack(spacing: 8) {
                Button {
                    store.open(store.changelogURL)
                } label: {
                    Label("OpenAI Codex changelog", systemImage: "safari")
                }
                .buttonStyle(.link)

                Spacer()

                if store.unreadCount > 0 {
                    Button("모두 읽음") {
                        store.markAllRead()
                    }
                    .buttonStyle(.borderless)
                }
            }
            .font(.caption)

            CurrentVersionView(store: store, compact: true)

            if let errorMessage = store.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                    Text(errorMessage)
                        .lineLimit(2)
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(8)
                .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
    }

    private var content: some View {
        Group {
            if store.visibleReleases.isEmpty {
                EmptyStateView {
                    Task { await store.refresh(sendNotifications: false) }
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(store.visibleReleases) { release in
                            ReleaseCardView(
                                store: store,
                                item: release,
                                openDetails: { openDetails(release) }
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("Unofficial companion app. Not affiliated with OpenAI.")
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("앱 종료")
        }
        .font(.caption2)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("업데이트를 불러오지 못했습니다")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button("다시 시도", action: retry)
            Spacer()
        }
        .padding()
    }
}

private struct EmptyStateView: View {
    let refresh: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("표시할 업데이트가 없습니다")
                .font(.headline)
            Text("필터를 조정하거나 데이터를 새로고침하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("새로고침", action: refresh)
            Spacer()
        }
        .padding()
    }
}
