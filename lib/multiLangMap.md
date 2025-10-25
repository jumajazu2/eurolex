List<Map<String, dynamic>> processMultilingualMap(
  Map<String, List<List<String>>> map,
  String indexName,
  String celex,
  String dirID,
  bool simulate,
  bool debug,
  bool paragraphsNotMatched,
  bool namesNotMatched,
) {
  List<Map<String, dynamic>> jsonData =
      []; //to store created json entry for file

  int sequenceID = 0;

  int numParagraphs = map.values.first.length;



//here a part of json will be created dynamically based on the supplied map, including all languages in the map 
  for (int i = 0; i < numParagraphs; i++) {
    Map<String, String> texts = {};
    for (String lang in langsEU) {
      if (map.containsKey(lang) && map[lang]!.length > i) {
        texts["text_${lang.toLowerCase()}"] = map[lang]![i][0]; //texts["lang.toLowerCase()] = map[lang]![i][0];
      }
    }

    // list of langs []

    // Pick the first available class at index i across known langs
    String classForIndex(int i) {
      for (final lang in langsEU) {
        final rows = map[lang];
        if (rows != null && i >= 0 && i < rows.length && rows[i].length > 1) {
          final cls = rows[i][1];
          if (cls.isNotEmpty) return cls;
        }
      }
      return 'unknown';
    }

    if (texts.isNotEmpty) {
      final cls = classForIndex(i);
      final Map<String, dynamic> jsonEntry = {
        "sequence_id": sequenceID++,
        "date": DateTime.now().toUtc().toIso8601String(),
        "language": {"en": "English", "sk": "Slovak", "cz": "Czech"},
        "celex": celex,
        "dir_id": dirID,
        "filename": celex,
        "paragraphsNotMatched": paragraphsNotMatched,
        "namesNotMatched": namesNotMatched,
        "class": cls,
      };

      jsonEntry.addAll(texts);
      jsonData.add(jsonEntry);
    }
  }

  openSearchUpload(jsonData, indexName);
  return jsonData;