import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'auth_screen.dart';
import 'dashboard_screen.dart';
import 'projects_screen.dart';
import 'profile_screen.dart';
import 'create_project_screen.dart';
import 'ai_assistant_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  const ProjectDetailScreen({Key? key, required this.projectId})
    : super(key: key);

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _isSaving = false;
  bool _isSidebarVisible = false;
  Map<String, dynamic>? _project;
  String _errorMessage = '';

  final Map<int, bool> _expandedModules = {
    0: true,
    1: false,
    2: true,
    3: true,
    4: false,
    5: false,
    6: true,
  };

  final List<String> _taskTitles = [
    'Initialize project workspace and modular architecture setup',
    'Configure backend services, database schema, and secure migrations',
    'Implement JWT-based secure authentication & role management',
    'Build core data ingestion pipelines and third-party API clients',
    'Implement automated business logic and background queue workers',
    'Develop secure payment gateway / transaction handling module',
    'Create automated export and reporting engines (PDF/Excel)',
    'Build responsive, accessible user interface with modern styling',
    'Implement real-time notification services and alerts',
    'Write unit and integration tests for core business workflows',
    'Configure caching layer for high-performance data retrieval',
    'Setup CI/CD deployment pipelines on cloud infrastructure',
    'Perform security audit, performance tuning, and final documentation',
  ];

  late List<bool> _taskCompleted;

  @override
  void initState() {
    super.initState();
    _taskCompleted = List.generate(_taskTitles.length, (index) => false);
    _fetchProjectDetails();
  }

  String _cleanPdfText(String input) {
    if (input.isEmpty) return '';
    String cleaned = input
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u200B', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\uFEFF', '');

    cleaned = cleaned
        .replaceAll('•', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'");

    return cleaned.replaceAll(RegExp(r'[^\x20-\x7E\r\n\t]'), '').trim();
  }

  Future<void> _fetchProjectDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://specflow-ai-mobile-backend.onrender.com/api/projects/${widget.projectId}',
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final proj = data['project'] ?? data;

        List<bool> loadedTasks = List.generate(
          _taskTitles.length,
          (index) => false,
        );
        if (proj['aiPlan'] != null &&
            proj['aiPlan']['developmentTasks'] != null) {
          List tasks = proj['aiPlan']['developmentTasks'];
          for (int i = 0; i < tasks.length && i < loadedTasks.length; i++) {
            if (tasks[i] is Map) {
              loadedTasks[i] =
                  tasks[i]['isCompleted'] == true ||
                  tasks[i]['status'] == 'Completed';
            }
          }
        }

        setState(() {
          _project = proj;
          _taskCompleted = loadedTasks;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load project details.';
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

  Future<void> _saveTasksProgress() async {
    if (_project == null) return;
    setState(() => _isSaving = true);

    try {
      List<Map<String, dynamic>> updatedTasksList = [];
      for (int i = 0; i < _taskTitles.length; i++) {
        updatedTasksList.add({
          'taskNumber': i + 1,
          'title': _taskTitles[i],
          'description': 'Status: Ready for code generation',
          'isCompleted': _taskCompleted[i],
          'status': _taskCompleted[i] ? 'Completed' : 'Pending',
        });
      }

      Map<String, dynamic> updatedAiPlan = _project!['aiPlan'] ?? {};
      updatedAiPlan['developmentTasks'] = updatedTasksList;

      final response = await http.put(
        Uri.parse(
          'https://specflow-ai-mobile-backend.onrender.com/api/projects/${widget.projectId}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'aiPlan': updatedAiPlan}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Development task progress saved successfully! 🚀'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save task progress.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  Future<void> _deleteProject() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Project',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this project? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
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
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isDeleting = true);

              try {
                final response = await http.delete(
                  Uri.parse(
                    'https://specflow-ai-mobile-backend.onrender.com/api/projects/${widget.projectId}',
                  ),
                );

                if (!mounted) return;

                if (response.statusCode == 200) {
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Project deleted successfully!'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete project.')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Network error: $e')));
              } finally {
                if (mounted) setState(() => _isDeleting = false);
              }
            },
            child: _isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_project == null) return;

    final pdf = pw.Document();
    final projName = _cleanPdfText(
      _project!['projectName'] ?? 'Project Report',
    );
    final projIdea = _cleanPdfText(_project!['projectIdea'] ?? '');
    final domain = _cleanPdfText(_project!['domain'] ?? 'General');
    final projectType = _cleanPdfText(
      _project!['projectType'] ?? 'Full-Stack Application',
    );

    Map<String, dynamic> techData = _getDynamicTechStack();
    Map<String, String> recommendedStack = Map<String, String>.from(
      techData['stack'],
    );
    String whyStack = _cleanPdfText(techData['why'] ?? '');
    Map<String, String> dynamicSpecs = Map<String, String>.from(
      techData['specs'],
    );

    List<String> rawReqs = (dynamicSpecs['reqs'] ?? '')
        .split('\n')
        .map((line) => _cleanPdfText(line.replaceAll('-', '').trim()))
        .where((line) => line.isNotEmpty)
        .toList();

    final primaryBlue = PdfColor.fromHex('#2563EB');
    final darkNavy = PdfColor.fromHex('#0F172A');
    final borderColor = PdfColor.fromHex('#CBD5E1');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: primaryBlue, width: 2),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: darkNavy,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'SPECFLOW AI - SPECIFICATION REPORT',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: pw.BoxDecoration(
                            color: primaryBlue,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            'CONFIDENTIAL',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F8FAFC'),
                      border: pw.Border.all(color: borderColor),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Project Name: $projName',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: darkNavy,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Domain: $domain | Architecture: $projectType',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColor.fromHex('#475569'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  _buildPdfSectionHeader(
                    '1. Project Overview & Vision',
                    primaryBlue,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    projIdea,
                    style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 1.3),
                  ),
                  pw.SizedBox(height: 12),
                  _buildPdfSectionHeader(
                    '2. Recommended Technology Stack',
                    primaryBlue,
                  ),
                  pw.SizedBox(height: 4),
                  ...recommendedStack.entries.map(
                    (e) => pw.Bullet(
                      text:
                          '${_cleanPdfText(e.key)}: ${_cleanPdfText(e.value)}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Rationale:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    whyStack,
                    style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.2),
                  ),
                  pw.SizedBox(height: 12),
                  _buildPdfSectionHeader(
                    '3. Functional Requirements & Specs',
                    primaryBlue,
                  ),
                  pw.SizedBox(height: 4),
                  if (rawReqs.isNotEmpty)
                    ...rawReqs.map(
                      (req) => pw.Bullet(
                        text: req,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    )
                  else
                    pw.Text(
                      _cleanPdfText(dynamicSpecs['reqs'] ?? ''),
                      style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.2),
                    ),
                  pw.SizedBox(height: 12),
                  _buildPdfSectionHeader(
                    '4. Technical Architecture & Security',
                    primaryBlue,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _cleanPdfText(dynamicSpecs['arch'] ?? ''),
                    style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.2),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _cleanPdfText(dynamicSpecs['sec'] ?? ''),
                    style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.2),
                  ),
                  pw.SizedBox(height: 12),
                  _buildPdfSectionHeader(
                    '5. Development Tasks & Milestones',
                    primaryBlue,
                  ),
                  pw.SizedBox(height: 6),
                  ...List.generate(
                    _taskTitles.length,
                    (i) => pw.Bullet(
                      text:
                          'Task ${i + 1}: ${_cleanPdfText(_taskTitles[i])} [${_taskCompleted[i] ? "Completed" : "Pending"}]',
                      style: const pw.TextStyle(fontSize: 8.5),
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '${projName.replaceAll(' ', '_')}_Full_Report.pdf',
    );
  }

  pw.Widget _buildPdfSectionHeader(String title, PdfColor color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#EFF6FF'),
        border: pw.Border(left: pw.BorderSide(color: color, width: 3)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Future<void> _exportDocx() async {
    if (_project == null) return;

    final projName = _cleanPdfText(
      _project!['projectName'] ?? 'Project Report',
    );
    final projIdea = _cleanPdfText(_project!['projectIdea'] ?? '');
    final domain = _cleanPdfText(_project!['domain'] ?? 'General');
    final projectType = _cleanPdfText(
      _project!['projectType'] ?? 'Full-Stack Application',
    );

    Map<String, dynamic> techData = _getDynamicTechStack();
    Map<String, String> recommendedStack = Map<String, String>.from(
      techData['stack'],
    );
    String whyStack = _cleanPdfText(techData['why'] ?? '');
    Map<String, String> dynamicSpecs = Map<String, String>.from(
      techData['specs'],
    );

    String docxContent =
        '''
<html xmlns:o="urn:schemas-microsoft-com:office:office" 
      xmlns:w="urn:schemas-microsoft-com:office:word" 
      xmlns="http://www.w3.org/TR/REC-html40">
<head>
<meta charset="utf-8">
<title>$projName Specification</title>
<style>
  body {
    font-family: 'Calibri', 'Segoe UI', Arial, sans-serif;
    color: #1E293B;
    font-size: 11pt;
    line-height: 1.6;
    margin: 40px;
  }
  .page-border {
    border: 3px solid #2563EB;
    padding: 24px;
    border-radius: 8px;
  }
  .header-box {
    background-color: #0F172A;
    color: #FFFFFF;
    padding: 16px;
    font-weight: bold;
    font-size: 16pt;
    text-align: center;
    margin-bottom: 20px;
  }
  .info-box {
    background-color: #F8FAFC;
    border: 1px solid #CBD5E1;
    padding: 12px;
    margin-bottom: 20px;
  }
  .section-hdr {
    background-color: #EFF6FF;
    color: #2563EB;
    padding: 8px 12px;
    font-size: 12pt;
    font-weight: bold;
    margin-top: 20px;
    margin-bottom: 10px;
  }
  ul { margin-top: 5px; }
  li { font-size: 11pt; margin-bottom: 5px; }
  p { font-size: 11pt; margin-bottom: 10px; }
</style>
</head>
<body>
<div class="page-border">
  <div class="header-box">SPECFLOW AI - SPECIFICATION REPORT</div>

  <div class="info-box">
    <b style="font-size: 13pt; color: #0F172A;">Project Name: $projName</b><br>
    <span style="color: #475569;">Domain: $domain | Architecture: $projectType</span>
  </div>

  <div class="section-hdr">1. Project Overview & Vision</div>
  <p>$projIdea</p>

  <div class="section-hdr">2. Recommended Technology Stack</div>
  <ul>
    ${recommendedStack.entries.map((e) => "<li><b>${_cleanPdfText(e.key)}:</b> ${_cleanPdfText(e.value)}</li>").join('')}
  </ul>
  <p><b>Why This Stack:</b> $whyStack</p>

  <div class="section-hdr">3. Functional Requirements & Specifications</div>
  <p>${_cleanPdfText(dynamicSpecs['reqs'] ?? '')}</p>

  <div class="section-hdr">4. Technical Architecture & Security</div>
  <p>${_cleanPdfText(dynamicSpecs['arch'] ?? '')}</p>
  <p>${_cleanPdfText(dynamicSpecs['sec'] ?? '')}</p>

  <div class="section-hdr">5. Development Tasks & Milestones</div>
  <ul>
    ${List.generate(_taskTitles.length, (i) => "<li><b>Task ${i + 1}:</b> ${_cleanPdfText(_taskTitles[i])} [${_taskCompleted[i] ? 'Completed' : 'Pending'}]</li>").join('')}
  </ul>
</div>
</body>
</html>
''';

    final List<int> bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(docxContent)];

    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: '${projName.replaceAll(' ', '_')}_Specification.doc',
    );
  }

  Map<String, dynamic> _getDynamicTechStack() {
    Map<String, dynamic> aiPlan =
        (_project != null && _project!['aiPlan'] != null)
        ? _project!['aiPlan']
        : {};

    var rawStack = aiPlan['technologyStack'] ?? aiPlan['techStack'];
    Map<String, String> stackMap = {};
    if (rawStack is Map) {
      rawStack.forEach((k, v) {
        String keyName = k.toString();
        if (keyName.isNotEmpty) {
          keyName = keyName[0].toUpperCase() + keyName.substring(1);
        }
        stackMap[keyName] = v.toString();
      });
    } else {
      stackMap = {
        'Frontend': 'Configured via AI Plan',
        'Backend': 'Configured via AI Plan',
        'Database': 'Configured via AI Plan',
      };
    }

    String whyText =
        aiPlan['whyTechnology'] ??
        aiPlan['whyThisStack'] ??
        'Selected based on specific architectural requirements and project scope.';

    List<dynamic> rawAlternatives = aiPlan['alternatives'] ?? [];
    List<Map<String, String>> altList = [];
    if (rawAlternatives.isNotEmpty) {
      for (var alt in rawAlternatives) {
        if (alt is Map) {
          altList.add({
            'name': alt['name']?.toString() ?? 'Alternative Option',
            'desc': alt['desc']?.toString() ?? '',
          });
        } else if (alt is String) {
          altList.add({
            'name': alt,
            'desc': 'Alternative architectural approach considered for this project scope.',
          });
        }
      }
    } else {
      altList = [
        {
          'name': 'Standard Architecture Option',
          'desc':
              'Alternative containerized architecture option considered by AI.',
        },
      ];
    }

    String reqsText = '';
    if (aiPlan['requirements'] is List) {
      reqsText = (aiPlan['requirements'] as List)
          .map((r) => '• ${r.toString()}'.trim())
          .join('\n');
    } else if (aiPlan['requirements'] is String) {
      reqsText = aiPlan['requirements'];
    } else {
      reqsText = '• Functional & Non-functional requirements defined by project context.';
    }

    String dbText = aiPlan['databaseDesign'] is String
        ? aiPlan['databaseDesign']
        : '• Relational database schema configured.';

    String personasText = '';
    if (aiPlan['userPersonas'] is List) {
      personasText = (aiPlan['userPersonas'] as List)
          .map((u) => '• ${u.toString()}'.trim())
          .join('\n');
    } else if (aiPlan['userPersonas'] is String) {
      personasText = aiPlan['userPersonas'];
    } else {
      personasText = '• Target user personas and interaction flows.';
    }

    String archText = aiPlan['architecture'] is String
        ? aiPlan['architecture']
        : '• High-level system architecture and data pipelines.';

    String secText = aiPlan['security'] is String
        ? aiPlan['security']
        : '• Security and compliance implementation guidelines.';

    return {
      'stack': stackMap,
      'why': whyText,
      'alternatives': altList,
      'specs': {
        'reqs': reqsText,
        'db': dbText,
        'personas': personasText,
        'arch': archText,
        'sec': secText,
      },
    };
  }

  Future<void> _showGenerateCodeDialog(int taskIndex, String taskTitle) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
      ),
    );

    String codeSnippet = "";
    String filePath = "";
    try {
      final response = await http.post(
        Uri.parse(
          'http://localhost:5001/api/projects/${widget.projectId}/generate-task-code',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'taskTitle': taskTitle,
          'taskDesc': 'Implementation code generation',
          'techStack': _project?['projectType'] ?? 'Full-Stack Application',
        }),
      );

      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        codeSnippet = data['code'] ?? '// Code generated successfully.';
        filePath = data['filePath'] ?? '';
      } else {
        codeSnippet = '// Failed to generate code from backend service.';
      }
    } catch (e) {
      Navigator.pop(context);
      codeSnippet = '// Network error: $e';
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 650,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Generated Code: Task ${taskIndex + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (filePath.isNotEmpty)
                          Text(
                            filePath,
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              Text(
                taskTitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Builder(
                    builder: (context) {
                      final ScrollController verticalController =
                          ScrollController();
                      final ScrollController horizontalController =
                          ScrollController();
                      return Scrollbar(
                        controller: verticalController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: verticalController,
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            controller: horizontalController,
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              codeSnippet,
                              style: const TextStyle(
                                color: Color(0xFF4ADE80),
                                fontFamily: 'monospace',
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF3B82F6)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: codeSnippet));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Code copied to clipboard successfully! 📋',
                          ),
                          backgroundColor: Color(0xFF2563EB),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.copy,
                      size: 16,
                      color: Color(0xFF3B82F6),
                    ),
                    label: const Text(
                      'Copy Code',
                      style: TextStyle(color: Color(0xFF3B82F6)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 768;
    String userEmail = _project != null
        ? (_project!['userEmail'] ?? 'tina@gmail.com')
        : 'tina@gmail.com';
    String userName = userEmail.split('@')[0];
    if (userName.isNotEmpty) {
      userName = userName[0].toUpperCase() + userName.substring(1);
    }

    String domain = _project != null ? (_project!['domain'] ?? '') : '';
    String projectType = _project != null
        ? (_project!['projectType'] ?? 'Full-Stack Application')
        : 'Full-Stack Application';

    Map<String, dynamic> techData = _getDynamicTechStack();
    Map<String, String> recommendedStack = Map<String, String>.from(
      techData['stack'],
    );
    List<dynamic> alternativeOptions = List<dynamic>.from(
      techData['alternatives'],
    );
    String whyThisStackText = techData['why'];
    Map<String, String> dynamicSpecs = Map<String, String>.from(
      techData['specs'],
    );

    int completedCount = _taskCompleted.where((element) => element).length;
    double progressPercent = completedCount / _taskTitles.length;

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
        child: ListView(
          padding: EdgeInsets.zero,
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
                          userEmail,
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
                    builder: (context) => DashboardScreen(userEmail: userEmail),
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
                    builder: (context) => ProjectsScreen(userEmail: userEmail),
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
                        AiAssistantScreen(userEmail: userEmail),
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
                        CreateProjectScreen(userEmail: userEmail),
                  ),
                );
              },
            ),
            const Divider(color: Colors.white24, height: 32),
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
                    builder: (context) => ProfileScreen(userEmail: userEmail),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );

    Widget mainProjectContent = _isLoading
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _fetchProjectDetails,
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        : _project == null
        ? const Center(
            child: Text(
              'Project not found',
              style: TextStyle(color: Colors.white70),
            ),
          )
        : RefreshIndicator(
            onRefresh: _fetchProjectDetails,
            color: const Color(0xFF3B82F6),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _exportPdf,
                        icon: const Icon(
                          Icons.picture_as_pdf,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Export PDF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _exportDocx,
                        icon: const Icon(
                          Icons.description,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Export DOCX',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      bool isWide = constraints.maxWidth > 850;
                      Widget mainBanner = Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'PROJECT WORKSPACE',
                                  style: TextStyle(
                                    color: Color(0xFF3B82F6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.green.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    _project!['aiStatus'] ?? 'Completed',
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _project!['projectName'] ?? 'Untitled Project',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _project!['projectIdea'] ??
                                  'No description provided.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.layers_outlined,
                                      color: Colors.white60,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Type: $projectType',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                if (domain.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.domain,
                                        color: Colors.white60,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Domain: $domain',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );

                      Widget whyStack = Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.lightbulb_outline,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Why This Stack?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              whyThisStackText,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: mainBanner),
                            const SizedBox(width: 20),
                            Expanded(flex: 2, child: whyStack),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            mainBanner,
                            const SizedBox(height: 20),
                            whyStack,
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: const Text(
                                '⚡ AI Recommended Technology Stack',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF3B82F6)
                                      .withOpacity(0.5),
                                ),
                              ),
                              child: const Text(
                                'AI Selected',
                                style: TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: recommendedStack.entries.map((entry) {
                            return _buildTechChip(entry.key, entry.value);
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🔄 Alternative Technology Options',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Other architectural approaches considered by AI for this domain:',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ...alternativeOptions.asMap().entries.map((entry) {
                          int idx = entry.key;
                          var alt = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFF3B82F6),
                                  child: Text(
                                    '${idx + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alt['name'] ?? 'Alternative Option',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        alt['desc'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Detailed Specification Modules',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCustomAccordionModule(
                    index: 0,
                    title: 'Project Overview',
                    subtitle: 'AI-generated comprehensive understanding of your project.',
                    icon: Icons.description_outlined,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (_project!['aiPlan'] != null &&
                                  _project!['aiPlan']['overview'] != null)
                              ? _project!['aiPlan']['overview']
                              : (_project!['projectIdea'] ??
                                    'Comprehensive system overview and operational workflow details.'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'This platform utilizes domain-specific intelligence to synthesize requirements, automate task decomposition, and produce production-ready code modules.',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCustomAccordionModule(
                    index: 1,
                    title: 'Requirements & Features',
                    subtitle: 'In-depth functional requirements, modules, and constraints.',
                    icon: Icons.check_circle_outline,
                    content: Text(
                      dynamicSpecs['reqs'] ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCustomAccordionModule(
                    index: 2,
                    title: 'Database & API Design',
                    subtitle: 'Database schemas, entity relationships, and RESTful endpoints.',
                    icon: Icons.storage_outlined,
                    content: Builder(
                      builder: (context) {
                        var dbDesign =
                            (_project != null && _project!['aiPlan'] != null)
                            ? _project!['aiPlan']['databaseDesign']
                            : null;

                        if (dbDesign is List && dbDesign.isNotEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: dbDesign.map<Widget>((tableMap) {
                              String tableName =
                                  tableMap['tableName'] ?? 'Table';
                              List columns = tableMap['columns'] is List
                                  ? tableMap['columns']
                                  : [];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.table_chart,
                                          color: Color(0xFF3B82F6),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          tableName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowHeight: 32,
                                        dataRowMinHeight: 30,
                                        dataRowMaxHeight: 36,
                                        columnSpacing: 20,
                                        columns: const [
                                          DataColumn(
                                            label: Text(
                                              'Column Name',
                                              style: TextStyle(
                                                color: Color(0xFF3B82F6),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Data Type',
                                              style: TextStyle(
                                                color: Color(0xFF3B82F6),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Constraint',
                                              style: TextStyle(
                                                color: Color(0xFF3B82F6),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                        rows: columns.map<DataRow>((col) {
                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  col['name']?.toString() ?? '',
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  col['type']?.toString() ?? '',
                                                  style: const TextStyle(
                                                    color: Colors.greenAccent,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  col['constraint']
                                                          ?.toString() ??
                                                      '',
                                                  style: const TextStyle(
                                                    color: Colors.amberAccent,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        } else {
                          return Text(
                            dynamicSpecs['db'] ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCustomAccordionModule(
                    index: 3,
                    title: 'User Stories & Personas',
                    subtitle: 'Target user expectations, pain points, and behavioral flows.',
                    icon: Icons.people_outline,
                    content: Builder(
                      builder: (context) {
                        var rawPersonas =
                            (_project != null && _project!['aiPlan'] != null)
                            ? (_project!['aiPlan']['userPersonas'] ??
                                  _project!['aiPlan']['userStories'])
                            : null;

                        if (rawPersonas is List && rawPersonas.isNotEmpty) {
                          var validPersonas = rawPersonas
                              .where(
                                (p) =>
                                    p != null && p.toString().trim().isNotEmpty,
                              )
                              .toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: validPersonas
                                .map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12.0,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 4.0),
                                          child: Icon(
                                            Icons.arrow_right,
                                            color: Color(0xFF3B82F6),
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            p.toString(),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        } else {
                          return Text(
                            dynamicSpecs['personas'] ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCustomAccordionModule(
                    index: 4,
                    title: 'Technical Architecture & Data Flow',
                    subtitle: 'Microservices layout, caching layers, and communication protocols.',
                    icon: Icons.architecture,
                    content: Text(
                      dynamicSpecs['arch'] ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCustomAccordionModule(
                    index: 5,
                    title: 'Security & Compliance',
                    subtitle: 'Encryption standards, access control policies, and data retention.',
                    icon: Icons.security,
                    content: Text(
                      dynamicSpecs['sec'] ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCustomAccordionModule(
                    index: 6,
                    title: 'Development Tasks & Implementation Plan',
                    subtitle:
                        '$completedCount of ${_taskTitles.length} tasks completed',
                    icon: Icons.task_alt,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progressPercent,
                                  backgroundColor: Colors.white12,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF3B82F6),
                                      ),
                                  minHeight: 8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _isSaving ? null : _saveTasksProgress,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.save,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                              label: Text(
                                _isSaving ? 'Saving...' : 'Save Progress',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _taskTitles.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _taskCompleted[index]
                                      ? Colors.green.withOpacity(0.4)
                                      : Colors.white12,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _taskCompleted[index],
                                    activeColor: const Color(0xFF3B82F6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _taskCompleted[index] = val ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Task ${index + 1}: ${_taskTitles[index]}',
                                          style: TextStyle(
                                            color: _taskCompleted[index]
                                                ? Colors.white38
                                                : Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            decoration: _taskCompleted[index]
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Status: Ready for code generation',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFF3B82F6),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      _showGenerateCodeDialog(
                                        index,
                                        _taskTitles[index],
                                      );
                                    },
                                    child: const Text(
                                      'Generate Code',
                                      style: TextStyle(
                                        color: Color(0xFF3B82F6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
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
          backgroundColor: const Color(0xFF111827),
          elevation: 0,
          automaticallyImplyLeading: false,
          title: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
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
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  tooltip: 'Back to Projects',
                  onPressed: () => Navigator.pop(context, true),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.rocket_launch,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'Project Workspace',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  tooltip: 'Delete Project',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: _deleteProject,
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.purpleAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Colors.purpleAccent.withOpacity(0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () {
                    String projName = _project?['projectName'] ?? 'Project';
                    String projDomain = _project?['domain'] ?? '';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AiAssistantScreen(
                          userEmail: userEmail,
                          initialProjectContext:
                              "Hi! I need help regarding my project '$projName' (Domain: $projDomain).",
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.smart_toy_outlined, size: 14),
                  label: const Text(
                    'Ask AI',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
      body: Row(
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
          Expanded(child: mainProjectContent),
        ],
      ),
    );
  }

  Widget _buildTechChip(String category, String details) {
    return Container(
      width: 290,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: const TextStyle(
              color: Color(0xFF3B82F6),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            details,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomAccordionModule({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget content,
  }) {
    bool isExpanded = _expandedModules[index] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _expandedModules[index] = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF3B82F6),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Align(alignment: Alignment.topLeft, child: content),
            ),
        ],
      ),
    );
  }
}
