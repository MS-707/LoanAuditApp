import SwiftUI
import Combine
import PDFKit
import UniformTypeIdentifiers

// MARK: - Data Models

/// Basic loan details structure
struct SimpleLoanDetails {
    var servicerName: String = "Unknown Servicer"
    var accountNumber: String?
    var interestRate: Double?
    var currentBalance: Double?
    var loanStartDate: Date?
    var forbearancePeriods: [(start: Date, end: Date)] = []
    var paymentHistory: [(date: Date, amount: Double)] = []
    
    /// Creates a string summary of the loan details
    func summary() -> String {
        var result = "Loan Details Summary:\n"
        result += "• Servicer: \(servicerName)\n"
        
        if let accountNumber = accountNumber {
            result += "• Account: \(accountNumber)\n"
        }
        
        if let interestRate = interestRate {
            result += "• Interest Rate: \(String(format: "%.2f%%", interestRate))\n"
        }
        
        if let currentBalance = currentBalance {
            result += "• Current Balance: $\(String(format: "%.2f", currentBalance))\n"
        }
        
        if let loanStartDate = loanStartDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            result += "• Start Date: \(dateFormatter.string(from: loanStartDate))\n"
        }
        
        result += "• Found \(forbearancePeriods.count) forbearance periods\n"
        result += "• Found \(paymentHistory.count) payment records"
        
        return result
    }
}

/// Simple errors that can occur during document parsing
enum DocumentParsingError: Error, LocalizedError {
    case documentEmpty
    case unreadableDocument
    case missingRequiredData
    case unsupportedFileType
    case invalidCSVFormat
    
    var errorDescription: String? {
        switch self {
        case .documentEmpty:
            return "The selected document appears to be empty."
        case .unreadableDocument:
            return "Unable to read the document. It may be corrupted or password-protected."
        case .missingRequiredData:
            return "Unable to find basic loan information in this document."
        case .unsupportedFileType:
            return "This file type is not supported. Please use a PDF, CSV, or text file."
        case .invalidCSVFormat:
            return "The CSV file format is invalid or missing required columns."
        }
    }
}

/// A representation of audit results
struct AuditResult: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let severity: AuditSeverity
    let suggestedAction: String
    let issueType: AuditIssueType
}

/// Severity levels for audit findings
enum AuditSeverity {
    case low, moderate, high, critical
    
    var color: Color {
        switch self {
        case .low:       return Color(.systemYellow)
        case .moderate:  return Color(.systemOrange)
        case .high:      return Color(.systemRed)
        case .critical:  return Color(.systemRed).opacity(0.8)
        }
    }
    
    var accessibilityDescription: String {
        switch self {
        case .low:       return "Low severity"
        case .moderate:  return "Moderate severity"
        case .high:      return "High severity"
        case .critical:  return "Critical severity"
        }
    }
}

/// Types of issues that can be found in audits
enum AuditIssueType: String, CaseIterable {
    case forbearance = "Forbearance Issues"
    case interest = "Interest Issues"
    case payments = "Payment Issues"
    case other = "Other Issues"
    
    var localizedDescription: String {
        return self.rawValue
    }
}

// MARK: - Sample Data and Utilities

/// Mock sample data
extension AuditResult {
    static var samples: [AuditResult] {
        [
            AuditResult(
                title: "Excessive Forbearance Duration",
                description: "Loan has 48 months of forbearance, which exceeds the recommended maximum of 36 months",
                severity: .moderate,
                suggestedAction: "Review forbearance history with your loan servicer. Extended forbearance can dramatically increase interest capitalization.",
                issueType: .forbearance
            ),
            AuditResult(
                title: "Excessive Forbearance Duration",
                description: "Loan has 72 months of forbearance, which exceeds the recommended maximum of 36 months",
                severity: .high,
                suggestedAction: "Your extended forbearance period may have significantly increased your loan balance through interest capitalization. Consider contacting your servicer to discuss options.",
                issueType: .forbearance
            ),
            AuditResult(
                title: "Unexplained Interest Capitalization",
                description: "Found 3 unexplained interest capitalization events on: Jan 15, 2022, Mar 3, 2022, July 10, 2022",
                severity: .high,
                suggestedAction: "Request detailed explanation from your loan servicer for each capitalization event. Review your loan terms to verify if these events were permitted under your loan agreement.",
                issueType: .interest
            ),
            AuditResult(
                title: "Extended Non-Payment Period",
                description: "Found 2 periods of non-payment without corresponding forbearance or deferment status: From Apr 2, 2021 to Aug 15, 2021; From Oct 5, 2022 to Jan 12, 2023",
                severity: .critical,
                suggestedAction: "Request documentation for these periods to confirm your loan status. If payments were made during these periods, request verification that they were properly applied to your account.",
                issueType: .payments
            ),
            AuditResult(
                title: "High Interest Rate",
                description: "Loan interest rate of 8.5% exceeds typical federal loan rate of 6.8%",
                severity: .low,
                suggestedAction: "Verify that the interest rate is correctly applied to your loan. If the rate is accurate, consider researching refinancing options to potentially lower your interest rate and overall repayment costs.",
                issueType: .interest
            )
        ]
    }
}

