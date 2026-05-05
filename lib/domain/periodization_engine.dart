import 'package:intl/intl.dart';

import '../data/muscle_group_keywords.dart';
import 'models.dart';

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

