# OpenSearch Index Readonly Management

## Overview

OpenSearch indices can be set to readonly mode, blocking all write operations (uploads, updates, deletes). This document explains how to check and manage readonly status.

## Types of Readonly Blocks

OpenSearch has **two different** readonly settings:

1. **`index.blocks.read_only`** - Explicit readonly block (commonly used)
2. **`index.blocks.read_only_allow_delete`** - Readonly but allows deletes (used for disk space issues)

Both will block uploads, but the error messages differ.

## Error Messages

### 403 Error from Readonly Index

```json
{
  "took": 0,
  "errors": true,
  "items": [{
    "index": {
      "_index": "eurolex_sparql_sector6",
      "_id": "1Xm8NZwBjyP6szk60Kbm",
      "status": 403,
      "error": {
        "type": "cluster_block_exception",
        "reason": "index [eurolex_sparql_sector6] blocked by: [FORBIDDEN/5/index read-only (api)]"
      }
    }
  }]
}
```

The key indicator: `"index read-only (api)"` means `index.blocks.read_only` is set to `true`.

## Check Readonly Status

### Check Specific Index - Both Blocks

```bash
curl http://localhost:9200/eurolex_sparql_sector6/_settings/index.blocks?pretty
```

Response:
```json
{
  "eurolex_sparql_sector6" : {
    "settings" : {
      "index" : {
        "blocks" : {
          "read_only" : "true",               ← Blocks all writes
          "read_only_allow_delete" : "false"  ← Not blocking (false)
        }
      }
    }
  }
}
```

### Check All Indices - read_only Block Only

```bash
curl http://localhost:9200/_all/_settings/index.blocks.read_only?pretty
```

### Check All Indices - All Blocks

```bash
curl http://localhost:9200/_all/_settings/index.blocks?pretty
```

### Quick Check with grep

```bash
curl http://localhost:9200/_all/_settings | grep -A5 "blocks"
```

## Understanding the Values

| Value | Status | Uploads Allowed? |
|-------|--------|------------------|
| `"read_only": "true"` | Readonly | ❌ No |
| `"read_only": "false"` | Writable | ✅ Yes |
| `"read_only": null` | Writable | ✅ Yes |
| No `blocks` section | Writable (default) | ✅ Yes |

## Enable Writes (Remove Readonly)

### Single Index

CUSTOM: curl -H "x-api-key: ****" -H "x-email: juraj.kuban.sk@gmail.com"  -X PUT "http://localhost:9200/eurolex_sparql_sector6/_settings"   -H "Content-Type: application/json"   -d '{"index": {"blocks": {"read_only": null}}}'


```bash
curl -X PUT "http://localhost:9200/eurolex_sparql_sector6/_settings" \
  -H "Content-Type: application/json" \
  -d '{"index": {"blocks": {"read_only": null}}}'
```

### All Indices

```bash
curl -X PUT "http://localhost:9200/_all/_settings" \
  -H "Content-Type: application/json" \
  -d '{"index": {"blocks": {"read_only": null}}}'
```

### Verify Changes

```bash
curl http://localhost:9200/_all/_settings/index.blocks.read_only?pretty
```

Successful response shows empty `{}` or `"read_only": null` for writable indices.

## Disable Writes (Make Readonly)

### Single Index

```bash
curl -X PUT "http://localhost:9200/eurolex_sparql_sector6/_settings" \
  -H "Content-Type: application/json" \
  -d '{"index": {"blocks": {"read_only": "true"}}}'
```

### All Indices

```bash
curl -X PUT "http://localhost:9200/_all/_settings" \
  -H "Content-Type: application/json" \
  -d '{"index": {"blocks": {"read_only": "true"}}}'
```

## Important Notes

⚠️ **Automatic Readonly Protection**

OpenSearch may automatically set indices to readonly when:
- Disk space is critically low (< 5% free by default)
- Disk watermark threshold is exceeded
- Cluster health issues occur

If this happens, the readonly block will **automatically revert** after you fix it, or you'll need to:
1. Free up disk space
2. Remove the readonly block manually
3. Adjust watermark settings in `opensearch.yml`

⚠️ **Server.js Limitation**

The LegisTracerEU app's `server.js` proxy does **NOT** currently support `/_settings` endpoints. 

To enable readonly detection in the app, you would need to add these routes to `server.js`:
- `GET /_all/_settings`
- `GET /:index/_settings`  
- `PUT /:index/_settings`

Currently, readonly status must be checked/changed **directly on the OpenSearch server** using the commands above.

## Disk Space Check

Check if low disk space is causing readonly issues:

```bash
# Check disk usage
df -h

# Check OpenSearch cluster settings
curl http://localhost:9200/_cluster/settings?pretty

# Check disk watermark settings
curl http://localhost:9200/_cluster/settings?include_defaults=true | grep watermark
```

## Troubleshooting

### Issue: Index keeps reverting to readonly

**Cause:** Low disk space triggering automatic protection

**Solution:**
1. Free up disk space
2. Adjust watermark thresholds:

```bash
curl -X PUT "http://localhost:9200/_cluster/settings" \
  -H "Content-Type: application/json" \
  -d '{
    "persistent": {
      "cluster.routing.allocation.disk.watermark.low": "90%",
      "cluster.routing.allocation.disk.watermark.high": "95%",
      "cluster.routing.allocation.disk.watermark.flood_stage": "97%"
    }
  }'
```

### Issue: Cannot PUT /_settings from app

**Cause:** `server.js` doesn't proxy these endpoints

**Solution:** Either:
1. SSH to server and use curl commands directly
2. Update `server.js` to proxy `/_settings` endpoints

## Quick Reference Commands

```bash
# Check all readonly indices
curl http://localhost:9200/_all/_settings/index.blocks.read_only?pretty

# Make all indices writable
curl -X PUT "http://localhost:9200/_all/_settings" \
  -H "Content-Type: application/json" \
  -d '{"index": {"blocks": {"read_only": null}}}'

# Make all indices readonly
curl -X PUT "http://localhost:9200/_all/_settings" \
  -H "Content-Type: application/json" \
  -d '{"index": {"blocks": {"read_only": "true"}}}'

# Check disk space
df -h
```
