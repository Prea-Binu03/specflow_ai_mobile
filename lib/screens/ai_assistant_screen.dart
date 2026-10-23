import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import 'dashboard_screen.dart';
import 'projects_screen.dart';
import 'create_project_screen.dart';
import 'profile_screen.dart';
import 'auth_screen.dart';

class ChatSession {
  String id;
  String title;
  List<Map<String, dynamic>> messages;
  DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': id,
    'title': title,
    'messages': messages.map((m) {
      String sender = m['sender'] ?? 'user';
      String role = (sender == 'ai' || sender == 'assistant')
          ? 'assistant'
          : 'user';
      return {
        'role': role,
        'content': m['text'] ?? '',
        if (m['file'] != null) 'file': m['file'],
      };
    }).toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    var rawMessages = json['messages'] as List? ?? [];
    List<Map<String, dynamic>> parsedMessages = rawMessages.map((m) {
      String role = m['role'] ?? 'user';
      String sender = (role == 'assistant' || role == 'ai') ? 'ai' : 'user';
      String text = m['content'] ?? m['text'] ?? '';
      return {
        'sender': sender,
        'text': text,
        if (m['file'] != null) 'file': m['file'],
      };
    }).toList();

    return ChatSession(
      id:
          json['sessionId'] ??
          json['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? 'New Specification Chat',
      messages: parsedMessages,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }
}

class AiAssistantScreen extends StatefulWidget {
  final String userEmail;
  final String? initialProjectContext;
  final String? pinnedProjectName;

  const AiAssistantScreen({
    Key? key,
    required this.userEmail,
    this.initialProjectContext,
    this.pinnedProjectName,
  }) : super(key: key);

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<ChatSession> _sessions = [];
  late ChatSession _currentSession;
  bool _isLoading = false;
  bool _isSidebarVisible = false;
  PlatformFile? _attachedFile;

  @override
  void initState() {
    super.initState();
    _currentSession = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'New Specification Chat',
      messages: [],
      updatedAt: DateTime.now(),
    );
    _sessions.add(_currentSession);

    _fetchUserChats().then((_) {
      if (widget.pinnedProjectName != null &&
          widget.pinnedProjectName!.isNotEmpty) {
        String contextMsg =
            widget.initialProjectContext ??
            "Hi! I need help regarding my project '${widget.pinnedProjectName}'.";

        setState(() {
          _currentSession.messages.add({'sender': 'user', 'text': contextMsg});
          _currentSession.title = 'Chat: ${widget.pinnedProjectName}';
        });

        _sendInitialContextToAI(contextMsg);
      } else if (widget.initialProjectContext != null &&
          widget.initialProjectContext!.isNotEmpty) {
        setState(() {
          _currentSession.messages.add({
            'sender': 'user',
            'text': widget.initialProjectContext!,
          });
        });
        _sendInitialContextToAI(widget.initialProjectContext!);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserChats() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://specflow-ai-mobile-backend.onrender.com/api/chats?userEmail=${widget.userEmail}',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['sessions'] != null) {
          final List loadedSessions = data['sessions'];
          setState(() {
            if (loadedSessions.isNotEmpty) {
              _sessions = loadedSessions
                  .map((s) => ChatSession.fromJson(s))
                  .toList();
              _currentSession = _sessions.first;
            }
          });
        }
      }
    } catch (e) {
      print("⚠️ Error fetching chat history: $e");
    }
  }

