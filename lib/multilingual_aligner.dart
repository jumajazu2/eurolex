/// Multilingual line alignment for EUR-Lex documents.
///
/// Aligns per-language line arrays (each entry: [text, cssClass]) to a common
/// backbone before they are zipped and uploaded to OpenSearch.
///
/// Algorithm: patience-diff style O(n log n) per language pair.
///   Each line is reduced to a language-invariant key: a number fingerprint
///   when available ("article_1", "annex_iv", "(a)"), otherwise the CSS class
///   label ("c:normal", "c:sti-art-ti", ...).  An inverted index maps keys to
///   sorted positions in the target language array; for each reference line a
///   binary search finds the next available matching position.  This handles
///   100k-line documents without size limits or approximation.
///
/// Entry point: [alignMultilingualLines].

// --------------------------------------------------------------------------
// Line-key extraction
// --------------------------------------------------------------------------

/// Article/annex/chapter headings - numbers are language-invariant.
final _kHeadingRe = RegExp(
  r'^(article|annex|chapter|section|title|deel|titre|titel|kapitel|artículo|articolo|artigo|artykuł|článek|článok|cikk|artikkel|straipsnio|artikel)\s+([ivxlcdm]+|\d+)',
  caseSensitive: false,
);

/// Leading enumerator: "1.", "(a)", "(1)", "i.", roman numerals followed by "."
final _kLeadEnumRe = RegExp(
  r'^(?:(\d+)\.|\(([a-z\d]+)\)|([ivxlcdm]{1,5})\.)\s',
);

/// Returns a language-invariant fingerprint if the line starts with a numbered
/// structural element, otherwise null.
String? _fingerprint(List<String> line) {
  final text = line[0].trim();
  final m1 = _kHeadingRe.firstMatch(text);
  if (m1 != null) {
    return '${m1.group(1)!.toLowerCase()}_${m1.group(2)!.toLowerCase()}';
  }
  final m2 = _kLeadEnumRe.firstMatch(text);
  if (m2 != null) return m2.group(0)!.trim().toLowerCase();
  return null;
}

/// The key used for matching two lines across languages.
/// Priority: fingerprint > table code text > CSS class label.
String _lineKey(List<String> line) {
  final fp = _fingerprint(line);
  if (fp != null) return 'fp:$fp';
  final cls = line.length > 1 ? line[1] : '';
  // Table code cells contain commodity/legal codes that are language-invariant.
  // Using the actual text gives far more discriminating keys than the class alone.
  if (cls.contains('tbl-cod') || cls.contains('tbl-num')) {
    final text = line[0].trim().replaceAll(RegExp(r'\s+'), '');
    if (text.isNotEmpty) return 'cod:$text';
  }
  return cls.isNotEmpty ? 'c:$cls' : 'u';
}

// --------------------------------------------------------------------------
// Patience-diff style O(n log n) aligner
// --------------------------------------------------------------------------

/// Returns (refIdx, otherIdx) matched pairs using a greedy order-preserving
/// match on line keys.
///
/// For each line in [a] the inverted index of [b] is binary-searched for the
/// next available position with the same key.  Time: O(n log n).
/// Space: O(n + m).
List<(int, int)> _patientAlign(List<List<String>> a, List<List<String>> b) {
  if (a.isEmpty || b.isEmpty) return const [];

  // Build inverted index: key -> sorted list of positions in b
  final bIndex = <String, List<int>>{};
  for (var j = 0; j < b.length; j++) {
    (bIndex[_lineKey(b[j])] ??= []).add(j);
  }

  final matches = <(int, int)>[];
  var minBIdx = 0; // monotone lower bound enforces order

  for (var ai = 0; ai < a.length; ai++) {
    final candidates = bIndex[_lineKey(a[ai])];
    if (candidates == null) continue;

    // Binary search: first position in b >= minBIdx
    var lo = 0, hi = candidates.length;
    while (lo < hi) {
      final mid = (lo + hi) >>> 1;
      if (candidates[mid] < minBIdx)
        lo = mid + 1;
      else
        hi = mid;
    }
    if (lo < candidates.length) {
      final bj = candidates[lo];
      matches.add((ai, bj));
      minBIdx = bj + 1;
    }
  }

  return matches;
}

// --------------------------------------------------------------------------
// Progress callback
// --------------------------------------------------------------------------

/// Called after each language pair is aligned.
/// [lang] language just finished, [done]/[total] counts,
/// [elapsed]/[estimated] wall-clock times,
/// [refLen] source units, [otherLen] target units, [matched] matched pairs,
/// [alignedRows] the actual aligned output rows for this language.
typedef AlignmentProgressCallback =
    void Function(
      String lang,
      int done,
      int total,
      Duration elapsed,
      Duration estimated,
      int refLen,
      int otherLen,
      int matched,
      List<List<String>> alignedRows,
    );

