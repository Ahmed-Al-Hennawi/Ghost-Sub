import SwiftUI

// MARK: - App Screen Routing
// The emailSync and scanning cases have been removed — subscription import
// is now handled entirely by the Screenshot Scanner inside the Dashboard.
enum AppScreen {
    case login
    case register
    case dashboard
}

struct ContentView: View {
    @State private var currentScreen: AppScreen = .login
    @EnvironmentObject var authManager: AuthManager

    @AppStorage("themePreference") var themePreference: Int = 0

    var activeTheme: ColorScheme? {
        if themePreference == 1 { return .light }
        if themePreference == 2 { return .dark }
        return nil
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            switch currentScreen {
            case .login:
                LoginView(currentScreen: $currentScreen)
            case .register:
                RegisterView(currentScreen: $currentScreen)
            case .dashboard:
                DashboardView(currentScreen: $currentScreen)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: currentScreen)
        .preferredColorScheme(activeTheme)
        .onAppear {
            // If the user is already signed in, go straight to the dashboard
            if authManager.currentUserSession != nil {
                currentScreen = .dashboard
            }
        }
    }
}
