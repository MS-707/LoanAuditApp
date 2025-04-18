# Code & Pattern Tracking

## [Repository Structure]
- Design Pattern(s): Modular organization
- Libraries/Frameworks Used: None yet
- Accessibility Enhancements: None yet
- Unit Testing Strategy: Separate `/tests/` directory prepared for future test implementation
- Architectural Considerations: Separation of UI (`/ios_app/`) from business logic (`/core_logic/`), documentation-first approach with `/claude_prompts/` and `/dev_notes/`

## [Loan Audit Engine]
- Design Pattern(s): 
  - Protocol-oriented programming
  - Strategy pattern for rules implementation
  - Composability through rule aggregation
  - Immutable data structures
- Libraries/Frameworks Used: 
  - Foundation (Date, DateFormatter, DateInterval)
- Accessibility Enhancements: 
  - Severity levels with clear textual descriptions
  - Detailed human-readable issue descriptions
- Unit Testing Strategy: 
  - Each rule can be tested independently
  - Mock LoanDetails can be created for specific test scenarios
  - Rules follow single responsibility principle for focused testing
- Architectural Considerations: 
  - Clear separation of data models from business logic
  - Protocol-based design for extensibility
  - Enum-based categorization for consistency
  - Pure functions in rules for predictability and testing

## [Loan Audit Engine Optimization]
- Design Pattern(s): 
  - Inheritance for shared rule implementation (NonPaymentDurationRule base class)
  - Factory methods for test data creation
  - Singleton-like shared formatters
  - Policy pattern for centralized configuration
  - Fluent interface for SeverityScaler
- Libraries/Frameworks Used: 
  - Foundation (NSLocalizedString, NumberFormatter)
  - Swift Concurrency (async/await, TaskGroup)
- Accessibility Enhancements: 
  - Internationalization with NSLocalizedString for all user-facing messages
  - Consistent date and number formatting with locale support
  - Comparable interface for severity levels
- Unit Testing Strategy: 
  - Factory methods create pre-configured test data
  - Equatable conformance for easy result comparison
  - Rule codes for precise identification in tests
  - Base classes for testing related rule types
- Architectural Considerations: 
  - Centralized configuration with AuditPolicy struct
  - Consolidated formatting with AuditFormatters
  - Consistent severity calculation with SeverityScaler
  - Strong public interfaces with well-documented parameters
  - Final classes where inheritance is not intended

## [PDF Loan Parser]
- Design Pattern(s): 
  - Composition over inheritance
  - Builder pattern for constructing LoanDetails incrementally
  - Strategy pattern for different parsing approaches
  - Utility pattern for reusable parsing functions
  - Error handling with custom domain-specific errors
- Libraries/Frameworks Used: 
  - PDFKit (PDFDocument, page handling, text extraction)
  - Foundation (Regular expressions, date handling)
  - NSRegularExpression for pattern matching
- Accessibility Enhancements: 
  - Error messages designed for clear user feedback
  - Robust error handling with specific error types
  - Fallback strategies to ensure data availability
- Unit Testing Strategy: 
  - Clear separation of document reading from parsing logic
  - Field extraction methods designed for independent testing
  - Validation logic centralized for consistent data quality
  - Error conditions clearly specified for test coverage
- Architectural Considerations: 
  - Modular extraction methods for each field type
  - Clear separation of concerns:
    - Document normalization
    - Pattern recognition
    - Date and number parsing
    - Field validation
    - Entity construction
  - Extensibility for different loan servicer formats
  - Privacy-first design with on-device processing