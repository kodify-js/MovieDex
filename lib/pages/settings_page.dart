import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:moviedex/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  bool _useHardwareDecoding = true;
  String _selectedTheme = 'system';
  String _selectedAccentColor = 'blue';
  String _defaultQuality = 'Auto';
  String _version = '1.0.0';
  final String _repoOwner = 'kodify-js';
  final String _repoName = 'MovieDex-Flutter';
  Map<String, dynamic>? _repoInfo;
  Map<String, dynamic>? _maintainerInfo;

  @override
  void initState() {
    super.initState();
    _initSettings();
    PackageInfo.fromPlatform().then((info) => _version = info.version);
    _fetchGitHubInfo();
  }

  Future<void> _initSettings() async {
    _settingsBox = await Hive.openBox('settings');
    setState(() {
      _useCustomProxy = _settingsBox.get('useCustomProxy', defaultValue: false);
      _proxyController.text = _settingsBox.get('proxyUrl', defaultValue: '');
      _autoPlayNext = _settingsBox.get('autoPlayNext', defaultValue: true);
      _useHardwareDecoding = _settingsBox.get('useHardwareDecoding', defaultValue: true);
      _selectedTheme = _settingsBox.get('theme', defaultValue: 'system');
      _selectedAccentColor = _settingsBox.get('accentColor', defaultValue: 'blue');
      _defaultQuality = _settingsBox.get('defaultQuality', defaultValue: 'Auto');
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
      print('Failed to fetch GitHub info: $e');
    }
  }

  @override
  void dispose() {
    _proxyController.dispose();
    super.dispose();
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
          _buildAppearanceSection(),
          _buildSettingSection(
            'Video Player',
            [
              SwitchListTile(
                title: Text('Auto Play Next Episode', 
                  style: Theme.of(context).textTheme.bodyLarge),
                value: _autoPlayNext,
                onChanged: (value) {
                  setState(() => _autoPlayNext = value);
                  _saveSetting('autoPlayNext', value);
                },
              ),
              SwitchListTile(
                title: Text('Hardware Decoding', 
                  style: Theme.of(context).textTheme.bodyLarge),
                subtitle: Text('Better performance but may cause issues on some devices',
                  style: Theme.of(context).textTheme.bodyMedium),
                value: _useHardwareDecoding,
                onChanged: (value) {
                  setState(() => _useHardwareDecoding = value);
                  _saveSetting('useHardwareDecoding', value);
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
          _buildSettingSection(
            'Advanced',
            [
              SwitchListTile(
                title: Text('Use Custom Proxy', 
                  style: Theme.of(context).textTheme.bodyLarge),
                value: _useCustomProxy,
                onChanged: (value) {
                  setState(() => _useCustomProxy = value);
                  _saveSetting('useCustomProxy', value);
                },
              ),
              if (_useCustomProxy)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _proxyController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Proxy URL',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                    ),
                    onChanged: (_) => _saveSetting('proxyUrl', _proxyController.text),
                  ),
                ),
            ],
          ),
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
}