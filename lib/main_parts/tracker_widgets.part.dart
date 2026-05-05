part of '../main.dart';

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
                    // Keep padding/decoration structure stable when isPR toggles so
                    // layout does not jump and the keyboard/focus are not dropped.
                    decoration: BoxDecoration(
                      color:
                          isPR
                              ? Colors.yellow.shade900.withValues(alpha: 0.3)
                              : null,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color:
                            isPR
                                ? Colors.yellow.shade700
                                : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
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
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _CompactInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // While focused, the controller is authoritative — syncing from parent on
    // every setState would fight the IME and can drop focus on some devices.
    if (!_focusNode.hasFocus && widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
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

