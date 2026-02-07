


# HTML vs XHTML Retry Logic Analysis

## Overview

This document analyzes the `retryFailedCelex()` function in the Upload References (Tab 2) workflow and identifies issues with how it handles failed CELEX uploads that should retry with HTML instead of XHTML.

## Current Implementation Flow

### Main Upload Process (`pickAndLoadFile2()`)

1. **Format Selection Logic:**
   ```dart
   await uploadSparqlForCelexWithProgress(
     celex,
     newIndexName,
     "xhtml",  // Always requests XHTML first
     onLangProgress,
     onHttpStatus,
     // ...
   )
   ```

2. **Inside `uploadSparqlForCelexWithProgress()`:**
   ```dart
   final htmlDownloadLinks = await fetchLinksForCelex(celex, "html");
   final xhtmlDownloadLinks = await fetchLinksForCelex(celex, "xhtml");
   
   if (htmlCount >= xhtmlCount) {
     downloadLinks = htmlDownloadLinks;  // Use HTML
   } else {
     downloadLinks = xhtmlDownloadLinks; // Use XHTML
   }
   ```
   
   **Note:** The `format` parameter passed to the function is **completely ignored**. The function decides based on availability count.

3. **Progress Tracking:**
   - Uses progress callbacks to update `CelexProgress` objects
   - Updates session and saves to disk
   - Updates progress table in real-time

4. **Failed CELEX Collection:**
   - When download fails, CELEX is added to `failedCelex` list
   - List is checked after all uploads complete

### Retry Process (`retryFailedCelex()`)

```dart
Future<void> retryFailedCelex(List celex, String indexName) async {
  for (final cel in celex) {
    extractedCelex.add('${_completedUploads + 1}/$_totalUploads: $celex:');  // ❌ Bug: uses 'celex' instead of 'cel'

    var status = await uploadSparqlForCelex(
      cel,
      newIndexName,
      "html",  // ← Passes "html" but it's ignored!
      0,
      debugMode,
      simulateUpload,
    );
    
    // ❌ No progress table updates
    // ❌ No session updates
    // ❌ Still uses format selection logic (html vs xhtml count)
  }
}
```

## Identified Problems

### ❌ Problem 1: Format Parameter Ignored

**Issue:** The `"html"` parameter in `uploadSparqlForCelex()` is passed but never used.

**Current Logic:**
```dart
// Inside uploadSparqlForCelex()
if (htmlCount >= xhtmlCount) {
  downloadLinks = htmlDownloadLinks;
} else {
  downloadLinks = xhtmlDownloadLinks;  // Could still use XHTML!
}
```

**Impact:** If XHTML has more languages than HTML, retry will use XHTML again, causing the same failure.

**Expected:** Force HTML download on retry, regardless of availability count.

---

### ❌ Problem 2: No Progress Table Integration

**Issue:** `retryFailedCelex()` uses the old `uploadSparqlForCelex()` function which doesn't support progress callbacks.

**Missing Features:**
- No `onLangProgress` callback
- No `onHttpStatus` callback
- No `CelexProgress` updates
- No session saves
- Progress table shows stale data

**Impact:** Users cannot see retry progress in the table. Retried documents appear frozen.

**Expected:** Use `uploadSparqlForCelexWithProgress()` with proper callbacks to update the progress table.

---

### ❌ Problem 3: Incorrect Variable Reference

**Bug:**
```dart
for (final cel in celex) {
  extractedCelex.add('${_completedUploads + 1}/$_totalUploads: $celex:');
  //                                                              ^^^^^^
  // Wrong! Should be 'cel' (current item), not 'celex' (the list)
}
```

**Impact:** Console log shows the entire list instead of current CELEX number.

---

### ❌ Problem 4: Progress Counter Issues

**Issue:** `_completedUploads` and `_totalUploads` don't account for retry phase.

**Current:**
- `_totalUploads` = initial document count
- Retries increment `_completedUploads` beyond `_totalUploads`
- Progress bar can exceed 100%

**Expected:** Adjust counters to include retry documents, or use separate retry counter.

---

### ❌ Problem 5: Missing Session Context

**Issue:** Retry doesn't access or update the `HarvestSession` object.

**Missing:**
- No access to `_harvestSession`
- Can't update existing `CelexProgress` for failed documents
- Progress table shows outdated status (failed from first attempt)

**Expected:** Update existing progress entries rather than creating new state.

---

## Recommended Solution

