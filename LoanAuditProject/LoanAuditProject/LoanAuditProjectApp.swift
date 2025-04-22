import SwiftUI

@main
struct LoanAuditProjectApp: App {
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashScreenView(isShowing: $showSplash)
            } else {
                LoanAuditView()
            }
        }
    }
}

/// Splash screen for LoanScope
struct SplashScreenView: View {
    @Binding var isShowing: Bool
    
    var body: some View {
        ZStack {
            Color.blue.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // App logo
                Image(systemName: "doc.text.magnifyingglass")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundColor(.white)
                
                // App name
                Text("LoanScope")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Tagline
                Text("Find clarity in your student loans")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(30)
        }
        .onAppear {
            // Automatically dismiss the splash screen after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    isShowing = false
                }
            }
        }
    }
}