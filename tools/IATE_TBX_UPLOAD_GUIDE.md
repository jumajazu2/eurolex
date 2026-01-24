# IATE TBX Termbase Upload Guide

## Overview

This guide explains how to upload the IATE (Inter-Active Terminology for Europe) termbase in TBX format to OpenSearch using the command-line tool.

## What is IATE TBX?

- **Format**: TBX (TermBase eXchange) - XML-based terminology exchange format
- **Size**: ~1.5 GB
- **Content**: Multilingual EU terminology database with concept-based entries
- **Structure**: Each `<conceptEntry>` contains terms in multiple languages with metadata

## Prerequisites

1. Download IATE TBX file from: https://iate.europa.eu/download-iate
2. Ensure you have Dart SDK installed
3. Have your OpenSearch credentials ready (email + passkey)

## Installation

The tool is located at: `tools/tbx_to_opensearch.dart`

Install required dependencies:
```bash
dart pub get
```

## Usage

### Basic Upload

```bash
dart tools/tbx_to_opensearch.dart \
  --file path/to/IATE-Export-2026.tbx \
  --index iate_terminology \
  --server search.pts-translation.sk \
  --email your@email.com \
  --passkey your-passkey
```

### With Options

```bash
dart tools/tbx_to_opensearch.dart \
  --file IATE.tbx \
  --index iate_terminology \
  --server search.pts-translation.sk \
  --email your@email.com \
  --passkey your-passkey \
  --batch-size 1000 \
  --verbose
```

### Dry Run (Test Parsing Without Uploading)

```bash
dart tools/tbx_to_opensearch.dart \
  --file IATE.tbx \
  --index iate_terminology \
  --server search.pts-translation.sk \
  --email your@email.com \
  --passkey your-passkey \
  --dry-run
```

## Command-Line Options

| Option | Short | Description | Required | Default |
|--------|-------|-------------|----------|---------|
| `--file` | `-f` | Path to TBX file | Yes | - |
| `--index` | `-i` | OpenSearch index name | Yes | - |
| `--server` | `-s` | OpenSearch server | Yes | - |
| `--email` | `-e` | User email | Yes | - |
| `--passkey` | `-p` | Access key | Yes | - |
| `--batch-size` | `-b` | Concepts per batch | No | 500 |
| `--dry-run` | `-d` | Parse without upload | No | false |
| `--verbose` | `-v` | Detailed logging | No | false |
| `--help` | `-h` | Show usage | No | false |

## Document Structure

Each IATE concept is converted to an OpenSearch document:

```json
{
  "concept_id": "777942",
  "filename": "IATE-Export-2026.tbx",
  "subject_field": "international agreement;EU relations;ENVIRONMENT",
  "languages": ["en", "de", "fr", "sk", "cs", ...],
  "en_text": "Vienna Convention, Vienna Convention for the Protection of the Ozone Layer",
  "de_text": "Wiener Übereinkommen zum Schutz der Ozonschicht",
  "fr_text": "Convention de Vienne pour la protection de la couche d'ozone",
  "sk_text": "Viedenský dohovor o ochrane ozónovej vrstvy",
  "term_types": ["fullForm", "shortForm"],
  "reliability_codes": [9, 10]
}
```

### Field Descriptions

- **concept_id**: Unique IATE concept identifier
- **filename**: Source TBX filename
- **subject_field**: Semicolon-separated subject domains
- **languages**: Array of language codes present in the entry
- **{lang}_text**: Terms in each language (comma-separated if multiple)
- **term_types**: Types of terms (fullForm, shortForm, abbreviation, etc.)
- **reliability_codes**: Quality indicators (1-10 scale)

## OpenSearch Template

The tool automatically creates an index template: `iate-terminology-template`

Template features:
- **Keyword fields**: concept_id, filename, languages, term_types
- **Text fields**: subject_field with standard_folding analyzer
- **Dynamic templates**: Automatically map `*_text` fields as searchable text
- **Integer fields**: reliability_codes for quality filtering

## Performance

For a 1.5 GB TBX file with ~1.4 million concepts:

- **Parsing**: Stream-based (low memory footprint)
- **Batch uploads**: 500-1000 concepts per request
- **Estimated time**: 2-4 hours (depending on network speed)
- **Progress updates**: Every 1,000 concepts processed

## Monitoring Progress

The tool outputs:
```
Starting TBX upload...
File: IATE-Export-2026.tbx
Index: iate_terminology
Server: search.pts-translation.sk
Batch size: 500

File size: 1.47 GB

Creating index template...
Template created successfully

Processed: 1000 concepts...
Processed: 2000 concepts...
...
Processed: 1400000 concepts...

Upload complete!
Processed: 1,423,456 concepts
Uploaded: 1,423,456 concepts
Errors: 0
Duration: 187m 34s
```

## Searching IATE Terminology

After upload, you can search the terminology index from your application using the same search patterns as EUR-Lex documents:

```dart
// Example search query
{
  "query": {
    "bool": {
      "must": [
        {
          "multi_match": {
            "query": "ozone layer",
            "fields": ["en_text", "de_text", "fr_text"]
          }
        }
      ],
      "filter": [
        {"terms": {"languages": ["en", "sk"]}},
        {"range": {"reliability_codes": {"gte": 9}}}
      ]
    }
  }
}
```

## Troubleshooting

### Out of Memory Error

If you encounter memory issues:
- The tool uses stream parsing, so memory should remain low
- Try reducing `--batch-size` to 250 or 100

### Network Timeouts

For large batches:
- Reduce `--batch-size` to avoid timeouts
- Check your network connection stability

### Parsing Errors

Some concepts may fail to parse:
- The tool continues processing on errors
- Use `--verbose` to see detailed error messages
- Check error count in final statistics

### Template Already Exists

If the template exists:
- The tool will attempt to update it
- You can manually delete: `DELETE /_index_template/iate-terminology-template`

## Updating IATE Data

To refresh with new IATE export:

1. Delete old index:
   ```bash
   DELETE /iate_yourpasskey_iate_terminology
   ```

2. Run upload with new file:
   ```bash
   dart tools/tbx_to_opensearch.dart --file IATE-New.tbx ...
   ```

## Integration with Main App

The IATE terminology index is **separate** from EUR-Lex indices. To integrate searches:

1. Add terminology search option in UI
2. Query both document and terminology indices
3. Merge results or display separately
4. Filter by subject_field for domain-specific terminology

## Best Practices

1. **Test first**: Use `--dry-run` to validate parsing
2. **Monitor progress**: Keep terminal visible during long uploads
3. **Check errors**: Review error count in final statistics
4. **Verify data**: Search for known terms after upload completes
5. **Backup**: Keep original TBX file for re-uploads if needed

## Additional Resources

- IATE Website: https://iate.europa.eu/
- TBX Standard: https://www.tbxinfo.net/
- OpenSearch Bulk API: https://opensearch.org/docs/latest/api-reference/document-apis/bulk/
