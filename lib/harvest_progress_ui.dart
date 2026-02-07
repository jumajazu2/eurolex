import 'dart:async';
import 'package:flutter/material.dart';
import 'package:LegisTracerEU/harvest_progress.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

/// Helper function to launch URLs
Future<void> launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (await url_launcher.canLaunchUrl(uri)) {
    await url_launcher.launchUrl(uri);
  }
}

/// Optimized widget to display harvest progress with virtualization for thousands of documents
class HarvestProgressWidget extends StatefulWidget {
  final HarvestSession session;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;

  const HarvestProgressWidget({
    Key? key,
    required this.session,
    this.onPause,
    this.onResume,
    this.onCancel,
  }) : super(key: key);

  @override
  State<HarvestProgressWidget> createState() => _HarvestProgressWidgetState();
}

class _HarvestProgressWidgetState extends State<HarvestProgressWidget> {
  int _currentPage = 0;
  int _itemsPerPage = 50; // Default: show 50 documents per page
  bool _showCompletedOnly = false;
  bool _showFailedOnly = false;
  String _searchFilter = '';
  Timer? _refreshTimer;
  late HarvestSession _currentSession;

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session; // Initialize with the initial session
    // Refresh UI every 2 seconds and reload session from disk
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (mounted) {
        // Reload session from disk to get latest updates (even when tab is inactive)
        final reloaded = await HarvestSession.load(widget.session.sessionId);
        if (reloaded != null && mounted) {
          setState(() {
            _currentSession = reloaded;
          });
        } else if (mounted) {
          setState(() {
            // Trigger rebuild even if reload failed
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  List<String> get _filteredCelexList {
    var list = widget.session.celexOrder;

    if (_showCompletedOnly) {
      list =
          list.where((celex) {
            final progress = widget.session.documents[celex];
            return progress != null &&
                progress.isCompleted &&
                !progress.hasFailures;
          }).toList();
    } else if (_showFailedOnly) {
      list =
          list.where((celex) {
            final progress = widget.session.documents[celex];
            return progress != null && progress.hasFailures;
          }).toList();
    }

    if (_searchFilter.isNotEmpty) {
      list =
          list
              .where(
                (celex) =>
                    celex.toLowerCase().contains(_searchFilter.toLowerCase()),
              )
              .toList();
    }

    return list;
  }

  int get _totalPages => (_filteredCelexList.length / _itemsPerPage).ceil();

  @override
  Widget build(BuildContext context) {
    final session = _currentSession;
    final elapsed = session.elapsedTime;
    final estimated = session.estimatedTimeRemaining;
    final filteredList = _filteredCelexList;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with session info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Collection Creation: ${session.sessionId}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize:
                              (Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.fontSize ??
                                  22) *
                              1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Index: ${session.indexName}${session.sector != null ? ' | Sector: ${session.sector}' : ''}${session.year != null ? ' | Year: ${session.year}' : ''}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize:
                              (Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.fontSize ??
                                  14) *
                              1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onPause != null ||
                    widget.onResume != null ||
                    widget.onCancel != null)
                  Row(
                    children: [
                      if (widget.onPause != null)
                        IconButton(
                          icon: const Icon(Icons.pause),
                          onPressed: widget.onPause,
                          tooltip: 'Pause',
                        ),
                      if (widget.onResume != null)
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: widget.onResume,
                          tooltip: 'Resume',
                        ),
                      if (widget.onCancel != null)
                        IconButton(
                          icon: const Icon(Icons.stop),
                          onPressed: widget.onCancel,
                          tooltip: 'Cancel',
                          color: Colors.red,
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress bar and statistics
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: session.progressPercentage / 100,
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${session.completedDocuments}/${session.totalDocuments} documents (${session.progressPercentage.toStringAsFixed(1)}%)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize:
                            (Theme.of(context).textTheme.bodyMedium?.fontSize ??
                                14) *
                            1.25,
                      ),
                    ),
                    Text(
                      'Failed: ${session.failedDocuments}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize:
                            (Theme.of(context).textTheme.bodyMedium?.fontSize ??
                                14) *
                            1.25,
                        color: session.failedDocuments > 0 ? Colors.red : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Time info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Elapsed: ${_formatDuration(elapsed)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize:
                        (Theme.of(context).textTheme.bodySmall?.fontSize ??
                            12) *
                        1.25,
                  ),
                ),
                if (estimated != null)
                  Text(
                    'Remaining: ${_formatDuration(estimated)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize:
                          (Theme.of(context).textTheme.bodySmall?.fontSize ??
                              12) *
                          1.25,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Filters and pagination controls
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Search filter
                SizedBox(
                  width: 200,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Search CELEX',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      suffixIcon:
                          _searchFilter.isNotEmpty
                              ? IconButton(
                                icon: Icon(Icons.clear, size: 16),
                                onPressed:
                                    () => setState(() => _searchFilter = ''),
                              )
                              : null,
                    ),
                    onChanged:
                        (value) => setState(() {
                          _searchFilter = value;
                          _currentPage = 0;
                        }),
                  ),
                ),

                // Items per page selector
                DropdownButton<int>(
                  value: _itemsPerPage,
                  items:
                      [25, 50, 100, 200]
                          .map(
                            (count) => DropdownMenuItem(
                              value: count,
                              child: Text('$count/page'),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) => setState(() {
                        _itemsPerPage = value ?? 50;
                        _currentPage = 0;
                      }),
                ),

                // Filter chips
                FilterChip(
                  label: Text('Completed'),
                  selected: _showCompletedOnly,
                  onSelected:
                      (selected) => setState(() {
                        _showCompletedOnly = selected;
                        _showFailedOnly = false;
                        _currentPage = 0;
                      }),
                ),
                FilterChip(
                  label: Text('Failed'),
                  selected: _showFailedOnly,
                  selectedColor: Colors.red.shade100,
                  onSelected:
                      (selected) => setState(() {
                        _showFailedOnly = selected;
                        _showCompletedOnly = false;
                        _currentPage = 0;
                      }),
                ),

                // Page info
                Text(
                  'Showing ${filteredList.isEmpty ? 0 : _currentPage * _itemsPerPage + 1}-${((_currentPage + 1) * _itemsPerPage).clamp(0, filteredList.length)} of ${filteredList.length}',
                  style: TextStyle(fontSize: 12),
                ),

                // Pagination buttons
                IconButton(
                  icon: Icon(Icons.first_page),
                  onPressed:
                      _currentPage > 0
                          ? () => setState(() => _currentPage = 0)
                          : null,
                  tooltip: 'First page',
                ),
                IconButton(
                  icon: Icon(Icons.chevron_left),
                  onPressed:
                      _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                  tooltip: 'Previous page',
                ),
                Text('${_currentPage + 1} / ${_totalPages.clamp(1, 999999)}'),
                IconButton(
                  icon: Icon(Icons.chevron_right),
                  onPressed:
                      _currentPage < _totalPages - 1
                          ? () => setState(() => _currentPage++)
                          : null,
                  tooltip: 'Next page',
                ),
                IconButton(
                  icon: Icon(Icons.last_page),
                  onPressed:
                      _currentPage < _totalPages - 1
                          ? () => setState(() => _currentPage = _totalPages - 1)
                          : null,
                  tooltip: 'Last page',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Virtualized document list
            Expanded(child: _buildVirtualizedList(filteredList)),
          ],
        ),
      ),
    );
  }

