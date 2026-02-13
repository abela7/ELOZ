/// ============================================================================
/// ALL ICONS AGGREGATOR
/// ============================================================================
/// This file aggregates all icon data files into a single collection.
/// Total icons: 1500+ icons across all categories
/// ============================================================================

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'icon_data.dart';
import 'icon_data_2.dart';
import 'icon_data_3.dart';
import 'icon_data_4.dart';
import 'icon_data_5.dart';
import 'icon_data_6.dart';
import 'icon_data_7.dart';
import 'icon_data_8.dart';
import 'icon_data_9.dart';
import 'icon_data_10.dart';

/// Centralized icon library for the entire application
class AllIcons {
  /// Get all icons combined from all data files
  static List<IconDataEntry> getAllIcons() {
    return [
      ...ExtendedIcons.additionalIcons,
      ...ExtendedIcons2.icons,
      ...ExtendedIcons3.icons,
      ...ExtendedIcons4.icons,
      ...ExtendedIcons5.icons,
      ...ExtendedIcons6.icons,
      ...ExtendedIcons7.icons,
      ...ExtendedIcons8.icons,
      ...ExtendedIcons9.icons,
      ...ExtendedIcons10.icons,
    ];
  }
  
  /// Get categorized icons for the picker UI
  static Map<String, CategoryData> getCategorizedIcons() {
    return {
      'All': CategoryData(Icons.apps_rounded, getAllIcons()),
      'Common': CategoryData(Icons.star_rounded, _commonIcons),
      'Habits': CategoryData(Icons.checklist_rounded, _habitIcons), // Daily routines
      'Spiritual': CategoryData(Icons.church_rounded, _spiritualIcons), // Christian focus
      'Social': CategoryData(Icons.groups_rounded, _socialIcons), // People & relationships
      'Emotions': CategoryData(Icons.emoji_emotions_rounded, _emotionIcons), // Feelings & emoji
      'Arrows': CategoryData(Icons.arrow_forward_rounded, _arrowIcons),
      'Media': CategoryData(Icons.play_circle_rounded, _mediaIcons),
      'Communication': CategoryData(Icons.chat_rounded, _communicationIcons),
      'Devices': CategoryData(Icons.smartphone_rounded, _deviceIcons),
      'Food': CategoryData(Icons.restaurant_rounded, _foodIcons),
      'Shopping': CategoryData(Icons.shopping_cart_rounded, _shoppingIcons),
      'Buildings': CategoryData(Icons.business_rounded, _buildingIcons),
      'Nature': CategoryData(Icons.eco_rounded, _natureIcons),
      'Weather': CategoryData(Icons.wb_sunny_rounded, _weatherIcons),
      'Sports': CategoryData(Icons.sports_rounded, _sportsIcons),
      'Work': CategoryData(Icons.work_rounded, _workIcons),
      'Tools': CategoryData(Icons.build_rounded, _toolIcons),
      'Actions': CategoryData(Icons.touch_app_rounded, _actionIcons),
      'Education': CategoryData(Icons.school_rounded, _educationIcons),
      'Technology': CategoryData(Icons.code_rounded, _techIcons),
      'Photography': CategoryData(Icons.camera_alt_rounded, _photoIcons),
      'Travel': CategoryData(Icons.flight_rounded, _travelIcons),
      'Maps': CategoryData(Icons.map_rounded, _mapIcons),
      'Health': CategoryData(Icons.favorite_rounded, _healthIcons),
      'Finance': CategoryData(Icons.attach_money_rounded, _financeIcons),
      'Shapes': CategoryData(Icons.category_rounded, _shapeIcons),
      'Security': CategoryData(Icons.security_rounded, _securityIcons),
      'Files': CategoryData(Icons.folder_rounded, _fileIcons),
    };
  }
  
  // Common/Popular icons
  static final List<IconDataEntry> _commonIcons = [
    // Level & Status Indicators (Low, Medium, High)
    IconDataEntry(Icons.signal_cellular_alt_1_bar_rounded, 'Low Level', ['low', '1', 'signal', 'bar']),
    IconDataEntry(Icons.signal_cellular_alt_2_bar_rounded, 'Medium Level', ['medium', '2', 'signal', 'bar']),
    IconDataEntry(Icons.signal_cellular_alt_rounded, 'High Level', ['high', '3', 'signal', 'bar', 'full']),
    IconDataEntry(Icons.battery_1_bar_rounded, 'Low Battery', ['low', '1', 'power']),
    IconDataEntry(Icons.battery_3_bar_rounded, 'Medium Battery', ['medium', '2', 'power']),
    IconDataEntry(Icons.battery_full_rounded, 'High Battery', ['high', '3', 'power', 'full']),
    IconDataEntry(Icons.filter_1_rounded, 'Level 1', ['one', '1', 'low']),
    IconDataEntry(Icons.filter_2_rounded, 'Level 2', ['two', '2', 'medium']),
    IconDataEntry(Icons.filter_3_rounded, 'Level 3', ['three', '3', 'high']),
    IconDataEntry(FontAwesomeIcons.temperatureLow, 'Low Temp', ['cold', 'low', 'level']),
    IconDataEntry(FontAwesomeIcons.temperatureHalf, 'Medium Temp', ['warm', 'medium', 'level']),
    IconDataEntry(FontAwesomeIcons.temperatureHigh, 'High Temp', ['hot', 'high', 'level']),
    IconDataEntry(FontAwesomeIcons.gauge, 'Medium Gauge', ['medium', 'speed', 'level']),
    IconDataEntry(FontAwesomeIcons.gaugeHigh, 'High Gauge', ['high', 'speed', 'level', 'fast']),
    IconDataEntry(Icons.low_priority_rounded, 'Low Priority', ['low', 'down', 'arrow']),
    IconDataEntry(Icons.priority_high_rounded, 'High Priority', ['high', 'exclamation', 'important']),
    IconDataEntry(Icons.tune_rounded, 'Adjust', ['level', 'settings', 'slider']),
    IconDataEntry(Icons.sort_rounded, 'Sort', ['level', 'list', 'order']),
    IconDataEntry(Icons.bar_chart_rounded, 'Levels', ['stats', 'graph', 'chart']),
    
    // Original Common Icons
    IconDataEntry(Icons.star_rounded, 'Star', ['favorite', 'rate']),
    IconDataEntry(Icons.home_rounded, 'Home', ['house', 'main']),
    IconDataEntry(Icons.settings_rounded, 'Settings', ['gear', 'config']),
    IconDataEntry(Icons.person_rounded, 'Person', ['user', 'profile']),
    IconDataEntry(Icons.favorite_rounded, 'Heart', ['love', 'like']),
    IconDataEntry(Icons.search_rounded, 'Search', ['find', 'look']),
    IconDataEntry(Icons.add_rounded, 'Add', ['plus', 'new']),
    IconDataEntry(Icons.edit_rounded, 'Edit', ['modify', 'pencil']),
    IconDataEntry(Icons.delete_rounded, 'Delete', ['trash', 'remove']),
    IconDataEntry(Icons.check_rounded, 'Check', ['done', 'complete']),
    IconDataEntry(Icons.close_rounded, 'Close', ['x', 'cancel']),
    IconDataEntry(Icons.share_rounded, 'Share', ['send', 'post']),
    IconDataEntry(Icons.notifications_rounded, 'Notifications', ['bell', 'alert']),
    IconDataEntry(Icons.email_rounded, 'Email', ['mail', 'message']),
    IconDataEntry(Icons.phone_rounded, 'Phone', ['call', 'dial']),
    IconDataEntry(Icons.calendar_today_rounded, 'Calendar', ['date', 'schedule']),
    IconDataEntry(Icons.access_time_rounded, 'Time', ['clock', 'hour']),
    IconDataEntry(Icons.location_on_rounded, 'Location', ['pin', 'place']),
    IconDataEntry(Icons.camera_alt_rounded, 'Camera', ['photo', 'picture']),
    IconDataEntry(Icons.mic_rounded, 'Microphone', ['record', 'voice']),
    IconDataEntry(Icons.bookmark_rounded, 'Bookmark', ['save', 'mark']),
    IconDataEntry(Icons.flag_rounded, 'Flag', ['mark', 'report']),
    IconDataEntry(Icons.info_rounded, 'Info', ['about', 'details']),
    IconDataEntry(Icons.help_rounded, 'Help', ['question', 'support']),
    IconDataEntry(Icons.warning_rounded, 'Warning', ['alert', 'caution']),
    IconDataEntry(Icons.error_rounded, 'Error', ['problem', 'issue']),
    IconDataEntry(Icons.lightbulb_rounded, 'Lightbulb', ['idea', 'tip']),
    IconDataEntry(Icons.attach_file_rounded, 'Attach', ['clip', 'file']),
    IconDataEntry(Icons.link_rounded, 'Link', ['url', 'connect']),
    IconDataEntry(Icons.wifi_rounded, 'WiFi', ['internet', 'network']),
    IconDataEntry(Icons.bluetooth_rounded, 'Bluetooth', ['wireless']),
    IconDataEntry(Icons.battery_full_rounded, 'Battery', ['power', 'charge']),
    IconDataEntry(Icons.brightness_6_rounded, 'Brightness', ['light', 'sun']),
    IconDataEntry(Icons.volume_up_rounded, 'Volume', ['sound', 'audio']),
    IconDataEntry(Icons.refresh_rounded, 'Refresh', ['reload', 'sync']),
    IconDataEntry(Icons.download_rounded, 'Download', ['save', 'get']),
    IconDataEntry(Icons.upload_rounded, 'Upload', ['send', 'share']),
    IconDataEntry(Icons.cloud_rounded, 'Cloud', ['storage', 'sync']),
    IconDataEntry(Icons.lock_rounded, 'Lock', ['secure', 'password']),
    IconDataEntry(Icons.key_rounded, 'Key', ['unlock', 'access']),
  ];

