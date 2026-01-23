# TMX Upload Testing Guide

## Prerequisites

- Flutter project built and running
- OpenSearch server accessible
- Valid authentication credentials configured
- Test TMX file ready

## Test TMX File

Create a file named `test_upload.tmx` with this content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE tmx SYSTEM "tmx14.dtd">
<tmx version="1.4">
  <header creationtool="TestTool" creationtoolversion="1.0" 
          segtype="sentence" o-tmf="unknown" adminlang="en" 
          srclang="en" datatype="PlainText"/>
  <body>
    <tu creationdate="20260122T152808Z" creationid="Tester" 
        changedate="20260122T152808Z" changeid="Tester">
      <tuv xml:lang="en-GB">
        <seg>European Union</seg>
      </tuv>
      <tuv xml:lang="sk-SK">
        <seg>Európska únia</seg>
      </tuv>
    </tu>
    
    <tu creationdate="20260122T152900Z" creationid="Tester">
      <tuv xml:lang="en-GB">
        <seg>Legal Framework</seg>
      </tuv>
      <tuv xml:lang="sk-SK">
        <seg>Právny rámec</seg>
      </tuv>
    </tu>
    
    <tu creationdate="20260122T153000Z" creationid="Tester">
      <tuv xml:lang="en-GB">
        <seg>Member States</seg>
      </tuv>
      <tuv xml:lang="sk-SK">
        <seg>Členské štáty</seg>
      </tuv>
      <tuv xml:lang="cs-CZ">
        <seg>Členské státy</seg>
      </tuv>
    </tu>
    
    <tu creationdate="20260122T153100Z" creationid="Tester">
      <tuv xml:lang="en-GB">
        <seg>This regulation shall enter into force on the twentieth day following that of its publication in the Official Journal of the European Union.</seg>
      </tuv>
      <tuv xml:lang="sk-SK">
        <seg>Toto nariadenie nadobúda účinnosť dvadsiatym dňom po jeho uverejnení v Úradnom vestníku Európskej únie.</seg>
      </tuv>
    </tu>
    
    <tu creationdate="20260122T153200Z" creationid="Tester">
      <tuv xml:lang="en-GB">
        <seg>The Commission shall adopt implementing acts.</seg>
      </tuv>
      <tuv xml:lang="sk-SK">
        <seg>Komisia prijme vykonávacie akty.</seg>
      </tuv>
    </tu>
  </body>
</tmx>
```

## Test Scenarios

### Test 1: Basic Upload (Simulation Mode)

**Objective:** Verify parsing works without uploading

**Steps:**
1. Launch application
2. Navigate to: Upload References → Upload Own Reference Documents
3. Enter index name: `test_tmx` (will become `eu_[passkey]_test_tmx`)
4. Enable checkboxes:
   - ☑️ Simulate
   - ☑️ Debug Mode
5. Click "Pick TMX/Reference file and upload"
6. Select `test_upload.tmx`
7. Wait for completion

**Expected Results:**
- ✅ Console shows: "TMX parsed: 5 entries, Languages: en, sk, cs"
- ✅ Console shows: "SIMULATION MODE: Would upload 5 entries"
- ✅ File created: `debug_output/tmx_test_upload_[timestamp].json`
- ✅ Log created: `logs/[timestamp]_eu_[passkey]_test_tmx_tmx.log`
- ✅ No data uploaded to OpenSearch
- ✅ No errors in console

**Validation:**
```powershell
# Check debug file exists
Get-ChildItem debug_output\tmx_test_upload*.json

# View parsed content
Get-Content debug_output\tmx_test_upload*.json | ConvertFrom-Json

# Check log file
Get-Content logs\*test_tmx_tmx.log
```

---

### Test 2: Actual Upload

**Objective:** Upload data to OpenSearch

**Steps:**
1. Use same setup as Test 1
2. **Disable** Simulate checkbox (keep Debug Mode enabled)
3. Click "Pick TMX/Reference file and upload"
4. Select `test_upload.tmx`
5. Wait for completion

**Expected Results:**
- ✅ Console shows: "Data successfully processed in opensearch!"
- ✅ Console shows: "Successfully uploaded TMX data to OpenSearch"
- ✅ Debug file created with parsed data
- ✅ Upload log shows successful HTTP 200 response
- ✅ Index `eu_[passkey]_test_tmx` appears in dropdown after refresh

**Validation:**
```powershell
# Check OpenSearch via API (replace with your credentials)
$headers = @{
    "x-api-key" = "your_passkey"
}
Invoke-WebRequest -Uri "https://your-server/eu_[passkey]_test_tmx/_search" -Headers $headers -Method GET

