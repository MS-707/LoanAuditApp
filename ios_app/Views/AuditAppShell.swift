import SwiftUI

/// Top-level shell for the Loan Audit App MVP
struct AuditAppShell: View {
    /// State for controlling the display of the about view
    @State private var showingAboutView = false
    
    var body: some View {
        #if os(iOS) && targetEnvironment(macCatalyst)
        // Use NavigationView on Mac Catalyst
        navigationViewContent
        #elseif os(iOS)
        // Check if we're running on iPad to use split view
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView {
                // Sidebar for iPad (empty for now)
                List {
                    NavigationLink("About", destination: AboutView())
                    NavigationLink("Audit Tool", destination: AuditReviewContainerView())
                        .bold()
                }
                .navigationTitle("Loan Audit")
            } detail: {
                // Detail view displays the main audit container
                AuditReviewContainerView()
            }
        } else {
            // Use standard NavigationView on iPhone
            navigationViewContent
        }
        #else
        // Fallback for other platforms
        navigationViewContent
        #endif
    }
    
    /// Standard NavigationView content for iPhone and fallback
    private var navigationViewContent: some View {
        NavigationView {
            AuditReviewContainerView()
                .navigationTitle("Loan Audit")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAboutView = true }) {
                            Image(systemName: "questionmark.circle")
                        }
                    }
                }
                .sheet(isPresented: $showingAboutView) {
                    AboutView()
                }
        }
    }
}

/// Simple placeholder for the About view
struct AboutView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.magnifyingglass")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(Color(.systemBlue))
                    .padding(.bottom, 10)
                
                Text("Student Loan Audit Tool")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Version 1.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("This app helps you identify potential issues in your student loan documents and provides actionable insights.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                Spacer()
                
                Text("© 2025 Student Loan Advocates")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // This will only be used when presented as a sheet
                    }
                }
            }
        }
    }
}

struct AuditAppShell_Previews: PreviewProvider {
    static var previews: some View { 
        AuditAppShell() 
    }
}