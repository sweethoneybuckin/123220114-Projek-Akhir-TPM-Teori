// lib/pages/vinyl_home_page.dart (Updated without filters and fixed popup)

import 'dart:io';
import 'package:flutter/material.dart';
import '../presenters/vinyl_presenter.dart';
import '../models/vinyl_model.dart';
import '../services/auth_service.dart';
import '../services/favorite_service.dart';
import 'vinyl_detail_page.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'events_page.dart';
import 'favorite_vinyl_page.dart';

class VinylHomePage extends StatefulWidget {
  const VinylHomePage({super.key});

  @override
  State<VinylHomePage> createState() => _VinylHomePageState();
}

class _VinylHomePageState extends State<VinylHomePage> 
    implements VinylListView {
  
  final VinylPresenter _presenter = VinylPresenter();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();
  final FavoriteService _favoriteService = FavoriteService();
  final PageController _pageController = PageController();
  
  List<VinylRelease> _releases = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPageIndex = 0;
  int _favoritesCount = 0;
  
  // Pagination state
  bool _hasNext = false;
  bool _hasPrevious = false;
  int _currentPage = 1;
  int _totalPages = 1;
  
  @override
  void initState() {
    super.initState();
    _presenter.attachListView(this);
    // Load current user and popular releases
    _loadUserAndReleases();
    _loadFavoritesCount();
  }
  
  Future<void> _loadUserAndReleases() async {
    await _authService.loadCurrentUser();
    _presenter.getPopularReleases();
  }

  Future<void> _loadFavoritesCount() async {
    final count = await _favoriteService.getFavoritesCount();
    setState(() {
      _favoritesCount = count;
    });
  }
  
  @override
  void dispose() {
    _presenter.detachListView();
    _searchController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }
  
  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    // Simple search without filters
    _presenter.searchReleases(query);
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  void _showUserMenu() {
    final user = _authService.getCurrentUser();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // User info
                if (user != null) ...[
                  // Profile photo with improved display
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      backgroundImage: user.profilePhoto != null 
                        ? FileImage(File(user.profilePhoto!))
                        : null,
                      child: user.profilePhoto == null
                        ? Text(
                            user.username[0].toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.username,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Menu items
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ProfilePage()),
                    ).then((_) {
                      // Refresh user data when returning from profile page
                      setState(() {});
                    });
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Saran dan Kesan'),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('123220114'),
                        content: const SingleChildScrollView(
                          child: Text(
                            'Alvino Abyan Rizaldi - 123220114 - Selama mengikuti mata kuliah Pemrograman Mobile, saya mendapatkan banyak pengalaman baru dalam memahami cara kerja pengembangan aplikasi di platform mobile secara lebih mendalam. Mata kuliah ini memberikan gambaran yang nyata tentang tantangan yang dihadapi developer mobile.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 20),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar() {
    final user = _authService.getCurrentUser();
    
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white,
        backgroundImage: user?.profilePhoto != null 
          ? FileImage(File(user!.profilePhoto!))
          : null,
        child: user?.profilePhoto == null
          ? Text(
              user?.username[0].toUpperCase() ?? 'U',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            )
          : null,
      ),
    );
  }

  Widget _buildVinylPage() {
    return Column(
      children: [
        // Custom App Bar with Search
        Container(
          color: Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Title, Favorites, and User
              Row(
                children: [
                  Icon(
                    Icons.album,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vinyl Discovery',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Favorites icon with badge
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const FavoriteVinylPage()),
                            ).then((_) {
                              _loadFavoritesCount();
                            });
                          },
                        ),
                        if (_favoritesCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '$_favoritesCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // User avatar/menu with profile photo support
                  GestureDetector(
                    onTap: _showUserMenu,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildUserAvatar(),
                          const SizedBox(width: 8),
                          Text(
                            _authService.getCurrentUser()?.username ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Search Bar (without filter icon)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search vinyl records, artists, genres...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: _performSearch,
                    ),
                  ],
                ),
              ),
              
              // Shake instruction hint
              if (_releases.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.vibration,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Shake device on detail page to add to favorites!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Main Content Area
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }
  
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading vinyl records...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Oops! Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _presenter.getPopularReleases(),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_releases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.album,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No vinyl records found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching for something else',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _presenter.getPopularReleases(),
              icon: const Icon(Icons.explore),
              label: const Text('Browse Popular'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        await _presenter.getPopularReleases();
        await _loadFavoritesCount(); // Refresh favorites count too
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _releases.length,
        itemBuilder: (context, index) {
          final release = _releases[index];
          return _buildVinylCard(release);
        },
      ),
    );
  }
  
  Widget _buildVinylCard(VinylRelease release) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => VinylDetailPage(release: release),
            ),
          ).then((_) {
            // Refresh favorites count when returning from detail page
            _loadFavoritesCount();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album Art
              Hero(
                tag: 'album-${release.id}',
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                    image: release.thumb != null
                      ? DecorationImage(
                          image: NetworkImage(release.thumb!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  ),
                  child: release.thumb == null
                    ? Icon(
                        Icons.album,
                        size: 40,
                        color: Colors.grey[400],
                      )
                    : null,
                ),
              ),
              const SizedBox(width: 12),
              
              // Release Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      release.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Artist
                    Text(
                      release.displayArtists,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // Metadata Row with Price
                    Row(
                      children: [
                        if (release.year != null) ...[
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${release.year}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Price in USD
                        if (release.lowestPrice != null && release.lowestPrice! > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Text(
                              '\$${release.lowestPrice!.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    // Genres
                    if (release.genres.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: release.genres.take(3).map((genre) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              genre,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 11,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Shake hint
              Column(
                children: [
                  Icon(
                    Icons.vibration,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPageIndex = index;
            });
          },
          children: [
            _buildVinylPage(),
            const EventsPage(),
            const FavoriteVinylPage(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPageIndex,
        onTap: (index) {
          setState(() {
            _currentPageIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          
          // Refresh favorites count when navigating to favorites tab
          if (index == 2) {
            _loadFavoritesCount();
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.album),
            label: 'Vinyl Discovery',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.favorite),
                if (_favoritesCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        '$_favoritesCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Favorites',
          ),
        ],
      ),
    );
  }
  
  // VinylListView implementation
  @override
  void showLoading() {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
  }
  
  @override
  void hideLoading() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  void showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _releases = [];
      });
    }
  }
  
  @override
  void showVinylList(List<VinylRelease> releases) {
    if (mounted) {
      setState(() {
        _releases = releases;
        _errorMessage = null;
      });
    }
  }
  
  @override
  void showEmptyState() {
    if (mounted) {
      setState(() {
        _releases = [];
        _errorMessage = null;
      });
    }
  }
  
  @override
  void updatePagination(bool hasNext, bool hasPrevious, int currentPage, int totalPages) {
    if (mounted) {
      setState(() {
        _hasNext = hasNext;
        _hasPrevious = hasPrevious;
        _currentPage = currentPage;
        _totalPages = totalPages;
      });
    }
  }
}