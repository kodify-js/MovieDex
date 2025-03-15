import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/pages/info_page.dart';
import 'package:moviedex/pages/watch_page.dart';

// Custom scroll behavior to enable mouse scrolling
class CarouselScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class Carousel extends StatelessWidget {
  const Carousel({
    super.key,
    required this.data,
  });

  final List<Contentclass> data;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;
    final isLandscape = width > height;
    final isDesktop = width > 800;

    // Adjust sidebar width and remove any extra spacing
    final sidebarWidth = isDesktop ? 200.0 : 0.0;
    final effectiveWidth = width - sidebarWidth;

    // Calculate height without padding
    final effectiveHeight = isLandscape
        ? height - mediaQuery.padding.top - kToolbarHeight
        : height * 0.45;

    return Container(
      width: effectiveWidth,
      height: effectiveHeight,
      margin: EdgeInsets.zero, // Remove margins
      padding: EdgeInsets.zero, // Remove padding
      child: ScrollConfiguration(
        // Apply custom scroll behavior for mouse scrolling
        behavior: CarouselScrollBehavior(),
        child: PageView.builder(
          itemCount: data.length,
          controller: PageController(viewportFraction: 1.0),
          scrollDirection: Axis.horizontal,
          // Use custom physics for better mouse wheel scrolling
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          // Enable mouse drag scrolling
          dragStartBehavior: DragStartBehavior.start,
          itemBuilder: (context, index) => _buildCarouselItem(
            context,
            data[index],
            effectiveWidth,
            effectiveHeight,
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselItem(
    BuildContext context,
    Contentclass content,
    double width,
    double height,
  ) {
    final isDesktop = width > 800;
    final isLandscape = width > height;

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.zero, // Remove padding
      margin: EdgeInsets.zero, // Remove margin
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image with proper sizing and alignment
          Image.network(
            content.backdrop,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.black54,
              child: const Icon(Icons.error_outline, color: Colors.white),
            ),
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              return AnimatedOpacity(
                opacity: frame != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: child,
              );
            },
          ),

          // Enhanced gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0.0, 0.3, 0.7, 1.0],
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surface.withOpacity(0.9),
                  Theme.of(context).colorScheme.surface.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Content positioning
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              width: width,
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 48 : 16, // Reduced left padding
                16,
                isDesktop ? 48 : 16,
                isDesktop ? 48 : 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo or Title with responsive sizing
                  if (content.logoPath != null)
                    SizedBox(
                      width: isDesktop
                          ? width * 0.25
                          : width * (isLandscape ? 0.3 : 0.5),
                      child: Image.network(
                        content.logoPath!,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                    )
                  else
                    Text(
                      content.title,
                      maxLines: 2,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isDesktop ? 42 : 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: isDesktop ? 32 : 24),

                  // Action buttons
                  Wrap(
                    spacing: isDesktop ? 16 : 12,
                    runSpacing: 12,
                    children: [
                      _ActionButton(
                        onPressed: () => _navigateToWatch(context, content),
                        icon: Icons.play_arrow_rounded,
                        label: "Watch Now",
                        isPrimary: true,
                        isDesktop: isDesktop,
                      ),
                      _ActionButton(
                        onPressed: () => _navigateToInfo(context, content),
                        icon: Icons.info_outline_rounded,
                        label: "More Info",
                        isPrimary: false,
                        isDesktop: isDesktop,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToWatch(BuildContext context, Contentclass data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WatchPage(
          data: data,
          title: data.title,
        ),
      ),
    );
  }

  void _navigateToInfo(BuildContext context, Contentclass data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Infopage(
          id: data.id,
          name: data.title,
          type: data.type,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;
  final bool isDesktop;

  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(
          isPrimary
              ? Theme.of(context).colorScheme.primary
              : Colors.black.withOpacity(0.7),
        ),
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 16,
            vertical: isDesktop ? 16 : 12,
          ),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isDesktop ? 28 : 24,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
