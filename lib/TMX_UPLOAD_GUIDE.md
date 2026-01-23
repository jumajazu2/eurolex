# TMX File Upload Feature

## Overview
This feature allows you to upload TMX (Translation Memory eXchange) files containing bilingual or multilingual translation pairs to OpenSearch.

## How to Use

1. **Navigate to Upload References**
   - Go to the "Upload References" tab in the application
   - Select the "Upload Own Reference Documents" sub-tab

2. **Select or Create an Index**
   - Choose an existing index from the dropdown, OR
   - Enter a new index name in the text field
   - Index names must be lowercase and can only contain: a-z, 0-9, dot (.), underscore (_), hyphen (-)
   - Cannot start with: _ , - , +

3. **Upload Your TMX File**
   - Click "Pick TMX/Reference file and upload"
   - Select your .tmx or .xml file
   - The system will automatically parse and upload the translation units

4. **Optional Settings**
   - **Simulate**: Test the upload process without actually sending data to OpenSearch
   - **Debug Mode**: Save a JSON file of the parsed data to the `debug_output` folder for troubleshooting

## TMX File Format

The parser expects TMX files with the following structure:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<tmx version="1.4">
  <header ... />
  <body>
    <tu creationdate="..." creationid="..." changedate="..." changeid="...">
      <tuv xml:lang="en-GB">
        <seg>English text here</seg>
      </tuv>
      <tuv xml:lang="sk-SK">
        <seg>Slovak text here</seg>
      </tuv>
    </tu>
    <!-- More translation units... -->
  </body>
</tmx>
```

### Supported Features
- **Multiple Language Pairs**: Each translation unit can contain 2 or more languages
- **Language Code Normalization**: Language codes like "en-GB", "en-US" are normalized to "en"
- **Metadata Preservation**: Creation date, change date, and creator information are preserved
- **Flexible Language Codes**: Supports any ISO language codes

### Data Structure
Each translation unit is converted to a JSON document with:
- `sequence_id`: Sequential number within the file
- `filename`: Original TMX filename
- `source`: Set to "TMX"
- `creation_date`: When the translation was created
- `change_date`: When it was last modified
- `creator`: Who created the translation
- `[lang]_text`: Text content for each language (e.g., `en_text`, `sk_text`)
- `languages`: Array of language codes present in this entry

## Example

Given a TMX file with English-Slovak pairs:

**Input TMX:**
```xml
<tu creationdate="20260122T152808Z">
  <tuv xml:lang="en-GB">
    <seg>CALL FOR EVIDENCE</seg>
  </tuv>
  <tuv xml:lang="sk-SK">
    <seg>VÝZVA NA PREDKLADANIE PODKLADOV</seg>
  </tuv>
</tu>
```

**Output JSON (uploaded to OpenSearch):**
```json
{
  "sequence_id": 0,
  "filename": "translations.tmx",
  "source": "TMX",
  "creation_date": "20260122T152808Z",
  "en_text": "CALL FOR EVIDENCE",
  "sk_text": "VÝZVA NA PREDKLADANIE PODKLADOV",
  "languages": ["en", "sk"]
}
```

## Logs and Debugging

- **Upload Logs**: Found in `logs/` folder with timestamp and index name
- **Debug Output**: When Debug Mode is enabled, JSON files are saved to `debug_output/` folder
- **Statistics**: The parser logs statistics including:
  - Total number of translation units
  - Languages found in the file
  - Language pair counts

## Error Handling

The system will handle:
- Invalid XML structure
- Missing language codes
- Empty segments
- Translation units with insufficient languages (< 2)

Errors are logged to the log files for troubleshooting.

## Notes

- The system automatically creates the target index if it doesn't exist
- Each translation unit becomes a separate searchable document in OpenSearch
- Language codes are normalized (e.g., "en-GB" → "en") for consistency
- Only translation units with at least 2 languages are uploaded
