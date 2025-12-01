import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../models/ad.dart';
import '../models/request.dart';
import 'image_gallery_screen.dart';
// TODO: Create edit_ad_screen.dart
// import 'edit_ad_screen.dart';
import '../services/audio_service.dart';

class MyAdsScreen extends StatefulWidget {
  const MyAdsScreen({super.key});

  @override
  State<MyAdsScreen> createState() => _MyAdsScreenState();
}

class _MyAdsScreenState extends State<MyAdsScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> playButtonSound() async {
    await AudioService().playSound(AudioEvent.buttonClick);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('מודעות שלי'),
        ),
        body: const Center(
          child: Text('יש להתחבר כדי לראות את המודעות שלך'),
        ),
      );
    }

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('מודעות שלי'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF9C27B0)
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('ads')
              .where('createdBy', isEqualTo: currentUserId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'שגיאה בטעינת המודעות',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.campaign,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'אין לך מודעות כרגע',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            // מיון התוצאות בצד הלקוח לפי תאריך יצירה (החדש ביותר ראשון)
            final ads = snapshot.data!.docs
                .map((doc) => Ad.fromFirestore(doc))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ads.length,
                itemBuilder: (context, index) {
                  final ad = ads[index];
                  return _buildAdCard(ad);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdCard(Ad ad) {

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
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
                  const Icon(
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

            // מספר מעוניינים
            if (ad.interestedUsers.isNotEmpty)
              Row(
                children: [
                  Icon(
                    Icons.favorite,
                    size: 16,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${ad.interestedUsers.length} מעוניינים',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            // כפתורי עריכה ומחיקה
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await playButtonSound();
                      _editAd(ad);
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('ערוך'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await playButtonSound();
                      _deleteAd(ad);
                    },
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('מחק'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAd(Ad ad) async {
    if (!mounted) return;

    // TODO: Create EditAdScreen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('עריכת מודעה - תכונה זו תהיה זמינה בקרוב'),
        backgroundColor: Colors.orange,
      ),
    );
    
    // final result = await Navigator.push<bool>(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => EditAdScreen(ad: ad),
    //   ),
    // );

    // if (result == true) {
    //   setState(() {});
    // }
  }

  Future<void> _deleteAd(Ad ad) async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת מודעה'),
        content: const Text('האם אתה בטוח שברצונך למחוק את המודעה? פעולה זו לא ניתנת לביטול.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        // מחיקת תמונות מ-Firebase Storage
        if (ad.images.isNotEmpty) {
          await _deleteImagesFromStorage(ad.images);
        }

        // מחיקת המודעה מ-Firestore
        await FirebaseFirestore.instance
            .collection('ads')
            .doc(ad.adId)
            .delete();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('המודעה נמחקה בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה במחיקת המודעה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteImagesFromStorage(List<String> imageUrls) async {
    try {
      for (final imageUrl in imageUrls) {
        try {
          // חילוץ שם הקובץ מה-URL
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          debugPrint('❌ Error deleting image $imageUrl: $e');
          // ממשיכים למחוק תמונות אחרות גם אם אחת נכשלה
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleting images from storage: $e');
    }
  }
}

