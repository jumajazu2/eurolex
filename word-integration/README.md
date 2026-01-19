# Bible Search Word Integration

Two solutions for integrating Bible search into Microsoft Word:

## 1. VBA Macro (Quick Testing) ⚡

**Location:** `word-integration/BibleSearchMacro.vba`

### Installation:
1. Open Word → Press `Alt+F11` (opens VBA Editor)
2. Insert → Module
3. Copy-paste the code from `BibleSearchMacro.vba`
4. Add reference: Tools → References → Check "Microsoft WinHTTP Services, version 5.1"
5. Insert → UserForm → Name it `frmBibleResults`
6. Add controls to the form:
   - Label `lblTitle` (Caption: "Bible Search Results")
   - Label `lblSearchTerm` (Caption: "Search term:")
   - TextBox `txtSearchTerm` (Locked: True)
   - TextBox `txtResults` (MultiLine: True, ScrollBars: Vertical, 400x300)
   - Button `btnInsert` (Caption: "Insert Selected")
   - Button `btnClose` (Caption: "Close")

### Usage:
1. Select text in Word
2. Run macro: `SearchBibleFromSelection` (assign to keyboard shortcut: Alt+F8 → Options → Shortcut key)
3. View results in popup form
4. Select verse and click "Insert" to add to document

### Pros:
✅ Quick setup (15 minutes)
✅ No external hosting needed
✅ Works offline after initial setup

### Cons:
❌ Desktop Word only
❌ Users must enable macros
❌ Basic UI

---

## 2. Office Add-in (Production) 🚀

**Location:** `word-integration/office-addin/`

### Setup:
```powershell
cd word-integration/office-addin
npm install
npm run start
```

This will:
- Install dependencies
- Start local dev server (https://localhost:3000)
- Sideload add-in into Word

### Usage:
1. Open Word
2. Click "Bible Search" button in Home tab
3. Task pane opens on the right
4. Select text or type search
5. Click results to insert verses

### Features:
✅ Modern UI with live search
✅ Works in Word Online & Desktop
✅ Cross-platform (Windows/Mac/Web)
✅ No macro security warnings
✅ Professional appearance

### Deployment:
**For personal use:**
- Keep running on localhost:3000
- Or host on your server

**For distribution:**
- Upload files to web server
- Update manifest.xml with production URLs
- Submit to Office Store OR share manifest file

### File Structure:
```
office-addin/
├── manifest.xml          # Add-in configuration
├── package.json          # Dependencies
└── src/
    └── taskpane/
        └── taskpane.html # Main UI (standalone file)
```

---

## API Configuration

Both solutions use:
- **URL:** `https://search.pts-translation.sk/eu_7239_bibles/_search`
- **API Key:** `7239`
- **Email:** `juraj.kuban.sk@gmail.com`

Update these values in:
- VBA: Lines 12-14 of BibleSearchMacro.vba
- Add-in: Lines 145-147 of taskpane.html

---

## Comparison

| Feature | VBA Macro | Office Add-in |
|---------|-----------|---------------|
| Setup Time | 15 min | 30 min |
| Works Online | ❌ | ✅ |
| Security | Requires macros | No warnings |
| UI Quality | Basic | Modern |
| Distribution | Copy VBA file | Host on web |
| Maintenance | Manual updates | Auto-update |

---

## Recommendation

**Start with VBA** to test the concept → **Move to Add-in** for production use.

Both are ready to use with your Bible API! 🎉
