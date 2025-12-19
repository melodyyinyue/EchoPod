import Foundation
import AVFoundation

@MainActor
final class PlayerController: ObservableObject {
	@Published private(set) var currentURL: URL?
	@Published private(set) var isPlaying: Bool = false
	@Published private(set) var currentTime: Double = 0
	@Published private(set) var duration: Double = 0
	@Published var rate: Float = 1.0

	private let player = AVPlayer()
	private var timeObserver: Any?
	private var endObserver: NSObjectProtocol?

	init() {
		let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
		timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
			guard let self else { return }
			self.currentTime = time.seconds
			self.isPlaying = self.player.timeControlStatus == .playing
		}
	}


	func play(url: URL) {
		if currentURL == url, player.currentItem != nil {
			player.playImmediately(atRate: rate)
			isPlaying = true
			return
		}

		let item = AVPlayerItem(url: url)
		player.replaceCurrentItem(with: item)
		currentURL = url
		currentTime = 0
		duration = 0

		if let endObserver {
			NotificationCenter.default.removeObserver(endObserver)
		}
		endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
			guard let self else { return }
			self.isPlaying = false
		}

		Task { [weak self] in
			guard let self else { return }
			let d = try? await item.asset.load(.duration)
			let seconds = d?.seconds ?? 0
			await MainActor.run {
				self.duration = seconds.isFinite ? seconds : 0
			}
		}

		player.playImmediately(atRate: rate)
		isPlaying = true
	}

	func togglePlayPause() {
		if isPlaying {
			pause()
		} else {
			player.playImmediately(atRate: rate)
			isPlaying = true
		}
	}

	func pause() {
		player.pause()
		isPlaying = false
	}

	func seek(to seconds: Double) {
		let t = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
		player.seek(to: t)
	}

	func applyRate() {
		if isPlaying {
			player.rate = rate
		}
	}
}
