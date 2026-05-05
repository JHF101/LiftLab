// Epley Formula
int calculate1RM(double? weight, double? reps) {
  if (weight == null || reps == null || weight == 0 || reps == 0) return 0;
  return (weight * (1 + reps / 30)).round();
}

