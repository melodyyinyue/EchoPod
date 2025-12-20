import Foundation
import SwiftData

@Model
final class EchoPodcast {
	@Attribute(.unique) var id: String
	var question: String
	var title: String
	var audioURL: String?  // 改为可选，生成中时为 nil
	var coverURL: String?
	var scriptContent: String?  // 播客脚本文本内容

	var localFilePath: String?
	var localCoverPath: String?
	var downloadedAt: Date?

	var createdAt: Date
	
	// 生成状态：generating, completed, failed
	var status: String
	var statusMessage: String?  // 当前生成进度提示
	var errorMessage: String?   // 错误信息
	
	var isGenerating: Bool {
		status == "generating"
	}
	
	var isCompleted: Bool {
		status == "completed"
	}
	
	var isFailed: Bool {
		status == "failed"
	}

	init(id: String, question: String, title: String, audioURL: String? = nil, coverURL: String? = nil, status: String = "generating") {
		self.id = id
		self.question = question
		self.title = title
		self.audioURL = audioURL
		self.coverURL = coverURL
		self.status = status
		self.createdAt = Date()
	}
}
