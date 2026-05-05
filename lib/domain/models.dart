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
      weekNumber: weekNumberFromJson(json['weekNumber']),
    );
  }

  static int weekNumberFromJson(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
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