# Or use Postman/Insomnia:
# GET https://your-server/eu_[passkey]_test_tmx/_search
# Header: x-api-key: your_passkey
```

---

### Test 3: Multi-Language Support

**Objective:** Verify 3+ language entries work

**Steps:**
1. Focus on the third translation unit (has en, sk, cs)
2. Upload using Test 2 procedure
3. Query the specific document

**Expected Results:**
- ✅ Document contains all three languages:
  ```json
  {
    "en_text": "Member States",
    "sk_text": "Členské štáty",
    "cs_text": "Členské státy",
    "languages": ["en", "sk", "cs"]
  }
  ```

**Validation:**
```json
// Search for the entry
GET /eu_[passkey]_test_tmx/_search
{
  "query": {
    "match": {
      "en_text": "Member States"
    }
  }
}
```

---

### Test 4: Invalid TMX File

**Objective:** Test error handling

**Steps:**
1. Create file `invalid.tmx`:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <tmx version="1.4">
     <body>
       <tu>
         <tuv xml:lang="en">
           <seg>Test</seg>
         <!-- Missing closing tags
       </tu>
   </tmx>
   ```
2. Try to upload `invalid.tmx`

**Expected Results:**
- ✅ Error logged in console
- ✅ Error in log file: "ERROR parsing TMX"
- ✅ Application doesn't crash
- ✅ User-friendly error handling

---

### Test 5: Large File Performance

**Objective:** Test with many entries

**Steps:**
1. Create TMX with 1000+ translation units (use script or tool)
2. Upload with Debug Mode enabled
3. Monitor performance

**Expected Results:**
- ✅ Parsing completes in reasonable time (< 10 seconds for 1000 entries)
- ✅ Upload completes successfully
- ✅ All entries indexed in OpenSearch
- ✅ Debug JSON file size reasonable

**Performance Benchmarks:**
- 100 entries: < 2 seconds
- 1000 entries: < 10 seconds
- 10000 entries: < 60 seconds

---

### Test 6: Language Code Normalization

**Objective:** Verify language codes are normalized

**Test Data:**
```xml
<tu>
  <tuv xml:lang="en-US"><seg>Color</seg></tuv>
  <tuv xml:lang="en-GB"><seg>Colour</seg></tuv>
  <tuv xml:lang="pt-BR"><seg>Cor</seg></tuv>
  <tuv xml:lang="pt-PT"><seg>Cor</seg></tuv>
</tu>
```

**Expected Results:**
- ✅ `en-US` → `en`
- ✅ `en-GB` → `en`  
- ✅ `pt-BR` → `pt`
- ✅ `pt-PT` → `pt`
- ✅ Keys in JSON: `en_text`, `pt_text`

---

### Test 7: Missing Language Codes

**Objective:** Handle incomplete translation units

**Test Data:**
```xml
<tu>
  <tuv xml:lang="en"><seg>Complete entry</seg></tuv>
  <tuv xml:lang="sk"><seg>Úplný záznam</seg></tuv>
</tu>
<tu>
  <tuv xml:lang="en"><seg>Incomplete entry</seg></tuv>
  <!-- Only one language - should be skipped -->
</tu>
<tu>
  <tuv><seg>No language code</seg></tuv>
  <tuv><seg>Bez kódu jazyka</seg></tuv>
</tu>
```

**Expected Results:**
- ✅ First TU: uploaded successfully
- ✅ Second TU: skipped (< 2 languages)
- ✅ Third TU: skipped (no language codes)
- ✅ Log shows: "Skipping TU with insufficient languages"
- ✅ Statistics: 1 entry uploaded, 2 skipped

---

### Test 8: Index Name Validation

**Objective:** Test index name constraints

**Test Cases:**

| Input | Expected Result |
|-------|----------------|
| `test_index` | ✅ Valid → `eu_[passkey]_test_index` |
| `Test_Index` | ❌ Rejected (uppercase) |
| `test-index` | ✅ Valid → `eu_[passkey]_test-index` |
| `test.index` | ✅ Valid → `eu_[passkey]_test.index` |
| `_test` | ❌ Rejected (starts with _) |
| `-test` | ❌ Rejected (starts with -) |
| `test index` | ❌ Rejected (space) |
| `.` | ❌ Rejected (just dot) |
| `..` | ❌ Rejected (just dots) |

---

### Test 9: Metadata Preservation

**Objective:** Verify metadata is stored

**Steps:**
1. Upload test file
2. Query OpenSearch for a document
3. Check metadata fields

**Expected Fields:**
```json
{
  "sequence_id": 0,
  "filename": "test_upload.tmx",
  "source": "TMX",
  "creation_date": "20260122T152808Z",
  "change_date": "20260122T152808Z",
  "creator": "Tester",
  "en_text": "...",
  "sk_text": "...",
  "languages": ["en", "sk"]
}
```

---

### Test 10: Concurrent Uploads

**Objective:** Test multiple uploads don't interfere

**Steps:**
1. Upload `file1.tmx` to `index1`
2. Immediately upload `file2.tmx` to `index2`
3. Verify both complete successfully

**Expected Results:**
- ✅ Both uploads succeed
- ✅ No data mixing between indices
- ✅ Separate log files created
- ✅ Separate debug files created

