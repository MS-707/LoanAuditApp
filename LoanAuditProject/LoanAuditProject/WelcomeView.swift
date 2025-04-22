import SwiftUI

struct WelcomeView: View {
    @State private var showMainApp = false
    
    var body: some View {
        if showMainApp {
            AuditAppShell()
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "doc.text.magnifyingglass")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                    
                    Text("Let's bring clarity to your student loans.")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Your data stays on your device. Always.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showMainApp = true
                        }
                    }) {
                        HStack {
                            Text("🔍 Securely Analyze My Loans")
                                .fontWeight(.semibold)
                        }
                        .frame(minWidth: 250)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(radius: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Securely Analyze My Loans")
                    .padding(.bottom, 50)
                }
                .padding()
                .animation(.easeOut, value: true)
            }
            .transition(.opacity)
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}