/// A unified parser for extracting loan information from various document types
class DocumentParser {
    
    /// Extracts basic loan details from a document
    /// - Parameter url: The URL of the document to parse
    /// - Returns: The extracted loan details
    /// - Throws: DocumentParsingError if the extraction fails
    static func extractBasicLoanDetails(from url: URL) async throws -> SimpleLoanDetails {
        // Determine file type based on extension
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return try await extractFromPDF(url: url)
        case "csv":
            return try await extractFromCSV(url: url)
        case "txt":
            return try await extractFromTextFile(url: url)
        default:
            // Try to handle the file based on content if extension is unrecognized
            if let uti = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
                if UTType(uti)?.conforms(to: UTType.pdf) == true {
                    return try await extractFromPDF(url: url)
                } else if UTType(uti)?.conforms(to: UTType.commaSeparatedText) == true {
                    return try await extractFromCSV(url: url)
                } else if UTType(uti)?.conforms(to: UTType.text) == true {
                    return try await extractFromTextFile(url: url)
                }
            }
            
            throw DocumentParsingError.unsupportedFileType
        }
    }
    
    /// Extracts loan details from a PDF document
    private static func extractFromPDF(url: URL) async throws -> SimpleLoanDetails {
        // Create a PDF document from the URL
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentParsingError.unreadableDocument
        }
        
        // Check that the document has pages
        guard pdfDocument.pageCount > 0 else {
            throw DocumentParsingError.documentEmpty
        }
        
        // Extract text from all pages
        var extractedText = ""
        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i),
               let pageText = page.string {
                extractedText += pageText + "\n"
            }
        }
        
        // Basic parsing - check the content is not empty
        if extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw DocumentParsingError.documentEmpty
        }
        
        // Parse the extracted text
        return try parseExtractedText(extractedText)
    }
    
    /// Extracts loan details from a CSV file
    private static func extractFromCSV(url: URL) async throws -> SimpleLoanDetails {
        // Read the CSV file content
        let data = try Data(contentsOf: url)
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw DocumentParsingError.unreadableDocument
        }
        
        // Basic parsing - check the content is not empty
        if csvString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw DocumentParsingError.documentEmpty
        }
        
        // Split into lines
        var lines = csvString.components(separatedBy: .newlines)
        
        // Remove empty lines
        lines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        guard !lines.isEmpty else {
            throw DocumentParsingError.documentEmpty
        }
        
        // Create a loan details object
        var loanDetails = SimpleLoanDetails()
        
        // Try two approaches: column-based or key-value pairs
        
        // First, try to interpret as a standard CSV with headers
        if lines.count >= 2 {
            let headers = parseCSVLine(lines[0])
            let values = parseCSVLine(lines[1])
            
            if headers.count == values.count && !headers.isEmpty {
                // Create a dictionary of header:value pairs
                let dict = Dictionary(uniqueKeysWithValues: zip(headers, values))
                
                // Look for key columns
                for (key, value) in dict {
                    let lowercaseKey = key.lowercased()
                    
                    if lowercaseKey.contains("servicer") {
                        loanDetails.servicerName = value
                    } else if lowercaseKey.contains("account") || lowercaseKey.contains("number") {
                        loanDetails.accountNumber = value
                    } else if lowercaseKey.contains("interest") || lowercaseKey.contains("rate") {
                        if let rate = extractPercentage(from: value) {
                            loanDetails.interestRate = rate
                        }
                    } else if lowercaseKey.contains("balance") {
                        if let balance = extractCurrency(from: value) {
                            loanDetails.currentBalance = balance
                        }
                    } else if lowercaseKey.contains("date") && lowercaseKey.contains("start") {
                        if let date = extractDate(from: value) {
                            loanDetails.loanStartDate = date
                        }
                    }
                }
            }
        }
        
        // If we didn't get the basic info, try the key-value format
        if loanDetails.accountNumber == nil && loanDetails.interestRate == nil && loanDetails.currentBalance == nil {
            for line in lines {
                let parts = line.split(separator: ",", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                if parts.count == 2 {
                    let key = parts[0].lowercased()
                    let value = parts[1]
                    
                    if key.contains("servicer") {
                        loanDetails.servicerName = value
                    } else if key.contains("account") || key.contains("number") {
                        loanDetails.accountNumber = value
                    } else if key.contains("interest") || key.contains("rate") {
                        if let rate = extractPercentage(from: value) {
                            loanDetails.interestRate = rate
                        }
                    } else if key.contains("balance") {
                        if let balance = extractCurrency(from: value) {
                            loanDetails.currentBalance = balance
                        }
                    } else if key.contains("date") && key.contains("start") {
                        if let date = extractDate(from: value) {
                            loanDetails.loanStartDate = date
                        }
                    }
                }
            }
        }
        
        // Check if we got at least some basic information
        if loanDetails.accountNumber == nil && loanDetails.interestRate == nil && loanDetails.currentBalance == nil {
            throw DocumentParsingError.missingRequiredData
        }
        
        return loanDetails
    }
    
    /// Helper function to parse a CSV line considering quoted fields
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                result.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        // Add the last field
        result.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
        
        return result
    }
    
    /// Extracts loan details from a text file
    private static func extractFromTextFile(url: URL) async throws -> SimpleLoanDetails {
        // Read the text file content
        let data = try Data(contentsOf: url)
        guard let textContent = String(data: data, encoding: .utf8) else {
            throw DocumentParsingError.unreadableDocument
        }
        
        // Basic parsing - check the content is not empty
        if textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw DocumentParsingError.documentEmpty
        }
        
        // Parse the extracted text
        return try parseExtractedText(textContent)
    }
    
    /// Parses extracted text to find loan details
    private static func parseExtractedText(_ extractedText: String) throws -> SimpleLoanDetails {
        // Create a loan details object
        var loanDetails = SimpleLoanDetails()
        
        // Attempt to identify the servicer
        for servicer in ["Navient", "Great Lakes", "Nelnet", "MOHELA", "FedLoan", "Sallie Mae"] {
            if extractedText.contains(servicer) {
                loanDetails.servicerName = servicer
                break
            }
        }
        
        // Try to find an account number (typically 8-12 digits, may have X's)
        let accountPattern = "(?:Account|Loan)[^0-9A-Z]*([0-9A-Z\\-*]{6,12})"
        if let accountMatch = extractRegex(pattern: accountPattern, from: extractedText),
           accountMatch.count > 1 {
            loanDetails.accountNumber = accountMatch[1]
        }
        
        // Try to find an interest rate (typically expressed as a percentage)
        let interestPattern = "(?:Interest Rate|Rate)[^0-9]*([0-9]+\\.[0-9]{1,3})\\s*%"
        if let interestMatch = extractRegex(pattern: interestPattern, from: extractedText),
           interestMatch.count > 1,
           let rate = Double(interestMatch[1]) {
            loanDetails.interestRate = rate
        }
        
        // Try to find current balance
        let balancePattern = "(?:Current Balance|Balance|Total Balance)[^0-9$]*\\$?([0-9,]+\\.[0-9]{2})"
        if let balanceMatch = extractRegex(pattern: balancePattern, from: extractedText),
           balanceMatch.count > 1 {
            // Remove commas from the number
            let cleanedNumber = balanceMatch[1].replacingOccurrences(of: ",", with: "")
            if let balance = Double(cleanedNumber) {
                loanDetails.currentBalance = balance
            }
        }
        
        // Try to identify some dates that might be loan start date
        let datePattern = "(0?[1-9]|1[0-2])[/\\-](0?[1-9]|[12][0-9]|3[01])[/\\-](19|20)([0-9]{2})"
        let dateMatches = extractAllRegex(pattern: datePattern, from: extractedText)
        if !dateMatches.isEmpty {
            // Heuristic: the earliest date might be the loan start date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd/yyyy"
            
            // Convert matches to dates
            var dates: [Date] = []
            for match in dateMatches where match.count > 4 {
                let month = match[1]
                let day = match[2]
                let century = match[3]
                let year = match[4]
                let dateString = "\(month)/\(day)/\(century)\(year)"
                
                if let date = dateFormatter.date(from: dateString) {
                    dates.append(date)
                }
            }
            
            // Sort dates and take earliest as possible loan start
            if let earliestDate = dates.sorted().first {
                loanDetails.loanStartDate = earliestDate
            }
        }
        
        // Check if we got at least some basic information
        if loanDetails.accountNumber == nil && loanDetails.interestRate == nil && loanDetails.currentBalance == nil {
            throw DocumentParsingError.missingRequiredData
        }
        
        return loanDetails
    }
    
    /// Helper function to extract percentage values from text
    private static func extractPercentage(from text: String) -> Double? {
        // Remove any % symbol and whitespace
        let cleaned = text.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned)
    }
    
    /// Helper function to extract currency values from text
    private static func extractCurrency(from text: String) -> Double? {
        // Remove $ symbol, commas, and whitespace
        let cleaned = text
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned)
    }
    
    /// Helper function to extract date values from text
    private static func extractDate(from text: String) -> Date? {
        let dateFormatters = [
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "MMMM d, yyyy",
            "MMM d, yyyy"
        ].map {
            let formatter = DateFormatter()
            formatter.dateFormat = $0
            return formatter
        }
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        for formatter in dateFormatters {
            if let date = formatter.date(from: trimmedText) {
                return date
            }
        }
        
        return nil
    }
    
    /// Runs a regex pattern against text and returns the first match
    /// - Parameters:
    ///   - pattern: The regex pattern to use
    ///   - text: The text to search
    /// - Returns: An array of capture groups if found, nil otherwise
    static func extractRegex(pattern: String, from text: String) -> [String]? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            
            if let match = matches.first {
                var result: [String] = []
                for i in 0..<match.numberOfRanges {
                    let range = match.range(at: i)
                    if range.location != NSNotFound {
                        result.append(nsString.substring(with: range))
                    }
                }
                return result
            }
        } catch {
            print("Regex error: \(error)")
        }
        return nil
    }
    
    /// Runs a regex pattern against text and returns all matches
    /// - Parameters:
    ///   - pattern: The regex pattern to use
    ///   - text: The text to search
    /// - Returns: An array of arrays, where each inner array contains capture groups
    static func extractAllRegex(pattern: String, from text: String) -> [[String]] {
        var results: [[String]] = []
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                var result: [String] = []
                for i in 0..<match.numberOfRanges {
                    let range = match.range(at: i)
                    if range.location != NSNotFound {
                        result.append(nsString.substring(with: range))
                    }
                }
                results.append(result)
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        return results
    }
}

