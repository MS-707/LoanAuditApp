import Foundation

/// Represents a payment made on a loan
public struct Payment {
    let date: Date
    let amount: Double
    let type: PaymentType
    
    public enum PaymentType {
        case regular
        case extraPrincipal
        case interestOnly
        case fee
    }
}

/// Represents a period of forbearance or deferment
public struct NonPaymentPeriod {
    let startDate: Date
    let endDate: Date
    let type: NonPaymentType
    let reason: String?
    
    public enum NonPaymentType {
        case forbearance
        case deferment
    }
    
    var durationInMonths: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: startDate, to: endDate)
        return components.month ?? 0
    }
}

/// Complete details of a student loan
public struct LoanDetails {
    let servicerName: String
    let loanID: String
    let startDate: Date
    let endDate: Date?
    let originalPrincipal: Double
    let interestRate: Double
    let currentBalance: Double
    let nonPaymentPeriods: [NonPaymentPeriod]
    let paymentHistory: [Payment]
    let interestCapitalizationEvents: [Date]
    
    /// Returns the total duration of all forbearance periods in months
    func totalForbearanceDuration() -> Int {
        return nonPaymentPeriods
            .filter { $0.type == .forbearance }
            .reduce(0) { $0 + $1.durationInMonths }
    }
    
    /// Returns the total duration of all deferment periods in months
    func totalDefermentDuration() -> Int {
        return nonPaymentPeriods
            .filter { $0.type == .deferment }
            .reduce(0) { $0 + $1.durationInMonths }
    }
    
    /// Finds periods of non-payment that don't have a corresponding forbearance or deferment record
    func findUnexplainedNonPaymentPeriods(minimumMonths: Int = 2) -> [DateInterval] {
        guard !paymentHistory.isEmpty else { return [] }
        
        // Sort payments by date
        let sortedPayments = paymentHistory.sorted(by: { $0.date < $1.date })
        var unexplainedPeriods: [DateInterval] = []
        
        // Check each pair of consecutive payments
        for i in 0..<(sortedPayments.count - 1) {
            let currentPaymentDate = sortedPayments[i].date
            let nextPaymentDate = sortedPayments[i + 1].date
            
            // Calculate gap between payments
            let calendar = Calendar.current
            let components = calendar.dateComponents([.month], from: currentPaymentDate, to: nextPaymentDate)
            
            if let months = components.month, months >= minimumMonths {
                // Check if this period overlaps with any forbearance or deferment period
                let interval = DateInterval(start: currentPaymentDate, end: nextPaymentDate)
                let isExplained = nonPaymentPeriods.contains { period in
                    let periodInterval = DateInterval(start: period.startDate, end: period.endDate)
                    return interval.intersects(periodInterval)
                }
                
                if !isExplained {
                    unexplainedPeriods.append(interval)
                }
            }
        }
        
        return unexplainedPeriods
    }
}