import SwiftUI
import SwiftData

struct EchoPodcastsView: View {
	@Query(sort: [SortDescriptor(\EchoPodcast.createdAt, order: .reverse)])
	private var items: [EchoPodcast]

	var body: some View {
		NavigationStack {
			Group {
				if items.isEmpty {
					ContentUnavailableView("还没有回音播客", systemImage: "waveform", description: Text("在菜单栏图标里输入问题即可生成。"))
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				} else {
					List(items) { item in
						NavigationLink {
							EchoPodcastDetailView(item: item)
						} label: {
							VStack(alignment: .leading, spacing: 4) {
								Text(item.title)
									.font(.headline)
								Text(item.question)
									.font(.caption)
									.foregroundStyle(.secondary)
							}
						}
					}
				}
			}
			.navigationTitle("我的回音播客")
		}
	}
}
