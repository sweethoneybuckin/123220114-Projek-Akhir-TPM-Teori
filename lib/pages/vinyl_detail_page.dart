// lib/pages/vinyl_detail_page.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../presenters/vinyl_presenter.dart';
import '../models/vinyl_model.dart';
import '../services/favorite_service.dart';

class VinylDetailPage extends StatefulWidget {
  final VinylRelease release;
  
  const VinylDetailPage({
    super.key,
    required this.release,
  });

  @override
  State<VinylDetailPage> createState() => _VinylDetailPageState();
}

class _VinylDetailPageState extends State<VinylDetailPage> 
    with TickerProviderStateMixin implements VinylDetailView {
  
  final VinylPresenter _presenter = VinylPresenter();
  final FavoriteService _favoriteService = FavoriteService();
  
  VinylRelease? _detailedRelease;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isFavorite = false;
  
  // Accelerometer variables
  late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
  double _shakeThreshold = 15.0; // Sensitivity threshold
  DateTime? _lastShakeTime;
  bool _isShaking = false;
  
  // Animation controllers for shake feedback (album art only)
  late AnimationController _shakeAnimationController;
  late Animation<double> _shakeAnimation;
  
  // Currency data
  String _selectedCountry = 'US';
  
  // Static conversion rates (USD as base)
  static const Map<String, double> _conversionRates = {
    'US': 1.0,      // USD - United States Dollar (base)
    'JP': 150.0,    // JPY - Japanese Yen
    'ID': 15800.0,  // IDR - Indonesian Rupiah
  };
  
  // Currency symbols
  static const Map<String, String> _currencySymbols = {
    'US': '\$',
    'JP': '¥',
    'ID': 'Rp',
  };
  
  // Country information
  static const Map<String, Map<String, String>> _countries = {
    'US': {
      'name': 'United States',
      'currency': 'USD',
      'flag': '🇺🇸',
    },
    'JP': {
      'name': 'Japan',
      'currency': 'JPY',
      'flag': '🇯🇵',
    },
    'ID': {
      'name': 'Indonesia',
      'currency': 'IDR',
      'flag': '🇮🇩',
    },
  };
  
  @override
  void initState() {
    super.initState();
    _presenter.attachDetailView(this);
    _detailedRelease = widget.release;
    _setupAnimations();
    _initializeAccelerometer();
    _checkFavoriteStatus();
    
    // Load detailed information
    _presenter.getReleaseDetails(widget.release.id);
  }

  void _setupAnimations() {
    _shakeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _shakeAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  void _initializeAccelerometer() {
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      _handleAccelerometerEvent(event);
    });
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    // Calculate the magnitude of acceleration
    double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    
    // Remove gravity (approximately 9.8 m/s²)
    magnitude = (magnitude - 9.8).abs();
    
    DateTime now = DateTime.now();
    
    // Check if shake threshold is exceeded and enough time has passed since last shake
    if (magnitude > _shakeThreshold && 
        (_lastShakeTime == null || now.difference(_lastShakeTime!).inMilliseconds > 1000)) {
      
      _lastShakeTime = now;
      _onShakeDetected();
    }
  }

  void _onShakeDetected() {
    if (_isShaking || _detailedRelease == null) return;
    
    setState(() {
      _isShaking = true;
    });

    // Trigger shake animation (album art only)
    _shakeAnimationController.forward().then((_) {
      _shakeAnimationController.reverse();
    });

    // Add to favorites without animation
    _addToFavoritesWithoutAnimation();

    // Reset shake state after a delay
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isShaking = false;
        });
      }
    });
  }

  Future<void> _addToFavoritesWithoutAnimation() async {
    try {
      if (_isFavorite) {
        // If already favorite, show a different message
        _showCustomSnackBar(
          '💿 Already in favorites!',
          backgroundColor: Colors.orange,
          icon: Icons.favorite,
        );
        return;
      }

      final success = await _favoriteService.addToFavorites(_detailedRelease!);
      
      if (success) {
        setState(() {
          _isFavorite = true;
        });

        _showCustomSnackBar(
          '🎉 Added to favorites!',
          backgroundColor: Colors.green,
          icon: Icons.favorite,
        );

        // Add haptic feedback
        _triggerHapticFeedback();
      } else {
        _showCustomSnackBar(
          '❌ Failed to add to favorites',
          backgroundColor: Colors.red,
          icon: Icons.error,
        );
      }
    } catch (e) {
      _showCustomSnackBar(
        '❌ Error adding to favorites',
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    }
  }

  void _triggerHapticFeedback() {
    // You can use HapticFeedback.heavyImpact() if you import 'package:flutter/services.dart'
    // HapticFeedback.heavyImpact();
  }

  void _showCustomSnackBar(String message, {required Color backgroundColor, required IconData icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: 'View Favorites',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).pushNamed('/favorites');
          },
        ),
      ),
    );
  }

  Future<void> _checkFavoriteStatus() async {
    if (_detailedRelease != null) {
      final isFav = await _favoriteService.isFavorite(_detailedRelease!.id);
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_detailedRelease == null) return;

    try {
      if (_isFavorite) {
        final success = await _favoriteService.removeFromFavorites(_detailedRelease!.id);
        if (success) {
          setState(() {
            _isFavorite = false;
          });
          _showCustomSnackBar(
            '💔 Removed from favorites',
            backgroundColor: Colors.grey,
            icon: Icons.favorite_border,
          );
        }
      } else {
        await _addToFavoritesWithoutAnimation();
      }
    } catch (e) {
      _showCustomSnackBar(
        '❌ Error updating favorites',
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    }
  }
  
  @override
  void dispose() {
    _presenter.detachDetailView();
    _accelerometerSubscription.cancel();
    _shakeAnimationController.dispose();
    super.dispose();
  }

  // Convert USD price to selected currency
  double _convertPrice(double usdPrice) {
    return usdPrice * (_conversionRates[_selectedCountry] ?? 1.0);
  }

  // Format price with proper currency symbol
  String _formatPrice(double price, String countryCode) {
    final symbol = _currencySymbols[countryCode] ?? '\$';
    
    switch (countryCode) {
      case 'JP': // Japanese Yen - no decimals
        return '$symbol${price.round().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
      case 'ID': // Indonesian Rupiah - no decimals
        return '$symbol${price.round().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
      case 'US': // US Dollar - 2 decimals
      default:
        return '$symbol${price.toStringAsFixed(2)}';
    }
  }

  // Get exchange rate info
  String _getExchangeRateInfo() {
    final rate = _conversionRates[_selectedCountry] ?? 1.0;
    if (_selectedCountry == 'US') {
      return 'Base currency';
    }
    return '1 USD = ${_formatPrice(rate, _selectedCountry)}';
  }

  void _onCountryChanged(String? countryCode) {
    if (countryCode != null) {
      setState(() {
        _selectedCountry = countryCode;
      });
    }
  }

  Widget _buildShakeInstructions() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.1),
            Colors.blue.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_isShaking ? _shakeAnimation.value : 0, 0),
                child: const Icon(
                  Icons.vibration,
                  color: Colors.purple,
                  size: 24,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shake to add to favorites!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
                
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencySelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.language,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Select Country & Currency',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountry,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down),
                  onChanged: _onCountryChanged,
                  items: _countries.entries.map((entry) {
                    final countryCode = entry.key;
                    final countryInfo = entry.value;
                    return DropdownMenuItem<String>(
                      value: countryCode,
                      child: Row(
                        children: [
                          Text(
                            countryInfo['flag']!,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  countryInfo['name']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  countryInfo['currency']!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getExchangeRateInfo(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection(VinylRelease release) {
    if (release.lowestPrice == null || release.lowestPrice! <= 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.price_change,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Price Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Price not available for this release',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final originalPrice = release.lowestPrice!;
    final convertedPrice = _convertPrice(originalPrice);
    final selectedCountryInfo = _countries[_selectedCountry]!;
    final isConverted = _selectedCountry != 'US';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.price_change,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Price Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Main price display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        selectedCountryInfo['flag']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lowest Price in ${selectedCountryInfo['name']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _formatPrice(convertedPrice, _selectedCountry),
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  if (isConverted) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Original: \$${originalPrice.toStringAsFixed(2)} USD',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final release = _detailedRelease ?? widget.release;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with Album Art
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              // Simple favorite button without animation
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.white,
                  size: 28,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Hero(
                        tag: 'album-${release.id}',
                        child: AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                _isShaking ? _shakeAnimation.value * sin(_shakeAnimationController.value * 4 * pi) : 0,
                                0,
                              ),
                              child: Container(
                                width: 200,
                                height: 200,
                                margin: const EdgeInsets.only(top: 40),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: release.coverImage != null || release.thumb != null
                                    ? Image.network(
                                        release.coverImage ?? release.thumb!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[300],
                                            child: Icon(
                                              Icons.album,
                                              size: 80,
                                              color: Colors.grey[600],
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.grey[300],
                                        child: Icon(
                                          Icons.album,
                                          size: 80,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: _isLoading 
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _errorMessage != null
                ? _buildErrorWidget()
                : _buildContent(release),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading details',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _presenter.getReleaseDetails(widget.release.id),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildContent(VinylRelease release) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shake Instructions
          _buildShakeInstructions(),

          // Title and Artist
          _buildTitleSection(release),
          const SizedBox(height: 24),

          // Currency Selector
          _buildCurrencySelector(),
          const SizedBox(height: 16),

          // Price Section with Currency Conversion
          _buildPriceSection(release),
          const SizedBox(height: 24),
          
          // Release Information
          _buildReleaseInfoSection(release),
          const SizedBox(height: 24),
          
          // Genres
          _buildGenresSection(release),
          const SizedBox(height: 24),
          
          // Tracklist (if available)
          if (release.tracklist != null && release.tracklist!.isNotEmpty) ...[
            _buildTracklistSection(release),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTitleSection(VinylRelease release) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          release.title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          'by ${release.displayArtists}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildReleaseInfoSection(VinylRelease release) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Release Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Year', release.year?.toString()),
            _buildInfoRow('Label', release.displayLabels),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGenresSection(VinylRelease release) {
    if (release.genres.isEmpty) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Genre',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: release.genres.map((genre) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    genre,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTracklistSection(VinylRelease release) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tracklist',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...release.tracklist!.asMap().entries.map((entry) {
              final index = entry.key;
              final track = entry.value;
              
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: index < release.tracklist!.length - 1
                        ? Colors.grey[200]!
                        : Colors.transparent,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      child: Text(
                        track.position.isNotEmpty ? track.position : '${index + 1}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          if (track.displayArtists.isNotEmpty)
                            Text(
                              track.displayArtists,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (track.duration != null)
                      Text(
                        track.duration!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  // VinylDetailView implementation
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
        _isLoading = false;
      });
    }
  }
  
  @override
  void showVinylDetails(VinylRelease release) {
    if (mounted) {
      setState(() {
        _detailedRelease = release;
        _errorMessage = null;
        _isLoading = false;
      });
      _checkFavoriteStatus();
    }
  }
}