// lib/model/vinyl_model.dart

class VinylRelease {
  final int id;
  final String title;
  final List<String> artists;
  final String? thumb;
  final String? coverImage;
  final int? year;
  final List<String> genres;
  final List<String> styles;
  final String? country;
  final List<String> labels;
  final String? catno;
  final List<String> formats;
  final String? resourceUrl;
  final String? uri;
  final int? masterId;
  final String? masterUrl;
  
  // Additional details (when fetching full release)
  final List<Track>? tracklist;
  final String? notes;
  final String? releasedFormatted;
  final double? lowestPrice;
  final int? numForSale;
  final Map<String, dynamic>? community;
  
  // Variant support
  final List<VinylRelease>? variants;
  final int? variantCount;
  final bool isMainRelease;

  VinylRelease({
    required this.id,
    required this.title,
    required this.artists,
    this.thumb,
    this.coverImage,
    this.year,
    this.genres = const [],
    this.styles = const [],
    this.country,
    this.labels = const [],
    this.catno,
    this.formats = const [],
    this.resourceUrl,
    this.uri,
    this.masterId,
    this.masterUrl,
    this.tracklist,
    this.notes,
    this.releasedFormatted,
    this.lowestPrice,
    this.numForSale,
    this.community,
    this.variants,
    this.variantCount,
    this.isMainRelease = true,
  });

  factory VinylRelease.fromSearchResult(Map<String, dynamic> json) {
    return VinylRelease(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Unknown Title',
      artists: _extractArtists(json),
      thumb: json['thumb'],
      coverImage: json['cover_image'],
      year: json['year'] != null ? int.tryParse(json['year'].toString()) : null,
      genres: List<String>.from(json['genre'] ?? []),
      styles: List<String>.from(json['style'] ?? []),
      country: json['country'],
      labels: List<String>.from(json['label'] ?? []),
      catno: json['catno'],
      formats: List<String>.from(json['format'] ?? []),
      resourceUrl: json['resource_url'],
      uri: json['uri'],
      masterId: json['master_id'],
      masterUrl: json['master_url'],
      isMainRelease: true,
    );
  }

  factory VinylRelease.fromDetailedJson(Map<String, dynamic> json) {
    return VinylRelease(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Unknown Title',
      artists: _extractDetailedArtists(json),
      thumb: json['thumb'],
      coverImage: _extractCoverImage(json),
      year: json['year'],
      genres: List<String>.from(json['genres'] ?? []),
      styles: List<String>.from(json['styles'] ?? []),
      country: json['country'],
      labels: _extractLabels(json),
      catno: _extractCatNo(json),
      formats: _extractFormats(json),
      resourceUrl: json['resource_url'],
      uri: json['uri'],
      masterId: json['master_id'],
      masterUrl: json['master_url'],
      tracklist: _extractTracklist(json),
      notes: json['notes'],
      releasedFormatted: json['released_formatted'],
      lowestPrice: json['lowest_price']?.toDouble(),
      numForSale: json['num_for_sale'],
      community: json['community'],
      isMainRelease: true,
    );
  }

  // Create a copy with variants
  VinylRelease copyWithVariants(List<VinylRelease> variants) {
    return VinylRelease(
      id: id,
      title: title,
      artists: artists,
      thumb: thumb,
      coverImage: coverImage,
      year: year,
      genres: genres,
      styles: styles,
      country: country,
      labels: labels,
      catno: catno,
      formats: formats,
      resourceUrl: resourceUrl,
      uri: uri,
      masterId: masterId,
      masterUrl: masterUrl,
      tracklist: tracklist,
      notes: notes,
      releasedFormatted: releasedFormatted,
      lowestPrice: lowestPrice,
      numForSale: numForSale,
      community: community,
      variants: variants,
      variantCount: variants.length,
      isMainRelease: true,
    );
  }

  static List<String> _extractArtists(Map<String, dynamic> json) {
    // For search results, artists are in the title format: "Artist - Album Title"
    final title = json['title'] ?? '';
    if (title.contains(' - ')) {
      return [title.split(' - ')[0]];
    }
    return ['Unknown Artist'];
  }

  static List<String> _extractDetailedArtists(Map<String, dynamic> json) {
    final artists = <String>[];
    if (json['artists'] != null) {
      for (var artist in json['artists']) {
        artists.add(artist['name'] ?? 'Unknown Artist');
      }
    }
    return artists.isNotEmpty ? artists : ['Unknown Artist'];
  }

  static String? _extractCoverImage(Map<String, dynamic> json) {
    if (json['images'] != null && json['images'].isNotEmpty) {
      return json['images'][0]['uri'] ?? json['images'][0]['uri150'];
    }
    return json['thumb'];
  }

  static List<String> _extractLabels(Map<String, dynamic> json) {
    final labels = <String>[];
    if (json['labels'] != null) {
      for (var label in json['labels']) {
        labels.add(label['name'] ?? 'Unknown Label');
      }
    }
    return labels;
  }

  static String? _extractCatNo(Map<String, dynamic> json) {
    if (json['labels'] != null && json['labels'].isNotEmpty) {
      return json['labels'][0]['catno'];
    }
    return null;
  }

  static List<String> _extractFormats(Map<String, dynamic> json) {
    final formats = <String>[];
    if (json['formats'] != null) {
      for (var format in json['formats']) {
        final name = format['name'] ?? '';
        final descriptions = format['descriptions'] ?? [];
        final text = format['text'] ?? '';
        
        if (name.isNotEmpty) {
          formats.add(name);
        }
        formats.addAll(List<String>.from(descriptions));
        if (text.isNotEmpty && !formats.contains(text)) {
          formats.add(text);
        }
      }
    }
    return formats;
  }

