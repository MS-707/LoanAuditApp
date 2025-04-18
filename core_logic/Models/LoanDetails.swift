import Foundation

/// Complete details of a student loan, including payment history and non-payment periods
public struct LoanDetails: Codable, Equatable, Sendable {
    // MARK: - Basic Loan Information
    
    /// The name of the loan servicer
    public let servicerName: String
    
    /// The loan or account number
    public var accountNumber: String?
    
    /// The annual interest rate as a percentage (e.g., 5.25 for 5.25%)
    public var interestRate: Double
    
    /// The original principal amount of the loan in dollars
    public var originalPrincipal: Double?
    
    /// The current outstanding balance of the loan in dollars
    public var currentBalance: Double
    
    /// The date when the loan was originated or first disbursed
    public var loanStartDate: Date?
    
    /// The expected payoff date for the loan
    public var loanEndDate: Date?
    
    // MARK: - Non-payment Periods
    
    /// Represents a period of forbearance or deferment
    public struct NonPaymentPeriod: Codable, Equatable {
        /// The type of non-payment period
        public enum Kind: String, Codable {
            case forbearance
            case deferment
            case other
        }
        
        /// The type of non-payment period
        public let kind: Kind
        
        /// The start date of the non-payment period
        public let startDate: Date
        
        /// The end date of the non-payment period
        public let endDate: Date
        
        /// Calculates the duration of this period in months
        public var durationInMonths: Int {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.month], from: startDate, to: endDate)
            return components.month ?? 0
        }
    }
    
    /// List of non-payment periods (forbearance, deferment, etc.)
    public var nonPaymentPeriods: [NonPaymentPeriod] = []
    
    // MARK: - Payment History
    
    /// Represents an individual payment made on the loan
    public struct PaymentRecord: Codable, Equatable {
        /// The date of the payment
        public let date: Date
        
        /// The amount of the payment in dollars (negative values represent refunds)
        public let amount: Double
    }
    
    /// List of all payments made on the loan
    public var paymentHistory: [PaymentRecord] = []
    
    // MARK: - Interest Capitalization
    
    /// Dates when interest was capitalized (added to principal)
    public var interestCapitalizationEvents: [Date] = []
    
    // MARK: - Computed Properties
    
    /// Returns the total duration of all forbearance periods in months
    internal func totalForbearanceDuration() -> Int {
        return nonPaymentPeriods
            .filter { $0.kind == .forbearance }
            .reduce(0) { $0 + $1.durationInMonths }
    }
    
    /// Finds periods of non-payment that don't have a corresponding forbearance or deferment record
    /// - Parameter minimumMonths: The minimum gap in months to be considered significant
    /// - Returns: Array of tuples with start date, end date, and duration of unexplained gaps
    internal func findUnexplainedNonPaymentPeriods(minimumMonths: Int = 2) -> [(start: Date, end: Date, duration: TimeInterval)] {
        guard !paymentHistory.isEmpty else { return [] }
        
        // Sort payments by date
        let sortedPayments = paymentHistory.sorted(by: { $0.date < $1.date })
        var unexplainedPeriods: [(start: Date, end: Date, duration: TimeInterval)] = []
        
        // Check each pair of consecutive payments
        for i in 0..<(sortedPayments.count - 1) {
            let currentPaymentDate = sortedPayments[i].date
            let nextPaymentDate = sortedPayments[i + 1].date
            
            // Calculate gap between payments
            let calendar = Calendar.current
            let components = calendar.dateComponents([.month], from: currentPaymentDate, to: nextPaymentDate)
            
            if let months = components.month, months >= minimumMonths {
                // Check if this period overlaps with any forbearance or deferment period
                let isExplained = nonPaymentPeriods.contains { period in
                    let periodStartDate = period.startDate
                    let periodEndDate = period.endDate
                    
                    // Check for overlap with non-payment period
                    return (currentPaymentDate <= periodEndDate && nextPaymentDate >= periodStartDate)
                }
                
                if !isExplained {
                    let duration = nextPaymentDate.timeIntervalSince(currentPaymentDate)
                    unexplainedPeriods.append((start: currentPaymentDate, end: nextPaymentDate, duration: duration))
                }
            }
        }
        
        return unexplainedPeriods
    }
    
    /// Calculates the total amount paid on the loan
    /// - Returns: The sum of all payment amounts
    internal func totalPaid() -> Double {
        return paymentHistory.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Test Support
#if DEBUG
extension LoanDetails {
    /// Creates an example loan for testing purposes
    public static func example() -> LoanDetails {
        let calendar = Calendar.current
        let today = Date()
        let loanStartDate = calendar.date(byAdding: .year, value: -5, to: today)!
        let loanEndDate = calendar.date(byAdding: .year, value: 5, to: today)!
        
        // Create sample payment history
        let paymentHistory = stride(from: -48, to: 0, by: 1).compactMap { monthOffset in
            calendar.date(byAdding: .month, value: monthOffset, to: today)
        }.map { date in
            PaymentRecord(date: date, amount: 350.00)
        }
        
        // Create sample forbearance period
        let forbearanceStart = calendar.date(byAdding: .month, value: -24, to: today)!
        let forbearanceEnd = calendar.date(byAdding: .month, value: -18, to: today)!
        let forbearancePeriod = NonPaymentPeriod(
            kind: .forbearance,
            startDate: forbearanceStart,
            endDate: forbearanceEnd
        )
        
        // Create sample deferment period
        let defermentStart = calendar.date(byAdding: .month, value: -12, to: today)!
        let defermentEnd = calendar.date(byAdding: .month, value: -10, to: today)!
        let defermentPeriod = NonPaymentPeriod(
            kind: .deferment,
            startDate: defermentStart,
            endDate: defermentEnd
        )
        
        // Create sample capitalization events (typically at end of forbearance/deferment)
        let capitalizationEvents = [
            forbearanceEnd,
            defermentEnd
        ]
        
        // Create and return the example loan
        var loan = LoanDetails(
            servicerName: "ExampleServicer",
            accountNumber: "LOAN-12345",
            interestRate: 5.25,
            originalPrincipal: 25000.00,
            currentBalance: 15000.00,
            loanStartDate: loanStartDate,
            loanEndDate: loanEndDate
        )
        
        loan.paymentHistory = paymentHistory
        loan.nonPaymentPeriods = [forbearancePeriod, defermentPeriod]
        loan.interestCapitalizationEvents = capitalizationEvents
        
        return loan
    }
}
#endif