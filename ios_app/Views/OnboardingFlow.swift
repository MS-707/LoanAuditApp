import SwiftUI

/// Onboarding flow that introduces new users to LoanScope
struct OnboardingFlow: View {
    /// Tracks whether the user has completed onboarding
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    
    /// Current page in the onboarding flow
    @State private var currentPage = 0
    
    /// Pages in the onboarding flow
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to LoanScope",
            message: "Student loans are complex. We're here to help you make sense of them — clearly, securely, and without the jargon.",
            imageName: "doc.text",
            buttonText: "Next →"
        ),
        OnboardingPage(
            title: "Private & Secure",
            message: "Your loan data stays on your device.\nWe never upload to a server.\nNo accounts. No tracking. No cloud.\nYour information is parsed locally and securely — powered by Apple's built-in privacy protections.",
            imageName: "lock.shield",
            buttonText: "Next →"
        ),
        OnboardingPage(
            title: "What to Expect",
            message: "Just scan your student loan document and we'll highlight potential issues — clearly and privately.",
            imageName: "magnifyingglass.circle",
            buttonText: "Get Started →"
        )
    ]
    
    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(0..<pages.count, id: \.self) { index in
                OnboardingPageView(
                    page: pages[index],
                    isLastPage: index == pages.count - 1,
                    onButtonTap: {
                        if index == pages.count - 1 {
                            // Last page - complete onboarding
                            withAnimation {
                                hasSeenOnboarding = true
                            }
                        } else {
                            // Move to next page
                            withAnimation {
                                currentPage = index + 1
                            }
                        }
                    }
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .animation(.easeInOut, value: currentPage)
        .transition(.slide)
    }
}

/// Model for onboarding page content
struct OnboardingPage {
    let title: String
    let message: String
    let imageName: String
    let buttonText: String
}

/// Reusable onboarding page view component
struct OnboardingPageView: View {
    /// Page content
    let page: OnboardingPage
    
    /// Whether this is the last page in the flow
    let isLastPage: Bool
    
    /// Action to perform when button is tapped
    let onButtonTap: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            Image(systemName: page.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.bottom, 20)
            
            // Title
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Message
            Text(page.message)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            // Button
            Button(action: onButtonTap) {
                Text(page.buttonText)
                    .fontWeight(.semibold)
                    .frame(width: 280, height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.bottom, 50)
            .accessibilityLabel(isLastPage ? "Get Started" : "Next Page")
        }
        .padding()
    }
}

/// Preview provider for OnboardingFlow
struct OnboardingFlow_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFlow()
    }
}