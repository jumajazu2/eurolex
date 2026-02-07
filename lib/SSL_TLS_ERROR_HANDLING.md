# SSL/TLS Error Handling System

## Overview

The SSL/TLS Error Handling System provides comprehensive detection, logging, and user notification for certificate verification failures in the LegisTracerEU application. This is particularly important for newly installed applications where users may encounter `HandshakeException` errors with `CERTIFICATE_VERIFY_FAILED` messages.

## Architecture

### Components

1. **`https_error_handler.dart`** - Core error handling module
2. **`opensearch.dart`** - Integration example with OpenSearch operations
3. **`logger.dart`** - Log file management (existing)
4. **`/support` endpoint** - Email reporting (via Node.js server.js)

### Module: `lib/https_error_handler.dart`

The `HttpsErrorHandler` class provides static methods for detecting, logging, and handling SSL/TLS certificate errors.

## Features

### 1. Error Detection

**Method:** `isCertificateError(dynamic error)`

Detects SSL/TLS certificate-related errors by checking for:
- `HandshakeException` type
- Error strings containing: `handshake`, `certificate_verify_failed`, `unable to get local issuer certificate`, `ssl`, `tls`

**Example:**
```dart
try {
  await http.get(Uri.parse('https://example.com'));
} catch (e) {
  if (HttpsErrorHandler.isCertificateError(e)) {
    print('SSL certificate error detected');
  }
}
```

### 2. Detailed Logging

**Method:** `logCertificateError(error, stackTrace, operation)`

Logs comprehensive error information including:
- Timestamp
- Operation being performed
- Server URL and user email
- API key (masked)
- Platform information (OS, version, Dart version)
- Full error message and stack trace

**Log Output Format:**
```
========== SSL/TLS ERROR ==========
Timestamp: 2026-02-06T10:30:45.123456
Operation: CELEX Existence Check for 32019R2424 in eu_7239_reg
Server: https://search.pts-translation.sk
User Email: user@example.com
API Key: 7239

Error Type: HandshakeException
Error Message: HandshakeException: Handshake error in client (OS Error: CERTIFICATE_VERIFY_FAILED...)

Platform: windows
OS Version: Windows 10 Version 22H2
Dart Version: 3.x.x

Stack Trace:
[stack trace details...]

=================================
```

**Returns:** Complete log message as string

### 3. User-Friendly Error Dialog

**Method:** `showCertificateErrorDialog(context, error, operation)`

