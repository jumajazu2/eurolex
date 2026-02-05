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

/// Widget to display harvest progress in a real-time table
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
  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final elapsed = session.elapsedTime;
    final estimated = session.estimatedTimeRemaining;

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
                        'Custom Collection Creation Session: ${session.sessionId}',
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

            // Progress bar
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

            // Documents table
            Expanded(
              child: SingleChildScrollView(
                child: Table(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columnWidths: const {
                    0: FixedColumnWidth(40), // #
                    1: FlexColumnWidth(1), // CELEX (narrower)
                    2: FlexColumnWidth(5), // Languages status (more space)
                    3: FlexColumnWidth(2), // Status
                  },
                  children: [
                    // Header
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      children: [
                        _tableHeader('#'),
                        _tableHeader('CELEX'),
                        _tableHeader('Languages'),
                        _tableHeader('Status'),
                      ],
                    ),
                    // Data rows
                    ...session.celexOrder.asMap().entries.map((entry) {
                      final index = entry.key;
                      final celex = entry.value;
                      final progress = session.documents[celex];
                      if (progress == null) {
                        return TableRow(
                          children: [
                            _tableCell((index + 1).toString()),
                            _tableCell(celex),
                            _tableCell('⏳ Pending'),
                            _tableCell('Not started'),
                          ],
                        );
                      }

                      // Debug: Check completion status
                      final completionStatus =
                          progress.isCompleted
                              ? 'Done'
                              : (progress.completedAt != null
                                  ? 'Processing'
                                  : 'In progress');

                      final debugInfo =
                          '${progress.languages.values.where((s) => s == LangStatus.completed).length}/${progress.languages.length} langs completed';

                      // Calculate block count validation
                      final unitCounts =
                          progress.unitCounts.values
                              .where((c) => c > 0)
                              .toList();
                      final blocksMatched =
                          unitCounts.isNotEmpty &&
                          unitCounts.toSet().length == 1;
                      final majorityCount = _getMajorityCount(
                        progress.unitCounts,
                      );

                      // Check for serious error (>25% difference)
                      bool hasSeriousError = false;
                      if (majorityCount != null && majorityCount > 0) {
                        for (final count in unitCounts) {
                          final diff =
                              (count - majorityCount).abs() / majorityCount;
                          if (diff > 0.25) {
                            hasSeriousError = true;
                            break;
                          }
                        }
                      }

                      // Build language status widget with download links
                      final langStatusWidget = Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children:
                            progress.languages.entries.map((e) {
                              final lang = e.key;
                              final status = e.value;
                              final unitCount = progress.unitCounts[lang] ?? 0;
                              final unitInfo =
                                  unitCount > 0 ? ' ($unitCount)' : '';
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
                                      : (isDifferent
                                          ? Colors.orange
                                          : Colors.black);

                              // Get actual download URL from progress
                              final downloadUrl =
                                  progress.downloadUrls[lang] ?? '';

                              return InkWell(
                                onTap:
                                    downloadUrl.isNotEmpty
                                        ? () {
                                          // Open URL in browser
                                          launchUrl(downloadUrl);
                                        }
                                        : null,
                                child: Text(
                                  '$lang$unitInfo $emoji',
                                  style: TextStyle(
                                    color: langColor,
                                    fontWeight:
                                        isDifferent
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    decoration:
                                        downloadUrl.isNotEmpty
                                            ? TextDecoration.underline
                                            : null,
                                    decorationColor: langColor,
                                  ),
                                ),
                              );
                            }).toList(),
                      );

                      final blockValidation =
                          unitCounts.isNotEmpty
                              ? (blocksMatched
                                  ? ' ✅ Blocks matched'
                                  : (hasSeriousError
                                      ? ' 🚨 SERIOUS ERROR: Block count mismatch >25%'
                                      : ' ⚠️ Blocks mismatch'))
                              : '';

                      final errorMsg = progress.errors.values
                          .where((e) => e != null && e.isNotEmpty)
                          .join('; ');

                      return TableRow(
                        decoration: BoxDecoration(
                          color:
                              progress.isCompleted
                                  ? (progress.hasFailures
                                      ? Colors.red.shade50
                                      : Colors.green.shade50)
                                  : null,
                        ),
                        children: [
                          _tableCell((index + 1).toString()),
                          _tableCell(celex),
                          _tableCellWidget(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                langStatusWidget,
                                if (blockValidation.isNotEmpty)
                                  Text(
                                    blockValidation,
                                    style: TextStyle(
                                      color:
                                          hasSeriousError
                                              ? Colors.red
                                              : (blocksMatched
                                                  ? Colors.green
                                                  : Colors.orange),
                                      fontWeight:
                                          hasSeriousError
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      fontSize: 15,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _tableCell(() {
                            final httpStatusText =
                                progress.httpStatus != null
                                    ? 'HTTP:${progress.httpStatus} '
                                    : '';
                            final statusText =
                                errorMsg.isEmpty
                                    ? '$completionStatus ($debugInfo)'
                                    : errorMsg;
                            return '$httpStatusText$statusText';
                          }(), isError: errorMsg.isNotEmpty),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18.75, // 15 * 1.25
        ),
      ),
    );
  }

  Widget _tableCell(
    String text, {
    bool isError = false,
    bool hasMismatch = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          color: isError ? Colors.red : (hasMismatch ? Colors.orange : null),
          fontSize: 15, // 12 * 1.25
        ),
      ),
    );
  }

  Widget _tableCellWidget(Widget child) {
    return Padding(padding: const EdgeInsets.all(8), child: child);
  }

  /// Find the majority unit count (most common count)
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
