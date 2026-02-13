import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/notifications/notification_hub.dart';
import '../../../../core/notifications/notifications.dart';
import '../../../../core/notifications/services/universal_notification_repository.dart';
import '../../../../core/services/reminder_manager.dart';
import '../../../../data/models/subtask.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/habit_category.dart';
import '../models/habit_reason.dart';
import '../models/temptation_log.dart';
import '../repositories/habit_category_repository.dart';
import '../repositories/habit_reason_repository.dart';
import '../repositories/habit_repository.dart';
import '../repositories/temptation_log_repository.dart';

/// Utility class for generating sample habit data for testing
class SampleHabitGenerator {
  final HabitRepository _repository;
  final HabitCategoryRepository _categoryRepository;
  final HabitReasonRepository _reasonRepository;
  final TemptationLogRepository _temptationLogRepository;
  final math.Random _random;

  SampleHabitGenerator(
    this._repository, {
    HabitCategoryRepository? categoryRepository,
    HabitReasonRepository? reasonRepository,
    TemptationLogRepository? temptationLogRepository,
    math.Random? random,
  }) : _categoryRepository = categoryRepository ?? HabitCategoryRepository(),
       _reasonRepository = reasonRepository ?? HabitReasonRepository(),
       _temptationLogRepository =
           temptationLogRepository ?? TemptationLogRepository(),
       _random = random ?? math.Random();

  /// Generate all sample habits at once
  Future<List<Habit>> generateAllSampleHabits({
    bool includeQuitHabits = true,
  }) async {
    final end = _sampleEndDate();
    final start = _sampleStartDate();
    final categories = await _ensureCategories(createdAt: start);
    final reasons = await _ensureReasons(createdAt: start);
    final notDoneReasonTexts = reasons.notDone.map((r) => r.text).toList();
    final slipReasons = reasons.slip;
    final temptationReasons = reasons.temptation;

    final existingHabits = await _repository.getAllHabits(
      includeArchived: true,
    );
    final existingTitles = existingHabits
        .map((h) => _normalize(h.title))
        .toSet();

    final habits = <Habit>[];
    var sortOrder = 0;

    final prayer = await _createYesNoHabit(
      title: 'Pray',
      description: 'Daily prayer and reflection',
      icon: Icons.self_improvement_rounded,
      color: const Color(0xFF10B981),
      categoryId: categories['Spiritual']?.id,
      startDate: start,
      endDate: end,
      frequencyType: 'daily',
      targetCount: 1,
      reminderMinutes: 330,
      habitTimeMinutes: 330,
      hasSpecificTime: true,
      motivation: 'Start the day with gratitude',
      tags: const ['Spiritual', 'Morning', 'Sample'],
      customYesPoints: 15,
      customNoPoints: -5,
      completionRate: 0.9,
      skipRate: 0.05,
      noRate: 0.03,
      completionStartHour: 5,
      completionEndHour: 7,
      skipReasons: _mergeReasonList(notDoneReasonTexts, const [
        'Overslept',
        'Morning rush',
      ]),
      sortOrder: sortOrder,
      existingTitles: existingTitles,
    );
    if (prayer != null) {
      habits.add(prayer);
      sortOrder++;
    }

    final fasting = await _createYesNoHabit(
      title: 'Fasting',
      description: 'Fast on Wednesdays and Fridays',
      icon: Icons.no_meals_rounded,
      color: const Color(0xFF6366F1),
      categoryId: categories['Spiritual']?.id,
      startDate: start,
      endDate: end,
      frequencyType: 'weekly',
      weekDays: const [3, 5],
      targetCount: 1,
      reminderMinutes: 300,
      hasSpecificTime: false,
      motivation: 'Discipline and spiritual focus',
      tags: const ['Spiritual', 'Discipline', 'Sample'],
      customYesPoints: 18,
      customNoPoints: -8,
      completionRate: 0.8,
      skipRate: 0.1,
      noRate: 0.05,
      completionStartHour: 18,
      completionEndHour: 21,
      skipReasons: _mergeReasonList(notDoneReasonTexts, const [
        'Medical reason',
        'Travel day',
      ]),
      sortOrder: sortOrder,
      existingTitles: existingTitles,
    );
    if (fasting != null) {
      habits.add(fasting);
      sortOrder++;
    }

    final bible = await _createNumericHabit(
      title: 'Read Bible',
      description: 'Read at least 2 pages',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF7C3AED),
      categoryId: categories['Spiritual']?.id,
      startDate: start,
      endDate: end,
      frequencyType: 'daily',
      targetCount: 1,
      targetValue: 2.0,
      unit: 'pages',
      pointCalculation: 'proportional',
      reminderMinutes: 1260,
      habitTimeMinutes: 1260,
      hasSpecificTime: true,
      motivation: 'Stay grounded in faith',
      tags: const ['Spiritual', 'Reading', 'Sample'],
      customYesPoints: 12,
      completionRate: 0.85,
      skipRate: 0.07,
      completionStartHour: 20,
      completionEndHour: 22,
      minValue: 1.0,
      maxValue: 5.0,
      skipReasons: _mergeReasonList(notDoneReasonTexts, const [
        'Fell asleep',
        'No quiet time',
      ]),
      sortOrder: sortOrder,
      existingTitles: existingTitles,
    );
    if (bible != null) {
      habits.add(bible);
      sortOrder++;
    }

    final book = await _createNumericHabit(
      title: 'Read Book',
      description: 'Read at least 10 pages',
      icon: Icons.book_rounded,
      color: const Color(0xFF3B82F6),
      categoryId: categories['Reading']?.id,
      startDate: start,
      endDate: end,
      frequencyType: 'daily',
      targetCount: 1,
      targetValue: 10.0,
      unit: 'pages',
      pointCalculation: 'proportional',
      reminderMinutes: 1320,
      habitTimeMinutes: 1320,
      hasSpecificTime: true,
      motivation: 'Grow through daily reading',
      tags: const ['Reading', 'Learning', 'Sample'],
      customYesPoints: 14,
      completionRate: 0.7,
      skipRate: 0.12,
      completionStartHour: 21,
      completionEndHour: 23,
      minValue: 6.0,
      maxValue: 22.0,
      skipReasons: _mergeReasonList(notDoneReasonTexts, const [
        'Long workday',
        'Eye strain',
      ]),
      sortOrder: sortOrder,
      existingTitles: existingTitles,
    );
    if (book != null) {
      habits.add(book);
      sortOrder++;
    }

    final water = await _createNumericHabit(
      title: 'Drink Water',
      description: 'Drink 2 liters of water',
      icon: Icons.water_drop_rounded,
      color: const Color(0xFF0EA5E9),
      categoryId: categories['Health']?.id,
      startDate: start,
      endDate: end,
      frequencyType: 'daily',
      targetCount: 1,
      targetValue: 2.0,
      unit: 'L',
      pointCalculation: 'proportional',
      reminderMinutes: 1200,
      hasSpecificTime: false,
      motivation: 'Stay hydrated and energized',
      tags: const ['Health', 'Hydration', 'Sample'],
      customYesPoints: 10,
      completionRate: 0.9,
      skipRate: 0.05,
      completionStartHour: 19,
      completionEndHour: 22,
      minValue: 1.2,
      maxValue: 2.6,
      skipReasons: _mergeReasonList(notDoneReasonTexts, const [
        'Forgot water bottle',
        'Out all day',
      ]),
      sortOrder: sortOrder,
      existingTitles: existingTitles,
    );
    if (water != null) {
      habits.add(water);
      sortOrder++;
    }

