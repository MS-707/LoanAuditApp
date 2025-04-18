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