import 'package:flutter/material.dart';

class ProgramEditorScreen extends StatefulWidget {
  final String programName;
  final Map<String, List<String>> programData;
  final Function(String name, Map<String, List<String>> data) onSave;

  const ProgramEditorScreen({
    super.key,
    required this.programName,
    required this.programData,
    required this.onSave,
  });

  @override
  State<ProgramEditorScreen> createState() => _ProgramEditorScreenState();
}

class _ProgramEditorScreenState extends State<ProgramEditorScreen> {
  late TextEditingController _programNameController;
  late Map<String, List<String>> _programData;
  final Map<String, TextEditingController> _dayNameControllers = {};
  final Map<String, Map<int, TextEditingController>> _exerciseControllers = {};
  final Map<String, Map<int, TextEditingController>> _exerciseTargetControllers =
      {};

  @override
  void initState() {
    super.initState();
    _programNameController = TextEditingController(text: widget.programName);
    _programData = Map.from(widget.programData);
    if (_programData.isEmpty) {
      _programData['Day 1'] = [''];
    }
    _initializeControllers();
  }

  void _initializeControllers() {
    _programData.forEach((dayName, exercises) {
      _dayNameControllers[dayName] = TextEditingController(text: dayName);
      _exerciseControllers[dayName] = {};
      _exerciseTargetControllers[dayName] = {};
      for (int i = 0; i < exercises.length; i++) {
        _exerciseControllers[dayName]![i] = TextEditingController(
          text: exercises[i],
        );
        _exerciseTargetControllers[dayName]![i] = TextEditingController();
      }
    });
  }

  void _addDay() {
    final dayName = "Day ${_programData.length + 1}";
    setState(() {
      _programData[dayName] = [''];
      _dayNameControllers[dayName] = TextEditingController(text: dayName);
      _exerciseControllers[dayName] = {0: TextEditingController(text: '')};
      _exerciseTargetControllers[dayName] = {
        0: TextEditingController(text: ''),
      };
    });
  }

  void _deleteDay(String dayName) {
    setState(() {
      _programData.remove(dayName);
      _dayNameControllers[dayName]?.dispose();
      _exerciseControllers[dayName]?.values.forEach((c) => c.dispose());
      _exerciseTargetControllers[dayName]?.values.forEach((c) => c.dispose());
      _dayNameControllers.remove(dayName);
      _exerciseControllers.remove(dayName);
      _exerciseTargetControllers.remove(dayName);
    });
  }

  void _addExercise(String dayName) {
    setState(() {
      final currentExercises = _programData[dayName] ?? [];
      final newIndex = currentExercises.length;
      _programData[dayName] = [...currentExercises, ''];
      _exerciseControllers.putIfAbsent(dayName, () => {});
      _exerciseControllers[dayName]![newIndex] = TextEditingController();

      _exerciseTargetControllers.putIfAbsent(dayName, () => {});
      _exerciseTargetControllers[dayName]![newIndex] = TextEditingController();
    });
  }

  void _deleteExercise(String dayName, int index) {
    setState(() {
      _exerciseControllers[dayName]?.values.forEach((c) => c.dispose());
      _exerciseTargetControllers[dayName]?.values.forEach((c) => c.dispose());

      _programData[dayName]!.removeAt(index);

      final exercises = _programData[dayName]!;
      final newControllers = <int, TextEditingController>{};
      final newTargetControllers = <int, TextEditingController>{};
      for (int i = 0; i < exercises.length; i++) {
        newControllers[i] = TextEditingController(text: exercises[i]);
        newTargetControllers[i] = TextEditingController();
      }
      _exerciseControllers[dayName] = newControllers;
      _exerciseTargetControllers[dayName] = newTargetControllers;
    });
  }

  void _saveProgram() {
    final programName = _programNameController.text.trim();
    if (programName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a program name")),
      );
      return;
    }

    if (_programData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one day")),
      );
      return;
    }

    final Map<String, List<String>> finalData = {};
    _programData.forEach((oldDayName, exercises) {
      final dayController = _dayNameControllers[oldDayName];
      final dayName = dayController?.text.trim() ?? oldDayName;
      if (dayName.isEmpty) return;

      final dayExercises = <String>[];
      final exerciseMap = _exerciseControllers[oldDayName] ?? {};
      for (int i = 0; i < exercises.length; i++) {
        final controller = exerciseMap[i];
        if (controller != null) {
          final exercise = controller.text.trim();
          if (exercise.isNotEmpty) {
            dayExercises.add(exercise);
          }
        }
      }

      if (dayExercises.isNotEmpty) {
        finalData[dayName] = dayExercises;
      }
    });

    if (finalData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one exercise")),
      );
      return;
    }

    widget.onSave(programName, finalData);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _programNameController.dispose();
    for (final c in _dayNameControllers.values) {
      c.dispose();
    }
    for (final map in _exerciseControllers.values) {
      for (final c in map.values) {
        c.dispose();
      }
    }
    for (final map in _exerciseTargetControllers.values) {
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
        title: Text(widget.programName.isEmpty ? "New Program" : "Edit Program"),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveProgram),
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _programNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Program Name",
              labelStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade700),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade700),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF3B82F6)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ..._programData.keys.map(_buildDayCard),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _addDay,
            icon: const Icon(Icons.add),
            label: const Text("Add Day"),
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

  Widget _buildDayCard(String dayName) {
    final dayController = _dayNameControllers[dayName]!;
    final exercises = _programData[dayName]!;
    final exerciseMap = _exerciseControllers[dayName] ?? {};
    final targetMap = _exerciseTargetControllers[dayName] ?? {};

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
                  child: TextField(
                    controller: dayController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: "Day Name",
                      labelStyle: TextStyle(color: Colors.grey.shade400),
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
                ),
                if (_programData.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteDay(dayName),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...exercises.asMap().entries.map((entry) {
              final index = entry.key;
              if (exerciseMap[index] == null) {
                exerciseMap[index] = TextEditingController(
                  text: exercises[index],
                );
              }
              final controller = exerciseMap[index]!;

              if (targetMap[index] == null) {
                targetMap[index] = TextEditingController();
              }
              final targetController = targetMap[index]!;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          TextField(
                            controller: controller,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Exercise ${index + 1}",
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: targetController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText:
                                  "Target (optional): e.g. 10-12, RPE 8, RIR 2",
                              hintStyle: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteExercise(dayName, index),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => _addExercise(dayName),
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Add Exercise"),
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

