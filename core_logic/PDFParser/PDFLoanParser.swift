import Foundation
import PDFKit
import os.log

/// Errors that can occur during PDF parsing
public enum PDFParsingError: Error {
    case documentEmpty
    case unreadableDocument
    case missingRequiredField(String)
    case invalidFieldFormat(String)
    case unsupportedDocumentType
    case processingError(String)
}

/// Service provider types to help with targeted parsing
public enum LoanServicerType {
    case navient
    case nelnet
    case greatLakes
    case fedLoan
    case mohela
    case other
    
    /// Default patterns of text that identify the servicer in the PDF
    var identifierPatterns: [String] {
        switch self {
        case .navient:
            return ["navient", "navient.com"]
        case .nelnet:
            return ["nelnet", "nelnet.com"]
        case .greatLakes:
            return ["great lakes", "mygreatlakes"]
        case .fedLoan:
            return ["fedloan", "myfedloan"]
        case .mohela:
            return ["mohela"]
        case .other:
            return []
        }
    }
}

/// Utilities for working with dates in loan documents
public struct DateParsingUtils {
    /// Cache for date formatters to improve performance
    private static var formattersCache: [String: DateFormatter] = [:]
    
    /// Standard date formats commonly found in loan documents
    static let commonFormats: [String] = [
        "MM/dd/yyyy",
        "M/d/yyyy",
        "MM/dd/yy",
        "MMMM dd, yyyy",
        "MMM dd, yyyy",
        "MMMM yyyy",
        "MMM yyyy",
        "yyyy-MM-dd"
    ]
    
    /// Attempt to parse a date string using multiple common formats
    /// - Parameter dateString: The string containing a date
    /// - Returns: A Date if successful, nil otherwise
    static func parseDate(_ dateString: String) -> Date? {
        let trimmedString = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        for format in commonFormats {
            // Get or create a formatter for this format
            let formatter: DateFormatter
            if let cachedFormatter = formattersCache[format] {
                formatter = cachedFormatter
            } else {
                formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = format
                formattersCache[format] = formatter
            }
            
            if let date = formatter.date(from: trimmedString) {
                return date
            }
        }
        
        return nil
    }
    
    /// Extract all dates from a string using regex patterns
    /// - Parameter text: Text to search for dates
    /// - Returns: Array of extracted dates
    static func extractDatesFromText(_ text: String) -> [Date] {
        var dates: [Date] = []
        
        // Common date patterns
        let patterns = [
            #"\b\d{1,2}/\d{1,2}/\d{2,4}\b"#,                      // MM/DD/YYYY or M/D/YY
            #"\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4}\b"#, // Month DD, YYYY
            #"\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2},?\s+\d{4}\b"#, // MMM DD, YYYY
            #"\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4}\b"#, // Month YYYY
            #"\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{4}\b"#, // MMM YYYY
            #"\b\d{4}-\d{2}-\d{2}\b"#                             // YYYY-MM-DD
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
                let matches = regex.matches(in: text, options: [], range: nsRange)
                
                for match in matches {
                    if let range = Range(match.range, in: text) {
                        let dateString = String(text[range])
                        if let date = parseDate(dateString) {
                            dates.append(date)
                        }
                    }
                }
            } catch {
                os_log(.error, "PDFLoanParser regex error: %{public}@", String(describing: error))
            }
        }
        
        return dates
    }
}

/// Utilities for extracting currency and numeric values
public struct NumberParsingUtils {
    /// Extract a currency amount from text
    /// - Parameter text: Text containing a currency value
    /// - Returns: The extracted Double value, or nil if not found
    static func extractCurrencyAmount(from text: String) -> Double? {
        // Pattern matches currency with optional $ and parentheses, negative sign, with commas and optional decimal places
        let pattern = #"[\$\(]?\s*-?([0-9,]+(\.[0-9]{1,2})?)\)?"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, options: [], range: nsRange)
            
            if let match = matches.first, let valueRange = Range(match.range(at: 1), in: text) {
                let valueString = String(text[valueRange])
                    .replacingOccurrences(of: ",", with: "")
                
                // Handle parentheses for negative values
                if text.contains("(") && text.contains(")") {
                    return -Double(valueString)!
                }
                
                return Double(valueString)
            }
        } catch {
            os_log(.error, "PDFLoanParser regex error: %{public}@", String(describing: error))
        }
        
