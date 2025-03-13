import 'package:flutter/material.dart';

class UIConstants {
  static const double searchBarHeight = 50.0;
  static const double cardRadius = 12.0;
  static const double gridSpacing = 12.0;
  static const double contentPadding = 16.0;
  static const double cardElevation = 4.0;

  static BoxDecoration searchBarDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).cardColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(25),
      border: Border.all(
        color: Colors.white24,
        width: 1,
      ),
    );
  }

  static BoxDecoration cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(cardRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static InputDecoration searchInputDecoration({
    required BuildContext context,
    required TextEditingController controller,
    required VoidCallback onClear,
  }) {
    return InputDecoration(
      hintText: "Search movies and TV shows...",
      hintStyle: TextStyle(
        color: Colors.grey[400],
        fontSize: 16,
      ),
      prefixIcon: Icon(
        Icons.search_rounded,
        color: Colors.grey[400],
        size: 22,
      ),
      suffixIcon: controller.text.isNotEmpty
          ? IconButton(
              icon: Icon(Icons.clear_rounded, color: Colors.grey[400], size: 20),
              onPressed: onClear,
            )
          : null,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
