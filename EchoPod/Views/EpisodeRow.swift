import SwiftUI

struct EpisodeRow: View {
	@EnvironmentObject private var player: PlayerController
	@EnvironmentObject private var downloads: EpisodeDownloadManager
	let episode: PodcastEpisode

	private var remoteURL: URL? { URL(string: episode.audioURL) }
	private var localURL: URL? {
		guard let p = episode.localFilePath else { return nil }
		let url = URL(fileURLWithPath: p)
		return FileManager.default.fileExists(atPath: url.path) ? url : nil
	}
	private var effectiveURL: URL? { localURL ?? remoteURL }

	private var isCurrent: Bool {
		guard let effectiveURL else { return false }
		return player.currentURL == effectiveURL
	}

	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: isCurrent && player.isPlaying ? "waveform" : "headphones")
				.frame(width: 28)
			VStack(alignment: .leading, spacing: 4) {
				Text(episode.title)
					.font(.headline)
				HStack(spacing: 8) {
					Text(episode.feed?.title ?? "")
						.lineLimit(1)
					Text(episode.publishedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
				}
				.font(.caption)
				.foregroundStyle(.secondary)
			}
			Spacer()

			HStack(spacing: 8) {
				if downloads.isDownloading(guid: episode.guid) {
					ProgressView(value: downloads.progress(guid: episode.guid) ?? 0)
						.frame(width: 44)
				} else if localURL != nil {
					Image(systemName: "arrow.down.circle.fill")
						.foregroundStyle(.secondary)
				}
				Button {
					guard let url = effectiveURL else { return }
					if isCurrent {
						player.togglePlayPause()
					} else {
						player.play(url: url)
					}
				} label: {
					Image(systemName: (isCurrent && player.isPlaying) ? "pause.fill" : "play.fill")
				}
				.buttonStyle(.borderless)
				.disabled(effectiveURL == nil)
			}
		}
		.padding(.vertical, 4)
	}
}
