# TMX File Upload Implementation - Summary

## Overview
Successfully implemented TMX (Translation Memory eXchange) file parsing and upload functionality to OpenSearch. Users can now upload bilingual and multilingual translation memory files through the "Upload Own Reference Documents" interface.

## Files Created

### 1. `lib/tmx_parser.dart` (New)
Core TMX parsing module with the following features:
- **TmxParser class**: Main parser for TMX files
  - `parseTmxContent()`: Parses TMX XML and extracts translation units
  - `convertToNdjson()`: Converts parsed data to OpenSearch NDJSON format
  - `getStatistics()`: Provides statistics about the TMX data
- **Language normalization**: Converts "en-GB", "sk-SK" → "en", "sk"
- **Metadata preservation**: Keeps creation date, change date, creator info
- **Multi-language support**: Handles any number of languages per translation unit
- **Error handling**: Robust error logging and recovery

### 2. `lib/TMX_UPLOAD_GUIDE.md` (New)
Complete user documentation including:
- Step-by-step usage instructions
- TMX file format requirements
- Data structure explanation
- Examples with input/output
- Troubleshooting guide

### 3. `lib/example_tmx_parser.dart` (New)
Working example demonstrating:
- How to use the TMX parser
- Sample TMX content with multiple language pairs
- Output formatting
- Statistics display

## Files Modified

### `lib/bulkupload.dart`
Added TMX support to the bulk upload functionality:

**New Imports:**
```dart
import 'package:LegisTracerEU/tmx_parser.dart';
import 'package:LegisTracerEU/processDOM.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
```

**New Functions:**
- `processBulk()`: Updated to handle file picking and route to appropriate parser
- `_processTmxFile()`: Processes TMX files specifically
- `_uploadTmxToOpenSearch()`: Uploads parsed TMX data using existing infrastructure
- `_saveTmxDebugFile()`: Saves debug JSON when Debug Mode is enabled

**UI Updates:**
- Updated file picker to accept `.tmx` and `.xml` extensions
- Changed button text to "Pick TMX/Reference file and upload"
- Updated instruction text to mention TMX files

## Features

### Core Functionality
✅ Parse TMX files with multiple language pairs
✅ Extract translation units with metadata
✅ Normalize language codes (en-GB → en)
✅ Upload to OpenSearch via existing infrastructure
✅ Support for Simulate mode (test without uploading)
✅ Support for Debug mode (save JSON files)
✅ Comprehensive logging
✅ Statistics and progress reporting

### Data Structure
Each translation unit becomes an OpenSearch document with:
```json
{
  "sequence_id": 0,
  "filename": "example.tmx",
  "source": "TMX",
  "creation_date": "20260122T152808Z",
  "change_date": "20260122T152808Z",
  "creator": "DESKTOP-II0DE2P\\Juraj",
  "en_text": "CALL FOR EVIDENCE",
  "sk_text": "VÝZVA NA PREDKLADANIE PODKLADOV",
  "languages": ["en", "sk"]
}
```

## How to Use

1. **Navigate to the UI**
   - Open the application
   - Go to "Upload References" tab
   - Select "Upload Own Reference Documents"

2. **Select Index**
   - Choose existing index from dropdown, OR
   - Enter new index name (will be prefixed with `eu_[passkey]_`)

3. **Upload TMX File**
   - Click "Pick TMX/Reference file and upload"
   - Select your `.tmx` file
   - Wait for processing to complete

4. **Optional Settings**
   - ☑️ Simulate: Test without uploading
   - ☑️ Debug Mode: Save JSON to `debug_output/` folder

## Integration Points

### Reuses Existing Infrastructure
- `openSearchUpload()` from `processDOM.dart` for uploading
- `LogManager` for logging
- `fileSafeStamp` for timestamped filenames
- `getCustomIndices()` for index management
- Existing authentication and server configuration

### No Breaking Changes
- All existing functionality remains intact
- Backward compatible with current upload methods
- Uses same OpenSearch connection and credentials

## Testing

### Manual Test Steps
1. Prepare a TMX file with the structure shown in the documentation
2. Launch the application
3. Navigate to Upload References → Upload Own Reference Documents
4. Enter or select an index name
5. Enable "Debug Mode" checkbox
6. Enable "Simulate" checkbox for first test
7. Click "Pick TMX/Reference file and upload"
8. Select your TMX file
9. Check `debug_output/` folder for JSON output
10. Verify in console/logs that parsing succeeded
11. Disable "Simulate" and upload again
12. Search for your uploaded translations in OpenSearch

### Example Test File
Use the content from `lib/example_tmx_parser.dart` to create a test TMX file.

## Logs and Debugging

### Log Files
- `logs/[timestamp]_[indexname]_tmx.log`: TMX parsing log
- `logs/[timestamp]_[indexname].log`: Upload log

### Debug Output
When Debug Mode is enabled:
- `debug_output/tmx_[filename]_[timestamp].json`: Parsed data as JSON

### Console Output
- Statistics: total entries, languages found
- Progress indicators
- Error messages if any

## Error Handling

The implementation handles:
- ✅ Invalid XML structure
- ✅ Missing `<body>` element
- ✅ Missing language codes
- ✅ Empty segments
- ✅ Translation units with < 2 languages
- ✅ File read errors
- ✅ Upload failures

Errors are logged and don't crash the application.

## Dependencies

All required packages are already in `pubspec.yaml`:
- `xml: ^6.5.0` ✅ (already present)
- `file_picker: ^5.0.1` ✅ (already present)
- `path` ✅ (from path_provider package)
- `http: ^1.2.1` ✅ (already present)

No additional packages needed!

## Future Enhancements (Optional)

Possible improvements for future versions:
- [ ] Support for other translation memory formats (XLIFF, etc.)
- [ ] Batch upload of multiple TMX files
- [ ] Preview of parsed data before upload
- [ ] Progress bar during parsing large files
- [ ] Filter by language pairs
- [ ] Merge multiple TMX files into single index
- [ ] Export from OpenSearch back to TMX

## Verification Checklist

Before using in production:
- ✅ Code compiles without errors
- ✅ No breaking changes to existing functionality
- ✅ XML package is available (in pubspec.yaml)
- ✅ UI is accessible from Upload References tab
- ✅ File picker accepts .tmx files
- ✅ Parser handles malformed TMX gracefully
- ✅ Upload uses existing OpenSearch infrastructure
- ✅ Debug mode creates output files
- ✅ Logs are created properly
- ✅ Documentation is complete

## Summary

The TMX upload feature is **ready to use**. It seamlessly integrates with your existing OpenSearch upload infrastructure and provides a user-friendly way to import translation memories into your reference database.

Users can now:
1. Select a TMX file from "Upload Own Reference Documents"
2. Parse bilingual/multilingual translation pairs automatically
3. Upload to OpenSearch with existing authentication
4. Debug and troubleshoot with detailed logs and JSON output
5. Simulate uploads before committing

All functionality is documented in [TMX_UPLOAD_GUIDE.md](TMX_UPLOAD_GUIDE.md).
