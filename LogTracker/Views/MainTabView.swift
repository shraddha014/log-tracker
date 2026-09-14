import SwiftUI

public struct MainTabView: View {
    @StateObject private var viewModel = AppViewModel()
    
    public init() {}
    
    public var body: some View {
        Group {
            if !viewModel.settings.hasCompletedOnboarding {
                OnboardingView(viewModel: viewModel)
            } else {
                TabView {
                    DashboardView(viewModel: viewModel)
                        .tabItem {
                            Label("Dashboard", systemImage: "clock.fill")
                        }
                    
                    AnalyticsView(viewModel: viewModel)
                        .tabItem {
                            Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    
                    HistoryView(viewModel: viewModel)
                        .tabItem {
                            Label("History", systemImage: "list.bullet.rectangle.portrait")
                        }
                    
                    LocationsView(viewModel: viewModel)
                        .tabItem {
                            Label("Locations", systemImage: "mappin.and.ellipse")
                        }
                    
                    SettingsView(viewModel: viewModel)
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                }
            }
        }
        .onAppear {
            LocationManager.shared.requestPermissions()
            NotificationManager.shared.requestAuthorization()
        }
    }
}
