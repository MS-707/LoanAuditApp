import SwiftUI

/// Extension to provide color mapping for AuditSeverity levels
extension AuditSeverity {
    /// Returns a color representing the severity level
    var color: Color {
        switch self {
        case .low:
            return Color.yellow
        case .moderate:
            return Color.orange
        case .high:
            return Color.red
        case .critical:
            return Color(red: 0.7, green: 0, blue: 0) // dark red
        }
    }
    
    /// Returns an accessibility description for the severity level
    var accessibilityDescription: String {
        switch self {
        case .low:
            return "Low severity"
        case .moderate:
            return "Moderate severity"
        case .high:
            return "High severity"
        case .critical:
            return "Critical severity"
        }
    }
}

/// Extension to provide mock data for previews and testing
extension AuditResult {
    /// Mock samples of AuditResult for testing and preview purposes
    static var mockSamples: [AuditResult] {
        [
            AuditResult(
                issueType: .excessiveForbearance,
                ruleCode: "FORBEAR_EXCESS_001",
                description: "Loan has 48 months of forbearance, which exceeds the recommended maximum of 36 months",
                severity: .moderate,
                suggestedAction: "Review forbearance history with your loan servicer. Extended forbearance can dramatically increase interest capitalization.",
                title: "Excessive Forbearance Duration"
            ),
            AuditResult(
                issueType: .excessiveForbearance,
                ruleCode: "FORBEAR_EXCESS_002",
                description: "Loan has 72 months of forbearance, which exceeds the recommended maximum of 36 months",
                severity: .high,
                suggestedAction: "Your extended forbearance period may have significantly increased your loan balance through interest capitalization. Consider contacting your servicer to discuss options.",
                title: "Excessive Forbearance Duration"
            ),
            AuditResult(
                issueType: .unexplainedInterestCapitalization,
                ruleCode: "CAP_UNEXP_001",
                description: "Found 3 unexplained interest capitalization events on: Jan 15, 2022, Mar 3, 2022, July 10, 2022",
                severity: .high,
                suggestedAction: "Request detailed explanation from your loan servicer for each capitalization event. Review your loan terms to verify if these events were permitted under your loan agreement.",
                title: "Unexplained Interest Capitalization"
            ),
            AuditResult(
                issueType: .extendedNonPayment,
                ruleCode: "NONPAY_001",
                description: "Found 2 periods of non-payment without corresponding forbearance or deferment status: From Apr 2, 2021 to Aug 15, 2021; From Oct 5, 2022 to Jan 12, 2023",
                severity: .critical,
                suggestedAction: "Request documentation for these periods to confirm your loan status. If payments were made during these periods, request verification that they were properly applied to your account.",
                title: "Extended Non-Payment Period"
            ),
            AuditResult(
                issueType: .highInterestRate,
                ruleCode: "INTEREST_HIGH_001",
                description: "Loan interest rate of 8.5% exceeds typical federal loan rate of 6.8%",
                severity: .low,
                suggestedAction: "Verify that the interest rate is correctly applied to your loan. If the rate is accurate, consider researching refinancing options to potentially lower your interest rate and overall repayment costs.",
                title: "High Interest Rate"
            )
        ]
    }
}

/// View for displaying a list of audit results
struct AuditResultView: View {
    /// Results to display
    let results: [AuditResult]
    
    /// Computed property to group results by issue type
    private var groupedResults: [AuditIssue: [AuditResult]] {
        Dictionary(grouping: results, by: { $0.issueType })
    }
    
    var body: some View {
        List {
            if results.isEmpty {
                emptyStateView
            } else {
                ForEach(AuditIssue.allCases, id: \.self) { issueType in
                    if let issueResults = groupedResults[issueType], !issueResults.isEmpty {
                        Section(header: Text(issueType.localizedDescription).font(.headline)) {
                            ForEach(issueResults, id: \.ruleCode) { result in
                                AuditResultRowView(result: result)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Audit Results")
        .accessibilityLabel("Audit results list")
    }
    
    /// View displayed when there are no results
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size:.zero).font(size: 60))
                .foregroundColor(.green)
            
            Text("No issues found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your loan appears to be in good standing based on our audit criteria.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No audit issues found")
    }
}

/// Row view for a single audit result
struct AuditResultRowView: View {
    /// The audit result to display
    let result: AuditResult
    
    /// Whether the suggested action is expanded
    @State private var isActionExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Severity indicator
                Circle()
                    .fill(result.severity.color)
                    .frame(width: 12, height: 12)
                    .overlay(
                        result.severity == .critical ?
                            Circle()
                                .strokeBorder(result.severity.color, lineWidth: 2)
                                .frame(width: 16, height: 16)
                            : nil
                    )
                    .accessibilityHidden(true)
                    .padding(.top, 4)
                
                // Result title and description
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(result.description)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Only show action disclosure if there is action text
            if !result.suggestedAction.isEmpty {
                DisclosureGroup(
                    isExpanded: $isActionExpanded,
                    content: {
                        Text(result.suggestedAction)
                            .font(.callout)
                            .padding(.vertical, 8)
                            .fixedSize(horizontal: false, vertical: true)
                    },
                    label: {
                        Text("Suggested Action")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                )
                .padding(.leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        isActionExpanded.toggle()
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.title), \(result.severity.accessibilityDescription)")
        .accessibilityHint("Double tap to \(isActionExpanded ? "hide" : "show") suggested action")
        .accessibilityAction {
            withAnimation {
                isActionExpanded.toggle()
            }
        }
    }
}

// MARK: - Previews
struct AuditResultView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Normal state with results
            NavigationView {
                AuditResultView(results: AuditResult.mockSamples)
            }
            .previewDisplayName("Results List")
            
            // Empty state
            NavigationView {
                AuditResultView(results: [])
            }
            .previewDisplayName("Empty State")
            
            // Single result row
            AuditResultRowView(result: AuditResult.mockSamples[0])
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Result Row")
        }
    }
}

// MARK: - Logic Tests
#if DEBUG
struct AuditResultViewTests {
    /// Tests that severity levels map to expected colors
    static func testSeverityColors() -> Bool {
        let expectedColors: [AuditSeverity: Color] = [
            .low: .yellow,
            .moderate: .orange,
            .high: .red,
            .critical: Color(red: 0.7, green: 0, blue: 0)
        ]
        
        // Verify all severity levels map to expected colors
        for severity in [AuditSeverity.low, .moderate, .high, .critical] {
            if severity.color != expectedColors[severity] {
                return false
            }
        }
        
        return true
    }
}
#endif