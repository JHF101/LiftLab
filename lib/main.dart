import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

// --- Constants & Data ---

const Map<String, Map<String, List<String>>> allPrograms = {
  "Upper / Lower (4 Day)": {
    "Day 1: Upper A (Chest Focus)": [
      "Bench Press / DB Bench",
      "Incline DB Press",
      "Chest Fly (Cable/Machine)",
      "Pull-ups / Lat Pulldown",
      "Chest-supported Row",
      "Lateral Raises",
    ],
    "Day 2: Lower A (Quad Focus)": [
      "Hack Squat / Leg Press",
      "Squat / Belt Squat",
      "Leg Extension",
      "RDL / Hip Hinge",
      "Hamstring Curl",
    ],
    "Day 3: Upper B (Back/Shoulder Focus)": [
      "Weighted Pull-ups / Lat Pulldown",
      "Row Variation",
      "Reverse Fly / Rear Delt",
      "Overhead Press / DB Press",
      "Incline Cable Fly",
      "Biceps Curl",
      "Triceps Rope / Dip",
    ],
    "Day 4: Lower B (Hams/Glute Focus)": [
      "RDL",
      "Leg Press / Hack Squat",
      "Glute Bridge / Hip Thrust",
      "Hamstring Curl",
      "Leg Extension",
      "Calf Raises",
    ],
  },
  "Push / Pull / Legs (3-6 Day)": {
    "Push (Chest/Shoulders/Tri)": [
      "Bench Press",
      "Overhead Press",
      "Incline DB Press",
      "Lateral Raises",
      "Tricep Pushdown",
    ],
    "Pull (Back/Bi)": [
      "Deadlift",
      "Pull-ups",
      "Barbell Row",
      "Face Pulls",
      "Hammer Curls",
    ],
    "Legs (Quad/Ham/Calf)": [
      "Squat",
      "RDL",
      "Leg Press",
      "Leg Curl",
      "Standing Calf Raise",
    ],
  },
  "Full Body (3 Day)": {
    "Workout A": [
      "Squat",
      "Bench Press",
      "Barbell Row",
      "Overhead Press",
      "Dips",
    ],
    "Workout B": [
      "Deadlift",
      "Pull-ups",
      "Incline Bench",
      "Lunges",
      "Bicep Curl",
    ],
  },
};

// Epley Formula
int calculate1RM(double? weight, double? reps) {
  if (weight == null || reps == null || weight == 0 || reps == 0) return 0;
  return (weight * (1 + reps / 30)).round();
}

// --- Periodization Engine Data Models ---

class DailyReadinessScore {
  final String date;
  final int score; // 1-5 scale

  DailyReadinessScore({required this.date, required this.score});

  Map<String, dynamic> toJson() => {'date': date, 'score': score};

  factory DailyReadinessScore.fromJson(Map<String, dynamic> json) {
    return DailyReadinessScore(date: json['date'], score: json['score']);
  }
}

class Microcycle {
  final String startDate;
  final String endDate;
  final int weekNumber;

  Microcycle({
    required this.startDate,
    required this.endDate,
    required this.weekNumber,
  });

  Map<String, dynamic> toJson() => {
    'startDate': startDate,
    'endDate': endDate,
    'weekNumber': weekNumber,
  };

  factory Microcycle.fromJson(Map<String, dynamic> json) {
    return Microcycle(
      startDate: json['startDate'],
      endDate: json['endDate'],
      weekNumber: json['weekNumber'],
    );
  }
}

class Mesocycle {
  final String startDate;
  final String endDate;
  final String goal; // "Hypertrophy" or "Strength"
  final List<String> microcycleDates;

  Mesocycle({
    required this.startDate,
    required this.endDate,
    required this.goal,
    required this.microcycleDates,
  });

  Map<String, dynamic> toJson() => {
    'startDate': startDate,
    'endDate': endDate,
    'goal': goal,
    'microcycleDates': microcycleDates,
  };

  factory Mesocycle.fromJson(Map<String, dynamic> json) {
    return Mesocycle(
      startDate: json['startDate'],
      endDate: json['endDate'],
      goal: json['goal'],
      microcycleDates: List<String>.from(json['microcycleDates']),
    );
  }
}

// Muscle Group Mapping - Keywords for better matching
const Map<String, List<String>> muscleGroupKeywords = {
  'Chest': [
    'bench',
    'press',
    'fly',
    'pec',
    'chest',
    'incline',
    'decline',
    'pushup',
  ],
  'Back': [
    'pull',
    'pulldown',
    'row',
    'deadlift',
    'lat',
    'face pull',
    'rear delt',
    'shrug',
    't-bar',
  ],
  'Shoulders': [
    'overhead',
    'ohp',
    'lateral',
    'raise',
    'rear delt',
    'reverse fly',
    'shoulder',
    'delt',
    'arnold',
  ],
  'Quads': [
    'squat',
    'leg press',
    'leg extension',
    'hack squat',
    'belt squat',
    'quad',
    'front squat',
    'goblet',
  ],
  'Hamstrings': [
    'rdl',
    'hamstring',
    'leg curl',
    'hip hinge',
    'stiff leg',
    'good morning',
  ],
  'Glutes': [
    'glute',
    'hip thrust',
    'bridge',
    'rdl', // RDL also hits glutes
  ],
  'Calves': ['calf', 'calves', 'calf raise'],
  'Biceps': ['bicep', 'curl', 'hammer', 'preacher', 'concentration'],
  'Triceps': [
    'tricep',
    'dip',
    'pushdown',
    'tricep extension',
    'close grip',
    'skull crusher',
    'overhead extension',
  ],
};

void main() {
  runApp(const GrowthTrackerApp());
}

class GrowthTrackerApp extends StatelessWidget {
  const GrowthTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lift Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        primaryColor: const Color(0xFF3B82F6), // Blue 500
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF3B82F6),
          secondary: const Color(0xFF8B5CF6),
          surface: const Color(0xFF1E293B), // Slate 800
          error: const Color(0xFFEF4444),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          onError: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        cardColor: const Color(0xFF1E293B), // Slate 800
        dividerColor: const Color(0xFF334155), // Slate 700
      ),
      home: const TrackerHomePage(),
    );
  }
}

class WorkoutEntry {
  final double id;
  final String date;
  final String split;
  final String exercise;
  final int setNumber;
  final double weight;
  final double reps;
  final String rpe;
  final int oneRM;

  WorkoutEntry({
    required this.id,
    required this.date,
    required this.split,
    required this.exercise,
    required this.setNumber,
    required this.weight,
    required this.reps,
    required this.rpe,
    required this.oneRM,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'split': split,
    'exercise': exercise,
    'set': setNumber,
    'weight': weight,
    'reps': reps,
    'rpe': rpe,
    'oneRM': oneRM,
  };

  factory WorkoutEntry.fromJson(Map<String, dynamic> json) {
    return WorkoutEntry(
      id: json['id'] is int ? (json['id'] as int).toDouble() : json['id'],
      date: json['date'],
      split: json['split'],
      exercise: json['exercise'],
      setNumber: json['set'],
      weight: (json['weight'] as num).toDouble(),
      reps: (json['reps'] as num).toDouble(),
      rpe: json['rpe'] ?? "",
      oneRM: json['oneRM'],
    );
  }
}

class CardioEntry {
  final double id;
  final String date;
  final String type; // Running, Cycling, Rowing, etc.
  final int duration; // minutes
  final double? distance; // km (optional)
  final String? intensity; // RPE or heart rate zone (optional)
  final String? notes; // optional notes

  CardioEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.duration,
    this.distance,
    this.intensity,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'type': type,
    'duration': duration,
    'distance': distance,
    'intensity': intensity,
    'notes': notes,
  };

  factory CardioEntry.fromJson(Map<String, dynamic> json) {
    return CardioEntry(
      id: json['id'] is int ? (json['id'] as int).toDouble() : json['id'],
      date: json['date'],
      type: json['type'],
      duration: json['duration'],
      distance:
          json['distance'] != null
              ? (json['distance'] as num).toDouble()
              : null,
      intensity: json['intensity'],
      notes: json['notes'],
    );
  }
}

// --- Periodization Engine Logic ---

class PeriodizationEngine {
  // Get muscle groups for an exercise using keyword matching
  // Accepts optional custom keywords map (for user-defined mappings)
  static List<String> getMuscleGroups(
    String exerciseName, [
    Map<String, List<String>>? customKeywords,
  ]) {
    final groups = <String>[];
    final exerciseLower = exerciseName.toLowerCase();

    // Use custom keywords if provided, otherwise use defaults
    final keywordsMap = customKeywords ?? muscleGroupKeywords;

    // Check each muscle group's keywords
    for (final entry in keywordsMap.entries) {
      for (final keyword in entry.value) {
        if (exerciseLower.contains(keyword.toLowerCase())) {
          if (!groups.contains(entry.key)) {
            groups.add(entry.key);
          }
        }
      }
    }

    // Special handling for compound movements that hit multiple groups
    // If we found multiple groups, that's fine - compound exercises do hit multiple
    // If we found none, return 'Other'
    return groups.isEmpty ? ['Other'] : groups;
  }

  // Calculate volume load for a week
  static double calculateWeeklyVolumeLoad(
    List<WorkoutEntry> entries,
    String weekStartDate,
  ) {
    final weekStart = DateTime.parse(weekStartDate);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekEntries =
        entries.where((e) {
          final entryDate = DateTime.parse(e.date);
          return entryDate.isAfter(
                weekStart.subtract(const Duration(days: 1)),
              ) &&
              entryDate.isBefore(weekEnd);
        }).toList();

    return weekEntries.fold<double>(0, (sum, e) => sum + (e.weight * e.reps));
  }

  // Calculate average intensity (RPE) for a week
  static double calculateWeeklyAverageRPE(
    List<WorkoutEntry> entries,
    String weekStartDate,
  ) {
    final weekStart = DateTime.parse(weekStartDate);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekEntries =
        entries.where((e) {
          final entryDate = DateTime.parse(e.date);
          return entryDate.isAfter(
                weekStart.subtract(const Duration(days: 1)),
              ) &&
              entryDate.isBefore(weekEnd);
        }).toList();

    final rpeValues =
        weekEntries
            .map((e) => double.tryParse(e.rpe) ?? 0)
            .where((r) => r > 0)
            .toList();

    if (rpeValues.isEmpty) return 0;
    return rpeValues.reduce((a, b) => a + b) / rpeValues.length;
  }

