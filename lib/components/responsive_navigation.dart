import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui';  // Add this import for ImageFilter

class ResponsiveNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<NavigationDestination> items;

  const ResponsiveNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 800;
    final theme = Theme.of(context);

    final navigationTheme = NavigationBarThemeData(
      backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            color: theme.colorScheme.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          );
        }
        return TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        );
      }),
    );

    if (isDesktop) {
      return NavigationRail(
        extended: width > 800,
        backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        labelType: width > 800 
            ? NavigationRailLabelType.none 
            : NavigationRailLabelType.selected,
        useIndicator: false,
        indicatorColor: theme.colorScheme.primary.withOpacity(0.2),
        minWidth: 60,
        minExtendedWidth: 200,
        destinations: items.map((item) => 
          NavigationRailDestination(
            padding: const EdgeInsets.symmetric(vertical: 12),
            icon: _buildIcon(
              icon: item.icon, 
              selected: false,
              theme: theme,
            ),
            selectedIcon: _buildIcon(
              icon: item.selectedIcon ?? item.icon, 
              selected: true,
              theme: theme,
            ),
            label: Text(item.label),
          ),
        ).toList(),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        navigationBarTheme: navigationTheme,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.8),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: onTap,
              backgroundColor: Colors.transparent,
              elevation: 0,
              height: 75,
              destinations: items.map((item) => 
                NavigationDestination(
                  icon: _buildIcon(
                    icon: item.icon,
                    selected: false,
                    theme: theme,
                  ),
                  selectedIcon: _buildIcon(
                    icon: item.selectedIcon ?? item.icon,
                    selected: true,
                    theme: theme,
                  ),
                  label: item.label,
                ),
              ).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon({
    required Widget icon,
    required bool selected,
    required ThemeData theme,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected 
            ? theme.colorScheme.primary.withOpacity(0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconTheme(
        data: IconThemeData(
          color: selected 
              ? theme.colorScheme.primary
              : Colors.white.withOpacity(0.7),
          size: 26,
        ),
        child: icon,
      ),
    );
  }
}
