import SwiftUI
import SwiftData

struct SettingsView: View {
	@Environment(\.modelContext) private var modelContext
	@Query(filter: #Predicate<AppSettings> { $0.id == "singleton" })
	private var settings: [AppSettings]

	@State private var podcastAppID: String = ""
	@State private var podcastAccessToken: String = ""
	@State private var podcastResourceID: String = "volc.service_type.10050"
	@State private var speakerPair: SpeakerPair = .miziAndDayi

	@State private var coverKey: String = ""
	@State private var coverBaseURL: String = "https://ark.cn-beijing.volces.com"
	
	@State private var showSaveSuccess: Bool = false

	var body: some View {
		Form {
			// MARK: - 播客生成配置
			Section {
				VStack(alignment: .leading, spacing: 16) {
					LabeledContent {
						TextField("请输入 APP ID", text: $podcastAppID)
							.textFieldStyle(.roundedBorder)
					} label: {
						Label("APP ID", systemImage: "app.badge")
							.frame(width: 120, alignment: .leading)
					}
					
					LabeledContent {
						SecureField("请输入 Access Token", text: $podcastAccessToken)
							.textFieldStyle(.roundedBorder)
					} label: {
						Label("Access Token", systemImage: "key.fill")
							.frame(width: 120, alignment: .leading)
					}
					
					LabeledContent {
						TextField("volc.service_type.10050", text: $podcastResourceID)
							.textFieldStyle(.roundedBorder)
					} label: {
						Label("Resource ID", systemImage: "server.rack")
							.frame(width: 120, alignment: .leading)
					}
				}
				.padding(.vertical, 4)
			} header: {
				Text("播客生成配置")
					.font(.headline)
			} footer: {
				Text("用于连接火山引擎语音技术，生成播客音频。")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			// MARK: - 个性化设置
			Section {
				VStack(alignment: .leading, spacing: 16) {
					LabeledContent {
						Picker("", selection: $speakerPair) {
							ForEach(SpeakerPair.allCases, id: \.self) { pair in
								Text(pair.displayName).tag(pair)
							}
						}
						.pickerStyle(.segmented)
						.frame(maxWidth: 300)
					} label: {
						Label("主讲人风格", systemImage: "person.2.wave.2")
							.frame(width: 120, alignment: .leading)
					}
				}
				.padding(.vertical, 4)
			} header: {
				Text("个性化设置")
					.font(.headline)
			}
			
			// MARK: - 封面生成配置
			Section {
				VStack(alignment: .leading, spacing: 16) {
					LabeledContent {
						SecureField("请输入 API Key", text: $coverKey)
							.textFieldStyle(.roundedBorder)
					} label: {
						Label("API Key", systemImage: "key")
							.frame(width: 120, alignment: .leading)
					}
					
					LabeledContent {
						VStack(alignment: .leading, spacing: 4) {
							TextField("https://ark.cn-beijing.volces.com", text: $coverBaseURL)
								.textFieldStyle(.roundedBorder)
								.textContentType(.URL)
						}
					} label: {
						Label("Base URL", systemImage: "network")
							.frame(width: 120, alignment: .leading)
					}
				}
				.padding(.vertical, 4)
			} header: {
				Text("封面生成配置")
					.font(.headline)
			} footer: {
				Text("用于生成播客封面图片。")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			// MARK: - 操作区域
			Section {
				HStack {
					Spacer()
					Button {
						save()
					} label: {
						HStack(spacing: 6) {
							if showSaveSuccess {
								Image(systemName: "checkmark")
							}
							Text(showSaveSuccess ? "已保存" : "保存配置")
						}
						.frame(width: 100)
					}
					.buttonStyle(.borderedProminent)
					.tint(showSaveSuccess ? .green : AppTheme.primary)
					.animation(.snappy, value: showSaveSuccess)
				}
				.padding(.top, 8)
			}
		}
		.formStyle(.grouped)
		.padding()
		.onAppear { load() }
		.navigationTitle("设置")
	}

	private func load() {
		let s = settings.first ?? {
			let created = AppSettings()
			modelContext.insert(created)
			return created
		}()
		podcastAppID = s.volcPodcastAppID ?? ""
		podcastAccessToken = s.volcPodcastAccessToken ?? ""
		podcastResourceID = s.volcPodcastResourceID ?? "volc.service_type.10050"
		speakerPair = s.speakerPair
		coverKey = s.volcCoverAPIKey ?? ""
		// 如果数据库有值就用，没有就用默认值
		coverBaseURL = s.volcCoverBaseURL ?? "https://ark.cn-beijing.volces.com"
	}

	private func save() {
		let s = settings.first ?? {
			let created = AppSettings()
			modelContext.insert(created)
			return created
		}()
		s.volcPodcastAppID = podcastAppID.isEmpty ? nil : podcastAppID
		s.volcPodcastAccessToken = podcastAccessToken.isEmpty ? nil : podcastAccessToken
		s.volcPodcastResourceID = podcastResourceID.isEmpty ? nil : podcastResourceID
		s.speakerPair = speakerPair
		s.volcCoverAPIKey = coverKey.isEmpty ? nil : coverKey
		// Base URL 保存时，使用默认值而不是 nil
		s.volcCoverBaseURL = coverBaseURL.isEmpty ? "https://ark.cn-beijing.volces.com" : coverBaseURL
		s.updatedAt = Date()
		try? modelContext.save()
		
		// 显示保存成功
		withAnimation {
			showSaveSuccess = true
		}
		
		// 触觉反馈 (如果有)
		#if os(iOS)
		let generator = UINotificationFeedbackGenerator()
		generator.notificationOccurred(.success)
		#endif
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
			withAnimation {
				showSaveSuccess = false
			}
		}
	}
}

