import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request.dart';

class AdminRequestsStatisticsScreen extends StatefulWidget {
  const AdminRequestsStatisticsScreen({super.key});

  @override
  State<AdminRequestsStatisticsScreen> createState() => _AdminRequestsStatisticsScreenState();
}

class _AdminRequestsStatisticsScreenState extends State<AdminRequestsStatisticsScreen> {
  int _deletedRequestsCount = 0;
  bool _isLoadingDeleted = true;

  @override
  void initState() {
    super.initState();
    _loadDeletedRequestsCount();
  }

  Future<void> _loadDeletedRequestsCount() async {
    try {
      // ספירת בקשות שנמחקו דרך צ'אטים עם requestId שלא קיים
      final chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .get();
      
      final requestIds = <String>{};
      for (var chatDoc in chatsSnapshot.docs) {
        final requestId = chatDoc.data()['requestId'] as String?;
        if (requestId != null && requestId.isNotEmpty) {
          requestIds.add(requestId);
        }
      }
      
      // בדיקה אילו requestIds לא קיימים ב-requests
      int deletedCount = 0;
      for (var requestId in requestIds) {
        final requestDoc = await FirebaseFirestore.instance
            .collection('requests')
            .doc(requestId)
            .get();
        
        if (!requestDoc.exists) {
          deletedCount++;
        }
      }
      
      if (mounted) {
        setState(() {
          _deletedRequestsCount = deletedCount;
          _isLoadingDeleted = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading deleted requests count: $e');
      if (mounted) {
        setState(() {
          _isLoadingDeleted = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('סטטיסטיקות בקשות'),
        backgroundColor: const Color(0xFF03A9F4),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('requests').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Text('שגיאה בטעינת הסטטיסטיקות: ${snapshot.error}'),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Text('אין בקשות להצגה'),
                ),
              );
            }

            final requests = snapshot.data!.docs;
            
            // ספירה לפי סטטוס
            int openRequests = 0; // פתוחות - status='open' ו-helpersCount == 0
            int completedRequests = 0; // טופלו - status='completed'
            int inProgressRequests = 0; // בטיפול - status='inProgress' **או** status='open' עם helpersCount > 0
            
            // ספירה לפי סוג בקשה
            int freeRequests = 0; // בקשות חינם
            int paidRequests = 0; // בקשות בתשלום
            
            // ספירה לפי תחום עיסוק
            final categoryCount = <String, int>{};
            
            // ספירה לפי איזור גיאוגרפי
            int northCount = 0;
            int centerCount = 0;
            int southCount = 0;
            int unknownLocationCount = 0;

            for (var doc in requests) {
              final data = doc.data() as Map<String, dynamic>;
              
              // סטטוס
              final status = data['status'] as String?;
              final helpers = data['helpers'] as List<dynamic>? ?? [];
              final helpersCount = helpers.length;
              
              if (status == 'completed') {
                completedRequests++;
              } else if (status == 'inProgress') {
                // "בטיפול" - בקשות עם status='inProgress'
                inProgressRequests++;
              } else if (status == 'open') {
                // "בטיפול" - בקשות פתוחות עם helpers>0
                if (helpersCount > 0) {
                  inProgressRequests++;
                } else {
                  // "פתוחות" - בקשות פתוחות ללא helpers
                  openRequests++;
                }
              }
              
              // ספירה לפי סוג בקשה (חינם/בתשלום)
              final type = data['type'] as String?;
              if (type == 'free') {
                freeRequests++;
              } else if (type == 'paid') {
                paidRequests++;
              }
              
              // תחום עיסוק
              final category = data['category'] as String?;
              if (category != null) {
                categoryCount[category] = (categoryCount[category] ?? 0) + 1;
              }
              
              // איזור גיאוגרפי
              final latitude = data['latitude'] as double?;
              if (latitude != null) {
                if (latitude > 32.3) {
                  northCount++;
                } else if (latitude > 31.5) {
                  centerCount++;
                } else {
                  southCount++;
                }
              } else {
                unknownLocationCount++;
              }
            }

            // מיון תחומי עיסוק לפי כמות
            final sortedCategories = categoryCount.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // סטטוס בקשות
                  _buildSectionCard(
                    title: 'סטטוס בקשות',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCardSmall(
                                'סה"כ בקשות',
                                Icons.description,
                                Colors.blue,
                                openRequests + inProgressRequests + completedRequests + _deletedRequestsCount,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStatCardSmall(
                                'פתוחות',
                                Icons.lock_open,
                                Colors.green,
                                openRequests,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCardSmall(
                                'בטיפול',
                                Icons.work,
                                Colors.orange,
                                inProgressRequests,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStatCardSmall(
                                'טופלו',
                                Icons.check_circle,
                                Colors.teal,
                                completedRequests,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _isLoadingDeleted
                                  ? Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : _buildStatCardSmall(
                                      'נמחקו',
                                      Icons.delete,
                                      Colors.red,
                                      _deletedRequestsCount,
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Container()),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // סוג בקשות (חינם/בתשלום)
                  _buildSectionCard(
                    title: 'סוג בקשות',
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCardSmall(
                            'חינם',
                            Icons.free_breakfast,
                            Colors.green,
                            freeRequests,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCardSmall(
                            'בתשלום',
                            Icons.payment,
                            Colors.purple,
                            paidRequests,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // תחומי עיסוק
                  _buildSectionCard(
                    title: 'תחומי עיסוק (טופ 10)',
                    child: Column(
                      children: sortedCategories.take(10).map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _getCategoryDisplayName(entry.key),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF03A9F4).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${entry.value}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF03A9F4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // איזור גיאוגרפי
                  _buildSectionCard(
                    title: 'איזור גיאוגרפי',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCardSmall(
                                'צפון',
                                Icons.north,
                                Colors.blue,
                                northCount,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStatCardSmall(
                                'מרכז',
                                Icons.center_focus_strong,
                                Colors.green,
                                centerCount,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStatCardSmall(
                                'דרום',
                                Icons.south,
                                Colors.orange,
                                southCount,
                              ),
                            ),
                          ],
                        ),
                        if (unknownLocationCount > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'ללא מיקום: $unknownLocationCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF03A9F4),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildStatCardSmall(String title, IconData icon, Color color, int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getCategoryDisplayName(String categoryName) {
    try {
      final category = RequestCategory.values.firstWhere(
        (e) => e.name == categoryName,
        orElse: () => RequestCategory.plumbing,
      );
      
      return category.categoryDisplayName;
    } catch (e) {
      return categoryName;
    }
  }
}

