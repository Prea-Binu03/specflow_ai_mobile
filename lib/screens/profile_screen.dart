import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import 'auth_screen.dart';
import 'create_project_screen.dart';
import 'dashboard_screen.dart';
import 'projects_screen.dart';
import 'ai_assistant_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userEmail;
  const ProfileScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSidebarVisible = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _customRoleController = TextEditingController();

  String _selectedRole = 'Software Developer';
  bool _isCustomRole = false;
  PlatformFile? _selectedAvatar;

  final List<String> _roleOptions = [
    'Software Developer',
    'Project Manager',
    'AI Engineer',
    'UI/UX Designer',
    'Full-Stack Developer',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _customRoleController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
          'https://specflow-ai-mobile-backend.onrender.com/api/users/profile?email=${widget.userEmail}',
        ),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _nameController.text = data['name'] ?? widget.userEmail.split('@')[0];
          _phoneController.text = data['phone'] ?? '';
          _bioController.text = data['bio'] ?? '';

          String dbRole = data['role'] ?? 'Software Developer';
          if (_roleOptions.contains(dbRole)) {
            _selectedRole = dbRole;
            _isCustomRole = false;
          } else {
            _selectedRole = 'Other';
            _customRoleController.text = dbRole;
            _isCustomRole = true;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _nameController.text = widget.userEmail.split('@')[0];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nameController.text = widget.userEmail.split('@')[0];
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null) {
        setState(() {
          _selectedAvatar = result.files.first;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    String finalRole = _isCustomRole
        ? _customRoleController.text.trim()
        : _selectedRole;

    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse(
          'https://specflow-ai-mobile-backend.onrender.com/api/users/profile',
        ),
      );

      request.fields['email'] = widget.userEmail;
      request.fields['name'] = _nameController.text.trim();
      request.fields['phone'] = _phoneController.text.trim();
      request.fields['bio'] = _bioController.text.trim();
      request.fields['role'] = finalRole;

      if (_selectedAvatar != null && _selectedAvatar!.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'avatar',
            _selectedAvatar!.bytes!,
            filename: _selectedAvatar!.name,
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully! 🚀')),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to update profile'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Network error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 768;
    String userName = _nameController.text.isNotEmpty
        ? _nameController.text
        : widget.userEmail.split('@')[0];
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
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF1E293B),
                      backgroundImage:
                          _selectedAvatar != null &&
                              _selectedAvatar!.bytes != null
                          ? MemoryImage(_selectedAvatar!.bytes!)
                          : null,
                      child: _selectedAvatar == null
                          ? const Icon(
                              Icons.person,
                              color: Color(0xFF3B82F6),
                              size: 18,
                            )
                          : null,
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
                Icons.folder_outlined,
                color: Colors.white70,
                size: 20,
              ),
              title: const Text(
                'My Projects',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              onTap: () {
                if (isMobile) Navigator.pop(context);
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
                color: Color(0xFF3B82F6),
                size: 20,
              ),
              title: const Text(
                'Profile Settings',
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

    Widget profileMainContent = _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
          )
        : Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: const Color(0xFF2563EB),
                            backgroundImage:
                                _selectedAvatar != null &&
                                    _selectedAvatar!.bytes != null
                                ? MemoryImage(_selectedAvatar!.bytes!)
                                : null,
                            child: _selectedAvatar == null
                                ? const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 50,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _pickAvatar,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF3B82F6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        widget.userEmail,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 20),

                    const Text(
                      'Account Information',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      initialValue: widget.userEmail,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white54),
                      decoration: InputDecoration(
                        labelText: 'Email Address (Locked)',
                        labelStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: Colors.blueAccent,
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
                            color: Color(0xFF2563EB),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: Colors.greenAccent,
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
                            color: Color(0xFF2563EB),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Workspace Role',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(
                          Icons.work_outline,
                          color: Colors.purpleAccent,
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
                            color: Color(0xFF2563EB),
                            width: 2,
                          ),
                        ),
                      ),
                      items: _roleOptions
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedRole = val!;
                          _isCustomRole = (_selectedRole == 'Other');
                        });
                      },
                    ),

                    if (_isCustomRole) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _customRoleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Enter Custom Role',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(
                            Icons.edit_note,
                            color: Colors.amberAccent,
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
                              color: Color(0xFF2563EB),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _bioController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Bio / Description',
                        labelStyle: const TextStyle(color: Colors.white70),
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 40),
                          child: Icon(
                            Icons.info_outline,
                            color: Colors.tealAccent,
                          ),
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
                            color: Color(0xFF2563EB),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveProfile,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save, color: Colors.white),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save Profile Changes',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AuthScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text(
                        'Logout Account',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: AppBar(
          backgroundColor: const Color(0xFF111827),
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 22),
                tooltip: 'Toggle Sidebar',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
                tooltip: 'Back to Dashboard',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.settings,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Profile & Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: PopupMenuButton<String>(
                  offset: const Offset(0, 45),
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF3B82F6),
                        backgroundImage:
                            _selectedAvatar != null &&
                                _selectedAvatar!.bytes != null
                            ? MemoryImage(_selectedAvatar!.bytes!)
                            : null,
                        child: _selectedAvatar == null
                            ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ],
                  ),
                  onSelected: (value) {
                    if (value == 'logout') {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AuthScreen(),
                        ),
                        (route) => false,
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
              ),
            ],
          ),
        ),
      ),
      body: isMobile
          ? profileMainContent
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
                Expanded(child: profileMainContent),
              ],
            ),
    );
  }
}
