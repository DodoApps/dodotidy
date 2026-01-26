import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard
    case cleaner
    case analyzer
    case optimizer
    case apps
    case history
    case scheduled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .cleaner: return "Cleaner"
        case .analyzer: return "Analyzer"
        case .optimizer: return "Optimizer"
        case .apps: return "Apps"
        case .history: return "History"
        case .scheduled: return "Scheduled"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.needle"
        case .cleaner: return "trash"
        case .analyzer: return "chart.pie"
        case .optimizer: return "bolt"
        case .apps: return "square.grid.2x2"
        case .history: return "clock.arrow.circlepath"
        case .scheduled: return "calendar.badge.clock"
        }
    }
}

struct MainWindowView: View {
    @State private var selectedItem: NavigationItem? = .dashboard
    @State private var dodoService = DodoTidyService.shared

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedItem: $selectedItem)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await dodoService.startMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateTo)) { notification in
            if let item = notification.object as? NavigationItem {
                selectedItem = item
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedItem {
        case .dashboard:
            DashboardView()
        case .cleaner:
            CleanerView()
        case .analyzer:
            AnalyzerView()
        case .optimizer:
            OptimizerView()
        case .apps:
            AppsView()
        case .history:
            HistoryView()
        case .scheduled:
            ScheduledTasksView()
        case .none:
            DashboardView()
        }
    }
}

#Preview {
    MainWindowView()
        .frame(width: 1000, height: 700)
}
