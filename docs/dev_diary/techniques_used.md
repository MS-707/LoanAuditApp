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