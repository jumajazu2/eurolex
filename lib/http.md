ingestServer.onRequest = (payload) async {
      final content = payload['source'] ?? '';
      if (content.isEmpty) {
        return {'status': 'error', 'message': 'Empty source text'};
      }

      final count = min(lang1Results.length, min(lang2Results.length, metaCelex.length));
      if (count == 0) {
        return {'status': 'success', 'count': 0, 'results': []};
      }

      final results = List<Map<String, String>>.generate(count, (i) {
        return {
          'lang1_result': lang1Results[i],
          'lang2_result': lang2Results[i],
          'celex': metaCelex[i],
        };
      });

      return {
        'status': 'success',
        'count': results.length,
        'results': results,
      };
    };

