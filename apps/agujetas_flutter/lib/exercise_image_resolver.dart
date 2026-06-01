import 'dart:convert';

import 'package:flutter/services.dart';

class ResolvedExerciseImage {
  const ResolvedExerciseImage({
    required this.assetPath,
    required this.status,
    required this.reviewStatus,
    required this.source,
    required this.isFallback,
    required this.legacyUriBlocked,
    this.imageId,
  });

  final String assetPath;
  final String status;
  final String reviewStatus;
  final String source;
  final bool isFallback;
  final bool legacyUriBlocked;
  final String? imageId;

  String get uri => imageId == null ? '' : 'agujetas-image://$imageId';

  bool get needsReview =>
      isFallback || reviewStatus == 'pending' || reviewStatus == 'priority';

  String get qualityLabel {
    if (isFallback) return 'Sin asset';
    return switch (reviewStatus) {
      'approved' => 'Aprobada',
      'priority' => 'Prioridad',
      'pending' => 'Revisar',
      _ => 'Revisar',
    };
  }
}

class ExerciseImageAuditSummary {
  const ExerciseImageAuditSummary({
    required this.entries,
    required this.generated,
    required this.priorityReview,
    required this.pendingReview,
    required this.placeholders,
  });

  final int entries;
  final int generated;
  final int priorityReview;
  final int pendingReview;
  final int placeholders;

  int get reviewed => entries - pendingReview - priorityReview;

  double get reviewedRatio => entries == 0 ? 0 : reviewed / entries;
}

class ExerciseImageResolver {
  ExerciseImageResolver._();

  static final instance = ExerciseImageResolver._();

  Future<_ExerciseImageManifest>? _manifestFuture;

  Future<ResolvedExerciseImage> resolve({
    required String exerciseId,
    required String name,
    required String muscleGroup,
    String? imageUri,
  }) async {
    final manifest = await _loadManifest();
    final trimmedUri = imageUri?.trim();
    final legacyUriBlocked = trimmedUri?.startsWith('app-image://') == true;
    final explicitImageId = _agujetasImageId(trimmedUri);

    final entry = explicitImageId == null
        ? null
        : manifest.byImageId[explicitImageId];
    final matched =
        entry ??
        manifest.byExerciseKey[_normalize(exerciseId)] ??
        manifest.byName[_normalize(name)];

    if (matched != null) {
      return ResolvedExerciseImage(
        assetPath: matched.assetPath,
        status: matched.status,
        reviewStatus: matched.reviewStatus,
        source: matched.source,
        isFallback: false,
        legacyUriBlocked: legacyUriBlocked,
        imageId: matched.imageId,
      );
    }

    return ResolvedExerciseImage(
      assetPath: manifest.placeholderFor(muscleGroup),
      status: 'placeholder',
      reviewStatus: 'missing',
      source: 'agujetas-placeholder',
      isFallback: true,
      legacyUriBlocked: legacyUriBlocked,
    );
  }

  Future<ExerciseImageAuditSummary> auditSummary() async {
    final manifest = await _loadManifest();
    return manifest.summary;
  }

  Future<_ExerciseImageManifest> _loadManifest() {
    return _manifestFuture ??= _ExerciseImageManifest.load();
  }
}

String? sanitizeExerciseImageUri(String? imageUri) {
  final trimmed = imageUri?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (trimmed.startsWith('app-image://')) return null;
  return trimmed;
}

String? _agujetasImageId(String? imageUri) {
  if (imageUri == null || !imageUri.startsWith('agujetas-image://')) {
    return null;
  }
  final id = imageUri.substring('agujetas-image://'.length).trim();
  return id.isEmpty ? null : id;
}

String _normalize(String value) {
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'ã': 'a',
    'Á': 'a',
    'À': 'a',
    'Ä': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'É': 'e',
    'È': 'e',
    'Ë': 'e',
    'Ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'Í': 'i',
    'Ì': 'i',
    'Ï': 'i',
    'Î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'Ó': 'o',
    'Ò': 'o',
    'Ö': 'o',
    'Ô': 'o',
    'Õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'Ú': 'u',
    'Ù': 'u',
    'Ü': 'u',
    'Û': 'u',
    'ñ': 'n',
    'Ñ': 'n',
    'ç': 'c',
    'Ç': 'c',
  };
  final buffer = StringBuffer();
  for (final codePoint in value.runes) {
    final char = String.fromCharCode(codePoint);
    buffer.write(replacements[char] ?? char);
  }
  return buffer
      .toString()
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