// MARK: - View Model

/// Enhanced view model with support for multiple document types
class LoanAuditViewModel: ObservableObject {
    
    // MARK: - Published properties
    
    /// Current state of the audit process
    @Published var state: AuditState = .initial
    
    /// Results from the audit
    @Published var auditResults: [AuditResult] = []
    
    /// Tracks if dev mode is enabled
    @Published var devModeEnabled = false
    
    /// Simulated progress for loading animation (0.0 to 1.0)
    @Published var loadingProgress: Double = 0.0
    
    /// Error message if something goes wrong
    @Published var errorMessage: String?
    
    /// URL of the selected document
    @Published var selectedDocumentURL: URL?
    
    /// Extracted loan details
    @Published var loanDetails: SimpleLoanDetails?
    
    /// Show document picker
    @Published var showingDocumentPicker = false
    
    /// Show document preview
    @Published var showingDocumentPreview = false
    
    // MARK: - Private properties
    
    /// Timer for simulating progress
    private var progressTimer: Timer?
    
    // MARK: - State management
    
    /// Different states the audit process can be in
    enum AuditState {
        case initial        // Welcome screen
        case documentSelected // Document selected, showing preview
        case loading        // Processing/analyzing document
        case results        // Showing list of issues
        case resultsEmpty   // No issues found
        case error          // Error occurred
    }
    