  Future<void> _saveCurrentSessionToBackend() async {
    try {
      List<Map<String, dynamic>> backendMessages = _currentSession.messages.map(
        (m) {
          String sender = m['sender'] ?? 'user';
          String role = (sender == 'ai' || sender == 'assistant')
              ? 'assistant'
              : 'user';
          return {
            'role': role,
            'content': m['text'] ?? '',
            if (m['file'] != null) 'file': m['file'],
          };
        },
      ).toList();

      await http.post(
        Uri.parse('https://specflow-ai-mobile-backend.onrender.com/api/chats'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userEmail': widget.userEmail,
          'sessionId': _currentSession.id,
          'title': _currentSession.title,
          'messages': backendMessages,
        }),
      );
    } catch (e) {
      print("⚠️ Error saving chat session: $e");
    }
  }

  Future<void> _sendInitialContextToAI(String promptText) async {
    setState(() => _isLoading = true);
    try {
      final promptToSend = widget.pinnedProjectName != null
          ? "[Project Context: ${widget.pinnedProjectName}] $promptText"
          : promptText;

      final response = await http.post(
        Uri.parse(
          'https://specflow-ai-mobile-backend.onrender.com/api/ai/assistant',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': promptToSend}),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final replyText =
            data['reply'] ??
            data['response'] ??
            'Hello! I am ready to help you with your project specs.';
        setState(() {
          _currentSession.messages.add({'sender': 'ai', 'text': replyText});
        });
        await _saveCurrentSessionToBackend();
      }
    } catch (e) {
      setState(() {
        _currentSession.messages.add({
          'sender': 'ai',
          'text': 'Connected to workspace. How can I help with this project?',
        });
      });
      await _saveCurrentSessionToBackend();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _createNewSession({bool initial = false}) {
    final newSession = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: widget.pinnedProjectName != null
          ? 'Chat: ${widget.pinnedProjectName}'
          : 'New Specification Chat',
      messages: [],
      updatedAt: DateTime.now(),
    );
    setState(() {
      _sessions.insert(0, newSession);
      _currentSession = newSession;
    });
    _saveCurrentSessionToBackend();
  }

  void _switchSession(ChatSession session) {
    setState(() {
      _currentSession = session;
    });
  }

  Future<void> _deleteSession(String sessionId) async {
    try {
      await http.delete(
        Uri.parse(
          'https://specflow-ai-mobile-backend.onrender.com/api/chats/$sessionId',
        ),
      );
    } catch (e) {
      print("⚠️ Error deleting chat session from backend: $e");
    }

    setState(() {
      _sessions.removeWhere((s) => s.id == sessionId);
      if (_sessions.isEmpty) {
        _createNewSession(initial: true);
      } else if (_currentSession.id == sessionId) {
        _currentSession = _sessions.first;
      }
    });
  }

  Future<void> _pickAttachment() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result != null) {
        setState(() {
          _attachedFile = result.files.first;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  Future<void> _sendMessage({String? editedText, int? editIndex}) async {
    final text = editedText ?? _messageController.text.trim();
    if (text.isEmpty && _attachedFile == null) return;

    if (editIndex != null) {
      setState(() {
        _currentSession.messages[editIndex]['text'] = text;
        _currentSession.updatedAt = DateTime.now();
        _isLoading = true;
      });
    } else {
      _messageController.clear();
      final currentFile = _attachedFile;

      if (_currentSession.title == 'New Specification Chat' &&
          text.isNotEmpty) {
        _currentSession.title = text.length > 25
            ? '${text.substring(0, 25)}...'
            : text;
      }

      setState(() {
        _attachedFile = null;
        _currentSession.messages.add({
          'sender': 'user',
          'text': text,
          'file': currentFile?.name,
        });
        _currentSession.updatedAt = DateTime.now();
        _isLoading = true;
      });
    }

    await _saveCurrentSessionToBackend();

    try {
      final promptToSend = widget.pinnedProjectName != null
          ? "[Project Context: ${widget.pinnedProjectName}] $text"
          : text;

      final response = await http.post(
        Uri.parse(
          'https://specflow-ai-mobile-backend.onrender.com/api/ai/assistant',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': promptToSend}),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final replyText =
            data['reply'] ?? data['response'] ?? 'No reply received from AI.';

        setState(() {
          if (editIndex != null &&
              editIndex + 1 < _currentSession.messages.length) {
            _currentSession.messages[editIndex + 1]['text'] = replyText;
          } else {
            _currentSession.messages.add({'sender': 'ai', 'text': replyText});
          }
          _currentSession.updatedAt = DateTime.now();
        });
        await _saveCurrentSessionToBackend();
      } else {
        setState(() {
          _currentSession.messages.add({
            'sender': 'ai',
            'text':
                'Error: Failed to fetch AI response (Status ${response.statusCode})',
          });
        });
        await _saveCurrentSessionToBackend();
      }
    } catch (e) {
      setState(() {
        _currentSession.messages.add({
          'sender': 'ai',
          'text': 'Network error: $e',
        });
      });
      await _saveCurrentSessionToBackend();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _editMessage(int index) {
    final msg = _currentSession.messages[index];
    if (msg['sender'] != 'user') return;

    _messageController.text = msg['text'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit Prompt',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: _messageController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
            ),
            onPressed: () {
              Navigator.pop(context);
              final updatedText = _messageController.text.trim();
              _messageController.clear();
              _sendMessage(editedText: updatedText, editIndex: index);
            },
            child: const Text(
              'Update & Regenerate',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(int index) {
    setState(() {
      _currentSession.messages.removeAt(index);
      if (index < _currentSession.messages.length &&
          _currentSession.messages[index]['sender'] == 'ai') {
        _currentSession.messages.removeAt(index);
      }
      _currentSession.updatedAt = DateTime.now();
    });
    _saveCurrentSessionToBackend();
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
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              dense: true,
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
              dense: true,
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
              dense: true,
              leading: const Icon(
                Icons.auto_awesome,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
              title: const Text(
                'AI Assistant',
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
              dense: true,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CHATS',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle,
                      color: Color(0xFF3B82F6),
                      size: 16,
                    ),
                    onPressed: () {
                      if (isMobile) Navigator.pop(context);
                      _createNewSession();
                    },
                    tooltip: 'New Chat',
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 110,
              child: ListView.builder(
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  final isSelected = session.id == _currentSession.id;
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF3B82F6).withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.chat_bubble_outline,
                        color: isSelected
                            ? const Color(0xFF3B82F6)
                            : Colors.white60,
                        size: 14,
                      ),
                      title: Text(
                        session.title,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 14,
                        ),
                        onPressed: () => _deleteSession(session.id),
                      ),
                      onTap: () {
                        if (isMobile) Navigator.pop(context);
                        _switchSession(session);
                      },
                    ),
                  );
                },
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.08), height: 1),
            ListTile(
              dense: true,
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
              dense: true,
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    Widget chatMainContent = Column(
      children: [
        if (widget.pinnedProjectName != null &&
            widget.pinnedProjectName!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.push_pin, color: Color(0xFF3B82F6), size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Active Pinned Project: ',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Expanded(
                  child: Text(
                    widget.pinnedProjectName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'Context Active',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _currentSession.messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF3B82F6),
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'How can I help you with your project specs today?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Ask Gemini about software architecture, code snippets, or system design.',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _currentSession.messages.length,
                  itemBuilder: (context, index) {
                    final msg = _currentSession.messages[index];
                    final isUser = msg['sender'] == 'user';
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: isUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF3B82F6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              constraints: const BoxConstraints(maxWidth: 650),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: isUser
                                    ? null
                                    : Border.all(color: Colors.white12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (msg['file'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.attach_file,
                                            color: Colors.amberAccent,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            msg['file'],
                                            style: const TextStyle(
                                              color: Colors.amberAccent,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Text(
                                    msg['text'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isUser)
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white60,
                                  size: 18,
                                ),
                                color: const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                onSelected: (value) {
                                  if (value == 'edit') _editMessage(index);
                                  if (value == 'delete') _deleteMessage(index);
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text(
                                      'Edit Prompt',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: LinearProgressIndicator(color: Color(0xFF3B82F6)),
          ),
        if (_attachedFile != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                const Icon(
                  Icons.insert_drive_file,
                  color: Colors.amberAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _attachedFile!.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _attachedFile = null),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file, color: Colors.white70),
                tooltip: 'Upload Image or Document',
                onPressed: _pickAttachment,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: widget.pinnedProjectName != null
                        ? 'Ask about ${widget.pinnedProjectName} specs...'
                        : 'Ask Gemini about software specs...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : () => _sendMessage(),
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0F172A),
      appBar: PreferredSize(
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
                icon: const Icon(Icons.menu, color: Colors.white, size: 20),
                tooltip: 'Toggle Sidebar',
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gemini Pro AI Workspace',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _currentSession.title,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.add_comment_outlined,
                color: Color(0xFF3B82F6),
              ),
              tooltip: 'New Chat Session',
              onPressed: () => _createNewSession(),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
      body: isMobile
          ? chatMainContent
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
                Expanded(child: chatMainContent),
              ],
            ),
    );
  }
}
