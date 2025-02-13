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
    // Get screen dimensions and padding
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final padding = MediaQuery.of(context).padding;
    final viewPadding = MediaQuery.of(context).viewPadding;
    
    // Calculate responsive dimensions
    final isDesktop = width > 600;
    final isMobile = !isDesktop;
    final isLandscape = width > height;
    
    // Calculate carousel height based on screen size and orientation
    final carouselHeight = isDesktop 
        ? height * 0.7 // Desktop height
        : isLandscape 
            ? height * 0.9 // Landscape mobile
            : height * 0.4; // Portrait mobile
            
    // Adjust for navigation bars and status bar
    final bottomPadding = viewPadding.bottom + (isMobile ? 70 : 0); // Account for bottom nav
    final topPadding = padding.top;
    
    return SizedBox(
      width: width,
      height: carouselHeight - bottomPadding - topPadding,
      child: AspectRatio(
        aspectRatio: isDesktop ? 21/9 : 16/9,
        child: ListView.builder(
          itemCount: data.length,
          controller: ScrollController(),
          scrollDirection: Axis.horizontal,
          physics: const PageScrollPhysics().applyTo(
            const ClampingScrollPhysics(),
          ),
          itemBuilder: (context, index) {
            return Container(
              width: isMobile ? width : width * 0.68,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(data[index].backdrop),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.surface.withOpacity(0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  isMobile ? 24 : 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Title or Logo
                    if (data[index].logoPath == null)
                      Text(
                        data[index].title,
                        maxLines: 2,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isDesktop ? 32 : 24,
                          fontWeight: FontWeight.bold,
                          overflow: TextOverflow.ellipsis
                        ),
                      )
                    else
                      SizedBox(
                        width: isDesktop ? width / 5 : width / 2,
                        child: Image.network(
                          data[index].logoPath!,
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.contain,
                        ),
                      ),
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Wrap(
                      spacing: 16,
                      children: [
                        _ActionButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WatchPage(
                                  data: data[index],
                                  title: data[index].title,
                                ),
                              ),
                            );
                          },
                          icon: Icons.play_arrow_rounded,
                          label: "Watch Now",
                          isPrimary: true,
                          isDesktop: isDesktop,
                        ),
                        _ActionButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Infopage(
                                  id: data[index].id,
                                  name: data[index].title,
                                  type: data[index].type,
                                ),
                              ),
                            );
                          },
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
            );
          },
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
        backgroundColor: MaterialStateProperty.all(
          isPrimary
              ? Theme.of(context).colorScheme.primary
              : Colors.black.withOpacity(0.7),
        ),
        padding: MaterialStateProperty.all(
          EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 16,
            vertical: isDesktop ? 16 : 12,
          ),
        ),
        shape: MaterialStateProperty.all(
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