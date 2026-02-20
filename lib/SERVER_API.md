# Server.js API Documentation

This document describes all API endpoints provided by the Node.js proxy server (`server.js`). The server runs on port 3000 and acts as a secure gateway to OpenSearch, implementing authentication, rate limiting, and query validation.

## Table of Contents

- [Authentication](#authentication)
- [Rate Limiting](#rate-limiting)
- [Search Endpoints](#search-endpoints)
- [Index Management](#index-management)
- [Document Operations](#document-operations)
- [User Management (Admin Only)](#user-management-admin-only)
- [Utility Endpoints](#utility-endpoints)
- [Support](#support)
- [Error Responses](#error-responses)

---

## Authentication

All endpoints (except `/version`, `/reset-rate-limit`, and `/support`) require authentication via headers:

```http
x-api-key: <your-passkey>
x-email: <your-registered-email>  # Optional but recommended
```

### API Key Registry

API keys are loaded from `lib/api-keys.json` with the following structure:

```json
{
  "keys": [
    {
      "key": "7239",
      "email": "user@example.com",
      "allowPrefixes": ["eu_7239_"],
      "dailyQuota": 10000,
      "userType": "paid",
      "blocked": false
    }
  ]
}
```

### User Types

- **paid**: Full access with specified daily quota
- **trial**: Limited access with combined email/IP quota limits
- **free**: Grace period access (if applicable)

### Admin Access

Admin users are identified by:
- Email: `juraj.kuban.sk@gmail.com` (hardcoded)
- Admin key: `7239` or the first key in the registry

Admin users have access to:
- All indices (not limited by prefix)
- User management endpoints
- Deletion of any index

---

## Rate Limiting

Daily quota system tracks requests per IP address:

- **Paid users**: Daily quota as specified in API key registry
- **Trial users**: Combined email + IP tracking
- **Exceeded quota**: Returns 429 status code

Rate limit information is logged with each request.

---

## Search Endpoints

### POST /search

Secure search endpoint with server-side query construction.

**Request Body:**
```json
{
  "index": "eu_7239_celex_en_cs",
  "term": "regulation",
  "langs": ["en_text", "cs_text"],
  "pattern": 1,
  "size": 50,
  "existsLangs": ["en_text"]
}
```

**Parameters:**
- `index` (string, required): Index name or comma-separated list
- `term` (string, required): Search term
- `langs` (array, required): Language fields to search
- `pattern` (number, optional): Query pattern (1-6), default: 1
- `size` (number, optional): Number of results, default: 50
- `existsLangs` (array, optional): Fields that must exist in results

**Query Patterns:**

1. **Pattern 1**: Multi-field boolean OR with phrase/wildcard fallback
2. **Pattern 2**: Multi-field with minimum_should_match=1
3. **Pattern 3**: Cross-fields search (splits term, searches all fields)
4. **Pattern 4**: Fuzzy search (disabled by default due to performance)
5. **Pattern 5**: Wildcard search only (case-insensitive)
6. **Pattern 6**: Auto-lookup from Trados (currently same as Pattern 2)

**Response:**
```json
{
  "hits": {
    "total": { "value": 150 },
    "hits": [...]
  }
}
```

**Authentication:** Required  
**Rate Limited:** Yes

---

### POST /context

Retrieve surrounding segments for context display.

**Request Body:**
```json
{
  "index": "eu_7239_celex_en_cs",
  "celex": "32020R0001",
  "sequenceId": 42,
  "window": 3,
  "langs": ["en_text", "cs_text"]
}
```

**Parameters:**
- `index` (string, required): Index name (must be valid)
- `celex` (string, optional): CELEX document identifier
- `filename` (string, optional): Alternative to CELEX
- `sequenceId` (number, required): Center sequence ID
- `window` (number, required): Number of segments before/after
- `langs` (array, required): Language fields to return

**Note:** Must provide either `celex` or `filename`.

**Response:**
OpenSearch hits containing segments in range `[sequenceId - window, sequenceId + window]`

**Authentication:** Required  
**Rate Limited:** Yes

---

## Index Management

### GET /_cat/indices

List indices accessible to the authenticated user.

**Query Parameters:**
- `h` (string, optional): Comma-separated column names (default: "index")
  - Available: `index`, `store.size`, `docs.count`

**Examples:**
```http
GET /_cat/indices?h=index
GET /_cat/indices?h=index,store.size,docs.count
```

**Access Control:**
- **Admin**: Sees all indices except system indices (starting with `.` or `top_queries`)
- **Trial users**: See no indices
- **Regular users**: See only their own indices (`eu_{apiKey}_*`)

**Response Format:**

Single column:
```
eu_7239_celex_en_sk
eu_7239_iate_terminology
```

Multiple columns (space-separated):
```
eu_7239_celex_en_sk 1.2gb 15000
eu_7239_iate_terminology 500mb 8000
```

**Authentication:** Required  
**Rate Limited:** No

---

### DELETE /:index

Delete an index.

**Path Parameters:**
- `index` (string): Index name to delete

**Security:**
- Regular users: Can only delete indices starting with `eu_{apiKey}_`
- Admin users: Can delete any index

**Example:**
```http
DELETE /eu_7239_test_index
```

**Response:**
```json
{
  "acknowledged": true
}
```

**Authentication:** Required  
**Admin Required:** For non-owned indices  
**Rate Limited:** No

---

## Document Operations

### POST /upload

Secure bulk upload endpoint with server-side operation construction.

**Request Body:**
```json
{
  "index": "eu_7239_celex_en_sk",
  "documents": [
    {
      "celex": "32020R0001",
      "sequenceId": 1,
      "en_text": "regulation text",
      "sk_text": "text nariadenia"
    }
  ]
}
```

**Parameters:**
- `index` (string, required): Target index name
- `documents` (array, required): Array of documents to upload (max 50MB)

**Security Features:**
- Server constructs all bulk operations (always "index", never delete/update)
- Validates index access via `allowPrefixes` check
- Blocks dangerous fields: `script`, `runtime_mappings`
- Client only sends documents, not operations

**Response:**
```json
{
  "took": 250,
  "errors": false,
  "items": [...]
}
```

**Authentication:** Required  
**Rate Limited:** Yes

---

### GET /check-exists/:index/:celex

Check if a document with given CELEX exists in an index.

**Path Parameters:**
- `index` (string): Index name
- `celex` (string): CELEX identifier

**Example:**
```http
GET /check-exists/eu_7239_celex_en_sk/32020R0001
```

**Response:**
```json
{
  "exists": true,
  "celex": "32020R0001",
  "index": "eu_7239_celex_en_sk",
  "hits": 42
}
```

**Use Case:** Deduplication before upload

**Authentication:** Required  
**Rate Limited:** No

---

## User Management (Admin Only)

All user management endpoints require admin authentication via the `x-admin-key` header:

```http
x-admin-key: 7239
```

Admin endpoints bypass quota checks and are only accessible to users with admin privileges.

---

### GET /api/users/list

List all registered users with their quota and usage statistics.

**Headers:**
```http
x-admin-key: 7239
```

**Response:**
```json
{
  "users": [
    {
      "key": "7239",
      "email": "user@example.com",
      "userType": "paid",
      "dailyQuota": 10000,
      "quotaUsed": 523,
      "quotaRemaining": 9477,
      "allowPrefixes": ["eu_7239_"],
      "blocked": false
    }
  ]
}
```

**User Fields:**
- `key`: User's passkey
- `email`: Registered email address
- `userType`: paid | trial | free
- `dailyQuota`: Maximum daily requests
- `quotaUsed`: Requests used today
- `quotaRemaining`: Remaining requests today
- `allowPrefixes`: Index prefixes user can access
- `blocked`: Whether user is blocked

**Authentication:** Admin only  
**Rate Limited:** No (skips quota middleware)

---

### POST /api/users/add

Add a new user to the system.

**Headers:**
```http
x-admin-key: 7239
Content-Type: application/json
```

**Request Body:**
```json
{
  "email": "newuser@example.com",
  "passkey": "abc123",
  "dailyQuota": 1000,
  "userType": "paid"
}
```

**Parameters:**
- `email` (string, required): User's email address
- `passkey` (string, required): User's API passkey
- `dailyQuota` (number, optional): Daily request quota (default: 1000)
- `userType` (string, optional): paid | trial | free (default: "paid")

**Response:**
```json
{
  "success": true,
  "message": "User added successfully",
  "user": {
    "key": "abc123",
    "email": "newuser@example.com",
    "dailyQuota": 1000,
    "userType": "paid",
    "allowPrefixes": ["eu_abc123_"],
    "blocked": false
  }
}
```

**Error Response (409):**
```json
{
  "error": "User already exists"
}
```

**Authentication:** Admin only  
**Rate Limited:** No

---

### POST /api/users/set-quota

Update a user's daily quota.

**Headers:**
```http
x-admin-key: 7239
Content-Type: application/json
```

**Request Body:**
```json
{
  "passkey": "abc123",
  "dailyQuota": 5000
}
```

**Parameters:**
- `passkey` (string, required): User's passkey to update
- `dailyQuota` (number, required): New daily quota value

**Response:**
```json
{
  "success": true,
  "message": "Quota updated successfully",
  "user": {
    "key": "abc123",
    "email": "user@example.com",
    "dailyQuota": 5000,
    "userType": "paid"
  }
}
```

**Error Response (404):**
```json
{
  "error": "User not found"
}
```

**Authentication:** Admin only  
**Rate Limited:** No

---

### POST /api/users/block

Block or unblock a user from accessing the system.

**Headers:**
```http
x-admin-key: 7239
Content-Type: application/json
```

**Request Body:**
```json
{
  "passkey": "abc123",
  "blocked": true
}
```

**Parameters:**
- `passkey` (string, required): User's passkey to block/unblock
- `blocked` (boolean, required): true to block, false to unblock

**Response:**
```json
{
  "success": true,
  "message": "User blocked successfully",
  "user": {
    "key": "abc123",
    "email": "user@example.com",
    "blocked": true
  }
}
```

**Effect:** Blocked users receive 403 Forbidden on all requests

**Authentication:** Admin only  
**Rate Limited:** No

---

### DELETE /api/users/delete

Delete a user from the system (requires confirmation).

**Headers:**
```http
x-admin-key: 7239
Content-Type: application/json
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "passkey": "abc123"
}
```

**Parameters:**
- `email` (string, required): User's email (must match exactly)
- `passkey` (string, required): User's passkey (must match exactly)

**Response:**
```json
{
  "success": true,
  "message": "User deleted successfully",
  "deletedUser": {
    "key": "abc123",
    "email": "user@example.com"
  }
}
```

**Error Response (404):**
```json
{
  "error": "User not found or credentials do not match"
}
```

**Note:** Both email and passkey must match for deletion to proceed (two-step confirmation).

**Authentication:** Admin only  
**Rate Limited:** No

---

### GET /api/users/statistics

Get aggregated statistics for all users.

**Headers:**
```http
x-admin-key: 7239
```

**Response:**
```json
{
  "statistics": {
    "totalUsers": 15,
    "activeToday": 8,
    "totalSearchesToday": 1523,
    "totalQuotaAllocated": 150000,
    "totalQuotaUsed": 45230
  }
}
```

**Statistics Fields:**
- `totalUsers`: Total number of registered users
- `activeToday`: Users who made requests today
- `totalSearchesToday`: Total search requests today across all users
- `totalQuotaAllocated`: Sum of all users' daily quotas
- `totalQuotaUsed`: Sum of all users' usage today

**Authentication:** Admin only  
**Rate Limited:** No

---

## Utility Endpoints

### GET /version

Get current application version information.

**Response:**
```json
{
  "version": "0.9.9",
  "minVersion": "0.9.9",
  "updateUrl": "https://apps.microsoft.com/detail/9nknvgxjfsw5"
}
```

**Authentication:** None required  
**Rate Limited:** No

---

### GET /fetch/update-info

Proxy endpoint to fetch update information from external source.

**Response:**
JSON from `https://www.pts-translation.sk/updateInfoUrl.json`

**Authentication:** Required  
**Rate Limited:** Yes

---

### GET /dump-api-keys

Developer endpoint to dump API key registry and usage counters to JSON file.

**Response:**
```json
{
  "timestamp": "2026-02-17T10:30:45.123Z",
  "apiKeys": [...],
  "usageCounters": [...],
  "totalIPs": 42
}
```

**Output File:** Written to disk in the lib directory

**Authentication:** Required  
**Rate Limited:** No

---

### POST /reset-rate-limit

Development endpoint to reset rate limit counters.

**Warning:** Should be removed or secured in production.

**Authentication:** None required  
**Rate Limited:** No

---

## Support

### POST /support

Submit support/error reports from the application.

**Request Body:**
```json
{
  "email": "user@example.com",
  "subject": "Error Report",
  "message": "Description of the issue...",
  "apiKey": "optional-passkey"
}
```

**Parameters:**
- `email` (string, required): User's contact email
- `subject` (string, required): Support request subject
- `message` (string, required): Detailed message/error description
- `apiKey` (string, optional): User's passkey for tracking

**Response:**
```json
{
  "success": true,
  "message": "Support request received and logged",
  "requestId": "SUP-1234567890-abc123"
}
```

**Features:**
- Rate limited: 10 requests per email per day
- Logs all requests to disk
- Optionally forwards via email if SMTP configured

**Environment Variables (optional email forwarding):**
```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=true
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SUPPORT_EMAIL_FROM=support@your-domain.com
SUPPORT_EMAIL_TO=your-email@gmail.com
```

**Authentication:** None required (public endpoint)  
**Rate Limited:** Yes (10/day per email)

---

## Error Responses

### Common HTTP Status Codes

- **200 OK**: Request successful
- **400 Bad Request**: Invalid parameters or malformed request
- **401 Unauthorized**: Missing or invalid API key
- **403 Forbidden**: Access denied (blocked user or unauthorized action)
- **404 Not Found**: Resource not found
- **409 Conflict**: Resource already exists (e.g., duplicate user)
- **429 Too Many Requests**: Daily quota exceeded
- **500 Internal Server Error**: Server-side error
- **502 Bad Gateway**: OpenSearch connection failed

### Error Response Format

```json
{
  "error": "Description of the error"
}
```

### Detailed Error Response (with context)

```json
{
  "error": "Validation failed",
  "details": "Index name contains invalid characters",
  "field": "index"
}
```

---

## Security Features

### Index Name Validation

All index names must match: `^[a-z0-9._-]+$`

- **Allowed**: lowercase letters, numbers, dots, underscores, hyphens
- **Forbidden**: uppercase, spaces, special characters

### Index Access Control

Users can only access indices matching their `allowPrefixes` from the registry:

```json
{
  "key": "7239",
  "allowPrefixes": ["eu_7239_"]
}
```

Admin users bypass this restriction.

### Query Validation

- Server constructs all queries (client sends only parameters)
- Dangerous fields blocked: `script`, `runtime_mappings`
- Query patterns are predefined and immutable by clients
- Size limits enforced

### Upload Security

- Only "index" operations allowed (no delete/update)
- Server validates all documents before bulk upload
- 50MB payload size limit
- Index access checked via `allowPrefixes`

### User Management Security

- Admin-only endpoints protected by `requireAdmin` middleware
- Admin key validation (`x-admin-key` header)
- User deletion requires both email and passkey confirmation
- Blocked users receive 403 on all requests (checked in quota middleware)
- Admin endpoints bypass quota checks to prevent lockout

---

## Monitoring and Logging

### Request Logging

All requests are logged with:
- Timestamp
- Request ID
- Method and path
- IP address
- API key and email
- Quota information
- User-Agent
- Device ID (if present)

### Access Log

Quota events are written to an access log file with:
- Timestamp
- Email
- IP address
- Request count
- Quota limit

### Console Output

Detailed logging to console with:
- Request/response lifecycle
- OpenSearch interactions
- Query details
- Result counts
- Error stack traces

---

## Configuration

### Server Settings

```javascript
// Port
const PORT = 3000;

// OpenSearch connection
const OS_HOST = '127.0.0.1';
const OS_PORT = 9200;
const OS_AUTH = 'Basic ' + Buffer.from('admin:admin').toString('base64');

// Rate limiting
const SUPPORT_REQUESTS_PER_DAY = 10;

// Payload limits
const UPLOAD_LIMIT = '50mb';
const SEARCH_LIMIT = '20mb';
const BULK_LIMIT = '100mb';
```

### CORS Configuration

Allowed origins:
- `https://search.pts-translation.sk`
- `https://www.pts-translation.sk`
- `http://localhost:8080` (development)

Allowed methods: `GET`, `POST`, `OPTIONS`  
Allowed headers: `Content-Type`, `x-api-key`, `x-client-context`, `x-email`, `x-admin-key`

---

## Architecture

```
Client Application
       ↓
  [Authentication]
       ↓
  [Rate Limiting]
       ↓
  [Route Handler]
       ↓
  [Query Construction]
       ↓
  [OpenSearch Proxy]
       ↓
   OpenSearch (localhost:9200)
```

### Middleware Chain

1. **Trust Proxy**: Enable proper IP detection
2. **CORS**: Handle cross-origin requests
3. **Morgan**: HTTP request logging
4. **Security Headers**: X-Content-Type-Options, Cache-Control
5. **API Key Extraction**: Extract from x-api-key header
6. **Request Logging**: Detailed request information
7. **API Key Validation**: Verify against registry
8. **Email Verification**: Optional email matching
9. **Rate Limiting**: Check daily quota
10. **Route Handlers**: Process specific endpoints

---

## Version History

- **0.9.9**: Current version with user management endpoints
- **0.9.8**: Added support endpoint with email forwarding
- **0.9.7**: Secure upload endpoint with server-side operations
- **0.9.6**: Context retrieval endpoint
- **0.9.5**: Pattern-based search queries
- **0.9.4**: Rate limiting and quota system
- **0.9.3**: API key registry from external file
- **0.9.2**: Index access control
- **0.9.1**: Initial secure search endpoint

---

## Development

### Testing Endpoints

Use curl or Postman to test endpoints:

```bash
# Search request
curl -X POST http://localhost:3000/search \
  -H "x-api-key: 7239" \
  -H "Content-Type: application/json" \
  -d '{
    "index": "eu_7239_test",
    "term": "regulation",
    "langs": ["en_text"],
    "pattern": 1
  }'

# List indices
curl -X GET "http://localhost:3000/_cat/indices?h=index" \
  -H "x-api-key: 7239"

# Add user (admin)
curl -X POST http://localhost:3000/api/users/add \
  -H "x-admin-key: 7239" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newuser@example.com",
    "passkey": "test123",
    "dailyQuota": 1000,
    "userType": "paid"
  }'

# Get user statistics (admin)
curl -X GET http://localhost:3000/api/users/statistics \
  -H "x-admin-key: 7239"
```

### Running the Server

```bash
cd lib
node server.js
```

### Environment Variables

Optional for email support:

```bash
export SMTP_HOST=smtp.gmail.com
export SMTP_PORT=587
export SMTP_SECURE=true
export SMTP_USER=your-email@gmail.com
export SMTP_PASS=your-app-password
export SUPPORT_EMAIL_FROM=support@domain.com
export SUPPORT_EMAIL_TO=admin@domain.com
```

---

## Troubleshooting

### Common Issues

**Issue: 401 Unauthorized**
- Verify API key is in `api-keys.json`
- Check `x-api-key` header is correct

**Issue: 403 Forbidden**
- User may be blocked (check `blocked` field)
- Non-admin trying to access admin endpoint
- Email mismatch with registered key

**Issue: 429 Too Many Requests**
- Daily quota exceeded
- Wait until next day or contact admin for quota increase
- Use `/dump-api-keys` to check current usage

**Issue: 400 Bad Request (Invalid index)**
- Index name contains invalid characters
- Use only: a-z, 0-9, dots, underscores, hyphens

**Issue: 502 Bad Gateway**
- OpenSearch connection failed
- Check OpenSearch is running on localhost:9200
- Verify authentication credentials

**Issue: Admin endpoint returns 403**
- Verify `x-admin-key` header is set to `7239`
- Check if user is registered as admin in api-keys.json

---

## Best Practices

### For Regular Users

1. Always include `x-email` header for better tracking
2. Monitor your quota usage
3. Use specific index names instead of wildcards when possible
4. Implement exponential backoff for rate limit errors
5. Cache search results to reduce requests

### For Admin Users

1. Regularly review user statistics
2. Monitor blocked users
3. Set appropriate quotas based on user needs
4. Back up `api-keys.json` before making changes
5. Use two-step confirmation for user deletions
6. Review access logs for suspicious activity

### For Developers

1. Test with trial keys before deploying
2. Implement proper error handling for all status codes
3. Use request IDs for debugging
4. Log failed requests for analysis
5. Respect rate limits in automated scripts
6. Never commit `api-keys.json` to version control

---

## Contact

For additional support or questions about the API:
- Submit via `/support` endpoint
- Email: support@pts-translation.sk
- Check application logs in `lib/logs/`