  Widget _buildVirtualizedList(List<String> filteredList) {
    if (filteredList.isEmpty) {
      return Center(child: Text('No documents match the current filter.'));
    }

    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = ((startIndex + _itemsPerPage).clamp(
      0,
      filteredList.length,
    ));
    final pageItems = filteredList.sublist(startIndex, endIndex);

    return ListView.builder(
      itemCount: pageItems.length,
      itemBuilder: (context, index) {
        final globalIndex = startIndex + index;
        final celex = pageItems[index];
        final progress = widget.session.documents[celex];

        return _buildDocumentCard(globalIndex + 1, celex, progress);
      },
    );
  }

  Widget _buildDocumentCard(
    int displayNumber,
    String celex,
    CelexProgress? progress,
  ) {
    if (progress == null) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        child: ListTile(
          leading: CircleAvatar(child: Text('$displayNumber')),
          title: Text(celex, style: TextStyle(fontFamily: 'monospace')),
          subtitle: Text('⏳ Pending'),
        ),
      );
    }

    // Calculate block count validation
    final unitCounts = progress.unitCounts.values.where((c) => c > 0).toList();
    final blocksMatched =
        unitCounts.isNotEmpty && unitCounts.toSet().length == 1;
    final majorityCount = _getMajorityCount(progress.unitCounts);

    // Check for serious error (>25% difference)
    bool hasSeriousError = false;
    if (majorityCount != null && majorityCount > 0) {
      for (final count in unitCounts) {
        final diff = (count - majorityCount).abs() / majorityCount;
        if (diff > 0.25) {
          hasSeriousError = true;
          break;
        }
      }
    }

    final completionStatus =
        progress.isCompleted
            ? '✓ Done'
            : (progress.completedAt != null
                ? '⏳ Processing'
                : '🔄 In progress');
    final errorMsg = progress.errors.values
        .where((e) => e != null && e.isNotEmpty)
        .join('; ');

    final cardColor =
        progress.isCompleted
            ? (progress.hasFailures ? Colors.red.shade50 : Colors.green.shade50)
            : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      color: cardColor,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor:
              progress.hasFailures
                  ? Colors.red
                  : (progress.isCompleted ? Colors.green : Colors.blue),
          child: Text(
            '$displayNumber',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                celex,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                completionStatus,
                style: TextStyle(
                  fontSize: 12,
                  color: progress.hasFailures ? Colors.red : Colors.black87,
                ),
              ),
            ),
            if (progress.httpStatus != null)
              Text(
                'HTTP:${progress.httpStatus}',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        subtitle: Text(
          '${progress.languages.values.where((s) => s == LangStatus.completed).length}/${progress.languages.length} languages completed',
          style: TextStyle(fontSize: 11),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Language status with download links
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children:
                      progress.languages.entries.map((e) {
                        final lang = e.key;
                        final status = e.value;
                        final unitCount = progress.unitCounts[lang] ?? 0;
                        final unitInfo = unitCount > 0 ? ' ($unitCount)' : '';
                        final emoji = langStatusEmoji(status);

                        // Determine if this lang has mismatch
                        final isDifferent =
                            unitCount > 0 &&
                            majorityCount != null &&
                            unitCount != majorityCount;

                        // Check if this specific lang has serious error
                        final isSeriousError =
                            isDifferent &&
                            majorityCount != null &&
                            majorityCount > 0 &&
                            ((unitCount - majorityCount).abs() /
                                    majorityCount) >
                                0.25;

                        final langColor =
                            isSeriousError
                                ? Colors.red
                                : (isDifferent ? Colors.orange : Colors.black);

                        // Get actual download URL from progress
                        final downloadUrl = progress.downloadUrls[lang] ?? '';

                        return InkWell(
                          onTap:
                              downloadUrl.isNotEmpty
                                  ? () => launchUrl(downloadUrl)
                                  : null,
                          child: Chip(
                            label: Text(
                              '$lang$unitInfo $emoji',
                              style: TextStyle(
                                color: langColor,
                                fontWeight:
                                    isDifferent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                fontSize: 11,
                              ),
                            ),
                            backgroundColor:
                                downloadUrl.isNotEmpty
                                    ? Colors.blue.shade50
                                    : null,
                          ),
                        );
                      }).toList(),
                ),

                // Block validation
                if (unitCounts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    blocksMatched
                        ? '✅ Blocks matched'
                        : (hasSeriousError
                            ? '🚨 SERIOUS ERROR: Block count mismatch >25%'
                            : '⚠️ Blocks mismatch'),
                    style: TextStyle(
                      color:
                          hasSeriousError
                              ? Colors.red
                              : (blocksMatched ? Colors.green : Colors.orange),
                      fontWeight:
                          hasSeriousError ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ],

                // Errors
                if (errorMsg.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Errors: $errorMsg',
                    style: TextStyle(color: Colors.red, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  int? _getMajorityCount(Map<String, int> unitCounts) {
    if (unitCounts.isEmpty) return null;

    final counts = unitCounts.values.where((c) => c > 0).toList();
    if (counts.isEmpty) return null;

    // Count frequency of each value
    final frequency = <int, int>{};
    for (final count in counts) {
      frequency[count] = (frequency[count] ?? 0) + 1;
    }

    // Find the most common count
    int? majorityCount;
    int maxFreq = 0;
    frequency.forEach((count, freq) {
      if (freq > maxFreq) {
        maxFreq = freq;
        majorityCount = count;
      }
    });

    return majorityCount;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
