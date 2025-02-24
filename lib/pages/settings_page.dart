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
import 'dart:io';

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

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      setState(() => _version = info.version);
    });
    _initializeSettings();
    _fetchGitHubInfo();
    _loadCacheInfo();
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
      _defaultQuality = _settingsBox.get('defaultQuality', defaultValue: 'Auto');
      _useCustomProxy = _settingsBox.get('useCustomProxy', defaultValue: false);
      _proxyController.text = _settingsBox.get('proxyUrl', defaultValue: '');
      _autoPlayNext = _settingsBox.get('autoPlayNext', defaultValue: true);
      _selectedTheme = _settingsBox.get('theme', defaultValue: 'system');
      _selectedAccentColor = _settingsBox.get('accentColor', defaultValue: 'blue');
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

      if (repoResponse.statusCode == 200 && maintainerResponse.statusCode == 200) {
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
      _cacheValidity = _settingsBox.get(
        'cacheValidity', 
        defaultValue: const Duration(days: 1).inMinutes
      ).toInt().minutes;
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                  () => _launchUrl('https://github.com/$_repoOwner/$_repoName/issues'),
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

  Widget _buildGitHubStat(IconData icon, String count, String label, Color color) {
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
    return _buildSettingSection(
      'Downloads',
      [
        ListTile(
          title: Text('Download Location', style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text(
            SettingsService.instance.downloadPath,
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
                subtitle: Text(
                  'Automatically play next episode in series',
                  style: Theme.of(context).textTheme.bodyMedium
                ),
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
          title: Text('AMOLED Dark Mode', style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text('Pure black dark mode for OLED displays',
            style: Theme.of(context).textTheme.bodyMedium),
          value: themeProvider.amoledMode,
          onChanged: (value) => themeProvider.setAmoledMode(value),
        ),
        ListTile(
          title: Text('Theme Color', style: Theme.of(context).textTheme.bodyLarge),
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
            _fonts.firstWhere(
              (f) => f['name'] == themeProvider.fontFamily, 
              orElse: () => _fonts.first
            )['displayName']!,
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
          children: qualities.map((quality) => ListTile(
            title: Text(quality, 
              style: const TextStyle(color: Colors.white)),
            selected: _defaultQuality == quality,
            selectedTileColor: Colors.white.withOpacity(0.1),
            onTap: () {
              setState(() => _defaultQuality = quality);
              _saveSetting('defaultQuality', quality);
              Navigator.pop(context);
            },
          )).toList(),
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
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
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
      if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }

    return _buildSettingSection(
      'Cache',
      [
        ListTile(
          title: Text('Cache Size', style: Theme.of(context).textTheme.bodyLarge),
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
            ...durations.map((option) => ListTile(
              title: Text(
                option['label'] as String,
                style: const TextStyle(color: Colors.white),
              ),
              selected: _cacheValidity == option['duration'],
              selectedTileColor: Colors.white.withOpacity(0.1),
              onTap: () {
                setState(() => _cacheValidity = option['duration'] as Duration);
                _settingsBox.put('cacheValidity', _cacheValidity.inMinutes);
                Navigator.pop(context);
              },
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySection() {
    bool isUserLoggedIn = false;
    AppwriteService.instance.getCurrentUser().then((user){
      isUserLoggedIn = true;
    });
    final settingsService = SettingsService.instance;

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
            style: Theme.of(context).textTheme.bodyMedium
          ),
          value: _syncEnabled && isUserLoggedIn && !_incognitoMode,
          onChanged: (isUserLoggedIn && !_incognitoMode) ? (value) async {
            await settingsService.setSyncEnabled(value);
            setState(() => _syncEnabled = value);
          } : null,  // Switch is disabled when user is not logged in or in incognito mode
        ),
        SwitchListTile(
          title: Text('Incognito Mode', 
            style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text(
            'Browse without saving history or preferences',
            style: Theme.of(context).textTheme.bodyMedium
          ),
          value: settingsService.isIncognito, // Use direct value from service
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
              )
            ),
            onTap: () => _showClearDataConfirmation(),
          ),
      ],
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
        content: const Text(
          'While in incognito mode:\n'
          '• Watch history won\'t be saved\n'
          '• Preferences won\'t be stored\n'
          '• Data won\'t be synced\n'
          '• My List will be temporarily disabled\n\n'
          'This will apply until you disable incognito mode.'
        ),
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
        content: const Text(
          'This will permanently delete all your:\n'
          '• Watch history\n'
          '• Preferences\n'
          '• Saved settings\n\n'
          'This action cannot be undone.'
        ),
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
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    suffixIcon: _isValidatingProxy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.check_circle),
                            onPressed: () => _validateAndSaveProxy(_proxyController.text),
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
      ],
    );
  }
}