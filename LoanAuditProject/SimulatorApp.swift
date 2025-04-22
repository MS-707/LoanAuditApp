import SwiftUI

@main
struct SimulatorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var auditResults = [
        AuditResult(
            title: "High Interest Rate",
            description: "Loan interest rate of 6.8% exceeds typical federal loan rate of 5.00%",
            severity: .moderate,
            suggestedAction: "Verify that the interest rate is correctly applied to your loan. If the rate is accurate, consider researching refinancing options to potentially lower your interest rate and overall repayment costs."
        ),
        AuditResult(
            title: "Excessive Forbearance Duration",
            description: "Loan has approximately 48 months of forbearance, which exceeds the recommended maximum of 36 months",
            severity: .high,
            suggestedAction: "Review forbearance history with your loan servicer. Extended forbearance can dramatically increase interest capitalization."
        ),
        AuditResult(
            title: "Servicer with Known Issues",
            description: "Your loan is serviced by Navient, which has been involved in recent legal settlements regarding loan servicing practices.",
            severity: .low,
            suggestedAction: "Review your account history carefully. Consider requesting a complete account history and payment record to verify all transactions have been properly applied."
        )
    ]
    
    @State private var loadingProgress = 1.0
    @State private var isShowingDetails = false
    @State private var selectedResult: AuditResult?
    
    var body: some View {
        NavigationView {
            VStack {
                loanInfoView
                
                List {
                    ForEach(auditResults) { result in
                        AuditResultRow(result: result)
                            .onTapGesture {
                                selectedResult = result
                                isShowingDetails = true
                            }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .navigationTitle("Loan Audit Results")
            }
            .sheet(isPresented: $isShowingDetails, content: {
                if let result = selectedResult {
                    DetailView(result: result)
                }
            })
        }
    }
    
    private var loanInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Loan Details")
                .font(.headline)
                .padding(.bottom, 4)
            
            LoanDetailRow(label: "Account", value: "123456789")
            LoanDetailRow(label: "Servicer", value: "Navient")
            LoanDetailRow(label: "Interest Rate", value: "6.8%")
            LoanDetailRow(label: "Balance", value: "$45,678.90")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding()
    }
}

struct LoanDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}

struct AuditResult: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let severity: AuditSeverity
    let suggestedAction: String
}

enum AuditSeverity {
    case low, moderate, high, critical
    
    var color: Color {
        switch self {
        case .low:       return Color.yellow
        case .moderate:  return Color.orange
        case .high:      return Color.red
        case .critical:  return Color.red.opacity(0.8)
        }
    }
    
    var name: String {
        switch self {
        case .low:       return "Low severity"
        case .moderate:  return "Moderate severity"
        case .high:      return "High severity"
        case .critical:  return "Critical severity"
        }
    }
}

struct AuditResultRow: View {
    let result: AuditResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Severity indicator
                Circle()
                    .fill(result.severity.color)
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)
                
                // Result title and description
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.title)
                        .font(.headline)
                    
                    Text(result.description)
                        .font(.body)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct DetailView: View {
    let result: AuditResult
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(result.severity.name)
                        .font(.subheadline)
                        .padding(6)
                        .background(result.severity.color.opacity(0.2))
                        .foregroundColor(result.severity.color)
                        .cornerRadius(4)
                    
                    Spacer()
                }
                
                Text(result.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(result.description)
                    .font(.body)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Suggested Action")
                        .font(.headline)
                    
                    Text(result.suggestedAction)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Issue Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}