### 1. Create Force-HTML Download Function

```dart
Future<Map<String, Map<String, String>>> fetchLinksForCelexForceHTML(String celex) async {
  // Always return HTML links, never XHTML
  final htmlDownloadLinks = await fetchLinksForCelex(celex, "html");
  return htmlDownloadLinks;
}
```

### 2. Update Retry to Use Progress Callbacks

```dart
Future<void> retryFailedCelex(List<String> celexList, String indexName) async {
  if (_harvestSession == null) return;
  
  final retryCount = celexList.length;
  print('🔄 Retrying ${retryCount} failed CELEX with HTML format...');
  
  for (var i = 0; i < celexList.length; i++) {
    final celex = celexList[i];
    final progress = _harvestSession!.documents[celex];
    
    if (progress == null) {
      print('⚠️ No progress entry found for $celex');
      continue;
    }
    
    // Reset progress for retry
    progress.languages.clear();
    progress.startedAt = DateTime.now();
    progress.completedAt = null;
    progress.httpStatus = null;
    
    extractedCelex.add('🔄 RETRY ${i + 1}/$retryCount: $celex (forcing HTML)');
    
    try {
      // Use the progress-aware function
      await uploadSparqlForCelexWithProgressForceHTML(
        celex,
        indexName,
        (String lang, LangStatus status, int unitCount) {
          progress.languages[lang] = status;
          if (unitCount > 0) progress.unitCounts[lang] = unitCount;
          if (mounted) setState(() {});
        },
        (int httpStatus) {
          progress.httpStatus = httpStatus;
          if (mounted) setState(() {});
        },
        0,
        debugMode,
        simulateUpload,
        _getSelectedWorkingLanguages(),
      );
      
      progress.completedAt = DateTime.now();
      
      // Remove from failedCelex if successful
      if (progress.httpStatus == 200) {
        failedCelex.remove(celex);
        extractedCelex.add('✅ RETRY SUCCESS: $celex');
      } else {
        extractedCelex.add('❌ RETRY FAILED: $celex (HTTP ${progress.httpStatus})');
      }
      
    } catch (e) {
      print('❌ Retry failed for $celex: $e');
      progress.languages.values.forEach((lang) {
        progress.languages[lang] = LangStatus.failed;
      });
      extractedCelex.add('❌ RETRY ERROR: $celex - $e');
    }
    
    await _harvestSession!.save();
    
    if (!mounted) return;
    setState(() {});
  }
}
```

### 3. Create Force-HTML Version of Upload Function

```dart
// In testHtmlDumps.dart
Future<Map<String, int>> uploadSparqlForCelexWithProgressForceHTML(
  String celex,
  String indexName,
  void Function(String lang, LangStatus status, int unitCount)? onLangProgress,
  void Function(int httpStatus)? onHttpStatus,
  int startPointer,
  bool debugMode,
  bool simulateUpload,
  List<String>? filterLanguages,
) async {
  final langUnitCounts = <String, int>{};
  
  // FORCE HTML - don't check counts
  final htmlDownloadLinks = await fetchLinksForCelex(celex, "html");
  
  if (htmlDownloadLinks.isEmpty || htmlDownloadLinks[celex]?.isEmpty == true) {
    print('⚠️ No HTML links found for $celex');
    return langUnitCounts;
  }
  
  var downloadLinks = htmlDownloadLinks;
  print('🔄 Force HTML download for $celex');
  
  // ... rest of uploadSparqlForCelexWithProgress logic ...
}
```

## Benefits of Proposed Solution

✅ **Forces HTML on Retry:** Explicitly uses HTML links, no ambiguity

✅ **Progress Table Updates:** Real-time status visible to users

✅ **Session Integration:** Updates existing progress entries

✅ **Proper Error Handling:** Distinguishes retry failures from initial failures

✅ **Accurate Progress:** Clear indication of retry phase

✅ **User Visibility:** Shows "RETRY" prefix in logs and progress

## Testing Checklist

- [ ] Verify retry uses HTML when XHTML has more languages
- [ ] Confirm progress table updates during retry
- [ ] Check session file contains retry attempts
- [ ] Validate `_completedUploads` doesn't overflow
- [ ] Test with documents that have only XHTML (should skip retry)
- [ ] Test with documents that have only HTML (should succeed on retry)
- [ ] Verify failedCelex list is cleared for successful retries
- [ ] Confirm UI shows retry status clearly
