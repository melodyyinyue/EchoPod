import SwiftUI
import SwiftData

struct AllEpisodesView: View {
	@Environment(\.modelContext) private var modelContext

	@Query(sort: [
		SortDescriptor(\PodcastEpisode.publishedAt, order: .reverse),
		SortDescriptor(\PodcastEpisode.createdAt, order: .reverse)
	])
	private var episodes: [PodcastEpisode]

	@State private var isPresentingAdd = false
	@State private var isRefreshing = false

	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				HStack {
					Text("全部单集")
						.font(.title2)
						.bold()
					Spacer()
					Button {
						isPresentingAdd = true
					} label: {
						Label("订阅", systemImage: "plus")
					}
					Button {
						Task { @MainActor in await refreshAll() }
					} label: {
						Label(isRefreshing ? "刷新中" : "刷新", systemImage: "arrow.clockwise")
					}
					.disabled(isRefreshing)
				}
				.padding()

				if episodes.isEmpty {
					ContentUnavailableView("还没有单集", systemImage: "rectangle.stack", description: Text("先添加一个 RSS 订阅链接吧。"))
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				} else {
					List(episodes) { ep in
						NavigationLink {
							EpisodeDetailView(episode: ep)
						} label: {
							EpisodeRow(episode: ep)
						}
					}
				}
			}
			.sheet(isPresented: $isPresentingAdd) {
				AddSubscriptionSheet()
			}
		}
	}

	@MainActor
	private func refreshAll() async {
		isRefreshing = true
		defer { isRefreshing = false }

		let service = RSSService(modelContext: modelContext)
		do {
			try await service.refreshAllFeeds()
		} catch {
			// 最小实现：先不弹窗
		}
	}
}
