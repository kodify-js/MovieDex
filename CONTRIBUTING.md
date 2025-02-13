# Contributing to MovieDex

Thank you for your interest in contributing to MovieDex! This document provides guidelines and information about contributing to the project.

## Project Structure

```
MovieDex/
├── lib/
│   ├── api/                    # API related code
│   │   ├── class/             # Data models and classes
│   │   ├── contentproviders/  # Streaming providers implementation
│   │   ├── models/           # Database models
│   │   └── utils.dart        # Common utilities
│   ├── components/           # Reusable UI components
│   ├── pages/               # Application screens
│   │   ├── auth/           # Authentication screens
│   │   └── ...            # Other screens
│   ├── providers/         # State management
│   ├── services/         # Business logic services
│   ├── utils/           # Helper functions
│   └── main.dart        # Application entry point
├── assets/             # Static assets (images, fonts)
├── android/           # Android specific files
├── ios/              # iOS specific files
└── test/            # Unit and widget tests
```

## Key Components

1. **API Layer (`/lib/api/`)**
   - `contentproviders/`: Implements different streaming sources
   - `class/`: Core data models
   - `models/`: Database models for local storage
   - `utils.dart`: Common API utilities

2. **UI Components (`/lib/components/`)**
   - Reusable widgets
   - Custom UI elements
   - Player components

3. **Services (`/lib/services/`)**
   - `firebase_service.dart`: Authentication handling
   - `cache_service.dart`: Local caching
   - `watch_history_service.dart`: History tracking
   - `proxy_service.dart`: Proxy management

4. **State Management (`/lib/providers/`)**
   - Theme management
   - State providers

## Getting Started

1. Fork the repository
2. Clone your fork:
```bash
git clone https://github.com/kodify-js/MovieDex-Flutter.git
```

3. Set up development environment:
```bash
flutter pub get
flutter pub run build_runner build
```

4. Create a feature branch:
```bash
git checkout -b feature/your-feature-name
```

## Development Guidelines

1. **Code Style**
   - Follow Flutter/Dart style guidelines
   - Use meaningful variable names
   - Add documentation for public APIs
   - Keep methods focused and concise

2. **Commit Messages**
   - Use clear, descriptive commit messages
   - Format: `type(scope): description`
   - Example: `feat(player): add quality selection`

3. **Testing**
   - Add tests for new features
   - Ensure existing tests pass
   - Test on multiple devices

4. **Documentation**
   - Update README if needed
   - Add inline documentation
   - Include example usage

## Pull Request Process

1. Update your fork with the latest changes
2. Ensure tests pass locally
3. Create a pull request with:
   - Clear description
   - Screenshots/videos if UI changes
   - List of changes
   - Tests if applicable

## Code Review

- Changes will be reviewed by maintainers
- Address review comments
- Keep discussions constructive
- Be patient and respectful


