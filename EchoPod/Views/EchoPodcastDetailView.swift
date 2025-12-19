import SwiftUI

struct EchoPodcastDetailView: View {
	@EnvironmentObject private var player: PlayerController
	let item: EchoPodcast

	private var url: URL? { URL(string: item.audioURL) }
	private var isCurrent: Bool {
		guard let url else { return false }
		return player.currentURL == url
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 12) {
				HStack(alignment: .top, spacing: 12) {
					if let cover = item.coverURL, let coverURL = URL(string: cover) {
						AsyncImage(url: coverURL) { phase in
							switch phase {
							case .empty:
								ProgressView().frame(width: 72, height: 72)
							case .success(let image):
								image.resizable().scaledToFill().frame(width: 72, height: 72).clipped().cornerRadius(10)
							case .failure:
								Image(systemName: "photo").frame(width: 72, height: 72)
							@unknown default:
								EmptyView()
							}
						}
					} else {
						Image(systemName: "waveform").frame(width: 72, height: 72)
					}

					VStack(alignment: .leading, spacing: 6) {
						Text(item.title)
							.font(.title2)
							.bold()
						Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					Spacer()
				}

				Text("问题")
					.font(.headline)
				Text(item.question)
					.textSelection(.enabled)

				HStack(spacing: 12) {
					Button {
						guard let url else { return }
						if isCurrent {
							player.togglePlayPause()
						} else {
							player.play(url: url)
						}
					} label: {
						Label(isCurrent && player.isPlaying ? "暂停" : "播放", systemImage: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
					}
					.disabled(url == nil)
				}
			}
			.padding()
		}
		.navigationTitle("回音播客")
	}
}