    final shower = await _createYesNoHabit(
      title: 'Take Shower',
      description: 'Shower at least 2 times per week',
      icon: Icons.shower_rounded,
      color: const Color(0xFF38BDF8),
      categoryId: categories['Hygiene']?.id,
      startDate: start,
      endDate: end,
      frequencyType: 'xTimesPerWeek',
      targetCount: 2,
      scheduleWeekDays: const [2, 6],
      motivation: 'Stay clean and refreshed',
      tags: const ['Hygiene', 'Self Care', 'Sample'],
      customYesPoints: 8,
      customNoPoints: -3,
      completionRate: 0.85,
      skipRate: 0.08,
      noRate: 0.03,
      completionStartHour: 7,
      completionEndHour: 9,
      skipReasons: _mergeReasonList(notDoneReasonTexts, const [
        'Late night',
        'Feeling sick',
      ]),
      sortOrder: sortOrder,
      existingTitles: existingTitles,
    );
    if (shower != null) {
      habits.add(shower);
      sortOrder++;
    }

    final hairOil = await _createYesNoHabit(
      title: 'Apply Hair Oil',
      description: 'Hair oil routine on scheduled days',
      icon: Icons.brush,
      color: const Color(0xFFF59E0B),
      categoryId: categories['Hair Care']?.id,
      startDate: start,
      endDate: end,
      frequencyType: 'weekly',
      weekDays: const [0, 1, 3, 5],
      targetCount: 1,
      motivation: 'Keep hair healthy and strong',
      tags: const ['Hair Care', 'Self Care', 'Sample'],
      customYesPoints: 10,
      customNoPoints: -4,
      completionRate: 0.8,
      skipRate: 0.1,
      noRate: 0.03,
      completionStartHour: 20,
      completionEndHour: 22,
      skipReasons: _mergeReasonList(notDoneReasonTexts, const [
        'Ran out of oil',
        'Washed hair late',
      ]),
      sortOrder: sortOrder,
      existingTitles: existingTitles,
    );
    if (hairOil != null) {
      habits.add(hairOil);
      sortOrder++;
    }

    final skinCare = await _createYesNoHabit(
      title: 'Face Skin Treatment',
      description: 'Skin care routine on Tue, Thu, Sat',
      icon: Icons.face_retouching_natural,
      color: const Color(0xFFF472B6),
      categoryId: categories['Skincare']?.id,
      startDate: start,
      endDate: end,
      frequencyType: 'weekly',
      weekDays: const [2, 4, 6],
      targetCount: 1,
      motivation: 'Healthy and clear skin',
      tags: const ['Skincare', 'Self Care', 'Sample'],
      customYesPoints: 10,
      customNoPoints: -4,
      completionRate: 0.78,
      skipRate: 0.1,
      noRate: 0.04,
      completionStartHour: 21,
      completionEndHour: 23,
      skipReasons: _mergeReasonList(notDoneReasonTexts, const [
        'Skin irritation',
        'No products',
      ]),
      sortOrder: sortOrder,
      existingTitles: existingTitles,
    );
    if (skinCare != null) {
      habits.add(skinCare);
      sortOrder++;
    }

    final gym = await _createTimerHabit(
      title: 'GYM',
      description: 'Workout 4 days per week',
      icon: Icons.fitness_center,
      color: const Color(0xFF22C55E),
      categoryId: categories['Fitness']?.id,
      startDate: start,
      endDate: end,
      frequencyType: 'xTimesPerWeek',
      targetCount: 4,
      scheduleWeekDays: const [1, 2, 4, 6],
      targetDurationMinutes: 60,
      timeUnit: 'hour',
      timerType: 'target',
      customYesPoints: 20,
      customNoPoints: -6,
      completionRate: 0.75,
      skipRate: 0.08,
      completionStartHour: 18,
      completionEndHour: 21,
      minDurationMinutes: 40,
      maxDurationMinutes: 95,
      skipReasons: _mergeReasonList(notDoneReasonTexts, const [
        'Muscle soreness',
        'Work overtime',
      ]),
      tags: const ['Fitness', 'Strength', 'Sample'],
      sortOrder: sortOrder,
      existingTitles: existingTitles,
    );
    if (gym != null) {
      habits.add(gym);
      sortOrder++;
    }

    final deepClean = await _createChecklistHabit(
      title: 'Deep Clean House',
      description: 'Deep clean every Sunday',
      icon: Icons.cleaning_services,
      color: const Color(0xFF6B7280),
      categoryId: categories['Home']?.id,
      startDate: start,
      endDate: end,
      frequencyType: 'weekly',
      weekDays: const [0],
      checklist: [
        Subtask(title: 'Vacuum floors'),
        Subtask(title: 'Mop floors'),
        Subtask(title: 'Dust surfaces'),
        Subtask(title: 'Clean bathroom'),
        Subtask(title: 'Wash bedding'),
        Subtask(title: 'Organize kitchen'),
      ],
      customYesPoints: 18,
      completionRate: 0.7,
      skipRate: 0.18,
      completionStartHour: 10,
      completionEndHour: 14,
      skipReasons: _mergeReasonList(notDoneReasonTexts, const [
        'Weekend trip',
        'Guests visiting',
      ]),
      tags: const ['Home', 'Cleaning', 'Sample'],
      sortOrder: sortOrder,
      existingTitles: existingTitles,
    );
    if (deepClean != null) {
      habits.add(deepClean);
      sortOrder++;
    }

    if (includeQuitHabits) {
      final junkFood = await _createQuitHabit(
        title: 'Stop Eating Junky Food',
        description: 'Avoid junk food and late-night snacks',
        icon: Icons.fastfood,
        color: const Color(0xFFF97316),
        categoryId: categories['Nutrition']?.id,
        startDate: start,
        endDate: end,
        quitActionName: 'Stop',
        quitSubstance: 'Junk Food',
        unit: 'snacks',
        dailyReward: 10,
        slipCalculation: 'perUnit',
        slipPenalty: -15,
        penaltyPerUnit: -5,
        costPerUnit: 4.5,
        streakProtection: 1,
        slipRate: 0.14,
        temptationRate: 0.25,
        unitsPerDay: 1,
        tags: const ['Quit', 'Nutrition', 'Sample'],
        slipReasons: slipReasons,
        temptationReasons: temptationReasons,
        sortOrder: sortOrder,
        existingTitles: existingTitles,
      );
      if (junkFood != null) {
        habits.add(junkFood);
        sortOrder++;
      }

      final soda = await _createQuitHabit(
        title: 'Stop Soda Drink',
        description: 'Avoid soda and sugary drinks',
        icon: Icons.local_drink,
        color: const Color(0xFF38BDF8),
        categoryId: categories['Nutrition']?.id,
        startDate: start,
        endDate: end,
        quitActionName: 'Stop',
        quitSubstance: 'Soda',
        unit: 'drinks',
        dailyReward: 10,
        slipCalculation: 'perUnit',
        slipPenalty: -12,
        penaltyPerUnit: -3,
        costPerUnit: 2.5,
        streakProtection: 1,
        slipRate: 0.1,
        temptationRate: 0.18,
        unitsPerDay: 1,
        tags: const ['Quit', 'Nutrition', 'Sample'],
        slipReasons: slipReasons,
        temptationReasons: temptationReasons,
        sortOrder: sortOrder,
        existingTitles: existingTitles,
      );
      if (soda != null) {
        habits.add(soda);
        sortOrder++;
      }

      final spending = await _createQuitHabit(
        title: 'Stop Unnecessary Spending',
        description: 'Avoid impulse and unplanned purchases',
        icon: Icons.account_balance_wallet,
        color: const Color(0xFF14B8A6),
        categoryId: categories['Finance']?.id,
        startDate: start,
        endDate: end,
        quitActionName: 'Stop',
        quitSubstance: 'Unnecessary Spending',
        unit: 'purchases',
        dailyReward: 12,
        slipCalculation: 'perUnit',
        slipPenalty: -18,
        penaltyPerUnit: -8,
        costPerUnit: 12.0,
        streakProtection: 1,
        slipRate: 0.07,
        temptationRate: 0.12,
        unitsPerDay: 1,
        tags: const ['Quit', 'Finance', 'Sample'],
        slipReasons: slipReasons,
        temptationReasons: temptationReasons,
        sortOrder: sortOrder,
        existingTitles: existingTitles,
      );
      if (spending != null) {
        habits.add(spending);
        sortOrder++;
      }

      final shameful = await _createQuitHabit(
        title: 'Stop Being Shameful',
        description: 'Replace shameful reactions with confidence',
        icon: Icons.psychology,
        color: const Color(0xFF8B5CF6),
        categoryId: categories['Mindset']?.id,
        startDate: start,
        endDate: end,
        quitActionName: 'Stop',
        quitSubstance: 'Shameful Behavior',
        unit: 'incidents',
        dailyReward: 11,
        slipCalculation: 'fixed',
        slipPenalty: -12,
        streakProtection: 2,
        slipRate: 0.05,
        temptationRate: 0.1,
        unitsPerDay: 1,
        tags: const ['Quit', 'Mindset', 'Sample'],
        slipReasons: slipReasons,
        temptationReasons: temptationReasons,
        sortOrder: sortOrder,
        existingTitles: existingTitles,
      );
      if (shameful != null) {
        habits.add(shameful);
        sortOrder++;
      }

      final procrastinating = await _createQuitHabit(
        title: 'Stop Procrastinating',
        description: 'Reduce delays and start tasks sooner',
        icon: Icons.event_note,
        color: const Color(0xFF3B82F6),
        categoryId: categories['Productivity']?.id,
        startDate: start,
        endDate: end,
        quitActionName: 'Stop',
        quitSubstance: 'Procrastination',
        unit: 'episodes',
        dailyReward: 11,
        slipCalculation: 'fixed',
        slipPenalty: -10,
        streakProtection: 1,
        slipRate: 0.12,
        temptationRate: 0.2,
        unitsPerDay: 1,
        tags: const ['Quit', 'Productivity', 'Sample'],
        slipReasons: slipReasons,
        temptationReasons: temptationReasons,
        sortOrder: sortOrder,
        existingTitles: existingTitles,
      );
      if (procrastinating != null) {
        habits.add(procrastinating);
        sortOrder++;
      }

      final scrolling = await _createQuitHabit(
        title: 'Stop Scrolling',
        description: 'Reduce unnecessary phone scrolling',
        icon: Icons.phone_android,
        color: const Color(0xFF64748B),
        categoryId: categories['Digital Wellness']?.id,
        startDate: start,
        endDate: end,
        quitActionName: 'Stop',
        quitSubstance: 'Scrolling',
        unit: 'sessions',
        dailyReward: 10,
        slipCalculation: 'perUnit',
        slipPenalty: -8,
        penaltyPerUnit: -2,
        costPerUnit: 0.0,
        streakProtection: 1,
        slipRate: 0.18,
        temptationRate: 0.3,
        unitsPerDay: 1,
        tags: const ['Quit', 'Digital', 'Sample'],
        slipReasons: slipReasons,
        temptationReasons: temptationReasons,
        sortOrder: sortOrder,
        existingTitles: existingTitles,
      );
      if (scrolling != null) {
        habits.add(scrolling);
        sortOrder++;
      }
    }