---

## Automated Test Script

Create `test_tmx_upload.dart`:

```dart
import 'package:LegisTracerEU/tmx_parser.dart';
import 'dart:io';

void main() async {
  print('Starting TMX Upload Tests...\n');
  
  final testResults = <String, bool>{};
  
  // Test 1: Valid TMX parsing
  try {
    final parser = TmxParser();
    final tmxContent = '''<?xml version="1.0"?>
    <tmx version="1.4"><body>
      <tu><tuv xml:lang="en"><seg>Test</seg></tuv>
           <tuv xml:lang="sk"><seg>Test</seg></tuv></tu>
    </body></tmx>''';
    
    final result = parser.parseTmxContent(tmxContent, 'test.tmx');
    testResults['Valid TMX Parsing'] = result.length == 1;
    print('✓ Valid TMX Parsing: ${result.length} entries');
  } catch (e) {
    testResults['Valid TMX Parsing'] = false;
    print('✗ Valid TMX Parsing failed: $e');
  }
  
  // Test 2: Language normalization
  try {
    final parser = TmxParser();
    final tmxContent = '''<?xml version="1.0"?>
    <tmx version="1.4"><body>
      <tu><tuv xml:lang="en-GB"><seg>Test</seg></tuv>
           <tuv xml:lang="sk-SK"><seg>Test</seg></tuv></tu>
    </body></tmx>''';
    
    final result = parser.parseTmxContent(tmxContent, 'test.tmx');
    final entry = result.first;
    final hasNormalizedLangs = entry.containsKey('en_text') && 
                                entry.containsKey('sk_text');
    testResults['Language Normalization'] = hasNormalizedLangs;
    print('✓ Language Normalization: ${entry['languages']}');
  } catch (e) {
    testResults['Language Normalization'] = false;
    print('✗ Language Normalization failed: $e');
  }
  
  // Test 3: Statistics
  try {
    final parser = TmxParser();
    final tmxContent = '''<?xml version="1.0"?>
    <tmx version="1.4"><body>
      <tu><tuv xml:lang="en"><seg>Test1</seg></tuv>
           <tuv xml:lang="sk"><seg>Test1</seg></tuv></tu>
      <tu><tuv xml:lang="en"><seg>Test2</seg></tuv>
           <tuv xml:lang="sk"><seg>Test2</seg></tuv></tu>
    </body></tmx>''';
    
    final result = parser.parseTmxContent(tmxContent, 'test.tmx');
    final stats = parser.getStatistics(result);
    final statsOk = stats['total_entries'] == 2 &&
                    (stats['languages'] as List).length == 2;
    testResults['Statistics'] = statsOk;
    print('✓ Statistics: $stats');
  } catch (e) {
    testResults['Statistics'] = false;
    print('✗ Statistics failed: $e');
  }
  
  // Summary
  print('\n' + '='*50);
  print('Test Summary:');
  print('='*50);
  testResults.forEach((test, passed) {
    print('${passed ? "✓" : "✗"} $test');
  });
  
  final totalTests = testResults.length;
  final passedTests = testResults.values.where((v) => v).length;
  print('\nPassed: $passedTests/$totalTests');
  
  exit(passedTests == totalTests ? 0 : 1);
}
```

Run with:
```powershell
dart run lib/test_tmx_upload.dart
```

---

## Troubleshooting Guide

### Issue: "No file selected"
- **Cause:** File picker cancelled
- **Solution:** Select file when prompted

### Issue: "Invalid TMX file: No <body> element"
- **Cause:** Malformed XML or wrong structure
- **Solution:** Validate TMX against standard, check for closing tags

### Issue: "No valid translation units found"
- **Cause:** All TUs have < 2 languages or empty segments
- **Solution:** Verify each TU has at least 2 languages with text

### Issue: "HTTP 401" or "HTTP 429"
- **Cause:** Authentication or rate limit issues
- **Solution:** Check API key, wait and retry

### Issue: Debug file not created
- **Cause:** Debug Mode not enabled or permissions issue
- **Solution:** Enable checkbox, check folder permissions

### Issue: Upload seems successful but data not searchable
- **Cause:** Index not refreshed or wrong index name
- **Solution:** Refresh indices, verify index name matches

---

## Success Criteria

All tests pass when:
- ✅ TMX files parse correctly
- ✅ Language codes normalize properly
- ✅ Metadata preserved
- ✅ Data uploads to OpenSearch
- ✅ Searchable in target index
- ✅ Debug files created in Debug Mode
- ✅ Logs show no errors
- ✅ Invalid files handled gracefully
- ✅ Statistics accurate
- ✅ Performance acceptable

---

## Next Steps

After successful testing:
1. ✅ Test with real translation memory files
2. ✅ Test with production OpenSearch server
3. ✅ Verify search results quality
4. ✅ Document any edge cases found
5. ✅ Train users on the feature
