import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request.dart';
import '../l10n/app_localizations.dart';
import 'detailed_rating_screen.dart';

class SelectHelperForRatingScreen extends StatefulWidget {
  final Request request;

  const SelectHelperForRatingScreen({
    super.key,
    required this.request,
  });

  @override
  State<SelectHelperForRatingScreen> createState() => _SelectHelperForRatingScreenState();
}

class _SelectHelperForRatingScreenState extends State<SelectHelperForRatingScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _helpers = [];

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 SelectHelperForRatingScreen initState called');
    debugPrint('🔍 Request ID: ${widget.request.requestId}');
    debugPrint('🔍 Request helpers: ${widget.request.helpers}');
    _loadHelpers();
  }

  Future<void> _loadHelpers() async {
    try {
      debugPrint('🔍 Loading helpers for request: ${widget.request.requestId}');
      debugPrint('🔍 Helpers list: ${widget.request.helpers}');
      
      if (widget.request.helpers.isEmpty) {
        debugPrint('ℹ️ No helpers in request, showing empty state');
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('🔍 Querying users collection for helpers...');
      // קבלת פרטי המשתמשים המעוניינים
      final helpersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: widget.request.helpers)
          .get();

      debugPrint('🔍 Found ${helpersQuery.docs.length} helper documents');

      final helpers = helpersQuery.docs.map((doc) {
        final data = doc.data();
        debugPrint('🔍 Helper data: ${doc.id} -> ${data['displayName']}');
        return {
          'uid': doc.id,
          'displayName': data['displayName'] ?? 'משתמש',
          'email': data['email'] ?? '',
          'userType': data['userType'] ?? 'personal',
        };
      }).toList();

      debugPrint('🔍 Processed ${helpers.length} helpers');
      setState(() {
        _helpers = helpers;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading helpers: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בטעינת המשתמשים: $e'),
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
          title: const Text('בחר מי עזר לך'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFFFF9800) // כתום ענתיק
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(l10n),
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    if (_helpers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'אין משתמשים שעזרו לך',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'אף משתמש לא לחץ "אני מעוניין" על בקשה זו',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('חזור'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'בחר את המשתמש שעזר לך בפועל כדי לדרג אותו',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'משתמשים שעזרו לך:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _helpers.length,
              itemBuilder: (context, index) {
                final helper = _helpers[index];
                return _buildHelperCard(helper);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelperCard(Map<String, dynamic> helper) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            helper['displayName'][0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          helper['displayName'],
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(helper['email']),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: helper['userType'] == 'business' 
                    ? Colors.orange[100] 
                    : Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                helper['userType'] == 'business' ? 'עסקי' : 'פרטי',
                style: TextStyle(
                  fontSize: 12,
                  color: helper['userType'] == 'business' 
                      ? Colors.orange[700] 
                      : Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        trailing: ElevatedButton.icon(
          onPressed: () => _navigateToRating(helper),
          icon: const Icon(Icons.star),
          label: const Text('דרג'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  void _navigateToRating(Map<String, dynamic> helper) {
    debugPrint('🔍 Navigating to rating screen for helper: ${helper['uid']}');
    debugPrint('🔍 Helper data: $helper');
    
    // בדיקת נתוני המשתמש
    if (helper['uid'] == null || helper['uid'].toString().isEmpty) {
      debugPrint('❌ Invalid helper UID');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('שגיאה: נתוני המשתמש לא תקינים'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailedRatingScreen(
          request: widget.request,
          helper: helper,
        ),
      ),
    ).then((ratingCompleted) {
      debugPrint('🔄 Returned from rating screen, rating completed: $ratingCompleted');
      // אחרי הדירוג, חזור למסך הקודם עם הערך שחוזר
      Navigator.pop(context, ratingCompleted);
    }).catchError((error) {
      debugPrint('❌ Error in rating screen: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }
}
