# MovieDex - Open Source Movie Streaming App

<p align="center">
  <img src="assets/images/screenshot-1.jpg" alt="MovieDex">
</p>

MovieDex is a Flutter-based movie and TV show streaming application that provides a beautiful user interface and rich features for streaming enthusiasts.

## Features

- 🎬 Movie & TV Show Streaming
- 🔍 Advanced Search
- 📱 Responsive Design
- 🌙 Dark/AMOLED Theme
- 📋 Watchlist Management
- 🔐 User Authentication
- 🔄 Cloud Sync
- 📺 Multiple Video Quality
- 🌐 Proxy Support

## Screenshots

<table>
  <tr>
    <td align="center">
        <img src="assets/images/screenshot-2.jpg" width="200px;" alt=""/>
    </td>
    <td align="center">
        <img src="assets/images/screenshot-3.jpeg" width="200px;" alt=""/>
    </td>
    <td align="center">
        <img src="assets/images/screenshot-4.jpeg" width="200px;" alt=""/>
    </td>
  </tr>
  <tr>
    <td align="center">
        <img src="assets/images/screenshot-5.jpeg" width="200px;" alt=""/>
    </td>
    <td align="center">
        <img src="assets/images/screenshot-6.jpeg" width="200px;" alt=""/>
    </td>
    <td align="center">
        <img src="assets/images/screenshot-8.jpeg" width="200px;" alt=""/>
    </td>
  </tr>
</table>

## Desktop Screenshots

<table>
  <tr>
    <td align="center">
        <img src="assets/images/desktop-screenshot-1.png" alt="Desktop Home"/>
    </td>
  <tr>
    <td align="center">
        <img src="assets/images/desktop-screenshot-2.png" alt="Desktop Player"/>
    </td>
  </tr>
</table>

## Setup Instructions

### Prerequisites
- Flutter SDK (3.0 or higher)
- Dart SDK
- Android Studio / VS Code
- Git

### Installation Steps

1. Clone the repository:
```bash
git clone https://github.com/kodify-js/MovieDex.git
cd MovieDex
```

2. Install dependencies:
```bash
flutter pub get
```

3. Setup TMDB API:
   - Sign up at [TMDB](https://www.themoviedb.org/signup)
   - Get your API key from [API Settings](https://www.themoviedb.org/settings/api)
   - Create `lib/api/secrets.dart`:
```dart
const String apiKey = 'YOUR_TMDB_API_KEY';
```

4. Appwrite Setup:
   - Create a new Appwrite project at [Appwrite Console](https://cloud.appwrite.io/)
   - Create a new platform for Flutter in your project settings
   - Update `lib/api/secrets.dart` with your Appwrite credentials:
```dart
// TMDB API Key
const String apiKey = 'YOUR_TMDB_API_KEY';

// Appwrite Credentials
const projectId = "<YOUR Appwrite project Id>";
const databaseId = "<YOUR Appwrite database Id>";
const watchHistoryCollection = "<YOUR Appwrite  watchHistoryCollection Id>";
const userListCollection = "<YOUR Appwrite userListCollection Id>";
const mixpanelToken = "<YOUR Mixpanel Token>";

```
   - Create `lib/services/appwrite_service.dart`:

5. Generate Hive Adapters:
```bash
flutter pub run build_runner build
```

6. Run the app:
```bash
flutter run
```

## Configuration

### Appwrite Setup Details
1. Go to [Appwrite Console](https://cloud.appwrite.io/)
2. Create a new project
3. Add Flutter platform:
   - Go to your project settings
   - Click on 'Add Platform'
   - Choose 'Flutter App'
   - Add your app's package name (e.g., `com.kodify.moviedex`)
4. Enable Authentication:
   - Go to Auth > Settings
   - Enable Email/Password sign-in method
5. Setup Database:
   - Create a new database
   - Create necessary collections (watchlist, user_preferences)
   - Set up appropriate attributes and indexes
   - Configure read/write permissions

### TMDB API Setup
1. Create account on [TMDB](https://www.themoviedb.org/)
2. Request an API key
3. open `secrets.dart`:
```dart
const String apiKey = 'YOUR_API_KEY';
```

## Contributing

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

## Acknowledgments

- [TMDB](https://www.themoviedb.org/) for providing the movie database
- [Flutter](https://flutter.dev/) for the amazing framework
- [Appwrite](https://appwrite.io/) for backend services

## Support

If you find this project helpful, please give it a ⭐️!

For help getting started with Flutter development, view the
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Contributors

### Core Team

- **[KodifyJs](https://github.com/kodify-js)** - *Project Lead*
  - Core architecture
  - Video player implementation
  - Content providers

### Contributors


<a href="https://github.com/Kodify-js/Moviedex/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=Kodify-js/Moviedex" />
</a>


## Project Structure

Key features and their locations:

```
lib/
├── api/              # API and data layer
├── components/       # Reusable UI components
├── pages/           # Application screens
├── providers/       # State management
├── services/        # Business logic
└── utils/          # Helper functions
```

### Key Files

- `lib/api/contentproviders/` - Streaming source implementations
- `lib/components/content_player.dart` - Video player component
- `lib/services/watch_history_service.dart` - History tracking
- `lib/services/appwrite_service.dart` - Authentication
- `lib/services/cache_service.dart` - Local caching

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed project structure and contribution guidelines.

### DMCA disclaimer
The developers of this application do not have any affiliation with the content available in the app. It collects content from sources that are freely available through any web browser.
