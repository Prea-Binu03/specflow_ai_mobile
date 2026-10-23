import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import 'auth_screen.dart';
import 'dashboard_screen.dart';
import 'projects_screen.dart';
import 'profile_screen.dart';
import 'ai_assistant_screen.dart';
import 'project_detail_screen.dart';

class CreateProjectScreen extends StatefulWidget {
  final String userEmail;
  final String? initialProjectName;
  final String? initialProjectIdea;
  final String? initialDomain;

  const CreateProjectScreen({
    Key? key,
    required this.userEmail,
    this.initialProjectName,
    this.initialProjectIdea,
    this.initialDomain,
  }) : super(key: key);

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ideaController;
  late final TextEditingController _domainController;
  final TextEditingController _customProjectTypeController =
      TextEditingController();

  String _projectType = 'Full-Stack Application';
  final String _technologyPreference = 'AI Recommended';
  bool _isLoading = false;
  bool _isGeneratingSuggestions = false;
  bool _isSidebarVisible =
      false; // Mobile ke liye default false taaki content na dabey

  final _ideaKeywordController = TextEditingController();
  List<dynamic> _aiSuggestions = [];

  PlatformFile? _selectedImage;
  PlatformFile? _selectedDocument;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialProjectName ?? '',
    );
    _ideaController = TextEditingController(
      text: widget.initialProjectIdea ?? '',
    );
    _domainController = TextEditingController(text: widget.initialDomain ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ideaController.dispose();
    _domainController.dispose();
    _customProjectTypeController.dispose();
    _ideaKeywordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null) {
        setState(() {
          _selectedImage = result.files.first;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
        withData: true,
      );
      if (result != null) {
        setState(() {
          _selectedDocument = result.files.first;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error picking document: $e')));
    }
  }

  Future<void> _fetchAiSuggestions(StateSetter setDialogState) async {
    String keyword = _ideaKeywordController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a keyword or topic')),
      );
      return;
    }

    setDialogState(() => _isGeneratingSuggestions = true);

    try {
      final response = await http.post(
        Uri.parse(
          'https://specflow-ai-mobile-backend.onrender.com/api/ai/project-recommendations',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic': keyword,
          'techStack': _technologyPreference,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setDialogState(() {
          _aiSuggestions = data['ideas'] ?? [];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate AI suggestions')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Network error: $e')));
    } finally {
      setDialogState(() => _isGeneratingSuggestions = false);
    }
  }

  void _showGenerateIdeasDialog(BuildContext context) {
    _ideaKeywordController.clear();
    _aiSuggestions.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
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
            height: 500,
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isGeneratingSuggestions
                          ? null
                          : () => _fetchAiSuggestions(setDialogState),
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
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_aiSuggestions.isNotEmpty)
                  const Text(
                    'Select a suggested project to auto-fill spec:',
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
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _nameController.text =
                                  suggestion['projectName'] ?? '';
                              _ideaController.text =
                                  suggestion['description'] ?? '';
                              _domainController.text =
                                  suggestion['domain'] ??
                                  _ideaKeywordController.text.trim();
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'AI suggestion applied successfully! 🚀',
                                ),
                                backgroundColor: Color(0xFF2563EB),
                              ),
                            );
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
                                  suggestion['projectName'] ?? 'Project Option',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  suggestion['description'] ?? '',
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

  Future<void> _submitProject() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final String finalProjectType = _projectType == 'Other'
        ? _customProjectTypeController.text.trim()
        : _projectType;

    try {
      final response = await http.post(
        Uri.parse(
          'https://specflow-ai-mobile-backend.onrender.com/api/projects',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userEmail': widget.userEmail,
          'projectName': _nameController.text.trim(),
          'projectIdea': _ideaController.text.trim(),
          'projectType': finalProjectType,
          'technologyPreference': _technologyPreference,
          'domain': _domainController.text.trim(),
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final createdProject = data['project'];
        final String newProjectId =
            createdProject['_id'] ?? createdProject['id'];

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailScreen(projectId: newProjectId),
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to create project'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Network error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                Icons.folder_outlined,
                color: Colors.white70,
                size: 20,
              ),
              title: const Text(
                'My Projects',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProjectsScreen(userEmail: widget.userEmail),
                  ),
                );
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AiAssistantScreen(userEmail: widget.userEmail),
                  ),
                );
              },
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3B82F6).withOpacity(0.25),
                    const Color(0xFF1D4ED8).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.add_circle,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
                title: const Text(
                  'Create Project',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {},
              ),
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

    Widget createProjectMainContent = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640),
          padding: const EdgeInsets.all(36.0),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF3B82F6),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Initialize AI Project Spec',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Provide your project details and attachments for AI generation.',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Project Name *',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(
                      Icons.folder_open,
                      color: Colors.blueAccent,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1F2937),
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
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Please enter project name'
                      : null,
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _ideaController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Project Idea / Description *',
                    labelStyle: const TextStyle(color: Colors.white70),
                    alignLabelWithHint: true,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 64),
                      child: Icon(Icons.lightbulb_outline, color: Colors.amber),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1F2937),
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
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Please describe your project idea'
                      : null,
                ),
                const SizedBox(height: 22),
                DropdownButtonFormField<String>(
                  value: _projectType,
                  dropdownColor: const Color(0xFF1F2937),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Project Type',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(
                      Icons.code,
                      color: Colors.tealAccent,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1F2937),
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
                  ),
                  items:
                      [
                            'Full-Stack Application',
                            'Mobile App',
                            'AI/ML System',
                            'Web API',
                            'Other',
                          ]
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                  onChanged: (val) => setState(() => _projectType = val!),
                ),

                if (_projectType == 'Other') ...[
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: _customProjectTypeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Enter Custom Project Type *',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(
                        Icons.edit_note,
                        color: Colors.tealAccent,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1F2937),
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
                    ),
                    validator: (v) {
                      if (_projectType == 'Other' && (v == null || v.isEmpty)) {
                        return 'Please enter your custom project type';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 22),
                TextFormField(
                  controller: _domainController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Domain (e.g., Healthcare, FinTech, E-Commerce)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(
                      Icons.domain,
                      color: Colors.purpleAccent,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1F2937),
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
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Attachments (Optional)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.15),
                          ),
                          backgroundColor: const Color(0xFF1F2937),
                        ),
                        onPressed: _pickImage,
                        icon: const Icon(
                          Icons.image_outlined,
                          color: Colors.blueAccent,
                        ),
                        label: Text(
                          _selectedImage == null
                              ? 'Upload Image'
                              : _selectedImage!.name,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.15),
                          ),
                          backgroundColor: const Color(0xFF1F2937),
                        ),
                        onPressed: _pickDocument,
                        icon: const Icon(
                          Icons.insert_drive_file_outlined,
                          color: Colors.amberAccent,
                        ),
                        label: Text(
                          _selectedDocument == null
                              ? 'Upload Document'
                              : _selectedDocument!.name,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor: const Color(0xFF3B82F6).withOpacity(0.5),
                    ),
                    onPressed: _isLoading ? null : _submitProject,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save & Initialize Project Spec',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
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
                        setState(() {
                          _isSidebarVisible = !_isSidebarVisible;
                        });
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
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Create Project',
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
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.purpleAccent),
                      backgroundColor: Colors.purpleAccent.withOpacity(0.12),
                      foregroundColor: Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _showGenerateIdeasDialog(context),
                    icon: const Icon(Icons.lightbulb_outline, size: 16),
                    label: const Text(
                      'Generate Ideas',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<String>(
                    offset: const Offset(0, 50),
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0xFF3B82F6),
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                        ],
                      ),
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(
                              Icons.logout,
                              color: Colors.redAccent,
                              size: 16,
                            ),
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
                  const SizedBox(width: 12),
                ],
              ),
            ),
            Expanded(
              child: isMobile
                  ? Stack(
                      children: [
                        createProjectMainContent,
                        if (_isSidebarVisible) ...[
                          GestureDetector(
                            onTap: () =>
                                setState(() => _isSidebarVisible = false),
                            child: Container(color: Colors.black54),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 260,
                            child: premiumSidebar,
                          ),
                        ],
                      ],
                    )
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
                        Expanded(child: createProjectMainContent),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
