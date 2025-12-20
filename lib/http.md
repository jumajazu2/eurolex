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



monitoring traffic on server

sudo tcpdump -i lo -s0 -A 'tcp port 9200'
# or for a remote ES host
sudo tcpdump -i eth0 -s0 -A 'host <ES_IP> and tcp port 9200'
# ngrep (human-friendly HTTP) BEST FORMAT //TODO monitoring traffic on server at node.js
sudo ngrep -W byline '^(POST|GET|PUT|DELETE)' 'tcp and port 9200' -d lo


Write a pcap to inspect later in Wireshark
sudo tcpdump -i any -nn -s0 -w /tmp/es_bulk.pcap 'tcp port 9200'

