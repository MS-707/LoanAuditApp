import Foundation

/// Shared constants and policy values used across audit rules
public struct AuditPolicy: Sendable {
    // Forbearance and deferment thresholds
    /// Maximum recommended forbearance duration in months (36 months / 3 years)
    /// Federal guidance typically suggests limiting forbearance to avoid excessive interest capitalization
    public static let maxForbearanceMonths: Int = 36
    
    /// Severe forbearance threshold in months (60 months / 5 years)
    /// Exceeding this duration suggests potential mismanagement of forbearance benefits
    public static let severeForbearanceMonths: Int = 60
    
    /// Minimum period (in months) to consider a gap in payments significant
    public static let minNonPaymentMonths: Int = 2
    
    // Severity thresholds for non-payment periods
    /// Non-payment period over 90 days is considered moderate severity
    public static let moderateNonPaymentDays: Int = 90
    
    /// Non-payment period over 180 days is considered high severity
    public static let highNonPaymentDays: Int = 180
    
    // Interest rate thresholds
    /// Standard maximum interest rate for federal student loans (historically 6.8%)
    public static let standardMaxInterestRate: Double = 6.8
    
    /// Thresholds for excess interest rate severity
    public static let moderateExcessInterestRate: Double = 1.5
    public static let highExcessInterestRate: Double = 3.0
    
    // Capitalization event policies
    /// Number of unexplained capitalization events to trigger high severity alert
    public static let highCapitalizationEventCount: Int = 3
    
    /// Allowed window in days for a capitalization event to be associated with end of forbearance
    public static let capitalizationWindowDays: Double = 30
    
    // Time constants
    /// Number of seconds in a day, used for date interval calculations
    public static let secondsPerDay: Double = 60 * 60 * 24
}

/// Helper for formatting values consistently across the audit engine
public enum AuditFormatters {
    /// Thread-safe date formatter function that creates a new instance each time
    public static func dateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    /// Thread-safe number formatter function for interest rates
    public static func interestRateFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
    
    /// Format a date using a thread-safe formatter with current locale
    public static func formatDate(_ date: Date) -> String {
        return NSLocalizedString(
            dateFormatter().string(from: date),
            comment: "Formatted date for audit report"
        )
    }
    
    /// Format an interest rate as a percentage string
    public static func formatInterestRate(_ rate: Double) -> String {
        return NSLocalizedString(
            "\(interestRateFormatter().string(from: NSNumber(value: rate)) ?? String(format: "%.2f", rate))%",
            comment: "Formatted interest rate for audit report"
        )
    }
    
    /// Format an integer using locale settings
    public static func formatInteger(_ number: Int) -> String {
        return NumberFormatter.localizedString(from: number as NSNumber, number: .decimal)
    }
}

/// Helper for scaling severity based on value thresholds
public struct SeverityScaler: Sendable {
    /// Calculate severity based on a value and thresholds
    /// - Parameters:
    ///   - value: The value to evaluate
    ///   - low: Threshold for low severity (default)
    ///   - moderate: Threshold for moderate severity
    ///   - high: Threshold for high severity
    ///   - critical: Threshold for critical severity
    /// - Returns: The appropriate severity level based on thresholds, or nil if below moderate threshold
    public static func scale(
        value: Double,
        low: Double? = nil,
        moderate: Double,
        high: Double,
        critical: Double? = nil
    ) -> AuditSeverity? {
        if let criticalThreshold = critical, value >= criticalThreshold {
            return .critical
        } else if value >= high {
            return .high
        } else if value >= moderate {
            return .moderate
        } else if let lowThreshold = low, value >= lowThreshold {
            return .low
        } else {
            return nil
        }
    }
}

/// The severity level of an audit issue
public enum AuditSeverity: Comparable, Sendable {
    case low
    case moderate
    case high
    case critical
    
