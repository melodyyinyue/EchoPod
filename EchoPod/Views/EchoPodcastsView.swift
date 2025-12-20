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
							EchoPodcastRow(item: item)
						}
					}
				}
			}
			.navigationTitle("我的回音播客")
		}
	}
}

struct EchoPodcastRow: View {
	@Bindable var item: EchoPodcast
	var body: some View {
		HStack(spacing: 12) {
			// 封面缩略图
			Group {
				if let coverURL = item.coverURL, let url = URL(string: coverURL) {
					AsyncImage(url: url) { phase in
						switch phase {
						case .success(let image):
							image
								.resizable()
								.aspectRatio(contentMode: .fill)
						case .failure:
							defaultCover
						default:
							ProgressView()
						}
					}
				} else {
					defaultCover
				}
			}
			.frame(width: 50, height: 50)
			.clipShape(RoundedRectangle(cornerRadius: 8))
			
			VStack(alignment: .leading, spacing: 4) {
				HStack {
					Text(item.title)
						.font(.headline)
					
					if item.isGenerating {
						ProgressView()
							.scaleEffect(0.6)
					} else if item.isFailed {
						Image(systemName: "exclamationmark.triangle.fill")
							.foregroundStyle(.red)
							.font(.caption)
					}
				}
				
				if item.isGenerating, let msg = item.statusMessage {
					Text(msg)
						.font(.caption)
						.foregroundStyle(.orange)
				} else if item.isFailed, let err = item.errorMessage {
					Text("失败: \(err)")
						.font(.caption)
						.foregroundStyle(.red)
						.lineLimit(1)
				} else {
					Text(item.question)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}
			}
			
			Spacer()
			
			// 状态指示
			if item.isCompleted {
				if item.localFilePath != nil {
					Image(systemName: "arrow.down.circle.fill")
						.foregroundStyle(.green)
						.font(.caption)
				}
			}
		}
		.padding(.vertical, 4)
	}
	
	private var defaultCover: some View {
		ZStack {
			LinearGradient(
				colors: [.purple.opacity(0.6), .blue.opacity(0.6)],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			Image(systemName: item.isGenerating ? "waveform" : "mic.fill")
				.foregroundStyle(.white)
				.font(.title3)
		}
	}
}
