import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'auth_screen.dart';
import 'create_project_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'project_detail_screen.dart';
import 'ai_assistant_screen.dart';

class ProjectsScreen extends StatefulWidget {
  final String userEmail;
  const ProjectsScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _isLoading = true;
  bool _isSidebarVisible = false;
  List<dynamic> _projects = [];
  List<dynamic> _filteredProjects = [];
  String _errorMessage = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _searchController.addListener(_filterProjects);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProjects() async {
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
          _projects = data['projects'] ?? [];
          // Strict filtering: Only show 'Generated' projects in My Projects screen as requested
          _filteredProjects = _projects.where((proj) {
            String status = proj['aiStatus'] ?? 'Pending';
            return status == 'Generated';
          }).toList();
          _isLoading = false;
        });
        _filterProjects();
      } else {
        setState(() {
          _errorMessage = 'Failed to load projects from server.';
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

  void _filterProjects() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProjects = _projects.where((proj) {
        String status = proj['aiStatus'] ?? 'Pending';
        // Only consider Generated projects for the list view
        if (status != 'Generated') return false;

        String name = (proj['projectName'] ?? '').toLowerCase();
        String idea = (proj['projectIdea'] ?? '').toLowerCase();
        String domain = (proj['domain'] ?? '').toLowerCase();
        String type = (proj['projectType'] ?? '').toLowerCase();

        return name.contains(query) ||
            idea.contains(query) ||
            domain.contains(query) ||
            type.contains(query);
      }).toList();
    });
  }

  void _showStatusInfoPopup(Map<String, dynamic> project) {
    String status = project['aiStatus'] ?? 'Pending';
    String title = status == 'Failed'
        ? 'Generation Failed'
        : 'Generation Pending';
    IconData icon = status == 'Failed'
        ? Icons.error_outline
        : Icons.hourglass_empty;
    Color iconColor = status == 'Failed'
        ? Colors.redAccent
        : Colors.orangeAccent;

    String reason = status == 'Failed'
        ? 'This project specification generation failed due to a network timeout, invalid server response, or AI model rate limit error. Please try editing or recreating the project spec.'
        : 'This project is currently queued or awaiting AI engine processing. Please wait a moment or click refresh to check for updates.';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          reason,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProject(String projectId) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Delete Project',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
                  style: TextStyle(color: Colors.white60),
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

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project deleted successfully')),
        );
        _fetchProjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete project')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  void _editProjectDialog(Map<String, dynamic> project) {
    final nameController = TextEditingController(text: project['projectName']);
    final ideaController = TextEditingController(text: project['projectIdea']);
    final domainController = TextEditingController(
      text: project['domain'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit Project Spec',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Project Name',
                  labelStyle: TextStyle(color: Colors.white60),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ideaController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Project Idea / Description',
                  labelStyle: TextStyle(color: Colors.white60),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: domainController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Domain',
                  labelStyle: TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
            onPressed: () async {
              try {
                final response = await http.put(
                  Uri.parse(
                    'https://specflow-ai-mobile-backend.onrender.com/api/projects/${project['_id']}',
                  ),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'projectName': nameController.text.trim(),
                    'projectIdea': ideaController.text.trim(),
                    'domain': domainController.text.trim(),
                  }),
                );

                if (!mounted) return;
                Navigator.pop(context);

                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Project updated successfully! 🚀'),
                    ),
                  );
                  _fetchProjects();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update project')),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Network error: $e')));
              }
            },
            child: const Text(
              'Save Changes',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
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

    Widget premiumSidebar = Material(
      color: const Color(0xFF161E2E),
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: const Color(0xFF161E2E),
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
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
                      radius: 18,
                      backgroundColor: Color(0xFF1E293B),
                      child: Icon(
                        Icons.person,
                        color: Color(0xFF3B82F6),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
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
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
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
            ),
            ListTile(
              leading: const Icon(
                Icons.home_outlined,
                color: Colors.white70,
                size: 20,
              ),
              title: const Text(
                'Dashboard / Home',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              onTap: () {
                if (isMobile) Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DashboardScreen(userEmail: widget.userEmail),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.folder,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
              title: const Text(
                'My Projects',
                style: TextStyle(
                  color: Color(0xFF3B82F6),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                if (isMobile) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.auto_awesome_outlined,
                color: Colors.white70,
                size: 20,
              ),
              title: const Text(
                'AI Assistant',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              onTap: () {
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
            ListTile(
              leading: const Icon(
                Icons.add_circle_outline,
                color: Colors.white70,
                size: 20,
              ),
              title: const Text(
                'Create Project',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              onTap: () {
                if (isMobile) Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreateProjectScreen(userEmail: widget.userEmail),
                  ),
                );
              },
            ),
            const Spacer(),
            Divider(color: Colors.white.withOpacity(0.08), height: 1),
            ListTile(
              leading: const Icon(
                Icons.settings_outlined,
                color: Colors.white70,
                size: 20,
              ),
              title: const Text(
                'Profile Settings',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              onTap: () {
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
              leading: const Icon(
                Icons.logout,
                color: Colors.redAccent,
                size: 20,
              ),
              title: const Text(
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
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    Widget projectsMainContent = _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
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
                    backgroundColor: const Color(0xFF3B82F6),
                  ),
                  onPressed: _fetchProjects,
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _fetchProjects,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search generated projects by name, domain, or idea...',
                            hintStyle: const TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.white54,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF3B82F6),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredProjects.isEmpty
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(48),
                            constraints: const BoxConstraints(maxWidth: 500),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.folder_off_outlined,
                                  size: 56,
                                  color: Colors.white38,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No generated projects found',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Only successfully generated project specs appear here. Create a new one to get started!',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CreateProjectScreen(
                                              userEmail: widget.userEmail,
                                            ),
                                      ),
                                    );
                                    if (result == true) _fetchProjects();
                                  },
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Create Project',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                          itemCount: _filteredProjects.length,
                          itemBuilder: (context, index) {
                            final project = _filteredProjects[index];
                            String status = project['aiStatus'] ?? 'Generated';
                            Color statusColor = Colors.green.shade400;

                            final aiPlan = project['aiPlan'];
                            List developmentTasks = [];
                            if (aiPlan != null &&
                                aiPlan is Map &&
                                aiPlan['developmentTasks'] != null) {
                              developmentTasks =
                                  aiPlan['developmentTasks'] as List;
                            }
                            int totalTasks = developmentTasks.length;

                            int completedTasks = 0;
                            for (var task in developmentTasks) {
                              if (task is Map) {
                                if (task['completed'] == true ||
                                    task['isCompleted'] == true ||
                                    task['isDone'] == true ||
                                    task['checked'] == true ||
                                    task['done'] == true ||
                                    task['status'] == 'completed' ||
                                    task['status'] == 'Completed') {
                                  completedTasks++;
                                }
                              }
                            }

                            double progress = totalTasks > 0
                                ? (completedTasks / totalTasks)
                                : 0.0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1E293B),
                                    Color(0xFF0F172A),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 15,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ProjectDetailScreen(
                                              projectId: project['_id'],
                                            ),
                                      ),
                                    );
                                    if (result == true) _fetchProjects();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(22),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF3B82F6)
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: const Color(0xFF3B82F6)
                                                      .withOpacity(0.3),
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.auto_awesome,
                                                color: Color(0xFF3B82F6),
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
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
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    project['projectIdea'] ?? 'No description provided.',
                                                    style: const TextStyle(
                                                      color: Colors.white60,
                                                      fontSize: 13,
                                                      height: 1.4,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: statusColor
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    border: Border.all(
                                                      color: statusColor
                                                          .withOpacity(0.4),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    status,
                                                    style: TextStyle(
                                                      color: statusColor,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                PopupMenuButton<String>(
                                                  icon: const Icon(
                                                    Icons.more_vert,
                                                    color: Colors.white70,
                                                    size: 20,
                                                  ),
                                                  color: const Color(
                                                    0xFF1E293B,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    side: const BorderSide(
                                                      color: Colors.white12,
                                                    ),
                                                  ),
                                                  onSelected: (value) async {
                                                    if (value == 'open') {
                                                      final result = await Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              ProjectDetailScreen(
                                                                projectId:
                                                                    project['_id'],
                                                              ),
                                                        ),
                                                      );
                                                      if (result == true) {
                                                        _fetchProjects();
                                                      }
                                                    } else if (value ==
                                                        'edit') {
                                                      _editProjectDialog(
                                                        project,
                                                      );
                                                    } else if (value ==
                                                        'delete') {
                                                      _deleteProject(
                                                        project['_id'],
                                                      );
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    const PopupMenuItem(
                                                      value: 'open',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .visibility_outlined,
                                                            color: Colors
                                                                .blueAccent,
                                                            size: 16,
                                                          ),
                                                          SizedBox(width: 10),
                                                          Text(
                                                            'Open Spec',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'edit',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.edit_outlined,
                                                            color: Colors
                                                                .amberAccent,
                                                            size: 16,
                                                          ),
                                                          SizedBox(width: 10),
                                                          Text(
                                                            'Edit Spec',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const PopupMenuDivider(),
                                                    const PopupMenuItem(
                                                      value: 'delete',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .delete_outline,
                                                            color: Colors
                                                                .redAccent,
                                                            size: 16,
                                                          ),
                                                          SizedBox(width: 10),
                                                          Text(
                                                            'Delete Project',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .redAccent,
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
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        const Divider(
                                          color: Colors.white10,
                                          height: 1,
                                        ),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Task Progress ($completedTasks/$totalTasks Tasks)',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${(progress * 100).toInt()}%',
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF3B82F6,
                                                          ),
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    child: LinearProgressIndicator(
                                                      value: progress,
                                                      backgroundColor:
                                                          const Color(
                                                            0xFF0F172A,
                                                          ),
                                                      valueColor:
                                                          const AlwaysStoppedAnimation<
                                                            Color
                                                          >(Color(0xFF3B82F6)),
                                                      minHeight: 6,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  project['projectType'] ??
                                                      'Full-Stack',
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  project['domain'] != null &&
                                                          project['domain']
                                                              .toString()
                                                              .isNotEmpty
                                                      ? project['domain']
                                                      : 'General',
                                                  style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
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
                ),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            PreferredSize(
              preferredSize: const Size.fromHeight(70),
              child: AppBar(
                backgroundColor: const Color(0xFF111827),
                elevation: 0,
                leadingWidth: 100,
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.menu,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Toggle Sidebar',
                      onPressed: () {
                        if (isMobile) {
                          showGeneralDialog(
                            context: context,
                            barrierDismissible: true,
                            barrierLabel: 'Sidebar',
                            barrierColor: Colors.black54,
                            transitionDuration: const Duration(
                              milliseconds: 200,
                            ),
                            pageBuilder: (context, anim1, anim2) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Material(
                                  color: Colors.transparent,
                                  child: SizedBox(
                                    width: 260,
                                    height: double.infinity,
                                    child: premiumSidebar,
                                  ),
                                ),
                              );
                            },
                          );
                        } else {
                          setState(() {
                            _isSidebarVisible = !_isSidebarVisible;
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Back to Dashboard',
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DashboardScreen(userEmail: widget.userEmail),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.folder,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'My Projects',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                iconTheme: const IconThemeData(color: Colors.white),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    tooltip: 'Refresh Projects',
                    onPressed: _fetchProjects,
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
            Expanded(
              child: isMobile
                  ? projectsMainContent
                  : Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: _isSidebarVisible ? 260 : 0,
                          child: ClipRect(
                            child: OverflowBox(
                              minWidth: 0,
                              maxWidth: 260,
                              alignment: Alignment.topLeft,
                              child: premiumSidebar,
                            ),
                          ),
                        ),
                        Expanded(child: projectsMainContent),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
