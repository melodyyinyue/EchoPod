# EchoPod 回音播客

**English** | [中文](#中文介绍)

EchoPod is a native macOS podcast client and AI podcast creation tool. It lets you subscribe to and play RSS podcasts, generate conversational AI podcast episodes from a question, create AI covers, save scripts, and keep generated audio locally.

## Download

- Latest DMG: [Download EchoPod.dmg](https://github.com/melodyyinyue/EchoPod/releases/download/v0.1.0/EchoPod.dmg)
- All versions: [GitHub Releases](https://github.com/melodyyinyue/EchoPod/releases)
- Installation: download and open `EchoPod.dmg`, then drag the app into `Applications`.

## Features

- RSS subscriptions: add podcast feeds, parse episode lists, and view episode details.
- Playback and downloads: play episodes, use the global player bar, cache content, and keep audio offline.
- AI Echo Podcasts: enter a question and generate a two-host conversational podcast episode.
- Script view: review generated scripts and use them as reading context while listening.
- AI cover design: generate podcast covers from topic prompts and keep cover design history.
- Personalization: configure host styles, Volcengine voice generation, and image generation APIs.
- Demo content: built-in sample audio and cover assets for a quick first-run experience.

## Tech Stack

- SwiftUI: native macOS user interface.
- SwiftData: local data models for feeds, episodes, AI podcasts, and cover history.
- AVFoundation: audio playback and playback state handling.
- URLSession / WebSocket: RSS fetching, audio generation, and image generation requests.
- Volcengine: AI podcast voice generation and Seedream image generation.

## Project Structure

```text
EchoPod/
├── Models/          # SwiftData models
├── Services/        # RSS, playback, cache, and AI generation services
├── Views/           # SwiftUI views and components
├── Resources/       # App icons and demo assets
└── Info.plist       # macOS app configuration
```

## Run from Source

1. Open `EchoPod.xcodeproj` in Xcode.
2. Select a macOS run destination.
3. Click Run to launch the app.

Requirements: macOS 14.0 or later and Swift 6.0.

## API Configuration

Open Settings in the app and configure:

- Podcast generation: `APP ID`, `Access Token`, and `Resource ID`.
- Cover generation: `API Key` and `Base URL`.
- Default cover generation Base URL: `https://ark.cn-beijing.volces.com`.

Cover generation uses the Volcengine Ark image generation endpoint:

```text
POST https://ark.cn-beijing.volces.com/api/v3/images/generations
```

If cover generation fails because the host cannot be resolved, check your network, proxy, API key, and Base URL settings.

## Usage

1. Add RSS podcast feeds in Subscriptions.
2. Browse and play episodes in All Episodes.
3. Enter a question from the menu bar entry to generate an AI podcast.
4. Review generated audio and scripts in My Echoes.
5. Generate standalone podcast covers in Cover Design.

## Notes

- AI generation depends on external services and requires valid Volcengine credentials.
- Generated image URLs may expire, so cache or save the images when needed.
- The project currently targets macOS desktop usage; mobile adaptation is not the focus yet.

---

## 中文介绍

EchoPod 回音播客是一款 macOS 播客客户端与 AI 播客创作工具。它既可以订阅、浏览和播放 RSS 播客，也可以根据用户输入的问题生成一段 AI 播客，并自动生成封面、保存脚本和本地音频。

## 直接下载

- 最新版 DMG：[下载 EchoPod.dmg](https://github.com/melodyyinyue/EchoPod/releases/download/v0.1.0/EchoPod.dmg)
- 所有版本：[GitHub Releases](https://github.com/melodyyinyue/EchoPod/releases)
- 安装方式：下载并打开 `EchoPod.dmg`，将应用拖入 `Applications` 后启动。

## 主要功能

- RSS 播客订阅：添加播客源，解析节目列表，查看单集详情。
- 播放与下载：支持单集播放、全局播放条、缓存和离线保存。
- AI 回音播客：输入一个问题，生成双人对话式播客内容和音频。
- 脚本查看：生成完成后可查看播客脚本，并在播放时辅助定位内容。
- AI 封面设计：根据主题生成播客封面，支持封面设计历史记录。
- 个性化配置：支持主讲人风格、火山引擎语音配置、图片生成 API 配置。
- 演示数据：内置示例音频和封面，首次启动即可体验核心交互。

<img width="1920" height="1080" alt="EchoPod 002" src="https://github.com/user-attachments/assets/7a3cfa94-9ea7-4edf-b91e-42c6f41939dd" />
<img width="1920" height="1080" alt="EchoPod 008" src="https://github.com/user-attachments/assets/1a371680-9212-454a-a4b6-dc6bd9bab044" />
<img width="1920" height="1080" alt="EchoPod 007" src="https://github.com/user-attachments/assets/e3a2b21c-f749-444c-a827-5ce87fbec014" />
<img width="1920" height="1080" alt="EchoPod 011" src="https://github.com/user-attachments/assets/c9bf3608-ce9e-4a5b-a4c5-f8aa0d692a98" />



## 技术栈

- SwiftUI：构建 macOS 原生界面。
- SwiftData：管理订阅、单集、AI 播客和封面历史数据。
- AVFoundation：处理音频播放与播放状态。
- URLSession / WebSocket：请求播客 RSS、音频生成和图片生成服务。
- 火山引擎：用于 AI 播客语音生成与 Seedream 图片生成。

## 项目结构

```text
EchoPod/
├── Models/          # SwiftData 数据模型
├── Services/        # RSS、播放、缓存、AI 生成等服务
├── Views/           # SwiftUI 页面和组件
├── Resources/       # App 图标与演示资源
└── Info.plist       # macOS 应用配置
```

## 运行方式

1. 使用 Xcode 打开 `EchoPod.xcodeproj`。
2. 选择 macOS 运行目标。
3. 点击 Run 启动应用。

项目最低运行环境为 macOS 14.0，Swift 版本为 6.0。

## API 配置

打开应用后进入“设置”，填写以下配置：

- 播客生成配置：`APP ID`、`Access Token`、`Resource ID`。
- 封面生成配置：`API Key`、`Base URL`。
- 默认封面生成 Base URL：`https://ark.cn-beijing.volces.com`。

封面生成使用火山方舟图片生成接口：

```text
POST https://ark.cn-beijing.volces.com/api/v3/images/generations
```

如果封面生成遇到域名解析失败，请优先检查网络、代理、API Key 和 Base URL 配置。

## 使用流程

1. 在“我的订阅”中添加 RSS 播客源。
2. 在“全部单集”中浏览节目并播放。
3. 在菜单栏入口输入问题，生成一段 AI 回音播客。
4. 在“我的回音”中查看生成记录、播放音频和查看脚本。
5. 在“封面设计”中输入主题，生成独立播客封面。

## 开发说明

- `project.yml` 可用于维护 Xcode 工程配置。
- `EchoPod/Services/VolcPodcastTTSWebSocketClient.swift` 负责 AI 播客音频生成。
- `EchoPod/Services/VolcEchoClient.swift` 负责封面生成接口调用。
- `EchoPod/Services/EchoPodcastCacheService.swift` 负责 AI 播客音频与封面缓存。
- `EchoPod/Services/RSSService.swift` 和 `EchoPod/Services/RSSParser.swift` 负责 RSS 获取与解析。

## 注意事项

- AI 生成能力依赖外部服务，运行前需要在设置中配置有效的火山引擎凭证。
- 生成图片 URL 通常有有效期，建议及时缓存或保存。
- 本项目目前面向 macOS 桌面端，移动端适配尚未完善。
