import 'package:flutter/material.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/pages/info_page.dart';
import 'package:moviedex/pages/watch_page.dart';

class Carousel extends StatelessWidget {
  const Carousel({
    super.key,
    required this.data,
  });

  final List<Contentclass> data;

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions and layout info
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;
    final padding = mediaQuery.padding;
    final viewInsets = mediaQuery.viewInsets;
    
    // Calculate navigation dimensions
    final sidebarWidth = width > 800 ? width<850 ? 265.0 : 200.0 : 0.0;
    final bottomNavHeight = width <= 600 ? 70.0 : 0.0;
    
    // Calculate effective dimensions
    final effectiveWidth = width - sidebarWidth;
    final effectiveHeight = height - bottomNavHeight - padding.top - padding.bottom;
    
    // Calculate optimal carousel height
    final carouselHeight = width > 800  // Desktop
        ? effectiveHeight * 0.75
            : effectiveHeight * (width > height ? 0.9 : 0.45);
            
    return Container(
      width: effectiveWidth,
      height: carouselHeight,
      child: ClipRRect( // Add clipping to prevent overflow
        borderRadius: BorderRadius.circular(0),
        child: ListView.builder(
          itemCount: data.length,
          controller: ScrollController(),
          scrollDirection: Axis.horizontal,
          physics: const PageScrollPhysics().applyTo(
            const ClampingScrollPhysics(),
          ),
          itemBuilder: (context, index) => _buildCarouselItem(
            context,
            data[index],
            effectiveWidth,
            carouselHeight,
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
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 64 : 24,
                16,
                isDesktop ? 64 : 24,
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