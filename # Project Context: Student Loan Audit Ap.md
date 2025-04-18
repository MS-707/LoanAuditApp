# Project Context: Student Loan Audit App

## Mission
Develop an iOS application that empowers U.S. student loan borrowers to audit their loan documents for potential errors and generate actionable reports or letters to address identified issues.

## Target Audience
- U.S. student loan borrowers seeking to identify and rectify errors in their loan documents.
- Individuals affected by misapplied payments, incorrect interest calculations, or other discrepancies.

## Key Features
- **PDF Parsing**: Extract relevant data from uploaded loan documents.
- **Audit Engine**: Analyze extracted data against predefined rules to identify potential issues.
- **Report Generation**: Provide users with clear summaries of identified issues and suggested actions.
- **Letter Templates**: Generate customizable letters for users to send to loan servicers or regulatory bodies.

## Design Principles
- **Accessibility**: Ensure the app is usable by individuals with disabilities, adhering to best practices for accessible design.
- **Privacy-First**: All data processing occurs locally on the user's device; no data is transmitted to external servers.
- **User-Centric**: Design with a focus on clarity, ease of use, and providing actionable insights.

## Technical Stack
- **Platform**: iOS
- **Language**: Swift
- **Frameworks**: SwiftUI for UI, PDFKit for PDF processing

## Claude Code's Role
- Assist in generating modular Swift code components based on provided prompts.
- Ensure generated code adheres to best practices for accessibility, privacy, and maintainability.

## Repository Structure
- `/ios_app/`: SwiftUI views and related UI components.
- `/core_logic/`: Core functionalities including PDF parsing and audit engine.
- `/claude_prompts/`: Markdown files containing prompts for Claude Code.
- `/dev_notes/`: Documentation and notes for developers.
- `/tests/`: Unit and integration tests.
- `/tools/`: Auxiliary tools and scripts.

## Development Workflow
1. Define specific tasks and create corresponding prompts in `/claude_prompts/`.
2. Use Claude Code to generate code based on prompts.
3. Review and integrate generated code into the project.
4. Test functionalities and iterate as needed.

## Licensing and Distribution
- **License**: MIT License
- **Distribution**: Available on the App Store; open-source code hosted on GitHub.

---

# Claude Code Prompt: Create Project Repository Structure

## Purpose
Establish the foundational directory and file structure for the Student Loan Audit App, ensuring a modular and organized codebase.

## Inputs
- Project Name: `LoanAuditApp`
- Description: "An iOS application that audits student loan documents for potential errors and assists users in addressing identified issues."

## Output
- Directory structure:
  - `/ios_app/`
  - `/core_logic/`
  - `/claude_prompts/`
  - `/dev_notes/`
  - `/tests/`
  - `/tools/`
- Files:
  - `README.md` with project overview.
  - `.gitignore` tailored for Swift projects.
  - `LICENSE` file with MIT License.

## Guidelines
- Ensure directories are created with placeholder `.gitkeep` files if necessary to maintain structure.
- `README.md` should include sections: Project Overview, Features, Installation, Usage, Contributing, License.
- `.gitignore` should exclude build artifacts, user-specific files, and other unnecessary files.
- Maintain consistency with Swift project conventions.
