import 'package:flutter/material.dart';
import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:moviedex/api/api.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/utils/utils.dart';
import 'package:moviedex/pages/info_page.dart';
import 'package:moviedex/components/cached_poster.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:moviedex/utils/ui_constants.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  Api api = Api();
  bool isSearching = false;
  bool isSearched = false;
  String searchQuery = '';
  TextEditingController textEditingController = TextEditingController();
  final Debouncer _debouncer = Debouncer();
  bool _isLoading = false;
  String _errorMessage = '';
  late AnimationController _fadeController;
  final _scrollController = ScrollController();
  final _focusNode = FocusNode(); // Add focus node to control keyboard focus

  void _handleTextFieldChange(String value) {
    const duration = Duration(milliseconds: 500);
    _debouncer.debounce(
      duration: duration,
      onDebounce: () {
        if (mounted) {
          // Check mounted state before updating
          setState(() {
            searchQuery = value;
            isSearched = true;
          });
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController.forward();

    // Add focus node listener to handle focus changes properly
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {
          isSearching = _focusNode.hasFocus;
        });
      }
    });

    textEditingController.addListener(() {
      if (textEditingController.text.isNotEmpty) {
        if (textEditingController.text.toString() != searchQuery) {
          _handleTextFieldChange(textEditingController.text);
        }
      } else {
        if (mounted) {
          setState(() {
            isSearched = false;
            searchQuery = '';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    textEditingController.dispose();
    _scrollController.dispose();
    _focusNode.dispose(); // Clean up focus node
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final crossAxisCount = isMobile ? 2 : (size.width ~/ 180).clamp(3, 6);

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFF141414),
      ),
      child: Scaffold(
        body: FadeTransition(
          opacity: _fadeController,
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildHeaderSection(),
                    _buildContent(isMobile, crossAxisCount),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: const Color(0xFF141414),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12, // Added more bottom padding
      ),
      child: _buildSearchField(),
    );
  }

  Widget _buildSearchField() {
    // Use AnimatedContainer for smooth transitions when focused/unfocused
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: UIConstants.searchBarHeight,
      decoration: BoxDecoration(
        color: isSearching ? Colors.grey[800] : Colors.grey[900],
        borderRadius: BorderRadius.circular(isSearching ? 16 : 24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: isSearching ? 12 : 5,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: TextField(
        controller: textEditingController,
        focusNode: _focusNode, // Use the focus node
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'Search movies and shows...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.only(
              left: isSearching ? 12 : 16,
              right: isSearching ? 8 : 12,
            ),
            child: Icon(
              Icons.search,
              color: isSearching
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
          ),
          suffixIcon: textEditingController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    textEditingController.clear();
                    setState(() {
                      isSearched = false;
                      searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding:
            const EdgeInsets.only(left: 20, top: 24, right: 20, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                isSearched && searchQuery.isNotEmpty
                    ? 'Results for "$searchQuery"'
                    : "Trending Movies",
                key: ValueKey(searchQuery),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!isSearched || searchQuery.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Discover popular movies from around the world",
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isMobile, int crossAxisCount) {
    if (_isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.all(20),
        sliver: _buildLoadingGrid(isMobile, crossAxisCount),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return SliverFillRemaining(
        child: _buildErrorWidget(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: isSearched && searchQuery.isNotEmpty
          ? _buildSearchResults(isMobile, crossAxisCount)
          : _buildPopularContent(isMobile, crossAxisCount),
    );
  }

  Widget _buildLoadingGrid(bool isMobile, int crossAxisCount) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.65, // Slightly taller cards look more modern
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildShimmerItem(isMobile),
        childCount: 10,
      ),
    );
  }

  Widget _buildShimmerItem(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[900]!,
        highlightColor: Colors.grey[800]!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.white70),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _errorMessage = '';
                _isLoading = true;
              });
              // Retry logic here
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isMobile, int crossAxisCount) {
    return FutureBuilder(
      future: api.search(query: searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGrid(isMobile, crossAxisCount);
        }

        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: _buildErrorWidget(),
          );
        }

        final data = snapshot.data!;
        if (data.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No results found for "$searchQuery"',
                    style: const TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try different keywords or check spelling',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return _buildContentGrid(data, isMobile, crossAxisCount);
      },
    );
  }

  Widget _buildPopularContent(bool isMobile, int crossAxisCount) {
    return FutureBuilder<List<Contentclass>>(
      future: api.getPopular(
        type: "movie",
        imageSize: ImageSize.w342,
        language: "en",
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGrid(isMobile, crossAxisCount);
        }

        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: _buildErrorWidget(),
          );
        }

        final data = snapshot.data!;
        return _buildContentGrid(data, isMobile, crossAxisCount);
      },
    );
  }

  Widget _buildContentGrid(
      List<Contentclass> data, bool isMobile, int crossAxisCount) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.65, // Taller cards for better visibility
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildContentItem(data[index], isMobile),
        childCount: data.length,
      ),
    );
  }

  Widget _buildContentItem(Contentclass content, bool isMobile) {
    return Hero(
      tag: 'content_${content.id}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Infopage(
                  id: content.id,
                  name: content.title,
                  type: content.type,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedPoster(
                    imageUrl: content.poster,
                    fit: BoxFit.cover,
                  ),
                  _buildContentOverlay(content),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentOverlay(Contentclass content) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.8),
              Colors.black,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            if (content.rating != null)
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    content.rating!.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