    // MARK: - Public methods
    
    /// Selects a document from the document picker
    func selectDocument(url: URL) {
        self.selectedDocumentURL = url
        self.showingDocumentPreview = true
        self.state = .documentSelected
    }
    
    /// Process the selected document
    func processDocument() {
        guard let url = selectedDocumentURL else {
            showDocumentPicker()
            return
        }
        
        // If in dev mode and selected the sample button, just show mock results
        if devModeEnabled {
            self.auditResults = AuditResult.samples
            self.state = .results
            return
        }
        
        // Show loading state
        self.state = .loading
        
        // Start a background task to process the document
        Task {
            do {
                // Extract loan details
                self.loadingProgress = 0.1
                let extractedDetails = try await performWithProgress(
                    from: 0.1, to: 0.6,
                    task: { try await DocumentParser.extractBasicLoanDetails(from: url) }
                )
                
                // Store the extracted details
                await MainActor.run { self.loanDetails = extractedDetails }
                
                // Perform an audit on the extracted details
                self.loadingProgress = 0.7
                let results = try await performWithProgress(
                    from: 0.7, to: 0.95,
                    task: { self.auditLoanDetails(extractedDetails) }
                )
                
                // Update the UI with results
                await MainActor.run {
                    self.loadingProgress = 1.0
                    self.auditResults = results
                    
                    // Determine if we have results or empty state
                    if results.isEmpty {
                        self.state = .resultsEmpty
                    } else {
                        self.state = .results
                    }
                }
            } catch let error as DocumentParsingError {
                // Handle document parsing errors
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.state = .error
                }
            } catch {
                // Handle other errors
                await MainActor.run {
                    self.errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                    self.state = .error
                }
            }
        }
    }
    
    /// Shows the document picker
    func showDocumentPicker() {
        self.showingDocumentPicker = true
    }
    
    /// Dismisses the document preview
    func dismissDocumentPreview() {
        self.showingDocumentPreview = false
        self.state = .initial
    }
    
    /// Handles tapping the "View Sample Results" button
    func loadSampleResults() {
        // If dev mode is enabled, skip loading animation
        if devModeEnabled {
            self.auditResults = AuditResult.samples
            self.state = .results
            return
        }
        
        // Show loading state with progress animation
        self.state = .loading
        self.startLoadingAnimation {
            // After "loading" finishes, show results
            self.auditResults = AuditResult.samples
            self.state = .results
        }
    }
    
    /// Handles tapping the "View Empty State" button
    func loadEmptyResults() {
        // If dev mode is enabled, skip loading animation
        if devModeEnabled {
            self.auditResults = []
            self.state = .resultsEmpty
            return
        }
        
        // Show loading state with progress animation
        self.state = .loading
        self.startLoadingAnimation {
            // After "loading" finishes, show empty state
            self.auditResults = []
            self.state = .resultsEmpty
        }
    }
    
    /// Simulates an error occurring during processing
    func simulateError() {
        self.state = .loading
        self.startLoadingAnimation {
            self.errorMessage = "Unable to process the loan document. The file format may be unsupported or the document may be damaged."
            self.state = .error
        }
    }
    
    /// Resets back to welcome screen
    func reset() {
        self.state = .initial
        self.loadingProgress = 0.0
        self.errorMessage = nil
        self.selectedDocumentURL = nil
        self.loanDetails = nil
        self.showingDocumentPreview = false
    }
    
    // MARK: - Private helper methods
    
    /// Creates a timed animation for the loading progress
    private func startLoadingAnimation(completion: @escaping () -> Void) {
        // Reset progress
        self.loadingProgress = 0.0
        
        // Cancel any existing timer
        progressTimer?.invalidate()
        
        // Create a new timer that updates progress
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            
            // Increment progress
            self.loadingProgress += 0.01
            
            // When progress reaches 1.0, complete the loading process
            if self.loadingProgress >= 1.0 {
                timer.invalidate()
                self.progressTimer = nil
                
                // Small delay before completion for smoother transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    completion()
                }
            }
        }
    }
    
    /// Creates a test document file for simulator testing
    func createTestDocument(fileType: TestDocumentType = .pdf) -> (Data, String) {
        switch fileType {
        case .pdf:
            return (createTestPDF(), "sample_loan.pdf")
        case .csv:
            return (createTestCSV(), "sample_loan.csv")
        case .text:
            return (createTestTextFile(), "sample_loan.txt")
        }
    }
    
    /// Supported test document types
    enum TestDocumentType {
        case pdf, csv, text
    }
    
    /// Creates a test PDF file
    private func createTestPDF() -> Data {
        // Create a PDF document
        let pdfMetaData = [
            kCGPDFContextCreator: "Loan Servicer",
            kCGPDFContextTitle: "Student Loan Statement"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { (context) in
            context.beginPage()
            
            // Add a title
            let titleFont = UIFont.boldSystemFont(ofSize: 24.0)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont
            ]
            let titleString = "Student Loan Statement"
            let titleStringSize = titleString.size(withAttributes: titleAttributes)
            let titleStringRect = CGRect(
                x: (pageRect.width - titleStringSize.width) / 2.0,
                y: 50,
                width: titleStringSize.width,
                height: titleStringSize.height
            )
            titleString.draw(in: titleStringRect, withAttributes: titleAttributes)
            
            // Add loan details
            let textFont = UIFont.systemFont(ofSize: 12.0)
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: textFont
            ]
            
            let details = [
                "Servicer: Navient",
                "Account Number: 123456789",
                "Interest Rate: 6.8%",
                "Current Balance: $45,678.90",
                "Payment Due: $356.78",
                "Date: January 15, 2025"
            ]
            
            var y = 100.0
            for detail in details {
                let detailRect = CGRect(x: 72, y: y, width: pageWidth - 144, height: 20)
                detail.draw(in: detailRect, withAttributes: textAttributes)
                y += 20
            }
            
            // Add a section for payment history
            y += 40
            let sectionFont = UIFont.boldSystemFont(ofSize: 16.0)
            let sectionAttributes: [NSAttributedString.Key: Any] = [
                .font: sectionFont
            ]
            
            let sectionString = "Payment History"
            let sectionRect = CGRect(x: 72, y: y, width: 200, height: 20)
            sectionString.draw(in: sectionRect, withAttributes: sectionAttributes)
            
            y += 30
            let payments = [
                "Jan 1, 2025: $356.78",
                "Dec 1, 2024: $356.78",
                "Nov 1, 2024: $356.78",
                "Oct 1, 2024: $356.78"
            ]
            
            for payment in payments {
                let paymentRect = CGRect(x: 72, y: y, width: pageWidth - 144, height: 20)
                payment.draw(in: paymentRect, withAttributes: textAttributes)
                y += 20
            }
            
            // Add a section for forbearance periods
            y += 40
            let forbString = "Forbearance Periods"
            let forbRect = CGRect(x: 72, y: y, width: 200, height: 20)
            forbString.draw(in: forbRect, withAttributes: sectionAttributes)
            
            y += 30
            let forbearances = [
                "Mar 15, 2023 - Sep 15, 2023: COVID-19 Relief",
                "Jan 1, 2022 - Feb 28, 2022: Economic Hardship"
            ]
            
            for forb in forbearances {
                let forbRect = CGRect(x: 72, y: y, width: pageWidth - 144, height: 20)
                forb.draw(in: forbRect, withAttributes: textAttributes)
                y += 20
            }
        }
        
        return data
    }
    
    /// Creates a test CSV file
    private func createTestCSV() -> Data {
        let csvContent = """
        Servicer,Account Number,Interest Rate,Current Balance,Payment Due,Date
        Navient,123456789,6.8%,$45678.90,$356.78,January 15 2025
        
        Payment History
        Date,Amount
        01/01/2025,$356.78
        12/01/2024,$356.78
        11/01/2024,$356.78
        10/01/2024,$356.78
        
        Forbearance Periods
        Start Date,End Date,Reason
        03/15/2023,09/15/2023,COVID-19 Relief
        01/01/2022,02/28/2022,Economic Hardship
        """
        
        return Data(csvContent.utf8)
    }
    
    /// Creates a test text file
    private func createTestTextFile() -> Data {
        let textContent = """
        STUDENT LOAN STATEMENT
        
        Servicer: Navient
        Account Number: 123456789
        Interest Rate: 6.8%
        Current Balance: $45,678.90
        Payment Due: $356.78
        Date: January 15, 2025
        
        ---------- PAYMENT HISTORY ----------
        Jan 1, 2025: $356.78
        Dec 1, 2024: $356.78
        Nov 1, 2024: $356.78
        Oct 1, 2024: $356.78
        
        ---------- FORBEARANCE PERIODS ----------
        Mar 15, 2023 - Sep 15, 2023: COVID-19 Relief
        Jan 1, 2022 - Feb 28, 2022: Economic Hardship
        """
        
        return Data(textContent.utf8)
    }
    
    /// Performs a task with progress updates
    private func performWithProgress<T>(from startProgress: Double, to endProgress: Double, task: @escaping () async throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            // Start a background thread for the task
            Task {
                do {
                    // Run the task
                    let result = try await task()
                    
                    // Update progress on main thread
                    await MainActor.run {
                        self.loadingProgress = endProgress
                        continuation.resume(returning: result)
                    }
                } catch {
                    // Handle errors on main thread
                    await MainActor.run {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // Update progress on main thread
            Task { @MainActor in
                self.loadingProgress = startProgress
            }
        }
    }
    
    /// Performs a simplified audit on loan details
    private func auditLoanDetails(_ details: SimpleLoanDetails) -> [AuditResult] {
        var results: [AuditResult] = []
        
        // Only add sample issues based on the loan details
        // In a real implementation, this would run actual audit rules
        
        // Check interest rate
        if let interestRate = details.interestRate, interestRate > 5.0 {
            let severity: AuditSeverity = interestRate > 8.0 ? .high : 
                                         interestRate > 6.0 ? .moderate : .low
            
            results.append(AuditResult(
                title: "High Interest Rate",
                description: "Loan interest rate of \(String(format: "%.2f", interestRate))% exceeds typical federal loan rate of 5.00%",
                severity: severity,
                suggestedAction: "Verify that the interest rate is correctly applied to your loan. If the rate is accurate, consider researching refinancing options to potentially lower your interest rate and overall repayment costs.",
                issueType: .interest
            ))
        }
        
        // Check forbearance periods (if we found any)
        if !details.forbearancePeriods.isEmpty {
            // Calculate total forbearance days
            let totalDays = details.forbearancePeriods.reduce(0) { total, period in
                let days = Calendar.current.dateComponents([.day], from: period.start, to: period.end).day ?? 0
                return total + days
            }
            
            let totalMonths = totalDays / 30 // Approximate
            
            if totalMonths > 36 {
                let severity: AuditSeverity = totalMonths > 60 ? .high : .moderate
                
                results.append(AuditResult(
                    title: "Excessive Forbearance Duration",
                    description: "Loan has approximately \(totalMonths) months of forbearance, which exceeds the recommended maximum of 36 months",
                    severity: severity,
                    suggestedAction: "Review forbearance history with your loan servicer. Extended forbearance can dramatically increase interest capitalization.",
                    issueType: .forbearance
                ))
            }
        }
        
        // If we have a loan from a specific servicer, add some mock findings
        if details.servicerName == "Navient" {
            results.append(AuditResult(
                title: "Servicer with Known Issues",
                description: "Your loan is serviced by Navient, which has been involved in recent legal settlements regarding loan servicing practices.",
                severity: .low,
                suggestedAction: "Review your account history carefully. Consider requesting a complete account history and payment record to verify all transactions have been properly applied.",
                issueType: .other
            ))
        }
        
        return results
    }
}

// MARK: - Views

/// Button for loading a test document in the simulator
struct SimulatorTestButton: View {
    var docType: LoanAuditViewModel.TestDocumentType
    var onTestDocumentTapped: (LoanAuditViewModel.TestDocumentType) -> Void
    
    var buttonText: String {
        switch docType {
        case .pdf:
            return "Load Test PDF"
        case .csv:
            return "Load Test CSV"
        case .text:
            return "Load Text File"
        }
    }
    
    var buttonColor: Color {
        switch docType {
        case .pdf:
            return Color.orange
        case .csv:
            return Color.green
        case .text:
            return Color.purple
        }
    }
    
    var body: some View {
        Button(buttonText) {
            onTestDocumentTapped(docType)
        }
        .padding()
        .frame(minWidth: 240)
        .background(buttonColor)
        .foregroundColor(.white)
        .cornerRadius(10)
    }
}

/// A UIViewControllerRepresentable wrapper for UIDocumentPickerViewController
struct LoanDocumentPicker: UIViewControllerRepresentable {
    /// Callback when a document is selected
    var onDocumentSelected: (URL) -> Void
    
    /// Creates the document picker controller
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Specify supported file types: PDF, CSV, and text files
        let supportedTypes = [UTType.pdf, UTType.commaSeparatedText, UTType.text, UTType.plainText]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        
        // Allow only one file to be selected
        picker.allowsMultipleSelection = false
        
        // Connect the delegate
        picker.delegate = context.coordinator
        
        return picker
    }
    
    /// Updates the controller (not needed for this simple implementation)
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }
    
    /// Creates the coordinator to handle delegate methods
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// Coordinator class to handle delegate callbacks
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: LoanDocumentPicker
        
        init(_ parent: LoanDocumentPicker) {
            self.parent = parent
        }
        
        /// Called when a document is picked
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Make sure we have at least one URL
            guard let url = urls.first else { return }
            
            // Secure access to the file
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            
            // Call the callback with the selected document URL
            parent.onDocumentSelected(url)
            
            // Release access when done
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
}

