import 'dart:convert';
import 'dart:io';
import 'package:LegisTracerEU/file_handling.dart';

/// Status for each language in a document
enum LangStatus {
  pending, // ⏳ Not started
  downloading, // 🔄 Downloading HTML
  parsing, // 🔄 Parsing content
  uploading, // 🔄 Uploading to OpenSearch
  completed, // ✅ Success
  failed, // ❌ Error
  skipped, // ⏭️ Already exists
}

String langStatusEmoji(LangStatus status) {
  switch (status) {
    case LangStatus.pending:
      return '⏳';
    case LangStatus.downloading:
      return '⏬';
    case LangStatus.parsing:
      return '📝';
    case LangStatus.uploading:
      return '⬆️';
    case LangStatus.completed:
      return '✅';
    case LangStatus.failed:
      return '❌';
    case LangStatus.skipped:
      return '⏭️';
  }
}

/// Progress info for a single CELEX document
class CelexProgress {
  final String celex;
  final Map<String, LangStatus>
  languages; // e.g., {'EN': completed, 'FR': downloading}
  final Map<String, int> unitCounts; // Language -> number of units/chunks
  final Map<String, String?> errors; // Language -> error message if failed
  final Map<String, String>
  downloadUrls; // Language -> Europa Cellar download URL
  int?
  httpStatus; // HTTP status code for the entire upload (200, 401, 500, etc.) - one per document
  DateTime? startedAt;
  DateTime? completedAt;

  CelexProgress({
    required this.celex,
    required this.languages,
    Map<String, int>? unitCounts,
    Map<String, String?>? errors,
    Map<String, String>? downloadUrls,
    this.httpStatus,
    this.startedAt,
    this.completedAt,
  }) : unitCounts = unitCounts ?? {},
       errors = errors ?? {},
       downloadUrls = downloadUrls ?? {};

  bool get isCompleted => languages.values.every(
    (s) =>
        s == LangStatus.completed ||
        s == LangStatus.skipped ||
        s == LangStatus.failed,
  );

  bool get hasFailures => languages.values.any((s) => s == LangStatus.failed);

  Map<String, dynamic> toJson() => {
    'celex': celex,
    'languages': languages.map((k, v) => MapEntry(k, v.name)),
    'unitCounts': unitCounts,
    'errors': errors,
    'downloadUrls': downloadUrls,
    'httpStatus': httpStatus, // Single integer, not a map
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory CelexProgress.fromJson(Map<String, dynamic> json) {
    return CelexProgress(
      celex: json['celex'] as String,
      languages: (json['languages'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, LangStatus.values.firstWhere((e) => e.name == v)),
      ),
      unitCounts:
          (json['unitCounts'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          {},
      errors:
          (json['errors'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String?),
          ) ??
          {},
      downloadUrls:
          (json['downloadUrls'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String? ?? ''),
          ) ??
          {},
      httpStatus:
          (json['httpStatus'] as num?)?.toInt(), // Single integer, not a map
      startedAt:
          json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
      completedAt:
          json['completedAt'] != null
              ? DateTime.parse(json['completedAt'])
              : null,
    );
  }
}

/// Manages the progress of an entire harvest session
class HarvestSession {
  final String sessionId;
  final String indexName;
  final int? sector;
  final int? year;
  final DateTime startedAt;
  final Map<String, CelexProgress> documents; // CELEX -> Progress
  final List<String> celexOrder; // Ordered list for display

  int currentPointer = 0;
  DateTime? completedAt;
  String? errorMessage;

  HarvestSession({
    required this.sessionId,
    required this.indexName,
    this.sector,
    this.year,
    DateTime? startedAt,
    Map<String, CelexProgress>? documents,
    List<String>? celexOrder,
    this.currentPointer = 0,
    this.completedAt,
    this.errorMessage,
  }) : startedAt = startedAt ?? DateTime.now(),
       documents = documents ?? {},
       celexOrder = celexOrder ?? [];

  int get totalDocuments => celexOrder.length;

  int get completedDocuments =>
      documents.values.where((d) => d.isCompleted).length;

  int get failedDocuments =>
      documents.values.where((d) => d.hasFailures).length;

  double get progressPercentage =>
      totalDocuments > 0 ? (completedDocuments / totalDocuments) * 100 : 0;

  bool get isCompleted =>
      completedAt != null || completedDocuments == totalDocuments;

  Duration get elapsedTime =>
      completedAt?.difference(startedAt) ??
      DateTime.now().difference(startedAt);

  Duration? get estimatedTimeRemaining {
    if (completedDocuments == 0) return null;
    final avgTimePerDoc = elapsedTime.inSeconds / completedDocuments;
    final remaining = totalDocuments - completedDocuments;
    return Duration(seconds: (avgTimePerDoc * remaining).round());
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'indexName': indexName,
    'sector': sector,
    'year': year,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'currentPointer': currentPointer,
    'errorMessage': errorMessage,
    'celexOrder': celexOrder,
    'documents': documents.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory HarvestSession.fromJson(Map<String, dynamic> json) {
    return HarvestSession(
      sessionId: json['sessionId'] as String,
      indexName: json['indexName'] as String,
      sector: json['sector'] as int?,
      year: json['year'] as int?,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt:
          json['completedAt'] != null
              ? DateTime.parse(json['completedAt'])
              : null,
      currentPointer: json['currentPointer'] as int? ?? 0,
      errorMessage: json['errorMessage'] as String?,
      celexOrder: (json['celexOrder'] as List<dynamic>?)?.cast<String>() ?? [],
      documents:
          (json['documents'] as Map<String, dynamic>?)?.map(
            (k, v) =>
                MapEntry(k, CelexProgress.fromJson(v as Map<String, dynamic>)),
          ) ??
          {},
    );
  }

  /// Save session to JSON file
  Future<void> save() async {
    try {
      final path = await getFilePath('harvest_sessions/$sessionId.json');
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(JsonEncoder.withIndent('  ').convert(toJson()));
    } catch (e) {
      print('Failed to save harvest session: $e');
    }
  }

  /// Load session from JSON file
  static Future<HarvestSession?> load(String sessionId) async {
    try {
      final path = await getFilePath('harvest_sessions/$sessionId.json');
      final file = File(path);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      return HarvestSession.fromJson(
        jsonDecode(content) as Map<String, dynamic>,
      );
    } catch (e) {
      print('Failed to load harvest session: $e');
      return null;
    }
  }

  /// List all saved sessions
  static Future<List<String>> listSessions() async {
    try {
      final dirPath = await getFilePath('harvest_sessions/');
      final dir = Directory(dirPath);
      await dir.create(recursive: true);
      if (!await dir.exists()) return [];
      return await dir
          .list()
          .where((e) => e.path.endsWith('.json'))
          .map(
            (e) => e.path
                .split(Platform.pathSeparator)
                .last
                .replaceAll('.json', ''),
          )
          .toList();
    } catch (e) {
      print('Failed to list harvest sessions: $e');
      return [];
    }
  }
}
