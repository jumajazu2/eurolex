# TMX Upload - Quick Reference

## 🎯 Quick Start (3 Steps)

1. **Open Upload Tab**
   - Click "Upload References" → "Upload Own Reference Documents"

2. **Select Index**
   - Choose from dropdown OR enter new name (lowercase, letters/numbers/dots/dashes)

3. **Upload File**
   - Click "Pick TMX/Reference file and upload"
   - Select your `.tmx` file
   - Done! ✅

## 📁 What is TMX?

TMX = Translation Memory eXchange format - XML files containing bilingual/multilingual translation pairs.

**Example:**
```xml
<tu>
  <tuv xml:lang="en-GB"><seg>Hello</seg></tuv>
  <tuv xml:lang="sk-SK"><seg>Ahoj</seg></tuv>
</tu>
```

## ✨ Features

- ✅ Multiple language pairs (2+ languages per entry)
- ✅ Preserves metadata (dates, creator)
- ✅ Automatic language code normalization (en-GB → en)
- ✅ Debug mode: saves JSON to `debug_output/`
- ✅ Simulate mode: test without uploading
- ✅ Full logging to `logs/` folder

## 🔍 Output Format

Each TMX translation unit becomes:
```json
{
  "sequence_id": 0,
  "en_text": "Hello",
  "sk_text": "Ahoj",
  "source": "TMX",
  "filename": "my_translations.tmx",
  "languages": ["en", "sk"]
}
```

## ⚙️ Options

**Simulate** ☑️ - Test parsing without uploading
**Debug Mode** ☑️ - Save JSON files for troubleshooting

## 📝 Logs

- `logs/[timestamp]_[index]_tmx.log` - Parsing log
- `debug_output/tmx_[file]_[timestamp].json` - Debug output (if enabled)

## ❗ Requirements

- TMX file must have `<body>` with `<tu>` elements
- Each `<tu>` must have at least 2 languages
- Language codes in `xml:lang` attribute (e.g., "en-GB", "sk-SK")

## 🚫 Troubleshooting

**File not parsing?**
- Check it's valid XML
- Ensure it has `<body>` and `<tu>` elements
- Look at logs in `logs/` folder

**Nothing uploaded?**
- Disable "Simulate" mode
- Check index name is selected
- Verify OpenSearch connection

**Want to debug?**
- Enable "Debug Mode" checkbox
- Check `debug_output/` folder for JSON

## 📚 Full Documentation

See [TMX_UPLOAD_GUIDE.md](TMX_UPLOAD_GUIDE.md) for complete details.

---
**Ready to use!** Just pick your TMX file and upload. 🚀
