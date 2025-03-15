import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:moviedex/providers/theme_provider.dart';
import 'package:moviedex/services/appwrite_service.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:moviedex/services/cache_service.dart';
import 'package:moviedex/services/settings_service.dart';
import 'package:moviedex/services/proxy_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:moviedex/services/update_service.dart';
import 'dart:io';
import 'package:flutter_markdown/flutter_markdown.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _proxyController = TextEditingController();
  late Box _settingsBox;
  bool _useCustomProxy = false;
  bool _autoPlayNext = true;
  String _selectedTheme = 'system';
  String _selectedAccentColor = 'blue';
  String _defaultQuality = 'Auto';
  String _version = '';
  final String _repoOwner = 'kodify-js';
  final String _repoName = 'MovieDex';
  Map<String, dynamic>? _repoInfo;
  Map<String, dynamic>? _maintainerInfo;
  final List<Map<String, String>> _fonts = [
    {'name': 'Inter', 'displayName': 'Inter (Default)'},
    {'name': 'Roboto', 'displayName': 'Roboto'},
    {'name': 'Poppins', 'displayName': 'Poppins'},
    {'name': 'Open Sans', 'displayName': 'Open Sans'},
    {'name': 'Lato', 'displayName': 'Lato'},
    {'name': 'Montserrat', 'displayName': 'Montserrat'},
  ];
  final CacheService _cacheService = CacheService.instance;
  Duration _cacheValidity = const Duration(days: 1);
  int _cacheSize = 0;
  bool _syncEnabled = true;
  bool _incognitoMode = false;
  bool _isValidatingProxy = false;
  bool _isProxyValid = false;
  bool _showUpdateDialog = true;
  bool _isCheckingForUpdates = false;
  bool _isCheckingUpdate = false; // Add this variable
  String? _latestVersion;
  Map<String, dynamic>? _latestRelease;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      setState(() => _version = info.version);
    });
    _initializeSettings();
    _fetchGitHubInfo();
    _loadCacheInfo();
    _loadSettings();

    // Add listener for login state changes
    AppwriteService.instance.isLoggedIn().then((isLoggedIn) {
      if (!isLoggedIn) {
        setState(() {
          _syncEnabled = false;
        });
      }
    });
  }

  Future<void> _initializeSettings() async {
    final settingsService = SettingsService.instance;
    await settingsService.init();

    // Get initial state from SettingsService
    setState(() {
      _incognitoMode = settingsService.isIncognito;
      _syncEnabled = settingsService.isSyncEnabled;
    });

    // Listen to incognito mode changes
    settingsService.incognitoStream.listen((value) {
      if (mounted) {
        setState(() {
          _incognitoMode = value;
          _syncEnabled = value ? false : settingsService.isSyncEnabled;
        });
      }
    });
  }

  Future<void> _initSettings() async {
    _settingsBox = await Hive.openBox('settings');
    setState(() {
      _defaultQuality =
          _settingsBox.get('defaultQuality', defaultValue: 'Auto');
      _useCustomProxy = _settingsBox.get('useCustomProxy', defaultValue: false);
      _proxyController.text = _settingsBox.get('proxyUrl', defaultValue: '');
      _autoPlayNext = _settingsBox.get('autoPlayNext', defaultValue: true);
      _selectedTheme = _settingsBox.get('theme', defaultValue: 'system');
      _selectedAccentColor =
          _settingsBox.get('accentColor', defaultValue: 'blue');
      _syncEnabled = _settingsBox.get('syncEnabled', defaultValue: true);
      _incognitoMode = _settingsBox.get('incognitoMode', defaultValue: false);
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  Future<void> _fetchGitHubInfo() async {
    try {
      // Fetch repo information
      final repoResponse = await http.get(
        Uri.parse('https://api.github.com/repos/$_repoOwner/$_repoName'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      // Fetch maintainer information
      final maintainerResponse = await http.get(
        Uri.parse('https://api.github.com/users/$_repoOwner'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (repoResponse.statusCode == 200 &&
          maintainerResponse.statusCode == 200) {
        setState(() {
          _repoInfo = json.decode(repoResponse.body);
          _maintainerInfo = json.decode(maintainerResponse.body);
        });
      }
    } catch (e) {
      return;
    }
  }

  Future<void> _loadCacheInfo() async {
    final size = await _cacheService.getCacheSize();
    setState(() {
      _cacheSize = size;
      _cacheValidity = _settingsBox
          .get('cacheValidity', defaultValue: const Duration(days: 1).inMinutes)
          .toInt()
          .minutes;
    });
  }

  @override
  void dispose() {
    _proxyController.dispose();
    super.dispose();
  }

  Future<void> _validateAndSaveProxy(String value) async {
    if (value.isEmpty) {
      await _saveSetting('proxyUrl', '');
      return;
    }

    setState(() {
      _isValidatingProxy = true;
    });

    final isValid = await ProxyService.instance.validateProxy(value);

    if (mounted) {
      setState(() {
        _isValidatingProxy = false;
        _isProxyValid = isValid;
      });

      if (isValid) {
        await _saveSetting('proxyUrl', value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proxy configured successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid proxy. Please check the URL and try again.'),
            backgroundColor: Colors.red,
          ),
        );
        await _saveSetting('useCustomProxy', false);
        setState(() {
          _useCustomProxy = false;
        });
      }
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingForUpdates) return;

    setState(() => _isCheckingForUpdates = true);
    try {
      final updateAvailable = await UpdateService.instance.checkForUpdate();

      if (!mounted) return;

      if (updateAvailable) {
        _latestRelease = await UpdateService.instance.getLatestRelease();
        _latestVersion = _latestRelease!['tag_name']
            .toString()
            .replaceAll('v', '')
            .split('-')
            .first;
        _showUpdateAvailableDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have the latest version')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking for updates: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingForUpdates = false);
      }
    }
  }

  void _showUpdateAvailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version $_latestVersion is available'),
              const SizedBox(height: 16),
              if (_latestRelease != null && _latestRelease!['body'] != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: Markdown(
                      data: _latestRelease!['body'] ??
                          'No release notes available',
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color),
                        strong: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        h1: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                        h2: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleMedium?.color,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              UpdateService.instance.launchUpdate();
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  void _showWhatsNew() {
    if (_latestRelease == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('What\'s New in $_latestVersion'),
        content: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          width: double.maxFinite,
          child: Markdown(
            data: _latestRelease!['body'] ?? 'No release notes available',
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color),
              strong: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              h1: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
              h2: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingSection(String title, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Divider(
            height: 1,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'MovieDex',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Version $_version',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Open Source Movie Streaming App',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          if (_maintainerInfo != null) ...[
            const SizedBox(height: 8),
            _buildMaintainerInfo(),
          ],
          if (_repoInfo != null) ...[
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildGitHubStat(
                    Icons.star_rounded,
                    '${_repoInfo!['stargazers_count']}',
                    'Stars',
                    Theme.of(context).colorScheme.primary,
                  ),
                  _buildDivider(),
                  _buildGitHubStat(
                    Icons.call_split_rounded,
                    '${_repoInfo!['forks_count']}',
                    'Forks',
                    Colors.green,
                  ),
                  _buildDivider(),
                  _buildGitHubStat(
                    Icons.remove_red_eye_rounded,
                    '${_repoInfo!['watchers_count']}',
                    'Watchers',
                    Colors.purple,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildActionButton(
                  'View on GitHub',
                  Icons.code_rounded,
                  () => _launchUrl('https://github.com/$_repoOwner/$_repoName'),
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  'Report Issue',
                  Icons.bug_report_outlined,
                  () => _launchUrl(
                      'https://github.com/$_repoOwner/$_repoName/issues'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildGitHubStat(
      IconData icon, String count, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.7),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildMaintainerInfo() {
    if (_maintainerInfo == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'MAINTAINED BY',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _launchUrl(_maintainerInfo!['html_url']),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      _maintainerInfo!['avatar_url'],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _maintainerInfo!['name'] ?? _maintainerInfo!['login'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_maintainerInfo!['bio'] != null)
                        Text(
                          _maintainerInfo!['bio'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadSection() {
    return FutureBuilder<String>(
      future: SettingsService.instance.downloadPath,
      builder: (context, snapshot) {
        final path = snapshot.data ?? 'Loading...';
        return _buildSettingSection(
          'Downloads',
          [
            ListTile(
              title: Text('Download Location',
                  style: Theme.of(context).textTheme.bodyLarge),
              subtitle: Text(
                path,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.folder_open),
                onPressed: _selectDownloadPath,
              ),
            ),
            // ...other download settings...
          ],
        );
      },
    );
  }

  Future<void> _selectDownloadPath() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Download Directory',
      );

      if (selectedDirectory != null) {
        final dir = Directory(selectedDirectory);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        // Save the new path
        await SettingsService.instance.setDownloadPath(selectedDirectory);

        if (mounted) {
          setState(() {}); // Refresh UI
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download location updated')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting download path: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildPrivacySection(),
          _buildAppearanceSection(),
          _buildCacheSection(),
          _buildSettingSection(
            'Video Player',
            [
              SwitchListTile(
                title: Text('Auto Play Next Episode',
                    style: Theme.of(context).textTheme.bodyLarge),
                subtitle: Text('Automatically play next episode in series',
                    style: Theme.of(context).textTheme.bodyMedium),
                value: _autoPlayNext,
                onChanged: (value) {
                  setState(() => _autoPlayNext = value);
                  _saveSetting('autoPlayNext', value);
                },
              ),
              ListTile(
                title: Text('Default Quality',
                    style: Theme.of(context).textTheme.bodyLarge),
                subtitle: Text(_defaultQuality,
                    style: Theme.of(context).textTheme.bodyMedium),
                onTap: () => _showQualitySelector(),
              ),
            ],
          ),
          _buildAdvancedSection(),
          _buildDownloadSection(),
          _buildAboutSection(),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return _buildSettingSection(
      'Appearance',
      [
        SwitchListTile(
          title: Text('AMOLED Dark Mode',
              style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text('Pure black dark mode for OLED displays',
              style: Theme.of(context).textTheme.bodyMedium),
          value: themeProvider.amoledMode,
          onChanged: (value) => themeProvider.setAmoledMode(value),
        ),
        ListTile(
          title:
              Text('Theme Color', style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text('Choose your preferred color',
              style: Theme.of(context).textTheme.bodyMedium),
          trailing: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: themeProvider.accentColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
          ),
          onTap: _showColorPicker,
        ),
        ListTile(
          title: Text('Font', style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text(
            _fonts.firstWhere((f) => f['name'] == themeProvider.fontFamily,
                orElse: () => _fonts.first)['displayName']!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          onTap: _showFontSelector,
        ),
      ],
    );
  }

  void _showColorPicker() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final predefinedColors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme Color'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...predefinedColors.map((color) => InkWell(
                        onTap: () {
                          themeProvider.setAccentColor(color);
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: themeProvider.accentColor == color
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      )),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Or pick a custom color'),
              ),
              ColorPicker(
                pickerColor: themeProvider.accentColor,
                onColorChanged: (color) => themeProvider.setAccentColor(color),
                enableAlpha: false,
                labelTypes: const [],
                pickerAreaHeightPercent: 0.7,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showQualitySelector() {
    final qualities = ['Auto', '1080p', '720p', '480p', '360p'];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: qualities
              .map((quality) => ListTile(
                    title: Text(quality,
                        style: const TextStyle(color: Colors.white)),
                    selected: _defaultQuality == quality,
                    selectedTileColor: Colors.white.withOpacity(0.1),
                    onTap: () {
                      setState(() => _defaultQuality = quality);
                      _saveSetting('defaultQuality', quality);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showFontSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Font',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.1)),
            Expanded(
              child: ListView.builder(
                itemCount: _fonts.length,
                itemBuilder: (context, index) {
                  final font = _fonts[index];
                  final isSelected = themeProvider.fontFamily == font['name'];

                  return ListTile(
                    title: Text(
                      font['displayName']!,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: font['name'],
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'The quick brown fox jumps over the lazy dog',
                      style: TextStyle(
                        color: Colors.white70,
                        fontFamily: font['name'],
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: Colors.white.withOpacity(0.1),
                    trailing: isSelected
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      themeProvider.setFontFamily(font['name']!);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheSection() {
    String formatSize(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024)
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }

    return _buildSettingSection(
      'Cache',
      [
        ListTile(
          title:
              Text('Cache Size', style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text(
            formatSize(_cacheSize),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          trailing: TextButton(
            onPressed: () async {
              await _cacheService.clearCache();
              _loadCacheInfo(); // Reload cache size after clearing
            },
            child: const Text('Clear Cache'),
          ),
        ),
        ListTile(
          title: Text(
            'Cache Duration',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          subtitle: Text(
            '${_cacheValidity.inHours} hours',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          onTap: _showCacheDurationSelector,
        ),
      ],
    );
  }

  void _showCacheDurationSelector() {
    final durations = [
      {'label': '1 hour', 'duration': const Duration(hours: 1)},
      {'label': '6 hours', 'duration': const Duration(hours: 6)},
      {'label': '12 hours', 'duration': const Duration(hours: 12)},
      {'label': '1 day', 'duration': const Duration(days: 1)},
      {'label': '3 days', 'duration': const Duration(days: 3)},
      {'label': '1 week', 'duration': const Duration(days: 7)},
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Cache Duration',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.1)),
            ...durations
                .map((option) => ListTile(
                      title: Text(
                        option['label'] as String,
                        style: const TextStyle(color: Colors.white),
                      ),
                      selected: _cacheValidity == option['duration'],
                      selectedTileColor: Colors.white.withOpacity(0.1),
                      onTap: () {
                        setState(() =>
                            _cacheValidity = option['duration'] as Duration);
                        _settingsBox.put(
                            'cacheValidity', _cacheValidity.inMinutes);
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySection() {
    final settingsService = SettingsService.instance;

    return FutureBuilder<bool>(
      future: AppwriteService.instance.isLoggedIn(),
      builder: (context, snapshot) {
        final bool isUserLoggedIn = snapshot.data ?? false;

        return _buildSettingSection(
          'Privacy & Data',
          [
            SwitchListTile(
              title: Text('Sync Data',
                  style: Theme.of(context).textTheme.bodyLarge),
              subtitle: Text(
                  _incognitoMode
                      ? 'Sync is disabled in incognito mode'
                      : isUserLoggedIn
                          ? 'Sync your watch history and preferences across devices'
                          : 'Login required to enable sync',
                  style: Theme.of(context).textTheme.bodyMedium),
              value: isUserLoggedIn && _syncEnabled && !_incognitoMode,
              onChanged: isUserLoggedIn && !_incognitoMode
                  ? (value) async {
                      await settingsService.setSyncEnabled(value);
                      setState(() => _syncEnabled = value);
                    }
                  : null,
            ),
            SwitchListTile(
              title: Text('Incognito Mode',
                  style: Theme.of(context).textTheme.bodyLarge),
              subtitle: Text('Browse without saving history or preferences',
                  style: Theme.of(context).textTheme.bodyMedium),
              value: settingsService.isIncognito,
              onChanged: (value) async {
                await settingsService.setIncognitoMode(value);
                if (value) {
                  _showIncognitoWarning();
                }
              },
            ),
            if (_incognitoMode)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Clear All Local Data',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.red,
                        )),
                onTap: () => _showClearDataConfirmation(),
              ),
          ],
        );
      },
    );
  }

  void _showIncognitoWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person_off_rounded, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Incognito Mode'),
          ],
        ),
        content: const Text('While in incognito mode:\n'
            '• Watch history won\'t be saved\n'
            '• Preferences won\'t be stored\n'
            '• Data won\'t be synced\n'
            '• My List will be temporarily disabled\n\n'
            'This will apply until you disable incognito mode.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearDataConfirmation() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Local Data?'),
        content: const Text('This will permanently delete all your:\n'
            '• Watch history\n'
            '• Preferences\n'
            '• Saved settings\n\n'
            'This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () async {
              await _settingsBox.clear();
              await _cacheService.clear();
              // Re-initialize settings with defaults
              await _initSettings();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All local data cleared')),
                );
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return _buildSettingSection(
      'Advanced',
      [
        SwitchListTile(
          title: Text('Use Custom Proxy',
              style: Theme.of(context).textTheme.bodyLarge),
          value: _useCustomProxy,
          onChanged: (value) async {
            if (!value || _proxyController.text.isEmpty) {
              setState(() => _useCustomProxy = value);
              await _saveSetting('useCustomProxy', value);
            } else {
              // Validate proxy before enabling
              await _validateAndSaveProxy(_proxyController.text);
            }
          },
        ),
        if (_useCustomProxy)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _proxyController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Proxy URL',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    suffixIcon: _isValidatingProxy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.check_circle),
                            onPressed: () =>
                                _validateAndSaveProxy(_proxyController.text),
                          ),
                  ),
                  onSubmitted: _validateAndSaveProxy,
                ),
                const SizedBox(height: 8),
                Text(
                  'Example: http://proxy.example.com:8080',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        const Divider(),
        SwitchListTile(
          title: Text('Show Update Dialog',
              style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text('Show dialog when updates are available',
              style: Theme.of(context).textTheme.bodyMedium),
          value: _showUpdateDialog,
          onChanged: (value) async {
            setState(() => _showUpdateDialog = value);
            await SettingsService.instance.setShowUpdateDialog(value);
          },
        ),
        ListTile(
          title: Text('Check for Updates',
              style: Theme.of(context).textTheme.bodyLarge),
          trailing: _isCheckingForUpdates
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.system_update),
          onTap: _isCheckingForUpdates ? null : _checkForUpdates,
        ),
        if (_latestVersion != null)
          ListTile(
            title: Text('What\'s New',
                style: Theme.of(context).textTheme.bodyLarge),
            trailing: const Icon(Icons.new_releases),
            onTap: _showWhatsNew,
          ),
      ],
    );
  }

  Future<void> _loadSettings() async {
    final settings = SettingsService.instance;
    await settings.init();
    setState(() {
      _showUpdateDialog = settings.showUpdateDialog;
      // ...other settings loading...
    });
  }

  Future<void> _handleCheckForUpdates() async {
    setState(() => _isCheckingUpdate = true);

    try {
      final update = await UpdateService.instance.checkForUpdate();
      if (!mounted) return;
      setState(() => _isCheckingUpdate = false);

      if (update) {
        final latestRelease = await UpdateService.instance.getLatestRelease();
        if (latestRelease != null) {
          await _showUpdateDetailsDialog(
              latestRelease); // Rename this method call
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to get update information')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You are already on the latest version')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingUpdate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking for updates: ${e.toString()}')),
      );
    }
  }

  Future<void> _showUpdateDetailsDialog(Map<String, dynamic> update) async {
    // Renamed method
    if (!mounted) return;

    final currentVersion = _version;
    final newVersion =
        update['tag_name']?.toString().replaceAll("v", "").split("-")[0] ?? '';
    final hasChangelog = update['body']?.toString().isNotEmpty ?? false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A new version of MovieDex is available!'),
              const SizedBox(height: 8),
              Text(
                'Current version: $currentVersion\nNew version: $newVersion',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (hasChangelog) ...[
                const SizedBox(height: 16),
                const Text('What\'s new:'),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Markdown(
                      data: update['body']?.toString() ?? '',
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 14, color: Colors.white),
                        strong: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        h1: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        h2: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        a: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline),
                        listBullet: const TextStyle(color: Colors.white),
                      ),
                      onTapLink: (text, href, title) {
                        if (href != null) {
                          launchUrl(Uri.parse(href),
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => _handleUpdate(update, context),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdate(
      Map<String, dynamic> update, BuildContext context) async {
    try {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Downloading update...'),
            ],
          ),
        ),
      );

      final downloadUrl = update['assets'].first['browser_download_url'];
      final tagName = update['tag_name']?.toString() ?? '';

      // Check if this is an update that might cause package conflicts
      bool isConflictPossible = false;
      try {
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final String currentVersion = packageInfo.version;

        // Major version change might indicate package structure changes
        List<int> currentVersionParts =
            currentVersion.split('.').map(int.parse).toList();
        String newVersionCleaned = tagName.replaceAll('v', '').split('-')[0];
        List<int> newVersionParts =
            newVersionCleaned.split('.').map(int.parse).toList();

        // Check if major or minor version changed
        if (newVersionParts[0] > currentVersionParts[0] ||
            (newVersionParts[0] == currentVersionParts[0] &&
                newVersionParts[1] > currentVersionParts[1])) {
          isConflictPossible = true;
        }
      } catch (e) {
        // If we can't determine, assume conflict is possible
        isConflictPossible = true;
      }

      if (isConflictPossible && Platform.isAndroid) {
        // On Android, suggest uninstall and reinstall for major updates
        if (!mounted) return;
        Navigator.pop(context); // Close progress dialog

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Update Method'),
            content: const Text(
                'This update might conflict with your existing app. Would you like to:'),
            actions: [
              TextButton(
                onPressed: () async {
                  // Try direct update anyway
                  Navigator.pop(context);
                  await _proceedWithDirectUpdate(downloadUrl, tagName);
                },
                child: const Text('Try Direct Update'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Open browser for manual download
                  final Uri url = Uri.parse(downloadUrl);
                  await launchUrl(url, mode: LaunchMode.externalApplication);

                  if (!mounted) return;
                  Navigator.pop(context); // Close update dialog

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Please uninstall the current app before installing the new version'),
                      duration: Duration(seconds: 8),
                    ),
                  );
                },
                child: const Text('Manual Download'),
              ),
            ],
          ),
        );
      } else {
        // Direct update for iOS or non-major Android updates
        await _proceedWithDirectUpdate(downloadUrl, tagName);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog
      Navigator.pop(context); // Close update dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _proceedWithDirectUpdate(
      String downloadUrl, String tagName) async {
    await UpdateService.instance.downloadAndInstallUpdate(
      downloadUrl,
      tagName,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close progress dialog
    Navigator.pop(context); // Close update dialog

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Update downloaded. Installing...')),
    );
  }
}