Displays an informative dialog with:
- Clear error title and icon
- Explanation of the issue
- **Common causes:**
  - Outdated system certificate store (Let's Encrypt root certificates)
  - Corporate proxy or firewall blocking HTTPS
  - Incorrect system date/time
  - Antivirus software intercepting connections
- **Recommended solutions:**
  - Update Windows certificates via Windows Update
  - Verify system date and time
  - Temporarily disable antivirus to test
  - Contact IT administrator if on corporate network
- Operation details and truncated error message
- **Action buttons:**
  - "Close" - Dismiss dialog
  - "Send Error Report" - Email error log to support

**Example:**
```dart
try {
  await someHttpsOperation();
} catch (e) {
  if (HttpsErrorHandler.isCertificateError(e) && context.mounted) {
    await HttpsErrorHandler.showCertificateErrorDialog(
      context,
      e,
      'OpenSearch Index Query',
    );
  }
}
```

### 4. Automatic Error Reporting

**Method:** `_sendErrorReport(context, error, operation)`

Sends detailed error report to support endpoint:
- Collects full error log
- Includes recent application logs (last 3000 characters)
- **Fallback mechanism:** Attempts HTTP if HTTPS fails
- Sends to `$server/support` endpoint with:
  - User email
  - Subject: "SSL/TLS Certificate Error - [operation]"
  - Full error log and recent logs
  - API key for authentication

**Success:** Shows green SnackBar confirmation  
**Failure:** Opens dialog with log file location for manual submission

### 5. Operation Wrapper

**Method:** `wrapHttpOperation<T>({context, operation, operationName, fallbackValue})`

Wraps any HTTP operation with automatic error handling:
```dart
final result = await HttpsErrorHandler.wrapHttpOperation<bool>(
  context: context,
  operation: () async {
    final response = await http.get(Uri.parse(url));
    return response.statusCode == 200;
  },
  operationName: 'Fetch Server Version',
  fallbackValue: false,
);
```

**Features:**
- Automatic error detection
- Logging on certificate errors
- Optional user dialog (if context provided)
- Configurable fallback value
- Rethrows non-certificate errors

## Integration Guide

### Basic Integration (Recommended)

For operations where you want to continue gracefully on SSL errors:

```dart
import 'package:LegisTracerEU/https_error_handler.dart';
import 'dart:io';

Future<bool> myHttpsOperation() async {
  try {
    final response = await http.get(Uri.parse('https://api.example.com/data'));
    return response.statusCode == 200;
  } on HandshakeException catch (e, stackTrace) {
    await HttpsErrorHandler.logCertificateError(
      e,
      stackTrace,
      'My HTTPS Operation',
    );
    return false; // Graceful fallback
  } catch (e, stackTrace) {
    // Check for other SSL errors that might not be HandshakeException
    if (HttpsErrorHandler.isCertificateError(e)) {
      await HttpsErrorHandler.logCertificateError(
        e,
        stackTrace,
        'My HTTPS Operation',
      );
    }
    return false;
  }
}
```

### Integration with User Notification

For interactive operations where users should be informed:

```dart
Future<void> myInteractiveOperation(BuildContext context) async {
  try {
    final response = await http.post(
      Uri.parse('https://api.example.com/action'),
      body: jsonEncode(data),
    );
    // Process response...
  } on HandshakeException catch (e, stackTrace) {
    await HttpsErrorHandler.logCertificateError(
      e,
      stackTrace,
      'Interactive API Operation',
    );
    
    if (context.mounted) {
      await HttpsErrorHandler.showCertificateErrorDialog(
        context,
        e,
        'Interactive API Operation',
      );
    }
  } catch (e, stackTrace) {
    if (HttpsErrorHandler.isCertificateError(e)) {
      await HttpsErrorHandler.logCertificateError(
        e,
        stackTrace,
        'Interactive API Operation',
      );
      
      if (context.mounted) {
        await HttpsErrorHandler.showCertificateErrorDialog(
          context,
          e,
          'Interactive API Operation',
        );
      }
    } else {
      rethrow; // Non-SSL errors should be handled elsewhere
    }
  }
}
```

### Using the Wrapper (Simplest)

```dart
final data = await HttpsErrorHandler.wrapHttpOperation<Map>(
  context: context, // null if no UI needed
  operation: () async {
    final response = await http.get(Uri.parse(apiUrl));
    return jsonDecode(response.body);
  },
  operationName: 'Fetch User Data',
  fallbackValue: {}, // Return empty map on error
);
```

## Implementation Examples

### Example 1: opensearch.dart - CELEX Existence Check

```dart
Future<bool> celexExistsInIndex(String indexName, String celex) async {
  try {
    final resp = await http.post(searchUrl, headers: headers, body: body)
        .timeout(const Duration(seconds: 10));
    
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['hits']['total']['value'] > 0;
    }
    return false;
  } on HandshakeException catch (e, stackTrace) {
    await HttpsErrorHandler.logCertificateError(
      e,
      stackTrace,
      'CELEX Existence Check for $celex in $indexName',
    );
    print('🔒 SSL/TLS Error checking CELEX: $e');
    return false; // Assume doesn't exist on SSL error
  } catch (e, stackTrace) {
    if (HttpsErrorHandler.isCertificateError(e)) {
      await HttpsErrorHandler.logCertificateError(
        e,
        stackTrace,
        'CELEX Existence Check for $celex in $indexName',
      );
    }
    return false;
  }
}
```

### Example 2: opensearch.dart - Delete Index

```dart
Future<bool> deleteOpenSearchIndex(String index) async {
  try {
    final resp = await http.delete(
      Uri.parse('$server/$index'),
      headers: headers,
    );
    return resp.statusCode == 200;
  } on HandshakeException catch (e, stackTrace) {
    await HttpsErrorHandler.logCertificateError(
      e,
      stackTrace,
      'Delete OpenSearch Index: $index',
    );
    print('🔒 SSL/TLS Error deleting index: $e');
    return false;
  } catch (e, stackTrace) {
    if (HttpsErrorHandler.isCertificateError(e)) {
      await HttpsErrorHandler.logCertificateError(
        e,
        stackTrace,
        'Delete OpenSearch Index: $index',
      );
    }
    return false;
  }
}
```

## Server Configuration

### Support Endpoint (server.js)

The `/support` endpoint must be available for error reporting:

```javascript
app.post('/support', express.json({ limit: '1mb' }), async (req, res) => {
  const { email, subject, message, apiKey } = req.body;
  
  // Send email via nodemailer
  await emailTransporter.sendMail({
    from: process.env.SMTP_USER,
    to: process.env.SUPPORT_EMAIL_TO,
    subject: subject,
    text: message,
  });
  
  res.status(200).json({ message: 'Report sent successfully' });
});
```

**Environment Variables Required:**
- `SMTP_HOST` - SMTP server (e.g., smtp.gmail.com)
- `SMTP_PORT` - Port (587 for TLS, 465 for SSL)
- `SMTP_USER` - Email username
- `SMTP_PASS` - Email password or app-specific password
- `SUPPORT_EMAIL_TO` - Destination email for support requests

## Troubleshooting

### Common Issues

#### 1. HandshakeException: CERTIFICATE_VERIFY_FAILED

**Cause:** Outdated or missing root certificates in system store

**Solution:**
- Run Windows Update to get latest certificate updates
- Manually install Let's Encrypt root certificates if needed
- Check that ISRG Root X1 certificate is installed

**Code Handling:**
```dart
// Error is automatically logged with full details
// User sees friendly dialog with solutions
// Operation returns graceful fallback value
```

#### 2. Corporate Proxy Blocking HTTPS

**Cause:** Corporate firewall or proxy intercepting SSL connections

**Solution:**
- Configure proxy settings in application
- Add proxy CA certificate to system trust store
- Contact IT administrator for proxy configuration

**Detection:**
```dart
// Error string may contain "proxy" or "unable to get local issuer"
// HTTP fallback automatically attempted for error reporting
```

#### 3. Antivirus SSL Inspection

**Cause:** Antivirus software (Avast, AVG, Kaspersky) intercepting HTTPS

**Solution:**
- Add application to antivirus exclusions
- Disable SSL scanning temporarily to test
- Reinstall antivirus certificates if corrupted

#### 4. Incorrect System Time

**Cause:** System clock significantly off from real time

**Solution:**
- Sync system time with internet time server
- Verify timezone settings

**Effect:** Certificates appear expired or not yet valid

### Debugging Steps

1. **Check Log File:**
   ```
   %LOCALAPPDATA%\LegisTracerEU\eurolex_log.txt
   ```
   Look for "========== SSL/TLS ERROR ==========" sections

2. **Verify Server Accessibility:**
   ```bash
   curl -v https://search.pts-translation.sk
   ```
   Should return valid SSL certificate information

3. **Test Certificate Chain:**
   ```bash
   openssl s_client -connect search.pts-translation.sk:443 -showcerts
   ```
   Verify certificate chain is valid

4. **Check Windows Certificate Store:**
   - Run `certmgr.msc`
   - Navigate to Trusted Root Certification Authorities → Certificates
   - Look for "ISRG Root X1" (Let's Encrypt root)

## Best Practices

### 1. Always Catch HandshakeException First

```dart
try {
  // HTTPS operation
} on HandshakeException catch (e, stackTrace) {
  // Handle SSL error specifically
} catch (e, stackTrace) {
  // Handle other errors
}
```

### 2. Provide Operation Context

Make operation names descriptive:
- ✅ "CELEX Existence Check for 32019R2424 in eu_7239_reg"
- ✅ "Upload TMX Document: regulations_2024.tmx"
- ❌ "HTTP Request"
- ❌ "API Call"

### 3. Use Graceful Fallbacks

Don't crash the app on SSL errors:
```dart
return false; // For boolean operations
return []; // For list operations
return {}; // For map operations
return null; // When appropriate
```

### 4. Log Before Showing Dialog

```dart
// Log first (always succeeds)
await HttpsErrorHandler.logCertificateError(e, stackTrace, operation);

// Then show dialog (requires mounted context)
if (context.mounted) {
  await HttpsErrorHandler.showCertificateErrorDialog(context, e, operation);
}
```

### 5. Don't Block User Workflow

SSL errors shouldn't prevent users from using other features:
```dart
// ✅ Allow app to continue with reduced functionality
if (!await canConnectToServer()) {
  showOfflineMode();
} else {
  showOnlineMode();
}

// ❌ Don't block entire app
if (!await canConnectToServer()) {
  exit(1); // BAD: Crashes app
}
```

## Testing

### Manual Testing

1. **Test with Invalid Certificate:**
   ```dart
   // Point to server with self-signed certificate
   const testServer = 'https://self-signed.badssl.com/';
   ```

2. **Test with Expired Certificate:**
   ```dart
   const testServer = 'https://expired.badssl.com/';
   ```

3. **Test Error Dialog:**
   - Trigger SSL error
   - Verify dialog appears
   - Click "Send Error Report"
   - Verify email received

4. **Test Logging:**
   - Trigger SSL error
   - Check log file for detailed error entry
   - Verify platform info included

### Automated Testing

```dart
void main() {
  test('isCertificateError detects HandshakeException', () {
    final error = HandshakeException('CERTIFICATE_VERIFY_FAILED');
    expect(HttpsErrorHandler.isCertificateError(error), isTrue);
  });

  test('isCertificateError detects SSL error strings', () {
    final error = Exception('SSL handshake failed');
    expect(HttpsErrorHandler.isCertificateError(error), isTrue);
  });

  test('isCertificateError ignores other errors', () {
    final error = Exception('Network timeout');
    expect(HttpsErrorHandler.isCertificateError(error), isFalse);
  });
}
```

## Performance Considerations

### Logging Performance

- **Log writes are asynchronous** - don't block main thread
- **Log file grows over time** - implement rotation if needed
- **Reading logs for error reports** - limited to last 3000 characters

### Error Reporting Performance

- **HTTP fallback delays UI** - max 10 second timeout
- **Loading dialog prevents confusion** - user sees progress
- **Background operations preferred** - don't wait for email confirmation

### Memory Usage

- **Log messages buffered in memory** - StringBuffer for efficiency
- **Stack traces can be large** - already included, accept the cost
- **User dialogs released on close** - no memory leaks

## Security Considerations

### 1. Sensitive Data in Logs

**Current Approach:**
- API keys logged (for debugging)
- User emails logged (for identification)
- Server URLs logged (for context)

**Recommendations:**
- Mask API keys in production: `7239` → `72**`
- Hash emails if privacy required
- Review logs before sending to support

### 2. Email Reporting

**Security Measures:**
- SMTP credentials in environment variables (not code)
- TLS encryption for email transmission
- Authentication required for `/support` endpoint

**Risks:**
- Logs may contain sensitive search queries
- User IP addresses in server logs
- System information disclosure

### 3. HTTP Fallback

**Why It Exists:**
- SSL errors prevent HTTPS connections
- Need to report SSL errors even when SSL is broken
- HTTP only used for error reporting, not data transfer

**Security Trade-off:**
- Error logs sent over unencrypted HTTP
- Only triggered when HTTPS already failing
- Alternative is no error reporting at all

## Future Enhancements

### Planned Improvements

1. **Certificate Pinning** - Validate specific certificate fingerprints
2. **Custom Trust Store** - Include fallback certificates in app bundle
3. **Automatic Recovery** - Retry with different SSL configurations
4. **Analytics Integration** - Track SSL error frequency and patterns
5. **User Settings** - Allow disabling certificate validation (dev mode only)
6. **Localization** - Translate error dialogs into multiple languages
7. **Interactive Troubleshooting** - Guided wizard for common issues

### API Additions

Potential future methods:
```dart
// Test server connectivity with multiple strategies
Future<ConnectionResult> testServerConnection(String url);

// Install custom root certificate
Future<bool> installCustomCertificate(Uint8List certData);

// Export error report to file
Future<File> exportErrorReport(String errorId);

// Get SSL certificate info
Future<CertificateInfo> getServerCertificate(String url);
```

## Support and Debugging

### Getting Help

If SSL errors persist after following troubleshooting steps:

1. **Generate Error Report:**
   - Trigger the error
   - Click "Send Error Report" in dialog
   - Include report ID in support request

2. **Contact Support:**
   - Email: support@pts-translation.sk
   - Subject: "SSL/TLS Error - [operation]"
   - Attach: eurolex_log.txt file

3. **Provide Context:**
   - Windows version (run `winver`)
   - Application version
   - Internet connection type (direct/proxy/VPN)
   - Antivirus software name and version
   - Recent Windows updates installed

### Internal Debugging

For developers working on the codebase:

```dart
// Enable verbose SSL logging
import 'dart:io';

void enableSslDebugging() {
  // Set environment variable before creating HTTP clients
  Platform.environment['DART_VM_OPTIONS'] = '--verbose_debug';
}

// Test with custom HttpClient
final client = HttpClient()
  ..badCertificateCallback = 
      (X509Certificate cert, String host, int port) {
    print('Certificate for $host:');
    print('Subject: ${cert.subject}');
    print('Issuer: ${cert.issuer}');
    print('Valid from: ${cert.startValidity}');
    print('Valid to: ${cert.endValidity}');
    return true; // Accept anyway for debugging
  };
```

## Changelog

### Version 1.0.0 (2026-02-05)
- Initial implementation of SSL/TLS error handling system
- Detection, logging, user dialogs, and email reporting
- Integration into opensearch.dart operations
- HTTP fallback for error reporting

### Version 0.9.9 (2026-02-06)
- Updated error dialog copy for clarity
- Added "Open Log Folder" option on send failure
- Improved logging format with platform details

---

## Summary

The SSL/TLS Error Handling System provides robust, user-friendly error handling for certificate verification failures common in newly installed applications. Key features:

- ✅ **Automatic Detection** - Catches HandshakeException and SSL-related errors
- ✅ **Detailed Logging** - Full context including platform, operation, and stack trace
- ✅ **User-Friendly Dialogs** - Clear explanations and actionable solutions
- ✅ **Email Reporting** - Automatic error submission with HTTP fallback
- ✅ **Graceful Degradation** - Operations continue with appropriate fallback values
- ✅ **Easy Integration** - Simple wrapper methods and clear patterns

For questions or issues, contact the development team or refer to the troubleshooting section above.
