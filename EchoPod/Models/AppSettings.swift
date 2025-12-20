import Foundation
import SwiftData

/// 主讲人配对选项
enum SpeakerPair: String, CaseIterable, Codable {
	case miziAndDayi = "mizi_dayi"      // 咪仔和大壹
	case liufeiAndXiaolei = "liufei_xiaolei"  // 刘飞和潇磊
	
	var displayName: String {
		switch self {
		case .miziAndDayi: return "咪仔和大壹"
		case .liufeiAndXiaolei: return "刘飞和潇磊"
		}
	}
	
	var speakers: [String] {
		switch self {
		case .miziAndDayi:
			return [
				"zh_male_dayixiansheng_v2_saturn_bigtts",
				"zh_female_mizaitongxue_v2_saturn_bigtts"
			]
		case .liufeiAndXiaolei:
			return [
				"zh_male_liufei_v2_saturn_bigtts",
				"zh_male_xiaolei_v2_saturn_bigtts"
			]
		}
	}
}

@Model
final class AppSettings {
	@Attribute(.unique) var id: String

	var volcPodcastAppID: String?
	var volcPodcastAccessToken: String?
	var volcPodcastResourceID: String?
	
	/// 主讲人配对：mizi_dayi 或 liufei_xiaolei
	var speakerPairRaw: String?
	
	var speakerPair: SpeakerPair {
		get {
			guard let raw = speakerPairRaw else { return .miziAndDayi }
			return SpeakerPair(rawValue: raw) ?? .miziAndDayi
		}
		set {
			speakerPairRaw = newValue.rawValue
		}
	}

	var volcCoverAPIKey: String?
	var volcCoverBaseURL: String?
	var updatedAt: Date

	init(id: String = "singleton") {
		self.id = id
		self.volcPodcastResourceID = "volc.service_type.10050"
		self.speakerPairRaw = SpeakerPair.miziAndDayi.rawValue
		self.updatedAt = Date()
	}
}