/// A SwiftUI wrapper for displaying document previews
struct DocumentPreviewView: View {
    /// The URL of the document to display
    let url: URL
    
    var body: some View {
        let fileExtension = url.pathExtension.lowercased()
        
        if fileExtension == "pdf" {
            PDFPreviewView(url: url)
        } else {
            TextFilePreviewView(url: url)
        }
    }
}

/// A SwiftUI wrapper for PDFView to preview PDFs
struct PDFPreviewView: UIViewRepresentable {
    /// The URL of the PDF to display
    let url: URL
    
    /// Creates the PDF view
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.pageShadowsEnabled = true
        return pdfView
    }
    
    /// Updates the PDF view with the document
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
    }
}

/// A view for previewing text-based files
struct TextFilePreviewView: View {
    /// The URL of the text file to display
    let url: URL
    
    /// Text content loaded from the file
    @State private var content: String = ""
    @State private var isLoading: Bool = true
    @State private var error: String? = nil
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading document...")
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                        .padding()
                    
                    Text("Error loading document")
                        .font(.headline)
                    
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else {
                ScrollView {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
                .background(Color(.systemGray6))
            }
        }
        .onAppear {
            loadContent()
        }
    }
    
    private func loadContent() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: url)
                if let text = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.content = text
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.error = "Unable to decode the document contents."
                        self.isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

