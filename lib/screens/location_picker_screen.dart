import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/location_service.dart';
import '../l10n/app_localizations.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final double? initialExposureRadius;
  final double? maxExposureRadius; // טווח מקסימלי מותר
  final bool showExposureCircle; // האם להציג מעגל חשיפה

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    this.initialExposureRadius,
    this.maxExposureRadius,
    this.showExposureCircle = true, // ברירת מחדל: להציג מעגל חשיפה
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoading = true;
  bool _isGettingCurrentLocation = false;
  String? _mapError;
  
  // מעגל חשיפה (בקילומטרים)
  double _exposureRadius = 0.2; // קילומטרים (ברירת מחדל)
  final double _minRadius = 0.1; // 0.1 ק"מ
  double _maxRadius = 5.0; // 5 ק"מ מקסימום
  bool _sliderChanged = false; // האם המשתמש שינה את הסליידר
  
  // הגבלת טווח לגבולות ישראל
  double _maxRadiusInIsrael = 0.0; // יוחלט דינמית לפי המיקום
  
  // האם להציג מעגל חשיפה
  bool get _shouldShowExposureCircle => widget.showExposureCircle;
  
  /// חישוב הטווח המקסימלי לפי סוג המנוי של המשתמש
  void _calculateMaxRadiusForUser() async {
    if (_selectedLocation == null) return;
    
    try {
      // קבלת פרטי המשתמש הנוכחי
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _maxRadiusInIsrael = 10.0; // ברירת מחדל
        return;
      }
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) {
        _maxRadiusInIsrael = 10.0; // ברירת מחדל
        return;
      }
      
      final userData = userDoc.data()!;
      final userType = userData['userType'] as String? ?? 'personal';
      final isSubscriptionActive = userData['isSubscriptionActive'] as bool? ?? false;
      final recommendationsCount = userData['recommendationsCount'] as int? ?? 0;
      final averageRating = userData['averageRating'] as double? ?? 0.0;
      final isAdmin = userData['isAdmin'] as bool? ?? false;
      
      // חישוב הטווח המקסימלי לפי סוג המנוי (במטרים)
      final maxRadiusMeters = LocationService.calculateMaxRadiusForUser(
        userType: userType,
        isSubscriptionActive: isSubscriptionActive,
        recommendationsCount: recommendationsCount,
        averageRating: averageRating,
        isAdmin: isAdmin,
      );
      
      // המרה לקילומטרים
      _maxRadiusInIsrael = maxRadiusMeters / 1000;
      _maxRadius = _maxRadiusInIsrael;
      
      // וידוא שהרדיוס הנוכחי בטווח החדש
      _exposureRadius = _exposureRadius.clamp(_minRadius, _maxRadius);
      
      debugPrint('🎯 Max radius for user: $_maxRadiusInIsrael km (userType: $userType, subscription: $isSubscriptionActive)');
    } catch (e) {
      debugPrint('❌ Error calculating max radius: $e');
      _maxRadiusInIsrael = 5.0; // ברירת מחדל במקרה של שגיאה
      _maxRadius = 5.0;
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint('LocationPickerScreen initState');
    
    // אתחול טווח מקסימלי - שימוש בטווח המקסימלי החדש אם קיים
    _maxRadiusInIsrael = widget.maxExposureRadius ?? 5.0;
    
    // עדכון הטווח המקסימלי בסליידר
    if (widget.maxExposureRadius != null) {
      _maxRadius = widget.maxExposureRadius!;
    }
    
    // וידוא שהרדיוס הנוכחי בטווח
    _exposureRadius = _exposureRadius.clamp(_minRadius, _maxRadius);
    
    // הגדרת רדיוס ראשוני אם קיים
    if (widget.initialExposureRadius != null) {
      _exposureRadius = widget.initialExposureRadius!.clamp(_minRadius, _maxRadius);
      debugPrint('Initial exposure radius: ${widget.initialExposureRadius} -> $_exposureRadius km');
      // אם הטווח הראשוני הוא 0.1, נסמן שהסליידר לא שונה
      if (_exposureRadius == _minRadius) {
        _sliderChanged = false;
      }
    } else {
      // אם אין טווח ראשוני, נבדוק אם הטווח הנוכחי הוא המינימום
      if (_exposureRadius == _minRadius) {
        _sliderChanged = false;
      }
    }
    
    _initializeLocation();
    
    // חישוב טווח מקסימלי לפי סוג המשתמש אם לא סופק מבחוץ
    // מבטיח שמסך זה יכבד את ההגבלות הקשיחות לכל מקום בו הוא משומש
    if (widget.maxExposureRadius == null) {
      _calculateMaxRadiusForUser();
    }
    
    // בדיקה אם Google Maps API זמין
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _mapController == null) {
        debugPrint('Google Maps API not available after 8 seconds');
        setState(() {
          _mapError = 'Google Maps API לא זמין. אנא בדוק את המפתח או החיבור לאינטרנט';
        });
      } else {
        debugPrint('Google Maps API is working');
      }
    });
  }

  Future<void> _initializeLocation() async {
    try {
      debugPrint('Initializing location...');
      if (widget.initialLatitude != null && widget.initialLongitude != null) {
        _selectedLocation = LatLng(widget.initialLatitude!, widget.initialLongitude!);
        _selectedAddress = widget.initialAddress;
        debugPrint('Using initial location: ${_selectedLocation!.latitude}, ${_selectedLocation!.longitude}');
      } else {
        debugPrint('Getting current location...');
        await _getCurrentLocation();
      }
      setState(() {
        _isLoading = false;
        _mapError = null;
      });
      debugPrint('Location initialization completed');
    } catch (e) {
      debugPrint('Error initializing location: $e');
      setState(() {
        _isLoading = false;
        _mapError = 'שגיאה בטעינת המיקום: $e';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingCurrentLocation = true;
    });

    try {
      debugPrint('Getting current location...');
      Position? position = await LocationService.getCurrentPosition();
      
      if (position != null) {
        debugPrint('Position obtained: ${position.latitude}, ${position.longitude}');
        _selectedLocation = LatLng(position.latitude, position.longitude);
        
        // קבלת כתובת
        try {
        _selectedAddress = await LocationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        debugPrint('Address obtained: $_selectedAddress');
        
        // חישוב הטווח המקסימלי לפי סוג המנוי
        _calculateMaxRadiusForUser();
        } catch (e) {
          debugPrint('Error getting address: $e');
          _selectedAddress = 'מיקום לא ידוע';
        }
      } else {
        debugPrint('No position obtained, using default location');
        // ברירת מחדל - תל אביב
        _selectedLocation = const LatLng(32.0853, 34.7818);
        _selectedAddress = 'תל אביב, ישראל';
      }
    } catch (e) {
      debugPrint('Error in _getCurrentLocation: $e');
      // ברירת מחדל - תל אביב
      _selectedLocation = const LatLng(32.0853, 34.7818);
      _selectedAddress = 'תל אביב, ישראל';
    }

    setState(() {
      _isGettingCurrentLocation = false;
    });
    debugPrint('Current location process completed');
  }

  void _onMapTap(LatLng location) {
    debugPrint('Map tapped at: ${location.latitude}, ${location.longitude}');
    
    // בדיקה אם המיקום בתוך ישראל
    if (!LocationService.isLocationInIsrael(location.latitude, location.longitude)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ניתן לבחור מיקום רק בתוך ישראל'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _selectedLocation = location;
    });
    _updateAddressFromLocation(location);
    
      // חישוב הטווח המקסימלי לפי סוג המנוי
      _calculateMaxRadiusForUser();
  }

  // חישוב הרדיוס במטרים למפה
  double _getRadiusInMeters() {
    return _exposureRadius * 1000; // המרה מקילומטרים למטרים
  }

  // קבלת הרדיוס בקילומטרים
  double _getCurrentRadius() {
    return _exposureRadius;
  }

  Future<void> _updateAddressFromLocation(LatLng location) async {
    try {
      debugPrint('Updating address for location: ${location.latitude}, ${location.longitude}');
      String? address = await LocationService.getAddressFromCoordinates(
        location.latitude,
        location.longitude,
      );
      debugPrint('Address obtained: $address');
      setState(() {
        _selectedAddress = address ?? 'מיקום לא ידוע';
      });
    } catch (e) {
      debugPrint('Error updating address: $e');
      setState(() {
        _selectedAddress = 'מיקום לא ידוע';
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    debugPrint('Google Map created successfully');
    debugPrint('Map controller: $_mapController');
    debugPrint('Selected location: $_selectedLocation');
    
    // בדיקה שהמפה נטענה בהצלחה
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _mapController != null) {
        debugPrint('Map loaded successfully after delay');
        setState(() {
          _mapError = null;
          _isLoading = false;
        });
        
        // בדיקה שהמפה באמת עובדת
        _mapController!.getVisibleRegion().then((region) {
          debugPrint('Map visible region: $region');
          if (region.northeast.latitude == region.southwest.latitude && 
              region.northeast.longitude == region.southwest.longitude) {
            debugPrint('Map region is invalid - possible API issue');
            setState(() {
              _mapError = 'המפה לא נטענה כראוי - ייתכן שיש בעיה עם Google Maps API';
            });
          }
        }).catchError((error) {
          debugPrint('Error getting visible region: $error');
          setState(() {
            _mapError = 'שגיאה בטעינת המפה: $error';
          });
        });
      } else {
        debugPrint('Map controller is null after delay');
        setState(() {
          _mapError = 'המפה לא נטענה כראוי';
        });
      }
    });
  }

  Future<void> _moveToCurrentLocation() async {
    await _getCurrentLocation();
    if (_selectedLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(_selectedLocation!),
      );
    }
  }

  void _confirmLocation() {
    if (_selectedLocation != null) {
      debugPrint('Confirming location: ${_selectedLocation!.latitude}, ${_selectedLocation!.longitude}');
      
      // ✅ בדיקה אם הטווח הוא המינימום (0.1 ק"מ) והסליידר לא שונה
      if (_shouldShowExposureCircle && _exposureRadius == _minRadius && !_sliderChanged) {
        // הצגת דיאלוג אישור לטווח מינימלי
        _showMinimalRadiusConfirmationDialog();
        return;
      }
      
      // אם הטווח גדול מ-0.1 או שהסליידר שונה, להמשיך כרגיל
      _doConfirmLocation();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אנא בחר מיקום על המפה'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
  
  /// אישור המיקום בפועל
  void _doConfirmLocation() {
    final result = {
      'latitude': _selectedLocation!.latitude,
      'longitude': _selectedLocation!.longitude,
      'address': _selectedAddress,
    };
    
    // הוספת רדיוס החשיפה רק אם צריך להציג מעגל חשיפה
    if (_shouldShowExposureCircle) {
      debugPrint('Exposure radius: $_exposureRadius km');
      result['exposureRadius'] = _exposureRadius;
    }
    
    Navigator.pop(context, result);
  }
  
  /// הצגת דיאלוג אישור לטווח מינימלי
  void _showMinimalRadiusConfirmationDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.tertiary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.confirmMinimalRadius,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.minimalRadiusWarning,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _doConfirmLocation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _selectLocationManually() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('בחירת מיקום ידנית'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('אנא הזן את המיקום הרצוי:'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'כתובת או שם מקום',
                hintText: 'לדוגמה: תל אביב, ישראל',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _selectedAddress = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_selectedAddress != null && _selectedAddress!.isNotEmpty) {
                // חיפוש מיקום לפי כתובת
                try {
                  final position = await LocationService.getCoordinatesFromAddress(_selectedAddress!);
                  // Guard context usage after async gap
                  if (!context.mounted) return;
                  if (position != null) {
                    setState(() {
                      _selectedLocation = LatLng(position.latitude, position.longitude);
                      _mapError = null;
                    });
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('לא נמצא מיקום לכתובת זו'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  // Guard context usage after async gap
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('שגיאה בחיפוש מיקום: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('אנא הזן כתובת'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('חפש'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.selectLocationTitle),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
    ? const Color(0xFF9C27B0) // סגול יפה
    : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: _confirmLocation,
              child: Text(
                l10n.confirm,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  children: [
                    // כפתורי מיקום
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isGettingCurrentLocation ? null : _moveToCurrentLocation,
                                  icon: _isGettingCurrentLocation
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.my_location),
                                  label: Text(_isGettingCurrentLocation ? l10n.gettingLocation : l10n.currentLocation),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).brightness == Brightness.dark 
        ? const Color(0xFF9C27B0) // סגול יפה
        : Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        
                        // שליטה בגודל מעגל החשיפה
                        if (_selectedLocation != null && _shouldShowExposureCircle) ...[
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.radio_button_unchecked, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${l10n.exposureCircle}: ${_getCurrentRadius().toStringAsFixed(1)} ${l10n.kilometers}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // יחידות מידה - קילומטרים בלבד
                                  Row(
                                    children: [
                                      const Icon(Icons.straighten, color: Colors.grey, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.kilometers,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.remove, color: Colors.blue),
                                      Expanded(
                                        child: Slider(
                                          value: _exposureRadius.clamp(_minRadius, _maxRadius),
                                          min: _minRadius,
                                          max: _maxRadius,
                                          divisions: ((_maxRadius - _minRadius) * 10).round(), // קפיצות של 0.1 ק"מ
                                          activeColor: Colors.blue,
                                          inactiveColor: Colors.blue.withValues(alpha: 0.3),
                                          onChanged: (value) {
                                            setState(() {
                                              // עיגול לקפיצות של 0.1 ק"מ
                                              _exposureRadius = (value * 10).round() / 10;
                                              // וידוא שהערך לא יורד מתחת ל-0.1 ק"מ
                                              if (_exposureRadius < 0.1) {
                                                _exposureRadius = 0.1;
                                              }
                                              // ✅ סימון שהסליידר שונה
                                              _sliderChanged = true;
                                              debugPrint('Slider changed: $value -> $_exposureRadius km');
                                            });
                                          },
                                        ),
                                      ),
                                      const Icon(Icons.add, color: Colors.blue),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.dragSliderToChange,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (_maxRadiusInIsrael > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.maxRangeWithBonuses(_maxRadiusInIsrael.toStringAsFixed(1)),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.notificationsWillBeSent,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                        
                        if (_mapError != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _selectLocationManually,
                                  icon: const Icon(Icons.location_searching),
                                  label: const Text('בחר מיקום ידנית'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // מפה
                  Expanded(
                    child: _mapError != null
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'שגיאה בטעינת המפה',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _mapError!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _mapError = null;
                                      _isLoading = true;
                                    });
                                    _initializeLocation();
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('נסה שוב'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'אם הבעיה נמשכת, אנא בדוק:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '• חיבור לאינטרנט\n• מפתח Google Maps API תקין\n• הרשאות מיקום\n• נסה לבחור מיקום ידנית',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : Stack(
                            children: [
                              GoogleMap(
                                onMapCreated: _onMapCreated,
                                initialCameraPosition: CameraPosition(
                                  target: _selectedLocation ?? const LatLng(32.0853, 34.7818),
                                  zoom: 15,
                                ),
                                onTap: _onMapTap,
                                mapType: MapType.normal,
                                myLocationEnabled: true,
                                myLocationButtonEnabled: false,
                                zoomControlsEnabled: true,
                                compassEnabled: true,
                                buildingsEnabled: true,
                                trafficEnabled: false,
                                mapToolbarEnabled: false,
                                markers: _selectedLocation != null
                                    ? {
                                        Marker(
                                          markerId: const MarkerId('selected_location'),
                                          position: _selectedLocation!,
                                          infoWindow: InfoWindow(
                                            title: l10n.selectedLocation,
                                            snippet: _selectedAddress,
                                          ),
                                        ),
                                      }
                                    : {},
                                circles: _selectedLocation != null && _shouldShowExposureCircle
                                    ? {
                                        Circle(
                                          circleId: const CircleId('exposure_circle'),
                                          center: _selectedLocation!,
                                          radius: _getRadiusInMeters(), // שימוש בפונקציה החדשה
                                          fillColor: Colors.blue.withValues(alpha: 0.2),
                                          strokeColor: Colors.blue,
                                          strokeWidth: 2,
                                        ),
                                      }
                                    : {},
                                onCameraMove: (CameraPosition position) {
                              // עדכון המיקום הנבחר בזמן תנועה
                              if (_selectedLocation == null) {
                                setState(() {
                                  _selectedLocation = position.target;
                                });
                                _updateAddressFromLocation(position.target);
                              }
                            },
                            onCameraIdle: () {
                              // עדכון המיקום הנבחר כשהמצלמה נעצרת
                              if (_mapController != null) {
                                _mapController!.getVisibleRegion().then((region) {
                                  final center = LatLng(
                                    (region.northeast.latitude + region.southwest.latitude) / 2,
                                    (region.northeast.longitude + region.southwest.longitude) / 2,
                                  );
                                  setState(() {
                                    _selectedLocation = center;
                                  });
                                  _updateAddressFromLocation(center);
                                });
                              }
                            },
                          ),
                              // אינדיקטור טעינה
                              if (_isLoading)
                                Container(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text('טוען מפה...'),
                                      ],
                                    ),
                                  ),
                                ),
                              // הודעת דיבוג
                              if (_mapController == null && !_isLoading)
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  right: 16,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'המפה נטענת... אם זה נמשך יותר מ-8 שניות, ייתכן שיש בעיה עם Google Maps API',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                ),
                              // הודעת שגיאה אם המפה לא נטענת
                              if (_mapError != null)
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  right: 16,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _mapError!,
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  
                  // מידע על המיקום הנבחר
                  if (_selectedLocation != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        border: Border(
                          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.selectedLocationLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedAddress ?? 'מיקום לא ידוע',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'קואורדינטות: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
      ),
    );
  }
}
