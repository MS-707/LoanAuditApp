import SwiftUI
import LoanAuditProject

@main
struct LoanAuditAppApp: App {
    // Check if the user has seen the onboarding flow
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    
    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                // User has completed onboarding, show the main app
                AuditAppShell()
            } else {
                // User hasn't seen onboarding, show the flow
                OnboardingFlow()
            }
        }
    }
}