import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminContactInquiriesScreen extends StatefulWidget {
  const AdminContactInquiriesScreen({super.key});

  @override
  State<AdminContactInquiriesScreen> createState() => _AdminContactInquiriesScreenState();
}

class _AdminContactInquiriesScreenState extends State<AdminContactInquiriesScreen> {
  String _selectedStatus = 'all'; // all, new, in_progress, resolved
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 0;
  static const int _itemsPerPage = 10; // 10 הודעות לעמוד

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('ניהול פניות'),
        backgroundColor: const Color(0xFF03A9F4),
        foregroundColor: Colors.white,
        actions: [
          // פילטר סטטוס
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              setState(() {
                _selectedStatus = status;
                _currentPage = 0; // איפוס לעמוד הראשון
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('כל הפניות'),
              ),
              const PopupMenuItem(
                value: 'new',
                child: Text('חדשות'),
              ),
              const PopupMenuItem(
                value: 'in_progress',
                child: Text('בטיפול'),
              ),
              const PopupMenuItem(
                value: 'resolved',
                child: Text('נפתרו'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // סטטיסטיקות
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard('חדשות', 'new', Colors.orange),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard('בטיפול', 'in_progress', Colors.blue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard('נפתרו', 'resolved', Colors.green),
                ),
              ],
            ),
          ),
          
          // שדה חיפוש
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'חיפוש לפי שם, אימייל או הודעה...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                            _currentPage = 0; // איפוס לעמוד הראשון
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                  _currentPage = 0; // איפוס לעמוד הראשון
                });
              },
            ),
          ),
          
          // רשימת פניות
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _selectedStatus == 'all'
                  ? FirebaseFirestore.instance
                      .collection('contact_inquiries')
                      .orderBy('createdAt', descending: true)
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('contact_inquiries')
                      .where('status', isEqualTo: _selectedStatus)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('שגיאה בטעינת הפניות: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('אין פניות להצגה'),
                  );
                }

                final allInquiries = snapshot.data!.docs;
                
                // מיון לפי תאריך (החדשים קודם)
                allInquiries.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  
                  return bTime.compareTo(aTime); // חדשים קודם
                });
                
                // סינון לפי חיפוש
                final filteredInquiries = _searchQuery.isEmpty
                    ? allInquiries
                    : allInquiries.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? '').toString().toLowerCase();
                        final email = (data['email'] ?? '').toString().toLowerCase();
                        final message = (data['message'] ?? '').toString().toLowerCase();
                        
                        return name.contains(_searchQuery) ||
                               email.contains(_searchQuery) ||
                               message.contains(_searchQuery);
                      }).toList();

                if (filteredInquiries.isEmpty && _searchQuery.isNotEmpty) {
                  return const Center(
                    child: Text('לא נמצאו תוצאות לחיפוש'),
                  );
                }

                // חישוב Pagination
                final totalPages = (filteredInquiries.length / _itemsPerPage).ceil();
                final startIndex = _currentPage * _itemsPerPage;
                final endIndex = (startIndex + _itemsPerPage).clamp(0, filteredInquiries.length);
                final pageInquiries = filteredInquiries.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    // רשימת הודעות
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pageInquiries.length,
                        itemBuilder: (context, index) {
                          final doc = pageInquiries[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildInquiryCard(doc.id, data);
                        },
                      ),
                    ),
                    
                    // ניווט עמודים
                    if (totalPages > 1)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // כפתור קודם
                            ElevatedButton.icon(
                              onPressed: _currentPage > 0
                                  ? () {
                                      setState(() {
                                        _currentPage--;
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.arrow_back_ios),
                              label: const Text('קודם'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade600,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            
                            // מספר עמוד
                            Text(
                              'עמוד ${_currentPage + 1} מתוך $totalPages',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            
                            // כפתור הבא
                            ElevatedButton.icon(
                              onPressed: _currentPage < totalPages - 1
                                  ? () {
                                      setState(() {
                                        _currentPage++;
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.arrow_forward_ios),
                              label: const Text('הבא'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF03A9F4),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String status, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('contact_inquiries')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInquiryCard(String inquiryId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'new';
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(
            Icons.person,
            color: statusColor,
          ),
        ),
        title: Text(
          data['name'] ?? 'ללא שם',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['email'] ?? 'ללא אימייל'),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(data['createdAt']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'הודעה:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    data['message'] ?? 'ללא הודעה',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusButton(
                        'חדש',
                        'new',
                        Colors.orange,
                        status == 'new',
                        inquiryId,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatusButton(
                        'בטיפול',
                        'in_progress',
                        Colors.blue,
                        status == 'in_progress',
                        inquiryId,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatusButton(
                        'נפתר',
                        'resolved',
                        Colors.green,
                        status == 'resolved',
                        inquiryId,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String text, String status, Color color, bool isSelected, String inquiryId) {
    return ElevatedButton(
      onPressed: () => _updateStatus(status, inquiryId),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  void _updateStatus(String newStatus, String inquiryId) async {
    try {
      // עדכון הסטטוס ב-Firebase
      await FirebaseFirestore.instance
          .collection('contact_inquiries')
          .doc(inquiryId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // הצגת הודעת הצלחה
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('סטטוס עודכן ל: ${_getStatusText(newStatus)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // הצגת הודעת שגיאה
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעדכון הסטטוס: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'new':
        return 'חדש';
      case 'in_progress':
        return 'בטיפול';
      case 'resolved':
        return 'נפתר';
      default:
        return 'לא ידוע';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'לא ידוע';
    
    try {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'לא ידוע';
    }
  }
}
