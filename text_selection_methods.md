# Text Selection Methods for LegisTracerEU

## Overview

This document outlines various methods to capture selected text from any Windows application and search it in LegisTracerEU, eliminating the need for manual copy-paste into the app.

---

## Method 1: Global Hotkey + Basic Clipboard

### Description
User selects text, presses hotkey (e.g., `Ctrl+Shift+L`), app reads clipboard and searches.

### Implementation
```dart
// Package: hotkey_manager: ^0.2.3
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flutter/services.dart';

HotKey _hotKey = HotKey(
  key: PhysicalKeyboardKey.keyL,
  modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
);

await hotKeyManager.register(
  _hotKey,
  keyDownHandler: (hotKey) async {
    final clipboardText = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardText?.text != null) {
      performSearch(clipboardText!.text!);
    }
  },
);
```

### Pros
- ✅ Simple, reliable, fast
- ✅ Works with any selectable text
- ✅ User has explicit control
- ✅ Low resource usage (~1 MB RAM, 0% CPU idle)
- ✅ Instant response (<5ms)
- ✅ Small package size (+1 MB)

### Cons
- ❌ Only works with selectable text (not images/PDFs)
- ❌ User must manually copy text first
- ❌ Overwrites clipboard content
- ❌ Hotkey might conflict with other apps
- ❌ Requires app to be running
- ❌ ~50% of legal documents are scanned (can't read)

### Resource Usage
- **RAM:** ~1-2 MB additional
- **CPU (idle):** 0%
- **CPU (active):** <1%
- **Battery impact:** Negligible
- **App size:** +1 MB

### Best For
- Quick lookups during active work
- Users who prefer keyboard shortcuts
- Standard digital text documents

---

## Method 2: Smart Clipboard (Save/Restore)

### Description
Like Method 1, but automatically saves and restores clipboard content to avoid pollution.

### Implementation
```dart
Future<String?> getSelectedTextSmart() async {
  // 1. Save current clipboard
  final oldClipboard = await Clipboard.getData(Clipboard.kTextPlain);
  
  // 2. Simulate Ctrl+C to copy selection
  await simulateKeyPress(LogicalKeyboardKey.keyC, control: true);
  await Future.delayed(Duration(milliseconds: 50)); // Wait for copy
  
  // 3. Read new clipboard
  final selected = await Clipboard.getData(Clipboard.kTextPlain);
  
  // 4. Restore old clipboard immediately
  if (oldClipboard?.text != null) {
    await Clipboard.setData(ClipboardData(text: oldClipboard!.text!));
  }
  
  return selected?.text;
}

// Hotkey handler
await hotKeyManager.register(_hotKey, keyDownHandler: (hotKey) async {
  final text = await getSelectedTextSmart();
  if (text != null && text.isNotEmpty) {
    performSearch(text);
  }
});
```

### Additional Package Needed
```yaml
dependencies:
  flutter_window_manager: ^0.2.0  # For simulating key press
```

### Pros
- ✅ All benefits of Method 1
- ✅ **No clipboard pollution** (user never notices)
- ✅ Works with all apps that support Ctrl+C
- ✅ Simple implementation
- ✅ Fast (50ms save/copy/restore cycle)

### Cons
- ❌ Same limitations as Method 1 (no images/PDFs)
- ❌ Still technically uses clipboard (briefly)
- ❌ Tiny race condition possibility (50ms window)

### Resource Usage
Same as Method 1

### Best For
- Users sensitive about clipboard being overwritten
- Professional workflows with tight clipboard management
- **Recommended starting point**

---

## Method 3: Automatic Clipboard Monitoring

### Description
App continuously monitors clipboard, auto-searches when new text is copied.

### Implementation
```dart
// Package: clipboard_watcher: ^0.2.0
import 'package:clipboard_watcher/clipboard_watcher.dart';

class MyApp extends StatefulWidget with ClipboardListener {
  @override
  void onClipboardChanged() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.length > 3) {
      // Show search popup or auto-search
      showSearchDialog(data.text!);
    }
  }
  
  @override
  void initState() {
    super.initState();
    clipboardWatcher.addListener(this);
    clipboardWatcher.start();
  }
}
```

### Pros
- ✅ No hotkey needed - works on any copy
- ✅ Seamless experience
- ✅ Works anywhere user copies text

### Cons
- ❌ Auto-searches every copy (potentially annoying)
- ❌ Privacy concerns (monitors all clipboard activity)
- ❌ May trigger on unintended copies
- ❌ Slightly higher resource usage (0.1-0.5% CPU)

### Resource Usage
- **RAM:** ~2 MB
- **CPU (idle):** 0.1-0.5%
- **Battery impact:** Very low

### Best For
- Power users who copy frequently
- As optional feature (user-enabled in settings)
- Background monitoring mode

---

## Method 4: OCR Screen Capture

### Description
User presses hotkey, selects screen area, app OCRs image and searches text.

### Implementation
```dart
// Packages:
// - screen_capturer: ^0.2.0
// - google_mlkit_text_recognition: ^0.13.0

import 'package:screen_capturer/screen_capturer.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<void> captureAndOCR() async {
  // 1. Capture screen region
  final capturedData = await screenCapturer.capture(
    mode: CaptureMode.region, // User selects area
  );
  
  if (capturedData != null) {
    // 2. Perform OCR
    final inputImage = InputImage.fromFilePath(capturedData.imagePath!);
    final textRecognizer = TextRecognizer();
    final recognizedText = await textRecognizer.processImage(inputImage);
    
    // 3. Search the text
    performSearch(recognizedText.text);
    
    await textRecognizer.close();
  }
}
```

### Pros
- ✅ Works on images, PDFs, scanned documents
- ✅ Captures text from videos, locked PDFs
- ✅ No need to select text
- ✅ Covers ~50% of legal documents (scans)

### Cons
- ❌ Slow (500ms-3s processing time)
- ❌ Accuracy varies (70-99% depending on quality)
- ❌ Large package size (+50-200 MB)
- ❌ High CPU usage during OCR (20-40%)
- ❌ Battery drain
- ❌ Requires screen capture permission
- ❌ 4-step UX vs 2-step clipboard method
- ❌ Fails on: poor scans, watermarks, small text, rotated text

### Resource Usage
- **RAM:** ~50 MB
- **CPU (processing):** 20-40%
- **App size:** +50-200 MB (depending on language models)
- **Processing time:** 500-3000ms

### Accuracy by Document Type
- **Good quality text:** 95-99%
- **Poor quality scans:** 70-85%
- **Handwriting:** 60-80%
- **Complex tables:** 80-90%
- **Legal citations:** Variable (punctuation critical)

### Best For
- Scanned court decisions
- Image-based PDFs
- Screenshots of legislation
- **Phase 2 feature** (after clipboard method proven)

---

## Method 5: Windows UI Automation (Direct Selection Reading)

### Description
Read selected text directly from Windows UI controls without using clipboard at all.

### Implementation
```dart
// Via FFI to Windows UI Automation COM API
import 'dart:ffi';
import 'package:ffi/ffi.dart';

Future<String?> getSelectedTextViaUIA() async {
  // 1. Get foreground window
  // 2. Get focused UI element in that window
  // 3. Query IUIAutomationTextPattern interface
  // 4. Get selected text range
  // 5. Return text directly (no clipboard)
  
  return selectedText;
}
```

### Pros
- ✅ **True clipboard bypass** - no clipboard touched at all
- ✅ Works with most Windows apps
- ✅ Fast (native Windows API)
- ✅ No save/restore needed

### Cons
- ❌ Complex FFI implementation
- ❌ Some apps don't expose text via UIA (legacy apps)
- ❌ Requires significant development effort
- ❌ Windows 7+ only
- ❌ App-specific quirks and edge cases

### Resource Usage
Same as Method 1

### Best For
- Advanced implementation after basic methods proven
- Apps that block clipboard access
- Maximum privacy/security scenarios

---

## Method 6: HTTP Endpoint + AutoHotkey

### Description
App runs HTTP server, external AutoHotkey script sends selected text via HTTP POST (like Trados plugin).

### Implementation

**Flutter App:**
```dart
// Package: shelf: ^1.4.0
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> startTextReceiver() async {
  final handler = (Request request) async {
    if (request.method == 'POST' && request.url.path == 'search') {
      final text = await request.readAsString();
      performSearch(text);
      return Response.ok('Received');
    }
    return Response.notFound('Not found');
  };
  
  await io.serve(handler, 'localhost', 8765);
  print('Text receiver listening on http://localhost:8765');
}
```

**AutoHotkey Script (user installs):**
```ahk
; LegisTracerEU.ahk
^+l::  ; Ctrl+Shift+L
{
    ; Save clipboard
    oldClipboard := ClipboardAll
    Clipboard := ""
    
    ; Copy selection
    Send ^c
    ClipWait 0.5
    selectedText := Clipboard
    
    ; Send to app via HTTP
    whr := ComObject("WinHttp.WinHttpRequest.5.1")
    whr.Open("POST", "http://localhost:8765/search", false)
    whr.Send(selectedText)
    
    ; Restore clipboard
    Clipboard := oldClipboard
}
```

### Pros
- ✅ Clean separation of concerns
- ✅ True clipboard save/restore (from AHK side)
- ✅ Works system-wide
- ✅ Same pattern as Trados plugin
- ✅ Can customize hotkey in AHK script easily

### Cons
- ❌ Requires AutoHotkey installed
- ❌ Extra setup step for users
- ❌ Two-component system (app + script)
- ❌ HTTP security considerations (localhost only)

### Resource Usage
- **Flutter app:** Same as Method 1 + HTTP server (~2 MB)
- **AutoHotkey:** ~5 MB RAM, 0% CPU idle

### Best For
- Users already familiar with AutoHotkey
- Advanced/technical users
- When compatibility with external integrations needed

---

## Method 7: System Tray Integration

### Description
App lives in system tray with right-click menu for quick search.

### Implementation
```dart
// Package: tray_manager: ^0.2.0
import 'package:tray_manager/tray_manager.dart';

await trayManager.setContextMenu(
  Menu(items: [
    MenuItem(
      key: 'search_clipboard',
      label: 'Search Clipboard Text (Ctrl+Shift+L)',
    ),
    MenuItem.separator(),
    MenuItem(key: 'exit', label: 'Exit'),
  ]),
);

// Combined with global hotkey from Method 1
```

### Pros
- ✅ Always accessible
- ✅ Doesn't clutter taskbar
- ✅ Familiar UX pattern
- ✅ Can combine with any other method

### Cons
- ❌ Less discoverable than window
- ❌ Still needs hotkey for efficiency

### Resource Usage
+2 MB RAM for tray icon

### Best For
- Background operation mode
- Minimal UI footprint
- Combined with other methods

---

## Comparison Matrix

| Feature | Method 1<br>Basic Clipboard | Method 2<br>Smart Clipboard | Method 3<br>Auto Monitor | Method 4<br>OCR | Method 5<br>UI Automation | Method 6<br>HTTP+AHK |
|---------|----------|-----------|------------|---------|---------------|-------------|
| **Speed** | Instant | Instant | Instant | 0.5-3s | Instant | Instant |
| **Clipboard Pollution** | ❌ Yes | ✅ No | N/A | N/A | ✅ No | ✅ No |
| **Works on Images** | ❌ No | ❌ No | ❌ No | ✅ Yes | ❌ No | ❌ No |
| **Works on PDFs** | Partial | Partial | Partial | ✅ Yes | Partial | Partial |
| **App Size** | +1 MB | +1 MB | +2 MB | +50-200 MB | +1 MB | +2 MB |
| **CPU (Idle)** | 0% | 0% | 0.1-0.5% | 0% | 0% | 0% |
| **CPU (Active)** | <1% | <1% | <1% | 20-40% | <1% | <1% |
| **Complexity** | Easy | Medium | Easy | High | Very High | Medium |
| **External Deps** | None | None | None | None | None | AutoHotkey |
| **User Steps** | 2 | 2 | 1 | 4 | 2 | 2 |
| **Accuracy** | 100% | 100% | 100% | 70-99% | 100% | 100% |
| **Privacy** | Low | Low | High | Low | Low | Low |

---

## Recommended Implementation Strategy

### Phase 1: MVP (Immediate)
**Implement Method 2: Smart Clipboard**

Why?
- ✅ Best balance of features vs complexity
- ✅ No clipboard pollution (user-friendly)
- ✅ Works everywhere
- ✅ Simple implementation
- ✅ Low resource usage

```yaml
# Add to pubspec.yaml
dependencies:
  hotkey_manager: ^0.2.3
```

### Phase 2: Optional Features (Future)
Add as user-configurable options:

1. **Method 3: Auto Clipboard Monitor**
   - Off by default
   - Enable in Settings for power users

2. **Method 4: OCR**
   - Separate download/activation
   - Only for users who need it
   - Or use cloud API (no bloat)

3. **Method 7: System Tray**
   - Always-on background mode
   - Combine with Method 2

### Phase 3: Advanced (Optional)
1. **Method 5: UI Automation** - for maximum privacy
2. **Method 6: HTTP Endpoint** - for Trados-like integration

---

## Settings UI Mockup

```
┌─ Quick Search Settings ─────────────────────────────┐
│                                                      │
│ ☑ Enable global hotkey                              │
│   [Ctrl] + [Shift] + [L]  [Customize...]            │
│                                                      │
│ ☑ Restore clipboard after search (recommended)      │
│                                                      │
│ ☐ Auto-search on clipboard change                   │
│   ⚠ Searches every time you copy text               │
│                                                      │
│ ☐ Run in system tray                                │
│                                                      │
│ ─────── Advanced ───────────────────────────────    │
│                                                      │
│ ☐ Enable OCR for images (downloads 50 MB)           │
│   [Download OCR Model]                               │
│                                                      │
│ ☐ Enable HTTP endpoint (Port: [8765])               │
│   For external integrations                         │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## Legal/Privacy Considerations

### Clipboard Access
**Disclosure needed:**
> "LegisTracerEU reads your clipboard when you press Ctrl+Shift+L to search selected text. 
> Clipboard content is immediately restored and never stored or transmitted."

### Screen Capture (OCR)
**Permission required:**
> "OCR feature requires permission to capture screen content. 
> Captured images are processed locally and immediately deleted."

### Background Monitoring
**Clear opt-in:**
> "Clipboard monitoring watches all text you copy. 
> Enable only if you want automatic search suggestions."

---

## Troubleshooting Guide

### Hotkey Not Working
1. Check if another app is using the same hotkey
2. Try customizing to different key combination
3. Verify app has focus/is running
4. Check Windows hotkey conflicts (Win + G, etc.)

### Clipboard Not Restoring
1. Increase delay in smart clipboard (50ms → 100ms)
2. Some apps block clipboard access (security software)
3. Check clipboard history is enabled (Windows 11)

### OCR Low Accuracy
1. Ensure good image quality (>150 DPI)
2. Use higher resolution capture
3. Clean/enhance image before OCR
4. Try different OCR engine (Google Cloud Vision API)

### Performance Issues
1. Disable auto-monitor if enabled
2. Reduce OCR image size
3. Close other clipboard monitoring tools
4. Check antivirus isn't blocking hotkey registration

---

## Cost Analysis (Development Time)

| Method | Implementation Time | Testing Time | Total |
|--------|-------------------|--------------|-------|
| Method 1 | 2 hours | 1 hour | 3 hours |
| Method 2 | 4 hours | 2 hours | 6 hours |
| Method 3 | 3 hours | 2 hours | 5 hours |
| Method 4 | 16 hours | 8 hours | 24 hours |
| Method 5 | 40 hours | 16 hours | 56 hours |
| Method 6 | 8 hours | 4 hours | 12 hours |
| Method 7 | 4 hours | 2 hours | 6 hours |

**Recommended MVP:** Method 2 = **6 hours total** ✅

---

## References

- [hotkey_manager package](https://pub.dev/packages/hotkey_manager)
- [clipboard_watcher package](https://pub.dev/packages/clipboard_watcher)
- [screen_capturer package](https://pub.dev/packages/screen_capturer)
- [google_mlkit_text_recognition package](https://pub.dev/packages/google_mlkit_text_recognition)
- [Windows UI Automation API](https://docs.microsoft.com/en-us/windows/win32/winauto/entry-uiauto-win32)
- [AutoHotkey Documentation](https://www.autohotkey.com/docs/)

---

## Next Steps

1. ✅ Review this document and choose implementation method
2. ⏳ Implement Method 2 (Smart Clipboard) - 6 hours
3. ⏳ Add Settings UI for hotkey customization - 2 hours
4. ⏳ User testing and feedback - 1 week
5. ⏳ Consider Phase 2 features based on feedback

**Total MVP Time:** ~8 hours development + user testing
