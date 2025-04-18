import Foundation

/// The severity level of an audit issue
public enum AuditSeverity {
    case low
    case moderate
    case high
    case critical
    
    var description: String {
        switch self {
        case .low:
            return "Low - Minor potential issue"
        case .moderate:
            return "Moderate - Issue may affect loan terms"
        case .high:
            return "High - Significant impact on loan repayment"
        case .critical:
            return "Critical - May violate regulations or severely impact finances"
        }
    }
}

/// The type of issues that can be found during a loan audit
public enum AuditIssue {
    case excessiveForbearance
    case unexplainedInterestCapitalization
    case extendedNonPayment
    case highInterestRate
    case inaccurateBalance
    case misappliedPayment
}

/// The result of evaluating a loan with an audit rule
public struct AuditResult {
    let issueType: AuditIssue
    let description: String
    let severity: AuditSeverity
    let suggestedAction: String
    let affectedDates: [Date]?
    
    init(issueType: AuditIssue, description: String, severity: AuditSeverity, suggestedAction: String, affectedDates: [Date]? = nil) {
        self.issueType = issueType
        self.description = description
        self.severity = severity
        self.suggestedAction = suggestedAction
        self.affectedDates = affectedDates
    }
}

/// Protocol defining a rule that can be used to audit a loan
public protocol AuditRule {
    /// Evaluate a loan and return an AuditResult if an issue is found
    func evaluate(_ loan: LoanDetails) -> AuditResult?
}

/// Rule to check if forbearance periods exceed recommended durations
public struct ExcessiveForbearanceRule: AuditRule {
    private let maximumMonths: Int
    
    init(maximumMonths: Int = 36) {
        self.maximumMonths = maximumMonths
    }
    
    public func evaluate(_ loan: LoanDetails) -> AuditResult? {
        let totalForbearanceMonths = loan.totalForbearanceDuration()
        
        if totalForbearanceMonths > maximumMonths {
            let description = "Loan has \(totalForbearanceMonths) months of forbearance, which exceeds the recommended maximum of \(maximumMonths) months"
            let severity: AuditSeverity = totalForbearanceMonths > 60 ? .high : .moderate
            let action = "Review forbearance history with loan servicer. Extended forbearance may lead to significant interest capitalization."
            
            // Get the dates of forbearance periods
            let forbearanceDates = loan.nonPaymentPeriods
                .filter { $0.type == .forbearance }
                .flatMap { [period] in [period.startDate, period.endDate] }
            
            return AuditResult(
                issueType: .excessiveForbearance,
                description: description,
                severity: severity,
                suggestedAction: action,
                affectedDates: forbearanceDates
            )
        }
        
        return nil
    }
}

/// Rule to check for unexplained interest capitalization events
public struct UnexplainedCapitalizationRule: AuditRule {
    public func evaluate(_ loan: LoanDetails) -> AuditResult? {
        guard !loan.interestCapitalizationEvents.isEmpty else { return nil }
        
        // Check if capitalization events correspond to the end of forbearance/deferment periods
        var unexplainedEvents: [Date] = []
        let allowedWindowInDays: Double = 30  // Allow for some timing flexibility
        
        for capitalizationDate in loan.interestCapitalizationEvents {
            let isExplained = loan.nonPaymentPeriods.contains { period in
                let endDate = period.endDate
                let daysDifference = abs(endDate.timeIntervalSince(capitalizationDate)) / (60 * 60 * 24)
                return daysDifference <= allowedWindowInDays
            }
            
            if !isExplained {
                unexplainedEvents.append(capitalizationDate)
            }
        }
        
        if !unexplainedEvents.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            
            let datesString = unexplainedEvents
                .map { dateFormatter.string(from: $0) }
                .joined(separator: ", ")
            
            let description = "Found \(unexplainedEvents.count) unexplained interest capitalization events on: \(datesString)"
            let severity: AuditSeverity = unexplainedEvents.count > 3 ? .high : .moderate
            let action = "Request detailed explanation from loan servicer for each capitalization event. Review loan terms to verify if these events were permitted."
            
            return AuditResult(
                issueType: .unexplainedInterestCapitalization,
                description: description,
                severity: severity,
                suggestedAction: action,
                affectedDates: unexplainedEvents
            )
        }
        