class _ExerciseImageManifest {
  const _ExerciseImageManifest({
    required this.byImageId,
    required this.byExerciseKey,
    required this.byName,
    required this.placeholdersByMuscle,
    required this.summary,
  });

  final Map<String, _ExerciseImageEntry> byImageId;
  final Map<String, _ExerciseImageEntry> byExerciseKey;
  final Map<String, _ExerciseImageEntry> byName;
  final Map<String, String> placeholdersByMuscle;
  final ExerciseImageAuditSummary summary;

  static Future<_ExerciseImageManifest> load() async {
    final raw = await rootBundle.loadString(
      'assets/exercise_images/agujetas-image-manifest.json',
    );
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    final counts = decoded['counts'] as Map<String, Object?>? ?? const {};
    final entries = (decoded['entries'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((raw) => _ExerciseImageEntry.fromJson(raw.cast<String, Object?>()))
        .toList();

    final byImageId = <String, _ExerciseImageEntry>{};
    final byExerciseKey = <String, _ExerciseImageEntry>{};
    final byName = <String, _ExerciseImageEntry>{};
    final placeholdersByMuscle = <String, String>{};

    for (final entry in entries) {
      byImageId[entry.imageId] = entry;
      byExerciseKey.putIfAbsent(entry.exerciseKey, () => entry);
      byName.putIfAbsent(entry.normalizedName, () => entry);
      placeholdersByMuscle.putIfAbsent(
        _normalize(entry.muscleGroup),
        () => entry.placeholderAssetPath,
      );
    }

    placeholdersByMuscle.putIfAbsent(
      'general',
      () => 'assets/exercise_images/placeholders/placeholder_general.svg',
    );

    return _ExerciseImageManifest(
      byImageId: byImageId,
      byExerciseKey: byExerciseKey,
      byName: byName,
      placeholdersByMuscle: placeholdersByMuscle,
      summary: ExerciseImageAuditSummary(
        entries: _jsonInt(counts['entries']) ?? entries.length,
        generated: _jsonInt(counts['generated']) ?? entries.length,
        priorityReview: _jsonInt(counts['priorityReview']) ?? 0,
        pendingReview: _jsonInt(counts['pendingReview']) ?? 0,
        placeholders:
            _jsonInt(counts['placeholders']) ?? placeholdersByMuscle.length,
      ),
    );
  }

  String placeholderFor(String muscleGroup) {
    return placeholdersByMuscle[_normalize(muscleGroup)] ??
        placeholdersByMuscle['general']!;
  }
}

class _ExerciseImageEntry {
  const _ExerciseImageEntry({
    required this.imageId,
    required this.exerciseKey,
    required this.normalizedName,
    required this.muscleGroup,
    required this.assetPath,
    required this.placeholderAssetPath,
    required this.status,
    required this.reviewStatus,
    required this.source,
  });

  final String imageId;
  final String exerciseKey;
  final String normalizedName;
  final String muscleGroup;
  final String assetPath;
  final String placeholderAssetPath;
  final String status;
  final String reviewStatus;
  final String source;

  factory _ExerciseImageEntry.fromJson(Map<String, Object?> json) {
    return _ExerciseImageEntry(
      imageId: json['imageId']?.toString() ?? '',
      exerciseKey: json['exerciseKey']?.toString() ?? '',
      normalizedName: json['normalizedName']?.toString() ?? '',
      muscleGroup: json['muscleGroup']?.toString() ?? 'General',
      assetPath: json['assetPath']?.toString() ?? '',
      placeholderAssetPath:
          json['placeholderAssetPath']?.toString() ??
          'assets/exercise_images/placeholders/placeholder_general.svg',
      status: json['status']?.toString() ?? 'generated',
      reviewStatus: json['reviewStatus']?.toString() ?? 'pending',
      source: json['source']?.toString() ?? 'agujetas-generated',
    );
  }
}

int? _jsonInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
