# SwiftLint Action Plan

## Summary After Initial Fixes

- **Total violations**: 641 (down from 3,714)
- **Critical deprecated syntax fixed**: 10 Selector syntax issues ✅  
- **Remaining deprecated syntax**: 28 String format + 11 print statements

## Immediate Fixes Required

### 1. Deprecated String Format (28 violations)
Replace `String(format:)` with modern alternatives:
- For numbers: Use `formatted()` API
- For simple cases: Use string interpolation
- Example: `String(format: "%.2f", value)` → `"\(value.formatted(.number.precision(.fractionLength(2))))"`

### 2. Print Statements (11 violations)
Replace with proper logging:
- Import `os.log` or use `Logger`
- Replace `print()` with `Logger().info()` or similar
- Keep print statements only in example/test files

### 3. Force Unwrapping (39 violations)
Safety improvements:
- Use optional binding (`if let`, `guard let`)
- Use nil-coalescing operator (`??`)
- Add proper error handling

### 4. Legacy Multiple (7 violations)
Update deprecated APIs:
- Check for NSObject legacy methods
- Update to modern Swift equivalents

### 5. Deprecated NSApp (7 violations)
Replace direct NSApp usage:
- Use `NSApplication.shared` instead of `NSApp`
- Already configured in custom rules

## Code Quality Improvements

### Type Contents Order (198 violations)
Reorganize type members according to Swift conventions:
1. Type aliases
2. Subtypes
3. Properties
4. Initializers
5. Methods

### Switch Case Formatting (67 violations)
Add newlines after case statements for readability

### Force Unwrapping (39 violations)
Critical for safety - review each instance

## Auto-fixable Issues

Run SwiftLint with fix flag for specific rules:
```bash
swiftlint --fix --only trailing_whitespace,opening_brace
```

## Xcode Integration

Add to Build Phases:
```bash
if which swiftlint > /dev/null; then
    swiftlint
else
    echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

## CI/CD Integration

Add to GitHub Actions:
```yaml
- name: SwiftLint
  run: |
    brew install swiftlint
    swiftlint --strict --reporter github-actions-logging
```

## Priority Order

1. **High Priority** (Deprecated Syntax):
   - String format (28) - functional impact
   - Print statements (11) - production code quality

2. **Medium Priority** (Safety):
   - Force unwrapping (39) - crash risk
   - Force cast (6) - type safety

3. **Low Priority** (Style):
   - Type contents order (198)
   - Switch formatting (67)
   - Other style violations

## Estimated Time

- Automated fixes: 5 minutes
- Manual deprecated syntax fixes: 30 minutes
- Force unwrapping review: 45 minutes
- Full compliance: 2-3 hours