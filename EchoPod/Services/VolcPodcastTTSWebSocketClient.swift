import Foundation

struct VolcPodcastTTSWebSocketClient {
	struct PodcastEndMeta: Decodable {
		struct MetaInfo: Decodable {
			let audio_url: String?
		}
		let meta_info: MetaInfo?
	}

	let appID: String
	let accessToken: String
	let resourceID: String
	let appKey: String
	let session: URLSession

	init(appID: String, accessToken: String, resourceID: String = "volc.service_type.10050", appKey: String = "aGjiRDfUWi", session: URLSession = .shared) {
		self.appID = appID
		self.accessToken = accessToken
		self.resourceID = resourceID
		self.appKey = appKey
		self.session = session
	}

	// MARK: - Event Types (from official SDK)
	private enum EventType: UInt32 {
		case startConnection = 1
		case finishConnection = 2
		case connectionStarted = 50
		case connectionFailed = 51
		case connectionFinished = 52
		case startSession = 100
		case finishSession = 102
		case sessionStarted = 150
		case sessionFinished = 152
		case usageResponse = 154
		case podcastRoundStart = 360
		case podcastRoundResponse = 361
		case podcastRoundEnd = 362
		case podcastEnd = 363
	}
	
	// MARK: - Message Types (from official SDK)
	private enum MsgType: UInt8 {
		case fullClientRequest = 0b0001
		case audioOnlyClient = 0b0010
		case fullServerResponse = 0b1001
		case audioOnlyServer = 0b1011
		case error = 0b1111
	}
	
	private enum MsgFlag: UInt8 {
		case noSeq = 0
		case withEvent = 0b0100
	}

