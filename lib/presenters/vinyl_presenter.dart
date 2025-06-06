// lib/presenter/vinyl_presenter.dart

import '../models/vinyl_model.dart';
import '../network/base_network.dart';

// Base view interface
abstract class BaseView {
  void showLoading();
  void hideLoading();
  void showError(String message);
}

// Specific view interfaces
abstract class VinylListView extends BaseView {
  void showVinylList(List<VinylRelease> releases);
  void showEmptyState();
  void updatePagination(bool hasNext, bool hasPrevious, int currentPage, int totalPages);
}

abstract class VinylDetailView extends BaseView {
  void showVinylDetails(VinylRelease release);
}

abstract class ArtistView extends BaseView {
  void showArtistInfo(Artist artist);
  void showArtistReleases(List<VinylRelease> releases);
}

// Main presenter class
class VinylPresenter {
  // View references
  VinylListView? _listView;
  VinylDetailView? _detailView;
  ArtistView? _artistView;

  // State management
  List<VinylRelease> _currentReleases = [];
  VinylRelease? _currentRelease;
  Artist? _currentArtist;
  SearchResult? _lastSearchResult;
  
  // Pagination
  int _currentPage = 1;
  static const int _perPage = 200; // Increased to show more results at once
  
  // Search filters
  String _lastQuery = '';
  String _lastSearchType = 'all'; // all, artist, genre, vinyl

  // Attach views
  void attachListView(VinylListView view) => _listView = view;
  void attachDetailView(VinylDetailView view) => _detailView = view;
  void attachArtistView(ArtistView view) => _artistView = view;

  // Detach views
  void detachListView() => _listView = null;
  void detachDetailView() => _detailView = null;
  void detachArtistView() => _artistView = null;

  // Search methods with grouping
  Future<void> searchReleases(String query, {bool resetPage = true}) async {
    if (query.isEmpty) {
      _listView?.showEmptyState();
      return;
    }

    if (resetPage) _currentPage = 1;
    _lastQuery = query;
    _lastSearchType = 'all';

    _listView?.showLoading();

    try {
      final response = await BaseNetwork.searchReleases(
        query,
        page: _currentPage,
        perPage: _perPage,
      );

      final searchResult = SearchResult.fromJson(response);
      final groupedResult = searchResult.groupByAlbum();
      
      _lastSearchResult = groupedResult;
      _currentReleases = groupedResult.releases;

      _listView?.hideLoading();

      if (_currentReleases.isEmpty) {
        _listView?.showEmptyState();
      } else {
        _listView?.showVinylList(_currentReleases);
        _listView?.updatePagination(
          groupedResult.hasNextPage,
          groupedResult.hasPreviousPage,
          groupedResult.currentPage,
          groupedResult.totalPages,
        );
      }
    } catch (e) {
      _listView?.hideLoading();
      _listView?.showError(BaseNetwork.getErrorMessage(e));
    }
  }

  Future<void> searchByArtist(String artistName, {bool resetPage = true}) async {
    if (artistName.isEmpty) {
      _listView?.showEmptyState();
      return;
    }

    if (resetPage) _currentPage = 1;
    _lastQuery = artistName;
    _lastSearchType = 'artist';

    _listView?.showLoading();

    try {
      final response = await BaseNetwork.searchByArtist(
        artistName,
        page: _currentPage,
        perPage: _perPage,
      );

      final searchResult = SearchResult.fromJson(response);
      final groupedResult = searchResult.groupByAlbum();
      
      _lastSearchResult = groupedResult;
      _currentReleases = groupedResult.releases;

      _listView?.hideLoading();

      if (_currentReleases.isEmpty) {
        _listView?.showEmptyState();
      } else {
        _listView?.showVinylList(_currentReleases);
        _listView?.updatePagination(
          groupedResult.hasNextPage,
          groupedResult.hasPreviousPage,
          groupedResult.currentPage,
          groupedResult.totalPages,
        );
      }
    } catch (e) {
      _listView?.hideLoading();
      _listView?.showError(BaseNetwork.getErrorMessage(e));
    }
  }