  // Calculate average intensity as % of e1RM
  static double calculateWeeklyAverageIntensity(
    List<WorkoutEntry> entries,
    String weekStartDate,
  ) {
    final weekStart = DateTime.parse(weekStartDate);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekEntries =
        entries.where((e) {
          final entryDate = DateTime.parse(e.date);
          return entryDate.isAfter(
                weekStart.subtract(const Duration(days: 1)),
              ) &&
              entryDate.isBefore(weekEnd);
        }).toList();

    if (weekEntries.isEmpty) return 0;

    final intensities = <double>[];
    for (final entry in weekEntries) {
      if (entry.oneRM > 0 && entry.weight > 0) {
        intensities.add((entry.weight / entry.oneRM) * 100);
      }
    }

    if (intensities.isEmpty) return 0;
    return intensities.reduce((a, b) => a + b) / intensities.length;
  }

  // Get weekly sets per muscle group
  static Map<String, int> getWeeklySetsPerMuscleGroup(
    List<WorkoutEntry> entries,
    String weekStartDate, [
    Map<String, List<String>>? customKeywords,
  ]) {
    final weekStart = DateTime.parse(weekStartDate);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekEntries =
        entries.where((e) {
          final entryDate = DateTime.parse(e.date);
          return entryDate.isAfter(
                weekStart.subtract(const Duration(days: 1)),
              ) &&
              entryDate.isBefore(weekEnd);
        }).toList();

    final muscleGroupSets = <String, int>{};
    for (final entry in weekEntries) {
      final groups = getMuscleGroups(entry.exercise, customKeywords);
      for (final group in groups) {
        muscleGroupSets[group] = (muscleGroupSets[group] ?? 0) + 1;
      }
    }
    return muscleGroupSets;
  }

  // Get exercises that contributed to a specific muscle group for a week
  static Map<String, int> getExercisesForMuscleGroup(
    List<WorkoutEntry> entries,
    String muscleGroup,
    String weekStartDate, [
    Map<String, List<String>>? customKeywords,
  ]) {
    final weekStart = DateTime.parse(weekStartDate);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekEntries =
        entries.where((e) {
          final entryDate = DateTime.parse(e.date);
          return entryDate.isAfter(
                weekStart.subtract(const Duration(days: 1)),
              ) &&
              entryDate.isBefore(weekEnd);
        }).toList();

    final exerciseCounts = <String, int>{};
    for (final entry in weekEntries) {
      final groups = getMuscleGroups(entry.exercise, customKeywords);
      if (groups.contains(muscleGroup)) {
        exerciseCounts[entry.exercise] =
            (exerciseCounts[entry.exercise] ?? 0) + 1;
      }
    }
    return exerciseCounts;
  }

  // Detect plateau
  static bool detectPlateau(List<WorkoutEntry> entries, String exercise) {
    final exerciseEntries =
        entries.where((e) => e.exercise == exercise).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    if (exerciseEntries.length < 14) return false; // Need at least 2 weeks

    // Group by week
    final weeks = <String, List<WorkoutEntry>>{};
    for (final entry in exerciseEntries) {
      final weekStart = _getWeekStart(entry.date);
      if (!weeks.containsKey(weekStart)) {
        weeks[weekStart] = [];
      }
      weeks[weekStart]!.add(entry);
    }

    final weekList = weeks.keys.toList()..sort();
    if (weekList.length < 2) return false;

    // Check last 2 weeks
    final lastWeek = weekList[weekList.length - 1];
    final secondLastWeek = weekList[weekList.length - 2];

    final lastWeekMax1RM = weeks[lastWeek]!
        .map((e) => e.oneRM)
        .reduce((a, b) => a > b ? a : b);
    final secondLastWeekMax1RM = weeks[secondLastWeek]!
        .map((e) => e.oneRM)
        .reduce((a, b) => a > b ? a : b);

    // Check if e1RM didn't increase
    final noProgress = lastWeekMax1RM <= secondLastWeekMax1RM;

    // Check if high RPE (9-10) but no progress
    final lastWeekRPEs =
        weeks[lastWeek]!
            .map((e) => double.tryParse(e.rpe) ?? 0)
            .where((r) => r > 0)
            .toList();
    final avgRPE =
        lastWeekRPEs.isEmpty
            ? 0
            : lastWeekRPEs.reduce((a, b) => a + b) / lastWeekRPEs.length;

    final highRPE = avgRPE >= 9;

    return noProgress && highRPE;
  }

  // Estimate MRV for a muscle group
  static int? estimateMRV(
    List<WorkoutEntry> entries,
    String muscleGroup,
    String weekStartDate, [
    Map<String, List<String>>? customKeywords,
  ]) {
    final weekStart = DateTime.parse(weekStartDate);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekEntries =
        entries.where((e) {
          final entryDate = DateTime.parse(e.date);
          if (!entryDate.isAfter(weekStart.subtract(const Duration(days: 1))) ||
              !entryDate.isBefore(weekEnd)) {
            return false;
          }
          final groups = getMuscleGroups(e.exercise, customKeywords);
          return groups.contains(muscleGroup);
        }).toList();

    final sets = weekEntries.length;
    final rpeValues =
        weekEntries
            .map((e) => double.tryParse(e.rpe) ?? 0)
            .where((r) => r > 0)
            .toList();

    if (rpeValues.isEmpty) return null;

    final avgRPE = rpeValues.reduce((a, b) => a + b) / rpeValues.length;
    final maxRPE = rpeValues.reduce((a, b) => a > b ? a : b);

    // If user failed to complete target reps (high RPE) for 2 weeks, mark as MRV
    if (avgRPE >= 9 && maxRPE >= 9.5) {
      return sets;
    }

    return null;
  }

  // Helper: Get week start (Monday)
  static String _getWeekStart(String dateStr) {
    final date = DateTime.parse(dateStr);
    final weekday = date.weekday;
    final monday = date.subtract(Duration(days: weekday - 1));
    return DateFormat('yyyy-MM-dd').format(monday);
  }

  // Get all unique weeks from entries
  static List<String> getUniqueWeeks(List<WorkoutEntry> entries) {
    final weeks = <String>{};
    for (final entry in entries) {
      weeks.add(_getWeekStart(entry.date));
    }
    return weeks.toList()..sort();
  }

  // Calculate SRA (Stress, Recovery, Adaptation) curve
  // Returns a map of date -> adaptation score (0-100, where 50 is baseline)
  static Map<String, double> calculateSRACurve(
    List<WorkoutEntry> entries,
    List<DailyReadinessScore> readinessScores,
  ) {
    if (entries.isEmpty) return {};

    // Sort entries by date
    final sortedEntries = List<WorkoutEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    final sraMap = <String, double>{};
    double currentAdaptation = 50.0; // Baseline = 50

    // Get first and last dates
    final firstDate = DateTime.parse(sortedEntries.first.date);
    final lastDate = DateTime.parse(sortedEntries.last.date);
    final daysDiff = lastDate.difference(firstDate).inDays;

    // Process each day
    for (int i = 0; i <= daysDiff; i++) {
      final currentDate = firstDate.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);

      // Find entries for this date
      final dayEntries = sortedEntries.where((e) => e.date == dateStr).toList();

      // Get readiness score for this date
      final readiness =
          readinessScores
              .firstWhere(
                (r) => r.date == dateStr,
                orElse: () => DailyReadinessScore(date: dateStr, score: 3),
              )
              .score;

      if (dayEntries.isNotEmpty) {
        // Calculate stress from training
        double totalStress = 0;
        for (final entry in dayEntries) {
          final rpe = double.tryParse(entry.rpe) ?? 5;
          final volume = entry.weight * entry.reps;
          // Stress = volume * RPE factor
          // Higher RPE = more stress
          final stressFactor = (rpe / 10) * 2; // Scale to 0-2
          totalStress += volume * stressFactor;
        }

        // Normalize stress (divide by typical volume to get 0-1 range)
        final normalizedStress = (totalStress / 10000).clamp(0.0, 2.0);

        // Apply stress (immediate drop in adaptation)
        currentAdaptation -= normalizedStress * 15; // Stress reduces adaptation
        currentAdaptation = currentAdaptation.clamp(0.0, 100.0);
      } else {
        // Recovery day - adaptation increases
        // Recovery rate depends on readiness score (1-5)
        // Higher readiness = faster recovery
        final recoveryRate = (readiness / 5) * 2; // 0.4 to 2.0
        currentAdaptation += recoveryRate;

        // Cap at supercompensation (above baseline)
        if (currentAdaptation > 65) {
          currentAdaptation = 65; // Max supercompensation
        }
      }

      // Decay if too high (return to baseline if no training)
      if (currentAdaptation > 50 && dayEntries.isEmpty) {
        currentAdaptation -= 0.5; // Slow decay
      }

      sraMap[dateStr] = currentAdaptation;
    }

    return sraMap;
  }
}

class TrackerHomePage extends StatefulWidget {
  const TrackerHomePage({super.key});

  @override
  State<TrackerHomePage> createState() => _TrackerHomePageState();
}

class _TrackerHomePageState extends State<TrackerHomePage> {
  // --- State ---
  int _activeTabIndex = 0;
  List<WorkoutEntry> _history = [];
  List<CardioEntry> _cardioHistory = [];
  List<DailyReadinessScore> _readinessScores = [];

  // Program State
  Map<String, Map<String, List<String>>> _customPrograms = {};
  String _selectedProgramName = allPrograms.keys.first;
  String _selectedDay = allPrograms[allPrograms.keys.first]!.keys.first;
  // Map of "Exercise Name" -> List of Sets (Map of values)
  Map<String, List<Map<String, String>>> _currentLog = {};

  // Custom Muscle Group Keywords
  Map<String, List<String>>? _customMuscleGroupKeywords;

  // Progress State
  String _selectedExercise = "Bench Press / DB Bench";

  // Get all programs (default + custom)
  Map<String, Map<String, List<String>>> get _allPrograms {
    return {...allPrograms, ..._customPrograms};
  }