// --------------------------------------------------------------------------
// Public entry point
// --------------------------------------------------------------------------

/// Aligns all language arrays in [map] to the reference language (EN if
/// present, otherwise the first key).
///
/// Returns a new map where every language array has the same length as the
/// reference; unmatched positions carry ['', ''].
/// If all arrays already have the same length the original map is returned
/// unchanged (fast path).
///
/// The function is async so that the Flutter UI thread remains responsive.
/// [onProgress] is called after each language pair with timing information.
Future<Map<String, List<List<String>>>> alignMultilingualLines(
  Map<String, List<List<String>>> map, {
  AlignmentProgressCallback? onProgress,
}) async {
  if (map.length < 2) return map;

  // Fast path: already aligned
  final lengths = map.values.map((v) => v.length).toSet();
  if (lengths.length == 1) return map;

  final refLang = map.containsKey('EN') ? 'EN' : map.keys.first;
  final reference = map[refLang]!;
  final otherLangs = map.keys.where((l) => l != refLang).toList();
  final total = otherLangs.length;

  print(
    'alignMultilingualLines: ref=$refLang (${reference.length} lines), '
    'aligning $total language(s): ${otherLangs.join(', ')}',
  );

  final result = <String, List<List<String>>>{refLang: reference};
  final sw = Stopwatch()..start();

  for (var i = 0; i < total; i++) {
    final lang = otherLangs[i];

    // Yield to the Flutter event loop so the UI can repaint between languages
    await Future.delayed(Duration.zero);

    final langSw = Stopwatch()..start();
    final other = map[lang]!;

    // Skip alignment when the language has too few lines relative to the
    // reference — this signals a bad parse or download, not a real structural
    // difference.  Aligning would leave nearly all positions as ['', ''],
    // making the entire language appear empty in search results.
    if (other.isEmpty) {
      print(
        'alignMultilingualLines [$lang] SKIPPED — 0 lines (download/parse failure)',
      );
      result[lang] = List.filled(reference.length, const ['', '']);
      onProgress?.call(
        lang,
        i + 1,
        total,
        sw.elapsed,
        sw.elapsed,
        reference.length,
        0,
        0,
        result[lang]!,
      );
      continue;
    }
    final ratio = other.length / reference.length;
    if (ratio < 0.5) {
      print(
        'alignMultilingualLines [$lang] SKIPPED alignment (ratio ${ratio.toStringAsFixed(2)} < 0.50)'
        ' — using positional for first ${other.length} rows',
      );
      result[lang] = List.generate(
        reference.length,
        (ri) => ri < other.length ? other[ri] : const ['', ''],
      );
      onProgress?.call(
        lang,
        i + 1,
        total,
        sw.elapsed,
        sw.elapsed,
        reference.length,
        other.length,
        other.length,
        result[lang]!,
      );
      continue;
    }

    final matches = _patientAlign(reference, other);
    final matchRatio =
        reference.length > 0 ? matches.length / reference.length : 0.0;

    List<List<String>> aligned;
    if (matchRatio < 0.60) {
      // Match rate too low: alignment is unreliable for this language.
      // Fall back to positional so no rows are left empty in the upload.
      print(
        'alignMultilingualLines [$lang] LOW MATCH ${(matchRatio * 100).toStringAsFixed(1)}%'
        ' — falling back to positional alignment',
      );
      aligned = List.generate(
        reference.length,
        (ri) => ri < other.length ? other[ri] : const ['', ''],
      );
    } else {
      // Build lookup: refIdx -> otherIdx
      final lookup = <int, int>{for (final (ri, oi) in matches) ri: oi};
      aligned = List.generate(
        reference.length,
        (ri) => lookup[ri] != null ? other[lookup[ri]!] : const ['', ''],
      );
    }
    result[lang] = aligned;
    langSw.stop();

    final elapsed = sw.elapsed;
    final perLang = elapsed.inMilliseconds / (i + 1);
    final estimated = Duration(milliseconds: (total * perLang).round());
    final remaining = estimated - elapsed;

    final pct = (matchRatio * 100).toStringAsFixed(1);
    print(
      'alignMultilingualLines [$lang] ${i + 1}/$total'
      ' ref:${reference.length} other:${other.length}'
      ' matched:${matches.length} ($pct%)'
      ' ${langSw.elapsedMilliseconds}ms'
      ' elapsed:${elapsed.inSeconds}s'
      ' remaining:~${remaining.inSeconds < 0 ? 0 : remaining.inSeconds}s',
    );

    onProgress?.call(
      lang,
      i + 1,
      total,
      elapsed,
      estimated,
      reference.length,
      other.length,
      matches.length,
      aligned,
    );
  }

  sw.stop();
  print('alignMultilingualLines: done ${sw.elapsed.inMilliseconds}ms');
  return result;
}
