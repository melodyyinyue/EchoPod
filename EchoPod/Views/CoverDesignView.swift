import SwiftUI
import SwiftData
import AppKit

/// 封面设计历史记录
@Model
final class CoverDesignHistory {
	@Attribute(.unique) var id: String
	var prompt: String
	var imageURL: String
	var createdAt: Date
	var localFilePath: String?
	
	init(id: String = UUID().uuidString, prompt: String, imageURL: String) {
		self.id = id
		self.prompt = prompt
		self.imageURL = imageURL
		self.createdAt = Date()
	}
}

struct CoverDesignView: View {
	@Environment(\.modelContext) private var modelContext
	@Query(filter: #Predicate<AppSettings> { $0.id == "singleton" })
	private var settings: [AppSettings]
	
	@Query(sort: [SortDescriptor(\CoverDesignHistory.createdAt, order: .reverse)])
	private var history: [CoverDesignHistory]
	
	@State private var prompt: String = ""
	@State private var isGenerating = false
	@State private var currentImageURL: URL?
	@State private var errorMessage: String?
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				// 标题
				HStack {
					Image(systemName: "photo.artframe")
						.foregroundStyle(AppTheme.primary)
					Text("封面设计")
						.font(.title2)
						.bold()
				}
				
				// 预置信息提示区域
				VStack(alignment: .leading, spacing: 12) {
					// 主标题说明
					HStack(spacing: 8) {
						Image(systemName: "info.circle.fill")
							.foregroundStyle(AppTheme.primary)
						Text("生成你的专属播客封面")
							.font(.subheadline)
							.fontWeight(.medium)
					}
					
					// 封面规格说明
					HStack(spacing: 16) {
						VStack(alignment: .leading, spacing: 4) {
							HStack(spacing: 4) {
								Image(systemName: "square")
									.font(.caption)
								Text("正方形尺寸")
									.font(.caption)
									.fontWeight(.medium)
							}
							Text("1:1 比例，适配各平台")
								.font(.caption2)
								.foregroundStyle(.secondary)
						}
						
						Divider()
							.frame(height: 30)
						
						VStack(alignment: .leading, spacing: 4) {
							HStack(spacing: 4) {
								Image(systemName: "mic.fill")
									.font(.caption)
								Text("播客专属")
									.font(.caption)
									.fontWeight(.medium)
							}
							Text("AI 优化播客封面风格")
								.font(.caption2)
								.foregroundStyle(.secondary)
						}
						
						Divider()
							.frame(height: 30)
						
						VStack(alignment: .leading, spacing: 4) {
							HStack(spacing: 4) {
								Image(systemName: "sparkles")
									.font(.caption)
								Text("高清画质")
									.font(.caption)
									.fontWeight(.medium)
							}
							Text("专业级图像输出")
								.font(.caption2)
								.foregroundStyle(.secondary)
						}
					}
					.padding(.vertical, 8)
				}
				.padding()
				.background(
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.fill(AppTheme.primary.opacity(0.08))
						.overlay(
							RoundedRectangle(cornerRadius: 12, style: .continuous)
								.strokeBorder(AppTheme.primary.opacity(0.2), lineWidth: 1)
						)
				)
				
				// 输入区域
				VStack(alignment: .leading, spacing: 12) {
					Text("描述你的播客主题")
						.font(.headline)
					
					Text("请输入你的播客主题、内容方向或风格偏好，AI 会为你生成专属的正方形播客封面")
						.font(.caption)
						.foregroundStyle(.secondary)
					
					TextField("例如：科技播客，赛博朋克风格，霓虹灯光...", text: $prompt, axis: .vertical)
						.lineLimit(3...6)
						.textFieldStyle(.roundedBorder)
					
					// 设计建议标签
					VStack(alignment: .leading, spacing: 8) {
						Text("💡 参考设计建议")
							.font(.caption)
							.foregroundStyle(.secondary)
						
						HStack(spacing: 6) {
							Text("风格:")
								.font(.caption2)
								.foregroundStyle(.secondary)
							suggestionTag("极简主义")
							suggestionTag("赛博朋克")
							suggestionTag("复古怀旧")
							suggestionTag("自然清新")
						}
						
						HStack(spacing: 6) {
							Text("配色:")
								.font(.caption2)
								.foregroundStyle(.secondary)
							suggestionTag("渐变色")
							suggestionTag("暗色系")
							suggestionTag("明亮活泼")
							suggestionTag("单色调")
						}
						
						HStack(spacing: 6) {
							Text("元素:")
								.font(.caption2)
								.foregroundStyle(.secondary)
							suggestionTag("麦克风")
							suggestionTag("声波图案")
							suggestionTag("抽象几何")
							suggestionTag("光影效果")
						}
					}
					.padding(.top, 4)
					
					HStack {
						Button {
							Task { await generateCover() }
						} label: {
							HStack {
								if isGenerating {
									ProgressView()
										.controlSize(.small)
								}
								Text(isGenerating ? "生成中..." : "生成封面")
							}
						}
						.buttonStyle(.borderedProminent)
						.tint(AppTheme.primary)
						.disabled(isGenerating || prompt.isEmpty)
						
						if currentImageURL != nil {
							Button("换一个") {
								Task { await generateCover() }
							}
							.buttonStyle(.bordered)
							.disabled(isGenerating)
						}
					}
				}
				.padding()
				.background(
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.fill(AppTheme.background)
				)
				
				// 当前生成的封面
				if let url = currentImageURL {
					VStack(alignment: .leading, spacing: 12) {
						Text("生成结果")
							.font(.headline)
						
						AsyncImage(url: url) { phase in
							switch phase {
							case .empty:
								ProgressView()
									.frame(width: 300, height: 300)
							case .success(let image):
								image
									.resizable()
									.aspectRatio(contentMode: .fit)
									.frame(maxWidth: 400, maxHeight: 400)
									.clipShape(RoundedRectangle(cornerRadius: 16))
									.shadow(color: AppTheme.primary.opacity(0.3), radius: 10)
							case .failure:
								VStack {
									Image(systemName: "exclamationmark.triangle")
										.font(.largeTitle)
										.foregroundStyle(.red)
									Text("图片加载失败")
										.font(.caption)
								}
								.frame(width: 300, height: 300)
							@unknown default:
								EmptyView()
							}
						}
						
						HStack(spacing: 12) {
							Button {
								saveToLocal(url: url)
							} label: {
								Label("保存到本地", systemImage: "square.and.arrow.down")
							}
							.buttonStyle(.borderedProminent)
							.tint(AppTheme.primary)
						}
					}
					.padding()
					.background(
						RoundedRectangle(cornerRadius: 12, style: .continuous)
							.fill(AppTheme.background)
					)
				}
				
				// 错误提示
				if let error = errorMessage {
					HStack {
						Image(systemName: "exclamationmark.triangle.fill")
							.foregroundStyle(.red)
						Text(error)
							.foregroundStyle(.red)
					}
					.padding()
					.background(Color.red.opacity(0.1))
					.clipShape(RoundedRectangle(cornerRadius: 8))
				}
				
				// 历史记录
				if !history.isEmpty {
					VStack(alignment: .leading, spacing: 12) {
						HStack {
							Text("历史记录")
								.font(.headline)
							Spacer()
							Button("清空") {
								clearHistory()
							}
							.font(.caption)
							.foregroundStyle(.secondary)
						}
						
						LazyVGrid(columns: [
							GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12)
						], spacing: 12) {
							ForEach(history) { item in
								historyItem(item)
							}
						}
					}
					.padding()
					.background(
						RoundedRectangle(cornerRadius: 12, style: .continuous)
							.fill(AppTheme.background)
					)
				}
			}
			.padding()
		}
		.navigationTitle("封面设计")
	}
	
	/// 建议标签视图 - 可点击添加到输入框
	@ViewBuilder
	private func suggestionTag(_ text: String) -> some View {
		Button {
			if prompt.isEmpty {
				prompt = text
			} else if !prompt.contains(text) {
				prompt += "，\(text)"
			}
		} label: {
			Text(text)
				.font(.caption2)
				.padding(.horizontal, 8)
				.padding(.vertical, 4)
				.background(
					Capsule()
						.fill(AppTheme.primary.opacity(0.1))
				)
				.foregroundStyle(AppTheme.primary)
		}
		.buttonStyle(.plain)
	}
	
	@ViewBuilder
	private func historyItem(_ item: CoverDesignHistory) -> some View {
		VStack(spacing: 8) {
			AsyncImage(url: URL(string: item.imageURL)) { phase in
				switch phase {
				case .success(let image):
					image
						.resizable()
						.aspectRatio(contentMode: .fill)
				default:
					AppTheme.primaryGradient
				}
			}
			.frame(width: 120, height: 120)
			.clipShape(RoundedRectangle(cornerRadius: 8))
			
			Text(item.prompt)
				.font(.caption2)
				.lineLimit(2)
				.foregroundStyle(.secondary)
		}
		.contextMenu {
			Button {
				prompt = item.prompt
				currentImageURL = URL(string: item.imageURL)
			} label: {
				Label("使用此 Prompt", systemImage: "doc.on.doc")
			}
			
			Button {
				if let url = URL(string: item.imageURL) {
					saveToLocal(url: url)
				}
			} label: {
				Label("保存到本地", systemImage: "square.and.arrow.down")
			}
			
			Button(role: .destructive) {
				modelContext.delete(item)
				try? modelContext.save()
			} label: {
				Label("删除", systemImage: "trash")
			}
		}
	}
	
	@MainActor
	private func generateCover() async {
		let s = settings.first ?? AppSettings()
		
		guard let apiKey = s.volcCoverAPIKey, !apiKey.isEmpty else {
			errorMessage = "请先在设置中填写封面生成 API Key"
			return
		}
		
		isGenerating = true
		errorMessage = nil
		defer { isGenerating = false }
		
		let baseURL = URL(string: s.volcCoverBaseURL ?? "https://ark.cn-beijing.volces.com")
		let client = VolcEchoClient(podcastAPIKey: "", coverAPIKey: apiKey, coverBaseURL: baseURL)
		
		// 构建优化的 Prompt
		let fullPrompt = """
\(prompt)，
专业播客封面设计，高级质感，现代简约风格，
渐变色背景，柔和光影，高清画质
"""
		
		do {
			if let urlString = try await client.generateCover(prompt: fullPrompt) {
				currentImageURL = URL(string: urlString)
				
				// 保存到历史记录
				let historyItem = CoverDesignHistory(prompt: prompt, imageURL: urlString)
				modelContext.insert(historyItem)
				try? modelContext.save()
			} else {
				errorMessage = "生成返回空结果"
			}
		} catch {
			errorMessage = "生成失败：\(error.localizedDescription)"
		}
	}
	
	private func saveToLocal(url: URL) {
		Task {
			do {
				let (data, _) = try await URLSession.shared.data(from: url)
				
				let panel = NSSavePanel()
				panel.allowedContentTypes = [.png, .jpeg]
				panel.nameFieldStringValue = "podcast_cover_\(Date().timeIntervalSince1970).png"
				panel.title = "保存封面"
				
				if panel.runModal() == .OK, let saveURL = panel.url {
					try data.write(to: saveURL)
				}
			} catch {
				errorMessage = "保存失败：\(error.localizedDescription)"
			}
		}
	}
	
	private func clearHistory() {
		for item in history {
			modelContext.delete(item)
		}
		try? modelContext.save()
	}
}
