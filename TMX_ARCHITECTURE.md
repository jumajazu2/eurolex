# TMX Upload Flow Diagram

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     User Interface                          │
│  (Upload References → Upload Own Reference Documents)       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ 1. Select TMX file
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   bulkupload.dart                           │
│                                                             │
│  processBulk()                                              │
│    ├─ File picker (.tmx, .xml)                             │
│    ├─ Detect file type                                     │
│    └─ Route to _processTmxFile()                           │
│                                                             │
│  _processTmxFile()                                          │
│    ├─ Read file content                                    │
│    ├─ Call TmxParser.parseTmxContent()  ─────────┐         │
│    ├─ Get statistics                             │         │
│    ├─ Upload to OpenSearch (if not simulate)     │         │
│    └─ Save debug file (if debug mode)            │         │
└───────────────────────────────────────────────────┼─────────┘
                                                    │
                     ┌──────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   tmx_parser.dart                           │
│                                                             │
│  TmxParser                                                  │
│    ├─ parseTmxContent()                                     │
│    │   ├─ Parse XML structure                              │
│    │   ├─ Extract <tu> elements                            │
│    │   ├─ For each translation unit:                       │
│    │   │   ├─ Extract metadata (dates, creator)            │
│    │   │   ├─ Extract language segments                    │
│    │   │   ├─ Normalize language codes                     │
│    │   │   └─ Create JSON entry                            │
│    │   └─ Return List<Map<String, dynamic>>                │
│    │                                                        │
│    ├─ getStatistics()                                       │
│    │   ├─ Count entries                                    │
│    │   ├─ Identify languages                               │
│    │   └─ Count language pairs                             │
│    │                                                        │
│    └─ convertToNdjson()                                     │
│        ├─ Create index actions                             │
│        └─ Format as NDJSON                                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Returns parsed data
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   processDOM.dart                           │
│                                                             │
│  openSearchUpload(jsonData, indexName)                      │
│    ├─ Convert to NDJSON format                             │
│    ├─ Add bulk action headers                              │
│    └─ Call sendToOpenSearch()  ─────────────┐              │
│                                              │              │
│  sendToOpenSearch(url, bulkData)             │              │
│    ├─ Prepare HTTP request                  │              │
│    ├─ Add authentication headers             │              │
│    ├─ POST to OpenSearch /_bulk              │              │
│    └─ Handle response/errors                 │              │
└──────────────────────────────────────────────┼──────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     OpenSearch Server                       │
│                                                             │
│  Index: eu_[passkey]_[indexname]                           │
│    └─ Documents:                                            │
│        ├─ { sequence_id: 0, en_text: "...", sk_text: "..." }│
│        ├─ { sequence_id: 1, en_text: "...", sk_text: "..." }│
│        └─ ...                                               │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow Example

```
┌─────────────────────────┐
│   Input: TMX File       │
├─────────────────────────┤
│ <tu>                    │
│   <tuv xml:lang="en-GB">│
│     <seg>Hello</seg>    │
│   </tuv>                │
│   <tuv xml:lang="sk-SK">│
│     <seg>Ahoj</seg>     │
│   </tuv>                │
│ </tu>                   │
└───────────┬─────────────┘
            │
            │ TMX Parser
            ▼
┌─────────────────────────┐
│  Parsed JSON Object     │
├─────────────────────────┤
│ {                       │
│   "sequence_id": 0,     │
│   "en_text": "Hello",   │
│   "sk_text": "Ahoj",    │
│   "source": "TMX",      │
│   "filename": "...",    │
│   "languages": [        │
│     "en", "sk"          │
│   ]                     │
│ }                       │
└───────────┬─────────────┘
            │
            │ OpenSearch Upload
            ▼
┌─────────────────────────┐
│   NDJSON Format         │
├─────────────────────────┤
│ {"index":{"_index":...}}│
│ {"sequence_id":0,...}   │
└───────────┬─────────────┘
            │
            │ HTTP POST
            ▼
┌─────────────────────────┐
│    OpenSearch Index     │
│   (Searchable Data)     │
└─────────────────────────┘
```

## Component Interactions

```
┌──────────────┐
│  UI Layer    │  User clicks "Pick file"
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  File Picker │  Select .tmx file
└──────┬───────┘
       │
       ▼
┌──────────────┐  Read file content
│ File System  ├──────────────────┐
└──────────────┘                  │
                                  ▼
                         ┌─────────────────┐
                         │   TMX Parser    │  Parse XML
                         └────────┬────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │  JSON Converter │  Create documents
                         └────────┬────────┘
                                  │
                         ┌────────▼────────┐
                         │  Debug Output   │  (Optional)
                         │  JSON to disk   │
                         └─────────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ OpenSearch API  │  Upload via HTTP
                         └────────┬────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ OpenSearch DB   │  Store & Index
                         └─────────────────┘
```

## File Dependencies

```
main.dart
  └─> dataupload.dart
       └─> bulkupload.dart
            ├─> tmx_parser.dart (NEW)
            │    └─> xml package
            │
            ├─> processDOM.dart
            │    └─> openSearchUpload()
            │         └─> sendToOpenSearch()
            │              └─> http package
            │
            ├─> logger.dart
            └─> setup.dart
```

## Process Timeline

```
T0: User Action
│   └─ Select file from UI
│
T1: File Reading (< 1 sec)
│   └─ Read file into memory
│
T2: Parsing (< 1 sec for typical files)
│   ├─ Parse XML
│   ├─ Extract translation units
│   └─ Create JSON objects
│
T3: Statistics (< 0.1 sec)
│   └─ Count languages, entries
│
T4: Upload (1-5 sec depending on size)
│   ├─ Format as NDJSON
│   ├─ Send HTTP POST
│   └─ Receive confirmation
│
T5: Complete
    ├─ Log results
    ├─ Save debug file (if enabled)
    └─ Refresh index list
```

## Error Handling Flow

```
                ┌─ File not found?
                │   └─> Log error, return
                │
                ├─ Invalid XML?
processBulk() ──┤   └─> Catch parse error, log, return
                │
                ├─ No valid TUs?
                │   └─> Log warning, return
                │
                ├─ Upload fails?
                │   └─> Log HTTP error, rethrow
                │
                └─ Success
                    └─> Log completion, update UI
```

## Integration Points

### Reuses Existing Code
- ✅ `openSearchUpload()` from processDOM.dart
- ✅ `sendToOpenSearch()` from processDOM.dart
- ✅ `LogManager` from logger.dart
- ✅ `getCustomIndices()` from setup.dart
- ✅ `fileSafeStamp` global variable
- ✅ Authentication headers and device ID

### New Code
- 🆕 `TmxParser` class in tmx_parser.dart
- 🆕 `_processTmxFile()` in bulkupload.dart
- 🆕 `_uploadTmxToOpenSearch()` in bulkupload.dart
- 🆕 `_saveTmxDebugFile()` in bulkupload.dart

## Summary

The TMX upload feature integrates seamlessly with existing infrastructure:
- Uses standard file picker
- Leverages existing OpenSearch upload pipeline
- Follows established logging patterns
- Reuses authentication and configuration
- No breaking changes to existing code

The modular design allows easy extension to support additional file formats in the future.
