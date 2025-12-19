import Foundation
import CryptoKit

enum EpisodeCacheService {
	enum CacheError: Error {
		case invalidRemoteURL
		case missingTempFile
	}

	static func downloadAndCache(remoteURL: URL, guid: String) async throws -> URL {
		let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
		guard FileManager.default.fileExists(atPath: tempURL.path) else {
			throw CacheError.missingTempFile
		}

		let destination = try cachedFileURL(guid: guid, remoteURL: remoteURL)
		try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

		if FileManager.default.fileExists(atPath: destination.path) {
			try FileManager.default.removeItem(at: destination)
		}
		try FileManager.default.moveItem(at: tempURL, to: destination)
		return destination
	}

	static func removeCachedFile(atPath path: String) throws {
		let url = URL(fileURLWithPath: path)
		guard FileManager.default.fileExists(atPath: url.path) else { return }
		try FileManager.default.removeItem(at: url)
	}

	static func cachedFileURL(guid: String, remoteURL: URL) throws -> URL {
		let base = try downloadsDirectory()
		let ext = remoteURL.pathExtension.isEmpty ? "mp3" : remoteURL.pathExtension
		let name = sha256Hex("\(guid)|\(remoteURL.absoluteString)").prefix(24)
		return base.appendingPathComponent("\(name).\(ext)")
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
			.appendingPathComponent("Downloads", isDirectory: true)
	}

	private static func sha256Hex(_ s: String) -> String {
		let digest = SHA256.hash(data: Data(s.utf8))
		return digest.map { String(format: "%02x", $0) }.joined()
	}
}
