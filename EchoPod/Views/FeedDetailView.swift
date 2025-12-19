import SwiftUI
import SwiftData

struct FeedDetailView: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.modelContext) private var modelContext

	let feed: PodcastFeed
	@State private var isRefreshing = false

	private var episodesSorted: [PodcastEpisode] {
		feed.episodes.sorted {
			let lhs = $0.publishedAt ?? .distantPast
			let rhs = $1.publishedAt ?? .distantPast
			if lhs != rhs { return lhs > rhs }
			return $0.createdAt > $1.createdAt
		}
	}

	var body: some View {
		VStack(spacing: 0) {
			HStack(alignment: .top) {
				VStack(alignment: .leading, spacing: 6) {
					Text(feed.title ?? "未命名订阅")
						.font(.title2)
						.bold()
					Text(feed.url)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				Spacer()
				Button {
					Task { @MainActor in await refresh() }
				} label: {
					Label(isRefreshing ? "刷新中" : "刷新", systemImage: "arrow.clockwise")
				}
				.disabled(isRefreshing)

				Button(role: .destructive) {
					unsubscribe()
				} label: {
					Label("取消订阅", systemImage: "trash")
				}
			}
			.padding()

			if episodesSorted.isEmpty {
				ContentUnavailableView("暂无单集", systemImage: "rectangle.stack")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				List(episodesSorted) { ep in
					NavigationLink {
						EpisodeDetailView(episode: ep)
					} label: {
						EpisodeRow(episode: ep)
					}
				}
			}
		}
	}

	@MainActor
	private func refresh() async {
		isRefreshing = true
		defer { isRefreshing = false }

		let service = RSSService(modelContext: modelContext)
		do {
			try await service.refresh(feed: feed)
			try? modelContext.save()
		} catch {
			// 最小实现：先不弹窗
		}
	}

	private func unsubscribe() {
		modelContext.delete(feed)
		try? modelContext.save()
		dismiss()
	}
}
