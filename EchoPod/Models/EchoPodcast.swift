import Foundation
import SwiftData

@Model
final class EchoPodcast {
	@Attribute(.unique) var id: String
	var question: String
	var title: String
	var audioURL: String
	var coverURL: String?
	var createdAt: Date

	init(id: String, question: String, title: String, audioURL: String, coverURL: String? = nil) {
		self.id = id
		self.question = question
		self.title = title
		self.audioURL = audioURL
		self.coverURL = coverURL
		self.createdAt = Date()
	}
}
