import 'dart:convert';
import 'package:http/http.dart' as http;

class BaseNetwork {
  static const String baseUrl = 'https://api.discogs.com';
  static const String apiToken = 'KRBrYXFnpXHnIXVItuoZuiJSrPnAoolilZgoMGYb';

  // Search releases (albums/singles/EPs) by query - VINYL ONLY
  static Future<Map<String, dynamic>> searchReleases(String query, {int page = 1, int perPage = 50}) async {
    // Add format=Vinyl to ensure vinyl-only results
    final url = '$baseUrl/database/search?q=$query&format=Vinyl&type=release&page=$page&per_page=$perPage';
    print('Searching releases (vinyl only) from URL: $url'); // Debug print
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Discogs token=$apiToken',
        'User-Agent': 'VinylStoreApp/1.0',
      },
    );
    
    print('Response status: ${response.statusCode}'); // Debug print
    print('Response body: ${response.body}'); // Debug print
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Additional filtering to ensure vinyl only
      if (data['results'] != null) {
        final vinylOnly = (data['results'] as List).where((item) {
          final formats = item['format'] as List? ?? [];
          return formats.any((format) => 
            format.toString().toLowerCase().contains('vinyl') ||
            format.toString().toLowerCase().contains('lp') ||
            format.toString().contains('12"') ||
            format.toString().contains('7"') ||
            format.toString().contains('10"')
          );
        }).toList();
        
        data['results'] = vinylOnly;
        
        // Update pagination info to reflect filtered results
        if (data['pagination'] != null) {
          data['pagination']['items'] = vinylOnly.length;
        }
      }
      
      return data;
    } else {
      throw Exception('Failed to search releases: ${response.statusCode}');
    }
  }

  // Get release details by Discogs release ID
  static Future<Map<String, dynamic>> getReleaseDetails(int releaseId) async {
    final url = '$baseUrl/releases/$releaseId';
    print('Fetching release details from URL: $url'); // Debug print
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Discogs token=$apiToken',
        'User-Agent': 'VinylStoreApp/1.0',
      },
    );
    
    print('Response status: ${response.statusCode}'); // Debug print
    print('Response body: ${response.body}'); // Debug print
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data;
    } else {
      throw Exception('Failed to load release details: ${response.statusCode}');
    }
  }

  // Search by artist name - VINYL ONLY
  static Future<Map<String, dynamic>> searchByArtist(String artistName, {int page = 1, int perPage = 50}) async {
    // Add format=Vinyl to ensure vinyl-only results
    final url = '$baseUrl/database/search?artist=$artistName&format=Vinyl&type=release&page=$page&per_page=$perPage';
    print('Searching by artist (vinyl only) from URL: $url'); // Debug print
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Discogs token=$apiToken',
        'User-Agent': 'VinylStoreApp/1.0',
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Additional filtering to ensure vinyl only
      if (data['results'] != null) {
        final vinylOnly = (data['results'] as List).where((item) {
          final formats = item['format'] as List? ?? [];
          return formats.any((format) => 
            format.toString().toLowerCase().contains('vinyl') ||
            format.toString().toLowerCase().contains('lp') ||
            format.toString().contains('12"') ||
            format.toString().contains('7"') ||
            format.toString().contains('10"')
          );
        }).toList();
        
        data['results'] = vinylOnly;
        
        // Update pagination info to reflect filtered results
        if (data['pagination'] != null) {
          data['pagination']['items'] = vinylOnly.length;
        }
      }
      
      return data;
    } else {
      throw Exception('Failed to search by artist: ${response.statusCode}');
    }
  }

  // Search by genre - VINYL ONLY
  static Future<Map<String, dynamic>> searchByGenre(String genre, {int page = 1, int perPage = 50}) async {
    // Add format=Vinyl to ensure vinyl-only results
    final url = '$baseUrl/database/search?genre=$genre&format=Vinyl&type=release&page=$page&per_page=$perPage';
    print('Searching by genre (vinyl only) from URL: $url'); // Debug print
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Discogs token=$apiToken',
        'User-Agent': 'VinylStoreApp/1.0',
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Additional filtering to ensure vinyl only
      if (data['results'] != null) {
        final vinylOnly = (data['results'] as List).where((item) {
          final formats = item['format'] as List? ?? [];
          return formats.any((format) => 
            format.toString().toLowerCase().contains('vinyl') ||
            format.toString().toLowerCase().contains('lp') ||
            format.toString().contains('12"') ||
            format.toString().contains('7"') ||
            format.toString().contains('10"')
          );
        }).toList();
        
        data['results'] = vinylOnly;
        
        // Update pagination info to reflect filtered results
        if (data['pagination'] != null) {
          data['pagination']['items'] = vinylOnly.length;
        }
      }
      
      return data;
    } else {
      throw Exception('Failed to search by genre: ${response.statusCode}');
    }
  }

  // Search by format (vinyl, CD, cassette, etc.)
  static Future<Map<String, dynamic>> searchByFormat(String query, String format, {int page = 1, int perPage = 50}) async {
    final url = '$baseUrl/database/search?q=$query&format=$format&type=release&page=$page&per_page=$perPage';
    print('Searching by format from URL: $url'); // Debug print
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Discogs token=$apiToken',
        'User-Agent': 'VinylStoreApp/1.0',
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      // If searching for vinyl, apply additional filtering
      if (format.toLowerCase() == 'vinyl') {
        if (data['results'] != null) {
          final vinylOnly = (data['results'] as List).where((item) {
            final formats = item['format'] as List? ?? [];
            return formats.any((format) => 
              format.toString().toLowerCase().contains('vinyl') ||
              format.toString().toLowerCase().contains('lp') ||
              format.toString().contains('12"') ||
              format.toString().contains('7"') ||
              format.toString().contains('10"')
            );
          }).toList();
          
          data['results'] = vinylOnly;
          
          // Update pagination info to reflect filtered results
          if (data['pagination'] != null) {
            data['pagination']['items'] = vinylOnly.length;
          }
        }
      }
      
      return data;
    } else {
      throw Exception('Failed to search by format: ${response.statusCode}');
    }
  }

  // Get popular releases - VINYL ONLY
  static Future<Map<String, dynamic>> getPopularReleases({int page = 1}) async {
    // Search for popular genres but only vinyl format
    final popularGenres = ['Rock', 'Pop', 'Hip Hop', 'Electronic', 'Jazz', 'Classical', 'Soul', 'Funk'];
    final randomGenre = popularGenres[DateTime.now().millisecond % popularGenres.length];
    
    return await searchByGenre(randomGenre, page: page);
  }

  // Get vinyl releases specifically
  static Future<Map<String, dynamic>> getVinylReleases(String query, {int page = 1}) async {
    // More specific search for vinyl formats
    // Using format=Vinyl ensures we get actual vinyl records
    final url = '$baseUrl/database/search?q=$query&format=Vinyl&type=release&page=$page&per_page=50';
    print('Searching vinyl releases from URL: $url'); // Debug print
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Discogs token=$apiToken',
        'User-Agent': 'VinylStoreApp/1.0',
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Additional filtering to ensure we only get vinyl
      if (data['results'] != null) {
        final vinylOnly = (data['results'] as List).where((item) {
          final formats = item['format'] as List? ?? [];
          return formats.any((format) => 
            format.toString().toLowerCase().contains('vinyl') ||
            format.toString().toLowerCase().contains('lp') ||
            format.toString().contains('12"') ||
            format.toString().contains('7"') ||
            format.toString().contains('10"')
          );
        }).toList();
        
        data['results'] = vinylOnly;
        
        // Update pagination info to reflect filtered results
        if (data['pagination'] != null) {
          data['pagination']['items'] = vinylOnly.length;
        }
      }
      
      return data;
    } else {
      throw Exception('Failed to search by format: ${response.statusCode}');
    }
  }

  // Get artist information
  static Future<Map<String, dynamic>> getArtistInfo(int artistId) async {
    final url = '$baseUrl/artists/$artistId';
    print('Fetching artist info from URL: $url'); // Debug print
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Discogs token=$apiToken',
        'User-Agent': 'VinylStoreApp/1.0',
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data;
    } else {
      throw Exception('Failed to load artist info: ${response.statusCode}');
    }
  }

  // Get master release (main version of an album)
  static Future<Map<String, dynamic>> getMasterRelease(int masterId) async {
    final url = '$baseUrl/masters/$masterId';
    print('Fetching master release from URL: $url'); // Debug print
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Discogs token=$apiToken',
        'User-Agent': 'VinylStoreApp/1.0',
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data;
    } else {
      throw Exception('Failed to load master release: ${response.statusCode}');
    }
  }

  // Error handling helper
  static String getErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }
}