  // Habit icons - Daily routines and activities
  static final List<IconDataEntry> _habitIcons = [
    // Morning Routine
    IconDataEntry(Icons.wb_sunny_rounded, 'Wake Up', ['morning', 'sun', 'rise']),
    IconDataEntry(Icons.bed_rounded, 'Make Bed', ['sleep', 'bedroom', 'tidy']),
    IconDataEntry(FontAwesomeIcons.tooth, 'Brush Teeth', ['dental', 'clean', 'hygiene']),
    IconDataEntry(Icons.shower_rounded, 'Shower', ['bath', 'wash', 'clean']),
    IconDataEntry(Icons.bathtub_rounded, 'Bath', ['relax', 'wash', 'clean']),
    IconDataEntry(FontAwesomeIcons.soap, 'Wash Face', ['clean', 'hygiene', 'soap']),
    IconDataEntry(Icons.face_retouching_natural_rounded, 'Skincare', ['face', 'beauty', 'routine']),
    IconDataEntry(Icons.checkroom_rounded, 'Get Dressed', ['clothes', 'outfit', 'wear']),
    IconDataEntry(Icons.scale_rounded, 'Weigh In', ['weight', 'health', 'measure']),
    
    // Food & Drink
    IconDataEntry(Icons.local_drink_rounded, 'Drink Water', ['hydrate', 'glass', 'health']),
    IconDataEntry(Icons.coffee_rounded, 'Coffee', ['caffeine', 'morning', 'drink']),
    IconDataEntry(Icons.breakfast_dining_rounded, 'Breakfast', ['eat', 'food', 'morning']),
    IconDataEntry(Icons.lunch_dining_rounded, 'Lunch', ['eat', 'food', 'noon']),
    IconDataEntry(Icons.dinner_dining_rounded, 'Dinner', ['eat', 'food', 'evening']),
    IconDataEntry(Icons.restaurant_rounded, 'Eat Meal', ['food', 'dining']),
    IconDataEntry(Icons.no_food_rounded, 'Fast', ['diet', 'health']),
    IconDataEntry(FontAwesomeIcons.bottleWater, 'Water Bottle', ['hydrate', 'drink']),
    IconDataEntry(FontAwesomeIcons.pills, 'Vitamins', ['medication', 'health', 'supplements']),
    
    // Household
    IconDataEntry(Icons.cleaning_services_rounded, 'Clean House', ['tidy', 'chores', 'home']),
    IconDataEntry(FontAwesomeIcons.broom, 'Sweep', ['clean', 'floor', 'chores']),
    IconDataEntry(FontAwesomeIcons.bucket, 'Mop', ['clean', 'floor', 'wash']),
    IconDataEntry(Icons.local_laundry_service_rounded, 'Laundry', ['wash', 'clothes', 'chores']),
    IconDataEntry(Icons.iron_rounded, 'Ironing', ['clothes', 'chores']),
    IconDataEntry(Icons.kitchen_rounded, 'Cook', ['food', 'prepare', 'meal']),
    IconDataEntry(Icons.wash_rounded, 'Dishes', ['clean', 'kitchen', 'sink']),
    IconDataEntry(Icons.delete_rounded, 'Take out Trash', ['garbage', 'bin', 'chores']),
    IconDataEntry(Icons.local_florist_rounded, 'Water Plants', ['garden', 'nature', 'care']),
    IconDataEntry(Icons.pets_rounded, 'Feed Pet', ['animal', 'dog', 'cat', 'care']),
    IconDataEntry(FontAwesomeIcons.dog, 'Walk Dog', ['pet', 'animal', 'exercise']),
    
    // Health & Fitness
    IconDataEntry(Icons.directions_walk_rounded, 'Walk', ['exercise', 'steps', 'move']),
    IconDataEntry(Icons.directions_run_rounded, 'Run', ['jog', 'exercise', 'cardio']),
    IconDataEntry(Icons.fitness_center_rounded, 'Workout', ['gym', 'exercise', 'weights']),
    IconDataEntry(Icons.self_improvement_rounded, 'Meditate', ['mindfulness', 'zen', 'calm']),
    IconDataEntry(Icons.spa_rounded, 'Yoga', ['stretch', 'exercise', 'relax']),
    IconDataEntry(Icons.pool_rounded, 'Swim', ['exercise', 'water', 'sport']),
    IconDataEntry(Icons.directions_bike_rounded, 'Cycle', ['bike', 'ride', 'exercise']),
    IconDataEntry(Icons.monitor_heart_rounded, 'Check BP', ['health', 'heart', 'measure']),
    
    // Productivity & Learning
    IconDataEntry(Icons.menu_book_rounded, 'Read', ['book', 'study', 'learn']),
    IconDataEntry(Icons.edit_note_rounded, 'Journal', ['write', 'diary', 'note']),
    IconDataEntry(Icons.school_rounded, 'Study', ['learn', 'class', 'education']),
    IconDataEntry(Icons.work_rounded, 'Work', ['job', 'office', 'career']),
    IconDataEntry(Icons.language_rounded, 'Learn Language', ['study', 'speak', 'practice']),
    IconDataEntry(Icons.code_rounded, 'Code', ['program', 'dev', 'work']),
    IconDataEntry(Icons.music_note_rounded, 'Practice Music', ['instrument', 'play', 'learn']),
    
    // Evening
    IconDataEntry(Icons.family_restroom_rounded, 'Family Time', ['kids', 'parents', 'social']),
    IconDataEntry(Icons.phone_rounded, 'Call Family', ['talk', 'social', 'connect']),
    IconDataEntry(Icons.tv_rounded, 'Watch TV', ['relax', 'movie', 'show']),
    IconDataEntry(Icons.gamepad_rounded, 'Game', ['play', 'fun', 'relax']),
    IconDataEntry(Icons.bedtime_rounded, 'Sleep', ['night', 'rest', 'bed']),
    
    // Bad Habits / Quitting
    IconDataEntry(Icons.phone_android_rounded, 'Phone Addiction', ['screen time', 'scrolling', 'social media']),
    IconDataEntry(FontAwesomeIcons.scroll, 'Doom Scrolling', ['social media', 'waste time', 'phone']),
    IconDataEntry(Icons.timer_off_rounded, 'Wasting Time', ['procrastinate', 'lazy', 'delay']),
    IconDataEntry(Icons.do_not_disturb_on_total_silence_rounded, 'Digital Detox', ['offline', 'no phone', 'focus']),
    IconDataEntry(Icons.fastfood_rounded, 'Junk Food', ['unhealthy', 'burger', 'fast food']),
    IconDataEntry(FontAwesomeIcons.pizzaSlice, 'Pizza', ['junk food', 'unhealthy', 'meal']),
    IconDataEntry(FontAwesomeIcons.candyCane, 'Sweets', ['sugar', 'candy', 'unhealthy']),
    IconDataEntry(Icons.icecream_rounded, 'Dessert', ['sugar', 'sweets', 'unhealthy']),
    IconDataEntry(Icons.no_food_rounded, 'Stop Eating', ['diet', 'fast', 'control']),
    IconDataEntry(FontAwesomeIcons.ban, 'Quit', ['stop', 'no', 'bad habit']),
    IconDataEntry(Icons.smoking_rooms_rounded, 'Smoking', ['cigarette', 'tobacco', 'bad habit']),
    IconDataEntry(FontAwesomeIcons.smoking, 'Smoke', ['cigarette', 'tobacco', 'bad habit']),
    IconDataEntry(Icons.smoke_free_rounded, 'No Smoking', ['quit', 'health', 'stop']),
    IconDataEntry(Icons.local_bar_rounded, 'Alcohol', ['drink', 'beer', 'wine']),
    IconDataEntry(FontAwesomeIcons.wineBottle, 'Wine', ['alcohol', 'drink', 'bad habit']),
    IconDataEntry(Icons.no_drinks_rounded, 'No Alcohol', ['sober', 'quit', 'health']),
    IconDataEntry(Icons.videogame_asset_rounded, 'Gaming', ['play', 'waste time', 'addiction']),
    IconDataEntry(Icons.shopping_bag_rounded, 'Shopping', ['spending', 'money', 'addiction']),
    IconDataEntry(FontAwesomeIcons.dice, 'Gambling', ['bet', 'risk', 'money']),
    IconDataEntry(Icons.casino_rounded, 'Casino', ['gambling', 'bet', 'risk']),
    IconDataEntry(Icons.explicit_rounded, 'Swearing', ['bad language', 'curse', 'bad habit']),
    IconDataEntry(FontAwesomeIcons.hand, 'Biting Nails', ['bad habit', 'nervous', 'anxiety']),
    IconDataEntry(Icons.do_not_touch_rounded, 'No Touch', ['nofap', 'control', 'abstain']),
    IconDataEntry(Icons.privacy_tip_rounded, 'Private', ['secret', 'hidden', 'habit']),
    IconDataEntry(FontAwesomeIcons.fire, 'Urge', ['craving', 'desire', 'addiction']),
    IconDataEntry(Icons.back_hand_rounded, 'Stop', ['halt', 'quit', 'control']),
  ];

