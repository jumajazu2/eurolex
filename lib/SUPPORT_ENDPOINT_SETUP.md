# Support Endpoint Setup Guide

## Overview
The `/support` endpoint has been added to receive error/support reports from your app, log them, and forward them via email. This hides your personal email from users.

## Features
- ✅ Rate limiting: 5 requests per IP per day (prevents spam)
- ✅ Logs all support requests to `logs/support_requests.log`
- ✅ Forwards requests to your email via SMTP
- ✅ Sets replyTo to user's email for easy responses
- ✅ Input validation and sanitization
- ✅ Unique request IDs for tracking

## Installation

### 1. Install nodemailer
```bash
npm install nodemailer
```

### 2. Configure Environment Variables
Set these environment variables on your server:

```bash
# SMTP Configuration
SMTP_HOST=smtp.gmail.com          # Gmail SMTP server (or your provider)
SMTP_PORT=587                      # Port 587 for TLS, 465 for SSL
SMTP_USER=your-email@gmail.com     # Your email address
SMTP_PASS=your-app-password        # Gmail App Password (not your regular password)
SUPPORT_EMAIL_TO=your-email@gmail.com  # Where to receive support requests

# Example for Windows PowerShell:
$env:SMTP_HOST = "smtp.gmail.com"
$env:SMTP_PORT = "587"
$env:SMTP_USER = "your-email@gmail.com"
$env:SMTP_PASS = "your-app-password"
$env:SUPPORT_EMAIL_TO = "your-email@gmail.com"

# Example for Linux/Mac:
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT="587"
export SMTP_USER="your-email@gmail.com"
export SMTP_PASS="your-app-password"
export SUPPORT_EMAIL_TO="your-email@gmail.com"
```

### 3. Gmail App Password Setup (if using Gmail)
If using Gmail, you need an App Password:
1. Go to https://myaccount.google.com/security
2. Enable 2-Factor Authentication (required)
3. Go to https://myaccount.google.com/apppasswords
4. Generate a new App Password for "Mail"
5. Use this 16-character password as `SMTP_PASS`

### 4. Alternative Email Providers
- **Outlook/Hotmail**: `smtp.office365.com:587`
- **Yahoo**: `smtp.mail.yahoo.com:587`
- **Custom SMTP**: Use your provider's SMTP settings

## API Usage

### Endpoint
```
POST /support
Content-Type: application/json
```

### Request Body
```json
{
  "email": "user@example.com",      // Required: user's email (max 100 chars)
  "subject": "Bug Report",          // Required: subject line (max 200 chars)
  "message": "Description...",      // Required: message body (max 5000 chars)
  "apiKey": "1234"                  // Optional: user's API key for tracking
}
```

### Success Response (200)
```json
{
  "success": true,
  "message": "Support request received and will be forwarded",
  "requestId": "SUP-1705582800000-abc123"
}
```

### Rate Limit Response (429)
```json
{
  "error": "Rate limit exceeded",
  "message": "Maximum 5 support requests per day allowed."
}
```

### Validation Error (400)
```json
{
  "error": "Missing required fields",
  "message": "email, subject, and message are required"
}
```

## Dart/Flutter Integration Example

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> submitSupportRequest({
  required String email,
  required String subject,
  required String message,
  String? apiKey,
}) async {
  final url = Uri.parse('https://your-server.com/support');
  
  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'subject': subject,
        'message': message,
        'apiKey': apiKey,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Support request submitted: ${data['requestId']}');
      // Show success message to user
    } else if (response.statusCode == 429) {
      print('Rate limit exceeded');
      // Show rate limit message to user
    } else {
      print('Error: ${response.body}');
      // Show error message to user
    }
  } catch (e) {
    print('Network error: $e');
    // Show network error to user
  }
}
```

## Log Format

Support requests are logged to `lib/logs/support_requests.log`:

```
================================================================================
[2026-01-18T10:30:00.000Z] Support Request SUP-1705582800000-abc123
IP: 192.168.1.100
Email: user@example.com
API Key: 1234
Subject: Bug Report
Message:
The search feature is not working properly when I search for...
================================================================================
```

## Email Format

You'll receive emails with:
- **From**: Your SMTP_USER email
- **To**: Your SUPPORT_EMAIL_TO email
- **Reply-To**: User's email (click reply to respond directly)
- **Subject**: [Support] Bug Report
- **Body**: Full support request details with timestamp, IP, request ID

## Testing

### Without Email Configuration
If environment variables are not set, the endpoint still works but only logs requests locally:
```json
{
  "success": true,
  "message": "Support request received and logged",
  "requestId": "SUP-1705582800000-abc123"
}
```

### Test Request (PowerShell)
```powershell
$body = @{
    email = "test@example.com"
    subject = "Test Support Request"
    message = "This is a test message"
    apiKey = "trial"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3000/support" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body
```

## Security Features
- ✅ Rate limiting per IP (5/day) prevents spam
- ✅ Input sanitization (length limits)
- ✅ Email validation (requires @)
- ✅ No API key required (accessible to all users)
- ✅ Async email sending (doesn't block response)
- ✅ Async file logging (doesn't block response)
- ✅ Request IDs for tracking

## Troubleshooting

### Email not sending
1. Check environment variables are set correctly
2. Check console logs for error messages
3. Verify SMTP credentials are correct
4. For Gmail, ensure App Password is used (not regular password)
5. Check firewall allows outbound SMTP connections

### Rate limit too strict
Increase `SUPPORT_REQUESTS_PER_DAY` constant in server-DND.js (line ~114)

### Log file not created
Ensure `lib/logs/` directory exists (will be created automatically on first write)

## Notes
- Email sending is **asynchronous** - responses are sent immediately even if email fails
- If email fails, the request is still logged locally
- User can send 5 support requests per day per IP address
- Each request gets a unique ID (SUP-timestamp-random)
- The server will restart with email configuration if environment variables are added later
