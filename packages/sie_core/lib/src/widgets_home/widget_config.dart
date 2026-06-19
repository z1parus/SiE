import 'dart:convert';
import 'package:flutter/material.dart';
import 'widget_size_bucket.dart';

enum WidgetThemeMode { followApp, forceDark, forceLight }
enum WidgetBackgroundStyle { flat, glass, gradient, transparent }

class WidgetConfig {
  final int appWidgetId;
  final String moduleId;
  final WidgetSizeBucket sizeBucket;
  final WidgetThemeMode themeOverride;
  final Color? accentOverride;
  final WidgetBackgroundStyle bgStyle;
  final Map<String, dynamic> contentOptions;

  const WidgetConfig({
    required this.appWidgetId,
    required this.moduleId,
    required this.sizeBucket,
    this.themeOverride = WidgetThemeMode.followApp,
    this.accentOverride,
    this.bgStyle = WidgetBackgroundStyle.flat,
    this.contentOptions = const {},
  });

  String get signature => jsonEncode(toMap());

  Map<String, dynamic> toMap() => {
    'appWidgetId': appWidgetId,
    'moduleId': moduleId,
    'sizeBucket': sizeBucket.name,
    'themeOverride': themeOverride.name,
    'accentOverride': accentOverride?.value,
    'bgStyle': bgStyle.name,
    'contentOptions': contentOptions,
  };

  factory WidgetConfig.fromMap(Map<String, dynamic> m) => WidgetConfig(
    appWidgetId: m['appWidgetId'] as int,
    moduleId: m['moduleId'] as String,
    sizeBucket: WidgetSizeBucket.values.firstWhere(
      (e) => e.name == m['sizeBucket'],
      orElse: () => WidgetSizeBucket.medium,
    ),
    themeOverride: WidgetThemeMode.values.firstWhere(
      (e) => e.name == m['themeOverride'],
      orElse: () => WidgetThemeMode.followApp,
    ),
    accentOverride: m['accentOverride'] != null
        ? Color(m['accentOverride'] as int)
        : null,
    bgStyle: WidgetBackgroundStyle.values.firstWhere(
      (e) => e.name == m['bgStyle'],
      orElse: () => WidgetBackgroundStyle.flat,
    ),
    contentOptions: (m['contentOptions'] as Map<String, dynamic>?) ?? {},
  );

  WidgetConfig copyWith({
    WidgetSizeBucket? sizeBucket,
    WidgetThemeMode? themeOverride,
    Color? accentOverride,
    bool clearAccent = false,
    WidgetBackgroundStyle? bgStyle,
    Map<String, dynamic>? contentOptions,
  }) => WidgetConfig(
    appWidgetId: appWidgetId,
    moduleId: moduleId,
    sizeBucket: sizeBucket ?? this.sizeBucket,
    themeOverride: themeOverride ?? this.themeOverride,
    accentOverride: clearAccent ? null : (accentOverride ?? this.accentOverride),
    bgStyle: bgStyle ?? this.bgStyle,
    contentOptions: contentOptions ?? this.contentOptions,
  );
}