  static List<Track>? _extractTracklist(Map<String, dynamic> json) {
    if (json['tracklist'] == null) return null;
    
    final tracks = <Track>[];
    for (var track in json['tracklist']) {
      tracks.add(Track.fromJson(track));
    }
    return tracks;
  }

  String get displayArtists => artists.join(', ');
  
  String get displayFormats => formats.join(', ');
  
  String get displayLabels => labels.join(', ');
  
  String get displayGenres => genres.join(', ');
  
  bool get isVinyl => formats.any((format) => 
    format.toLowerCase().contains('vinyl') || 
    format.toLowerCase().contains('lp') ||
    format.toLowerCase().contains('12"') ||
    format.toLowerCase().contains('7"') ||
    format.toLowerCase().contains('10"')
  );

  String? get priceDisplay {
    if (lowestPrice != null) {
      return '\$${lowestPrice!.toStringAsFixed(2)}';
    }
    return null;
  }

  // Get a normalized title for grouping (removes extra info in parentheses, brackets)
  String get normalizedTitle {
    String normalized = title;
    
    // Remove common variations in parentheses/brackets
    normalized = normalized.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s*\[[^\]]*\]\s*'), ' ');
    
    // Remove extra whitespace
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return normalized.toLowerCase();
  }

  // Get album name without artist prefix
  String get albumTitle {
    String albumName = title;
    
    // Remove artist prefix if it exists (Artist - Album format)
    if (title.contains(' - ') && artists.isNotEmpty) {
      final parts = title.split(' - ');
      if (parts.length >= 2) {
        // Check if first part matches any artist name
        final firstPart = parts[0].toLowerCase();
        final hasMatchingArtist = artists.any((artist) => 
          firstPart.contains(artist.toLowerCase()) || artist.toLowerCase().contains(firstPart)
        );
        
        if (hasMatchingArtist) {
          albumName = parts.sublist(1).join(' - ');
        }
      }
    }
    
    return albumName;
  }
}

class Track {
  final String position;
  final String title;
  final String? duration;
  final List<String>? artists;

  Track({
    required this.position,
    required this.title,
    this.duration,
    this.artists,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    List<String>? artists;
    if (json['artists'] != null) {
      artists = [];
      for (var artist in json['artists']) {
        artists.add(artist['name'] ?? 'Unknown Artist');
      }
    }

    return Track(
      position: json['position'] ?? '',
      title: json['title'] ?? 'Unknown Track',
      duration: json['duration'],
      artists: artists,
    );
  }

  String get displayArtists => artists?.join(', ') ?? '';
}

class Artist {
  final int id;
  final String name;
  final String? realName;
  final String? profile;
  final List<String>? images;
  final String? resourceUrl;
  final String? uri;
  final List<String>? namevariations;
  final List<String>? urls;

  Artist({
    required this.id,
    required this.name,
    this.realName,
    this.profile,
    this.images,
    this.resourceUrl,
    this.uri,
    this.namevariations,
    this.urls,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    List<String>? imageUrls;
    if (json['images'] != null) {
      imageUrls = [];
      for (var image in json['images']) {
        imageUrls.add(image['uri'] ?? image['uri150'] ?? '');
      }
    }

    return Artist(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown Artist',
      realName: json['realname'],
      profile: json['profile'],
      images: imageUrls,
      resourceUrl: json['resource_url'],
      uri: json['uri'],
      namevariations: json['namevariations'] != null 
        ? List<String>.from(json['namevariations']) 
        : null,
      urls: json['urls'] != null 
        ? List<String>.from(json['urls']) 
        : null,
    );
  }
}

// Helper class for search results with grouping support
class SearchResult {
  final List<VinylRelease> releases;
  final int totalResults;
  final int totalPages;
  final int currentPage;

  SearchResult({
    required this.releases,
    required this.totalResults,
    required this.totalPages,
    required this.currentPage,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final results = json['results'] as List? ?? [];
    final releases = results.map((item) => VinylRelease.fromSearchResult(item)).toList();
    
    final pagination = json['pagination'] ?? {};
    
    return SearchResult(
      releases: releases,
      totalResults: pagination['items'] ?? 0,
      totalPages: pagination['pages'] ?? 1,
      currentPage: pagination['page'] ?? 1,
    );
  }

  // Group releases by album title
  SearchResult groupByAlbum() {
    final Map<String, List<VinylRelease>> groupedReleases = {};
    
    for (final release in releases) {
      // Create a grouping key based on artist and album title
      final groupKey = '${release.displayArtists.toLowerCase()}_${release.albumTitle.toLowerCase()}';
      
      if (groupedReleases.containsKey(groupKey)) {
        groupedReleases[groupKey]!.add(release);
      } else {
        groupedReleases[groupKey] = [release];
      }
    }
    
    // Create main releases with variants
    final groupedList = <VinylRelease>[];
    
    for (final group in groupedReleases.values) {
      if (group.length == 1) {
        // Single release, no variants
        groupedList.add(group.first);
      } else {
        // Multiple releases, group them
        // Sort by year (newest first) to pick the main release
        group.sort((a, b) {
          if (a.year == null && b.year == null) return 0;
          if (a.year == null) return 1;
          if (b.year == null) return -1;
          return b.year!.compareTo(a.year!);
        });
        
        final mainRelease = group.first;
        final variants = group.sublist(1);
        
        // Create main release with variants
        final releaseWithVariants = mainRelease.copyWithVariants([mainRelease, ...variants]);
        groupedList.add(releaseWithVariants);
      }
    }
    
    return SearchResult(
      releases: groupedList,
      totalResults: groupedList.length,
      totalPages: (groupedList.length / 20).ceil(),
      currentPage: currentPage,
    );
  }

  bool get hasNextPage => currentPage < totalPages;
  bool get hasPreviousPage => currentPage > 1;
}