        return nil
    }
}

/// Rule to check for periods of non-payment without corresponding forbearance/deferment
public struct ExtendedNonPaymentRule: AuditRule {
    private let minimumMonths: Int
    
    init(minimumMonths: Int = 2) {
        self.minimumMonths = minimumMonths
    }
    
    public func evaluate(_ loan: LoanDetails) -> AuditResult? {
        let unexplainedPeriods = loan.findUnexplainedNonPaymentPeriods(minimumMonths: minimumMonths)
        
        if !unexplainedPeriods.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            
            let periodsDescription = unexplainedPeriods
                .map { "From \(dateFormatter.string(from: $0.start)) to \(dateFormatter.string(from: $0.end))" }
                .joined(separator: "; ")
            
            let description = "Found \(unexplainedPeriods.count) periods of non-payment without corresponding forbearance or deferment status: \(periodsDescription)"
            
            // Calculate severity based on number of periods and total duration
            let totalDays = unexplainedPeriods.reduce(0) { total, interval in
                total + Int(interval.duration / (60 * 60 * 24))
            }
            
            let severity: AuditSeverity
            if totalDays > 180 {
                severity = .high
            } else if totalDays > 90 {
                severity = .moderate
            } else {
                severity = .low
            }
            
            let action = "Request documentation for these periods to confirm loan status. If payments were made, verify they were properly applied."
            
            // Extract the dates for affected periods
            let affectedDates = unexplainedPeriods.flatMap { [$0.start, $0.end] }
            
            return AuditResult(
                issueType: .extendedNonPayment,
                description: description,
                severity: severity,
                suggestedAction: action,
                affectedDates: affectedDates
            )
        }
        
        return nil
    }
}

/// Rule to check if interest rate is unusually high compared to federal loan standards
public struct HighInterestRateRule: AuditRule {
    private let threshold: Double
    
    init(threshold: Double = 6.8) {  // 6.8% was the cap for many federal student loans
        self.threshold = threshold
    }
    
    public func evaluate(_ loan: LoanDetails) -> AuditResult? {
        if loan.interestRate > threshold {
            let description = "Loan interest rate of \(String(format: "%.2f", loan.interestRate))% exceeds typical federal loan rate of \(String(format: "%.2f", threshold))%"
            
            // Calculate severity based on how much it exceeds the threshold
            let severity: AuditSeverity
            let excess = loan.interestRate - threshold
            
            if excess > 3.0 {
                severity = .high
            } else if excess > 1.5 {
                severity = .moderate
            } else {
                severity = .low
            }
            
            let action = "Verify that the interest rate is correctly applied. Consider refinancing options if the rate is indeed this high."
            
            return AuditResult(
                issueType: .highInterestRate,
                description: description,
                severity: severity,
                suggestedAction: action
            )
        }
        
        return nil
    }
}

/// The main engine responsible for running audit rules and collecting results
public class LoanAuditEngine {
    private var rules: [AuditRule]
    
    /// Initialize with default rules
    public init() {
        self.rules = [
            ExcessiveForbearanceRule(),
            UnexplainedCapitalizationRule(),
            ExtendedNonPaymentRule(),
            HighInterestRateRule()
        ]
    }
    
    /// Initialize with custom rules
    public init(rules: [AuditRule]) {
        self.rules = rules
    }
    
    /// Add a rule to the engine
    public func addRule(_ rule: AuditRule) {
        rules.append(rule)
    }
    
    /// Run all rules against the provided loan details
    public func performAudit(on loanDetails: LoanDetails) -> [AuditResult] {
        var results: [AuditResult] = []
        
        for rule in rules {
            if let result = rule.evaluate(loanDetails) {
                results.append(result)
            }
        }
        
        return results
    }
    
    /// Run specific rules by type
    public func performAudit(on loanDetails: LoanDetails, forIssue issueType: AuditIssue) -> [AuditResult] {
        return performAudit(on: loanDetails).filter { $0.issueType == issueType }
    }
}