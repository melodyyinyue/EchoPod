import Foundation
import CryptoKit

enum EchoPodcastCacheService {
	enum CacheError: Error {
		case invalidTaskID
	}

	static func localMP3URL(taskID: String) throws -> URL {
		let trimmed = taskID.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { throw CacheError.invalidTaskID }

		let base = try downloadsDirectory()
		try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

		let name = sha256Hex(trimmed).prefix(24)
		return base.appendingPathComponent("\(name).mp3")
	}

	static func removeCachedFile(atPath path: String) throws {
		let url = URL(fileURLWithPath: path)
		guard FileManager.default.fileExists(atPath: url.path) else { return }
		try FileManager.default.removeItem(at: url)
	}

	private static func downloadsDirectory() throws -> URL {
		let appSupport = try FileManager.default.url(
			for: .applicationSupportDirectory,
			in: .userDomainMask,
			appropriateFor: nil,
			create: true
		)
		return appSupport
			.appendingPathComponent("EchoPod", isDirectory: true)
			.appendingPathComponent("EchoGenerated", isDirectory: true)
	}

	private static func sha256Hex(_ s: String) -> String {
		let digest = SHA256.hash(data: Data(s.utf8))
		return digest.map { String(format: "%02x", $0) }.joined()
	}
}