        return nil
    }
    
    /// Extract an interest rate from text
    /// - Parameter text: Text containing an interest rate
    /// - Returns: The extracted Double value, or nil if not found
    static func extractInterestRate(from text: String) -> Double? {
        // Pattern matches percentages like 5.25% or 6%
        let pattern = #"(\d+(\.\d+)?)%"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, options: [], range: nsRange)
            
            if let match = matches.first, let valueRange = Range(match.range(at: 1), in: text) {
                let valueString = String(text[valueRange])
                if let rate = Double(valueString) {
                    // Sanity check for realistic interest rates
                    if (0...20).contains(rate) {
                        return rate
                    }
                }
            }
        } catch {
            os_log(.error, "PDFLoanParser regex error: %{public}@", String(describing: error))
        }
        
        return nil
    }
}

/// The main parser responsible for extracting loan details from PDF documents
public class PDFLoanParser {
    // Configuration
    private let minLineLength = 5
    private let maxLinesForServicerIdentification = 30
    
    // Patterns for identifying document sections and fields
    private let loanDetailsPatterns = [
        "loan details", "loan information", "loan summary", "account summary"
    ]
    private let interestRatePatterns = [
        "interest rate", "rate", "apr", "annual percentage rate"
    ]
    private let balancePatterns = [
        "current balance", "outstanding balance", "principal balance", "current principal",
        "total balance", "balance"
    ]
    private let loanIDPatterns = [
        "loan #", "loan number", "account number", "id:", "loan id"
    ]
    private let nonPaymentKeywords = [
        "forbearance": "forbearance",
        "deferment": "deferment"
    ]
    private let paymentHistoryMarkers = [
        "payment history", "transaction history", "payment activity", 
        "transaction details", "payment record"
    ]
    private let capitalizationEventMarkers = [
        "capitalized interest", "interest capitalization", "capitalization event"
    ]
    
    /// Date range used to validate and filter extracted dates (to prevent dates far in future or past)
    private let validDateRange: ClosedRange<Date>
    
    public init() {
        // Set valid date range from 25 years ago to 30 years in future
        let calendar = Calendar.current
        let currentDate = Date()
        let pastDate = calendar.date(byAdding: .year, value: -25, to: currentDate)!
        let futureDate = calendar.date(byAdding: .year, value: 30, to: currentDate)!
        self.validDateRange = pastDate...futureDate
    }
    
    /// Extract loan details from a PDF document
    /// - Parameter pdf: The PDF document to parse
    /// - Returns: A structured LoanDetails object
    /// - Throws: PDFParsingError if extraction fails
    public func extractLoanDetails(from pdf: PDFDocument) async throws -> LoanDetails {
        // Validate PDF
        guard pdf.pageCount > 0 else {
            throw PDFParsingError.documentEmpty
        }
        
        // Extract text from all pages (offload to background thread)
        let documentText = try await Task.detached {
            self.normalizeDocument(pdf)
        }.value
        
        guard !documentText.isEmpty else {
            throw PDFParsingError.unreadableDocument
        }
        
        // Identify loan servicer
        let servicerName = try identifyLoanServicer(from: documentText)
        
        // Extract loan ID
        let loanID = try extractLoanID(from: documentText)
        
        // Extract interest rate
        let interestRate = try extractInterestRate(from: documentText)
        
        // Verify interest rate is in a valid range
        guard (0...20).contains(interestRate) else {
            throw PDFParsingError.invalidFieldFormat("interestRate")
        }
        
        // Extract current balance
        let currentBalance = try extractCurrentBalance(from: documentText)
        
        // Extract loan start date and estimate end date
        let (startDate, endDate) = try extractLoanDates(from: documentText)
        
        // Extract payment history
        let paymentHistory = extractPaymentHistory(from: documentText)
        
        // Extract non-payment periods
        let nonPaymentPeriods = extractNonPaymentPeriods(from: documentText)
        
        // Extract capitalization events
        let capitalizationEvents = extractCapitalizationEvents(from: documentText)
        
        // Estimate original principal if not explicitly found
        let originalPrincipal = extractOriginalPrincipal(from: documentText) ?? estimateOriginalPrincipal(
            currentBalance: currentBalance,
            paymentHistory: paymentHistory
        )
        
        // Create and return the loan details
        return LoanDetails(
            servicerName: servicerName,
            loanID: loanID,
            startDate: startDate,
            endDate: endDate,
            originalPrincipal: originalPrincipal,
            interestRate: interestRate,
            currentBalance: currentBalance,
            nonPaymentPeriods: nonPaymentPeriods,
            paymentHistory: paymentHistory,
            interestCapitalizationEvents: capitalizationEvents
        )
    }
    
