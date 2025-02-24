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

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
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

  void _handleTextFieldChange(String value) {
    const duration = Duration(milliseconds: 500);
    _debouncer.debounce(
      duration: duration,
      onDebounce: () {
        setState(() {
          searchQuery = value;
          isSearched = true;
        });
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
    textEditingController.addListener(() {
      if (textEditingController.text.isNotEmpty) {
        if (textEditingController.text.toString() != searchQuery) {
          _handleTextFieldChange(textEditingController.text);
        }
      } else {
        setState(() {
          isSearched = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
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
        body: Column(
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
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: const Color(0xFF141414),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: _buildSearchField(),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: UIConstants.searchBarHeight,
      decoration: UIConstants.searchBarDecoration(context),
      child: TextField(
        controller: textEditingController,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: UIConstants.searchInputDecoration(
          context: context,
          controller: textEditingController,
          onClear: () {
            textEditingController.clear();
            setState(() {
              isSearched = false;
              searchQuery = '';
            });
          },
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            isSearched && searchQuery.isNotEmpty
                ? 'Results for "$searchQuery"'
                : "Trending Movies",
            key: ValueKey(searchQuery),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isMobile, int crossAxisCount) {
    if (_isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: _buildLoadingGrid(isMobile, crossAxisCount),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return SliverFillRemaining(
        child: _buildErrorWidget(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: isSearched && searchQuery.isNotEmpty
          ? _buildSearchResults(isMobile, crossAxisCount)
          : _buildPopularContent(isMobile, crossAxisCount),
    );
  }

  Widget _buildLoadingGrid(bool isMobile, int crossAxisCount) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 2/3,
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _errorMessage = '';
                _isLoading = true;
              });
              // Retry logic here
            },
            child: const Text('Retry'),
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
                  const Icon(Icons.search_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No results found for "$searchQuery"',
                    style: const TextStyle(fontSize: 16),
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

  Widget _buildContentGrid(List<Contentclass> data, bool isMobile, int crossAxisCount) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 2/3,
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
          borderRadius: BorderRadius.circular(UIConstants.cardRadius),
          child: Container(
            decoration: UIConstants.cardDecoration(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(UIConstants.cardRadius),
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
            bottom: Radius.circular(UIConstants.cardRadius),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.9),
            ],
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (content.rating != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    content.rating!.toStringAsFixed(1),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}