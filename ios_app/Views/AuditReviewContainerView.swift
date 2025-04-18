import SwiftUI
import PDFKit

/// View model that manages the state and business logic for the audit review process
final class AuditReviewViewModel: ObservableObject {
    /// Enumeration for tracking the various states of the audit review process
    enum AuditState {
        case initial        // Waiting for user to select a PDF
        case loading        // PDF parsing and audit in progress
        case results        // Audit results available
        case error(String)  // An error occurred during the process
    }
    
    /// Current state of the audit review process
    @Published var state: AuditState = .initial
    
    /// Results from the audit
    @Published var auditResults: [AuditResult] = []
    
    /// The file URL of the selected PDF
    @Published var selectedPDF: URL?
    
    /// Flag for enabling development/testing mode
    @Published var devModeEnabled = false
    
    /// The audit engine instance
    private let auditEngine = LoanAuditEngine()
    
    /// Processes a PDF file to extract loan details and perform an audit
    /// - Parameter url: The URL of the PDF file to process
    func processPDF(at url: URL) {
        self.selectedPDF = url
        self.state = .loading
        
        // Run on background thread to keep UI responsive
        Task {
            do {
                // Extract loan details from PDF
                let loanDetails = try await PDFLoanParser.extractLoanDetails(from: url)
                
                // Perform audit on the loan details
                let results = try await auditEngine.performAuditAsync(on: loanDetails)
                
                // Update UI on main thread
                await MainActor.run {
                    self.auditResults = results
                    self.state = .results
                }
            } catch let error as PDFParsingError {
                await MainActor.run {
                    // Provide user-friendly error messages based on the error type
                    switch error {
                    case .documentEmpty:
                        self.state = .error("The selected PDF appears to be empty.")
                    case .unreadableDocument:
                        self.state = .error("The PDF couldn't be read. It may be corrupted or password-protected.")
                    case .missingRequiredField(let fieldName):
                        self.state = .error("Required information missing: \(fieldName)")
                    case .invalidFieldFormat(let fieldName):
                        self.state = .error("Invalid format for: \(fieldName)")
                    case .unsupportedDocumentType:
                        self.state = .error("This document type is not supported. Please upload a loan statement.")
                    case .processingError(let message):
                        self.state = .error("Processing error: \(message)")
                    }
                }
            } catch {
                await MainActor.run {
                    self.state = .error("An unexpected error occurred: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Loads mock data for development/preview purposes
    func loadMockData() {
        self.state = .loading
        
        // Simulate network delay for realistic preview behavior
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            self.auditResults = AuditResult.mockSamples
            self.state = .results
        }
    }
    
    /// Resets the view model to its initial state
    func reset() {
        self.state = .initial
        self.auditResults = []
        self.selectedPDF = nil
    }
}

/// The main container view for the loan audit review process
struct AuditReviewContainerView: View {
    /// View model that manages the state and business logic
    @StateObject private var viewModel = AuditReviewViewModel()
    
    /// Indicates whether the document picker is being shown
    @State private var showingDocumentPicker = false
    
    /// Indicates whether the dev mode toggle is being shown
    @State private var showingDevOptions = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Display different content based on the current state
                switch viewModel.state {
                case .initial:
                    initialView
                case .loading:
                    loadingView
                case .results:
                    AuditResultView(results: viewModel.auditResults)
                case .error(let message):
                    errorView(message)
                }
            }
            .navigationTitle("Loan Audit")
            .toolbar {
                // Show reset button when audit is complete
                if case .results = viewModel.state {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: viewModel.reset) {
                            Text("New Audit")
                        }
                    }
                }
                
                // Dev mode toggle (hidden in triple tap)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingDevOptions = true }) {
                        Image(systemName: "gear")
                            .opacity(0.001) // Visually hidden but tappable
                    }
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(selectedURL: { url in
                    viewModel.processPDF(at: url)
                })
            }
            .alert("Developer Options", isPresented: $showingDevOptions) {
                Button("Load Mock Data") {
                    viewModel.loadMockData()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    /// View shown in the initial state, when the user needs to select a document
    private var initialView: some View {
        VStack(spacing: 25) {
            Image(systemName: "doc.text.magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(Color(.systemBlue))
                .padding(.bottom, 10)
            
            Text("Audit Your Student Loan")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Upload your loan statement to find potential issues and get actionable insights.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            Button(action: {
                showingDocumentPicker = true
            }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("Select PDF Statement")
                }
                .padding()
                .frame(minWidth: 240)
                .background(Color(.systemBlue))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top, 15)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loan audit initial screen")
        .accessibilityHint("Select a PDF loan statement to begin the audit")
    }
    
    /// View shown while the audit is in progress
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Analyzing your loan...")
                .font(.headline)
            
            if let selectedPDF = viewModel.selectedPDF {
                Text(selectedPDF.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Processing steps
            VStack(alignment: .leading, spacing: 10) {
                ProgressStep(text: "Extracting loan details", isActive: true)
                ProgressStep(text: "Identifying potential issues", isActive: true, delay: 1.0)
                ProgressStep(text: "Generating recommendations", isActive: true, delay: 2.0)
            }
            .padding(.top, 20)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Processing loan document")
        .accessibilityHint("Please wait while we analyze your loan statement")
    }
    
    /// View shown when an error occurs during the audit process
    /// - Parameter message: The error message to display
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(Color(.systemOrange))
                .padding()
            
            Text("Unable to Complete Audit")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: viewModel.reset) {
                Text("Try Again")
                    .padding()
                    .frame(minWidth: 200)
                    .background(Color(.systemBlue))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 15)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
        .accessibilityHint("Tap Try Again to return to the start screen")
    }
}

/// A step in the progress indicator for the loading view
struct ProgressStep: View {
    let text: String
    let isActive: Bool
    var delay: Double = 0
    
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 15) {
            Circle()
                .fill(isAnimating ? Color(.systemGreen) : Color(.systemGray4))
                .frame(width: 12, height: 12)
            
            Text(text)
                .font(.callout)
                .foregroundColor(isAnimating ? .primary : .secondary)
        }
        .onAppear {
            // Animate with a staggered delay for visual interest
            withAnimation(Animation.easeIn.delay(delay)) {
                isAnimating = isActive
            }
        }
    }
}