/// A view for displaying information about a selected document
struct SelectedDocumentView: View {
    let url: URL
    let onDismiss: () -> Void
    let onProcess: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Text("Selected Document:")
                    .font(.headline)
                Spacer()
                Button("Dismiss") {
                    onDismiss()
                }
            }
            .padding()
            
            Text(url.lastPathComponent)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            DocumentPreviewView(url: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            Button("Process This Document") {
                onDismiss()
                onProcess()
            }
            .padding()
            .frame(minWidth: 200)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.top, 20)
        }
        .padding()
    }
}

/// Main view that integrates document selection and processing
struct LoanAuditView: View {
    /// View model for state management
    @StateObject private var viewModel = LoanAuditViewModel()
    
    /// Loads a test document of the specified type
    private func loadTestDocument(_ docType: LoanAuditViewModel.TestDocumentType) {
        // Use a sample string to create a test document
        let (docData, fileName) = viewModel.createTestDocument(fileType: docType)
        
        // Save to temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try docData.write(to: fileURL)
            viewModel.selectDocument(url: fileURL)
        } catch {
            print("Error saving test document: \(error)")
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Display different content based on the current state
                switch viewModel.state {
                case .initial:
                    welcomeView
                case .documentSelected:
                    if viewModel.showingDocumentPreview, let url = viewModel.selectedDocumentURL {
                        SelectedDocumentView(
                            url: url,
                            onDismiss: {
                                viewModel.dismissDocumentPreview()
                            },
                            onProcess: {
                                viewModel.processDocument()
                            }
                        )
                    } else {
                        welcomeView
                    }
                case .loading:
                    loadingView
                case .results:
                    resultsView
                case .resultsEmpty:
                    emptyStateView
                case .error:
                    errorView
                }
            }
            .navigationTitle("Loan Audit")
            .toolbar {
                // Only show the reset button when not in initial state
                if viewModel.state != .initial {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("New Audit") {
                            viewModel.reset()
                        }
                    }
                }
                
