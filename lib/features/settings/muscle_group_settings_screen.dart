import 'package:flutter/material.dart';

class MuscleGroupSettingsScreen extends StatefulWidget {
  final Map<String, List<String>>? customKeywords;
  final Map<String, List<String>> defaultKeywords;
  final Function(Map<String, List<String>>?) onKeywordsUpdated;

  const MuscleGroupSettingsScreen({
    super.key,
    required this.customKeywords,
    required this.defaultKeywords,
    required this.onKeywordsUpdated,
  });

  @override
  State<MuscleGroupSettingsScreen> createState() =>
      _MuscleGroupSettingsScreenState();
}

class _MuscleGroupSettingsScreenState extends State<MuscleGroupSettingsScreen> {
  late Map<String, List<String>> _keywords;
  final Map<String, Map<int, TextEditingController>> _keywordControllers = {};

  @override
  void initState() {
    super.initState();
    if (widget.customKeywords != null) {
      _keywords = widget.customKeywords!.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      );
    } else {
      _keywords = widget.defaultKeywords.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      );
    }
    _initializeControllers();
  }

  void _initializeControllers() {
    _keywords.forEach((muscleGroup, keywords) {
      _keywordControllers[muscleGroup] = {};
      for (int i = 0; i < keywords.length; i++) {
        _keywordControllers[muscleGroup]![i] = TextEditingController(
          text: keywords[i],
        );
      }
    });
  }

  void _addKeyword(String muscleGroup) {
    setState(() {
      if (!_keywords.containsKey(muscleGroup)) {
        _keywords[muscleGroup] = [];
      } else {
        final currentList = _keywords[muscleGroup]!;
        _keywords[muscleGroup] = List<String>.from(currentList);
      }
      final newIndex = _keywords[muscleGroup]!.length;
      _keywords[muscleGroup]!.add('');
      _keywordControllers.putIfAbsent(muscleGroup, () => {});
      _keywordControllers[muscleGroup]![newIndex] = TextEditingController();
    });
  }

  void _removeKeyword(String muscleGroup, int index) {
    setState(() {
      _keywordControllers[muscleGroup]?[index]?.dispose();
      _keywords[muscleGroup]!.removeAt(index);
      final keywords = _keywords[muscleGroup]!;
      final newControllers = <int, TextEditingController>{};
      for (int i = 0; i < keywords.length; i++) {
        newControllers[i] = TextEditingController(text: keywords[i]);
      }
      _keywordControllers[muscleGroup] = newControllers;
    });
  }

  void _addMuscleGroup() {
    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            "Add Muscle Group",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Muscle group name",
              hintStyle: TextStyle(color: Colors.grey.shade500),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade700),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty && !_keywords.containsKey(name)) {
                  setState(() {
                    _keywords[name] = [''];
                    _keywordControllers[name] = {0: TextEditingController()};
                  });
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void _removeMuscleGroup(String muscleGroup) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text(
              "Remove Muscle Group?",
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              "Are you sure you want to remove '$muscleGroup'?",
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
                    _keywordControllers[muscleGroup]?.values.forEach(
                      (c) => c.dispose(),
                    );
                    _keywordControllers.remove(muscleGroup);
                    _keywords.remove(muscleGroup);
                  });
                  Navigator.pop(ctx);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Remove"),
              ),
            ],
          ),
    );
  }

  void _saveKeywords() {
    final Map<String, List<String>> finalKeywords = {};
    _keywords.forEach((muscleGroup, _) {
      final controllers = _keywordControllers[muscleGroup] ?? {};
      final keywords = <String>[];
      for (int i = 0; i < controllers.length; i++) {
        final controller = controllers[i];
        if (controller != null) {
          final keyword = controller.text.trim();
          if (keyword.isNotEmpty) {
            keywords.add(keyword);
          }
        }
      }
      if (keywords.isNotEmpty) {
        finalKeywords[muscleGroup] = keywords;
      }
    });

    bool isDifferent = false;
    if (finalKeywords.length != widget.defaultKeywords.length) {
      isDifferent = true;
    } else {
      for (final entry in finalKeywords.entries) {
        final defaultKeywords = widget.defaultKeywords[entry.key];
        if (defaultKeywords == null ||
            defaultKeywords.length != entry.value.length ||
            !defaultKeywords.every((k) => entry.value.contains(k))) {
          isDifferent = true;
          break;
        }
      }
    }

    widget.onKeywordsUpdated(isDifferent ? finalKeywords : null);
    Navigator.pop(context);
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text(
              "Reset to Defaults?",
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              "This will reset all muscle group keywords to their default values.",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  for (final map in _keywordControllers.values) {
                    for (final c in map.values) {
                      c.dispose();
                    }
                  }
                  setState(() {
                    _keywords = widget.defaultKeywords.map(
                      (key, value) => MapEntry(key, List<String>.from(value)),
                    );
                    _keywordControllers.clear();
                    _initializeControllers();
                  });
                  Navigator.pop(ctx);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text("Reset"),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    for (final map in _keywordControllers.values) {
      for (final c in map.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Muscle Group Keywords"),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Reset to Defaults",
            onPressed: _resetToDefaults,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: "Save",
            onPressed: _saveKeywords,
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade900.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade700),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade300, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Customize keywords to match exercises to muscle groups. "
                    "Exercises containing these keywords will be categorized accordingly.",
                    style: TextStyle(color: Colors.blue.shade300, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._keywords.keys.map(_buildMuscleGroupCard),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _addMuscleGroup,
            icon: const Icon(Icons.add),
            label: const Text("Add Muscle Group"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildMuscleGroupCard(String muscleGroup) {
    final keywords = _keywords[muscleGroup] ?? [];
    final controllers = _keywordControllers[muscleGroup] ?? {};

    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    muscleGroup,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.defaultKeywords.containsKey(muscleGroup))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Default",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                if (!widget.defaultKeywords.containsKey(muscleGroup))
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeMuscleGroup(muscleGroup),
                    tooltip: "Remove Muscle Group",
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...keywords.asMap().entries.map((entry) {
              final index = entry.key;
              if (controllers[index] == null) {
                controllers[index] = TextEditingController(
                  text: keywords[index],
                );
              }
              final controller = controllers[index]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Keyword ${index + 1}",
                          hintStyle: TextStyle(color: Colors.grey.shade500),
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
                            borderSide: const BorderSide(
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeKeyword(muscleGroup, index),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => _addKeyword(muscleGroup),
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Add Keyword"),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

