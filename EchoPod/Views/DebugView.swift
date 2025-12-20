import SwiftUI
import SwiftData

struct DebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<AppSettings> { $0.id == "singleton" })
    private var settings: [AppSettings]

    @StateObject private var logStore = DebugLogStore.shared
    @State private var autoScroll = true
    @State private var coverPrompt: String = "播客主题：简单对话，复古霓虹风格"
    @State private var coverURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Text("调试日志")
                    .font(.headline)
				
				Spacer()
				
				Text("\(logStore.logs.count) 条")
					.font(.caption)
					.foregroundStyle(.secondary)
				
				Toggle("自动滚动", isOn: $autoScroll)
					.toggleStyle(.switch)
					.controlSize(.small)
				
                Button("清空") {
                    logStore.clear()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // 封面生成测试
            DisclosureGroup("封面生成测试") {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("提示词（Prompt）", text: $coverPrompt, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("生成封面") { Task { await testGenerateCover() } }
                                .buttonStyle(.borderedProminent)
                            if let url = coverURL {
                                Link("打开图片", destination: url)
                            }
                        }
                    }
                    if let url = coverURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            default:
                                LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            }
                        }
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
                    }
                }
                .padding(12)
            }
            .padding(.horizontal)

            Divider()

            // 日志列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(logStore.logs) { entry in
                            LogEntryRow(entry: entry)
								.id(entry.id)
						}
					}
					.padding(8)
				}
				.onChange(of: logStore.logs.count) { _, _ in
					if autoScroll, let last = logStore.logs.last {
						withAnimation(.easeOut(duration: 0.1)) {
							proxy.scrollTo(last.id, anchor: .bottom)
						}
					}
				}
			}
			.background(Color(nsColor: .textBackgroundColor))
        }
        .navigationTitle("调试")
    }

    private func testGenerateCover() async {
        let s = settings.first ?? AppSettings()
        let key = s.volcCoverAPIKey ?? ""
        if key.isEmpty {
            logStore.error("未设置封面生成 API Key，请在设置页填写")
            return
        }
        let base = URL(string: s.volcCoverBaseURL ?? "https://ark.cn-beijing.volces.com")
        let client = VolcEchoClient(podcastAPIKey: "", coverAPIKey: key, coverBaseURL: base)
        do {
            if let urlString = try await client.generateCover(prompt: coverPrompt), let url = URL(string: urlString) {
                coverURL = url
                logStore.success("封面生成成功：\(urlString)")
            } else {
                logStore.warning("封面生成返回空结果")
            }
        } catch {
            logStore.error("封面生成失败：\(error.localizedDescription)")
            logStore.warning("当前 Base URL：\(s.volcCoverBaseURL ?? "未设置")")
            logStore.info("请确认网络可访问该域名，或在设置中更换 Base URL（例如企业代理或不同地域域名）")
        }
    }
}

struct LogEntryRow: View {
	let entry: DebugLogStore.LogEntry
	
	private var timeString: String {
		let formatter = DateFormatter()
		formatter.dateFormat = "HH:mm:ss.SSS"
		return formatter.string(from: entry.timestamp)
	}
	
	private var levelColor: Color {
		switch entry.level {
		case .info: return .primary
		case .success: return .green
		case .warning: return .orange
		case .error: return .red
		case .receive: return .blue
		case .send: return .purple
		case .event: return .cyan
		}
	}
	
	var body: some View {
		HStack(alignment: .top, spacing: 8) {
			Text(timeString)
				.font(.system(size: 11, design: .monospaced))
				.foregroundStyle(.secondary)
				.frame(width: 85, alignment: .leading)
			
			Text(entry.level.rawValue)
				.font(.system(size: 12))
			
			Text(entry.message)
				.font(.system(size: 12, design: .monospaced))
				.foregroundStyle(levelColor)
				.textSelection(.enabled)
		}
		.padding(.vertical, 2)
		.padding(.horizontal, 4)
		.background(
			entry.level == .error ? Color.red.opacity(0.1) :
			entry.level == .warning ? Color.orange.opacity(0.1) :
			Color.clear
		)
	}
}

#Preview {
	DebugView()
		.frame(width: 600, height: 400)
}
