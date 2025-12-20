import SwiftUI
import SwiftData

struct SubscriptionsView: View {
	@Environment(\.modelContext) private var modelContext

	@Query(sort: [SortDescriptor(\PodcastFeed.createdAt, order: .reverse)])
	private var feeds: [PodcastFeed]

	@State private var isPresentingAdd = false
	@State private var isRefreshing = false

	var body: some View {
		NavigationStack {
			Group {
				if feeds.isEmpty {
					ContentUnavailableView(
						"还没有订阅",
						systemImage: "dot.radiowaves.left.and.right",
						description: Text("点击右上角“+”添加 RSS 链接")
					)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
				} else {
                    List {
                        ForEach(feeds) { feed in
                            NavigationLink(value: feed) {
                                HStack(spacing: 10) {
                                    AsyncImage(url: URL(string: feed.imageURL ?? "")) { phase in
                                        switch phase {
                                        case .success(let img):
                                            img.resizable().scaledToFill()
                                        default:
                                            LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        }
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(feed.title ?? feed.url)
                                            .font(.headline)
                                        Text(feed.url)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    unsubscribe(feed)
                                } label: {
                                    Text("取消订阅")
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    }
				}
			}
			.navigationTitle("我的订阅")
			.toolbar {
				ToolbarItemGroup(placement: .primaryAction) {
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
			}
			.navigationDestination(for: PodcastFeed.self) { feed in
				FeedDetailView(feed: feed)
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
			try? modelContext.save()
		} catch {
			// 最小实现：先不弹窗
		}
	}

	private func delete(at offsets: IndexSet) {
		for index in offsets {
			modelContext.delete(feeds[index])
		}
		try? modelContext.save()
	}

	private func unsubscribe(_ feed: PodcastFeed) {
		modelContext.delete(feed)
		try? modelContext.save()
	}
}
