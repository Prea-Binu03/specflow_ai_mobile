import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'auth_screen.dart';
import 'projects_screen.dart';
import 'profile_screen.dart';
import 'ai_assistant_screen.dart';
import 'project_detail_screen.dart';
import 'create_project_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userEmail;
  const DashboardScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSidebarCollapsed = false;
  bool _isGeneratingSuggestions = false;

  Map<String, dynamic> _stats = {
    'total': 0,
    'pending': 0,
    'generated': 0,
    'failed': 0,
  };
  List<dynamic> _projects = [];
  String _errorMessage = '';

  final TextEditingController _ideaKeywordController = TextEditingController();
  List<dynamic> _aiSuggestions = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _ideaKeywordController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://specflow-ai-mobile-backend.onrender.com/api/projects?userEmail=${widget.userEmail}',
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _stats =
              data['stats'] ??
              {'total': 0, 'pending': 0, 'generated': 0, 'failed': 0};
          _projects = data['projects'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load projects data from server.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network error: Unable to connect to backend server.';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteProject(String projectId) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text(
              'Delete Project',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete this project? This action cannot be undone.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      final response = await http.delete(
        Uri.parse(
          'https://specflow-ai-mobile-backend.onrender.com/api/projects/$projectId',
        ),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project deleted successfully!')),
        );
        _fetchDashboardData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete project.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error deleting project: $e')));
    }
  }

  void _showGenerateIdeasDialog(BuildContext context) {
    try {
      _ideaKeywordController.clear();
    } catch (e) {}
    _aiSuggestions.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.purpleAccent),
              SizedBox(width: 12),
              Text(
                'AI Idea & Spec Generator',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 550,
            height: 580,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter a topic or domain keyword to get AI-powered project suggestions:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ideaKeywordController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText:
                              'e.g., Smart EV Charging, Healthcare, FinTech',
                          labelStyle: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Colors.purpleAccent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                      ),
                      onPressed: _isGeneratingSuggestions
                          ? null
                          : () async {
                              String keyword = _ideaKeywordController.text
                                  .trim();
                              if (keyword.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter a keyword or topic',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setDialogState(
                                () => _isGeneratingSuggestions = true,
                              );

                              try {
                                final response = await http.post(
                                  Uri.parse(
                                    'https://specflow-ai-mobile-backend.onrender.com/api/ai/project-recommendations',
                                  ),
                                  headers: {'Content-Type': 'application/json'},
                                  body: jsonEncode({
                                    'topic': keyword,
                                    'techStack': 'AI Recommended',
                                  }),
                                );

                                if (response.statusCode == 200) {
                                  final data = jsonDecode(response.body);
                                  setDialogState(() {
                                    _aiSuggestions = data['ideas'] ?? [];
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Failed to generate AI suggestions',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Network error: $e')),
                                );
                              } finally {
                                setDialogState(
                                  () => _isGeneratingSuggestions = false,
                                );
                              }
                            },
                      child: _isGeneratingSuggestions
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Get AI Suggestions',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_aiSuggestions.isNotEmpty)
                  const Text(
                    'Select a suggested project to initialize spec:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: _aiSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _aiSuggestions[index];
                      String title =
                          suggestion['projectName'] ??
                          suggestion['title'] ??
                          'Project Option';
                      String desc =
                          suggestion['description'] ?? suggestion['idea'] ?? '';
                      String domainVal =
                          suggestion['domain'] ??
                          _ideaKeywordController.text.trim();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () async {
                            Navigator.pop(context);
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateProjectScreen(
                                  userEmail: widget.userEmail,
                                  initialProjectName: title,
                                  initialProjectIdea: desc,
                                  initialDomain: domainVal,
                                ),
                              ),
                            );
                            if (result == true) {
                              _fetchDashboardData();
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.purpleAccent.withOpacity(0.4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  desc,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 768;
    String userName = widget.userEmail.split('@')[0];
    if (userName.isNotEmpty) {
      userName = userName[0].toUpperCase() + userName.substring(1);
    }

    Widget dashboardSidebar = Container(
      width: _isSidebarCollapsed ? 70 : 250,
      color: const Color(0xFF161E2E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isSidebarCollapsed)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF3B82F6),
                        width: 2,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFF1E293B),
                      child: Icon(
                        Icons.person,
                        color: Color(0xFF3B82F6),
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.userEmail,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFF1E293B),
                  child: Icon(Icons.person, color: Color(0xFF3B82F6), size: 18),
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (!_isSidebarCollapsed)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                'WORKSPACE',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSidebarItem(
                  0,
                  'Home',
                  Icons.home_outlined,
                  Icons.home,
                  () {
                    setState(() => _currentIndex = 0);
                    if (isMobile) Navigator.pop(context);
                  },
                ),
                _buildSidebarItem(
                  1,
                  'Create Project',
                  Icons.add_circle_outline,
                  Icons.add_circle,
                  () async {
                    if (isMobile) Navigator.pop(context);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CreateProjectScreen(userEmail: widget.userEmail),
                      ),
                    );
                    if (result == true) _fetchDashboardData();
                  },
                ),
                _buildSidebarItem(
                  2,
                  'My Projects',
                  Icons.folder_outlined,
                  Icons.folder,
                  () {
                    if (isMobile) Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProjectsScreen(userEmail: widget.userEmail),
                      ),
                    );
                  },
                ),
                _buildSidebarItem(
                  3,
                  'AI Assistant',
                  Icons.chat_bubble_outline,
                  Icons.chat_bubble,
                  () {
                    if (isMobile) Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AiAssistantScreen(userEmail: widget.userEmail),
                      ),
                    );
                  },
                ),
                const Divider(color: Colors.white24, height: 24),
                _buildSidebarItem(
                  4,
                  'Profile Settings',
                  Icons.settings_outlined,
                  Icons.settings,
                  () {
                    if (isMobile) Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProfileScreen(userEmail: widget.userEmail),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: _isSidebarCollapsed ? 16 : 16,
                  ),
                  leading: const Icon(
                    Icons.logout,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  title: _isSidebarCollapsed
                      ? null
                      : const Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AuthScreen(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget dashboardMainContent = _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF2563EB)),
          )
        : _errorMessage.isNotEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                  ),
                  onPressed: _fetchDashboardData,
                  child: const Text(
                    'Retry Connection',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _fetchDashboardData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E1B4B),
                          Color(0xFF312E81),
                          Color(0xFF1E293B),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, $userName! 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Turn your ideas into actionable software plans with automated AI specifications.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Project Statistics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isSmall = constraints.maxWidth < 600;
                      return GridView.count(
                        crossAxisCount: isSmall ? 2 : 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isSmall ? 2.2 : 2.0,
                        children: [
                          _buildStatCard(
                            'Total Projects',
                            '${_stats['total']}',
                            Icons.folder_outlined,
                            Colors.blue,
                          ),
                          _buildStatCard(
                            'AI Pending',
                            '${_stats['pending']}',
                            Icons.hourglass_empty,
                            Colors.orange,
                          ),
                          _buildStatCard(
                            'AI Generated',
                            '${_stats['generated']}',
                            Icons.check_circle_outline,
                            Colors.green,
                          ),
                          _buildStatCard(
                            'Failed',
                            '${_stats['failed']}',
                            Icons.error_outline,
                            Colors.redAccent,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildActionButton(
                        'Create New Project',
                        Icons.add_circle_outline,
                        const Color(0xFF2563EB),
                        () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateProjectScreen(
                                userEmail: widget.userEmail,
                              ),
                            ),
                          );
                          if (result == true) _fetchDashboardData();
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildActionButton(
                        'Generate Ideas',
                        Icons.lightbulb_outline,
                        Colors.purpleAccent,
                        () => _showGenerateIdeasDialog(context),
                      ),
                      const SizedBox(width: 12),
                      _buildActionButton(
                        'AI Assistant',
                        Icons.chat_bubble_outline,
                        Colors.tealAccent,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AiAssistantScreen(
                                userEmail: widget.userEmail,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Projects',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _fetchDashboardData,
                        icon: const Icon(
                          Icons.refresh,
                          size: 16,
                          color: Colors.blueAccent,
                        ),
                        label: const Text(
                          'Refresh',
                          style: TextStyle(color: Colors.blueAccent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _projects.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.folder_off_outlined,
                                size: 48,
                                color: Colors.white38,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No projects yet',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Get started by creating your first AI software specification project.',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CreateProjectScreen(
                                        userEmail: widget.userEmail,
                                      ),
                                    ),
                                  );
                                  if (result == true) _fetchDashboardData();
                                },
                                icon: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Create Your First Project',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _projects.length,
                          itemBuilder: (context, index) {
                            final project = _projects[index];
                            String status = project['aiStatus'] ?? 'Pending';
                            Color statusColor = status == 'Generated'
                                ? Colors.green.shade700
                                : status == 'Failed'
                                ? Colors.red.shade700
                                : Colors.orange.shade700;

                            List<dynamic> tasks =
                                project['aiPlan'] != null &&
                                    project['aiPlan']['developmentTasks'] !=
                                        null
                                ? project['aiPlan']['developmentTasks']
                                : [];
                            int totalTasks = tasks.length;
                            int completedTasks = tasks
                                .where(
                                  (t) =>
                                      t['isCompleted'] == true ||
                                      t['status'] == 'Completed',
                                )
                                .length;

                            double progress = totalTasks > 0
                                ? (completedTasks / totalTasks)
                                : 0.0;

                            int progressPercentage = (progress * 100).toInt();

                            final String? projId =
                                project['_id']?.toString() ??
                                project['id']?.toString();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    if (projId != null && projId.isNotEmpty) {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ProjectDetailScreen(
                                                projectId: projId,
                                              ),
                                        ),
                                      );
                                      if (result == true) {
                                        _fetchDashboardData();
                                      }
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2563EB)
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.code,
                                                color: Color(0xFF3B82F6),
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    project['projectName'] ??
                                                        'Untitled Project',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Type: ${project['projectType'] ?? 'Full-Stack'} ${project['domain'] != null && project['domain'].toString().isNotEmpty ? '• Domain: ${project['domain']}' : ''}',
                                                    style: const TextStyle(
                                                      color: Colors.white38,
                                                      fontSize: 11,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Chip(
                                              label: Text(
                                                status,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              backgroundColor: statusColor,
                                              padding: EdgeInsets.zero,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            const SizedBox(width: 4),
                                            PopupMenuButton<String>(
                                              icon: const Icon(
                                                Icons.more_vert,
                                                color: Colors.white70,
                                                size: 20,
                                              ),
                                              color: const Color(0xFF0F172A),
                                              onSelected: (val) async {
                                                if (val == 'view' &&
                                                    projId != null) {
                                                  final res =
                                                      await Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              ProjectDetailScreen(
                                                                projectId:
                                                                    projId,
                                                              ),
                                                        ),
                                                      );
                                                  if (res == true)
                                                    _fetchDashboardData();
                                                } else if (val == 'delete' &&
                                                    projId != null) {
                                                  _deleteProject(projId);
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'view',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .visibility_outlined,
                                                        color: Colors.white70,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'View Spec',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.delete_outline,
                                                        color: Colors.redAccent,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Delete Project',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.redAccent,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          project['projectIdea'] ??
                                              'No description provided.',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: progress,
                                                  backgroundColor: const Color(
                                                    0xFF0F172A,
                                                  ),
                                                  color: progress == 1.0
                                                      ? Colors.green
                                                      : Colors.orangeAccent,
                                                  minHeight: 6,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              '$progressPercentage% Done',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          automaticallyImplyLeading: false,
          title: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isMobile
                        ? Icons.menu
                        : (_isSidebarCollapsed ? Icons.menu : Icons.menu_open),
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: 'Toggle Sidebar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () {
                    if (isMobile) {
                      showGeneralDialog(
                        context: context,
                        barrierDismissible: true,
                        barrierLabel: 'Sidebar',
                        barrierColor: Colors.black54,
                        transitionDuration: const Duration(milliseconds: 200),
                        pageBuilder: (context, anim1, anim2) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Material(
                              color: Colors.transparent,
                              child: SizedBox(
                                width: 260,
                                height: double.infinity,
                                child: dashboardSidebar,
                              ),
                            ),
                          );
                        },
                      );
                    } else {
                      setState(() {
                        _isSidebarCollapsed = !_isSidebarCollapsed;
                      });
                    }
                  },
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'SpecFlow AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  offset: const Offset(0, 45),
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFF2563EB),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 70),
                        child: Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ],
                  ),
                  onSelected: (value) {
                    if (value == 'profile') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProfileScreen(userEmail: widget.userEmail),
                        ),
                      );
                    } else if (value == 'logout') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AuthScreen(),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Signed in as',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.userEmail,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            color: Colors.white70,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Profile Settings',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.redAccent, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Logout',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: isMobile
            ? dashboardMainContent
            : Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: _isSidebarCollapsed ? 70 : 250,
                    child: dashboardSidebar,
                  ),
                  Expanded(child: dashboardMainContent),
                ],
              ),
      ),
    );
  }

  Widget _buildSidebarItem(
    int index,
    String label,
    IconData icon,
    IconData activeIcon,
    VoidCallback onTap,
  ) {
    bool isSelected = _currentIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: isSelected
            ? const Color(0xFF2563EB).withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: _isSidebarCollapsed ? 12 : 16,
            vertical: 0,
          ),
          leading: Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? const Color(0xFF3B82F6) : Colors.white60,
            size: 20,
          ),
          title: _isSidebarCollapsed
              ? null
              : Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          dense: true,
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white12),
          ),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
