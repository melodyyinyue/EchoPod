import Foundation
import AVFoundation

/// 流式音频播放器 - 支持边下载边播放
@MainActor
class StreamingAudioPlayer: ObservableObject {
	@Published var isPlaying = false
	@Published var isBuffering = false
	@Published var currentTime: TimeInterval = 0
	@Published var duration: TimeInterval = 0
	@Published var bufferedDuration: TimeInterval = 0
	@Published var error: String?
	
	private var audioEngine: AVAudioEngine?
	private var playerNode: AVAudioPlayerNode?
	private var audioFormat: AVAudioFormat?
	
	// 使用 AVAudioPlayer 播放 MP3 片段
	private var audioPlayer: AVAudioPlayer?
	private var audioBuffer = Data()
	private var tempFileURL: URL?
	private var updateTimer: Timer?
	
	// 流式状态
	@Published var isStreaming = false
	private var hasStartedPlaying = false
	private let minBufferSize = 32 * 1024 // 32KB 开始播放
	
	init() {}
	
	/// 开始流式播放（准备接收数据）
	func startStreaming() {
		isStreaming = true
		isBuffering = true
		hasStartedPlaying = false
		audioBuffer = Data()
		error = nil
		
		// 创建临时文件
		let tempDir = FileManager.default.temporaryDirectory
		tempFileURL = tempDir.appendingPathComponent("streaming_\(UUID().uuidString).mp3")
		FileManager.default.createFile(atPath: tempFileURL!.path, contents: nil)
		
		debugLog("StreamingPlayer: 开始流式播放，临时文件: \(tempFileURL?.lastPathComponent ?? "")", level: .info)
	}
	
	/// 接收音频数据块
	func appendAudioData(_ data: Data) {
		guard isStreaming else { return }
		
		audioBuffer.append(data)
		bufferedDuration = Double(audioBuffer.count) / (24000 * 2) // 估算时长（假设 24kHz 16bit）
		
		// 写入临时文件
		if let url = tempFileURL, let handle = try? FileHandle(forWritingTo: url) {
			handle.seekToEndOfFile()
			handle.write(data)
			try? handle.close()
		}
		
		debugLog("StreamingPlayer: 收到 \(data.count) bytes, 总计: \(audioBuffer.count) bytes", level: .info)
		
		// 缓冲足够后开始播放
		if !hasStartedPlaying && audioBuffer.count >= minBufferSize {
			startPlayingFromBuffer()
		}
	}
	
	/// 流式接收完成
	func finishStreaming() {
		isStreaming = false
		isBuffering = false
		
		debugLog("StreamingPlayer: 流式接收完成，总计 \(audioBuffer.count) bytes", level: .success)
		
		// 如果还没开始播放，现在开始
		if !hasStartedPlaying && audioBuffer.count > 0 {
			startPlayingFromBuffer()
		}
	}
	
	private func startPlayingFromBuffer() {
		guard let url = tempFileURL else { return }
		
		do {
			hasStartedPlaying = true
			isBuffering = false
			
			audioPlayer = try AVAudioPlayer(contentsOf: url)
			audioPlayer?.prepareToPlay()
			duration = audioPlayer?.duration ?? 0
			
			audioPlayer?.play()
			isPlaying = true
			
			startUpdateTimer()
			
			debugLog("StreamingPlayer: 开始播放", level: .success)
		} catch {
			self.error = error.localizedDescription
			debugLog("StreamingPlayer: 播放失败 - \(error.localizedDescription)", level: .error)
		}
	}
	
	/// 播放/暂停
	func togglePlayPause() {
		if isPlaying {
			audioPlayer?.pause()
			isPlaying = false
		} else {
			audioPlayer?.play()
			isPlaying = true
		}
	}
	
	/// 跳转到指定时间
	func seek(to time: TimeInterval) {
		audioPlayer?.currentTime = time
		currentTime = time
	}
	
	/// 停止播放
	func stop() {
		audioPlayer?.stop()
		audioPlayer = nil
		isPlaying = false
		isStreaming = false
		isBuffering = false
		currentTime = 0
		
		stopUpdateTimer()
		
		// 清理临时文件
		if let url = tempFileURL {
			try? FileManager.default.removeItem(at: url)
		}
		tempFileURL = nil
		audioBuffer = Data()
	}
	
	private func startUpdateTimer() {
		stopUpdateTimer()
		updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
			Task { @MainActor in
				guard let self = self, let player = self.audioPlayer else { return }
				self.currentTime = player.currentTime
				self.duration = player.duration
				
				// 检查是否播放完成
				if !player.isPlaying && self.isPlaying {
					self.isPlaying = false
				}
			}
		}
	}
	
	private func stopUpdateTimer() {
		updateTimer?.invalidate()
		updateTimer = nil
	}
}