  // Get effective muscle group keywords (custom or default)
  Map<String, List<String>> get _effectiveMuscleGroupKeywords {
    return _customMuscleGroupKeywords ?? muscleGroupKeywords;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- Persistence ---

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load History (Existing logic)
    final String? savedHistory = prefs.getString('growth_tracker_data');
    if (savedHistory != null) {
      try {
        final List<dynamic> decoded = jsonDecode(savedHistory);
        setState(() {
          _history = decoded.map((e) => WorkoutEntry.fromJson(e)).toList();
        });
      } catch (e) {
        debugPrint("Failed to load history: $e");
      }
    }

    // 2. Load Custom Programs
    final String? savedCustomPrograms = prefs.getString('custom_programs');
    if (savedCustomPrograms != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(savedCustomPrograms);
        setState(() {
          _customPrograms = decoded.map(
            (key, value) => MapEntry(
              key,
              (value as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, List<String>.from(v as List)),
              ),
            ),
          );
        });
      } catch (e) {
        debugPrint("Failed to load custom programs: $e");
      }
    }

    // 3. Load Selected Program
    final String? savedProgram = prefs.getString('selected_program');
    final allProgramsMap = {...allPrograms, ..._customPrograms};
    if (savedProgram != null && allProgramsMap.containsKey(savedProgram)) {
      setState(() {
        _selectedProgramName = savedProgram;
        _selectedDay = allProgramsMap[savedProgram]!.keys.first;
      });
    }

    // 4. Load Readiness Scores
    final String? savedReadiness = prefs.getString('readiness_scores');
    if (savedReadiness != null) {
      try {
        final List<dynamic> decoded = jsonDecode(savedReadiness);
        setState(() {
          _readinessScores =
              decoded.map((e) => DailyReadinessScore.fromJson(e)).toList();
        });
      } catch (e) {
        debugPrint("Failed to load readiness scores: $e");
      }
    }

    // 5. Load Cardio History
    final String? savedCardio = prefs.getString('cardio_history');
    if (savedCardio != null) {
      try {
        final List<dynamic> decoded = jsonDecode(savedCardio);
        setState(() {
          _cardioHistory = decoded.map((e) => CardioEntry.fromJson(e)).toList();
        });
      } catch (e) {
        debugPrint("Failed to load cardio history: $e");
      }
    }

    // 6. Load Custom Muscle Group Keywords
    final String? savedKeywords = prefs.getString(
      'custom_muscle_group_keywords',
    );
    if (savedKeywords != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(savedKeywords);
        setState(() {
          _customMuscleGroupKeywords = decoded.map(
            (key, value) => MapEntry(key, List<String>.from(value as List)),
          );
        });
      } catch (e) {
        debugPrint("Failed to load custom muscle group keywords: $e");
      }
    }
  }

  Future<void> _saveProgramSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_program', _selectedProgramName);
  }

  Future<void> _saveCustomPrograms() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_customPrograms);
    await prefs.setString('custom_programs', encoded);
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_history.map((e) => e.toJson()).toList());
    await prefs.setString('growth_tracker_data', encoded);
  }

  Future<void> _saveReadinessScores() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      _readinessScores.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('readiness_scores', encoded);
  }

  Future<void> _saveCardioHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      _cardioHistory.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('cardio_history', encoded);
  }

  Future<void> _saveCustomMuscleGroupKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    if (_customMuscleGroupKeywords != null) {
      final String encoded = jsonEncode(
        _customMuscleGroupKeywords!.map((key, value) => MapEntry(key, value)),
      );
      await prefs.setString('custom_muscle_group_keywords', encoded);
    } else {
      await prefs.remove('custom_muscle_group_keywords');
    }
  }

  void _saveReadinessScore(String date, int score) {
    setState(() {
      _readinessScores.removeWhere((r) => r.date == date);
      _readinessScores.add(DailyReadinessScore(date: date, score: score));
    });
    _saveReadinessScores();
  }

  int? getReadinessScore(String date) {
    final score = _readinessScores.firstWhere(
      (r) => r.date == date,
      orElse: () => DailyReadinessScore(date: date, score: 0),
    );
    return score.score > 0 ? score.score : null;
  }

  // --- Logic ---

  int getPersonalBest(String exerciseName) {
    final exerciseHistory =
        _history.where((h) => h.exercise == exerciseName).toList();
    if (exerciseHistory.isEmpty) return 0;
    return exerciseHistory.map((h) => h.oneRM).reduce(max);
  }

  WorkoutEntry? getLastWorkoutEntry(String exerciseName) {
    final exerciseHistory =
        _history.where((h) => h.exercise == exerciseName).toList();
    if (exerciseHistory.isEmpty) return null;
    // Sort by date descending, then by id descending to get the most recent
    exerciseHistory.sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;
      return b.id.compareTo(a.id);
    });
    return exerciseHistory.first;
  }

  void _deleteWorkoutEntry(double entryId) {
    setState(() {
      _history.removeWhere((entry) => entry.id == entryId);
    });
    _saveHistory();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Workout entry deleted.")));
  }

  void _finishWorkout() {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    List<WorkoutEntry> newEntries = [];

    _currentLog.forEach((exercise, sets) {
      for (int i = 0; i < sets.length; i++) {
        final set = sets[i];
        final w = double.tryParse(set['weight'] ?? '');
        final r = double.tryParse(set['reps'] ?? '');
        final rpe = set['rpe'] ?? '';

        if (w != null && r != null) {
          final oneRM = calculate1RM(w, r);
          newEntries.add(
            WorkoutEntry(
              id:
                  DateTime.now().millisecondsSinceEpoch.toDouble() +
                  Random().nextDouble(),
              date: date,
              split: _selectedDay,
              exercise: exercise,
              setNumber: i + 1,
              weight: w,
              reps: r,
              rpe: rpe,
              oneRM: oneRM,
            ),
          );
        }
      }
    });

    if (newEntries.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Log some sets first!")));
      return;
    }

    setState(() {
      _history.addAll(newEntries);
      _currentLog = {}; // Reset log
    });
    _saveHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Workout Saved! Check History tab.")),
    );
  }

  Future<void> _exportToCSV() async {
    const header = "Date,Split,Exercise,Set,Weight,Reps,RPE,Est_1RM";
    final rows = _history
        .map((h) {
          // Escape quotes for CSV
          final split = h.split.contains(',') ? '"${h.split}"' : h.split;
          final ex = h.exercise.contains(',') ? '"${h.exercise}"' : h.exercise;
          return "${h.date},$split,$ex,${h.setNumber},${h.weight},${h.reps},${h.rpe},${h.oneRM}";
        })
        .join("\n");

    final csvContent = "$header\n$rows";

    // Generate filename with timestamp
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final fileName = "training_log_$timestamp.csv";

    try {
      // Try to use file picker's saveFile for direct file saving (works on desktop and some mobile)
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Training Log',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (outputFile != null) {
        // User selected a location, save the file there
        final file = File(outputFile);
        await file.writeAsString(csvContent);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("File saved to: ${file.path}"),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // User cancelled or platform doesn't support saveFile
        // Fall back to share functionality
        final directory = await getApplicationDocumentsDirectory();
        final path = "${directory.path}/$fileName";
        final file = File(path);
        await file.writeAsString(csvContent);

        await Share.shareXFiles(
          [XFile(path)],
          text: 'My Workout Log',
          subject: 'Training Log Export',
        );
      }
    } catch (e) {
      // If saveFile fails, fall back to share
      debugPrint("FilePicker saveFile failed: $e");
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/$fileName";
      final file = File(path);
      await file.writeAsString(csvContent);

      await Share.shareXFiles(
        [XFile(path)],
        text: 'My Workout Log',
        subject: 'Training Log Export',
      );
    }
  }

  Future<void> _importCSV() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type:
          FileType
              .any, // Allowing any for broader mobile compatibility, ideally 'csv'
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();

      try {
        List<String> rows = content.split("\n");
        if (rows.length < 2) return; // Header only

        List<WorkoutEntry> newHistory = [];

        // Skip header
        for (int i = 1; i < rows.length; i++) {
          String row = rows[i];
          if (row.trim().isEmpty) continue;

          // A safer manual split logic for simple CSVs:
          // Note: This is a basic parser.
          List<String> vals = row.split(',');

          if (vals.length >= 8) {
            // Basic reconstruction
            newHistory.add(
              WorkoutEntry(
                id: DateTime.now().millisecondsSinceEpoch.toDouble() + i,
                date: vals[0],
                split: vals[1].replaceAll('"', ''),
                exercise: vals[2].replaceAll('"', ''),
                setNumber: int.tryParse(vals[3]) ?? 1,
                weight: double.tryParse(vals[4]) ?? 0,
                reps: double.tryParse(vals[5]) ?? 0,
                rpe: vals[6],
                oneRM: int.tryParse(vals[7]) ?? 0,
              ),
            );
          }
        }

        if (!mounted) return;
        bool confirm =
            await showDialog(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: const Text("Overwrite Data?"),
                    content: Text(
                      "Found ${newHistory.length} entries. This will replace your current data.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("Import"),
                      ),
                    ],
                  ),
            ) ??
            false;

        if (confirm) {
          if (!mounted) return;
          setState(() {
            _history = newHistory;
          });
          _saveHistory();
        }
      } catch (e) {
        debugPrint(e.toString());
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Error parsing CSV")));
      }
    }
  }

  // --- UI Builders ---

  Widget _buildLogger() {
    // Get the actual days for the currently selected program
    final allPrograms = _allPrograms;
    final currentProgramDays = allPrograms[_selectedProgramName]!;

    // Ensure selectedDay is valid for this program (fallback safety)
    final validSelectedDay =
        currentProgramDays.containsKey(_selectedDay)
            ? _selectedDay
            : currentProgramDays.keys.first;

    // Update state if needed (schedule for after build)
    if (validSelectedDay != _selectedDay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedDay = validSelectedDay;
          });
        }
      });
    }

    final programExercises = currentProgramDays[validSelectedDay]!;

    // Get all exercises: program exercises + any swapped/added exercises in current log
    final allCurrentExercises = <String>{...programExercises};
    // Add any exercises in current log that aren't in the program (swapped/added)
    for (final exercise in _currentLog.keys) {
      allCurrentExercises.add(exercise);
    }
    final exercises = allCurrentExercises.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- 1. PROGRAM SELECTOR (NEW) ---
        Text(
          "Select Program",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade900.withValues(
              alpha: 0.3,
            ), // Distinct color
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade700),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedProgramName,
              icon: Icon(Icons.swap_horiz, color: Colors.blue.shade300),
              dropdownColor: const Color(0xFF1E293B),
              style: TextStyle(color: Colors.blue.shade300),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedProgramName = val;
                    // Reset the day to the first day of the new program
                    _selectedDay = _allPrograms[val]!.keys.first;
                    _currentLog = {}; // Clear active inputs
                  });
                  _saveProgramSelection(); // Persist the change
                }
              },
              items:
                  _allPrograms.keys
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Row(
                            children: [
                              Text(
                                e,
                                style: TextStyle(color: Colors.blue.shade300),
                              ),
                              if (_customPrograms.containsKey(e))
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade900.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.green.shade700,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      "Custom",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green.shade300,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // --- 2. DAY SELECTOR (EXISTING, UPDATED SOURCE) ---
        Text(
          "Select Workout Day",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: validSelectedDay,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedDay = val;
                    _currentLog = {}; // Reset log on split change
                  });
                }
              },
              // Use currentProgramDays.keys instead of SPLIT_DATA.keys
              items:
                  currentProgramDays.keys
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Exercises
        ...exercises.map((exercise) {
          final pb = getPersonalBest(exercise);
          final lastEntry = getLastWorkoutEntry(exercise);
          final isFromProgram = programExercises.contains(exercise);
          // Initialize sets if empty
          if (!_currentLog.containsKey(exercise)) {
            _currentLog[exercise] = [
              {'weight': '', 'reps': '', 'rpe': ''},
            ];
          }
          final sets = _currentLog[exercise]!;

          return _ExerciseCard(
            key: ValueKey(exercise), // Important for state retention
            exerciseName: exercise,
            personalBest: pb,
            lastWorkoutEntry: lastEntry,
            sets: sets,
            isSwapped: !isFromProgram, // Show indicator if swapped/added
            onSetChanged: (index, field, value) {
              setState(() {
                sets[index][field] = value;
                // Auto-add next set logic
                if (index == sets.length - 1 &&
                    sets[index]['weight']!.isNotEmpty &&
                    sets[index]['reps']!.isNotEmpty) {
                  sets.add({'weight': '', 'reps': '', 'rpe': ''});
                }
              });
            },
            onRemoveSet: (index) {
              setState(() {
                sets.removeAt(index);
                if (sets.isEmpty) {
                  sets.add({'weight': '', 'reps': '', 'rpe': ''});
                }
              });
            },
            onSwapExercise:
                (oldExercise) => _showSwapExerciseDialog(oldExercise),
            onRemoveExercise:
                !isFromProgram
                    ? () {
                      setState(() {
                        _currentLog.remove(exercise);
                      });
                    }
                    : null,
            onShowProgression:
                (exerciseName) => _showExerciseProgression(exerciseName),
          );
        }),
        // Add Exercise Button (for adding exercises not in program)
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _showAddExerciseDialog(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text("Add Exercise (Not in Program)"),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade700),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        // Optional Cardio Section
        Divider(color: Colors.grey.shade700),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _showAddCardioDialog(),
          icon: const Icon(Icons.directions_run, size: 18),
          label: const Text("Add Cardio (Optional)"),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green.shade300,
            side: BorderSide(color: Colors.green.shade700),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _finishWorkout,
          icon: const Icon(Icons.save),
          label: const Text("Finish & Save Workout"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 80), // Padding for bottom nav
      ],
    );
  }

  Widget _buildProgress() {
    // Prepare Data - Get all exercises from all programs
    final allPrograms = _allPrograms;
    final allExercises =
        allPrograms.values
            .expand(
              (program) => program.values.expand((exercises) => exercises),
            )
            .toSet()
            .toList();

    // Sort history by date
    final sortedHistory =
        _history.where((h) => h.exercise == _selectedExercise).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    // Group max 1RM per date
    Map<String, int> grouped = {};
    for (var h in sortedHistory) {
      if (!grouped.containsKey(h.date) || h.oneRM > grouped[h.date]!) {
        grouped[h.date] = h.oneRM;
      }
    }

    final chartData = grouped.entries.toList();

    // Convert dates to days since first date for linear time axis
    final dates = chartData.map((e) => DateTime.parse(e.key)).toList();
    final firstDate = dates.isNotEmpty ? dates.first : DateTime.now();
    final daysSinceFirst =
        dates.map((date) {
          return date.difference(firstDate).inDays.toDouble();
        }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value:
                  allExercises.contains(_selectedExercise)
                      ? _selectedExercise
                      : allExercises.first,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              onChanged: (val) => setState(() => _selectedExercise = val!),
              items:
                  allExercises
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Chart
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.trending_up, color: Color(0xFF3B82F6)),
                  SizedBox(width: 8),
                  Text(
                    "Strength Progression (Est. 1RM)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child:
                    chartData.isEmpty
                        ? Center(
                          child: Text(
                            "No data for this exercise yet.",
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        )
                        : chartData.length == 1
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "1RM: ${chartData.first.value} kg",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Date: ${chartData.first.key}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Need at least 2 entries to show trend",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                        : LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Colors.grey.shade800,
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: max(
                                    7.0,
                                    daysSinceFirst.isNotEmpty
                                        ? (daysSinceFirst.last -
                                                daysSinceFirst.first) /
                                            6
                                        : 7.0,
                                  ),
                                  getTitlesWidget: (value, meta) {
                                    // Find the closest date to this value
                                    double minDiff = double.infinity;
                                    int closestIndex = -1;
                                    for (
                                      int i = 0;
                                      i < daysSinceFirst.length;
                                      i++
                                    ) {
                                      final diff =
                                          (daysSinceFirst[i] - value).abs();
                                      if (diff < minDiff) {
                                        minDiff = diff;
                                        closestIndex = i;
                                      }
                                    }

                                    if (closestIndex >= 0 &&
                                        closestIndex < chartData.length) {
                                      final date = DateTime.parse(
                                        chartData[closestIndex].key,
                                      );
                                      final formatted = DateFormat(
                                        'MMM dd',
                                      ).format(date);
                                      return Text(
                                        formatted,
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 9,
                                        ),
                                        textAlign: TextAlign.center,
                                      );
                                    }
                                    return const Text("");
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            minX:
                                daysSinceFirst.isNotEmpty
                                    ? daysSinceFirst.first - 1
                                    : 0,
                            maxX:
                                daysSinceFirst.isNotEmpty
                                    ? daysSinceFirst.last + 1
                                    : 1,
                            minY:
                                chartData
                                    .map((e) => e.value.toDouble())
                                    .reduce((a, b) => a < b ? a : b) *
                                0.9,
                            maxY:
                                chartData
                                    .map((e) => e.value.toDouble())
                                    .reduce((a, b) => a > b ? a : b) *
                                1.1,
                            lineBarsData: [
                              LineChartBarData(
                                spots:
                                    chartData.asMap().entries.map((e) {
                                      return FlSpot(
                                        daysSinceFirst[e
                                            .key], // Days since first date
                                        e.value.value.toDouble(),
                                      );
                                    }).toList(),
                                isCurved: true,
                                color: const Color(0xFF3B82F6),
                                barWidth: 3,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (
                                    spot,
                                    percent,
                                    barData,
                                    index,
                                  ) {
                                    return FlDotCirclePainter(
                                      radius: 4,
                                      color: const Color(0xFF3B82F6),
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    );
                                  },
                                ),
                                belowBarData: BarAreaData(show: false),
                              ),
                            ],
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    // Find closest date to this x value
                                    double minDiff = double.infinity;
                                    int closestIndex = -1;
                                    for (
                                      int i = 0;
                                      i < daysSinceFirst.length;
                                      i++
                                    ) {
                                      final diff =
                                          (daysSinceFirst[i] - spot.x).abs();
                                      if (diff < minDiff) {
                                        minDiff = diff;
                                        closestIndex = i;
                                      }
                                    }

                                    if (closestIndex >= 0 &&
                                        closestIndex < chartData.length) {
                                      final date = chartData[closestIndex].key;
                                      final dateObj = DateTime.parse(date);
                                      final formatted = DateFormat(
                                        'MMM dd, yyyy',
                                      ).format(dateObj);
                                      return LineTooltipItem(
                                        "$formatted\n${spot.y.toInt()} kg",
                                        const TextStyle(color: Colors.white),
                                      );
                                    }
                                    return LineTooltipItem(
                                      "${spot.y.toInt()} kg",
                                      const TextStyle(color: Colors.white),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                          ),
                        ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Stats Cards
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                "Current Max",
                "${chartData.isEmpty ? 0 : chartData.map((e) => e.value).reduce(max)}",
                const Color(0xFF1E293B),
                Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                "Total Sets",
                "${sortedHistory.length}",
                const Color(0xFF1E293B),
                Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String val, Color bg, Color txt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
            ),
          ),
          Text(
            val,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importCSV,
                  icon: const Icon(Icons.file_upload, size: 16),
                  label: const Text("Import CSV"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportToCSV,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text("Export CSV"),
                ),
              ),
            ],
          ),
        ),
        // Warning
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade900.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade700),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Colors.amber.shade300,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Importing replaces current data.",
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade200),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF1E293B),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  "Date",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  "Activity",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "Details",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  "Metric",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              const SizedBox(width: 40), // Space for delete button
            ],
          ),
        ),

        // List - Combine workout and cardio entries
        Expanded(
          child: Builder(
            builder: (context) {
              // Combine and sort all entries by date (newest first)
              final allEntries = <Map<String, dynamic>>[];

              // Add workout entries
              for (final entry in _history) {
                allEntries.add({
                  'type': 'workout',
                  'id': entry.id,
                  'date': entry.date,
                  'data': entry,
                });
              }

              // Add cardio entries
              for (final entry in _cardioHistory) {
                allEntries.add({
                  'type': 'cardio',
                  'id': entry.id,
                  'date': entry.date,
                  'data': entry,
                });
              }

              // Sort by date (newest first)
              allEntries.sort((a, b) {
                final dateCompare = b['date'].compareTo(a['date']);
                if (dateCompare != 0) return dateCompare;
                // If same date, sort by id (newer first)
                return (b['id'] as double).compareTo(a['id'] as double);
              });

              if (allEntries.isEmpty) {
                return Center(
                  child: Text(
                    "No history logged.",
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                );
              }

              return ListView.separated(
                itemCount: allEntries.length,
                separatorBuilder:
                    (c, i) => Divider(height: 1, color: Colors.grey.shade800),
                itemBuilder: (context, index) {
                  final entryMap = allEntries[index];
                  final entryType = entryMap['type'] as String;
                  final entryDate = entryMap['date'] as String;

                  if (entryType == 'workout') {
                    final entry = entryMap['data'] as WorkoutEntry;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              entryDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.fitness_center,
                                  size: 14,
                                  color: Colors.blue.shade300,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    entry.exercise,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "${entry.weight.toStringAsFixed(0)} x ${entry.reps.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "${entry.oneRM}",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red.shade400,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder:
                                    (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E293B),
                                      title: const Text(
                                        "Delete Workout?",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: Text(
                                        "Are you sure you want to delete this workout entry?\n\n${entry.exercise} - ${entry.weight.toStringAsFixed(0)}kg x ${entry.reps.toStringAsFixed(0)}",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _deleteWorkoutEntry(entry.id);
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          child: const Text("Delete"),
                                        ),
                                      ],
                                    ),
                              );
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Cardio entry
                    final entry = entryMap['data'] as CardioEntry;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              entryDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.directions_run,
                                  size: 14,
                                  color: Colors.green.shade300,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    entry.type,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "${entry.duration} min${entry.distance != null ? ' • ${entry.distance!.toStringAsFixed(1)} km' : ''}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              entry.intensity ?? "-",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade300,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red.shade400,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder:
                                    (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E293B),
                                      title: const Text(
                                        "Delete Cardio?",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: Text(
                                        "Are you sure you want to delete this cardio session?\n\n${entry.type} - ${entry.duration} min${entry.distance != null ? ' • ${entry.distance!.toStringAsFixed(1)} km' : ''}",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            setState(() {
                                              _cardioHistory.removeWhere(
                                                (e) => e.id == entry.id,
                                              );
                                            });
                                            _saveCardioHistory();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Cardio session deleted.",
                                                ),
                                              ),
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          child: const Text("Delete"),
                                        ),
                                      ],
                                    ),
                              );
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedAnalytics() {
    final weeks = PeriodizationEngine.getUniqueWeeks(_history);
    final allExercises =
        _allPrograms.values
            .expand(
              (program) => program.values.expand((exercises) => exercises),
            )
            .toSet()
            .toList();

    // Check for plateaus
    final plateaus = <String>[];
    for (final exercise in allExercises) {
      if (PeriodizationEngine.detectPlateau(_history, exercise)) {
        plateaus.add(exercise);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Daily Readiness Score Input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.wb_sunny, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  const Text(
                    "Daily Readiness Score",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E293B),
                              title: const Text(
                                "Daily Readiness Score",
                                style: TextStyle(color: Colors.white),
                              ),
                              content: Text(
                                "The Daily Readiness Score helps the app understand your recovery status and optimize training recommendations.\n\n"
                                "HOW IT WORKS:\n"
                                "• Rate your day on a scale of 1-5 based on sleep quality and stress levels\n"
                                "• 1 = Poor (bad sleep, high stress, feeling drained)\n"
                                "• 2 = Below Average (restless sleep, elevated stress)\n"
                                "• 3 = Average (normal sleep, moderate stress)\n"
                                "• 4 = Good (quality sleep, low stress, feeling energized)\n"
                                "• 5 = Excellent (great sleep, minimal stress, fully recovered)\n\n"
                                "HOW IT'S USED:\n"
                                "• Affects the SRA (Stress, Recovery, Adaptation) curve calculations\n"
                                "• Higher readiness scores = faster recovery rates on rest days\n"
                                "• Lower readiness scores = slower recovery, may need more rest\n"
                                "• Helps identify patterns between readiness and training performance\n\n"
                                "TIP: Log your readiness score daily for the most accurate analytics. The app uses this data to model your recovery and adaptation phases.",
                                style: const TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Got it"),
                                ),
                              ],
                            ),
                      );
                    },
                    child: Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Rate your sleep/stress levels (1-5)",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final score = index + 1;
                  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                  final currentScore = getReadinessScore(today);
                  final isSelected = currentScore == score;
                  return GestureDetector(
                    onTap: () => _saveReadinessScore(today, score),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? const Color(0xFF3B82F6)
                                : Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              isSelected
                                  ? Colors.blue.shade300
                                  : Colors.grey.shade700,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "$score",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color:
                                isSelected
                                    ? Colors.white
                                    : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Plateau Detection Warning
        if (plateaus.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade900.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade300),
                    const SizedBox(width: 8),
                    const Text(
                      "Overreaching Detected",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Progress has stalled for 2+ weeks on: ${plateaus.join(', ')}",
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade200),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _showDeloadWizard(plateaus),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Schedule Deload Week"),
                ),
              ],
            ),
          ),

        if (plateaus.isNotEmpty) const SizedBox(height: 20),

        // Volume vs Intensity Graph
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  const Text(
                    "Volume vs Intensity",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E293B),
                              title: const Text(
                                "Volume vs Intensity",
                                style: TextStyle(color: Colors.white),
                              ),
                              content: Text(
                                "Shows weekly training volume (total kg lifted) and average intensity (% of e1RM).\n\n"
                                "• Blue line: Volume Load - Higher is more total work\n"
                                "• Purple line: Intensity - Higher % means heavier relative loads\n"
                                "• Ideal: Volume increases over mesocycle, intensity stays stable or slightly increases\n"
                                "• Warning: If both drop for 2+ weeks, you may be overreaching",
                                style: const TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Got it"),
                                ),
                              ],
                            ),
                      );
                    },
                    child: Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Volume (kg) - Left",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Intensity (%) - Right",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child:
                    weeks.isEmpty
                        ? Center(
                          child: Text(
                            "Need at least 1 week of data",
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        )
                        : Builder(
                          builder: (context) {
                            // Calculate volume and intensity values
                            final volumeValues =
                                weeks
                                    .map(
                                      (w) =>
                                          PeriodizationEngine.calculateWeeklyVolumeLoad(
                                            _history,
                                            w,
                                          ),
                                    )
                                    .toList();
                            final intensityValues =
                                weeks
                                    .map(
                                      (w) =>
                                          PeriodizationEngine.calculateWeeklyAverageIntensity(
                                            _history,
                                            w,
                                          ),
                                    )
                                    .toList();

                            // Find max values for normalization
                            final maxVolume =
                                volumeValues.isEmpty
                                    ? 1.0
                                    : volumeValues.reduce(
                                      (a, b) => a > b ? a : b,
                                    );
                            final maxIntensity =
                                intensityValues.isEmpty
                                    ? 1.0
                                    : intensityValues.reduce(
                                      (a, b) => a > b ? a : b,
                                    );

                            // Convert week dates to days since first week for linear time axis
                            final weekDates =
                                weeks.map((w) => DateTime.parse(w)).toList();
                            final firstWeekDate = weekDates.first;

                            // Calculate days since first week for each week
                            final daysSinceFirst =
                                weekDates.map((date) {
                                  return date
                                      .difference(firstWeekDate)
                                      .inDays
                                      .toDouble();
                                }).toList();

                            // Normalize both to 0-100 scale for comparison
                            final normalizedVolumeSpots =
                                weeks.asMap().entries.map((e) {
                                  final volume = volumeValues[e.key];
                                  final normalized =
                                      maxVolume > 0
                                          ? (volume / maxVolume) * 100
                                          : 0.0;
                                  return FlSpot(
                                    daysSinceFirst[e.key],
                                    normalized,
                                  );
                                }).toList();

                            final normalizedIntensitySpots =
                                weeks.asMap().entries.map((e) {
                                  final intensity = intensityValues[e.key];
                                  final normalized =
                                      maxIntensity > 0
                                          ? (intensity / maxIntensity) * 100
                                          : 0.0;
                                  return FlSpot(
                                    daysSinceFirst[e.key],
                                    normalized,
                                  );
                                }).toList();

                            return LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: Colors.grey.shade800,
                                      strokeWidth: 1,
                                    );
                                  },
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 60,
                                      getTitlesWidget: (value, meta) {
                                        // Convert normalized value back to actual volume
                                        final actualVolume =
                                            (value / 100) * maxVolume;
                                        if (maxVolume > 1000) {
                                          return Text(
                                            "${(actualVolume / 1000).toStringAsFixed(1)}k",
                                            style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 10,
                                            ),
                                          );
                                        }
                                        return Text(
                                          "${actualVolume.toInt()}",
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 10,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 50,
                                      getTitlesWidget: (value, meta) {
                                        // Convert normalized value back to actual intensity
                                        final actualIntensity =
                                            (value / 100) * maxIntensity;
                                        return Text(
                                          "${actualIntensity.toStringAsFixed(0)}%",
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 10,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 60,
                                      interval: max(
                                        7.0,
                                        (daysSinceFirst.last -
                                                daysSinceFirst.first) /
                                            6,
                                      ),
                                      getTitlesWidget: (value, meta) {
                                        // Find the closest week date to this value
                                        double minDiff = double.infinity;
                                        int closestIndex = -1;
                                        for (
                                          int i = 0;
                                          i < daysSinceFirst.length;
                                          i++
                                        ) {
                                          final diff =
                                              (daysSinceFirst[i] - value).abs();
                                          if (diff < minDiff) {
                                            minDiff = diff;
                                            closestIndex = i;
                                          }
                                        }

                                        if (closestIndex >= 0 &&
                                            closestIndex < weeks.length) {
                                          final weekStart = DateTime.parse(
                                            weeks[closestIndex],
                                          );
                                          final formatted = DateFormat(
                                            'MMM dd',
                                          ).format(weekStart);
                                          return RotatedBox(
                                            quarterTurns: 0,
                                            child: Text(
                                              formatted,
                                              style: TextStyle(
                                                color: Colors.grey.shade400,
                                                fontSize: 9,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          );
                                        }
                                        return const Text("");
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                minX: daysSinceFirst.first - 1,
                                maxX: daysSinceFirst.last + 1,
                                minY: 0,
                                maxY: 110, // Slightly above 100 for padding
                                lineBarsData: [
                                  // Volume Load Line (normalized)
                                  LineChartBarData(
                                    spots: normalizedVolumeSpots,
                                    isCurved: true,
                                    color: const Color(0xFF3B82F6),
                                    barWidth: 3,
                                    dotData: FlDotData(show: false),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                  // Intensity Line (normalized)
                                  LineChartBarData(
                                    spots: normalizedIntensitySpots,
                                    isCurved: true,
                                    color: const Color(0xFF8B5CF6),
                                    barWidth: 3,
                                    dotData: FlDotData(show: false),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                ],
                                lineTouchData: LineTouchData(
                                  touchTooltipData: LineTouchTooltipData(
                                    getTooltipItems: (touchedSpots) {
                                      return touchedSpots.map((spot) {
                                        // Find closest week to this x value
                                        double minDiff = double.infinity;
                                        int closestIndex = -1;
                                        for (
                                          int i = 0;
                                          i < daysSinceFirst.length;
                                          i++
                                        ) {
                                          final diff =
                                              (daysSinceFirst[i] - spot.x)
                                                  .abs();
                                          if (diff < minDiff) {
                                            minDiff = diff;
                                            closestIndex = i;
                                          }
                                        }

                                        if (closestIndex >= 0 &&
                                            closestIndex < weeks.length) {
                                          final volume =
                                              volumeValues[closestIndex];
                                          final intensity =
                                              intensityValues[closestIndex];
                                          final weekDate = DateTime.parse(
                                            weeks[closestIndex],
                                          );
                                          final dateStr = DateFormat(
                                            'MMM dd',
                                          ).format(weekDate);
                                          final isVolume = spot.barIndex == 0;
                                          if (isVolume) {
                                            return LineTooltipItem(
                                              "$dateStr\nVolume: ${volume.toStringAsFixed(0)}kg",
                                              const TextStyle(
                                                color: Color(0xFF3B82F6),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            );
                                          } else {
                                            return LineTooltipItem(
                                              "$dateStr\nIntensity: ${intensity.toStringAsFixed(1)}%",
                                              const TextStyle(
                                                color: Color(0xFF8B5CF6),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            );
                                          }
                                        }
                                        return LineTooltipItem(
                                          spot.y.toStringAsFixed(1),
                                          const TextStyle(color: Colors.white),
                                        );
                                      }).toList();
                                    },
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

        const SizedBox(height: 20),

        // e1RM Trends
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.show_chart, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  const Text(
                    "e1RM Trends (All Exercises)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E293B),
                              title: const Text(
                                "e1RM Trends",
                                style: TextStyle(color: Colors.white),
                              ),
                              content: Text(
                                "Estimated 1-Rep Max trends for each exercise over time.\n\n"
                                "• Shows true strength gains regardless of rep ranges used\n"
                                "• Calculated using Epley formula: e1RM = Weight × (1 + Reps/30)\n"
                                "• Upward trend = strength increasing\n"
                                "• Flat/declining trend for 2+ weeks = plateau detected\n"
                                "• Scroll horizontally to see all exercises",
                                style: const TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Got it"),
                                ),
                              ],
                            ),
                      );
                    },
                    child: Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child:
                    allExercises.isEmpty
                        ? Center(
                          child: Text(
                            "No exercises logged yet",
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        )
                        : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: allExercises.length,
                          itemBuilder: (context, index) {
                            final exercise = allExercises[index];
                            final exerciseHistory =
                                _history
                                    .where((h) => h.exercise == exercise)
                                    .toList()
                                  ..sort((a, b) => a.date.compareTo(b.date));

                            if (exerciseHistory.isEmpty) {
                              return const SizedBox();
                            }

                            final grouped = <String, int>{};
                            for (var h in exerciseHistory) {
                              if (!grouped.containsKey(h.date) ||
                                  h.oneRM > grouped[h.date]!) {
                                grouped[h.date] = h.oneRM;
                              }
                            }

                            final chartData = grouped.entries.toList();
                            if (chartData.length < 2) return const SizedBox();

                            // Convert dates to days since first date for linear time axis
                            final dates =
                                chartData
                                    .map((e) => DateTime.parse(e.key))
                                    .toList();
                            final firstDate = dates.first;
                            final daysSinceFirst =
                                dates.map((date) {
                                  return date
                                      .difference(firstDate)
                                      .inDays
                                      .toDouble();
                                }).toList();

                            return Container(
                              width: 250,
                              margin: const EdgeInsets.only(right: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exercise,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: LineChart(
                                      LineChartData(
                                        gridData: FlGridData(
                                          show: true,
                                          drawVerticalLine: false,
                                          getDrawingHorizontalLine: (value) {
                                            return FlLine(
                                              color: Colors.grey.shade800,
                                              strokeWidth: 1,
                                            );
                                          },
                                        ),
                                        titlesData: FlTitlesData(
                                          leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 40,
                                              getTitlesWidget: (value, meta) {
                                                return Text(
                                                  "${value.toInt()}kg",
                                                  style: TextStyle(
                                                    color: Colors.grey.shade400,
                                                    fontSize: 9,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          rightTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: false,
                                            ),
                                          ),
                                          topTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: false,
                                            ),
                                          ),
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 30,
                                              interval: max(
                                                7.0,
                                                (daysSinceFirst.last -
                                                        daysSinceFirst.first) /
                                                    6,
                                              ),
                                              getTitlesWidget: (value, meta) {
                                                // Find the closest date to this value
                                                double minDiff =
                                                    double.infinity;
                                                int closestIndex = -1;
                                                for (
                                                  int i = 0;
                                                  i < daysSinceFirst.length;
                                                  i++
                                                ) {
                                                  final diff =
                                                      (daysSinceFirst[i] -
                                                              value)
                                                          .abs();
                                                  if (diff < minDiff) {
                                                    minDiff = diff;
                                                    closestIndex = i;
                                                  }
                                                }

                                                if (closestIndex >= 0 &&
                                                    closestIndex <
                                                        chartData.length) {
                                                  final date = DateTime.parse(
                                                    chartData[closestIndex].key,
                                                  );
                                                  final formatted = DateFormat(
                                                    'MMM dd',
                                                  ).format(date);
                                                  return Text(
                                                    formatted,
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade400,
                                                      fontSize: 8,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  );
                                                }
                                                return const Text("");
                                              },
                                            ),
                                          ),
                                        ),
                                        borderData: FlBorderData(show: false),
                                        minX: daysSinceFirst.first - 1,
                                        maxX: daysSinceFirst.last + 1,
                                        minY:
                                            chartData
                                                .map((e) => e.value.toDouble())
                                                .reduce(
                                                  (a, b) => a < b ? a : b,
                                                ) *
                                            0.9,
                                        maxY:
                                            chartData
                                                .map((e) => e.value.toDouble())
                                                .reduce(
                                                  (a, b) => a > b ? a : b,
                                                ) *
                                            1.1,
                                        lineBarsData: [
                                          LineChartBarData(
                                            spots:
                                                chartData.asMap().entries.map((
                                                  e,
                                                ) {
                                                  return FlSpot(
                                                    daysSinceFirst[e
                                                        .key], // Days since first date
                                                    e.value.value.toDouble(),
                                                  );
                                                }).toList(),
                                            isCurved: true,
                                            color: const Color(0xFF3B82F6),
                                            barWidth: 2,
                                            dotData: FlDotData(show: false),
                                            belowBarData: BarAreaData(
                                              show: false,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // SRA (Stress, Recovery, Adaptation) Curve
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.waves, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "SRA Curve (Stress, Recovery, Adaptation)",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E293B),
                              title: const Text(
                                "SRA Curve",
                                style: TextStyle(color: Colors.white),
                              ),
                              content: SingleChildScrollView(
                                child: Text(
                                  "SRA (Stress, Recovery, Adaptation) curve models your training response.\n\n"
                                  "PHASES:\n"
                                  "• <45% (Red): Stress Phase - Training day, performance drops due to fatigue\n"
                                  "• 45-55% (Orange): Recovery Phase - Rest day, returning to baseline\n"
                                  "• >55% (Green): Adaptation Phase - Supercompensation, performance above baseline\n"
                                  "• Baseline (50%): Your normal performance level\n"
                                  "• Ideal: Train when in adaptation phase for best results\n\n"
                                  "FORMULA:\n"
                                  "Baseline: Adaptation = 50\n\n"
                                  "Training Days:\n"
                                  "• Stress = Σ(Weight × Reps × (RPE/10 × 2)) for all sets\n"
                                  "• NormalizedStress = (TotalStress / 10000).clamp(0.0, 2.0)\n"
                                  "• Adaptation = Adaptation - (NormalizedStress × 15)\n\n"
                                  "Recovery Days:\n"
                                  "• RecoveryRate = (ReadinessScore / 5) × 2\n"
                                  "• Adaptation = Adaptation + RecoveryRate\n"
                                  "• Max supercompensation capped at 65%\n\n"
                                  "Decay:\n"
                                  "• If Adaptation > 50 with no training: Adaptation -= 0.5\n\n"
                                  "Recovery rate depends on your daily readiness scores (1-5).",
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Got it"),
                                ),
                              ],
                            ),
                      );
                    },
                    child: Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Shows training stress, recovery, and supercompensation over time",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 12),
              Expanded(
                child:
                    _history.isEmpty
                        ? Center(
                          child: Text(
                            "Need training data to show SRA curve",
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        )
                        : _buildSRACurve(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Fatigue Accumulation Heatmap
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.heat_pump, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  const Text(
                    "Fatigue Accumulation Heatmap",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E293B),
                              title: const Text(
                                "Fatigue Accumulation Heatmap",
                                style: TextStyle(color: Colors.white),
                              ),
                              content: Text(
                                "Shows weekly set volume per muscle group and fatigue status.\n\n"
                                "• Green (<10 sets): Maintenance - Room to add volume\n"
                                "• Yellow (10-18 sets): Productive Training - Optimal range\n"
                                "• Red (>20 sets OR RPE 10 for 2 weeks): High Fatigue - Consider reducing volume\n"
                                "• Approaching MRV: Near your Maximum Recoverable Volume\n"
                                "• Based on current week's training data\n"
                                "• If a muscle group turns red, consider capping sets next week",
                                style: const TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Got it"),
                                ),
                              ],
                            ),
                      );
                    },
                    child: Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (weeks.isEmpty)
                Center(
                  child: Text(
                    "Need at least 1 week of data",
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                )
              else
                ..._effectiveMuscleGroupKeywords.keys.map((muscleGroup) {
                  final currentWeek = weeks.isNotEmpty ? weeks.last : "";
                  final weeklySets =
                      PeriodizationEngine.getWeeklySetsPerMuscleGroup(
                        _history,
                        currentWeek,
                        _customMuscleGroupKeywords,
                      );
                  final sets = weeklySets[muscleGroup] ?? 0;
                  final mrv = PeriodizationEngine.estimateMRV(
                    _history,
                    muscleGroup,
                    currentWeek,
                    _customMuscleGroupKeywords,
                  );

                  Color color;
                  String status;
                  if (sets < 10) {
                    color = Colors.green;
                    status = "Maintenance";
                  } else if (sets <= 18) {
                    color = Colors.yellow;
                    status = "Productive";
                  } else {
                    color = Colors.red;
                    status = "High Fatigue";
                  }

                  if (mrv != null && sets >= mrv * 0.9) {
                    color = Colors.red;
                    status = "Approaching MRV";
                  }

                  return InkWell(
                    onTap:
                        () => _showMuscleGroupExercises(
                          muscleGroup,
                          currentWeek,
                          sets,
                          status,
                          color,
                        ),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              muscleGroup,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            width: 100,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: color, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                "$sets sets",
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status,
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSRACurve() {
    final sraData = PeriodizationEngine.calculateSRACurve(
      _history,
      _readinessScores,
    );

    if (sraData.isEmpty) {
      return Center(
        child: Text(
          "No data available",
          style: TextStyle(color: Colors.grey.shade400),
        ),
      );
    }

    final sortedDates = sraData.keys.toList()..sort();
    final chartData =
        sortedDates.map((date) => MapEntry(date, sraData[date]!)).toList();

    // Find min/max for Y-axis
    final minAdaptation =
        chartData
            .map((e) => e.value)
            .reduce((a, b) => a < b ? a : b)
            .floor()
            .toDouble();
    final maxAdaptation =
        chartData
            .map((e) => e.value)
            .reduce((a, b) => a > b ? a : b)
            .ceil()
            .toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            // Highlight baseline (50)
            if (value == 50) {
              return FlLine(
                color: Colors.grey.shade600,
                strokeWidth: 2,
                dashArray: [5, 5],
              );
            }
            return FlLine(color: Colors.grey.shade800, strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                if (value == 50) {
                  return Text(
                    "Baseline",
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
                return Text(
                  "${value.toInt()}",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              interval: max(1, (chartData.length / 7).ceil().toDouble()),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < chartData.length) {
                  final date = DateTime.parse(chartData[index].key);
                  final formatted = DateFormat('MMM dd').format(date);
                  // Only show if different from previous
                  if (index == 0 ||
                      (index > 0 &&
                          chartData[index].key != chartData[index - 1].key)) {
                    return RotatedBox(
                      quarterTurns: 0,
                      child: Text(
                        formatted,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                }
                return const Text("");
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: minAdaptation - 5,
        maxY: maxAdaptation + 5,
        lineBarsData: [
          LineChartBarData(
            spots:
                chartData.asMap().entries.map((e) {
                  return FlSpot(e.key.toDouble(), e.value.value);
                }).toList(),
            isCurved: true,
            color: const Color(0xFF10B981), // Green for adaptation
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= 0 && index < chartData.length) {
                  final date = chartData[index].key;
                  final adaptation = spot.y;
                  String phase;
                  Color phaseColor;
                  if (adaptation < 45) {
                    phase = "Stress";
                    phaseColor = Colors.red;
                  } else if (adaptation < 55) {
                    phase = "Recovery";
                    phaseColor = Colors.orange;
                  } else {
                    phase = "Adaptation";
                    phaseColor = Colors.green;
                  }
                  return LineTooltipItem(
                    "$date\n${adaptation.toStringAsFixed(1)}% ($phase)",
                    TextStyle(color: phaseColor, fontWeight: FontWeight.bold),
                  );
                }
                return LineTooltipItem(
                  "${spot.y.toStringAsFixed(1)}%",
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  void _showSwapExerciseDialog(String oldExercise) {
    final controller = TextEditingController(text: oldExercise);
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text(
              "Swap Exercise",
              style: TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Replace '$oldExercise' with:",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "New exercise name",
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
                    const SizedBox(height: 16),
                    // Show suggestions from existing exercises
                    Text(
                      "Or choose from existing exercises:",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        // Get exercises from programs
                        final programExercises =
                            _allPrograms.values
                                .expand((p) => p.values.expand((e) => e))
                                .toSet();

                        // Get exercises from workout history
                        final historyExercises =
                            _history.map((e) => e.exercise).toSet();

                        // Combine both sources
                        final allExercises =
                            <String>{
                                ...programExercises,
                                ...historyExercises,
                              }.toList()
                              ..sort();

                        final filteredExercises =
                            allExercises
                                .where((e) => e != oldExercise && e.isNotEmpty)
                                .toList();

                        if (filteredExercises.isEmpty) {
                          return Container(
                            constraints: const BoxConstraints(maxHeight: 150),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade700),
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  "No other exercises available.\nType a new exercise name above.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade700),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: filteredExercises.length,
                            itemBuilder: (context, index) {
                              final suggestion = filteredExercises[index];
                              return InkWell(
                                onTap: () {
                                  controller.text = suggestion;
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade800,
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.fitness_center,
                                        size: 16,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          suggestion,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final newExercise = controller.text.trim();
                  if (newExercise.isNotEmpty && newExercise != oldExercise) {
                    // Swap the exercise in _currentLog
                    if (_currentLog.containsKey(oldExercise)) {
                      final sets = _currentLog[oldExercise]!;
                      _currentLog.remove(oldExercise);
                      _currentLog[newExercise] = sets;
                    }
                    Navigator.pop(ctx);
                    setState(() {}); // Refresh UI
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                ),
                child: const Text("Swap"),
              ),
            ],
          ),
    );
  }

  void _showAddExerciseDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text(
              "Add Exercise",
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Add an exercise not in your program:",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Exercise name",
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
                      borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  final exerciseName = controller.text.trim();
                  if (exerciseName.isNotEmpty) {
                    // Add to current log
                    if (!_currentLog.containsKey(exerciseName)) {
                      _currentLog[exerciseName] = [
                        {'weight': '', 'reps': '', 'rpe': ''},
                      ];
                    }
                    Navigator.pop(ctx);
                    setState(() {}); // Refresh UI to show new exercise
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                ),
                child: const Text("Add"),
              ),
            ],
          ),
    );
  }

  void _showExerciseProgression(String exerciseName) {
    // Get all workout entries for this exercise, sorted by date (newest first)
    final exerciseHistory =
        _history.where((h) => h.exercise == exerciseName).toList()
          ..sort((a, b) {
            final dateCompare = b.date.compareTo(a.date);
            if (dateCompare != 0) return dateCompare;
            return b.id.compareTo(a.id);
          });

    if (exerciseHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No history found for $exerciseName"),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: Row(
              children: [
                const Icon(Icons.trending_up, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    exerciseName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Summary stats
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade700),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                "${exerciseHistory.length}",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade300,
                                ),
                              ),
                              Text(
                                "Total Sets",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                "${exerciseHistory.map((e) => e.oneRM).reduce((a, b) => a > b ? a : b)}",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade300,
                                ),
                              ),
                              Text(
                                "Best 1RM",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Progression History:",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...exerciseHistory.map((entry) {
                      final isPR =
                          entry.oneRM ==
                          exerciseHistory
                              .map((e) => e.oneRM)
                              .reduce((a, b) => a > b ? a : b);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                isPR
                                    ? Colors.yellow.shade900.withValues(
                                      alpha: 0.2,
                                    )
                                    : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  isPR
                                      ? Colors.yellow.shade700
                                      : Colors.grey.shade700,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          "${entry.weight.toStringAsFixed(0)}kg × ${entry.reps.toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (isPR) ...[
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.emoji_events,
                                            size: 16,
                                            color: Colors.amber.shade300,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          "e1RM: ${entry.oneRM}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue.shade300,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "• ${_formatProgressionDate(entry.date)}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Close",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
    );
  }

  String _formatProgressionDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _showAddCardioDialog() {
    final typeController = TextEditingController();
    final durationController = TextEditingController();
    final distanceController = TextEditingController();
    final intensityController = TextEditingController();
    final notesController = TextEditingController();
    String selectedType = 'Running';

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text(
                    "Add Cardio Session",
                    style: TextStyle(color: Colors.white),
                  ),
                  content: SingleChildScrollView(
                    child: SizedBox(
                      width: double.maxFinite,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Type:",
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedType,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white),
                            items:
                                [
                                      'Running',
                                      'Cycling',
                                      'Rowing',
                                      'Swimming',
                                      'Walking',
                                      'Other',
                                    ]
                                    .map(
                                      (type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(type),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedType = value ?? 'Running';
                                if (value == 'Other') {
                                  typeController.text = '';
                                } else {
                                  typeController.text = value ?? '';
                                }
                              });
                            },
                          ),
                          if (selectedType == 'Other') ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: typeController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "Cardio type",
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            "Duration (minutes):",
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: durationController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "30",
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Distance (km) - Optional:",
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: distanceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "5.0",
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Intensity (RPE/HR Zone) - Optional:",
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: intensityController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Zone 2 / RPE 6",
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Notes - Optional:",
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: notesController,
                            maxLines: 2,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Easy recovery run",
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final duration = int.tryParse(
                          durationController.text.trim(),
                        );
                        if (duration != null && duration > 0) {
                          final cardioType =
                              selectedType == 'Other'
                                  ? typeController.text.trim()
                                  : selectedType;
                          if (cardioType.isNotEmpty) {
                            final date = DateFormat(
                              'yyyy-MM-dd',
                            ).format(DateTime.now());
                            final distance = double.tryParse(
                              distanceController.text.trim(),
                            );
                            final intensity =
                                intensityController.text.trim().isEmpty
                                    ? null
                                    : intensityController.text.trim();
                            final notes =
                                notesController.text.trim().isEmpty
                                    ? null
                                    : notesController.text.trim();

                            final cardioEntry = CardioEntry(
                              id:
                                  DateTime.now().millisecondsSinceEpoch
                                      .toDouble() +
                                  Random().nextDouble(),
                              date: date,
                              type: cardioType,
                              duration: duration,
                              distance: distance,
                              intensity: intensity,
                              notes: notes,
                            );

                            setState(() {
                              _cardioHistory.add(cardioEntry);
                            });
                            _saveCardioHistory();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Cardio session logged!"),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Save"),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showMuscleGroupExercises(
    String muscleGroup,
    String weekStartDate,
    int sets,
    String status,
    Color statusColor,
  ) {
    final exercises = PeriodizationEngine.getExercisesForMuscleGroup(
      _history,
      muscleGroup,
      weekStartDate,
      _customMuscleGroupKeywords,
    );

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "$muscleGroup ($sets sets)",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child:
                  exercises.isEmpty
                      ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          "No exercises logged for this muscle group this week.",
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                      : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: statusColor,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Status: $status",
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Exercises contributing to this muscle group:",
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...exercises.entries.map((entry) {
                              final exerciseName = entry.key;
                              final setCount = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade700,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.fitness_center,
                                        size: 16,
                                        color: Colors.blue.shade300,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          exerciseName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade900
                                              .withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: Colors.blue.shade700,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          "$setCount set${setCount > 1 ? 's' : ''}",
                                          style: TextStyle(
                                            color: Colors.blue.shade300,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Close",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
    );
  }

  void _showDeloadWizard(List<String> plateaus) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text(
              "Schedule Deload Week?",
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              "Your progress has stalled on: ${plateaus.join(', ')}\n\n"
              "A deload week will:\n"
              "• Reduce volume by 50%\n"
              "• Reduce intensity by 10%\n"
              "• Help clear accumulated fatigue\n\n"
              "After the deload, we'll start a new mesocycle with fresh progression.",
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Deload week scheduled! Reduce volume by 50% and intensity by 10% next week.",
                      ),
                      duration: Duration(seconds: 4),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                ),
                child: const Text("Schedule Deload"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.fitness_center, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "Lift Lab",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B), // Slate 800
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF334155)),
            ), // Slate 700
          ),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: "Settings",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => MuscleGroupSettingsScreen(
                        customKeywords: _customMuscleGroupKeywords,
                        defaultKeywords: muscleGroupKeywords,
                        onKeywordsUpdated: (updatedKeywords) {
                          setState(() {
                            _customMuscleGroupKeywords = updatedKeywords;
                          });
                          _saveCustomMuscleGroupKeywords();
                        },
                      ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.fitness_center, color: Colors.white),
            tooltip: "Manage Programs",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => ProgramManagementScreen(
                        customPrograms: _customPrograms,
                        onProgramsUpdated: (updatedPrograms) {
                          setState(() {
                            _customPrograms = updatedPrograms;
                            // If current program was deleted, switch to first available
                            final allProgramsMap = {
                              ...allPrograms,
                              ..._customPrograms,
                            };
                            if (!allProgramsMap.containsKey(
                              _selectedProgramName,
                            )) {
                              _selectedProgramName = allProgramsMap.keys.first;
                              _selectedDay =
                                  allProgramsMap[_selectedProgramName]!
                                      .keys
                                      .first;
                            }
                          });
                          _saveCustomPrograms();
                          _saveProgramSelection();
                        },
                      ),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _activeTabIndex,
        children: [
          _buildLogger(),
          _buildProgress(),
          _buildHistory(),
          _buildAdvancedAnalytics(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _activeTabIndex,
        onTap: (idx) => setState(() => _activeTabIndex = idx),
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey.shade600,
        backgroundColor: const Color(0xFF1E293B),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: "LOG",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: "STATS"),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: "HISTORY",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: "ANALYTICS",
          ),
        ],
      ),
    );
  }
}

// --- Helper Components ---

class _ExerciseCard extends StatelessWidget {
  final String exerciseName;
  final int personalBest;
  final WorkoutEntry? lastWorkoutEntry;
  final List<Map<String, String>> sets;
  final Function(int index, String field, String value) onSetChanged;
  final Function(int index) onRemoveSet;
  final Function(String newExerciseName)? onSwapExercise;
  final VoidCallback? onRemoveExercise;
  final Function(String)? onShowProgression;
  final bool isSwapped;

  const _ExerciseCard({
    required Key key,
    required this.exerciseName,
    required this.personalBest,
    this.lastWorkoutEntry,
    required this.sets,
    required this.onSetChanged,
    required this.onRemoveSet,
    this.onSwapExercise,
    this.onRemoveExercise,
    this.onShowProgression,
    this.isSwapped = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade700),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A), // Slate 900
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          exerciseName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (isSwapped)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade900.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.orange.shade700,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            "Swapped",
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.orange.shade300,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (personalBest > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      "Best 1RM: $personalBest",
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                if (onSwapExercise != null)
                  IconButton(
                    icon: Icon(
                      Icons.swap_horiz,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                    onPressed: () => onSwapExercise!(exerciseName),
                    tooltip: "Swap Exercise",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (onRemoveExercise != null)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.red.shade400,
                    ),
                    onPressed: onRemoveExercise,
                    tooltip: "Remove Exercise",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          // Last workout info row
          if (lastWorkoutEntry != null)
            InkWell(
              onTap: () => onShowProgression?.call(exerciseName),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900.withValues(alpha: 0.2),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade800),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 14, color: Colors.blue.shade300),
                    const SizedBox(width: 6),
                    Text(
                      "Last: ${lastWorkoutEntry!.weight.toStringAsFixed(0)}kg x ${lastWorkoutEntry!.reps.toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade300,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "• ${_formatDate(lastWorkoutEntry!.date)}",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.blue.shade300,
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: List.generate(sets.length, (index) {
                final set = sets[index];
                final w = double.tryParse(set['weight'] ?? '') ?? 0;
                final r = double.tryParse(set['reps'] ?? '') ?? 0;
                final est1RM = calculate1RM(w, r);
                final isPR = est1RM > personalBest && personalBest > 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    decoration:
                        isPR
                            ? BoxDecoration(
                              color: Colors.yellow.shade900.withValues(
                                alpha: 0.3,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.yellow.shade700),
                            )
                            : null,
                    padding: isPR ? const EdgeInsets.all(4) : EdgeInsets.zero,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            "${index + 1}",
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: _CompactInput(
                            placeholder: "kg",
                            value: set['weight']!,
                            onChanged: (v) => onSetChanged(index, 'weight', v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _CompactInput(
                            placeholder: "Reps",
                            value: set['reps']!,
                            onChanged: (v) => onSetChanged(index, 'reps', v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _CompactInput(
                            placeholder: "RPE",
                            value: set['rpe']!,
                            onChanged: (v) => onSetChanged(index, 'rpe', v),
                            isBgColored: true,
                          ),
                        ),
                        if (sets.length > 1)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.grey.shade400,
                            ),
                            onPressed: () => onRemoveSet(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else
                          const SizedBox(width: 18),

                        SizedBox(
                          width: 24,
                          child:
                              isPR
                                  ? const Icon(
                                    Icons.emoji_events,
                                    size: 18,
                                    color: Colors.amber,
                                  )
                                  : null,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return "Today";
      } else if (difference.inDays == 1) {
        return "Yesterday";
      } else if (difference.inDays < 7) {
        return "${difference.inDays} days ago";
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return "$weeks ${weeks == 1 ? 'week' : 'weeks'} ago";
      } else {
        return DateFormat('MMM dd, yyyy').format(date);
      }
    } catch (e) {
      return dateStr; // Return original if parsing fails
    }
  }
}

// Widget to handle text input cleanly without losing focus
class _CompactInput extends StatefulWidget {
  final String value;
  final String placeholder;
  final Function(String) onChanged;
  final bool isBgColored;

  const _CompactInput({
    required this.value,
    required this.placeholder,
    required this.onChanged,
    this.isBgColored = false,
  });

  @override
  State<_CompactInput> createState() => _CompactInputState();
}

class _CompactInputState extends State<_CompactInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _CompactInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      // Only update if external value is different to avoid cursor jumps
      // Note: This logic assumes parent updates are driving this.
      // In this specific app structure, parent state update triggers rebuild.
      // We preserve cursor position if text is similar.
      _controller.value = _controller.value.copyWith(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: widget.onChanged,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: widget.placeholder,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        isDense: true,
        filled: widget.isBgColored,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
      ),
    );
  }
}

// Program Management Screen
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
                      style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
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
              programData: {},
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
                  // If name changed, remove old and add new
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

// Program Editor Screen
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
    // If new program, start with one day
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
      _exerciseTargetControllers[dayName] = {0: TextEditingController(text: '')};
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
      if (_exerciseControllers[dayName] == null) {
        _exerciseControllers[dayName] = {};
      }
      _exerciseControllers[dayName]![newIndex] = TextEditingController();

      if (_exerciseTargetControllers[dayName] == null) {
        _exerciseTargetControllers[dayName] = {};
      }
      _exerciseTargetControllers[dayName]![newIndex] = TextEditingController();
    });
  }

  void _deleteExercise(String dayName, int index) {
    setState(() {
      // Dispose all controllers for this day
      _exerciseControllers[dayName]?.values.forEach((c) => c.dispose());
      _exerciseTargetControllers[dayName]?.values.forEach((c) => c.dispose());

      // Remove exercise from data
      _programData[dayName]!.removeAt(index);

      // Rebuild controllers from remaining exercises
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

    // Build final program data
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
        title: Text(
          widget.programName.isEmpty ? "New Program" : "Edit Program",
        ),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveProgram),
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Program Name
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

          // Days
          ..._programData.keys.map((dayName) {
            return _buildDayCard(dayName);
          }),

          const SizedBox(height: 16),

          // Add Day Button
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
                              hintText: "Target (optional): e.g. 10-12, RPE 8, RIR 2",
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

// Muscle Group Settings Screen
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
    // Start with custom keywords if available, otherwise use defaults
    // Create a deep copy to avoid modifying unmodifiable lists
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
        // Ensure we have a modifiable list (create new list if needed)
        final currentList = _keywords[muscleGroup]!;
        _keywords[muscleGroup] = List<String>.from(currentList);
      }
      final newIndex = _keywords[muscleGroup]!.length;
      _keywords[muscleGroup]!.add('');
      if (_keywordControllers[muscleGroup] == null) {
        _keywordControllers[muscleGroup] = {};
      }
      _keywordControllers[muscleGroup]![newIndex] = TextEditingController();
    });
  }

  void _removeKeyword(String muscleGroup, int index) {
    setState(() {
      _keywordControllers[muscleGroup]?[index]?.dispose();
      _keywords[muscleGroup]!.removeAt(index);
      // Rebuild controllers
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
    // Build final keywords map from controllers
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

    // Check if it's different from defaults
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
                  // Dispose all controllers
                  for (final map in _keywordControllers.values) {
                    for (final c in map.values) {
                      c.dispose();
                    }
                  }
                  setState(() {
                    // Create deep copy to avoid unmodifiable list error
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
          ..._keywords.keys.map((muscleGroup) {
            return _buildMuscleGroupCard(muscleGroup);
          }),
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
