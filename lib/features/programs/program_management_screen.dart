import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'program_editor_screen.dart';

class ProgramManagementScreen extends StatefulWidget {
  final Map<String, Map<String, List<String>>> customPrograms;
  final Function(Map<String, Map<String, List<String>>>) onProgramsUpdated;

  const ProgramManagementScreen({
    super.key,
    required this.customPrograms,
    required this.onProgramsUpdated,
  });

  @override
  State<ProgramManagementScreen> createState() =>
      _ProgramManagementScreenState();
}

class _ProgramManagementScreenState extends State<ProgramManagementScreen> {
  late Map<String, Map<String, List<String>>> _customPrograms;

  @override
  void initState() {
    super.initState();
    _customPrograms = Map.from(widget.customPrograms);
  }

  static const String _programsSchemaTemplate = '''
{
  "Program Name": {
    "Day 1: Upper A": [
      "Bench Press",
      "Incline DB Press",
      "Pull-ups"
    ],
    "Day 2: Lower A": [
      "Squat",
      "RDL"
    ]
  }
}
''';

  String _prettyJson(Object? value) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(value);
  }

  Map<String, Map<String, List<String>>> _parseProgramsJson(dynamic decoded) {
    if (decoded is! Map) {
      throw const FormatException(
        "Top-level JSON must be an object: { \"Program Name\": { ... } }",
      );
    }

    final result = <String, Map<String, List<String>>>{};

    for (final entry in decoded.entries) {
      final programName = entry.key;
      final programValue = entry.value;

      if (programName is! String || programName.trim().isEmpty) {
        throw const FormatException("Program names must be non-empty strings.");
      }
      if (programValue is! Map) {
        throw FormatException(
          "Program '$programName' must be an object mapping day names to exercise arrays.",
        );
      }

      final days = <String, List<String>>{};
      for (final dayEntry in programValue.entries) {
        final dayName = dayEntry.key;
        final dayValue = dayEntry.value;

        if (dayName is! String || dayName.trim().isEmpty) {
          throw FormatException(
            "Program '$programName' contains a day name that isn't a non-empty string.",
          );
        }
        if (dayValue is! List) {
          throw FormatException(
            "Program '$programName' day '$dayName' must be an array of exercise names.",
          );
        }

        final exercises = <String>[];
        for (final item in dayValue) {
          if (item is! String) {
            throw FormatException(
              "Program '$programName' day '$dayName' contains a non-string exercise name.",
            );
          }
          final trimmed = item.trim();
          if (trimmed.isNotEmpty) {
            exercises.add(trimmed);
          }
        }

        if (exercises.isNotEmpty) {
          days[dayName.trim()] = exercises;
        }
      }

      if (days.isNotEmpty) {
        result[programName.trim()] = days;
      }
    }

    if (result.isEmpty) {
      throw const FormatException(
        "No valid programs found. Check names, days, and exercise arrays.",
      );
    }

    return result;
  }

  Future<void> _importProgramsFromJsonText(
    String jsonText, {
    required bool replaceExisting,
  }) async {
    try {
      final decoded = jsonDecode(jsonText);
      final imported = _parseProgramsJson(decoded);

      setState(() {
        if (replaceExisting) {
          _customPrograms = imported;
        } else {
          _customPrograms = {..._customPrograms, ...imported};
        }
      });

      widget.onProgramsUpdated(_customPrograms);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            replaceExisting
                ? "Imported programs (replaced existing)."
                : "Imported programs (merged).",
          ),
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid schema: ${e.message}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to import JSON: $e")),
      );
    }
  }

  Future<void> _showProgramsImportDialog({String? initialJson}) async {
    final controller = TextEditingController(text: initialJson ?? '');
    bool replaceExisting = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text(
                "Import Programs JSON",
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Paste JSON matching the schema below. You can merge with existing programs or replace them.",
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      minLines: 6,
                      maxLines: 12,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: _programsSchemaTemplate,
                        hintStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade700),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade700),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: replaceExisting,
                      onChanged: (v) => setLocalState(() {
                        replaceExisting = v ?? false;
                      }),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        "Replace existing custom programs",
                        style: TextStyle(color: Colors.white),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(ctx);
                    await _importProgramsFromJsonText(
                      text,
                      replaceExisting: replaceExisting,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.upload_file),
                  label: const Text("Import"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showProgramsSchemaDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            "Programs JSON Schema (template)",
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Copy/paste this as a starting point.",
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: SelectableText(
                    _programsSchemaTemplate.trim(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(
                  ClipboardData(text: _programsSchemaTemplate.trim()),
                );
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text("Schema copied to clipboard.")),
                );
              },
              child: const Text("Copy"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importProgramsFromFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;

      final file = res.files.first;
      String text = '';
      if (file.bytes != null) {
        text = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        text = await File(file.path!).readAsString();
      }

      if (!mounted) return;
      await _showProgramsImportDialog(initialJson: text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to read file: $e")),
      );
    }
  }

  void _showProgramsImportMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.description, color: Colors.white),
                title: const Text(
                  "View schema template",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showProgramsSchemaDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file, color: Colors.white),
                title: const Text(
                  "Upload JSON file",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _importProgramsFromFile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_paste, color: Colors.white),
                title: const Text(
                  "Paste JSON",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showProgramsImportDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.white),
                title: const Text(
                  "Copy current custom programs as JSON",
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  "Useful for exporting + re-importing later",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                onTap: () async {
                  final jsonText = _prettyJson(_customPrograms);
                  await Clipboard.setData(ClipboardData(text: jsonText));
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Export copied to clipboard.")),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _addProgram() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ProgramEditorScreen(
              programName: '',
              programData: const {},
              onSave: (name, data) {
                setState(() {
                  _customPrograms[name] = data;
                });
                widget.onProgramsUpdated(_customPrograms);
              },
            ),
      ),
    );
  }

  void _editProgram(String programName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ProgramEditorScreen(
              programName: programName,
              programData: Map.from(_customPrograms[programName]!),
              onSave: (name, data) {
                setState(() {
                  if (name != programName) {
                    _customPrograms.remove(programName);
                  }
                  _customPrograms[name] = data;
                });
                widget.onProgramsUpdated(_customPrograms);
              },
            ),
      ),
    );
  }

  void _deleteProgram(String programName) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text(
              "Delete Program?",
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              "Are you sure you want to delete '$programName'?",
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _customPrograms.remove(programName);
                  });
                  widget.onProgramsUpdated(_customPrograms);
                  Navigator.pop(ctx);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Delete"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Programs"),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.import_export),
            tooltip: "Import / Export",
            onPressed: _showProgramsImportMenu,
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      body:
          _customPrograms.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fitness_center,
                      size: 64,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No custom programs yet",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Tap + to create your first program",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _customPrograms.length,
                itemBuilder: (context, index) {
                  final programName = _customPrograms.keys.elementAt(index);
                  final programData = _customPrograms[programName]!;
                  return Card(
                    color: const Color(0xFF1E293B),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _editProgram(programName),
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                programName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade900.withValues(
                                  alpha: 0.3,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.shade700),
                              ),
                              child: Text(
                                "Tap to Edit",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade300,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          "${programData.length} day(s) • ${programData.values.expand((e) => e).length} total exercises",
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteProgram(programName),
                          tooltip: "Delete Program",
                        ),
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProgram,
        backgroundColor: const Color(0xFF3B82F6),
        child: const Icon(Icons.add),
      ),
    );
  }
}

