# MacOSAIDiskCleaner - GitHub Copilot Configuration

## Project Overview

**Project Name**: MacOSAIDiskCleaner
**Type**: macOS Native Application
**Primary Language**: Swift 5.9+
**UI Framework**: SwiftUI
**Platform**: macOS 12.0+
**Architecture**: MVVM + Actor Concurrency

## Technology Stack

### Core Technologies
- **Language**: Swift 5.9+
- **UI**: SwiftUI (Native macOS)
- **Concurrency**: Swift Concurrency (async/await, Actor)
- **Build System**: Xcode 14.3+
- **Package Management**: Swift Package Manager

### Key Dependencies
- **Sparkle 2.6.4**: Auto-update framework
- **Files**: macOS FileManager operations
- **os.log**: Unified logging system
- **Security**: Keychain Services, Full Disk Access

### External Services
- **LLM API**: OpenAI-compatible endpoints for AI analysis
- **GitHub Actions**: CI/CD automation
- **Homebrew**: Dependency management for build tools

## Architecture Patterns

### Concurrency Model
- **Actor Isolation**: All state managers use Actor for thread safety
  - `StatisticsManager`: Manages cleanup statistics
  - `CategoryManager`: Handles scan categories
  - `AIAnalyzer`: Coordinates AI analysis
  - `TrashManager`: Manages file deletion operations

### MVVM Pattern
```
Views (SwiftUI)
  ↓
ViewModels (@MainActor)
  ↓
Models (Codable, Sendable)
  ↓
Actors (Business Logic)
```

### Security Architecture
- **Path Validation**: Use `canonicalPathKey` to resolve symlinks
- **Permission Management**: Continuous Full Disk Access monitoring
- **Keychain Storage**: Secure API key storage with device-only access
- **Sandbox Compliance**: System path protection list

## Code Style Guidelines

### Naming Conventions
- **Classes/Structs**: PascalCase (e.g., `FileScanner`, `CleanupStatistics`)
- **Functions**: camelCase (e.g., `scanTopLevelAggregates`)
- **Constants**: camelCase with descriptive names
- **Acronyms**: Treat as words (e.g., `apiUrl`, not `APIUrl`)

### Swift Best Practices
1. **Always use `canonicalPathKey`** for file path validation
2. **Check permissions continuously** during long-running operations
3. **Use Actor isolation** for all mutable shared state
4. **Prefer `async/await`** over completion handlers
5. **Mark Sendable conformance** for types passed across actor boundaries
6. **Use `@MainActor`** for all ViewModels and UI updates

### Security Requirements
- **Never trust user input paths**: Always validate with `canonicalPathKey`
- **Never bypass permission checks**: Check before each sensitive operation
- **Always use dry-run mode**: Default to safe operations
- **Log all security decisions**: Use `Logger.security` for audit trail

### Error Handling
```swift
// Do:
func scanFiles() async throws -> [URL] {
    guard permissionManager.fullDiskAccessStatus == .granted else {
        throw DiskCleanerError.permissionDenied("Full Disk Access required")
    }
    // ... scan logic
}

// Don't:
func scanFiles() -> [URL]? {
    // Avoid optional returns for error conditions
}
```

## Testing Strategy

### Unit Tests
- **Location**: `MacOSAIDiskCleanerTests/`
- **Framework**: XCTest
- **Coverage Target**: >80%
- **Test Data Cleanup**: Use `setUp()`/`tearDown()` to clean persisted state

### Test Categories
1. **Security Tests**: Path traversal, permission checks
2. **Concurrency Tests**: Actor isolation, data races
3. **Integration Tests**: End-to-end workflows
4. **Performance Tests**: Large directory scanning

## Build & Release Process

### CI Pipeline (.github/workflows/ci.yml)
- **Trigger**: Push/PR to main
- **SwiftLint**: Code quality checks
- **Unit Tests**: Multi-version Xcode testing
- **Build Verification**: Release build validation

### CD Pipeline (.github/workflows/release.yml)
- **Trigger**: Tag push (v*)
- **Build**: Release configuration with code signing
- **Package**: DMG creation via create-dmg
- **Release**: GitHub Release with artifacts

### Versioning
- **Format**: Semantic Versioning (vX.Y.Z)
- **Marketing Version**: User-facing version number
- **Build Number**: Incrementing integer from GitHub run number

## Development Workflow

### Feature Development
1. Create feature branch from main
2. Implement with tests
3. Run SwiftLint locally
4. Ensure all tests pass
5. Create PR with description
6. Address review feedback
7. Merge after approval

### Release Process
1. Update version in Xcode project
2. Update CHANGELOG.md
3. Commit all changes
4. Create and push tag: `git tag -a v1.0.0 -m "Release notes"`
5. Push tag: `git push origin v1.0.0`
6. GitHub Actions automatically builds and releases

## Common Patterns

### Adding New Scan Rules
```swift
static let newRule = CleanupRule(
    id: "custom.newrule",
    name: "New Rule",
    pattern: "**/target_path/**",
    riskLevel: .medium,
    description: "Describe what this cleans"
)
```

### Adding New Statistics
```swift
await statisticsManager.recordCleanup(
    stats,
    ruleBreakdown: [("ruleId", "Rule Name", count, bytes)]
)
```

### Safe File Operations
```swift
let canonicalPath = url.canonicalPath
guard !FileScanner.isProtectedSystemPath(canonicalPath) else {
    throw DiskCleanerError.permissionDenied(canonicalPath)
}
```

## Important Notes

### Permissions Required
- **Full Disk Access**: Required for scanning system directories
- **Network Access**: Required for AI analysis API calls
- **No Sandbox**: Currently runs unsandboxed for full filesystem access

### Known Limitations
- No internationalization (i18n) yet
- Requires manual Full Disk Access grant
- AI analysis requires API key configuration
- No iOS version planned

### Future Enhancements
- Custom rule editor UI
- Plugin system for user-defined rules
- Cloud sync for statistics
- Team/family license management

---

**Last Updated**: 2026-02-05
**Maintained By**: DISSIDIA-986