  // Arrow icons
  static final List<IconDataEntry> _arrowIcons = ExtendedIcons.additionalIcons
      .where((i) => i.name.toLowerCase().contains('arrow') || 
                    i.keywords.any((k) => k.contains('arrow') || k.contains('direction')))
      .toList();

  // Media icons
  static final List<IconDataEntry> _mediaIcons = [
    ...ExtendedIcons.additionalIcons.where((i) => 
        i.keywords.any((k) => ['audio', 'video', 'music', 'play', 'media'].contains(k))),
    ...ExtendedIcons7.icons,
  ];

  // Communication icons
  static final List<IconDataEntry> _communicationIcons = [
    ...ExtendedIcons.additionalIcons.where((i) => 
        i.keywords.any((k) => ['chat', 'message', 'call', 'email', 'mail'].contains(k))),
    ...ExtendedIcons3.icons.where((i) => 
        i.keywords.any((k) => ['social', 'share', 'like', 'comment'].contains(k))),
  ];

  // Device icons
  static final List<IconDataEntry> _deviceIcons = ExtendedIcons.additionalIcons
      .where((i) => i.keywords.any((k) => 
          ['phone', 'computer', 'device', 'laptop', 'tablet', 'watch'].contains(k)))
      .toList();

  // Food icons  
  static final List<IconDataEntry> _foodIcons = ExtendedIcons2.icons
      .where((i) => i.keywords.any((k) => 
          ['food', 'eat', 'drink', 'meal', 'restaurant', 'coffee'].contains(k)))
      .toList();

  // Shopping icons
  static final List<IconDataEntry> _shoppingIcons = ExtendedIcons2.icons
      .where((i) => i.keywords.any((k) => 
          ['shop', 'buy', 'cart', 'store', 'mall', 'purchase'].contains(k)))
      .toList();

  // Building icons
  static final List<IconDataEntry> _buildingIcons = ExtendedIcons2.icons
      .where((i) => i.keywords.any((k) => 
          ['building', 'house', 'home', 'office', 'hotel', 'hospital'].contains(k)))
      .toList();

  // Nature icons
  static final List<IconDataEntry> _natureIcons = ExtendedIcons4.icons
      .where((i) => i.keywords.any((k) => 
          ['nature', 'tree', 'plant', 'flower', 'park', 'outdoor', 'animal'].contains(k)))
      .toList();

  // Weather icons
  static final List<IconDataEntry> _weatherIcons = ExtendedIcons4.icons
      .where((i) => i.keywords.any((k) => 
          ['sun', 'cloud', 'rain', 'snow', 'weather', 'moon', 'night'].contains(k)))
      .toList();

  // Sports icons
  static final List<IconDataEntry> _sportsIcons = ExtendedIcons4.icons
      .where((i) => i.keywords.any((k) => 
          ['sport', 'game', 'ball', 'fitness', 'gym', 'exercise'].contains(k)))
      .toList();

  // Work icons
  static final List<IconDataEntry> _workIcons = ExtendedIcons5.icons
      .where((i) => i.keywords.any((k) => 
          ['work', 'office', 'job', 'business', 'meeting', 'briefcase'].contains(k)))
      .toList();

  // Tool icons
  static final List<IconDataEntry> _toolIcons = ExtendedIcons5.icons
      .where((i) => i.keywords.any((k) => 
          ['tool', 'build', 'fix', 'repair', 'wrench', 'settings'].contains(k)))
      .toList();

  // Action icons
  static final List<IconDataEntry> _actionIcons = ExtendedIcons5.icons
      .where((i) => i.keywords.any((k) => 
          ['add', 'edit', 'delete', 'save', 'cancel', 'done', 'check'].contains(k)))
      .toList();

  // Education icons
  static final List<IconDataEntry> _educationIcons = ExtendedIcons6.icons
      .where((i) => i.keywords.any((k) => 
          ['school', 'learn', 'study', 'book', 'education', 'class'].contains(k)))
      .toList();

  // Technology icons
  static final List<IconDataEntry> _techIcons = ExtendedIcons6.icons
      .where((i) => i.keywords.any((k) => 
          ['code', 'tech', 'web', 'api', 'computer', 'develop'].contains(k)))
      .toList();

  // Photography icons
  static final List<IconDataEntry> _photoIcons = ExtendedIcons7.icons
      .where((i) => i.keywords.any((k) => 
          ['photo', 'camera', 'image', 'picture', 'filter', 'crop'].contains(k)))
      .toList();

  // Travel icons
  static final List<IconDataEntry> _travelIcons = ExtendedIcons8.icons
      .where((i) => i.keywords.any((k) => 
          ['travel', 'flight', 'plane', 'car', 'train', 'bus', 'hotel'].contains(k)))
      .toList();

  // Map icons
  static final List<IconDataEntry> _mapIcons = ExtendedIcons8.icons
      .where((i) => i.keywords.any((k) => 
          ['map', 'location', 'navigation', 'gps', 'compass', 'direction'].contains(k)))
      .toList();

  // Health icons
  static final List<IconDataEntry> _healthIcons = ExtendedIcons9.icons
      .where((i) => i.keywords.any((k) => 
          ['health', 'medical', 'doctor', 'hospital', 'fitness', 'heart'].contains(k)))
      .toList();