    /// Extract text from PDF and normalize it for processing
    /// - Parameter pdf: The PDF document
    /// - Returns: Array of normalized text lines
    private func normalizeDocument(_ pdf: PDFDocument) -> [String] {
        var lines: [String] = []
        
        for pageIndex in 0..<pdf.pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }
            
            if let pageText = page.string {
                // Split into lines and normalize whitespace
                let pageLines = pageText.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.count >= minLineLength }
                
                lines.append(contentsOf: pageLines)
            }
        }
        
        return lines
    }
    
    /// Identify the loan servicer from document text
    /// - Parameter documentText: Extracted text lines from the document
    /// - Returns: The identified servicer name
    /// - Throws: PDFParsingError if servicer cannot be identified
    private func identifyLoanServicer(from documentText: [String]) throws -> String {
        // Check the header portion (first 30 lines) for servicer identifiers
        let headerText = documentText.prefix(maxLinesForServicerIdentification).joined(separator: " ").lowercased()
        
        // Check for known servicer patterns
        for servicerType in [LoanServicerType.navient, .nelnet, .greatLakes, .fedLoan, .mohela] {
            for pattern in servicerType.identifierPatterns {
                if headerText.contains(pattern.lowercased()) {
                    // Convert enum case to a nicely formatted string
                    switch servicerType {
                    case .navient: return "Navient"
                    case .nelnet: return "Nelnet"
                    case .greatLakes: return "Great Lakes"
                    case .fedLoan: return "FedLoan Servicing"
                    case .mohela: return "MOHELA"
                    case .other: break
                    }
                }
            }
        }
        
        // Look for company name patterns
        let companyPatterns = [
            #"([A-Z][a-z]+ ){1,3}(Servicing|Financial|Services|Corporation|Corp\.|Inc\.)"#,
            #"([A-Z][A-Za-z]+ ){1,2}Student Loan"#
        ]
        
        for line in documentText.prefix(maxLinesForServicerIdentification) {
            for pattern in companyPatterns {
                do {
                    let regex = try NSRegularExpression(pattern: pattern, options: [])
                    let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                    if let match = regex.firstMatch(in: line, options: [], range: nsRange),
                       let range = Range(match.range, in: line) {
                        let company = String(line[range])
                        if company.count > 4 { // Ensure it's a substantial name
                            return company
                        }
                    }
                } catch {
                    os_log(.error, "PDFLoanParser regex error: %{public}@", String(describing: error))
                    continue
                }
            }
        }
        
        // If unable to identify a servicer, check for any company-like name
        for line in documentText.prefix(maxLinesForServicerIdentification) {
            if line.contains(" Loan ") || line.contains("Servic") {
                // Extract potential servicer name
                let words = line.components(separatedBy: .whitespaces)
                    .filter { $0.first?.isUppercase == true && $0.count > 2 }
                
                if let company = words.first, company.count > 3 {
                    return company
                }
            }
        }
        
        throw PDFParsingError.missingRequiredField("Loan Servicer")
    }
    
    /// Extract the loan ID from document text
    /// - Parameter documentText: Extracted text lines from the document
    /// - Returns: The identified loan ID
    /// - Throws: PDFParsingError if loan ID cannot be found
    private func extractLoanID(from documentText: [String]) throws -> String {
        for line in documentText {
            let lowerLine = line.lowercased()
            
            for pattern in loanIDPatterns {
                if lowerLine.contains(pattern) {
                    // Extract ID following the pattern
                    if let range = lowerLine.range(of: pattern) {
                        let potentialID = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Extract alphanumeric sequence
                        if let idMatch = potentialID.range(of: #"[a-zA-Z0-9-]{4,}"#, options: .regularExpression) {
                            let id = String(potentialID[idMatch])
                            if id.count >= 4 { // Reasonable minimum length for an ID
                                return id
                            }
                        }
                    }
                }
            }
        }
        
        // Fallback to finding any pattern that looks like an ID
        let idPatterns = [
            #"Loan ID:?\s*([A-Z0-9-]{4,})"#,
            #"Account #:?\s*([A-Z0-9-]{4,})"#,
            #"Loan\s*#:?\s*([A-Z0-9-]{4,})"#,
            #"ID:?\s*([A-Z0-9-]{4,})"#,
            #"Loan Number:?\s*([A-Z0-9-]{4,})"#
        ]
        
        for pattern in idPatterns {
            if let id = extractTextWithRegex(pattern: pattern, from: documentText.joined(separator: " ")) {
                return id
            }
        }
        
        // Generate a placeholder ID if we can't find one
        return "UNKNOWN-" + String(Int.random(in: 10000...99999))
    }
    
    /// Extract the interest rate from document text
    /// - Parameter documentText: Extracted text lines from the document
    /// - Returns: The interest rate as a Double
    /// - Throws: PDFParsingError if interest rate cannot be found
    private func extractInterestRate(from documentText: [String]) throws -> Double {
        // First look for interest rate markers
        for line in documentText {
            let lowerLine = line.lowercased()
            
            for pattern in interestRatePatterns {
                if lowerLine.contains(pattern) {
                    if let rate = NumberParsingUtils.extractInterestRate(from: line) {
                        return rate
                    }
                }
            }
        }
        
        // Second, look for percentage values near interest keywords
        let interestContext = documentText.filter { line in
            let lowerLine = line.lowercased()
            return interestRatePatterns.contains { lowerLine.contains($0) }
        }
        
        for line in interestContext {
            if let rate = NumberParsingUtils.extractInterestRate(from: line) {
                return rate
            }
        }
        
        // Final attempt with broader regex pattern
        let pattern = #"interest\s+rate.*?(\d+\.\d+)%"#
        if let rateStr = extractTextWithRegex(pattern: pattern, from: documentText.joined(separator: " ")),
           let rate = Double(rateStr), (0...20).contains(rate) {
            return rate
        }
        
        throw PDFParsingError.missingRequiredField("Interest Rate")
    }
    
    /// Extract the current balance from document text
    /// - Parameter documentText: Extracted text lines from the document
    /// - Returns: The current balance as a Double
    /// - Throws: PDFParsingError if current balance cannot be found
    private func extractCurrentBalance(from documentText: [String]) throws -> Double {
        // First look for balance keywords
        for line in documentText {
            let lowerLine = line.lowercased()
            
            for pattern in balancePatterns {
                if lowerLine.contains(pattern) {
                    if let balance = NumberParsingUtils.extractCurrencyAmount(from: line) {
                        // Validate reasonableness (typical loan amounts)
                        if balance > 100.0 && balance < 500000.0 {
                            return balance
                        }
                    }
                }
            }
        }
        
        // Second, search within sections labeled as summaries or details
        let summaryLines = documentText.filter { line in
            let lowerLine = line.lowercased()
            return loanDetailsPatterns.contains { lowerLine.contains($0) }
        }
        
        let extendedSummary: [String] = summaryLines.flatMap { summaryLine in
            let index = documentText.firstIndex(of: summaryLine) ?? 0
            return Array(documentText[index..<min(index + 10, documentText.count)])
        }
        
        for line in extendedSummary {
            if let balance = NumberParsingUtils.extractCurrencyAmount(from: line) {
                if balance > 100.0 && balance < 500000.0 {
                    return balance
                }
            }
        }
        
        // Final attempt with broader regex pattern
        let pattern = #"(current|outstanding|total|principal)\s+balance.{0,20}\$(\d{1,3}(,\d{3})*(\.\d{2})?)"#
        if let balanceStr = extractTextWithRegex(pattern: pattern, from: documentText.joined(separator: " ")),
           let balance = Double(balanceStr.replacingOccurrences(of: ",", with: "")),
           balance > 100.0 && balance < 500000.0 {
            return balance
        }
        
        throw PDFParsingError.missingRequiredField("Current Balance")
    }
    
    /// Extract the loan start date and estimated end date
    /// - Parameter documentText: Extracted text lines from the document
    /// - Returns: Tuple of (startDate, endDate?)
    /// - Throws: PDFParsingError if start date cannot be found
    private func extractLoanDates(from documentText: [String]) throws -> (Date, Date?) {
        var possibleStartDate: Date?
        var possibleEndDate: Date?
        
        let startDatePatterns = [
            "loan date", "disbursement date", "start date", "originated", "issue date"
        ]
        
        let endDatePatterns = [
            "maturity date", "payoff date", "term end", "end date", "final payment date"
        ]
        
        // Search for explicit date markers
        for line in documentText {
            let lowerLine = line.lowercased()
            
            // Check for start date patterns
            for pattern in startDatePatterns {
                if lowerLine.contains(pattern) {
                    if let dates = DateParsingUtils.extractDatesFromText(line).filter({ validDateRange.contains($0) }).first {
                        possibleStartDate = dates
                    }
                }
            }
            
            // Check for end date patterns
            for pattern in endDatePatterns {
                if lowerLine.contains(pattern) {
                    if let dates = DateParsingUtils.extractDatesFromText(line).filter({ validDateRange.contains($0) }).first {
                        possibleEndDate = dates
                    }
                }
            }
        }
        
        // If start date not found, look for earliest transaction or document date
        if possibleStartDate == nil {
            let allDates = documentText.flatMap { DateParsingUtils.extractDatesFromText($0) }
                .filter { validDateRange.contains($0) }
                .sorted()
            
            if let earliestDate = allDates.first {
                possibleStartDate = earliestDate
            }
        }
        
        // Ensure we have a start date
        guard let startDate = possibleStartDate else {
            throw PDFParsingError.missingRequiredField("Loan Start Date")
        }
        
        // If no end date found, estimate based on typical loan term (10 years from start)
        if possibleEndDate == nil {
            let calendar = Calendar.current
            possibleEndDate = calendar.date(byAdding: .year, value: 10, to: startDate)
        }
        
        return (startDate, possibleEndDate)
    }
    
    /// Extract payment history from document text
    /// - Parameter documentText: Extracted text lines from the document
    /// - Returns: Array of Payment objects
    private func extractPaymentHistory(from documentText: [String]) -> [Payment] {
        var payments: [Payment] = []
        var inPaymentSection = false
        var paymentSectionText: [String] = []
        
        // Find the payment history section
        for line in documentText {
            let lowerLine = line.lowercased()
            
            // Check if we're entering a payment section
            if !inPaymentSection && paymentHistoryMarkers.contains(where: { lowerLine.contains($0) }) {
                inPaymentSection = true
                continue
            }
            
            // If we're in a payment section, collect the text
            if inPaymentSection {
                // Check if we're exiting the section (e.g., a new section heading)
                if linesIndicatesNewSection(line) && paymentSectionText.count > 5 {
                    inPaymentSection = false
                    break
                }
                
                paymentSectionText.append(line)
            }
        }
        
        // If we didn't find a clear payment section, use the whole document
        if paymentSectionText.isEmpty {
            paymentSectionText = documentText
        }
        
        // Patterns for recognizing payment entries
        let paymentPatterns = [
            #"(payment|paid|received).{0,30}\$(\d{1,3}(,\d{3})*(\.\d{2})?)"#,
            #"(\d{1,2}/\d{1,2}/\d{2,4}).{0,30}\$(\d{1,3}(,\d{3})*(\.\d{2})?)"#
        ]
        
        // Extract payments using patterns
        for line in paymentSectionText {
            let dates = DateParsingUtils.extractDatesFromText(line).filter { validDateRange.contains($0) }
            let amount = NumberParsingUtils.extractCurrencyAmount(from: line)
            
            // Valid payment requires both date and amount
            if let date = dates.first, let paymentAmount = amount {
                let paymentType: Payment.PaymentType = determinePaymentType(from: line)
                payments.append(Payment(date: date, amount: paymentAmount, type: paymentType))
            }
        }
        
        // Deduplicate payments by comparing dates (within 1 day) and amounts
        var uniquePayments: [Payment] = []
        for payment in payments {
            let isDuplicate = uniquePayments.contains { existingPayment in
                let sameAmount = abs(existingPayment.amount - payment.amount) < 0.01
                let sameDate = abs(existingPayment.date.timeIntervalSince(payment.date)) < 86400 // 1 day
                return sameAmount && sameDate
            }
            
            if !isDuplicate {
                uniquePayments.append(payment)
            }
        }
        
        return uniquePayments.sorted { $0.date < $1.date }
    }
    
    /// Determine payment type from context
    /// - Parameter lineText: The line of text containing payment information
    /// - Returns: The payment type
    private func determinePaymentType(from lineText: String) -> Payment.PaymentType {
        let lowerLine = lineText.lowercased()
        
        if lowerLine.contains("principal") && !lowerLine.contains("interest") {
            return .extraPrincipal
        } else if lowerLine.contains("interest only") || (lowerLine.contains("interest") && !lowerLine.contains("principal")) {
            return .interestOnly
        } else if lowerLine.contains("fee") || lowerLine.contains("charge") || lowerLine.contains("penalty") {
            return .fee
        } else {
            return .regular
        }
    }
    
    /// Extract non-payment periods (forbearance/deferment) from document text
    /// - Parameter documentText: Extracted text lines from the document
    /// - Returns: Array of NonPaymentPeriod objects
    private func extractNonPaymentPeriods(from documentText: [String]) -> [NonPaymentPeriod] {
        var nonPaymentPeriods: [NonPaymentPeriod] = []
        
        // Join adjacent lines to ensure we capture multi-line entries
        let joinedText = documentText.joined(separator: " ")
        
        // Pattern for extracting forbearance or deferment periods with dates
        let patterns = [
            #"(forbearance|deferment).{0,50}?(\d{1,2}/\d{1,2}/\d{2,4}).{0,20}(to|through|until).{0,20}(\d{1,2}/\d{1,2}/\d{2,4})"#,
            #"(forbearance|deferment).{0,50}?from.{0,20}(\d{1,2}/\d{1,2}/\d{2,4}).{0,20}(to|through|until).{0,20}(\d{1,2}/\d{1,2}/\d{2,4})"#,
            #"(\d{1,2}/\d{1,2}/\d{2,4}).{0,20}(to|through|until).{0,20}(\d{1,2}/\d{1,2}/\d{2,4}).{0,50}?(forbearance|deferment)"#
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let nsRange = NSRange(joinedText.startIndex..<joinedText.endIndex, in: joinedText)
                let matches = regex.matches(in: joinedText, options: [], range: nsRange)
                
                for match in matches {
                    if match.numberOfRanges >= 5,
                       let typeRange = Range(match.range(at: 1), in: joinedText),
                       let startDateRange = Range(match.range(at: 2), in: joinedText),
                       let endDateRange = Range(match.range(at: 4), in: joinedText) {
                        
                        let typeText = String(joinedText[typeRange]).lowercased()
                        let startDateText = String(joinedText[startDateRange])
                        let endDateText = String(joinedText[endDateRange])
                        
                        if let startDate = DateParsingUtils.parseDate(startDateText),
                           let endDate = DateParsingUtils.parseDate(endDateText),
                           validDateRange.contains(startDate),
                           validDateRange.contains(endDate) {
                            
                            let type: NonPaymentPeriod.NonPaymentType = typeText.contains("forbearance") ? .forbearance : .deferment
                            let reason = extractReasonText(near: typeText, in: joinedText)
                            
                            nonPaymentPeriods.append(NonPaymentPeriod(
                                startDate: startDate,
                                endDate: endDate,
                                type: type,
                                reason: reason
                            ))
                        }
                    }
                }
            } catch {
                os_log(.error, "PDFLoanParser regex error: %{public}@", String(describing: error))
            }
        }
        
        // Look for standalone forbearance/deferment sections
        var inNonPaymentSection = false
        var nonPaymentType: NonPaymentPeriod.NonPaymentType = .forbearance
        var nonPaymentSectionText: [String] = []
        
        for line in documentText {
            let lowerLine = line.lowercased()
            
            // Check for non-payment section markers
            if !inNonPaymentSection && (lowerLine.contains("forbearance") || lowerLine.contains("deferment")) {
                inNonPaymentSection = true
                nonPaymentType = lowerLine.contains("forbearance") ? .forbearance : .deferment
                nonPaymentSectionText.append(line)
                continue
            }
            
            // Collect text within the section
            if inNonPaymentSection {
                // Check if we're exiting the section
                if linesIndicatesNewSection(line) && nonPaymentSectionText.count > 2 {
                    // Process this section for date ranges
                    let sectionDates = nonPaymentSectionText.flatMap { DateParsingUtils.extractDatesFromText($0) }
                                                              .filter { validDateRange.contains($0) }
                                                              .sorted()
                    
                    // If we have an even number of dates, pair them as start/end
                    if sectionDates.count >= 2 {
                        for i in stride(from: 0, to: sectionDates.count - 1, by: 2) {
                            let startDate = sectionDates[i]
                            let endDate = sectionDates[i + 1]
                            
                            // Only add if endDate is after startDate and within a reasonable timeframe
                            if endDate > startDate && endDate.timeIntervalSince(startDate) < 60 * 86400 { // 60 days max
                                let reason = extractReasonText(near: nonPaymentType == .forbearance ? "forbearance" : "deferment",
                                                              in: nonPaymentSectionText.joined(separator: " "))
                                
                                nonPaymentPeriods.append(NonPaymentPeriod(
                                    startDate: startDate,
                                    endDate: endDate,
                                    type: nonPaymentType,
                                    reason: reason
                                ))
                            }
                        }
                    }
                    
                    // Reset for next section
                    inNonPaymentSection = false
                    nonPaymentSectionText = []
                } else {
                    nonPaymentSectionText.append(line)
                }
            }
        }
        
        // Deduplicate non-payment periods by comparing dates (within 3 days) and types
        var uniquePeriods: [NonPaymentPeriod] = []
        for period in nonPaymentPeriods {
            let isDuplicate = uniquePeriods.contains { existingPeriod in
                let sameType = existingPeriod.type == period.type
                let sameStartDate = abs(existingPeriod.startDate.timeIntervalSince(period.startDate)) < 3 * 86400 // 3 days
                let sameEndDate = abs(existingPeriod.endDate.timeIntervalSince(period.endDate)) < 3 * 86400 // 3 days
                return sameType && sameStartDate && sameEndDate
            }
            
            if !isDuplicate {
                uniquePeriods.append(period)
            }
        }
        
        return uniquePeriods.sorted { $0.startDate < $1.startDate }
    }
    
    /// Extract capitalization events from document text
    /// - Parameter documentText: Extracted text lines from the document
    /// - Returns: Array of capitalization event dates
    private func extractCapitalizationEvents(from documentText: [String]) -> [Date] {
        var capitalizationEvents: [Date] = []
        
        // Join text to look for multi-line mentions
        let joinedText = documentText.joined(separator: " ")
        
        // Look for capitalization event markers
        for marker in capitalizationEventMarkers {
            if joinedText.lowercased().contains(marker) {
                // Find nearby date mentions
                let markerRange = joinedText.lowercased().range(of: marker)!
                let beforeMarker = String(joinedText[..<markerRange.lowerBound])
                let afterMarker = String(joinedText[markerRange.upperBound...])
                
                // Look in nearby context (50 chars before and after)
                let beforeContext = String(beforeMarker.suffix(min(beforeMarker.count, 100)))
                let afterContext = String(afterMarker.prefix(min(afterMarker.count, 100)))
                let context = beforeContext + marker + afterContext
                
                // Extract dates from this context
                let contextDates = DateParsingUtils.extractDatesFromText(context).filter { validDateRange.contains($0) }
                capitalizationEvents.append(contentsOf: contextDates)
            }
        }
        
        // Also look for specific capitalization patterns
        let capitalizationPatterns = [
            #"interest.{0,10}capitalized.{0,30}(\d{1,2}/\d{1,2}/\d{2,4})"#,
            #"(\d{1,2}/\d{1,2}/\d{2,4}).{0,30}interest.{0,10}capitalized"#,
            #"capitalization.{0,10}date.{0,10}(\d{1,2}/\d{1,2}/\d{2,4})"#
        ]
        
        for pattern in capitalizationPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let nsRange = NSRange(joinedText.startIndex..<joinedText.endIndex, in: joinedText)
                let matches = regex.matches(in: joinedText, options: [], range: nsRange)
                
                for match in matches {
                    if match.numberOfRanges >= 2,
                       let dateRange = Range(match.range(at: 1), in: joinedText) {
                        let dateText = String(joinedText[dateRange])
                        if let date = DateParsingUtils.parseDate(dateText), validDateRange.contains(date) {
                            capitalizationEvents.append(date)
                        }
                    }
                }
            } catch {
                os_log(.error, "PDFLoanParser regex error: %{public}@", String(describing: error))
            }
        }
        
        // Look for capitalization amounts (where interest is added to principal)
        let amountPatterns = [
            #"(capitalized|capitalization).{0,30}\$(\d{1,3}(,\d{3})*(\.\d{2})?)"#
        ]
        
        for pattern in amountPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let nsRange = NSRange(joinedText.startIndex..<joinedText.endIndex, in: joinedText)
                let matches = regex.matches(in: joinedText, options: [], range: nsRange)
                
                for match in matches {
                    // Try to find date near this capitalization amount
                    if let range = Range(match.range, in: joinedText) {
                        let context = joinedText.distance(from: joinedText.startIndex, to: range.lowerBound) > 50 
                            ? String(joinedText[joinedText.index(range.lowerBound, offsetBy: -50)..<range.upperBound])
                            : String(joinedText[joinedText.startIndex..<range.upperBound])
                        
                        let nearbyDates = DateParsingUtils.extractDatesFromText(context).filter { validDateRange.contains($0) }
                        capitalizationEvents.append(contentsOf: nearbyDates)
                    }
                }
            } catch {
                os_log(.error, "PDFLoanParser regex error: %{public}@", String(describing: error))
            }
        }
        
        // Deduplicate dates (within 1 day)
        var uniqueDates: [Date] = []
        for date in capitalizationEvents {
            let isDuplicate = uniqueDates.contains { existingDate in
                abs(existingDate.timeIntervalSince(date)) < 86400 // 1 day
            }
            
            if !isDuplicate {
                uniqueDates.append(date)
            }
        }
        
        return uniqueDates.sorted()
    }
    
    /// Extract the original principal amount from document text
    /// - Parameter documentText: Extracted text lines from the document
    /// - Returns: The original principal if found, nil otherwise
    private func extractOriginalPrincipal(from documentText: [String]) -> Double? {
        let principalPatterns = [
            "original principal", "initial principal", "original loan amount", 
            "principal balance at disbursal", "loan amount"
        ]
        
        // Look for original principal in document text
        for line in documentText {
            let lowerLine = line.lowercased()
            
            for pattern in principalPatterns {
                if lowerLine.contains(pattern) {
                    if let amount = NumberParsingUtils.extractCurrencyAmount(from: line) {
                        // Validate reasonableness (typical loan amounts)
                        if amount > 100.0 && amount < 500000.0 {
                            return amount
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Estimate original principal based on current balance and payment history
    /// - Parameters:
    ///   - currentBalance: The current loan balance
    ///   - paymentHistory: The history of payments
    /// - Returns: Estimated original principal
    private func estimateOriginalPrincipal(currentBalance: Double, paymentHistory: [Payment]) -> Double {
        // Add current balance with total of all payments made (simple estimate)
        let totalPayments = paymentHistory.reduce(0.0) { $0 + $1.amount }
        let estimatedPrincipal = currentBalance + totalPayments * 0.8 // Assuming ~20% went to interest
        
        // Round to nearest $500
        return round(estimatedPrincipal / 500) * 500
    }
    
    /// Helper to extract text using a regex pattern
    /// - Parameters:
    ///   - pattern: The regex pattern to use
    ///   - text: The text to search
    /// - Returns: First capturing group match, or nil if none found
    private func extractTextWithRegex(pattern: String, from text: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            
            if let match = regex.firstMatch(in: text, options: [], range: nsRange),
               match.numberOfRanges >= 2,
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        } catch {
            os_log(.error, "PDFLoanParser regex error: %{public}@", String(describing: error))
        }
        
        return nil
    }
    
    /// Determine if a line indicates the start of a new section
    /// - Parameter line: The line to check
    /// - Returns: True if the line likely indicates a new section
    private func linesIndicatesNewSection(_ line: String) -> Bool {
        // Typically section headings are short, capitalized, and often end with a colon
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Empty or very short lines don't indicate a section
        if trimmedLine.count < 3 {
            return false
        }
        
        // Check for section-like characteristics
        let hasColon = trimmedLine.contains(":")
        let isAllCaps = trimmedLine == trimmedLine.uppercased() && trimmedLine.count > 4
        let startsWithCapital = trimmedLine.first?.isUppercase == true
        let isShort = trimmedLine.count < 30
        
        // Various combinations that suggest a section heading
        return (hasColon && startsWithCapital && isShort) ||
               (isAllCaps && isShort) ||
               trimmedLine.hasPrefix("Section") ||
               trimmedLine.hasPrefix("#") ||
               (startsWithCapital && isShort && trimmedLine.hasSuffix(":"))
    }
    
    /// Extract reason text near a keyword
    /// - Parameters:
    ///   - keyword: The keyword to look near
    ///   - text: The text to search in
    /// - Returns: The likely reason text, or nil if none found
    private func extractReasonText(near keyword: String, in text: String) -> String? {
        let reasonPatterns = [
            "reason:\\s*([^\\n.]{3,50})",
            "due to\\s*([^\\n.]{3,50})",
            "reason for\\s*\(keyword)\\s*:?\\s*([^\\n.]{3,50})",
            "\(keyword)\\s*for\\s*([^\\n.]{3,50})",
            "\(keyword)\\s*-\\s*([^\\n.]{3,50})"
        ]
        
        for pattern in reasonPatterns {
            if let reasonText = extractTextWithRegex(pattern: pattern, from: text.lowercased()) {
                let reason = reasonText.trimmingCharacters(in: .whitespacesAndNewlines)
                if reason.count >= 3 { // Sensible minimum
                    return reason.capitalized
                }
            }
        }
        
        return nil
    }
}