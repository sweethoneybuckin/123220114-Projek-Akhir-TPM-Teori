// lib/services/favorite_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vinyl_model.dart';

class FavoriteService {
  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;
  FavoriteService._internal();

  static const String _favoritesKey = 'favorite_vinyls';
  List<VinylRelease> _cachedFavorites = [];

  // Add vinyl to favorites
  Future<bool> addToFavorites(VinylRelease vinyl) async {
    try {
      final favorites = await getFavorites();
      
      // Check if already exists
      if (favorites.any((fav) => fav.id == vinyl.id)) {
        return false; // Already in favorites
      }
      
      favorites.add(vinyl);
      await _saveFavorites(favorites);
      _cachedFavorites = favorites;
      return true;
    } catch (e) {
      print('Error adding to favorites: $e');
      return false;
    }
  }

  // Remove vinyl from favorites
  Future<bool> removeFromFavorites(int vinylId) async {
    try {
      final favorites = await getFavorites();
      final initialLength = favorites.length;
      
      favorites.removeWhere((vinyl) => vinyl.id == vinylId);
      
      if (favorites.length < initialLength) {
        await _saveFavorites(favorites);
        _cachedFavorites = favorites;
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error removing from favorites: $e');
      return false;
    }
  }

  // Check if vinyl is in favorites
  Future<bool> isFavorite(int vinylId) async {
    try {
      final favorites = await getFavorites();
      return favorites.any((vinyl) => vinyl.id == vinylId);
    } catch (e) {
      print('Error checking favorite status: $e');
      return false;
    }
  }

  // Get all favorites
  Future<List<VinylRelease>> getFavorites() async {
    try {
      if (_cachedFavorites.isNotEmpty) {
        return _cachedFavorites;
      }

      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];
      
      final favorites = favoritesJson.map((jsonString) {
        final Map<String, dynamic> json = jsonDecode(jsonString);
        return VinylRelease.fromSearchResult(json);
      }).toList();
      
      _cachedFavorites = favorites;
      return favorites;
    } catch (e) {
      print('Error getting favorites: $e');
      return [];
    }
  }

  // Save favorites to storage
  Future<void> _saveFavorites(List<VinylRelease> favorites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = favorites.map((vinyl) {
        return jsonEncode(_vinylToMap(vinyl));
      }).toList();
      
      await prefs.setStringList(_favoritesKey, favoritesJson);
    } catch (e) {
      print('Error saving favorites: $e');
    }
  }

  // Convert VinylRelease to Map for storage
  Map<String, dynamic> _vinylToMap(VinylRelease vinyl) {
    return {
      'id': vinyl.id,
      'title': vinyl.title,
      'artists': vinyl.artists,
      'thumb': vinyl.thumb,
      'cover_image': vinyl.coverImage,
      'year': vinyl.year,
      'genre': vinyl.genres,
      'style': vinyl.styles,
      'country': vinyl.country,
      'label': vinyl.labels,
      'catno': vinyl.catno,
      'format': vinyl.formats,
      'resource_url': vinyl.resourceUrl,
      'uri': vinyl.uri,
      'master_id': vinyl.masterId,
      'master_url': vinyl.masterUrl,
    };
  }

  // Clear all favorites
  Future<void> clearFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_favoritesKey);
      _cachedFavorites.clear();
    } catch (e) {
      print('Error clearing favorites: $e');
    }
  }

  // Get favorites count
  Future<int> getFavoritesCount() async {
    final favorites = await getFavorites();
    return favorites.length;
  }

  // Search favorites
  List<VinylRelease> searchFavorites(String query) {
    if (query.isEmpty) return _cachedFavorites;
    
    final lowercaseQuery = query.toLowerCase();
    return _cachedFavorites.where((vinyl) {
      return vinyl.title.toLowerCase().contains(lowercaseQuery) ||
             vinyl.displayArtists.toLowerCase().contains(lowercaseQuery) ||
             vinyl.displayGenres.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Sort favorites
  void sortFavorites(String sortBy, {bool ascending = true}) {
    switch (sortBy) {
      case 'title':
        _cachedFavorites.sort((a, b) => ascending 
          ? a.title.compareTo(b.title)
          : b.title.compareTo(a.title));
        break;
      case 'artist':
        _cachedFavorites.sort((a, b) => ascending 
          ? a.displayArtists.compareTo(b.displayArtists)
          : b.displayArtists.compareTo(a.displayArtists));
        break;
      case 'year':
        _cachedFavorites.sort((a, b) {
          if (a.year == null && b.year == null) return 0;
          if (a.year == null) return ascending ? 1 : -1;
          if (b.year == null) return ascending ? -1 : 1;
          return ascending 
            ? a.year!.compareTo(b.year!)
            : b.year!.compareTo(a.year!);
        });
        break;
    }
  }
}