  // Finance icons
  static final List<IconDataEntry> _financeIcons = ExtendedIcons9.icons
      .where((i) => i.keywords.any((k) => 
          ['money', 'finance', 'bank', 'payment', 'card', 'dollar', 'chart'].contains(k)))
      .toList();

  // Shape icons
  static final List<IconDataEntry> _shapeIcons = ExtendedIcons10.icons
      .where((i) => i.keywords.any((k) => 
          ['shape', 'circle', 'square', 'star', 'triangle', 'dot'].contains(k)))
      .toList();

  // Emotion/Mood icons - EXPANDED with 100+ emoji and feelings
  static final List<IconDataEntry> _emotionIcons = [
    // ═══════════════════════════════════════════════════════════════
    // HAPPY & POSITIVE EMOTIONS
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.sentiment_satisfied_rounded, 'Happy', ['smile', 'joy', 'glad']),
    IconDataEntry(Icons.sentiment_very_satisfied_rounded, 'Very Happy', ['ecstatic', 'elated', 'overjoyed']),
    IconDataEntry(Icons.mood_rounded, 'Good Mood', ['happy', 'positive', 'cheerful']),
    IconDataEntry(Icons.emoji_emotions_rounded, 'Joyful', ['emoji', 'happy', 'smile']),
    IconDataEntry(Icons.celebration_rounded, 'Celebration', ['party', 'happy', 'joy', 'excited']),
    IconDataEntry(Icons.cake_rounded, 'Birthday Joy', ['celebrate', 'happy', 'party']),
    IconDataEntry(Icons.local_bar_rounded, 'Cheers', ['celebrate', 'happy', 'toast']),
    IconDataEntry(Icons.sports_bar_rounded, 'Party Mode', ['celebrate', 'fun', 'happy']),
    IconDataEntry(Icons.nightlife_rounded, 'Nightlife', ['party', 'fun', 'excited']),
    IconDataEntry(Icons.auto_awesome_rounded, 'Amazed', ['wonder', 'sparkle', 'excited']),
    IconDataEntry(Icons.stars_rounded, 'Starry Eyed', ['amazed', 'wonder', 'dreamy']),
    IconDataEntry(Icons.brightness_high_rounded, 'Radiant', ['bright', 'glowing', 'happy']),
    IconDataEntry(Icons.wb_sunny_rounded, 'Sunny Mood', ['bright', 'happy', 'warm']),
    IconDataEntry(Icons.emoji_events_rounded, 'Victorious', ['trophy', 'success', 'winner']),
    IconDataEntry(Icons.military_tech_rounded, 'Proud', ['achievement', 'medal', 'honor']),
    IconDataEntry(Icons.workspace_premium_rounded, 'Premium Feel', ['special', 'valued']),
    IconDataEntry(Icons.grade_rounded, 'Excellent', ['star', 'great', 'awesome']),
    IconDataEntry(Icons.thumb_up_rounded, 'Thumbs Up', ['like', 'agree', 'good', 'approval']),
    IconDataEntry(Icons.recommend_rounded, 'Recommend', ['like', 'thumbs up', 'approve']),
    IconDataEntry(Icons.verified_rounded, 'Satisfied', ['approved', 'verified', 'good']),
    IconDataEntry(Icons.check_circle_rounded, 'Content', ['done', 'satisfied', 'complete']),
    IconDataEntry(Icons.task_alt_rounded, 'Accomplished', ['done', 'achieved', 'success']),
    