	func generatePodcastFromPrompt(
		promptText: String,
		inputID: String,
		useHeadMusic: Bool,
		speakers: [String] = ["zh_male_dayixiansheng_v2_saturn_bigtts", "zh_female_mizaitongxue_v2_saturn_bigtts"],
		audioFormat: String = "mp3",
		sampleRate: Int = 24000,
		speechRate: Int = 0,
		saveToLocalMP3: Bool = true,
		onStatus: @escaping @Sendable (String) -> Void,
		onAudioData: (@Sendable (Data) -> Void)? = nil,  // 流式音频数据回调
		onScript: (@Sendable (String, String) -> Void)? = nil  // 脚本文本回调：(speaker, text)
	) async throws -> (taskID: String, audioURL: String, localFileURL: URL?) {
		let url = URL(string: "wss://openspeech.bytedance.com/api/v3/sami/podcasttts")!
		var req = URLRequest(url: url)
		req.setValue(appID, forHTTPHeaderField: "X-Api-App-Id")
		req.setValue(accessToken, forHTTPHeaderField: "X-Api-Access-Key")
		req.setValue(resourceID, forHTTPHeaderField: "X-Api-Resource-Id")
		req.setValue(appKey, forHTTPHeaderField: "X-Api-App-Key")
		req.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Connect-Id")

		let ws = session.webSocketTask(with: req)
		ws.resume()

		let sessionID = UUID().uuidString

		var localFileURL: URL?
		var localFH: FileHandle?
		var wroteAnyAudio = false
		if saveToLocalMP3, audioFormat.lowercased() == "mp3" {
			let dest = try EchoPodcastCacheService.localMP3URL(taskID: sessionID)
			FileManager.default.createFile(atPath: dest.path, contents: nil)
			localFH = try FileHandle(forWritingTo: dest)
			localFileURL = dest
		}

		// Build payload for Action 4 with speaker_info
		let payload: [String: Any] = [
			"input_id": inputID,
			"action": 4,
			"prompt_text": promptText,
			"use_head_music": useHeadMusic,
			"speaker_info": [
				"random_order": true,
				"speakers": speakers
			],
			"audio_config": [
				"format": audioFormat,
				"sample_rate": sampleRate,
				"speech_rate": speechRate
			]
		]
		let payloadData = try JSONSerialization.data(withJSONObject: payload)

		// Step 1: Send StartConnection (event=1)
		debugLog("=== 发送 StartConnection (event=1) ===", level: .send)
		let startConnFrame = buildFrame(event: .startConnection, sessionID: nil, payload: Data("{}".utf8))
		try await ws.send(.data(startConnFrame))
		
		// Step 2: Wait for ConnectionStarted (event=50)
		debugLog("等待 ConnectionStarted (event=50)...", level: .info)
		onStatus("正在建立连接...")
		let connStarted = try await waitForEvent(ws: ws, expectedEvent: .connectionStarted)
		debugLog("收到 ConnectionStarted: \(connStarted)", level: .success)

		// Step 3: Send StartSession (event=100) with payload
		debugLog("=== 发送 StartSession (event=100) ===", level: .send)
		debugLog("Payload: \(String(data: payloadData, encoding: .utf8) ?? "")", level: .info)
		let startSessionFrame = buildFrame(event: .startSession, sessionID: sessionID, payload: payloadData)
		try await ws.send(.data(startSessionFrame))
		onStatus("发送生成请求...")

		// Step 4: Wait for SessionStarted (event=150)
		debugLog("等待 SessionStarted (event=150)...", level: .info)
		let sessionStarted = try await waitForEvent(ws: ws, expectedEvent: .sessionStarted)
		debugLog("收到 SessionStarted: \(sessionStarted)", level: .success)
		onStatus("任务已开始")

		// Step 5: Send FinishSession (event=102)
		debugLog("=== 发送 FinishSession (event=102) ===", level: .send)
		let finishSessionFrame = buildFrame(event: .finishSession, sessionID: sessionID, payload: Data("{}".utf8))
		try await ws.send(.data(finishSessionFrame))

		// Step 6: Receive audio data and events
		var audioURL: String?
		var finished = false

		do {
			while !finished {
				let msg = try await ws.receive()
				switch msg {
				case .data(let data):
					let parsed = try parseFrame(data)
					
					if let error = parsed.error {
						debugLog("错误: code=\(error.code), message=\(error.message)", level: .error)
						throw NSError(domain: "VolcPodcastTTSWebSocketClient", code: Int(error.code), userInfo: [NSLocalizedDescriptionKey: error.message])
					}

					guard let event = parsed.event else { continue }
					
					switch event {
					case EventType.podcastRoundStart.rawValue:
						debugLog("Event 360: PodcastRoundStart", level: .event)
						if let json = parsed.payloadJSON, let text = json["text"] as? String {
							let speaker = (json["speaker"] as? String) ?? ""
							debugLog("  Speaker: \(speaker), Text: \(text.prefix(50))", level: .info)
							onStatus(speaker.isEmpty ? "生成中：\(text.prefix(20))" : "生成中（\(speaker)）：\(text.prefix(20))")
						onScript?(speaker, text)
						}
					case EventType.podcastRoundResponse.rawValue:
						let chunkSize = parsed.payloadData?.count ?? 0
						debugLog("Event 361: 音频块 \(chunkSize) bytes", level: .event)
						if let chunk = parsed.payloadData, !chunk.isEmpty {
							try localFH?.write(contentsOf: chunk)
							wroteAnyAudio = true
							// 流式回调
							onAudioData?(chunk)
						}
					case EventType.podcastRoundEnd.rawValue:
						debugLog("Event 362: PodcastRoundEnd", level: .event)
					case EventType.podcastEnd.rawValue:
						debugLog("Event 363: PodcastEnd - 生成完成!", level: .success)
						if let jsonData = parsed.payloadData {
							debugLog("  Payload: \(String(data: jsonData, encoding: .utf8) ?? "N/A")", level: .info)
							if let meta = try? JSONDecoder().decode(PodcastEndMeta.self, from: jsonData) {
								audioURL = meta.meta_info?.audio_url
								debugLog("  AudioURL: \(audioURL ?? "nil")", level: .success)
							}
						}
					case EventType.sessionFinished.rawValue:
						debugLog("Event 152: SessionFinished", level: .success)
						finished = true
					case EventType.usageResponse.rawValue:
						debugLog("Event 154: UsageResponse", level: .info)
					default:
						debugLog("其他事件: \(event)", level: .info)
					}

				case .string(let str):
					debugLog("收到字符串消息: \(str.prefix(100))", level: .receive)
				@unknown default:
					break
				}
			}
		} catch {
			try? localFH?.close()
			localFH = nil
			if let localFileURL {
				try? FileManager.default.removeItem(at: localFileURL)
			}
			throw error
		}

		// Step 7: Send FinishConnection (event=2)
		debugLog("=== 发送 FinishConnection (event=2) ===", level: .send)
		let finishConnFrame = buildFrame(event: .finishConnection, sessionID: nil, payload: Data("{}".utf8))
		try? await ws.send(.data(finishConnFrame))
		ws.cancel(with: .normalClosure, reason: nil)

		try? localFH?.close()

		if !wroteAnyAudio, let localFileURL {
			try? FileManager.default.removeItem(at: localFileURL)
		}

		guard let audioURL else {
			throw NSError(domain: "VolcPodcastTTSWebSocketClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "未获取到 audio_url"])
		}
		return (sessionID, audioURL, wroteAnyAudio ? localFileURL : nil)
	}

	// MARK: - Frame Building (based on official SDK)
	
	private func buildFrame(event: EventType, sessionID: String?, payload: Data) -> Data {
		var data = Data()
		
		// Header: [version|headerSize][msgType|flags][serialization|compression][reserved]
		// Byte 0: 0x11 = version 1, header size 4
		// Byte 1: 0x14 = FullClientRequest (0001) + WithEvent flag (0100)
		// Byte 2: 0x10 = JSON (0001) + no compression (0000)
		// Byte 3: 0x00 = reserved
		data.append(contentsOf: [0x11, 0x14, 0x10, 0x00])
		
		// Event (4 bytes, big endian)
		data.append(u32be(event.rawValue))
		
		// Session ID (only for session-related events, not for connection events)
		// Based on official SDK protocol.py lines 324-330
		if event != .startConnection && event != .finishConnection {
			if let sid = sessionID {
				let sidData = Data(sid.utf8)
				data.append(u32be(UInt32(sidData.count)))
				data.append(sidData)
			} else {
				data.append(u32be(0))
			}
		}
		
		// Payload length + payload
		data.append(u32be(UInt32(payload.count)))
		data.append(payload)
		
		debugLog("帧结构: header(4) + event(4)[\(event.rawValue)] + \(event != .startConnection && event != .finishConnection ? "sidLen(4)+sid(\(sessionID?.count ?? 0))+" : "")payloadLen(4)+payload(\(payload.count))", level: .info)
		
		return data
	}

	// MARK: - Frame Parsing
	
	private struct ParsedFrame {
		struct FrameError {
			let code: UInt32
			let message: String
		}
		let event: UInt32?
		let payloadData: Data?
		let payloadJSON: [String: Any]?
		let error: FrameError?
	}

	private func parseFrame(_ data: Data) throws -> ParsedFrame {
		guard data.count >= 4 else { return ParsedFrame(event: nil, payloadData: nil, payloadJSON: nil, error: nil) }
		let bytes = [UInt8](data)
		let headerSize = Int(bytes[0] & 0x0F) * 4
		guard data.count >= headerSize else { return ParsedFrame(event: nil, payloadData: nil, payloadJSON: nil, error: nil) }

		let messageType = bytes[1] >> 4
		let messageFlags = bytes[1] & 0x0F
		let serialization = bytes[2] >> 4
		let compression = bytes[2] & 0x0F
		
		debugLog("--- 帧解析 --- msgType=\(messageType), flags=\(messageFlags), serial=\(serialization), compress=\(compression)", level: .info)

		func readU32(_ offset: Int) -> UInt32 {
			UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
		}

		// Error frame (msgType = 15)
		if messageType == 0x0F {
			guard data.count >= headerSize + 4 else {
				return ParsedFrame(event: nil, payloadData: nil, payloadJSON: nil, error: .init(code: 0, message: "错误帧长度不足"))
			}
			let code = readU32(headerSize)
			let payloadStart = headerSize + 4
			let payloadLenOffset = payloadStart
			guard data.count >= payloadLenOffset + 4 else {
				return ParsedFrame(event: nil, payloadData: nil, payloadJSON: nil, error: .init(code: code, message: "code=\(code)"))
			}
			let payloadLen = Int(readU32(payloadLenOffset))
			let payloadDataStart = payloadLenOffset + 4
			let payloadEnd = min(data.count, payloadDataStart + payloadLen)
			let actualPayload = data.subdata(in: payloadDataStart..<payloadEnd)
			
			var message: String? = nil
			if serialization == 1, let obj = (try? JSONSerialization.jsonObject(with: actualPayload)) as? [String: Any] {
				message = obj["message"] as? String ?? obj["error"] as? String
			}
			if message == nil {
				message = String(data: actualPayload, encoding: .utf8) ?? "未知错误"
			}
			
			return ParsedFrame(event: nil, payloadData: actualPayload, payloadJSON: nil, error: .init(code: code, message: "code=\(code) \(message!)"))
		}

		if compression != 0 {
			return ParsedFrame(event: nil, payloadData: nil, payloadJSON: nil, error: .init(code: 0, message: "暂不支持 gzip 压缩"))
		}

		var cursor = headerSize
		guard data.count >= cursor + 4 else { return ParsedFrame(event: nil, payloadData: nil, payloadJSON: nil, error: nil) }
		let event = readU32(cursor)
		cursor += 4
		
		debugLog("  Event: \(event)", level: .event)

		// For WithEvent flag, read session_id (except for connection events)
		if messageFlags == MsgFlag.withEvent.rawValue {
			// Connection events (50, 51, 52) don't have session_id in response
			if event != EventType.connectionStarted.rawValue && 
			   event != EventType.connectionFailed.rawValue &&
			   event != EventType.connectionFinished.rawValue {
				// Read session_id length
				guard data.count >= cursor + 4 else {
					return ParsedFrame(event: event, payloadData: nil, payloadJSON: nil, error: nil)
				}
				let sidLen = Int(readU32(cursor))
				cursor += 4
				if sidLen > 0 && data.count >= cursor + sidLen {
					cursor += sidLen // skip session_id
				}
			}
		}

		// Read payload
		guard data.count >= cursor + 4 else {
			return ParsedFrame(event: event, payloadData: nil, payloadJSON: nil, error: nil)
		}
		let payloadLen = Int(readU32(cursor))
		cursor += 4
		let payloadEnd = min(data.count, cursor + payloadLen)
		let payload = (cursor < payloadEnd) ? data.subdata(in: cursor..<payloadEnd) : Data()
		
		if serialization == 1 {
			let obj = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any]
			return ParsedFrame(event: event, payloadData: payload, payloadJSON: obj, error: nil)
		}
		return ParsedFrame(event: event, payloadData: payload, payloadJSON: nil, error: nil)
	}

	private func waitForEvent(ws: URLSessionWebSocketTask, expectedEvent: EventType) async throws -> ParsedFrame {
		while true {
			let msg = try await ws.receive()
			switch msg {
			case .data(let data):
				debugLog("收到帧: \(data.count) bytes, header=\(hexPrefix(data.prefix(4), maxBytes: 4))", level: .receive)
				let parsed = try parseFrame(data)
				
				if let error = parsed.error {
					throw NSError(domain: "VolcPodcastTTSWebSocketClient", code: Int(error.code), userInfo: [NSLocalizedDescriptionKey: error.message])
				}
				
				if parsed.event == expectedEvent.rawValue {
					return parsed
				}
				
				debugLog("跳过非预期事件: \(parsed.event ?? 0), 等待: \(expectedEvent.rawValue)", level: .warning)
			case .string(let str):
				debugLog("收到字符串: \(str.prefix(100))", level: .receive)
			@unknown default:
				break
			}
		}
	}

	private func u32be(_ v: UInt32) -> Data {
		Data([UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)])
	}

	private func hexPrefix(_ data: Data, maxBytes: Int) -> String {
		let bytes = data.prefix(maxBytes)
		return bytes.map { String(format: "%02x", $0) }.joined()
	}
}
