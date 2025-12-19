import SwiftUI
import SwiftData

struct EpisodeDetailView: View {
	@Environment(\.modelContext) private var modelContext
	@EnvironmentObject private var player: PlayerController
	@EnvironmentObject private var downloads: EpisodeDownloadManager
	let episode: PodcastEpisode

	@State private var cacheError: String?

	private var remoteURL: URL? {
		URL(string: episode.audioURL)
	}

	private var localURL: URL? {
		guard let p = episode.localFilePath else { return nil }
		let url = URL(fileURLWithPath: p)
		return FileManager.default.fileExists(atPath: url.path) ? url : nil
	}

	private var effectiveURL: URL? {
		localURL ?? remoteURL
	}

	private var isCurrent: Bool {
		guard let effectiveURL else { return false }
		return player.currentURL == effectiveURL
	}

	private var currentTimeBinding: Binding<Double> {
		Binding(
			get: { isCurrent ? player.currentTime : 0 },
			set: { newValue in
				guard isCurrent else { return }
				player.seek(to: newValue)
			}
		)
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 12) {
				Text(episode.title)
					.font(.title2)
					.bold()

				HStack(spacing: 8) {
					if let name = episode.feed?.title {
						Text(name)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					Text(episode.publishedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
						.font(.caption)
						.foregroundStyle(.secondary)
				}

				VStack(alignment: .leading, spacing: 8) {
					if let cacheError {
						Text(cacheError)
							.font(.caption)
							.foregroundStyle(.red)
					}

					HStack(spacing: 12) {
						if downloads.isDownloading(guid: episode.guid) {
							ProgressView(value: downloads.progress(guid: episode.guid) ?? 0)
								.frame(width: 120)
						}
						Button {
							guard let url = effectiveURL else { return }
							if isCurrent {
								player.togglePlayPause()
							} else {
								player.play(url: url)
							}
						} label: {
							Label(
								(isCurrent && player.isPlaying) ? "暂停" : "播放",
								systemImage: (isCurrent && player.isPlaying) ? "pause.fill" : "play.fill"
							)
						}
						.disabled(effectiveURL == nil)

						Button {
							Task { @MainActor in await toggleCache() }
						} label: {
							if localURL != nil {
								Label("删除缓存", systemImage: "trash")
							} else if downloads.isDownloading(guid: episode.guid) {
								Label("取消缓存", systemImage: "xmark.circle")
							} else {
								Label("缓存", systemImage: "arrow.down.circle")
							}
						}
						.disabled(remoteURL == nil)

						Picker("倍速", selection: $player.rate) {
							Text("1.0x").tag(Float(1.0))
							Text("1.25x").tag(Float(1.25))
							Text("1.5x").tag(Float(1.5))
							Text("2.0x").tag(Float(2.0))
						}
						.pickerStyle(.menu)
						.onChange(of: player.rate) { _, _ in
							player.applyRate()
						}
					}

					if isCurrent {
						Slider(value: currentTimeBinding, in: 0...(max(1, player.duration)))

						HStack {
							Text(formatTime(player.currentTime))
							Spacer()
							Text(formatTime(player.duration))
						}
						.font(.caption)
						.foregroundStyle(.secondary)
					}
				}
				.padding(.vertical, 8)

				if let summary = episode.summary, !summary.isEmpty {
					Text(summary)
						.textSelection(.enabled)
				}
			}
			.padding()
		}
		.navigationTitle("单集")
	}

	@MainActor
	private func toggleCache() async {
		cacheError = nil

		if let path = episode.localFilePath, !path.isEmpty {
			do {
				try EpisodeCacheService.removeCachedFile(atPath: path)
				episode.localFilePath = nil
				episode.downloadedAt = nil
				try? modelContext.save()
			} catch {
				cacheError = "删除缓存失败：\(error.localizedDescription)"
			}
			return
		}

		guard let remoteURL else {
			cacheError = "音频链接无效"
			return
		}

		if downloads.isDownloading(guid: episode.guid) {
			downloads.cancelDownload(guid: episode.guid)
			return
		}

		downloads.startDownload(remoteURL: remoteURL, guid: episode.guid) { result in
			switch result {
			case .success(let dest):
				episode.localFilePath = dest.path
				episode.downloadedAt = Date()
				try? modelContext.save()
			case .failure(let error):
				cacheError = "缓存失败：\(error.localizedDescription)"
			}
		}
	}

	private func formatTime(_ seconds: Double) -> String {
		guard seconds.isFinite, seconds > 0 else { return "0:00" }
		let total = Int(seconds.rounded())
		let m = total / 60
		let s = total % 60
		return String(format: "%d:%02d", m, s)
	}
}