                // Question mark help button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Would show help/about view
                    }) {
                        Image(systemName: "questionmark.circle")
                    }
                }
                
                // Show dev mode toggle only in debug builds
                #if DEBUG
                ToolbarItem(placement: .navigationBarTrailing) {
                    Toggle("Dev", isOn: $viewModel.devModeEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                #endif
            }
            .sheet(isPresented: $viewModel.showingDocumentPicker) {
                LoanDocumentPicker { url in
                    viewModel.selectDocument(url: url)
                }
            }
        }
    }
    
    /// Welcome screen view
    private var welcomeView: some View {
        VStack(spacing: 25) {
            // App icon/logo
            Image(systemName: "doc.text.magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.bottom, 10)
            
            // Main title
            Text("Audit Your Student Loan")
                .font(.title)
                .fontWeight(.bold)
            
            // Description
            Text("Upload your loan statement to find potential issues and get actionable insights.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            // Action buttons
            VStack(spacing: 12) {
                // Main action button
                Button("Select Document") {
                    viewModel.showDocumentPicker()
                }
                .padding()
                .frame(minWidth: 240)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Text("Simulator Test Files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
                
                // Simulator test buttons for document testing
                SimulatorTestButton(docType: .pdf) { docType in
                    loadTestDocument(docType)
                }
                
                SimulatorTestButton(docType: .csv) { docType in
                    loadTestDocument(docType)
                }
                
                SimulatorTestButton(docType: .text) { docType in
                    loadTestDocument(docType)
                }
                
                // Only show these buttons in DEBUG mode
                #if DEBUG
                Divider()
                    .padding(.vertical, 10)
                
                Text("Development Options")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("View Sample Results") {
                    viewModel.loadSampleResults()
                }
                .padding()
                .frame(minWidth: 240)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(10)
                
                Button("View Empty State") {
                    viewModel.loadEmptyResults()
                }
                .padding()
                .frame(minWidth: 240)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(10)
                
                Button("Simulate Error") {
                    viewModel.simulateError()
                }
                .padding()
                .frame(minWidth: 240)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(10)
                #endif
            }
            .padding(.top, 15)
        }
        .padding()
    }
    
    /// Loading state with progress animation
    private var loadingView: some View {
        VStack(spacing: 30) {
            // Progress view with percentage
            ZStack {
                // Circular progress indicator
                Circle()
                    .stroke(lineWidth: 15)
                    .opacity(0.3)
                    .foregroundColor(Color.blue)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(viewModel.loadingProgress))
                    .stroke(style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
                    .foregroundColor(Color.blue)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: viewModel.loadingProgress)
                
                // Percentage text
                Text("\(Int(viewModel.loadingProgress * 100))%")
                    .font(.title)
                    .bold()
            }
            .frame(width: 150, height: 150)
            
            // Status text
            Text("Analyzing Loan Document...")
                .font(.headline)
            
            // Show the document name if available
            if let url = viewModel.selectedDocumentURL {
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Processing steps
            VStack(alignment: .leading, spacing: 15) {
                ProcessingStep(
                    text: "Extracting loan details",
                    isComplete: viewModel.loadingProgress > 0.3
                )
                
                ProcessingStep(
                    text: "Analyzing payment history",
                    isComplete: viewModel.loadingProgress > 0.6
                )
                
                ProcessingStep(
                    text: "Checking for potential issues",
                    isComplete: viewModel.loadingProgress > 0.9
                )
            }
            .frame(maxWidth: 300)
            .padding()
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Processing loan document")
        .accessibilityHint("Please wait while we analyze your loan statement")
    }
    
    /// Results list view
    private var resultsView: some View {
        VStack {
            // Show loan details summary if available
            if let details = viewModel.loanDetails {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Loan Details")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        if let accountNumber = details.accountNumber {
                            LoanDetailRow(label: "Account", value: accountNumber)
                        }
                        
                        LoanDetailRow(label: "Servicer", value: details.servicerName)
                        
                        if let interestRate = details.interestRate {
                            LoanDetailRow(label: "Interest Rate", value: "\(String(format: "%.2f", interestRate))%")
                        }
                        
                        if let balance = details.currentBalance {
                            LoanDetailRow(label: "Balance", value: "$\(String(format: "%.2f", balance))")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding()
                }
            }
            
            // Audit results list
            List {
                // Group results by issue type and display in sections
                ForEach(AuditIssueType.allCases, id: \.self) { issueType in
                    let filteredResults = viewModel.auditResults.filter { $0.issueType == issueType }
                    
                    if !filteredResults.isEmpty {
                        Section(header: Text(issueType.localizedDescription).font(.headline)) {
                            ForEach(filteredResults) { result in
                                AuditResultRow(result: result)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
    }
    
    /// Empty state view (no issues found)
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Show loan details summary if available
            if let details = viewModel.loanDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Loan Details")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    if let accountNumber = details.accountNumber {
                        LoanDetailRow(label: "Account", value: accountNumber)
                    }
                    
                    LoanDetailRow(label: "Servicer", value: details.servicerName)
                    
                    if let interestRate = details.interestRate {
                        LoanDetailRow(label: "Interest Rate", value: "\(String(format: "%.2f", interestRate))%")
                    }
                    
                    if let balance = details.currentBalance {
                        LoanDetailRow(label: "Balance", value: "$\(String(format: "%.2f", balance))")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
            }
            
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("No major issues found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Your loan appears to be in good standing based on our audit criteria.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No audit issues found")
    }
    
    /// Error state view
    private var errorView: some View {
        VStack(spacing: 20) {
            // Error icon
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.orange)
                .padding()
            
            // Error title
            Text("Unable to Complete Audit")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Error message
            Text(viewModel.errorMessage ?? "An unexpected error occurred.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Try again button
            Button("Try Again") {
                viewModel.reset()
            }
            .padding()
            .frame(minWidth: 200)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.top, 10)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(viewModel.errorMessage ?? "Unknown error")")
        .accessibilityHint("Tap Try Again to return to the start screen")
    }
}

/// Component for showing a processing step with completion indicator
struct ProcessingStep: View {
    let text: String
    let isComplete: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            // Completion indicator
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                
                if isComplete {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            // Step text
            Text(text)
                .font(.body)
                .foregroundColor(isComplete ? .primary : .secondary)
        }
        .animation(.easeInOut, value: isComplete)
    }
}

/// Row for displaying a loan detail
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

/// Row view for a single audit result
struct AuditResultRow: View {
    let result: AuditResult
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
        .accessibilityHint(
            isActionExpanded ?
                "Collapse suggested action" :
                "Expand suggested action"
        )
        .accessibilityAction {
            withAnimation {
                isActionExpanded.toggle()
            }
        }
    }
}