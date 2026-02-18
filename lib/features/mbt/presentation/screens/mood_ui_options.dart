import 'package:flutter/material.dart';

class MoodIconChoice {
  const MoodIconChoice({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class MoodColorChoice {
  const MoodColorChoice({required this.color, required this.label});

  final Color color;
  final String label;
}

const List<MoodIconChoice> moodIconChoices = <MoodIconChoice>[
  MoodIconChoice(
    icon: Icons.sentiment_very_satisfied_rounded,
    label: 'Very Happy',
  ),
  MoodIconChoice(icon: Icons.sentiment_satisfied_rounded, label: 'Happy'),
  MoodIconChoice(icon: Icons.sentiment_neutral_rounded, label: 'Neutral'),
  MoodIconChoice(icon: Icons.sentiment_dissatisfied_rounded, label: 'Sad'),
  MoodIconChoice(
    icon: Icons.sentiment_very_dissatisfied_rounded,
    label: 'Very Sad',
  ),
  MoodIconChoice(icon: Icons.psychology_alt_rounded, label: 'Reflective'),
  MoodIconChoice(icon: Icons.bolt_rounded, label: 'Energized'),
  MoodIconChoice(icon: Icons.spa_rounded, label: 'Calm'),
];

const List<MoodColorChoice> moodColorChoices = <MoodColorChoice>[
  MoodColorChoice(color: Color(0xFF2E7D32), label: 'Green'),
  MoodColorChoice(color: Color(0xFF1976D2), label: 'Blue'),
  MoodColorChoice(color: Color(0xFFEF6C00), label: 'Orange'),
  MoodColorChoice(color: Color(0xFFC2185B), label: 'Pink'),
  MoodColorChoice(color: Color(0xFFD32F2F), label: 'Red'),
  MoodColorChoice(color: Color(0xFF6A1B9A), label: 'Purple'),
  MoodColorChoice(color: Color(0xFF00897B), label: 'Teal'),
  MoodColorChoice(color: Color(0xFF546E7A), label: 'Slate'),
];