    return habits;
  }

  /// Generate quit-only sample habits with realistic history for the last 60 days.
  ///
  /// This is useful for testing the quit-habit journey end-to-end:
  /// slips, temptation triggers, resisted urges, and score trends.
  Future<List<Habit>> generateQuitHabitSampleData() async {
    final end = _sampleEndDate();
    final start = _sampleStartDate();
    final categories = await _ensureCategories(createdAt: start);
    final reasons = await _ensureReasons(createdAt: start);

    final existingHabits = await _repository.getAllHabits(
      includeArchived: true,
    );
    final existingTitles = existingHabits
        .map((h) => _normalize(h.title))
        .toSet();
    var sortOrder = existingHabits.isEmpty
        ? 0
        : existingHabits
                  .map((h) => h.sortOrder)
                  .reduce((a, b) => a > b ? a : b) +
              1;

    final habits = <Habit>[];

    final seeds = <_QuitHabitSeed>[
      const _QuitHabitSeed(
        title: 'Quit Junk Food',
        description: 'Cut junk meals, snacks, and late-night fast food.',
        icon: Icons.fastfood,
        color: Color(0xFFF97316),
        category: 'Nutrition',
        quitSubstance: 'Junk Food',
        unit: 'meals',
        dailyReward: 12,
        slipCalculation: 'perUnit',
        slipPenalty: -16,
        penaltyPerUnit: -6,
        costPerUnit: 8.0,
        streakProtection: 1,
        slipRate: 0.18,
        temptationRate: 0.34,
        unitsPerDay: 1,
        tags: ['Quit', 'Nutrition', 'Sample'],
        slipReasonTexts: [
          'Craving',
          'Late night',
          'Stress',
          'Rewarding myself',
          'Craving junk food',
        ],
        temptationReasonTexts: [
          'Fast food delivery ad',
          'Weekend treat',
          'Saw it nearby',
          'Habit cue',
        ],
      ),
      const _QuitHabitSeed(
        title: 'Quit Soda',
        description: 'Replace soda with water or unsweetened drinks.',
        icon: Icons.local_drink,
        color: Color(0xFF38BDF8),
        category: 'Nutrition',
        quitSubstance: 'Soda',
        unit: 'cans',
        dailyReward: 11,
        slipCalculation: 'perUnit',
        slipPenalty: -14,
        penaltyPerUnit: -4,
        costPerUnit: 2.5,
        streakProtection: 1,
        slipRate: 0.14,
        temptationRate: 0.29,
        unitsPerDay: 1,
        tags: ['Quit', 'Nutrition', 'Sample'],
        slipReasonTexts: ['Craving', 'Social event', 'Late night', 'Stress'],
        temptationReasonTexts: [
          'Friends drinking soda',
          'Social pressure',
          'Work break',
          'Saw it nearby',
        ],
      ),
      const _QuitHabitSeed(
        title: 'Quit Bad Gossip',
        description: 'Avoid negative talk and rumor-sharing in conversations.',
        icon: Icons.forum_outlined,
        color: Color(0xFF8B5CF6),
        category: 'Mindset',
        quitSubstance: 'Bad Gossip',
        unit: 'incidents',
        dailyReward: 13,
        slipCalculation: 'fixed',
        slipPenalty: -13,
        streakProtection: 2,
        slipRate: 0.11,
        temptationRate: 0.24,
        unitsPerDay: 1,
        tags: ['Quit', 'Mindset', 'Sample'],
        slipReasonTexts: [
          'Peer pressure',
          'Social event',
          'Gossip circle at work',
          'Boredom',
        ],
        temptationReasonTexts: [
          'Group chat gossip',
          'Social pressure',
          'Work break',
          'Habit cue',
        ],
      ),
      const _QuitHabitSeed(
        title: 'Quit Overspending',
        description: 'Stop impulse purchases and emotional shopping.',
        icon: Icons.account_balance_wallet_outlined,
        color: Color(0xFF14B8A6),
        category: 'Finance',
        quitSubstance: 'Overspending',
        unit: 'purchases',
        dailyReward: 14,
        slipCalculation: 'perUnit',
        slipPenalty: -20,
        penaltyPerUnit: -10,
        costPerUnit: 20.0,
        streakProtection: 1,
        slipRate: 0.08,
        temptationRate: 0.21,
        unitsPerDay: 1,
        tags: ['Quit', 'Finance', 'Sample'],
        slipReasonTexts: [
          'Impulse buy',
          'Rewarding myself',
          'Flash sale impulse',
          'Stress',
        ],
        temptationReasonTexts: [
          'Limited-time discount',
          'Flash sale notification',
          'Emotional day',
          'Just one more',
        ],
      ),
      const _QuitHabitSeed(
        title: 'Quit Doom Scrolling',
        description: 'Reduce endless social feeds and short-video loops.',
        icon: Icons.phone_android,
        color: Color(0xFF64748B),
        category: 'Digital Wellness',
        quitSubstance: 'Doom Scrolling',
        unit: 'sessions',
        dailyReward: 10,
        slipCalculation: 'perUnit',
        slipPenalty: -10,
        penaltyPerUnit: -3,
        streakProtection: 1,
        slipRate: 0.2,
        temptationRate: 0.38,
        unitsPerDay: 1,
        tags: ['Quit', 'Digital', 'Sample'],
        slipReasonTexts: [
          'Boredom',
          'Late night',
          'Doom-scroll spiral',
          'Stress',
        ],
        temptationReasonTexts: [
          'Picked up phone mindlessly',
          'Habit cue',
          'Work break',
          'Just one more',
        ],
      ),
      const _QuitHabitSeed(
        title: 'Quit People Pleasing',
        description: 'Practice boundaries and stop saying yes to everything.',
        icon: Icons.handshake_outlined,
        color: Color(0xFF3B82F6),
        category: 'Mindset',
        quitSubstance: 'People Pleasing',
        unit: 'incidents',
        dailyReward: 12,
        slipCalculation: 'fixed',
        slipPenalty: -12,
        streakProtection: 2,
        slipRate: 0.09,
        temptationRate: 0.22,
        unitsPerDay: 1,
        tags: ['Quit', 'Mindset', 'Sample'],
        slipReasonTexts: [
          'People-pleasing pressure',
          'Peer pressure',
          'Social event',
          'Stress',
        ],
        temptationReasonTexts: [
          'Fear of disappointing others',
          'Social pressure',
          'Emotional day',
          'Habit cue',
        ],
      ),
      const _QuitHabitSeed(
        title: 'Quit Shame Spiral',
        description:
            'Break self-shaming thoughts and recover faster after slips.',
        icon: Icons.psychology_alt_outlined,
        color: Color(0xFFEF4444),
        category: 'Mindset',
        quitSubstance: 'Shame Spiral',
        unit: 'episodes',
        dailyReward: 13,
        slipCalculation: 'fixed',
        slipPenalty: -14,
        streakProtection: 2,
        slipRate: 0.07,
        temptationRate: 0.19,
        unitsPerDay: 1,
        tags: ['Quit', 'Mindset', 'Sample'],
        slipReasonTexts: ['Harsh self-talk', 'Stress', 'Late night'],
        temptationReasonTexts: [
          'Shame trigger moment',
          'Feeling anxious',
          'Emotional day',
          'Habit cue',
        ],
      ),
    ];

    for (final seed in seeds) {
      final habit = await _createQuitHabit(
        title: seed.title,
        description: seed.description,
        icon: seed.icon,
        color: seed.color,
        categoryId: categories[seed.category]?.id,
        startDate: start,
        endDate: end,
        quitActionName: 'Quit',
        quitSubstance: seed.quitSubstance,
        unit: seed.unit,
        dailyReward: seed.dailyReward,
        slipCalculation: seed.slipCalculation,
        slipPenalty: seed.slipPenalty,
        penaltyPerUnit: seed.penaltyPerUnit,
        costPerUnit: seed.costPerUnit,
        streakProtection: seed.streakProtection,
        slipRate: seed.slipRate,
        temptationRate: seed.temptationRate,
        unitsPerDay: seed.unitsPerDay,
        tags: seed.tags,
        slipReasons: _selectReasonSubset(reasons.slip, seed.slipReasonTexts),
        temptationReasons: _selectReasonSubset(
          reasons.temptation,
          seed.temptationReasonTexts,
        ),
        sortOrder: sortOrder,
        existingTitles: existingTitles,
      );
      if (habit != null) {
        habits.add(habit);
        sortOrder++;
      }
    }

    return habits;
  }

  /// Delete all sample habits (for cleanup)
  Future<void> deleteSampleHabits() async {
    final allHabits = await _repository.getAllHabits(includeArchived: true);
    final sampleTitles = <String>{
      'Pray',
      'Fasting',
      'Read Bible',
      'Read Book',
      'Drink Water',
      'Take Shower',
      'Apply Hair Oil',
      'Face Skin Treatment',
      'GYM',
      'Deep Clean House',
      'Stop Eating Junky Food',
      'Stop Soda Drink',
      'Stop Unnecessary Spending',
      'Stop Being Shameful',
      'Stop Procrastinating',
      'Stop Scrolling',
      'Quit Junk Food',
      'Quit Soda',
      'Quit Bad Gossip',
      'Quit Overspending',
      'Quit Doom Scrolling',
      'Quit People Pleasing',
      'Quit Shame Spiral',
      'Morning Prayer',
      'Deep Work Session',
      'Hydration',
      'Morning Routine',
    };

    for (final habit in allHabits) {
      if (sampleTitles.contains(habit.title)) {
        await _temptationLogRepository.deleteLogsForHabit(habit.id);
        await ReminderManager().cancelRemindersForHabit(habit.id);
        await NotificationHub().cancelForEntity(
          moduleId: NotificationHubModuleIds.habit,
          entityId: habit.id,
        );
        await UniversalNotificationRepository().deleteByEntity(habit.id);
        await _repository.deleteHabit(habit.id);
      }
    }
  }

  Future<Habit?> _createYesNoHabit({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String? categoryId,
    required DateTime startDate,
    required DateTime endDate,
    required String frequencyType,
    List<int>? weekDays,
    int targetCount = 1,
    List<int>? scheduleWeekDays,
    int? reminderMinutes,
    int? habitTimeMinutes,
    bool hasSpecificTime = false,
    String? motivation,
    String? notes,
    List<String> tags = const [],
    int? customYesPoints,
    int? customNoPoints,
    required double completionRate,
    required double skipRate,
    double noRate = 0.03,
    required int completionStartHour,
    required int completionEndHour,
    required List<String> skipReasons,
    required int sortOrder,
    required Set<String> existingTitles,
  }) async {
    if (!_reserveTitle(title, existingTitles)) return null;

    final habit = Habit(
      title: title,
      description: description,
      iconCodePoint: icon.codePoint,
      colorValue: color.value,
      categoryId: categoryId,
      frequencyType: frequencyType,
      weekDays: weekDays,
      targetCount: targetCount,
      reminderEnabled: reminderMinutes != null,
      reminderMinutes: reminderMinutes,
      notes: notes,
      isGoodHabit: true,
      isArchived: false,
      startDate: startDate,
      createdAt: startDate,
      completionType: 'yesNo',
      customYesPoints: customYesPoints,
      customNoPoints: customNoPoints,
      habitStatus: 'active',
      motivation: motivation,
      hasSpecificTime: hasSpecificTime,
      habitTimeMinutes: habitTimeMinutes,
      tags: _mergeTags(tags),
      sortOrder: sortOrder,
    );

    final isDue = _buildIsDuePredicate(
      frequencyType,
      weekDays,
      scheduleWeekDays,
    );
    final completions = _generateYesNoHistory(
      habit: habit,
      startDate: startDate,
      endDate: endDate,
      isDue: isDue,
      completionRate: completionRate,
      skipRate: skipRate,
      noRate: noRate,
      completionStartHour: completionStartHour,
      completionEndHour: completionEndHour,
      skipReasons: skipReasons,
    );
    final points = _sumPoints(completions);
    return _persistHabitWithCompletions(
      habit,
      completions,
      pointsEarned: points,
    );
  }

  Future<Habit?> _createNumericHabit({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String? categoryId,
    required DateTime startDate,
    required DateTime endDate,
    required String frequencyType,
    List<int>? weekDays,
    int targetCount = 1,
    List<int>? scheduleWeekDays,
    required double targetValue,
    required String unit,
    required String pointCalculation,
    int? reminderMinutes,
    int? habitTimeMinutes,
    bool hasSpecificTime = false,
    String? motivation,
    String? notes,
    List<String> tags = const [],
    int? customYesPoints,
    required double completionRate,
    required double skipRate,
    required int completionStartHour,
    required int completionEndHour,
    required double minValue,
    required double maxValue,
    required List<String> skipReasons,
    required int sortOrder,
    required Set<String> existingTitles,
  }) async {
    if (!_reserveTitle(title, existingTitles)) return null;

    final habit = Habit(
      title: title,
      description: description,
      iconCodePoint: icon.codePoint,
      colorValue: color.value,
      categoryId: categoryId,
      frequencyType: frequencyType,
      weekDays: weekDays,
      targetCount: targetCount,
      completionType: 'numeric',
      targetValue: targetValue,
      unit: unit,
      pointCalculation: pointCalculation,
      customYesPoints: customYesPoints,
      reminderEnabled: reminderMinutes != null,
      reminderMinutes: reminderMinutes,
      notes: notes,
      isGoodHabit: true,
      isArchived: false,
      startDate: startDate,
      createdAt: startDate,
      habitStatus: 'active',
      motivation: motivation,
      hasSpecificTime: hasSpecificTime,
      habitTimeMinutes: habitTimeMinutes,
      tags: _mergeTags(tags),
      sortOrder: sortOrder,
    );

    final isDue = _buildIsDuePredicate(
      frequencyType,
      weekDays,
      scheduleWeekDays,
    );
    final completions = _generateNumericHistory(
      habit: habit,
      startDate: startDate,
      endDate: endDate,
      isDue: isDue,
      completionRate: completionRate,
      skipRate: skipRate,
      completionStartHour: completionStartHour,
      completionEndHour: completionEndHour,
      minValue: minValue,
      maxValue: maxValue,
      skipReasons: skipReasons,
    );
    final points = _sumPoints(completions);
    return _persistHabitWithCompletions(
      habit,
      completions,
      pointsEarned: points,
    );
  }

  Future<Habit?> _createTimerHabit({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String? categoryId,
    required DateTime startDate,
    required DateTime endDate,
    required String frequencyType,
    List<int>? weekDays,
    int targetCount = 1,
    List<int>? scheduleWeekDays,
    required int targetDurationMinutes,
    String? timerType,
    String? timeUnit,
    int? customYesPoints,
    int? customNoPoints,
    required double completionRate,
    required double skipRate,
    required int completionStartHour,
    required int completionEndHour,
    required int minDurationMinutes,
    required int maxDurationMinutes,
    required List<String> skipReasons,
    List<String> tags = const [],
    String? motivation,
    String? notes,
    int? reminderMinutes,
    int? habitTimeMinutes,
    bool hasSpecificTime = false,
    required int sortOrder,
    required Set<String> existingTitles,
  }) async {
    if (!_reserveTitle(title, existingTitles)) return null;

    final habit = Habit(
      title: title,
      description: description,
      iconCodePoint: icon.codePoint,
      colorValue: color.value,
      categoryId: categoryId,
      frequencyType: frequencyType,
      weekDays: weekDays,
      targetCount: targetCount,
      completionType: 'timer',
      targetDurationMinutes: targetDurationMinutes,
      timerType: timerType,
      timeUnit: timeUnit,
      customYesPoints: customYesPoints,
      customNoPoints: customNoPoints,
      allowOvertimeBonus: true,
      bonusPerMinute: 0.1,
      reminderEnabled: reminderMinutes != null,
      reminderMinutes: reminderMinutes,
      notes: notes,
      isGoodHabit: true,
      isArchived: false,
      startDate: startDate,
      createdAt: startDate,
      habitStatus: 'active',
      motivation: motivation,
      hasSpecificTime: hasSpecificTime,
      habitTimeMinutes: habitTimeMinutes,
      tags: _mergeTags(tags),
      sortOrder: sortOrder,
    );

    final isDue = _buildIsDuePredicate(
      frequencyType,
      weekDays,
      scheduleWeekDays,
    );
    final completions = _generateTimerHistory(
      habit: habit,
      startDate: startDate,
      endDate: endDate,
      isDue: isDue,
      completionRate: completionRate,
      skipRate: skipRate,
      completionStartHour: completionStartHour,
      completionEndHour: completionEndHour,
      minDurationMinutes: minDurationMinutes,
      maxDurationMinutes: maxDurationMinutes,
      skipReasons: skipReasons,
    );
    final points = _sumPoints(completions);
    return _persistHabitWithCompletions(
      habit,
      completions,
      pointsEarned: points,
    );
  }

  Future<Habit?> _createChecklistHabit({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String? categoryId,
    required DateTime startDate,
    required DateTime endDate,
    required String frequencyType,
    List<int>? weekDays,
    int targetCount = 1,
    required List<Subtask> checklist,
    int? customYesPoints,
    required double completionRate,
    required double skipRate,
    required int completionStartHour,
    required int completionEndHour,
    required List<String> skipReasons,
    List<String> tags = const [],
    String? motivation,
    String? notes,
    int? reminderMinutes,
    int? habitTimeMinutes,
    bool hasSpecificTime = false,
    required int sortOrder,
    required Set<String> existingTitles,
  }) async {
    if (!_reserveTitle(title, existingTitles)) return null;

    final habit = Habit(
      title: title,
      description: description,
      iconCodePoint: icon.codePoint,
      colorValue: color.value,
      categoryId: categoryId,
      frequencyType: frequencyType,
      weekDays: weekDays,
      targetCount: targetCount,
      completionType: 'checklist',
      checklist: checklist,
      customYesPoints: customYesPoints,
      reminderEnabled: reminderMinutes != null,
      reminderMinutes: reminderMinutes,
      notes: notes,
      isGoodHabit: true,
      isArchived: false,
      startDate: startDate,
      createdAt: startDate,
      habitStatus: 'active',
      motivation: motivation,
      hasSpecificTime: hasSpecificTime,
      habitTimeMinutes: habitTimeMinutes,
      tags: _mergeTags(tags),
      sortOrder: sortOrder,
    );

    final isDue = _buildIsDuePredicate(frequencyType, weekDays, null);
    final completions = _generateChecklistHistory(
      habit: habit,
      startDate: startDate,
      endDate: endDate,
      isDue: isDue,
      completionRate: completionRate,
      skipRate: skipRate,
      completionStartHour: completionStartHour,
      completionEndHour: completionEndHour,
      skipReasons: skipReasons,
    );
    final points = _sumPoints(completions);
    return _persistHabitWithCompletions(
      habit,
      completions,
      pointsEarned: points,
    );
  }

  Future<Habit?> _createQuitHabit({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String? categoryId,
    required DateTime startDate,
    required DateTime endDate,
    required String quitActionName,
    required String quitSubstance,
    required String unit,
    required int dailyReward,
    required String slipCalculation,
    required int slipPenalty,
    int? penaltyPerUnit,
    double? costPerUnit,
    int streakProtection = 1,
    required double slipRate,
    required double temptationRate,
    int unitsPerDay = 1,
    List<String> tags = const [],
    required List<HabitReason> slipReasons,
    required List<HabitReason> temptationReasons,
    required int sortOrder,
    required Set<String> existingTitles,
  }) async {
    if (!_reserveTitle(title, existingTitles)) return null;

    final habit = Habit(
      title: title,
      description: description,
      iconCodePoint: icon.codePoint,
      colorValue: color.value,
      categoryId: categoryId,
      frequencyType: 'daily',
      targetCount: 1,
      completionType: 'quit',
      isGoodHabit: false,
      dailyReward: dailyReward,
      slipPenalty: slipPenalty,
      slipCalculation: slipCalculation,
      penaltyPerUnit: penaltyPerUnit,
      streakProtection: streakProtection,
      costPerUnit: costPerUnit,
      costTrackingEnabled: (costPerUnit ?? 0) > 0,
      currencySymbol: (costPerUnit ?? 0) > 0 ? '\$' : null,
      enableTemptationTracking: true,
      quitHabitActive: true,
      quitActionName: quitActionName,
      quitSubstance: quitSubstance,
      unit: unit,
      customYesPoints: dailyReward,
      startDate: startDate,
      createdAt: startDate,
      habitStatus: 'active',
      tags: _mergeTags(tags),
      sortOrder: sortOrder,
    );

    final slipCompletions = _generateQuitSlipHistory(
      habit: habit,
      startDate: startDate,
      endDate: endDate,
      slipRate: slipRate,
      slipReasons: slipReasons,
    );
    final slipPoints = _sumPoints(slipCompletions);
    final slipDays = slipCompletions.length;
    final totalDays = endDate.difference(startDate).inDays + 1;
    final unitsAvoided = math.max(0, (totalDays - slipDays) * unitsPerDay);
    final moneySaved = (costPerUnit ?? 0) * unitsAvoided;

    final stored = await _persistHabitWithCompletions(
      habit,
      slipCompletions,
      pointsEarned: slipPoints,
      currentSlipCount: slipDays,
      moneySaved: moneySaved,
      unitsAvoided: unitsAvoided,
    );

    final slipDates = slipCompletions
        .map((c) => _dateOnly(c.completedDate))
        .toSet();
    final temptationLogs = _generateTemptationLogs(
      habitId: stored.id,
      startDate: startDate,
      endDate: endDate,
      slipDates: slipDates,
      temptationReasons: temptationReasons,
      temptationRate: temptationRate,
    );
    for (final log in temptationLogs) {
      await _temptationLogRepository.createLog(log);
    }

    return stored;
  }

  Future<Habit> _persistHabitWithCompletions(
    Habit habit,
    List<HabitCompletion> completions, {
    int? pointsEarned,
    int? currentSlipCount,
    double? moneySaved,
    int? unitsAvoided,
  }) async {
    await _repository.createHabit(habit);
    if (completions.isNotEmpty) {
      await _repository.addCompletionsBulk(completions);
    }
    final stored = await _repository.getHabitById(habit.id);
    if (stored == null) return habit;

    final updated = stored.copyWith(
      pointsEarned: pointsEarned ?? stored.pointsEarned,
      currentSlipCount: currentSlipCount ?? stored.currentSlipCount,
      moneySaved: moneySaved ?? stored.moneySaved,
      unitsAvoided: unitsAvoided ?? stored.unitsAvoided,
    );
    await _repository.updateHabit(updated);
    return updated;
  }

  List<HabitCompletion> _generateYesNoHistory({
    required Habit habit,
    required DateTime startDate,
    required DateTime endDate,
    required bool Function(DateTime date) isDue,
    required double completionRate,
    required double skipRate,
    required double noRate,
    required int completionStartHour,
    required int completionEndHour,
    required List<String> skipReasons,
  }) {
    final completions = <HabitCompletion>[];
    for (final date in _daysBetween(startDate, endDate)) {
      if (!isDue(date)) continue;
      final roll = _random.nextDouble();
      if (roll < completionRate) {
        completions.add(
          HabitCompletion(
            habitId: habit.id,
            completedDate: _dateOnly(date),
            completedAt: _randomTime(
              date,
              completionStartHour,
              completionEndHour,
            ),
            count: 1,
            answer: true,
            pointsEarned: habit.customYesPoints ?? 10,
          ),
        );
      } else if (roll < completionRate + skipRate) {
        completions.add(
          HabitCompletion(
            habitId: habit.id,
            completedDate: _dateOnly(date),
            completedAt: _randomTime(
              date,
              completionStartHour,
              completionEndHour,
            ),
            count: 0,
            isSkipped: true,
            skipReason: _pick(skipReasons),
            pointsEarned: 0,
          ),
        );
      } else if (roll < completionRate + skipRate + noRate) {
        completions.add(
          HabitCompletion(
            habitId: habit.id,
            completedDate: _dateOnly(date),
            completedAt: _randomTime(
              date,
              completionStartHour,
              completionEndHour,
            ),
            count: 0,
            answer: false,
            pointsEarned: habit.customNoPoints ?? -5,
          ),
        );
      }
    }
    return completions;
  }

  List<HabitCompletion> _generateNumericHistory({
    required Habit habit,
    required DateTime startDate,
    required DateTime endDate,
    required bool Function(DateTime date) isDue,
    required double completionRate,
    required double skipRate,
    required int completionStartHour,
    required int completionEndHour,
    required double minValue,
    required double maxValue,
    required List<String> skipReasons,
  }) {
    final completions = <HabitCompletion>[];
    final basePoints = habit.customYesPoints ?? 10;
    final target = habit.targetValue ?? maxValue;

    for (final date in _daysBetween(startDate, endDate)) {
      if (!isDue(date)) continue;
      final roll = _random.nextDouble();
      if (roll < completionRate) {
        final value = _randomDouble(minValue, maxValue);
        final rawRatio = target > 0 ? value / target : 1.0;
        final ratio = rawRatio.clamp(0.0, 1.4);
        final points = (basePoints * ratio).round();
        completions.add(
          HabitCompletion(
            habitId: habit.id,
            completedDate: _dateOnly(date),
            completedAt: _randomTime(
              date,
              completionStartHour,
              completionEndHour,
            ),
            count: 1,
            actualValue: value,
            pointsEarned: points,
          ),
        );
      } else if (roll < completionRate + skipRate) {
        completions.add(
          HabitCompletion(
            habitId: habit.id,
            completedDate: _dateOnly(date),
            completedAt: _randomTime(
              date,
              completionStartHour,
              completionEndHour,
            ),
            count: 0,
            isSkipped: true,
            skipReason: _pick(skipReasons),
            pointsEarned: 0,
          ),
        );
      }
    }
    return completions;
  }

  List<HabitCompletion> _generateTimerHistory({
    required Habit habit,
    required DateTime startDate,
    required DateTime endDate,
    required bool Function(DateTime date) isDue,
    required double completionRate,
    required double skipRate,
    required int completionStartHour,
    required int completionEndHour,
    required int minDurationMinutes,
    required int maxDurationMinutes,
    required List<String> skipReasons,
  }) {
    final completions = <HabitCompletion>[];
    for (final date in _daysBetween(startDate, endDate)) {
      if (!isDue(date)) continue;
      final roll = _random.nextDouble();
      if (roll < completionRate) {
        final duration = _randomInt(minDurationMinutes, maxDurationMinutes);
        final points = habit.calculateTimerPoints(duration).round();
        completions.add(
          HabitCompletion(
            habitId: habit.id,
            completedDate: _dateOnly(date),
            completedAt: _randomTime(
              date,
              completionStartHour,
              completionEndHour,
            ),
            count: 1,
            actualDurationMinutes: duration,
            pointsEarned: points,
          ),
        );
      } else if (roll < completionRate + skipRate) {
        completions.add(
          HabitCompletion(
            habitId: habit.id,
            completedDate: _dateOnly(date),
            completedAt: _randomTime(
              date,
              completionStartHour,
              completionEndHour,
            ),
            count: 0,
            isSkipped: true,
            skipReason: _pick(skipReasons),
            pointsEarned: 0,
          ),
        );
      }
    }
    return completions;
  }

  List<HabitCompletion> _generateChecklistHistory({
    required Habit habit,
    required DateTime startDate,
    required DateTime endDate,
    required bool Function(DateTime date) isDue,
    required double completionRate,
    required double skipRate,
    required int completionStartHour,
    required int completionEndHour,
    required List<String> skipReasons,
  }) {
    final completions = <HabitCompletion>[];
    final basePoints = habit.customYesPoints ?? 10;
    for (final date in _daysBetween(startDate, endDate)) {
      if (!isDue(date)) continue;
      final roll = _random.nextDouble();
      if (roll < completionRate) {
        completions.add(
          HabitCompletion(
            habitId: habit.id,
            completedDate: _dateOnly(date),
            completedAt: _randomTime(
              date,
              completionStartHour,
              completionEndHour,
            ),
            count: 1,
            answer: true,
            pointsEarned: basePoints,
          ),
        );
      } else if (roll < completionRate + skipRate) {
        completions.add(
          HabitCompletion(
            habitId: habit.id,
            completedDate: _dateOnly(date),
            completedAt: _randomTime(
              date,
              completionStartHour,
              completionEndHour,
            ),
            count: 0,
            isSkipped: true,
            skipReason: _pick(skipReasons),
            pointsEarned: 0,
          ),
        );
      }
    }
    return completions;
  }

  List<HabitCompletion> _generateQuitSlipHistory({
    required Habit habit,
    required DateTime startDate,
    required DateTime endDate,
    required double slipRate,
    required List<HabitReason> slipReasons,
  }) {
    final completions = <HabitCompletion>[];
    for (final date in _daysBetween(startDate, endDate)) {
      if (_random.nextDouble() >= slipRate) continue;
      final slipAmount = habit.slipCalculation == 'perUnit'
          ? _randomInt(1, 3)
          : 1;
      final penalty = habit.slipCalculation == 'perUnit'
          ? (habit.penaltyPerUnit ?? -3) * slipAmount
          : (habit.slipPenalty ?? -12);
      completions.add(
        HabitCompletion(
          habitId: habit.id,
          completedDate: _dateOnly(date),
          completedAt: _randomTime(date, 12, 22),
          count: slipAmount,
          isSkipped: true,
          skipReason: _pick(slipReasons).text,
          answer: false,
          pointsEarned: penalty,
        ),
      );
    }
    return completions;
  }

  List<TemptationLog> _generateTemptationLogs({
    required String habitId,
    required DateTime startDate,
    required DateTime endDate,
    required Set<DateTime> slipDates,
    required List<HabitReason> temptationReasons,
    required double temptationRate,
  }) {
    final logs = <TemptationLog>[];
    for (final date in _daysBetween(startDate, endDate)) {
      if (_random.nextDouble() >= temptationRate) continue;
      final reason = _pick(temptationReasons);
      final didResist = !slipDates.contains(_dateOnly(date));
      final intensityIndex = didResist ? _randomInt(0, 1) : _randomInt(2, 3);
      logs.add(
        TemptationLog(
          habitId: habitId,
          occurredAt: _randomTime(date, 12, 22),
          count: _randomInt(1, 2),
          reasonId: reason.id,
          reasonText: reason.text,
          intensityIndex: intensityIndex,
          didResist: didResist,
          location: _randomLocation(),
          iconCodePoint: reason.iconCodePoint,
          colorValue: reason.colorValue,
        ),
      );
    }
    return logs;
  }

  bool Function(DateTime) _buildIsDuePredicate(
    String frequencyType,
    List<int>? weekDays,
    List<int>? scheduleWeekDays,
  ) {
    if (scheduleWeekDays != null && scheduleWeekDays.isNotEmpty) {
      return (date) => _isDueOnWeekDays(date, scheduleWeekDays);
    }
    if (frequencyType == 'weekly' && weekDays != null && weekDays.isNotEmpty) {
      return (date) => _isDueOnWeekDays(date, weekDays);
    }
    return (_) => true;
  }

  Future<Map<String, HabitCategory>> _ensureCategories({
    required DateTime createdAt,
  }) async {
    final existing = await _categoryRepository.getAllCategories();
    final result = <String, HabitCategory>{};

    for (final seed in _categorySeeds) {
      final match = _findCategory(existing, seed.name);
      if (match != null) {
        result[seed.name] = match;
        continue;
      }
      final created = HabitCategory.fromIcon(
        name: seed.name,
        icon: seed.icon,
        color: seed.color,
        createdAt: createdAt,
      );
      await _categoryRepository.createCategory(created);
      existing.add(created);
      result[seed.name] = created;
    }
    return result;
  }

  Future<_SeededReasons> _ensureReasons({required DateTime createdAt}) async {
    final existing = await _reasonRepository.getAllReasons();
    final notDone = await _ensureReasonGroup(
      existing,
      _notDoneReasonSeeds,
      createdAt: createdAt,
    );
    final slip = await _ensureReasonGroup(
      existing,
      _slipReasonSeeds,
      createdAt: createdAt,
    );
    final temptation = await _ensureReasonGroup(
      existing,
      _temptationReasonSeeds,
      createdAt: createdAt,
    );
    return _SeededReasons(notDone: notDone, slip: slip, temptation: temptation);
  }

  Future<List<HabitReason>> _ensureReasonGroup(
    List<HabitReason> existing,
    List<_ReasonSeed> seeds, {
    required DateTime createdAt,
  }) async {
    final result = <HabitReason>[];
    for (final seed in seeds) {
      final match = _findReason(existing, seed.text, seed.typeIndex);
      if (match != null) {
        result.add(match);
        continue;
      }
      final created = HabitReason(
        text: seed.text,
        typeIndex: seed.typeIndex,
        icon: seed.icon,
        colorValue: seed.color.value,
        createdAt: createdAt,
        isActive: true,
        isDefault: true,
      );
      await _reasonRepository.createReason(created);
      existing.add(created);
      result.add(created);
    }
    return result;
  }

  HabitCategory? _findCategory(List<HabitCategory> categories, String name) {
    final key = _normalize(name);
    for (final category in categories) {
      if (_normalize(category.name) == key) {
        return category;
      }
    }
    return null;
  }

  HabitReason? _findReason(
    List<HabitReason> reasons,
    String text,
    int typeIndex,
  ) {
    final key = _normalize(text);
    for (final reason in reasons) {
      if (reason.typeIndex == typeIndex && _normalize(reason.text) == key) {
        return reason;
      }
    }
    return null;
  }

  String _normalize(String value) => value.trim().toLowerCase();

  List<String> _mergeTags(List<String> tags) {
    final merged = List<String>.from(tags);
    final normalized = merged.map(_normalize).toSet();
    if (!normalized.contains('sample')) {
      merged.add('Sample');
    }
    return merged;
  }

  List<String> _mergeReasonList(List<String> base, List<String> extra) {
    final merged = <String>[];
    final seen = <String>{};
    for (final reason in [...base, ...extra]) {
      final key = _normalize(reason);
      if (seen.add(key)) {
        merged.add(reason);
      }
    }
    return merged;
  }

  List<HabitReason> _selectReasonSubset(
    List<HabitReason> allReasons,
    List<String> preferredTexts,
  ) {
    if (allReasons.isEmpty) return const <HabitReason>[];
    if (preferredTexts.isEmpty) return allReasons;

    final selected = <HabitReason>[];
    final preferred = preferredTexts.map(_normalize).toSet();
    for (final reason in allReasons) {
      if (preferred.contains(_normalize(reason.text))) {
        selected.add(reason);
      }
    }
    return selected.isEmpty ? allReasons : selected;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _sampleEndDate() => _dateOnly(DateTime.now());

  DateTime _sampleStartDate() =>
      _sampleEndDate().subtract(const Duration(days: 59));

  Iterable<DateTime> _daysBetween(DateTime start, DateTime end) sync* {
    var current = _dateOnly(start);
    final last = _dateOnly(end);
    while (!current.isAfter(last)) {
      yield current;
      current = current.add(const Duration(days: 1));
    }
  }

  DateTime _randomTime(DateTime date, int startHour, int endHour) {
    final hourSpan = endHour >= startHour ? endHour - startHour : 0;
    final hour = startHour + (hourSpan > 0 ? _random.nextInt(hourSpan + 1) : 0);
    final minute = _random.nextInt(60);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  double _randomDouble(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }

  int _randomInt(int min, int max) {
    if (max <= min) return min;
    return min + _random.nextInt(max - min + 1);
  }

  int _sumPoints(List<HabitCompletion> completions) {
    return completions.fold<int>(0, (sum, c) => sum + c.pointsEarned);
  }

  T _pick<T>(List<T> items) {
    return items[_random.nextInt(items.length)];
  }

  String _randomLocation() {
    const locations = ['Home', 'Work', 'Out', 'Store', 'Commute'];
    return _pick(locations);
  }

  bool _reserveTitle(String title, Set<String> existingTitles) {
    final key = _normalize(title);
    if (existingTitles.contains(key)) {
      return false;
    }
    existingTitles.add(key);
    return true;
  }

  bool _isDueOnWeekDays(DateTime date, List<int> weekDays) {
    final weekday = date.weekday % 7;
    return weekDays.contains(weekday);
  }

  static const List<_CategorySeed> _categorySeeds = [
    _CategorySeed(
      'Spiritual',
      Icons.self_improvement_rounded,
      Color(0xFF10B981),
    ),
    _CategorySeed('Reading', Icons.menu_book_rounded, Color(0xFF6366F1)),
    _CategorySeed('Health', Icons.favorite, Color(0xFFEF4444)),
    _CategorySeed('Hygiene', Icons.shower_rounded, Color(0xFF38BDF8)),
    _CategorySeed('Hair Care', Icons.brush, Color(0xFFF59E0B)),
    _CategorySeed('Skincare', Icons.face_retouching_natural, Color(0xFFF472B6)),
    _CategorySeed('Fitness', Icons.fitness_center, Color(0xFF22C55E)),
    _CategorySeed('Home', Icons.home, Color(0xFF6B7280)),
    _CategorySeed('Nutrition', Icons.restaurant, Color(0xFFF97316)),
    _CategorySeed('Finance', Icons.account_balance_wallet, Color(0xFF14B8A6)),
    _CategorySeed('Mindset', Icons.psychology, Color(0xFF8B5CF6)),
    _CategorySeed('Productivity', Icons.event_note, Color(0xFF3B82F6)),
    _CategorySeed('Digital Wellness', Icons.phone_android, Color(0xFF64748B)),
  ];

  static const List<_ReasonSeed> _notDoneReasonSeeds = [
    _ReasonSeed('Overslept', 0, Icons.bedtime, Color(0xFFFF6B6B)),
    _ReasonSeed('No time', 0, Icons.schedule, Color(0xFFFFA726)),
    _ReasonSeed('Feeling sick', 0, Icons.sick_rounded, Color(0xFFEF5350)),
    _ReasonSeed('Family event', 0, Icons.event, Color(0xFF42A5F5)),
    _ReasonSeed('Travel day', 0, Icons.flight, Color(0xFF60A5FA)),
    _ReasonSeed('Work overtime', 0, Icons.work, Color(0xFF8D6E63)),
    _ReasonSeed('Low energy', 0, Icons.battery_alert, Color(0xFF9CA3AF)),
    _ReasonSeed('Forgot', 0, Icons.lightbulb_outline, Color(0xFFFDE68A)),
    _ReasonSeed('Bad weather', 0, Icons.cloud, Color(0xFF94A3B8)),
    _ReasonSeed(
      'Ran out of supplies',
      0,
      Icons.inventory_rounded,
      Color(0xFFB45309),
    ),
  ];

  static const List<_ReasonSeed> _slipReasonSeeds = [
    _ReasonSeed('Stress', 2, Icons.psychology, Color(0xFFEF5350)),
    _ReasonSeed('Social event', 2, Icons.celebration, Color(0xFF66BB6A)),
    _ReasonSeed('Craving', 2, Icons.favorite, Color(0xFFFF6B6B)),
    _ReasonSeed('Boredom', 2, Icons.hourglass_empty, Color(0xFF78909C)),
    _ReasonSeed('Late night', 2, Icons.nights_stay, Color(0xFF9575CD)),
    _ReasonSeed('Rewarding myself', 2, Icons.card_giftcard, Color(0xFFFFD54F)),
    _ReasonSeed('Impulse buy', 2, Icons.shopping_bag, Color(0xFF5C6BC0)),
    _ReasonSeed('Peer pressure', 2, Icons.people, Color(0xFF42A5F5)),
    _ReasonSeed(
      'People-pleasing pressure',
      2,
      Icons.handshake_outlined,
      Color(0xFF3B82F6),
    ),
    _ReasonSeed(
      'Gossip circle at work',
      2,
      Icons.forum_outlined,
      Color(0xFF8B5CF6),
    ),
    _ReasonSeed(
      'Flash sale impulse',
      2,
      Icons.local_offer_outlined,
      Color(0xFF14B8A6),
    ),
    _ReasonSeed(
      'Doom-scroll spiral',
      2,
      Icons.phone_android,
      Color(0xFF64748B),
    ),
    _ReasonSeed(
      'Harsh self-talk',
      2,
      Icons.psychology_alt_outlined,
      Color(0xFFEF4444),
    ),
    _ReasonSeed('Craving junk food', 2, Icons.fastfood, Color(0xFFF97316)),
  ];

  static const List<_ReasonSeed> _temptationReasonSeeds = [
    _ReasonSeed('Saw it nearby', 3, Icons.visibility, Color(0xFF5C6BC0)),
    _ReasonSeed('Habit cue', 3, Icons.repeat, Color(0xFFAB47BC)),
    _ReasonSeed('Emotional day', 3, Icons.mood, Color(0xFF9575CD)),
    _ReasonSeed('Weekend treat', 3, Icons.weekend, Color(0xFF66BB6A)),
    _ReasonSeed('Social pressure', 3, Icons.groups, Color(0xFF29B6F6)),
    _ReasonSeed('Work break', 3, Icons.work_outline, Color(0xFF9CA3AF)),
    _ReasonSeed(
      'Feeling anxious',
      3,
      Icons.warning_amber_rounded,
      Color(0xFFF59E0B),
    ),
    _ReasonSeed(
      'Just one more',
      3,
      Icons.notifications_active,
      Color(0xFF26A69A),
    ),
    _ReasonSeed(
      'Fast food delivery ad',
      3,
      Icons.delivery_dining,
      Color(0xFFF97316),
    ),
    _ReasonSeed(
      'Friends drinking soda',
      3,
      Icons.local_drink,
      Color(0xFF38BDF8),
    ),
    _ReasonSeed(
      'Group chat gossip',
      3,
      Icons.chat_bubble_outline,
      Color(0xFF8B5CF6),
    ),
    _ReasonSeed(
      'Limited-time discount',
      3,
      Icons.discount_outlined,
      Color(0xFF14B8A6),
    ),
    _ReasonSeed(
      'Flash sale notification',
      3,
      Icons.campaign_outlined,
      Color(0xFF14B8A6),
    ),
    _ReasonSeed(
      'Picked up phone mindlessly',
      3,
      Icons.touch_app_outlined,
      Color(0xFF64748B),
    ),
    _ReasonSeed(
      'Fear of disappointing others',
      3,
      Icons.people_alt_outlined,
      Color(0xFF3B82F6),
    ),
    _ReasonSeed(
      'Shame trigger moment',
      3,
      Icons.report_gmailerrorred_outlined,
      Color(0xFFEF4444),
    ),
  ];
}

class _CategorySeed {
  final String name;
  final IconData icon;
  final Color color;

  const _CategorySeed(this.name, this.icon, this.color);
}

class _QuitHabitSeed {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String category;
  final String quitSubstance;
  final String unit;
  final int dailyReward;
  final String slipCalculation;
  final int slipPenalty;
  final int? penaltyPerUnit;
  final double? costPerUnit;
  final int streakProtection;
  final double slipRate;
  final double temptationRate;
  final int unitsPerDay;
  final List<String> tags;
  final List<String> slipReasonTexts;
  final List<String> temptationReasonTexts;

  const _QuitHabitSeed({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
    required this.quitSubstance,
    required this.unit,
    required this.dailyReward,
    required this.slipCalculation,
    required this.slipPenalty,
    this.penaltyPerUnit,
    this.costPerUnit,
    this.streakProtection = 1,
    required this.slipRate,
    required this.temptationRate,
    this.unitsPerDay = 1,
    this.tags = const <String>[],
    this.slipReasonTexts = const <String>[],
    this.temptationReasonTexts = const <String>[],
  });
}

class _ReasonSeed {
  final String text;
  final int typeIndex;
  final IconData icon;
  final Color color;

  const _ReasonSeed(this.text, this.typeIndex, this.icon, this.color);
}

class _SeededReasons {
  final List<HabitReason> notDone;
  final List<HabitReason> slip;
  final List<HabitReason> temptation;

  const _SeededReasons({
    required this.notDone,
    required this.slip,
    required this.temptation,
  });
}
