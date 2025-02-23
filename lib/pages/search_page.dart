import 'package:flutter/material.dart';
import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:moviedex/api/api.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/utils/utils.dart';
import 'package:moviedex/pages/info_page.dart';
import 'package:moviedex/components/cached_poster.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  Api api = Api();
  bool isSearching = false;
  bool isSearched = false;
  String searchQuery = '';
  TextEditingController textEditingController = TextEditingController();
  final Debouncer _debouncer = Debouncer();
  bool _isLoading = false;
  String _errorMessage = '';

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
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final crossAxisCount = size.width ~/ (isMobile ? 120 : 200);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                alignment: Alignment.bottomCenter,
                child: _buildSearchField(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildHeaderText(),
            ),
          ),
          _buildContent(isMobile, crossAxisCount),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: textEditingController,
        autofocus: false,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: textEditingController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    textEditingController.clear();
                    setState(() {
                      isSearched = false;
                      searchQuery = '';
                    });
                  },
                )
              : null,
          hintText: "Search movies and TV shows",
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildHeaderText() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        isSearched && searchQuery.isNotEmpty
            ? 'Results for "$searchQuery"'
            : "Popular Movies",
        key: ValueKey(searchQuery),
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
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
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: isMobile ? 200 : 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => Infopage(
              id: content.id,
              name: content.title,
              type: content.type,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedPoster(
            imageUrl: content.poster,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}