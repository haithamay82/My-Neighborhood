import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../models/ad.dart';
import '../models/request.dart';
import 'image_gallery_screen.dart';
import 'appointment_booking_screen.dart';

class AllAdsScreen extends StatefulWidget {
  const AllAdsScreen({super.key});

  @override
  State<AllAdsScreen> createState() => _AllAdsScreenState();
}

class _AllAdsScreenState extends State<AllAdsScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Ad> _allAds = [];
  bool _isLoading = false;
  bool _hasMoreAds = true;
  DocumentSnapshot? _lastDocumentSnapshot;
  static const int _adsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadInitialAds();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoading && _hasMoreAds) {
        _loadMoreAds();
      }
    }
  }

  Future<void> _loadInitialAds() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final query = FirebaseFirestore.instance
          .collection('ads')
          .orderBy('createdAt', descending: true)
          .limit(_adsPerPage);

      final querySnapshot = await query.get();

      final ads = querySnapshot.docs
          .map((doc) => Ad.fromFirestore(doc))
          .toList();

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocumentSnapshot = querySnapshot.docs.last;
      }

      setState(() {
        _allAds = ads;
        _hasMoreAds = ads.length == _adsPerPage;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading ads: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreAds() async {
    if (_isLoading || !_hasMoreAds) return;
    setState(() {
      _isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('ads')
          .orderBy('createdAt', descending: true)
          .limit(_adsPerPage);

      if (_lastDocumentSnapshot != null) {
        query = query.startAfterDocument(_lastDocumentSnapshot!);
      }

      final querySnapshot = await query.get();

      final newAds = querySnapshot.docs
          .map((doc) => Ad.fromFirestore(doc))
          .toList();

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocumentSnapshot = querySnapshot.docs.last;
      }

      setState(() {
        _allAds.addAll(newAds);
        _hasMoreAds = newAds.length == _adsPerPage;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading more ads: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onInterested(Ad ad) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // בדיקה אם המשתמש כבר הביע עניין במודעה
      if (ad.interestedUsers.contains(currentUserId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('כבר הביעת עניין במודעה זו'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // אם המודעה דורשת תור, פתיחת מסך בחירת תור
      Map<String, dynamic>? appointmentResult;
      if (ad.requiresAppointment) {
        appointmentResult = await Navigator.push<Map<String, dynamic>?>(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentBookingScreen(
              adId: ad.adId,
              providerId: ad.createdBy,
            ),
          ),
        );

        // אם המשתמש ביטל את בחירת התור, לא נמשיך
        if (appointmentResult == null) {
          return;
        }
      }

      // הוספת המשתמש לרשימת המעוניינים
      await FirebaseFirestore.instance
          .collection('ads')
          .doc(ad.adId)
          .update({
        'interestedUsers': FieldValue.arrayUnion([currentUserId]),
      });

      // יצירת בקשה ב-"בקשות בטיפול שלי"
      final requestId = FirebaseFirestore.instance.collection('requests').doc().id;
      final now = DateTime.now();
      
      final requestData = {
        'requestId': requestId,
        'title': ad.title,
        'description': ad.description,
        'category': ad.category.name,
        'location': ad.location?.name,
        'isUrgent': ad.isUrgent,
        'images': ad.images,
        'createdAt': Timestamp.fromDate(now),
        'createdBy': ad.createdBy, // יוצר המודעה (נותן השירות)
        'helpers': [currentUserId], // המשתמש שהביע עניין
        'phoneNumber': ad.phoneNumber,
        'type': ad.type.name,
        'deadline': ad.deadline != null ? Timestamp.fromDate(ad.deadline!) : null,
        'targetAudience': ad.targetAudience.name,
        'maxDistance': ad.maxDistance,
        'targetVillage': ad.targetVillage,
        'targetCategories': ad.targetCategories?.map((c) => c.name).toList(),
        'minRating': ad.minRating,
        'minReliability': ad.minReliability,
        'minAvailability': ad.minAvailability,
        'minAttitude': ad.minAttitude,
        'minFairPrice': ad.minFairPrice,
        'urgencyLevel': ad.urgencyLevel.name,
        'tags': ad.tags.map((t) => t.name).toList(),
        'customTag': ad.customTag,
        'latitude': ad.latitude,
        'longitude': ad.longitude,
        'address': ad.address,
        'exposureRadius': ad.exposureRadius,
        'showToProvidersOutsideRange': ad.showToProvidersOutsideRange,
        'showToAllUsers': ad.showToAllUsers,
        'price': ad.price,
        'status': RequestStatus.inProgress.name, // סטטוס "בטיפול"
        'adId': ad.adId, // קישור למודעה המקורית
        'isDeleted': false,
      };

      // אם יש תור שנבחר, הוספת פרטי התור
      if (ad.requiresAppointment && appointmentResult != null) {
        requestData['appointmentId'] = appointmentResult['appointmentId'];
        requestData['appointmentDate'] = Timestamp.fromDate(appointmentResult['date'] as DateTime);
        requestData['appointmentStartTime'] = appointmentResult['startTime'];
        requestData['appointmentEndTime'] = appointmentResult['endTime'];
      }

      // שמירת הבקשה
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .set(requestData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התעניינותך במודעה נשמרה והבקשה נוספה ל"בקשות בטיפול שלי"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error expressing interest: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשמירת התעניינות: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('כל המודעות'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF9C27B0)
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: _isLoading && _allAds.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _allAds.isEmpty
                ? Center(
                    child: Text(
                      'אין מודעות כרגע',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      _allAds.clear();
                      _lastDocumentSnapshot = null;
                      _hasMoreAds = true;
                      await _loadInitialAds();
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _allAds.length + (_hasMoreAds ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _allAds.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final ad = _allAds[index];
                        return _buildAdCard(ad);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildAdCard(Ad ad) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isInterested = currentUserId != null && 
                        ad.interestedUsers.contains(currentUserId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // כותרת
            Text(
              ad.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // תיאור
            if (ad.description.isNotEmpty)
              Text(
                ad.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            
            const SizedBox(height: 12),
            
            // קטגוריה
            Row(
              children: [
                Icon(
                  Icons.category,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  ad.category.categoryDisplayName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // מחיר (אם קיים)
            if (ad.price != null)
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${ad.price} ₪',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 8),
            
            // דורש תור / דורש משלוח
            Wrap(
              spacing: 8,
              children: [
                if (ad.requiresAppointment)
                  Chip(
                    label: const Text('דורש תור'),
                    avatar: const Icon(Icons.calendar_today, size: 16),
                    backgroundColor: Colors.blue.withOpacity(0.2),
                  ),
                if (ad.requiresDelivery)
                  Chip(
                    label: const Text('אפשר לקבל במשלוח'),
                    avatar: const Icon(Icons.local_shipping, size: 16),
                    backgroundColor: Colors.orange.withOpacity(0.2),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // תמונות
            if (ad.images.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: ad.images.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImageGalleryScreen(
                              images: ad.images,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: CachedNetworkImageProvider(ad.images[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 12),
            
            // כפתור "אני מעוניין"
            ElevatedButton.icon(
              onPressed: isInterested ? null : () => _onInterested(ad),
              icon: Icon(isInterested ? Icons.check : Icons.favorite),
              label: Text(isInterested ? 'מעוניין' : 'אני מעוניין'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isInterested 
                    ? Colors.grey 
                    : Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

