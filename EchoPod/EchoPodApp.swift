import SwiftUI
import SwiftData

@main
struct EchoPodApp: App {
	private let modelContainer: ModelContainer
	@StateObject private var player = PlayerController()
	@StateObject private var downloads = EpisodeDownloadManager()

	init() {
		do {
			modelContainer = try ModelContainer(for: PodcastFeed.self, PodcastEpisode.self, EchoPodcast.self, AppSettings.self, CoverDesignHistory.self)
		} catch {
			fatalError("Failed to create ModelContainer: \(error)")
		}
	}

	var body: some Scene {
		WindowGroup {
			RootView()
				.environmentObject(player)
				.environmentObject(downloads)
		}
		.modelContainer(modelContainer)

		MenuBarExtra("回音播客", systemImage: "waveform") {
			VStack(spacing: 8) {
				GlobalPlayerBarView()
					.environmentObject(player)
					.environmentObject(downloads)
				Divider()
				NavigationStack {
					EchoComposerView()
						.environmentObject(player)
						.environmentObject(downloads)
				}
			}
		}
		.menuBarExtraStyle(.window)
		.modelContainer(modelContainer)
	}
}

import AppKit
import CryptoKit

@MainActor
final class DataLoader {
	static let shared = DataLoader()
	
	// 演示数据的硬编码信息
	private let demoID = "demo_podcast_v1"
	private let demoTitle = "霍华德《投资中最重要的事》这本书主要讲了什么"
	private let demoQuestion = "霍华德《投资中最重要的事》这本书主要讲了什么"
	
	func loadDemoData(modelContext: ModelContext) {
		// 1. 检查是否已存在
		let descriptor = FetchDescriptor<EchoPodcast>(predicate: #Predicate { $0.id == demoID })
		if let _ = try? modelContext.fetch(descriptor).first {
			print("Demo data already exists.")
			return
		}
		
		print("Loading demo data...")
		
		// 2. 准备目标路径
		// 使用 NSDataAsset 读取资源 (需要在 Assets.xcassets 中配置 Data Set)
		// 注意：在 macOS 上，NSDataAsset 也是可用的 (AppKit)
		guard let audioAsset = NSDataAsset(name: "demo_audio"),
			  let coverAsset = NSDataAsset(name: "demo_cover") else {
			print("Demo resources (NSDataAsset) not found.")
			return
		}
		
		do {
			let targetMP3 = try EchoPodcastCacheService.localMP3URL(taskID: demoID)
			let targetCover = try EchoPodcastCacheService.localCoverURL(taskID: demoID)
			
			// 确保目录存在
			let fileManager = FileManager.default
			try fileManager.createDirectory(at: targetMP3.deletingLastPathComponent(), withIntermediateDirectories: true)
			
			// 3. 写入文件
			if fileManager.fileExists(atPath: targetMP3.path) {
				try fileManager.removeItem(at: targetMP3)
			}
			try audioAsset.data.write(to: targetMP3)
			
			if fileManager.fileExists(atPath: targetCover.path) {
				try fileManager.removeItem(at: targetCover)
			}
			try coverAsset.data.write(to: targetCover)
			
			// 4. 创建数据库记录
			let echo = EchoPodcast(id: demoID, question: demoQuestion, title: demoTitle, status: "completed")
			echo.localFilePath = targetMP3.path
			echo.localCoverPath = targetCover.path
			echo.coverURL = targetCover.path
			echo.createdAt = Date()
			
			// 模拟脚本内容
			echo.scriptContent = """
			【AI】欢迎体验回音播客。
			
			【AI】这是一条内置的演示音频，带您快速了解霍华德·马克斯的投资哲学。
			
			【AI】《投资中最重要的事》倾注了作者一生的经验和研究，即使你不是职业投资人，也能从中获益良多。
			"""
			
			modelContext.insert(echo)
			try modelContext.save()
			
			print("Demo data loaded successfully.")
			
		} catch {
			print("Failed to load demo data: \(error)")
		}
	}
}