    // ═══════════════════════════════════════════════════════════════
    // LOVE & AFFECTION
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.favorite_rounded, 'Love', ['heart', 'affection', 'adore']),
    IconDataEntry(Icons.favorite_border_rounded, 'Liking', ['heart', 'fond', 'care']),
    IconDataEntry(Icons.heart_broken_rounded, 'Heartbreak', ['sad', 'loss', 'hurt']),
    IconDataEntry(Icons.volunteer_activism_rounded, 'Compassion', ['care', 'give', 'help']),
    IconDataEntry(Icons.handshake_rounded, 'Friendly', ['peace', 'agreement', 'bond']),
    IconDataEntry(Icons.diversity_1_rounded, 'Together', ['love', 'couple', 'unity']),
    IconDataEntry(Icons.diversity_2_rounded, 'Connected', ['love', 'friends', 'bond']),
    IconDataEntry(Icons.diversity_3_rounded, 'Unity', ['love', 'team', 'together']),
    IconDataEntry(Icons.loyalty_rounded, 'Loyal', ['faithful', 'devoted', 'heart']),
    IconDataEntry(Icons.child_friendly_rounded, 'Caring', ['nurture', 'protect', 'kind']),
    IconDataEntry(Icons.pets_rounded, 'Affectionate', ['pet', 'love', 'gentle']),
    IconDataEntry(Icons.cruelty_free_rounded, 'Gentle', ['kind', 'soft', 'tender']),
    IconDataEntry(Icons.spa_rounded, 'Relaxed Love', ['peace', 'calm', 'serene']),
    
    // ═══════════════════════════════════════════════════════════════
    // SAD & NEGATIVE EMOTIONS
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.sentiment_dissatisfied_rounded, 'Sad', ['unhappy', 'down', 'blue']),
    IconDataEntry(Icons.sentiment_very_dissatisfied_rounded, 'Very Sad', ['upset', 'distressed']),
    IconDataEntry(Icons.mood_bad_rounded, 'Bad Mood', ['sad', 'negative', 'down']),
    IconDataEntry(Icons.sick_rounded, 'Unwell', ['sick', 'ill', 'nauseous']),
    IconDataEntry(Icons.water_drop_rounded, 'Tearful', ['cry', 'sad', 'tears']),
    IconDataEntry(Icons.cloud_rounded, 'Gloomy', ['sad', 'dark', 'depressed']),
    IconDataEntry(Icons.nights_stay_rounded, 'Melancholy', ['sad', 'night', 'lonely']),
    IconDataEntry(Icons.bedtime_rounded, 'Tired Sad', ['exhausted', 'drained']),
    IconDataEntry(Icons.thumb_down_rounded, 'Thumbs Down', ['dislike', 'disagree', 'bad', 'disapproval']),
    IconDataEntry(Icons.cancel_rounded, 'Rejected', ['no', 'denied', 'hurt']),
    IconDataEntry(Icons.do_not_disturb_rounded, 'Leave Me Alone', ['sad', 'withdrawn']),
    IconDataEntry(Icons.remove_circle_rounded, 'Negative', ['minus', 'less', 'down']),
    IconDataEntry(Icons.mood_bad_rounded, 'Stressed', ['pressure', 'anxious', 'tense']),
    
    // ═══════════════════════════════════════════════════════════════
    // ANGRY & FRUSTRATED
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.local_fire_department_rounded, 'Furious', ['angry', 'rage', 'fire']),
    IconDataEntry(Icons.whatshot_rounded, 'Heated', ['angry', 'hot', 'intense']),
    IconDataEntry(Icons.flash_on_rounded, 'Explosive', ['angry', 'sudden', 'rage']),
    IconDataEntry(Icons.storm_rounded, 'Stormy', ['angry', 'turbulent', 'upset']),
    IconDataEntry(Icons.thunderstorm_rounded, 'Raging', ['angry', 'fierce', 'storm']),
    IconDataEntry(Icons.warning_rounded, 'Frustrated', ['annoyed', 'warning', 'upset']),
    IconDataEntry(Icons.error_rounded, 'Irritated', ['problem', 'annoyed', 'mad']),
    IconDataEntry(Icons.dangerous_rounded, 'Dangerous Mood', ['angry', 'threat', 'rage']),
    IconDataEntry(Icons.block_rounded, 'Blocked', ['frustrated', 'stuck', 'no']),
    IconDataEntry(Icons.report_rounded, 'Aggravated', ['report', 'annoyed', 'upset']),
    
    // ═══════════════════════════════════════════════════════════════
    // NEUTRAL & MIXED
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.sentiment_neutral_rounded, 'Neutral', ['meh', 'okay', 'indifferent']),
    IconDataEntry(Icons.thumbs_up_down_rounded, 'Mixed Feelings', ['undecided', 'conflicted']),
    IconDataEntry(Icons.horizontal_rule_rounded, 'Flat', ['neutral', 'no emotion', 'blank']),
    IconDataEntry(Icons.remove_rounded, 'Minus Mood', ['neutral', 'nothing']),
    IconDataEntry(Icons.radio_button_unchecked_rounded, 'Empty', ['neutral', 'void', 'blank']),
    IconDataEntry(Icons.lens_blur_rounded, 'Hazy', ['unclear', 'confused', 'foggy']),
    
    // ═══════════════════════════════════════════════════════════════
    // THINKING & CONTEMPLATION
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.psychology_rounded, 'Thinking', ['mind', 'mental', 'thought']),
    IconDataEntry(Icons.psychology_alt_rounded, 'Deep Thought', ['contemplation', 'ponder']),
    IconDataEntry(Icons.lightbulb_rounded, 'Inspired', ['idea', 'eureka', 'insight']),
    IconDataEntry(Icons.tips_and_updates_rounded, 'Enlightened', ['insight', 'realize']),
    IconDataEntry(Icons.emoji_objects_rounded, 'Curious', ['wonder', 'explore', 'think']),
    IconDataEntry(Icons.question_mark_rounded, 'Confused', ['uncertain', 'puzzled']),
    IconDataEntry(Icons.help_rounded, 'Questioning', ['unsure', 'doubt', 'wonder']),
    IconDataEntry(Icons.pending_rounded, 'Waiting', ['patient', 'expectant']),
    IconDataEntry(Icons.hourglass_empty_rounded, 'Anticipating', ['waiting', 'expect']),
    
    // ═══════════════════════════════════════════════════════════════
    // FEAR & ANXIETY
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.running_with_errors_rounded, 'Anxious', ['worry', 'stressed']),
    IconDataEntry(Icons.speed_rounded, 'Panicked', ['rush', 'anxious', 'fear']),
    IconDataEntry(Icons.visibility_off_rounded, 'Hiding', ['scared', 'avoid', 'shy']),
    IconDataEntry(Icons.shield_rounded, 'Defensive', ['protect', 'guard', 'fear']),
    IconDataEntry(Icons.ac_unit_rounded, 'Cold Fear', ['frozen', 'scared', 'chill']),
    IconDataEntry(Icons.report_problem_rounded, 'Worried', ['concern', 'anxiety']),
    
    // ═══════════════════════════════════════════════════════════════
    // ENERGY & EXCITEMENT
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.bolt_rounded, 'Energetic', ['power', 'electric', 'active']),
    IconDataEntry(Icons.electric_bolt_rounded, 'Electrified', ['excited', 'charged']),
    IconDataEntry(Icons.rocket_launch_rounded, 'Thrilled', ['excited', 'launch', 'go']),
    IconDataEntry(Icons.flight_takeoff_rounded, 'Elated', ['high', 'soaring', 'up']),
    IconDataEntry(Icons.trending_up_rounded, 'Uplifted', ['rising', 'better', 'up']),
    IconDataEntry(Icons.arrow_upward_rounded, 'Rising Mood', ['up', 'better', 'improve']),
    IconDataEntry(Icons.sports_score_rounded, 'Pumped', ['excited', 'ready', 'go']),
    IconDataEntry(Icons.music_note_rounded, 'Musical Mood', ['happy', 'rhythm']),
    IconDataEntry(Icons.headphones_rounded, 'In the Zone', ['focused', 'music']),
    
    // ═══════════════════════════════════════════════════════════════
    // CALM & PEACEFUL
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.self_improvement_rounded, 'Peaceful', ['calm', 'zen', 'serene']),
    IconDataEntry(Icons.waves_rounded, 'Calm', ['peaceful', 'relaxed', 'flow']),
    IconDataEntry(Icons.water_rounded, 'Serene', ['peaceful', 'still', 'calm']),
    IconDataEntry(Icons.park_rounded, 'Tranquil', ['nature', 'peaceful', 'calm']),
    IconDataEntry(Icons.nature_people_rounded, 'At Peace', ['nature', 'calm', 'relax']),
    IconDataEntry(Icons.emoji_nature_rounded, 'Nature Lover', ['peaceful', 'calm']),
    IconDataEntry(Icons.airline_seat_flat_rounded, 'Resting', ['relax', 'rest', 'calm']),
    IconDataEntry(Icons.weekend_rounded, 'Chilling', ['relax', 'weekend', 'calm']),
    IconDataEntry(Icons.hot_tub_rounded, 'Relaxing', ['spa', 'calm', 'unwind']),
    
    // ═══════════════════════════════════════════════════════════════
    // FACES & EXPRESSIONS
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.face_rounded, 'Face', ['person', 'expression', 'neutral']),
    IconDataEntry(Icons.face_2_rounded, 'Face 2', ['person', 'expression', 'smile']),
    IconDataEntry(Icons.face_3_rounded, 'Face 3', ['person', 'expression', 'woman']),
    IconDataEntry(Icons.face_4_rounded, 'Face 4', ['person', 'expression', 'elder']),
    IconDataEntry(Icons.face_5_rounded, 'Face 5', ['person', 'expression', 'cool']),
    IconDataEntry(Icons.face_6_rounded, 'Face 6', ['person', 'expression', 'young']),
    IconDataEntry(Icons.face_retouching_natural_rounded, 'Glowing', ['beautiful', 'radiant']),
    IconDataEntry(Icons.elderly_rounded, 'Wise Face', ['experience', 'age', 'elder']),
    IconDataEntry(Icons.child_care_rounded, 'Innocent', ['child', 'pure', 'baby']),
    IconDataEntry(Icons.boy_rounded, 'Boy', ['child', 'young', 'male']),
    IconDataEntry(Icons.girl_rounded, 'Girl', ['child', 'young', 'female']),
    IconDataEntry(Icons.man_rounded, 'Man', ['adult', 'male', 'person']),
    IconDataEntry(Icons.woman_rounded, 'Woman', ['adult', 'female', 'person']),
    IconDataEntry(Icons.record_voice_over_rounded, 'Speaking', ['talk', 'express', 'voice']),
    IconDataEntry(Icons.voice_over_off_rounded, 'Silent', ['quiet', 'mute', 'speechless']),
    
    // ═══════════════════════════════════════════════════════════════
    // MISCELLANEOUS EMOTIONS
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.emoji_symbols_rounded, 'Symbolic', ['expression', 'symbol']),
    IconDataEntry(Icons.emoji_people_rounded, 'Expressive', ['social', 'human']),
    IconDataEntry(Icons.emoji_food_beverage_rounded, 'Hungry', ['craving', 'food']),
    IconDataEntry(Icons.local_cafe_rounded, 'Need Coffee', ['tired', 'caffeine']),
    IconDataEntry(Icons.bedtime_off_rounded, 'Cant Sleep', ['insomnia', 'awake']),
    IconDataEntry(Icons.local_hotel_rounded, 'Sleepy', ['tired', 'rest', 'bed']),
    IconDataEntry(Icons.airline_seat_individual_suite_rounded, 'Exhausted', ['tired', 'drained']),
    IconDataEntry(Icons.coronavirus_rounded, 'Sick Feeling', ['ill', 'unwell', 'virus']),
    IconDataEntry(Icons.healing_rounded, 'Healing', ['recover', 'better', 'improve']),
    IconDataEntry(Icons.trending_down_rounded, 'Down Mood', ['sad', 'low', 'decrease']),
    IconDataEntry(Icons.arrow_downward_rounded, 'Falling', ['down', 'decrease', 'sad']),
    // ═══════════════════════════════════════════════════════════════
    // FONT AWESOME EMOTIONS & FACES (Expanded)
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(FontAwesomeIcons.faceSmile, 'Smile', ['happy', 'joy', 'face']),
    IconDataEntry(FontAwesomeIcons.faceSmileBeam, 'Beaming', ['happy', 'joy', 'face', 'grin']),
    IconDataEntry(FontAwesomeIcons.faceSmileWink, 'Winking', ['wink', 'happy', 'face']),
    IconDataEntry(FontAwesomeIcons.faceGrin, 'Grin', ['smile', 'happy', 'face']),
    IconDataEntry(FontAwesomeIcons.faceGrinBeam, 'Grin Beam', ['smile', 'happy', 'face']),
    IconDataEntry(FontAwesomeIcons.faceGrinHearts, 'Loving', ['love', 'heart', 'face', 'happy']),
    IconDataEntry(FontAwesomeIcons.faceGrinSquint, 'Laughing', ['laugh', 'happy', 'face']),
    IconDataEntry(FontAwesomeIcons.faceGrinStars, 'Starry Eyed', ['star', 'happy', 'face', 'amazed']),
    IconDataEntry(FontAwesomeIcons.faceGrinTears, 'Laughing Tears', ['laugh', 'cry', 'happy', 'face']),
    IconDataEntry(FontAwesomeIcons.faceGrinTongue, 'Silly', ['tongue', 'funny', 'face']),
    IconDataEntry(FontAwesomeIcons.faceGrinTongueSquint, 'Silly Laugh', ['tongue', 'funny', 'face']),
    IconDataEntry(FontAwesomeIcons.faceGrinWide, 'Wide Grin', ['smile', 'happy', 'face']),
    IconDataEntry(FontAwesomeIcons.faceLaugh, 'Laugh', ['smile', 'happy', 'face']),
    IconDataEntry(FontAwesomeIcons.faceLaughBeam, 'Laugh Beam', ['smile', 'happy', 'face']),
    IconDataEntry(FontAwesomeIcons.faceLaughSquint, 'Laugh Squint', ['smile', 'happy', 'face']),
    IconDataEntry(FontAwesomeIcons.faceLaughWink, 'Laugh Wink', ['smile', 'happy', 'face']),
    
    IconDataEntry(FontAwesomeIcons.faceMeh, 'Meh', ['neutral', 'face']),
    IconDataEntry(FontAwesomeIcons.faceMehBlank, 'Blank', ['neutral', 'face', 'empty']),
    IconDataEntry(FontAwesomeIcons.faceRollingEyes, 'Rolling Eyes', ['annoyed', 'face', 'meh']),
    
    IconDataEntry(FontAwesomeIcons.faceFrown, 'Frown', ['sad', 'face', 'bad']),
    IconDataEntry(FontAwesomeIcons.faceFrownOpen, 'Frown Open', ['sad', 'face', 'shock']),
    IconDataEntry(FontAwesomeIcons.faceSadCry, 'Crying', ['sad', 'tears', 'face']),
    IconDataEntry(FontAwesomeIcons.faceSadTear, 'Tear', ['sad', 'cry', 'face']),
    
    IconDataEntry(FontAwesomeIcons.faceAngry, 'Angry', ['mad', 'face', 'upset']),
    IconDataEntry(FontAwesomeIcons.faceDizzy, 'Dizzy', ['sick', 'face', 'confused']),
    IconDataEntry(FontAwesomeIcons.faceFlushed, 'Flushed', ['embarrassed', 'face', 'shy']),
    IconDataEntry(FontAwesomeIcons.faceGrimace, 'Grimace', ['awkward', 'face', 'oops']),
    IconDataEntry(FontAwesomeIcons.faceKiss, 'Kiss', ['love', 'face', 'affection']),
    IconDataEntry(FontAwesomeIcons.faceKissBeam, 'Kiss Beam', ['love', 'face', 'affection']),
    IconDataEntry(FontAwesomeIcons.faceKissWinkHeart, 'Kiss Heart', ['love', 'face', 'affection']),
    IconDataEntry(FontAwesomeIcons.faceSurprise, 'Surprise', ['shock', 'face', 'wow']),
    IconDataEntry(FontAwesomeIcons.faceTired, 'Tired', ['sleepy', 'face', 'exhausted']),
    
    IconDataEntry(FontAwesomeIcons.ghost, 'Ghost', ['spooky', 'halloween']),
    IconDataEntry(FontAwesomeIcons.poo, 'Poo', ['funny', 'mess']),
    IconDataEntry(FontAwesomeIcons.robot, 'Robot', ['tech', 'bot']),
  ];

  // Spiritual icons - Christian focus with multi-faith support (120+ icons)
  static final List<IconDataEntry> _spiritualIcons = [
    // ═══════════════════════════════════════════════════════════════
    // FONT AWESOME - SPECIFIC CHRISTIAN SYMBOLS
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(FontAwesomeIcons.cross, 'Cross', ['christian', 'jesus', 'crucify', 'salvation']),
    IconDataEntry(FontAwesomeIcons.handsPraying, 'Praying Hands', ['prayer', 'christian', 'worship', 'pray']),
    IconDataEntry(FontAwesomeIcons.personPraying, 'Person Praying', ['prayer', 'worship', 'bow']),
    IconDataEntry(FontAwesomeIcons.bible, 'Bible', ['scripture', 'gospel', 'word', 'christian']),
    IconDataEntry(FontAwesomeIcons.church, 'Church', ['christian', 'worship', 'sunday']),
    IconDataEntry(FontAwesomeIcons.dove, 'Dove', ['holy spirit', 'peace', 'christian']),
    IconDataEntry(FontAwesomeIcons.fish, 'Fish', ['ichthys', 'christian', 'symbol', 'jesus']),
    IconDataEntry(FontAwesomeIcons.heart, 'Sacred Heart', ['jesus', 'love', 'christian']),
    IconDataEntry(FontAwesomeIcons.handsHoldingCircle, 'Offering', ['give', 'tithe', 'hands']),
    
    // ═══════════════════════════════════════════════════════════════
    // FONT AWESOME - OTHER FAITHS
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(FontAwesomeIcons.mosque, 'Mosque', ['islam', 'muslim', 'prayer']),
    IconDataEntry(FontAwesomeIcons.kaaba, 'Kaaba', ['islam', 'mecca', 'hajj']),
    IconDataEntry(FontAwesomeIcons.starOfDavid, 'Star of David', ['jewish', 'judaism', 'israel']),
    IconDataEntry(FontAwesomeIcons.menorah, 'Menorah', ['hanukkah', 'jewish', 'candle']),
    IconDataEntry(FontAwesomeIcons.dharmachakra, 'Dharmachakra', ['buddhism', 'dharma', 'wheel']),
    IconDataEntry(FontAwesomeIcons.om, 'Om', ['hindu', 'yoga', 'meditation']),
    IconDataEntry(FontAwesomeIcons.yinYang, 'Yin Yang', ['taoism', 'balance', 'harmony']),
    IconDataEntry(FontAwesomeIcons.peace, 'Peace', ['symbol', 'harmony']),
    IconDataEntry(FontAwesomeIcons.placeOfWorship, 'Worship Place', ['temple', 'shrine']),
    
    // ═══════════════════════════════════════════════════════════════
    // MATERIAL ICONS - COMPLEMENTARY
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.church_rounded, 'Church Alt', ['christian', 'worship']),
    IconDataEntry(Icons.auto_stories_rounded, 'Bible Reading', ['devotion', 'study']),
    IconDataEntry(Icons.volunteer_activism_rounded, 'Praise Hands', ['worship', 'hands up']),
    IconDataEntry(Icons.self_improvement_rounded, 'Meditation', ['bow', 'humble', 'pray']),
    IconDataEntry(Icons.clean_hands_rounded, 'Clean Hands', ['pray', 'pure', 'holy']),
    IconDataEntry(Icons.stars_rounded, 'Divine Light', ['glory', 'heaven', 'star']),
    IconDataEntry(Icons.child_care_rounded, 'Nativity', ['baby', 'jesus', 'christmas']),
    IconDataEntry(Icons.family_restroom_rounded, 'Holy Family', ['mary', 'joseph', 'jesus']),
    IconDataEntry(Icons.record_voice_over_rounded, 'Preaching', ['sermon', 'pastor']),
    IconDataEntry(Icons.group_rounded, 'Fellowship', ['congregation', 'community']),
    IconDataEntry(Icons.water_drop_rounded, 'Baptism', ['water', 'sacrament']),
    IconDataEntry(Icons.local_fire_department_rounded, 'Holy Spirit', ['fire', 'pentecost']),
    IconDataEntry(Icons.wb_sunny_rounded, 'Resurrection', ['easter', 'light']),
    IconDataEntry(Icons.nightlight_rounded, 'Vigil', ['prayer', 'watch']),
  ];

  // Social icons - People, Groups, Friends, Relationships (80+ icons)
  static final List<IconDataEntry> _socialIcons = [
    // ═══════════════════════════════════════════════════════════════
    // INDIVIDUAL PEOPLE
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.person_rounded, 'Person', ['individual', 'user', 'single']),
    IconDataEntry(Icons.person_outline_rounded, 'Person Outline', ['individual', 'user']),
    IconDataEntry(Icons.person_2_rounded, 'Person 2', ['individual', 'user', 'member']),
    IconDataEntry(Icons.person_3_rounded, 'Person 3', ['individual', 'user', 'profile']),
    IconDataEntry(Icons.person_4_rounded, 'Person 4', ['individual', 'user', 'avatar']),
    IconDataEntry(Icons.account_circle_rounded, 'Account', ['profile', 'individual', 'user']),
    IconDataEntry(Icons.face_rounded, 'Face', ['person', 'individual', 'avatar']),
    IconDataEntry(Icons.face_2_rounded, 'Face 2', ['person', 'individual', 'smile']),
    IconDataEntry(Icons.face_3_rounded, 'Face 3', ['person', 'woman', 'female']),
    IconDataEntry(Icons.face_4_rounded, 'Face 4', ['person', 'elder', 'senior']),
    IconDataEntry(Icons.face_5_rounded, 'Face 5', ['person', 'cool', 'glasses']),
    IconDataEntry(Icons.face_6_rounded, 'Face 6', ['person', 'young', 'youth']),
    IconDataEntry(Icons.man_rounded, 'Man', ['male', 'adult', 'individual']),
    IconDataEntry(Icons.woman_rounded, 'Woman', ['female', 'adult', 'individual']),
    IconDataEntry(Icons.boy_rounded, 'Boy', ['male', 'child', 'young']),
    IconDataEntry(Icons.girl_rounded, 'Girl', ['female', 'child', 'young']),
    IconDataEntry(Icons.elderly_rounded, 'Elderly', ['senior', 'old', 'grandparent']),
    IconDataEntry(Icons.elderly_woman_rounded, 'Elderly Woman', ['senior', 'grandmother']),
    IconDataEntry(Icons.child_care_rounded, 'Baby', ['infant', 'child', 'newborn']),
    IconDataEntry(Icons.pregnant_woman_rounded, 'Pregnant', ['mother', 'expecting']),
    
    // ═══════════════════════════════════════════════════════════════
    // PAIRS & COUPLES
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.people_rounded, 'Two People', ['pair', 'couple', 'duo', 'friends']),
    IconDataEntry(Icons.people_outline_rounded, 'Two People Outline', ['pair', 'friends']),
    IconDataEntry(Icons.people_alt_rounded, 'People Alt', ['pair', 'couple', 'together']),
    IconDataEntry(Icons.diversity_1_rounded, 'Couple', ['love', 'pair', 'together', 'friends']),
    IconDataEntry(Icons.diversity_2_rounded, 'Partners', ['friends', 'couple', 'bond']),
    IconDataEntry(Icons.wc_rounded, 'Couple WC', ['male', 'female', 'pair']),
    IconDataEntry(Icons.handshake_rounded, 'Handshake', ['friends', 'agreement', 'meet']),
    IconDataEntry(Icons.connect_without_contact_rounded, 'Connected', ['friends', 'bond', 'link']),
    
    // ═══════════════════════════════════════════════════════════════
    // GROUPS & TEAMS
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.group_rounded, 'Group', ['team', 'people', 'members', 'friends']),
    IconDataEntry(Icons.group_add_rounded, 'Add to Group', ['invite', 'join', 'friends']),
    IconDataEntry(Icons.group_remove_rounded, 'Remove from Group', ['leave', 'exit']),
    IconDataEntry(Icons.group_off_rounded, 'Group Off', ['disbanded', 'separated']),
    IconDataEntry(Icons.groups_rounded, 'Groups', ['team', 'crowd', 'many', 'friends']),
    IconDataEntry(Icons.groups_2_rounded, 'Groups 2', ['team', 'large', 'community']),
    IconDataEntry(Icons.groups_3_rounded, 'Groups 3', ['team', 'organization']),
    IconDataEntry(Icons.diversity_3_rounded, 'Diverse Group', ['team', 'inclusive', 'friends']),
    IconDataEntry(Icons.reduce_capacity_rounded, 'Small Group', ['few', 'intimate']),
    IconDataEntry(Icons.safety_divider_rounded, 'Divided', ['separate', 'distance']),
    
    // ═══════════════════════════════════════════════════════════════
    // FAMILY
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.family_restroom_rounded, 'Family', ['parents', 'children', 'home']),
    IconDataEntry(Icons.escalator_warning_rounded, 'Parent Child', ['family', 'guardian']),
    IconDataEntry(Icons.child_friendly_rounded, 'Child Friendly', ['family', 'kids', 'safe']),
    IconDataEntry(Icons.stroller_rounded, 'Stroller', ['baby', 'family', 'parent']),
    IconDataEntry(Icons.baby_changing_station_rounded, 'Baby Care', ['family', 'infant']),
    IconDataEntry(Icons.crib_rounded, 'Crib', ['baby', 'family', 'infant']),
    IconDataEntry(Icons.home_rounded, 'Home', ['family', 'house', 'domestic']),
    IconDataEntry(Icons.house_rounded, 'House', ['family', 'home', 'residence']),
    IconDataEntry(Icons.cottage_rounded, 'Cottage', ['family', 'home', 'cozy']),
    
    // ═══════════════════════════════════════════════════════════════
    // FRIENDSHIP & RELATIONSHIPS
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.favorite_rounded, 'Love', ['heart', 'friend', 'affection']),
    IconDataEntry(Icons.favorite_border_rounded, 'Like', ['heart', 'friend', 'fond']),
    IconDataEntry(Icons.loyalty_rounded, 'Loyalty', ['faithful', 'friend', 'devoted']),
    IconDataEntry(Icons.volunteer_activism_rounded, 'Care', ['help', 'friend', 'support']),
    IconDataEntry(Icons.emoji_people_rounded, 'Social', ['people', 'friend', 'interact']),
    IconDataEntry(Icons.celebration_rounded, 'Celebration', ['party', 'friends', 'together']),
    IconDataEntry(Icons.cake_rounded, 'Birthday', ['celebrate', 'friends', 'party']),
    IconDataEntry(Icons.local_bar_rounded, 'Hangout', ['friends', 'drink', 'social']),
    IconDataEntry(Icons.sports_bar_rounded, 'Sports Bar', ['friends', 'watch', 'social']),
    IconDataEntry(Icons.nightlife_rounded, 'Night Out', ['friends', 'party', 'social']),
    IconDataEntry(Icons.restaurant_rounded, 'Dinner', ['friends', 'eat', 'social']),
    IconDataEntry(Icons.local_cafe_rounded, 'Coffee', ['friends', 'meet', 'chat']),
    
    // ═══════════════════════════════════════════════════════════════
    // COMMUNICATION & INTERACTION
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.chat_rounded, 'Chat', ['talk', 'friends', 'message']),
    IconDataEntry(Icons.chat_bubble_rounded, 'Message', ['talk', 'friends', 'text']),
    IconDataEntry(Icons.forum_rounded, 'Forum', ['discuss', 'group', 'social']),
    IconDataEntry(Icons.question_answer_rounded, 'Conversation', ['talk', 'friends', 'dialog']),
    IconDataEntry(Icons.call_rounded, 'Call', ['phone', 'friends', 'talk']),
    IconDataEntry(Icons.video_call_rounded, 'Video Call', ['friends', 'face', 'online']),
    IconDataEntry(Icons.duo_rounded, 'Duo Call', ['friends', 'video', 'chat']),
    IconDataEntry(Icons.share_rounded, 'Share', ['social', 'friends', 'post']),
    IconDataEntry(Icons.public_rounded, 'Public', ['world', 'social', 'global']),
    IconDataEntry(Icons.language_rounded, 'Global', ['world', 'social', 'connect']),
    
    // ═══════════════════════════════════════════════════════════════
    // SOCIAL MEDIA BRANDS (Font Awesome)
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(FontAwesomeIcons.instagram, 'Instagram', ['social', 'media', 'photo', 'ig']),
    IconDataEntry(FontAwesomeIcons.facebook, 'Facebook', ['social', 'media', 'fb']),
    IconDataEntry(FontAwesomeIcons.twitter, 'Twitter', ['social', 'media', 'x']),
    IconDataEntry(FontAwesomeIcons.xTwitter, 'X', ['social', 'media', 'twitter']),
    IconDataEntry(FontAwesomeIcons.tiktok, 'TikTok', ['social', 'media', 'video']),
    IconDataEntry(FontAwesomeIcons.youtube, 'YouTube', ['social', 'media', 'video']),
    IconDataEntry(FontAwesomeIcons.whatsapp, 'WhatsApp', ['social', 'chat', 'message']),
    IconDataEntry(FontAwesomeIcons.telegram, 'Telegram', ['social', 'chat', 'message']),
    IconDataEntry(FontAwesomeIcons.snapchat, 'Snapchat', ['social', 'media', 'photo']),
    IconDataEntry(FontAwesomeIcons.linkedin, 'LinkedIn', ['social', 'work', 'professional']),
    IconDataEntry(FontAwesomeIcons.github, 'GitHub', ['social', 'code', 'dev']),
    IconDataEntry(FontAwesomeIcons.discord, 'Discord', ['social', 'chat', 'gaming']),
    IconDataEntry(FontAwesomeIcons.reddit, 'Reddit', ['social', 'news', 'forum']),
    IconDataEntry(FontAwesomeIcons.pinterest, 'Pinterest', ['social', 'media', 'pin']),
    IconDataEntry(FontAwesomeIcons.spotify, 'Spotify', ['music', 'social', 'audio']),
    IconDataEntry(FontAwesomeIcons.twitch, 'Twitch', ['social', 'stream', 'gaming']),
    IconDataEntry(FontAwesomeIcons.medium, 'Medium', ['social', 'blog', 'read']),
    IconDataEntry(FontAwesomeIcons.slack, 'Slack', ['social', 'work', 'chat']),
    IconDataEntry(FontAwesomeIcons.skype, 'Skype', ['social', 'call', 'chat']),
    IconDataEntry(FontAwesomeIcons.facebookMessenger, 'Messenger', ['social', 'chat', 'fb']),
    
    // ═══════════════════════════════════════════════════════════════
    // MATERIAL SOCIAL ICONS
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.thumb_up_rounded, 'Like', ['approve', 'social', 'react']),
    IconDataEntry(Icons.thumb_down_rounded, 'Dislike', ['disapprove', 'social']),
    IconDataEntry(Icons.comment_rounded, 'Comment', ['reply', 'social', 'discuss']),
    IconDataEntry(Icons.mode_comment_rounded, 'Comments', ['discuss', 'social']),
    IconDataEntry(Icons.add_comment_rounded, 'Add Comment', ['reply', 'social']),
    IconDataEntry(Icons.insert_comment_rounded, 'Insert Comment', ['social', 'feedback']),
    IconDataEntry(Icons.tag_rounded, 'Tag', ['mention', 'social', 'label']),
    IconDataEntry(Icons.alternate_email_rounded, 'Mention', ['tag', 'social', 'at']),
    IconDataEntry(Icons.notifications_rounded, 'Notifications', ['alert', 'social', 'updates']),
    IconDataEntry(Icons.notification_add_rounded, 'Follow', ['subscribe', 'social']),
    IconDataEntry(Icons.person_add_rounded, 'Add Friend', ['invite', 'social', 'connect']),
    IconDataEntry(Icons.person_add_alt_rounded, 'Friend Request', ['invite', 'social']),
    IconDataEntry(Icons.person_remove_rounded, 'Remove Friend', ['unfriend', 'social']),
    IconDataEntry(Icons.block_rounded, 'Block', ['unfriend', 'social', 'remove']),
    IconDataEntry(Icons.report_rounded, 'Report', ['flag', 'social', 'warn']),
    
    // ═══════════════════════════════════════════════════════════════
    // PROFESSIONAL & WORK
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.badge_rounded, 'Badge', ['id', 'work', 'employee']),
    IconDataEntry(Icons.business_center_rounded, 'Business', ['work', 'professional']),
    IconDataEntry(Icons.work_rounded, 'Work', ['job', 'professional', 'career']),
    IconDataEntry(Icons.work_outline_rounded, 'Work Outline', ['job', 'professional']),
    IconDataEntry(Icons.corporate_fare_rounded, 'Corporate', ['company', 'organization']),
    IconDataEntry(Icons.meeting_room_rounded, 'Meeting Room', ['work', 'group', 'discuss']),
    IconDataEntry(Icons.co_present_rounded, 'Present', ['meeting', 'work', 'team']),
    IconDataEntry(Icons.interpreter_mode_rounded, 'Speaker', ['meeting', 'present', 'talk']),
    IconDataEntry(Icons.supervised_user_circle_rounded, 'Supervised', ['manage', 'team', 'work']),
    IconDataEntry(Icons.admin_panel_settings_rounded, 'Admin', ['manage', 'control', 'lead']),
    IconDataEntry(Icons.manage_accounts_rounded, 'Manager', ['lead', 'team', 'supervise']),
    
    // ═══════════════════════════════════════════════════════════════
    // ACTIVITIES & EVENTS
    // ═══════════════════════════════════════════════════════════════
    IconDataEntry(Icons.event_rounded, 'Event', ['social', 'gathering', 'party']),
    IconDataEntry(Icons.event_available_rounded, 'Available', ['social', 'free', 'open']),
    IconDataEntry(Icons.event_busy_rounded, 'Busy', ['unavailable', 'occupied']),
    IconDataEntry(Icons.sports_rounded, 'Sports', ['activity', 'friends', 'game']),
    IconDataEntry(Icons.sports_soccer_rounded, 'Soccer', ['game', 'friends', 'team']),
    IconDataEntry(Icons.sports_basketball_rounded, 'Basketball', ['game', 'friends', 'team']),
    IconDataEntry(Icons.theater_comedy_rounded, 'Entertainment', ['fun', 'friends', 'show']),
    IconDataEntry(Icons.movie_rounded, 'Movie', ['watch', 'friends', 'cinema']),
    IconDataEntry(Icons.attractions_rounded, 'Attractions', ['fun', 'friends', 'outing']),
    IconDataEntry(Icons.hiking_rounded, 'Hiking', ['outdoor', 'friends', 'activity']),
    IconDataEntry(Icons.directions_walk_rounded, 'Walk', ['friends', 'stroll', 'together']),
    IconDataEntry(Icons.directions_run_rounded, 'Run', ['exercise', 'friends', 'jog']),
    IconDataEntry(Icons.directions_bike_rounded, 'Bike', ['cycle', 'friends', 'ride']),
  ];

  // Security icons
  static final List<IconDataEntry> _securityIcons = ExtendedIcons3.icons
      .where((i) => i.keywords.any((k) => 
          ['secure', 'lock', 'key', 'password', 'protect', 'shield', 'privacy'].contains(k)))
      .toList();

  // File icons
  static final List<IconDataEntry> _fileIcons = ExtendedIcons3.icons
      .where((i) => i.keywords.any((k) => 
          ['file', 'folder', 'document', 'copy', 'paste', 'download', 'upload'].contains(k)))
      .toList();
}

/// Category data structure
class CategoryData {
  final IconData icon;
  final List<IconDataEntry> icons;
  
  const CategoryData(this.icon, this.icons);
}
