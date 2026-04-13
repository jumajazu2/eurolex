# Listmonk Installation Guide

Install Listmonk on your Hetzner VPS for marketing email campaigns.

---

## Option A: Docker Compose (Recommended)

### 1. Install Docker (if not already installed)

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sudo sh

# Add your user to the docker group (avoids needing sudo)
sudo usermod -aG docker $USER

# Install Docker Compose plugin
sudo apt install docker-compose-plugin -y

# Verify
docker --version
docker compose version
```

### 2. Create Listmonk directory

```bash
mkdir -p /opt/listmonk && cd /opt/listmonk
```

### 3. Download the Docker Compose file

```bash
curl -Lo docker-compose.yml https://raw.githubusercontent.com/knadh/listmonk/master/docker-compose.yml
```

### 4. Review and edit the compose file

```bash
nano docker-compose.yml
```

Key settings to change:

```yaml
services:
  app:
    image: listmonk/listmonk:latest
    ports:
      - "127.0.0.1:9000:9000"   # Only listen on localhost (nginx will proxy)
    environment:
      - TZ=Europe/Bratislava     # Your timezone

  db:
    image: postgres:14
    environment:
      - POSTGRES_PASSWORD=CHANGE_THIS_TO_A_STRONG_PASSWORD
      - POSTGRES_USER=listmonk
      - POSTGRES_DB=listmonk
    volumes:
      - listmonk-data:/var/lib/postgresql/data
```

> **Important:** Change the default Postgres password to something strong.

### 5. Initialize the database

```bash
docker compose run --rm app ./listmonk --install
```

This creates the database tables and a default admin user.

### 6. Start Listmonk

```bash
docker compose up -d
```

Listmonk is now running on `http://127.0.0.1:9000`.

### 7. Verify it's running

```bash
docker compose ps
curl http://127.0.0.1:9000/api/health
```

---

## Option B: Binary Install (No Docker)

### 1. Download the binary

```bash
cd /opt
curl -Lo listmonk.tar.gz "https://github.com/knadh/listmonk/releases/latest/download/listmonk_linux_amd64.tar.gz"
tar -xzf listmonk.tar.gz
mv listmonk_linux_amd64 listmonk
cd listmonk
```

### 2. Install PostgreSQL

```bash
sudo apt install postgresql postgresql-contrib -y
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

### 3. Create database and user

```bash
sudo -u postgres psql
```

```sql
CREATE USER listmonk WITH PASSWORD 'CHANGE_THIS_TO_A_STRONG_PASSWORD';
CREATE DATABASE listmonk OWNER listmonk;
\q
```

### 4. Create config file

```bash
./listmonk --new-config
nano config.toml
```

Edit `config.toml`:

```toml
[app]
address = "127.0.0.1:9000"
admin_username = "admin"
admin_password = "CHANGE_THIS_ADMIN_PASSWORD"

[db]
host = "localhost"
port = 5432
user = "listmonk"
password = "CHANGE_THIS_TO_A_STRONG_PASSWORD"
database = "listmonk"
ssl_mode = "disable"
```

### 5. Initialize and run

```bash
./listmonk --install    # Creates tables
./listmonk              # Starts the server
```

### 6. Create a systemd service (auto-start on boot)

```bash
sudo nano /etc/systemd/system/listmonk.service
```

```ini
[Unit]
Description=Listmonk Newsletter Manager
After=postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/listmonk
ExecStart=/opt/listmonk/listmonk
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo chown -R www-data:www-data /opt/listmonk
sudo systemctl daemon-reload
sudo systemctl enable listmonk
sudo systemctl start listmonk
```

---

## Expose via nginx (Both Options)

Add a new nginx server block to access Listmonk from a subdomain (e.g., `mail.yourcompany.com`):

### 1. Create nginx config

```bash
sudo nano /etc/nginx/sites-available/listmonk
```

```nginx
server {
    listen 80;
    server_name mail.yourcompany.com;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 2. Enable the site

```bash
sudo ln -s /etc/nginx/sites-available/listmonk /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 3. Add SSL with Let's Encrypt

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d mail.yourcompany.com
```

---

## Configure SMTP (Your Company Email)

After logging in to the Listmonk admin panel:

1. Go to **Settings → SMTP**
2. Fill in your webhosting SMTP details:

| Setting | Value |
|---------|-------|
| Host | `mail.yourcompany.com` (your SMTP server) |
| Port | `465` (SSL) or `587` (STARTTLS) |
| Auth protocol | `login` |
| Username | `info@yourcompany.com` |
| Password | your email password |
| TLS | `SSL` or `STARTTLS` (match the port) |
| Max connections | `2` (keep low for shared hosting) |
| Max message retries | `3` |
| Idle timeout | `15s` |

3. Set **sending rate** to ~10 emails/minute (safe for shared hosting SMTP)
4. Click **Save** and **Send test email** to verify

---

## First Campaign Checklist

### 1. Create a subscriber list
- Admin → Lists → New List
- Name: e.g., "LegisTracerEU Prospects"
- Type: Private
- Opt-in: Single (for manually added contacts) or Double (for self-signups)

### 2. Import subscribers
- Admin → Subscribers → Import
- CSV format:
  ```csv
  email,name,attributes
  john@example.com,John Smith,"{""company"":""Acme Corp""}"
  jane@example.com,Jane Doe,"{""company"":""Law Firm XY""}"
  ```
- Or add manually one by one

### 3. Create/edit the default email template
- Admin → Templates
- Edit the default template to include your branding, footer with:
  - Company address
  - `{{ .UnsubscribeURL }}` link
  - `{{ .ManageURL }}` link  
  - Privacy policy link

### 4. Create a campaign
- Admin → Campaigns → New Campaign
- Subject, body (HTML/Markdown/Rich text)
- Select target list(s)
- Preview → Send test email to yourself first
- Then send to list or schedule

---

## Useful Commands

```bash
# Docker: View logs
docker compose logs -f app

# Docker: Stop
docker compose down

# Docker: Restart
docker compose restart

# Docker: Update to latest version
docker compose pull
docker compose up -d

# Binary: View logs
sudo journalctl -u listmonk -f

# Binary: Restart
sudo systemctl restart listmonk
```

---

## DNS Records to Set Up

For best deliverability, make sure these DNS records exist for your sending domain:

| Record | Type | Name | Value |
|--------|------|------|-------|
| SPF | TXT | `@` | Check with your hosting provider (usually already set) |
| DKIM | TXT | varies | Check with your hosting provider |
| DMARC | TXT | `_dmarc` | `v=DMARC1; p=none; rua=mailto:dmarc@yourcompany.com` |
| Subdomain | A | `mail` | Your VPS IP (for the Listmonk admin panel) |

> Your webhosting provider likely already has SPF and DKIM configured for your domain. Verify with them.

---

## Notes

- Default admin login: `admin` / `admin` (change immediately after first login in Settings)
- Listmonk uses ~30MB RAM — very lightweight
- PostgreSQL data is persisted in a Docker volume (or `/var/lib/postgresql` for binary install)
- The admin panel is at `https://mail.yourcompany.com` after nginx + SSL setup
- Listmonk has a REST API if you ever want to add subscribers programmatically from your app
