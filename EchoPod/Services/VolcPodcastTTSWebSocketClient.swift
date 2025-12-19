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

	func generatePodcastFromPrompt(
		promptText: String,
		inputID: String,
		useHeadMusic: Bool,
		audioFormat: String = "mp3",
		sampleRate: Int = 24000,
		speechRate: Int = 0,
		onStatus: @escaping @Sendable (String) -> Void
	) async throws -> (taskID: String, audioURL: String) {
		let url = URL(string: "wss://openspeech.bytedance.com/api/v3/sami/podcasttts")!
		var req = URLRequest(url: url)
		req.setValue(appID, forHTTPHeaderField: "X-Api-App-Id")
		req.setValue(accessToken, forHTTPHeaderField: "X-Api-Access-Key")
		req.setValue(resourceID, forHTTPHeaderField: "X-Api-Resource-Id")
		req.setValue(appKey, forHTTPHeaderField: "X-Api-App-Key")
		req.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Request-Id")

		let ws = session.webSocketTask(with: req)
		ws.resume()

		let sessionID = UUID().uuidString.replacingOccurrences(of: "-", with: "")

		struct StartPayload: Encodable {
			struct InputInfo: Encodable { let return_audio_url: Bool }
			struct AudioConfig: Encodable {
				let format: String
				let sample_rate: Int
				let speech_rate: Int
			}
			let input_id: String
			let action: Int
			let prompt_text: String
			let use_head_music: Bool
			let input_info: InputInfo
			let audio_config: AudioConfig
		}

		let payload = StartPayload(
			input_id: inputID,
			action: 4,
			prompt_text: promptText,
			use_head_music: useHeadMusic,
			input_info: .init(return_audio_url: true),
			audio_config: .init(format: audioFormat, sample_rate: sampleRate, speech_rate: speechRate)
		)
		let payloadData = try JSONEncoder().encode(payload)

		onStatus("建连成功，开始生成…")
		try await ws.send(.data(try buildStartSessionFrame(sessionID: sessionID, payloadJSON: payloadData)))

		var audioURL: String?
		var finished = false

		while !finished {
			let msg = try await ws.receive()
			switch msg {
			case .data(let data):
				let parsed = try parseFrame(data)
				if let error = parsed.error {
					throw NSError(domain: "VolcPodcastTTSWebSocketClient", code: Int(error.code), userInfo: [NSLocalizedDescriptionKey: error.message])
				}

				switch parsed.event {
				case 150:
					onStatus("任务已开始")
				case 360:
					if let json = parsed.payloadJSON, let text = json["text"] as? String {
						let speaker = (json["speaker"] as? String) ?? ""
						onStatus(speaker.isEmpty ? "生成中：\(text.prefix(20))" : "生成中（\(speaker)）：\(text.prefix(20))")
					} else {
						onStatus("生成新轮次…")
					}
				case 361:
					break
				case 362:
					break
				case 363:
					if let jsonData = parsed.payloadData {
						if let meta = try? JSONDecoder().decode(PodcastEndMeta.self, from: jsonData) {
							audioURL = meta.meta_info?.audio_url
						}
					}
					finished = true
				case 152:
					finished = true
				case 154:
					break
				default:
					break
				}

			case .string:
				break
			@unknown default:
				break
			}
		}

		let finishPayload = Data("{}".utf8)
		try? await ws.send(.data(buildFinishConnectionFrame(payloadJSON: finishPayload)))
		ws.cancel(with: .normalClosure, reason: nil)

		guard let audioURL, !audioURL.isEmpty else {
			throw NSError(domain: "VolcPodcastTTSWebSocketClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "未获取到 audio_url（可能未返回 PodcastEnd 事件，可稍后重试）"])
		}
		return (sessionID, audioURL)
	}

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
		let serialization = bytes[2] >> 4
		let compression = bytes[2] & 0x0F

		func readU32(_ offset: Int) -> UInt32 {
			UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
		}

		// Error frame
		if messageType == 0x0F {
			guard data.count >= headerSize + 4 else {
				return ParsedFrame(event: nil, payloadData: nil, payloadJSON: nil, error: .init(code: 0, message: "未知错误"))
			}
			let code = readU32(headerSize)
			let payloadStart = headerSize + 4
			let payload = data.subdata(in: payloadStart..<data.count)
			let message: String
			if serialization == 1, let obj = try? JSONSerialization.jsonObject(with: payload) as? [String: Any], let m = obj["message"] as? String {
				message = m
			} else {
				message = String(data: payload, encoding: .utf8) ?? "未知错误"
			}
			return ParsedFrame(event: nil, payloadData: payload, payloadJSON: nil, error: .init(code: code, message: message))
		}

		// Only support no compression for now
		if compression != 0 {
			return ParsedFrame(event: nil, payloadData: nil, payloadJSON: nil, error: .init(code: 0, message: "暂不支持 gzip 压缩帧"))
		}

		var cursor = headerSize
		guard data.count >= cursor + 4 else { return ParsedFrame(event: nil, payloadData: nil, payloadJSON: nil, error: nil) }
		let event = readU32(cursor)
		cursor += 4

		// Try to parse: session_id_len + session_id + payload_len + payload
		guard data.count >= cursor + 4 else {
			return ParsedFrame(event: event, payloadData: nil, payloadJSON: nil, error: nil)
		}
		let sessionIDLen = Int(readU32(cursor))
		cursor += 4
		if sessionIDLen > 0, data.count >= cursor + sessionIDLen + 4 {
			cursor += sessionIDLen
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

		// Fallback: treat remaining as payload
		let payload = data.subdata(in: cursor..<data.count)
		if serialization == 1 {
			let obj = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any]
			return ParsedFrame(event: event, payloadData: payload, payloadJSON: obj, error: nil)
		}
		return ParsedFrame(event: event, payloadData: payload, payloadJSON: nil, error: nil)
	}

	private func buildStartSessionFrame(sessionID: String, payloadJSON: Data) throws -> Data {
		// Based on doc examples: v1, headerSize=4, messageType=0b1001, flags=0b0100, JSON, no compression
		var data = Data([0x11, 0x94, 0x10, 0x00])
		data.append(u32be(1)) // StartSession (assumed)
		let sid = Data(sessionID.utf8)
		data.append(u32be(UInt32(sid.count)))
		data.append(sid)
		data.append(u32be(UInt32(payloadJSON.count)))
		data.append(payloadJSON)
		return data
	}

	private func buildFinishConnectionFrame(payloadJSON: Data) -> Data {
		var data = Data([0x11, 0x94, 0x10, 0x00])
		data.append(u32be(2)) // FinishConnection
		data.append(u32be(UInt32(payloadJSON.count)))
		data.append(payloadJSON)
		return data
	}

	private func u32be(_ v: UInt32) -> Data {
		Data([UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)])
	}
}
