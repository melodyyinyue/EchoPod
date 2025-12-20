import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
	case allEpisodes = "全部单集"
	case subscriptions = "我的订阅"
	case echoPodcasts = "我的回音播客"
	case settings = "设置"
	case debug = "调试日志"

	var id: String { rawValue }

	var systemImage: String {
		switch self {
		case .allEpisodes: return "rectangle.stack"
		case .subscriptions: return "dot.radiowaves.left.and.right"
		case .echoPodcasts: return "waveform"
		case .settings: return "gearshape"
		case .debug: return "ladybug"
		}
	}
}

struct RootView: View {
	@State private var selection: SidebarItem? = .allEpisodes

	var body: some View {
		NavigationSplitView {
			List(SidebarItem.allCases, selection: $selection) { item in
				Label(item.rawValue, systemImage: item.systemImage)
					.tag(item)
			}
			.listStyle(.sidebar)
			.navigationTitle("EchoPod")
		} detail: {
			switch selection {
			case .allEpisodes:
				AllEpisodesView()
			case .subscriptions:
				SubscriptionsView()
			case .echoPodcasts:
				EchoPodcastsView()
			case .settings:
				SettingsView()
			case .debug:
				DebugView()
			case .none:
				AllEpisodesView()
			}
		}
	}
}