/// UIKit document picker wrapped for SwiftUI
struct DocumentPicker: UIViewControllerRepresentable {
    let selectedURL: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No update needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Get persistent access to the file
            guard url.startAccessingSecurityScopedResource() else {
                return
            }
            
            // Pass the URL back to the caller
            parent.selectedURL(url)
            
            // Release security access
            url.stopAccessingSecurityScopedResource()
        }
    }
}

// MARK: - Previews
struct AuditReviewContainerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Initial state
            AuditReviewContainerView()
                .previewDisplayName("Initial State")
            
            // Loading state
            LoadingStatePreview()
                .previewDisplayName("Loading State")
            
            // Results state
            ResultsStatePreview()
                .previewDisplayName("Results State")
            
            // Error state
            ErrorStatePreview()
                .previewDisplayName("Error State")
        }
    }
    
    // Helper preview views for different states
    struct LoadingStatePreview: View {
        var body: some View {
            NavigationView {
                AuditReviewContainerView(viewModel: mockViewModel(state: .loading))
            }
        }
    }
    
    struct ResultsStatePreview: View {
        var body: some View {
            NavigationView {
                AuditReviewContainerView(viewModel: mockViewModel(state: .results, 
                                                                  results: AuditResult.mockSamples))
            }
        }
    }
    
    struct ErrorStatePreview: View {
        var body: some View {
            NavigationView {
                AuditReviewContainerView(viewModel: mockViewModel(state: .error("Unable to extract required loan information from this document.")))
            }
        }
    }
    
    // Helper to create mock view models for previews
    static func mockViewModel(state: AuditReviewViewModel.AuditState, 
                             results: [AuditResult] = []) -> AuditReviewViewModel {
        let viewModel = AuditReviewViewModel()
        viewModel.state = state
        viewModel.auditResults = results
        return viewModel
    }
}

extension AuditReviewContainerView {
    init(viewModel: AuditReviewViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
}