  Future<void> searchByGenre(String genre, {bool resetPage = true}) async {
    if (genre.isEmpty) {
      _listView?.showEmptyState();
      return;
    }

    if (resetPage) _currentPage = 1;
    _lastQuery = genre;
    _lastSearchType = 'genre';

    _listView?.showLoading();

    try {
      final response = await BaseNetwork.searchByGenre(
        genre,
        page: _currentPage,
        perPage: _perPage,
      );

      final searchResult = SearchResult.fromJson(response);
      final groupedResult = searchResult.groupByAlbum();
      
      _lastSearchResult = groupedResult;
      _currentReleases = groupedResult.releases;

      _listView?.hideLoading();

      if (_currentReleases.isEmpty) {
        _listView?.showEmptyState();
      } else {
        _listView?.showVinylList(_currentReleases);
        _listView?.updatePagination(
          groupedResult.hasNextPage,
          groupedResult.hasPreviousPage,
          groupedResult.currentPage,
          groupedResult.totalPages,
        );
      }
    } catch (e) {
      _listView?.hideLoading();
      _listView?.showError(BaseNetwork.getErrorMessage(e));
    }
  }

  Future<void> searchVinylOnly(String query, {bool resetPage = true}) async {
    if (query.isEmpty) {
      _listView?.showEmptyState();
      return;
    }

    if (resetPage) _currentPage = 1;
    _lastQuery = query;
    _lastSearchType = 'vinyl';

    _listView?.showLoading();

    try {
      final response = await BaseNetwork.getVinylReleases(
        query,
        page: _currentPage,
      );

      final searchResult = SearchResult.fromJson(response);
      final groupedResult = searchResult.groupByAlbum();
      
      _lastSearchResult = groupedResult;
      _currentReleases = groupedResult.releases;

      _listView?.hideLoading();

      if (_currentReleases.isEmpty) {
        _listView?.showEmptyState();
      } else {
        _listView?.showVinylList(_currentReleases);
        _listView?.updatePagination(
          groupedResult.hasNextPage,
          groupedResult.hasPreviousPage,
          groupedResult.currentPage,
          groupedResult.totalPages,
        );
      }
    } catch (e) {
      _listView?.hideLoading();
      _listView?.showError(BaseNetwork.getErrorMessage(e));
    }
  }

  // Get popular/featured releases
  Future<void> getPopularReleases() async {
    _currentPage = 1;
    _lastQuery = '';
    _lastSearchType = 'popular';

    _listView?.showLoading();

    try {
      final response = await BaseNetwork.getPopularReleases(page: _currentPage);
      
      final searchResult = SearchResult.fromJson(response);
      final groupedResult = searchResult.groupByAlbum();
      
      _lastSearchResult = groupedResult;
      _currentReleases = groupedResult.releases;

      _listView?.hideLoading();

      if (_currentReleases.isEmpty) {
        _listView?.showEmptyState();
      } else {
        _listView?.showVinylList(_currentReleases);
        _listView?.updatePagination(
          groupedResult.hasNextPage,
          groupedResult.hasPreviousPage,
          groupedResult.currentPage,
          groupedResult.totalPages,
        );
      }
    } catch (e) {
      _listView?.hideLoading();
      _listView?.showError(BaseNetwork.getErrorMessage(e));
    }
  }

  // Get popular vinyl releases specifically
  Future<void> getPopularVinylReleases() async {
    // Since getPopularReleases now returns vinyl-only results, we can use it directly
    await getPopularReleases();
  }

  // Get release details
  Future<void> getReleaseDetails(int releaseId) async {
    _detailView?.showLoading();

    try {
      final response = await BaseNetwork.getReleaseDetails(releaseId);
      _currentRelease = VinylRelease.fromDetailedJson(response);
      
      _detailView?.hideLoading();
      _detailView?.showVinylDetails(_currentRelease!);
    } catch (e) {
      _detailView?.hideLoading();
      _detailView?.showError(BaseNetwork.getErrorMessage(e));
    }
  }