    /// Compare severity levels for sorting purposes
    public static func < (lhs: AuditSeverity, rhs: AuditSeverity) -> Bool {
        let order: [AuditSeverity] = [.low, .moderate, .high, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// Extension to provide human-readable descriptions of severity levels
extension AuditSeverity: CustomStringConvertible {
    public var description: String {
        switch self {
        case .low:
            return NSLocalizedString(
                "Low - Minor potential issue",
                comment: "Low severity audit issue description"
            )
        case .moderate:
            return NSLocalizedString(
                "Moderate - Issue may affect loan terms",
                comment: "Moderate severity audit issue description"
            )
        case .high:
            return NSLocalizedString(
                "High - Significant impact on loan repayment",
                comment: "High severity audit issue description"
            )
        case .critical:
            return NSLocalizedString(
                "Critical - May violate regulations or severely impact finances",
                comment: "Critical severity audit issue description"
            )
        }
    }
}

/// The type of issues that can be found during a loan audit
public enum AuditIssue: String, CaseIterable, Sendable {
    case excessiveForbearance
    case unexplainedInterestCapitalization
    case extendedNonPayment
    case highInterestRate
    case inaccurateBalance
    case misappliedPayment
    
    /// Human-readable description of the issue type
    public var localizedDescription: String {
        switch self {
        case .excessiveForbearance:
            return NSLocalizedString(
                "Excessive Forbearance",
                comment: "Audit issue for excessive forbearance periods"
            )
        case .unexplainedInterestCapitalization:
            return NSLocalizedString(
                "Unexplained Interest Capitalization",
                comment: "Audit issue for unexplained interest capitalization events"
            )
        case .extendedNonPayment:
            return NSLocalizedString(
                "Extended Non-payment Period",
                comment: "Audit issue for extended periods without payment"
            )
        case .highInterestRate:
            return NSLocalizedString(
                "High Interest Rate",
                comment: "Audit issue for unusually high interest rates"
            )
        case .inaccurateBalance:
            return NSLocalizedString(
                "Inaccurate Balance",
                comment: "Audit issue for inaccurate loan balance calculations"
            )
        case .misappliedPayment:
            return NSLocalizedString(
                "Misapplied Payment",
                comment: "Audit issue for payments applied incorrectly"
            )
        }
    }
}

/// The result of evaluating a loan with an audit rule
public struct AuditResult: Equatable, Sendable {
    /// The type of issue identified
    public let issueType: AuditIssue
    
    /// A unique code identifying the specific rule that generated this result
    public let ruleCode: String
    
    /// Human-readable description of the issue
    public let description: String
    
    /// The severity level of the issue
    public let severity: AuditSeverity
    
    /// Recommended action to address the issue
    public let suggestedAction: String
    
    /// Dates affected by this issue, if applicable
    public let affectedDates: [Date]?
    
    /// Optional URL for documentation about this issue
    public let docsURL: URL?
    
    /// Title of the issue (defaults to issue type description if not provided)
    public let title: String
    
    public init(
        issueType: AuditIssue,
        ruleCode: String,
        description: String,
        severity: AuditSeverity,
        suggestedAction: String,
        affectedDates: [Date]? = nil,
        docsURL: URL? = nil,
        title: String? = nil
    ) {
        self.issueType = issueType
        self.ruleCode = ruleCode
        self.description = description
        self.severity = severity
        self.suggestedAction = suggestedAction
        self.affectedDates = affectedDates
        self.docsURL = docsURL
        self.title = title ?? issueType.localizedDescription
    }
    
    /// Equatable implementation that ignores dates since they're hard to compare
    public static func == (lhs: AuditResult, rhs: AuditResult) -> Bool {
        return lhs.issueType == rhs.issueType &&
               lhs.ruleCode == rhs.ruleCode &&
               lhs.description == rhs.description &&
               lhs.severity == rhs.severity &&
               lhs.suggestedAction == rhs.suggestedAction &&
               lhs.title == rhs.title
        // Note: We deliberately don't compare affectedDates or docsURL for equality
    }
}

/// Extension to provide grouping functionality for arrays of audit results
extension Array where Element == AuditResult {
    /// Group results by issue type
    /// - Returns: Dictionary mapping issue types to arrays of results
    public func groupedByIssue() -> [AuditIssue: [AuditResult]] {
        var grouped: [AuditIssue: [AuditResult]] = [:]
        
        for result in self {
            if grouped[result.issueType] == nil {
                grouped[result.issueType] = []
            }
            grouped[result.issueType]?.append(result)
        }
        
        return grouped
    }
}

/// Protocol defining a rule that can be used to audit a loan
public protocol AuditRule: Sendable {
    /// Evaluate a loan and return an AuditResult if an issue is found
    /// - Parameter loan: The loan details to evaluate
    /// - Returns: An AuditResult if an issue is found, nil otherwise
    @discardableResult
    func evaluate(_ loan: LoanDetails) -> AuditResult?
    
    /// Returns a unique code identifying this rule
    var ruleCode: String { get }
    
    /// User-friendly title for this rule
    var title: String { get }
    
    /// Optional URL for documentation about this rule
    var docsURL: URL? { get }
}

/// Default implementation for optional properties
extension AuditRule {
    public var title: String {
        return ruleCode
    }
    
    public var docsURL: URL? {
        return nil
    }
}

/// Base class for duration-based non-payment rules
/// This consolidates common logic for ExcessiveForbearanceRule and ExtendedNonPaymentRule
public class NonPaymentDurationRule: AuditRule {
    private let maximumMonths: Int
    private let ruleName: String
    private let issueType: AuditIssue
    public let ruleCode: String
    public let title: String
    public let docsURL: URL?
    
    init(
        maximumMonths: Int,
        ruleName: String,
        issueType: AuditIssue,
        ruleCode: String,
        title: String? = nil,
        docsURL: URL? = nil
    ) {
        self.maximumMonths = maximumMonths
        self.ruleName = ruleName
        self.issueType = issueType
        self.ruleCode = ruleCode
        self.title = title ?? ruleName
        self.docsURL = docsURL
    }
    
    /// Evaluates duration against the threshold
    /// - Parameters:
    ///   - actualMonths: The actual duration in months
    ///   - loan: The loan details
    ///   - messageFormat: The format string for the description
    ///   - actionMessage: The suggested action
    ///   - affectedDates: The dates affected by this issue
    /// - Returns: An AuditResult if the duration exceeds the threshold
    func evaluateDuration(
        actualMonths: Int,
        loan: LoanDetails,
        messageFormat: String,
        actionMessage: String,
        affectedDates: [Date]
    ) -> AuditResult? {
        guard actualMonths > maximumMonths else { return nil }
        
        let description = String(format: messageFormat,
            AuditFormatters.formatInteger(actualMonths),
            AuditFormatters.formatInteger(maximumMonths)
        )
        
        let severity = SeverityScaler.scale(
            value: Double(actualMonths),
            moderate: Double(maximumMonths),
            high: Double(AuditPolicy.severeForbearanceMonths)
        ) ?? .low
        
        return AuditResult(
            issueType: issueType,
            ruleCode: ruleCode,
            description: description,
            severity: severity,
            suggestedAction: actionMessage,
            affectedDates: affectedDates,
            docsURL: docsURL,
            title: title
        )
    }
    
    public func evaluate(_ loan: LoanDetails) -> AuditResult? {
        fatalError("Subclasses must implement evaluate()")
    }
}

/// Rule to check if forbearance periods exceed recommended durations
public final class ExcessiveForbearanceRule: NonPaymentDurationRule {
    
    /// Initialize with default threshold from AuditPolicy
    public init() {
        super.init(
            maximumMonths: AuditPolicy.maxForbearanceMonths,
            ruleName: "ExcessiveForbearance",
            issueType: .excessiveForbearance,
            ruleCode: "FORBEAR_EXCESS_001",
            title: NSLocalizedString("Excessive Forbearance Duration", comment: "Title for excessive forbearance rule"),
            docsURL: URL(string: "https://studentaid.gov/manage-loans/lower-payments/get-temporary-relief/forbearance")
        )
    }
    
    /// Initialize with custom threshold
    public init(maximumMonths: Int) {
        super.init(
            maximumMonths: maximumMonths,
            ruleName: "ExcessiveForbearance",
            issueType: .excessiveForbearance,
            ruleCode: "FORBEAR_EXCESS_001",
            title: NSLocalizedString("Excessive Forbearance Duration", comment: "Title for excessive forbearance rule"),
            docsURL: URL(string: "https://studentaid.gov/manage-loans/lower-payments/get-temporary-relief/forbearance")
        )
    }
    
    public override func evaluate(_ loan: LoanDetails) -> AuditResult? {
        let totalForbearanceMonths = loan.totalForbearanceDuration()
        
        // Get the dates of forbearance periods
        let forbearanceDates = loan.nonPaymentPeriods
            .filter { $0.type == .forbearance }
            .flatMap { period in [period.startDate, period.endDate] }
        
        return evaluateDuration(
            actualMonths: totalForbearanceMonths,
            loan: loan,
            messageFormat: NSLocalizedString(
                "Loan has %@ months of forbearance, which exceeds the recommended maximum of %@ months",
                comment: "Message format for excessive forbearance rule"
            ),
            actionMessage: NSLocalizedString(
                "Review the full forbearance history with your loan servicer. Extended forbearance can dramatically increase interest capitalization.",
                comment: "Action for excessive forbearance"
            ),
            affectedDates: forbearanceDates
        )
    }
}

/// Rule to check for unexplained interest capitalization events
public struct UnexplainedCapitalizationRule: AuditRule {
    public let ruleCode = "CAP_UNEXP_001"
    public let title = NSLocalizedString("Unexplained Interest Capitalization", comment: "Title for unexplained capitalization rule")
    public let docsURL = URL(string: "https://studentaid.gov/understand-aid/types/loans/interest-rates#capitalization")
    
    public func evaluate(_ loan: LoanDetails) -> AuditResult? {
        guard !loan.interestCapitalizationEvents.isEmpty else { return nil }
        
        // Check if capitalization events correspond to the end of forbearance/deferment periods
        var unexplainedEvents: [Date] = []
        
        for capitalizationDate in loan.interestCapitalizationEvents {
            let isExplained = loan.nonPaymentPeriods.contains { period in
                let endDate = period.endDate
                let daysDifference = abs(endDate.timeIntervalSince(capitalizationDate)) / AuditPolicy.secondsPerDay
                return daysDifference <= AuditPolicy.capitalizationWindowDays
            }
            
            if !isExplained {
                unexplainedEvents.append(capitalizationDate)
            }
        }
        
        if !unexplainedEvents.isEmpty {
            let datesString = unexplainedEvents
                .map { AuditFormatters.formatDate($0) }
                .joined(separator: ", ")
            
            let description = String(format: NSLocalizedString(
                "Found %@ unexplained interest capitalization events on: %@",
                comment: "Message format for unexplained capitalization events"
            ), AuditFormatters.formatInteger(unexplainedEvents.count), datesString)
            
            // Use SeverityScaler for consistent severity classification
            let severity = SeverityScaler.scale(
                value: Double(unexplainedEvents.count),
                moderate: 1.0,
                high: Double(AuditPolicy.highCapitalizationEventCount)
            ) ?? .low
            
            let action = NSLocalizedString(
                "Request detailed explanation from your loan servicer for each capitalization event. Review your loan terms to verify if these events were permitted under your loan agreement.",
                comment: "Action for unexplained capitalization events"
            )
            
            return AuditResult(
                issueType: .unexplainedInterestCapitalization,
                ruleCode: ruleCode,
                description: description,
                severity: severity,
                suggestedAction: action,
                affectedDates: unexplainedEvents,
                docsURL: docsURL,
                title: title
            )
        }
        
        return nil
    }
}

/// Rule to check for periods of non-payment without corresponding forbearance/deferment
public final class ExtendedNonPaymentRule: AuditRule {
    private let minimumMonths: Int
    public let ruleCode = "NONPAY_001"
    public let title = NSLocalizedString("Extended Non-Payment Period", comment: "Title for extended non-payment rule")
    public let docsURL = URL(string: "https://studentaid.gov/manage-loans/default/getting-out")
    
    public init(minimumMonths: Int = AuditPolicy.minNonPaymentMonths) {
        self.minimumMonths = minimumMonths
    }
    
    public func evaluate(_ loan: LoanDetails) -> AuditResult? {
        let unexplainedPeriods = loan.findUnexplainedNonPaymentPeriods(minimumMonths: minimumMonths)
        
        if !unexplainedPeriods.isEmpty {
            let periodsDescription = unexplainedPeriods
                .map { period in
                    String(format: NSLocalizedString(
                        "From %@ to %@",
                        comment: "Date range format for audit periods"
                    ), AuditFormatters.formatDate(period.start), AuditFormatters.formatDate(period.end))
                }
                .joined(separator: "; ")
            
            let description = String(format: NSLocalizedString(
                "Found %@ periods of non-payment without corresponding forbearance or deferment status: %@",
                comment: "Message for unexplained non-payment periods"
            ), AuditFormatters.formatInteger(unexplainedPeriods.count), periodsDescription)
            
            // Calculate severity based on number of periods and total duration
            let totalDays = unexplainedPeriods.reduce(0) { total, interval in
                total + Int(interval.duration / AuditPolicy.secondsPerDay)
            }
            
            let severity = SeverityScaler.scale(
                value: Double(totalDays),
                moderate: Double(AuditPolicy.moderateNonPaymentDays),
                high: Double(AuditPolicy.highNonPaymentDays)
            ) ?? .low
            
            let action = NSLocalizedString(
                "Request detailed documentation for these periods to confirm your loan status. If payments were made during these periods, request verification that they were properly applied to your account.",
                comment: "Action for unexplained non-payment periods"
            )
            
            // Extract the dates for affected periods
            let affectedDates = unexplainedPeriods.flatMap { [$0.start, $0.end] }
            
            return AuditResult(
                issueType: .extendedNonPayment,
                ruleCode: ruleCode,
                description: description,
                severity: severity,
                suggestedAction: action,
                affectedDates: affectedDates,
                docsURL: docsURL,
                title: title
            )
        }
        
        return nil
    }
}

/// Rule to check if interest rate is unusually high compared to federal loan standards
public struct HighInterestRateRule: AuditRule {
    private let threshold: Double
    public let ruleCode = "INTEREST_HIGH_001"
    public let title = NSLocalizedString("Unusually High Interest Rate", comment: "Title for high interest rate rule")
    public let docsURL = URL(string: "https://studentaid.gov/understand-aid/types/loans/interest-rates")
    
    /// Initialize with default threshold from AuditPolicy
    public init() {
        self.threshold = AuditPolicy.standardMaxInterestRate
    }
    
    /// Initialize with a custom threshold
    /// - Parameter threshold: The interest rate threshold to use
    public init(threshold: Double) {
        self.threshold = threshold
    }
    
    public func evaluate(_ loan: LoanDetails) -> AuditResult? {
        guard loan.interestRate > threshold else { return nil }
        
        let description = String(format: NSLocalizedString(
            "Loan interest rate of %@ exceeds typical federal loan rate of %@",
            comment: "Message for high interest rate"
        ), AuditFormatters.formatInterestRate(loan.interestRate), AuditFormatters.formatInterestRate(threshold))
        
        // Calculate severity based on how much it exceeds the threshold
        let excess = loan.interestRate - threshold
        
        let severity = SeverityScaler.scale(
            value: excess,
            moderate: AuditPolicy.moderateExcessInterestRate,
            high: AuditPolicy.highExcessInterestRate
        ) ?? .low
        
        let action = NSLocalizedString(
            "Verify that the interest rate is correctly applied to your loan. If the rate is accurate, consider researching refinancing options to potentially lower your interest rate and overall repayment costs.",
            comment: "Action for high interest rate"
        )
        
        return AuditResult(
            issueType: .highInterestRate,
            ruleCode: ruleCode,
            description: description,
            severity: severity,
            suggestedAction: action,
            docsURL: docsURL,
            title: title
        )
    }
}

/// Configuration for the loan audit engine
public struct AuditPolicyConfig: Sendable {
    /// The policy values to use for auditing
    public let policy: AuditPolicy.Type
    
    /// Initialize with default policy
    public init() {
        self.policy = AuditPolicy.self
    }
    
    /// Initialize with custom policy
    public init(policy: AuditPolicy.Type) {
        self.policy = policy
    }
}

/// The main engine responsible for running audit rules and collecting results
public class LoanAuditEngine {
    private var rules: [AuditRule]
    private let policyConfig: AuditPolicyConfig
    
    /// Initialize with default rules and policy
    /// - Note: This initializer creates a standard set of audit rules with default thresholds
    public init() {
        self.rules = [
            ExcessiveForbearanceRule(),
            UnexplainedCapitalizationRule(),
            ExtendedNonPaymentRule(),
            HighInterestRateRule()
        ]
        self.policyConfig = AuditPolicyConfig()
    }
    
    /// Initialize with custom rules
    /// - Parameter rules: An array of AuditRule implementations to use
    public init(rules: [AuditRule]) {
        self.rules = rules
        self.policyConfig = AuditPolicyConfig()
    }
    
    /// Initialize with custom rules and policy
    /// - Parameters:
    ///   - policy: The policy configuration to use
    ///   - rules: An array of AuditRule implementations to use
    public init(policy: AuditPolicyConfig, rules: [AuditRule]? = nil) {
        self.policyConfig = policy
        if let customRules = rules {
            self.rules = customRules
        } else {
            self.rules = [
                ExcessiveForbearanceRule(),
                UnexplainedCapitalizationRule(),
                ExtendedNonPaymentRule(),
                HighInterestRateRule()
            ]
        }
    }
    
    /// Add a rule to the engine
    /// - Parameter rule: The rule to add
    public func addRule(_ rule: AuditRule) {
        rules.append(rule)
    }
    
    /// Run all rules against the provided loan details
    /// - Parameter loanDetails: The loan details to audit
    /// - Returns: Array of AuditResult objects for issues found
    public func performAudit(on loanDetails: LoanDetails) -> [AuditResult] {
        var results: [AuditResult] = []
        
        for rule in rules {
            if let result = rule.evaluate(loanDetails) {
                results.append(result)
            }
        }
        
        return results
    }
    
    /// Run specific rules by issue type
    /// - Parameters:
    ///   - loanDetails: The loan details to audit
    ///   - issueType: The specific issue type to filter for
    /// - Returns: Array of AuditResult objects matching the issue type
    public func performAudit(on loanDetails: LoanDetails, forIssue issueType: AuditIssue) -> [AuditResult] {
        return performAudit(on: loanDetails).filter { $0.issueType == issueType }
    }
    
    /// Asynchronously run all rules against the provided loan details
    /// - Parameter loanDetails: The loan details to audit
    /// - Returns: Array of AuditResult objects for issues found
    @available(iOS 13.0, macOS 10.15, *)
    public func performAuditAsync(on loanDetails: LoanDetails) async -> [AuditResult] {
        await withTaskGroup(of: AuditResult?.self) { group in
            var results: [AuditResult] = []
            
            // Add each rule to the task group for parallel execution
            for rule in rules {
                group.addTask {
                    return rule.evaluate(loanDetails)
                }
            }
            
            // Collect the results
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            
            return results
        }
    }
}

// MARK: - Testing Utilities
extension LoanDetails {
    /// Creates a fake loan details object with excessive forbearance for testing
    /// - Returns: A LoanDetails instance with predefined forbearance periods
    static func fakeForbearance(months: Int = 40) -> LoanDetails {
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .year, value: -5, to: today)!
        
        // Create a forbearance period with the specified duration
        let forbearanceStartDate = calendar.date(byAdding: .year, value: -3, to: today)!
        let forbearanceEndDate = calendar.date(byAdding: .month, value: months, to: forbearanceStartDate)!
        
        let forbearancePeriod = NonPaymentPeriod(
            startDate: forbearanceStartDate,
            endDate: forbearanceEndDate,
            type: .forbearance,
            reason: "Economic hardship"
        )
        
        // Create a payment history with a gap
        let paymentDates = stride(from: 0, to: 60, by: 1).compactMap { month in
            if month >= 36 && month <= 36 + months {
                return nil // No payments during forbearance
            }
            return calendar.date(byAdding: .month, value: -month, to: today)
        }
        
        let payments = paymentDates.map { date in
            Payment(date: date, amount: 350.0, type: .regular)
        }
        
        // Create test interest capitalization events
        let capEvents = [
            calendar.date(byAdding: .month, value: -24, to: today)!,
            forbearanceEndDate // This one should be explained by forbearance end
        ]
        
        return LoanDetails(
            servicerName: "TestServicer",
            loanID: "TEST-12345",
            startDate: startDate,
            endDate: calendar.date(byAdding: .year, value: 10, to: startDate),
            originalPrincipal: 25000.0,
            interestRate: 6.8,
            currentBalance: 22000.0,
            nonPaymentPeriods: [forbearancePeriod],
            paymentHistory: payments,
            interestCapitalizationEvents: capEvents
        )
    }
    
    /// Creates a fake loan details object with unexplained interest capitalization for testing
    /// - Returns: A LoanDetails instance with unexplained capitalization events
    static func fakeUnexplainedCapitalization(eventCount: Int = 3) -> LoanDetails {
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .year, value: -4, to: today)!
        
        // Create capitalization events without corresponding forbearance periods
        let capEvents = (0..<eventCount).map { i in
            calendar.date(byAdding: .month, value: -3 * i - 6, to: today)!
        }
        
        // Regular payment history
        let payments = stride(from: 0, to: 48, by: 1).compactMap { month in
            calendar.date(byAdding: .month, value: -month, to: today)
        }.map { date in
            Payment(date: date, amount: 350.0, type: .regular)
        }
        
        return LoanDetails(
            servicerName: "TestServicer",
            loanID: "TEST-12345",
            startDate: startDate,
            endDate: calendar.date(byAdding: .year, value: 10, to: startDate),
            originalPrincipal: 25000.0,
            interestRate: 5.8,
            currentBalance: 22000.0,
            nonPaymentPeriods: [], // No forbearance periods to explain capitalization
            paymentHistory: payments,
            interestCapitalizationEvents: capEvents
        )
    }
    
    /// Creates a fake loan details object with a high interest rate for testing
    /// - Returns: A LoanDetails instance with a high interest rate
    static func fakeHighInterestRate(rate: Double = 8.5) -> LoanDetails {
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .year, value: -3, to: today)!
        
        // Regular payment history
        let payments = stride(from: 0, to: 36, by: 1).compactMap { month in
            calendar.date(byAdding: .month, value: -month, to: today)
        }.map { date in
            Payment(date: date, amount: 400.0, type: .regular)
        }
        
        return LoanDetails(
            servicerName: "TestServicer",
            loanID: "TEST-12345",
            startDate: startDate,
            endDate: calendar.date(byAdding: .year, value: 10, to: startDate),
            originalPrincipal: 30000.0,
            interestRate: rate,
            currentBalance: 28000.0,
            nonPaymentPeriods: [],
            paymentHistory: payments,
            interestCapitalizationEvents: []
        )
    }
}