# Contributing to Hur Delivery

Thank you for your interest in contributing to Hur Delivery! This document provides guidelines and instructions for contributing to the project.

## 🚀 Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/hur-delivery.git
   cd hur-delivery
   ```
3. **Create a branch** for your feature or fix:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## 📋 Development Setup

### Prerequisites
- Flutter SDK 3.4.4+
- Dart SDK 3.0.0+
- Node.js 16+ (for website/admin panel)
- Supabase account
- Firebase account
- Mapbox account

### Environment Setup

1. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

2. **Set up environment variables**:
   ```bash
   cp env.example .env
   # Edit .env with your credentials
   ```

3. **Configure Firebase**:
   - Add `google-services.json` to `android/app/`
   - Add `GoogleService-Info.plist` to `ios/Runner/`

4. **Run the app**:
   ```bash
   flutter run
   ```

## 🎯 Code Style

### Dart/Flutter
- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` to check for issues
- Format code with `dart format .`
- Maximum line length: 80 characters
- Use meaningful variable and function names
- Add comments for complex logic

### JavaScript (Admin Panel & Website)
- Use ES6+ features
- Use `const` and `let` instead of `var`
- Use arrow functions where appropriate
- Add JSDoc comments for functions
- Follow consistent indentation (2 spaces)

### Naming Conventions
- **Files**: `snake_case.dart`, `kebab-case.js`
- **Classes**: `PascalCase`
- **Functions/Variables**: `camelCase`
- **Constants**: `UPPER_SNAKE_CASE`
- **Private members**: `_leadingUnderscore`

## 📝 Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, etc.)
- **refactor**: Code refactoring
- **test**: Adding or updating tests
- **chore**: Maintenance tasks

### Examples
```
feat(auth): add phone number verification

Implemented OTP-based phone verification for Iraqi numbers (+964)
using Supabase authentication.

Closes #123
```

```
fix(orders): resolve order assignment race condition

Fixed a race condition where multiple drivers could be assigned
to the same order simultaneously.

Fixes #456
```

## 🧪 Testing

### Running Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/features/auth/auth_test.dart

# Run with coverage
flutter test --coverage
```

### Writing Tests
- Write unit tests for business logic
- Write widget tests for UI components
- Write integration tests for critical flows
- Aim for >80% code coverage
- Mock external dependencies (Supabase, Firebase, etc.)

### Test Structure
```dart
void main() {
  group('Feature Name', () {
    setUp(() {
      // Setup code
    });

    tearDown(() {
      // Cleanup code
    });

    test('should do something specific', () {
      // Arrange
      // Act
      // Assert
    });
  });
}
```

## 🐛 Bug Reports

When reporting bugs, please include:

1. **Description**: Clear description of the bug
2. **Steps to Reproduce**: Detailed steps to reproduce the issue
3. **Expected Behavior**: What should happen
4. **Actual Behavior**: What actually happens
5. **Screenshots**: If applicable
6. **Environment**:
   - Flutter version
   - Dart version
   - Device/OS
   - App version

### Bug Report Template
```markdown
## Description
Brief description of the bug

## Steps to Reproduce
1. Go to '...'
2. Click on '...'
3. Scroll down to '...'
4. See error

## Expected Behavior
What you expected to happen

## Actual Behavior
What actually happened

## Screenshots
If applicable, add screenshots

## Environment
- Flutter version: 3.4.4
- Dart version: 3.0.0
- Device: iPhone 14 Pro
- OS: iOS 17.0
- App version: 1.0.4
```

## 💡 Feature Requests

When requesting features, please include:

1. **Problem Statement**: What problem does this solve?
2. **Proposed Solution**: How should it work?
3. **Alternatives**: Other solutions you've considered
4. **Additional Context**: Any other relevant information

## 🔄 Pull Request Process

1. **Update your fork**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Make your changes**:
   - Write clean, well-documented code
   - Follow code style guidelines
   - Add tests for new features
   - Update documentation as needed

3. **Test your changes**:
   ```bash
   flutter analyze
   flutter test
   flutter build apk --debug
   ```

4. **Commit your changes**:
   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```

5. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create a Pull Request**:
   - Go to the original repository
   - Click "New Pull Request"
   - Select your fork and branch
   - Fill in the PR template
   - Submit for review

### Pull Request Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Widget tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings
- [ ] Tests pass locally

## Screenshots (if applicable)
Add screenshots here

## Related Issues
Closes #123
```

## 📚 Documentation

- Update README.md for significant changes
- Add inline comments for complex logic
- Update API documentation
- Add examples for new features
- Keep documentation in sync with code

## 🔒 Security

- **Never commit sensitive data**:
  - API keys
  - Passwords
  - Private keys
  - Credentials
  - `.env` files

- **Report security vulnerabilities** privately:
  - Email: security@hur.delivery
  - Do not create public issues for security bugs

## 🌍 Internationalization

- All user-facing text must support Arabic and English
- Use the `intl` package for localization
- Add translations to `lib/l10n/`
- Test RTL layout for Arabic

## 📱 Platform-Specific Guidelines

### Android
- Test on Android 7.0+ (API 24+)
- Follow Material Design guidelines
- Test on different screen sizes
- Optimize for performance

### iOS
- Test on iOS 12.0+
- Follow Human Interface Guidelines
- Test on different iPhone models
- Handle safe areas properly

## 🎨 UI/UX Guidelines

- Follow the existing design system
- Maintain consistency with current UI
- Support both light and dark themes (if applicable)
- Ensure accessibility (screen readers, contrast, etc.)
- Test on different screen sizes
- Optimize for RTL layout

## 📊 Performance

- Optimize images and assets
- Minimize network requests
- Use lazy loading where appropriate
- Profile app performance
- Monitor memory usage
- Optimize build size

## 🤝 Code Review

All submissions require review. We use GitHub pull requests for this purpose.

### Review Checklist
- Code quality and style
- Test coverage
- Documentation
- Performance impact
- Security considerations
- Breaking changes

## 📞 Getting Help

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and discussions
- **Email**: support@hur.delivery

## 🙏 Thank You

Thank you for contributing to Hur Delivery! Your efforts help make this project better for everyone.

---

**حر - خدمة التوصيل السريع** 🚚