  // Get artist information
  Future<void> getArtistInfo(int artistId) async {
    _artistView?.showLoading();

    try {
      final response = await BaseNetwork.getArtistInfo(artistId);
      _currentArtist = Artist.fromJson(response);
      
      _artistView?.hideLoading();
      _artistView?.showArtistInfo(_currentArtist!);
      
      // Also fetch artist's releases
      if (_currentArtist != null) {
        await searchByArtist(_currentArtist!.name);
      }
    } catch (e) {
      _artistView?.hideLoading();
      _artistView?.showError(BaseNetwork.getErrorMessage(e));
    }
  }

  // Pagination methods (kept for compatibility but not used in UI)
  Future<void> nextPage() async {
    if (_lastSearchResult?.hasNextPage ?? false) {
      _currentPage++;
      await _refreshCurrentSearch();
    }
  }

  Future<void> previousPage() async {
    if (_lastSearchResult?.hasPreviousPage ?? false) {
      _currentPage--;
      await _refreshCurrentSearch();
    }
  }

  Future<void> goToPage(int page) async {
    if (page > 0 && page <= (_lastSearchResult?.totalPages ?? 1)) {
      _currentPage = page;
      await _refreshCurrentSearch();
    }
  }

  // Refresh current search with same parameters
  Future<void> _refreshCurrentSearch() async {
    switch (_lastSearchType) {
      case 'all':
        await searchReleases(_lastQuery, resetPage: false);
        break;
      case 'artist':
        await searchByArtist(_lastQuery, resetPage: false);
        break;
      case 'genre':
        await searchByGenre(_lastQuery, resetPage: false);
        break;
      case 'vinyl':
        await searchVinylOnly(_lastQuery, resetPage: false);
        break;
      case 'popular':
        await getPopularReleases();
        break;
    }
  }

  // Filter methods (work on already grouped results)
  List<VinylRelease> filterByYear(int startYear, int endYear) {
    return _currentReleases.where((release) {
      if (release.year == null) return false;
      return release.year! >= startYear && release.year! <= endYear;
    }).toList();
  }

  List<VinylRelease> filterByFormat(String format) {
    return _currentReleases.where((release) {
      return release.formats.any((f) => 
        f.toLowerCase().contains(format.toLowerCase())
      );
    }).toList();
  }

  List<VinylRelease> filterVinylOnly() {
    return _currentReleases.where((release) => release.isVinyl).toList();
  }

  // Sort methods
  void sortByYear({bool ascending = true}) {
    _currentReleases.sort((a, b) {
      if (a.year == null && b.year == null) return 0;
      if (a.year == null) return ascending ? 1 : -1;
      if (b.year == null) return ascending ? -1 : 1;
      return ascending ? a.year!.compareTo(b.year!) : b.year!.compareTo(a.year!);
    });
    _listView?.showVinylList(_currentReleases);
  }

  void sortByTitle({bool ascending = true}) {
    _currentReleases.sort((a, b) {
      return ascending 
        ? a.title.compareTo(b.title)
        : b.title.compareTo(a.title);
    });
    _listView?.showVinylList(_currentReleases);
  }

  void sortByArtist({bool ascending = true}) {
    _currentReleases.sort((a, b) {
      return ascending 
        ? a.displayArtists.compareTo(b.displayArtists)
        : b.displayArtists.compareTo(a.displayArtists);
    });
    _listView?.showVinylList(_currentReleases);
  }

  // Get variants for a specific release (for detail page)
  List<VinylRelease> getVariantsForRelease(VinylRelease release) {
    return release.variants ?? [release];
  }

  // Getters
  List<VinylRelease> get currentReleases => _currentReleases;
  VinylRelease? get currentRelease => _currentRelease;
  Artist? get currentArtist => _currentArtist;
  int get currentPage => _currentPage;
  int get totalPages => _lastSearchResult?.totalPages ?? 1;
  bool get hasNextPage => _lastSearchResult?.hasNextPage ?? false;
  bool get hasPreviousPage => _lastSearchResult?.hasPreviousPage ?? false;
}