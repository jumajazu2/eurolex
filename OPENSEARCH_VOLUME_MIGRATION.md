# OpenSearch Volume Migration Guide

Migrate OpenSearch data from the main Hetzner VPS disk to a new Hetzner Volume to resolve disk space issues (flood-stage watermark causing HTTP 429 / read-only-allow-delete blocks).

## Prerequisites

- Hetzner VPS with OpenSearch running
- Main disk: ~75GB (currently at ~87% usage)
- OpenSearch data at: `/var/lib/opensearch/`
- OpenSearch config at: `/etc/opensearch/opensearch.yml`
- OpenSearch uses HTTPS on port 9200 with basic auth (`admin:admin`)
- curl requires: `https://` + actual server IP (not `localhost`) + `-k` flag

---

## Step 1: Check Current Indices Size

Before provisioning, check how much space indices actually use:

```bash
curl -k -u admin:admin "https://<SERVER_IP>:9200/_cat/indices?v&h=index,store.size&s=store.size:desc"
```

For total size:

```bash
curl -k -u admin:admin "https://<SERVER_IP>:9200/_cat/allocation?v"
```

---

## Step 2: Provision Hetzner Volume

1. Go to Hetzner Cloud Console → Volumes
2. Create a new volume (e.g., 100GB — ~€4.40/mo)
3. Attach it to the VPS
4. Note the device name (e.g., `/dev/sdb` or `/dev/disk/by-id/scsi-0HC_Volume_XXXXXXXX`)

---

## Step 3: Format and Mount the Volume

```bash
# Format as ext4 (skip if Hetzner already formatted it)
sudo mkfs.ext4 /dev/sdb

# Create mount point
sudo mkdir -p /mnt/data

# Mount
sudo mount /dev/sdb /mnt/data

# Verify
df -h /mnt/data
```

### Add to fstab for persistence across reboots

Find the UUID:

```bash
sudo blkid /dev/sdb
```

Add to `/etc/fstab`:

```
UUID=<your-uuid>  /mnt/data  ext4  defaults,nofail  0  2
```

> **Important:** Use `nofail` so the server still boots if the volume is detached.

Test fstab without rebooting:

```bash
sudo umount /mnt/data
sudo mount -a
df -h /mnt/data
```

---

## Step 4: Stop OpenSearch

```bash
sudo systemctl stop opensearch
```

Verify it's stopped:

```bash
sudo systemctl status opensearch
```

---

## Step 5: Copy Data to the New Volume

Use `rsync` (not `mv`) so the original data remains intact as a fallback:

```bash
sudo rsync -avP /var/lib/opensearch/ /mnt/data/opensearch/
```

Fix ownership:

```bash
sudo chown -R opensearch:opensearch /mnt/data/opensearch/
```

Verify the copy:

```bash
# Compare sizes
du -sh /var/lib/opensearch/
du -sh /mnt/data/opensearch/

# Compare file counts
find /var/lib/opensearch/ -type f | wc -l
find /mnt/data/opensearch/ -type f | wc -l
```

---

## Step 6: Update OpenSearch Configuration

Edit `/etc/opensearch/opensearch.yml`:

```bash
sudo nano /etc/opensearch/opensearch.yml
```

Change `path.data`:

```yaml
# Before:
path.data: /var/lib/opensearch

# After:
path.data: /mnt/data/opensearch
```

---

## Step 7: Start OpenSearch and Verify

```bash
sudo systemctl start opensearch
```

Wait ~30 seconds for startup, then verify:

```bash
# Check service status
sudo systemctl status opensearch

# Check cluster health
curl -k -u admin:admin "https://<SERVER_IP>:9200/_cluster/health?pretty"

# Check all indices are present
curl -k -u admin:admin "https://<SERVER_IP>:9200/_cat/indices?v"
```

---

## Step 8: Clear Read-Only Block (if still set)

The flood-stage watermark may have left indices in read-only mode. Clear it:

```bash
curl -k -u admin:admin -XPUT "https://<SERVER_IP>:9200/_all/_settings" \
  -H 'Content-Type: application/json' \
  -d '{"index.blocks.read_only_allow_delete": null}'
```

Verify the block is cleared:

```bash
curl -k -u admin:admin "https://<SERVER_IP>:9200/_all/_settings?pretty" | grep read_only
```

---

## Step 9: Optionally Raise Watermarks

To prevent future issues, raise the disk watermarks (the new volume should have plenty of space, but just in case):

```bash
curl -k -u admin:admin -XPUT "https://<SERVER_IP>:9200/_cluster/settings" \
  -H 'Content-Type: application/json' \
  -d '{
    "persistent": {
      "cluster.routing.allocation.disk.watermark.low": "90%",
      "cluster.routing.allocation.disk.watermark.high": "95%",
      "cluster.routing.allocation.disk.watermark.flood_stage": "97%"
    }
  }'
```

---

## Step 10: Clean Up Old Data

**Only after verifying everything works:**

```bash
sudo rm -rf /var/lib/opensearch/*
```

> Wait at least a day or two before deleting. Run some test uploads and searches first to confirm the migration is solid.

---

## Step 11: Re-upload Failed Documents

After the migration is complete and verified, re-upload the 1,051 documents that failed with HTTP 429 during the `sector3_2006` harvest session (`sector3_2006_2026-03-30T14-14-32-598171.json`). These failed starting from CELEX `32006L0088` onwards.

---

## Notes

- **Volume is resizable online:** You can increase the volume size in Hetzner Cloud Console, then run `sudo resize2fs /dev/sdb` — no downtime needed.
- **server.js uses `http.request`** to connect to OpenSearch at `127.0.0.1:9200`, but OpenSearch has SSL enabled. This hasn't caused issues so far but is a potential configuration mismatch worth investigating.
- **No retry logic:** The upload pipeline in `processDOM.dart` (`_sendChunkToOpenSearch()`) has no retry/backoff for 429 errors. Consider adding this in the future to handle transient failures gracefully.
