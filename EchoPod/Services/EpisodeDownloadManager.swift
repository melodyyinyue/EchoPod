import Foundation

@MainActor
final class EpisodeDownloadManager: NSObject, ObservableObject {
	@Published private(set) var progressByGUID: [String: Double] = [:]

	private var tasksByGUID: [String: URLSessionDownloadTask] = [:]
	private var metaByTaskID: [Int: (guid: String, remoteURL: URL)] = [:]
	private var completionByTaskID: [Int: (Result<URL, Error>) -> Void] = [:]

	private lazy var session: URLSession = {
		URLSession(configuration: .default, delegate: self, delegateQueue: nil)
	}()

	func isDownloading(guid: String) -> Bool {
		tasksByGUID[guid] != nil
	}

	func progress(guid: String) -> Double? {
		progressByGUID[guid]
	}

	func startDownload(remoteURL: URL, guid: String, completion: @escaping (Result<URL, Error>) -> Void) {
		guard tasksByGUID[guid] == nil else { return }

		let task = session.downloadTask(with: remoteURL)
		tasksByGUID[guid] = task
		metaByTaskID[task.taskIdentifier] = (guid: guid, remoteURL: remoteURL)
		completionByTaskID[task.taskIdentifier] = completion
		progressByGUID[guid] = 0
		task.resume()
	}

	func cancelDownload(guid: String) {
		guard let task = tasksByGUID[guid] else { return }
		task.cancel()
		cleanup(guid: guid, taskID: task.taskIdentifier)
	}

	private func cleanup(guid: String, taskID: Int) {
		tasksByGUID.removeValue(forKey: guid)
		metaByTaskID.removeValue(forKey: taskID)
		completionByTaskID.removeValue(forKey: taskID)
		progressByGUID.removeValue(forKey: guid)
	}
}

extension EpisodeDownloadManager: URLSessionDownloadDelegate {
	nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
		Task { @MainActor in
			guard let meta = metaByTaskID[downloadTask.taskIdentifier] else { return }
			guard totalBytesExpectedToWrite > 0 else { return }
			let p = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
			progressByGUID[meta.guid] = max(0, min(1, p))
		}
	}

	nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		Task { @MainActor in
			guard let meta = metaByTaskID[downloadTask.taskIdentifier] else { return }
			guard let completion = completionByTaskID.removeValue(forKey: downloadTask.taskIdentifier) else {
				cleanup(guid: meta.guid, taskID: downloadTask.taskIdentifier)
				return
			}

			do {
				let dest = try EpisodeCacheService.cachedFileURL(guid: meta.guid, remoteURL: meta.remoteURL)
				try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)

				if FileManager.default.fileExists(atPath: dest.path) {
					try FileManager.default.removeItem(at: dest)
				}
				try FileManager.default.moveItem(at: location, to: dest)

				cleanup(guid: meta.guid, taskID: downloadTask.taskIdentifier)
				completion(.success(dest))
			} catch {
				cleanup(guid: meta.guid, taskID: downloadTask.taskIdentifier)
				completion(.failure(error))
			}
		}
	}

	nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		guard let error else { return }
		Task { @MainActor in
			guard let meta = metaByTaskID[task.taskIdentifier] else { return }
			guard let completion = completionByTaskID.removeValue(forKey: task.taskIdentifier) else {
				cleanup(guid: meta.guid, taskID: task.taskIdentifier)
				return
			}

			cleanup(guid: meta.guid, taskID: task.taskIdentifier)
			completion(.failure(error))
		}
	}
}
