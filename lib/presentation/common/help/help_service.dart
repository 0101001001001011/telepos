import 'dart:convert';

import 'package:flutter/services.dart';

class HelpContent {
  const HelpContent({
    required this.screenId,
    required this.title,
    required this.description,
    this.sections = const [],
    this.tips = const [],
    this.shortcuts = const [],
    this.relatedScreens = const [],
  });

  final String screenId;
  final String title;
  final String description;
  final List<HelpSection> sections;
  final List<String> tips;
  final List<HelpShortcut> shortcuts;
  final List<String> relatedScreens;

  factory HelpContent.fromJson(Map<String, dynamic> json) {
    return HelpContent(
      screenId: json['screenId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sections:
          (json['sections'] as List<dynamic>?)
              ?.map((e) => HelpSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      tips:
          (json['tips'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      shortcuts:
          (json['shortcuts'] as List<dynamic>?)
              ?.map((e) => HelpShortcut.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      relatedScreens:
          (json['relatedScreens'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}

class HelpSection {
  const HelpSection({required this.heading, required this.content});

  final String heading;
  final String content;

  factory HelpSection.fromJson(Map<String, dynamic> json) {
    return HelpSection(
      heading: json['heading'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}

class HelpShortcut {
  const HelpShortcut({required this.key, required this.action});

  final String key;
  final String action;

  factory HelpShortcut.fromJson(Map<String, dynamic> json) {
    return HelpShortcut(
      key: json['key'] as String? ?? '',
      action: json['action'] as String? ?? '',
    );
  }
}

class HelpService {
  HelpService._();

  static final _cache = <String, HelpContent>{};

  static Future<HelpContent?> load(String screenId) async {
    if (_cache.containsKey(screenId)) return _cache[screenId];
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/data/help/$screenId.json',
      );
      final content = HelpContent.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
      _cache[screenId] = content;
      return content;
    } catch (_) {
      return null;
    }
  }

  static String routeToScreenId(String? route) {
    if (route == null || route.isEmpty) return '';

    final path = route.split('?').first;

    return switch (path) {
      '/' => 'splash',
      '/initial-setup' => 'initial_setup',
      '/restore-or-new' => 'restore_or_new',
      '/telegram-setup' => 'telegram_auth',
      '/login' => 'login',
      '/payment' => 'payment',
      '/sale' => 'sale',
      '/refund' => 'refund',
      '/shift' => 'shift',
      '/history' => 'history',
      '/agent' => 'agent',
      '/supply' => 'supply',
      '/cash-operation' => 'cash_operation',
      '/settings' => 'settings',
      '/transport-settings' => 'transport_settings',
      '/printer-settings' => 'printer_settings',
      '/fiscal-settings' => 'fiscal_settings',
      '/sync' => 'sync',
      '/writeoff' => 'writeoff',
      '/inventory' => 'inventory',
      '/additional' => 'additional',
      '/tables' => 'tables',
      '/orders' => 'orders',
      '/service-queue' => 'service_queue',
      '/service-intake' => 'service_intake',
      _ => _handleDynamicRoute(path),
    };
  }

  static String _handleDynamicRoute(String path) {
    if (path.startsWith('/tables/')) return 'table_detail';
    if (path.startsWith('/service-queue/')) return 'service_detail';
    return path.substring(1).replaceAll('-', '_').replaceAll('/', '_');
  }

  static void clearCache() => _cache.clear();
}
