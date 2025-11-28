import 'package:flutter/material.dart';
import '../services/tutorial_service.dart';
import '../l10n/app_localizations.dart';

class TutorialCenterScreen extends StatefulWidget {
  const TutorialCenterScreen({super.key});

  @override
  State<TutorialCenterScreen> createState() => _TutorialCenterScreenState();
}

class _TutorialCenterScreenState extends State<TutorialCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<TutorialCategory> _buildCategories(AppLocalizations l10n) {
    return [
    TutorialCategory(
      id: 'home',
      title: l10n.tutorialCategoryHome,
      icon: Icons.home,
      color: Colors.blue,
      tutorials: [
        TutorialItem(
          id: 'home_basics',
          title: l10n.tutorialHomeBasicsTitle,
          description: l10n.tutorialHomeBasicsDescription,
          content: l10n.tutorialHomeBasicsContent,
        ),
        TutorialItem(
          id: 'home_search',
          title: l10n.tutorialHomeSearchTitle,
          description: l10n.tutorialHomeSearchDescription,
          content: l10n.tutorialHomeSearchContent,
        ),
      ],
    ),
    TutorialCategory(
      id: 'requests',
      title: l10n.tutorialCategoryRequests,
      icon: Icons.assignment,
      color: Colors.green,
      tutorials: [
        TutorialItem(
          id: 'create_request',
          title: l10n.tutorialCreateRequestTitle,
          description: l10n.tutorialCreateRequestDescription,
          content: l10n.tutorialCreateRequestContent,
        ),
        TutorialItem(
          id: 'manage_requests',
          title: l10n.tutorialManageRequestsTitle,
          description: l10n.tutorialManageRequestsDescription,
          content: l10n.tutorialManageRequestsContent,
        ),
      ],
    ),
    TutorialCategory(
      id: 'chat',
      title: l10n.tutorialCategoryChat,
      icon: Icons.chat,
      color: Colors.orange,
      tutorials: [
        TutorialItem(
          id: 'chat_basics',
          title: l10n.tutorialChatBasicsTitle,
          description: l10n.tutorialChatBasicsDescription,
          content: l10n.tutorialChatBasicsContent,
        ),
        TutorialItem(
          id: 'chat_advanced',
          title: l10n.tutorialChatAdvancedTitle,
          description: l10n.tutorialChatAdvancedDescription,
          content: l10n.tutorialChatAdvancedContent,
        ),
      ],
    ),
    TutorialCategory(
      id: 'profile',
      title: l10n.tutorialCategoryProfile,
      icon: Icons.person,
      color: Colors.purple,
      tutorials: [
        TutorialItem(
          id: 'profile_setup',
          title: l10n.tutorialProfileSetupTitle,
          description: l10n.tutorialProfileSetupDescription,
          content: l10n.tutorialProfileSetupContent,
        ),
        TutorialItem(
          id: 'subscription',
          title: l10n.tutorialSubscriptionTitle,
          description: l10n.tutorialSubscriptionDescription,
          content: l10n.tutorialSubscriptionContent,
        ),
      ],
    ),
  ];
  }

  @override
  void initState() {
    super.initState();
    // TabController will be initialized in build method
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = _buildCategories(l10n);
    
    // Update TabController length if needed
    if (_tabController.length != categories.length) {
      _tabController.dispose();
      _tabController = TabController(length: categories.length, vsync: this);
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.userGuide),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: categories.map((category) => Tab(
            icon: Icon(category.icon),
            text: category.title,
          )).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: categories.map((category) => _buildCategoryContent(category, l10n)).toList(),
      ),
    );
  }

  Widget _buildCategoryContent(TutorialCategory category, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // כותרת הקטגוריה
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [category.color, category.color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(category.icon, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  category.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.tutorialsAvailable(category.tutorials.length),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // רשימת הדרכות
          ...category.tutorials.map((tutorial) => _buildTutorialCard(tutorial, category.color)),
        ],
      ),
    );
  }

  Widget _buildTutorialCard(TutorialItem tutorial, Color categoryColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showTutorialDetail(tutorial, categoryColor),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.school,
                      color: categoryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tutorial.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tutorial.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTutorialDetail(TutorialItem tutorial, Color categoryColor) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // כותרת
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [categoryColor, categoryColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.school, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tutorial.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // תוכן
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    tutorial.content,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ),
              ),
              
              // כפתורים
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context).tutorialClose),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        // סמן כנקרא
                        await TutorialService.markTutorialAsRead(tutorial.id);
                        // Guard context usage after async gap - check context.mounted for builder context
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocalizations.of(context).tutorialMarkedAsRead),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: categoryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(AppLocalizations.of(context).tutorialRead),
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

class TutorialCategory {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final List<TutorialItem> tutorials;

  TutorialCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.tutorials,
  });
}

class TutorialItem {
  final String id;
  final String title;
  final String description;
  final String content;

  TutorialItem({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
  });
}
