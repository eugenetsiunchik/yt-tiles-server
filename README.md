## Belarus self-hosted vector tile server (TileServer GL + Nginx)

### 1) Before you clone: Git + SSH setup

You’ll need Git and an SSH key so `git clone` can authenticate without passwords.

#### 1.1 Install Git

- **macOS** (usually already installed):

```bash
git --version
```

- **Ubuntu**:

```bash
sudo apt-get update
sudo apt-get install -y git
git --version
```

#### 1.2 Configure Git identity (recommended)

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

#### 1.3 Create and register an SSH key

```bash
ssh-keygen -t ed25519 -C "you@example.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
pbcopy < ~/.ssh/id_ed25519.pub || cat ~/.ssh/id_ed25519.pub
```

- Add the copied public key to your Git hosting provider (GitHub/GitLab/etc).
- Verify:

```bash
ssh -T git@github.com  # replace github.com with your Git host
```

### 2) Clone the project

```bash
git clone <YOUR_REPO_URL> yt-tiles-server
cd yt-tiles-server
```

### 3) How to run locally

Prereq: Docker Desktop running.

```bash
cd yt-tiles-server

mkdir -p data/mbtiles
chmod +x scripts/*.sh
./scripts/fetch-assets.sh

# Get initial MBTiles (choose ONE option):
#
# Option A: download from an HTTP(S) URL (recommended for local dev)
# ./scripts/fetch-mbtiles.sh belarus "https://example.com/belarus.mbtiles"
# ./scripts/fetch-mbtiles.sh grodno  "https://example.com/grodno.mbtiles"
#
# Option B: fetch from S3 (requires AWS CLI configured; see section 8)
# ./scripts/fetch-mbtiles-s3.sh belarus "s3://<bucket>/tilesets/belarus/2026-02-28/belarus.mbtiles"
# ./scripts/fetch-mbtiles-s3.sh grodno  --manifest "s3://<bucket>/manifests/latest.json"
#
# Option C: copy files manually into data/mbtiles/
#   data/mbtiles/belarus.mbtiles
#   data/mbtiles/<city>.mbtiles  (optional overlays)

docker compose up -d
docker compose ps
```

Open:

- Demo: `http://localhost/`
- Style: `http://localhost/styles/style.json`
- Base tiles: `http://localhost/data/belarus/0/0/0.pbf`
- Any city overlay (if present): `http://localhost/data/<city>/10/???/???.pbf`

### 4) VPS install commands (Ubuntu 22.04)

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg unzip rsync git

# Docker repo key + repo
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker "$USER"
newgrp docker

# Firewall (public HTTP for now)
sudo ufw allow 80/tcp
sudo ufw --force enable
```

Optional (recommended on 2GB RAM VPS): add swap to avoid OOM-kills during spikes.

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
```

### 5) First run (VPS)

Copy this repo to the VPS (or `git clone`), then:

```bash
cd yt-tiles-server

mkdir -p data/mbtiles
chmod +x scripts/*.sh
./scripts/fetch-assets.sh

# Get initial MBTiles (choose ONE option):
#
# Option A: scp files into data/mbtiles/
#   data/mbtiles/belarus.mbtiles
#   data/mbtiles/<city>.mbtiles (optional)
#
# Option B: fetch from S3 (requires AWS CLI configured; see section 8)
# ./scripts/fetch-mbtiles-s3.sh belarus --manifest "s3://<bucket>/manifests/latest.json"
# ./scripts/fetch-mbtiles-s3.sh grodno  --manifest "s3://<bucket>/manifests/latest.json"
#
# Option C: download from HTTP(S)
# ./scripts/fetch-mbtiles.sh belarus "https://example.com/belarus.mbtiles"

docker compose up -d
docker compose ps
```

Check:

- Demo: `http://<VPS_IP>/`
- Style: `http://<VPS_IP>/styles/style.json`
- TileJSON: `http://<VPS_IP>/data/belarus.json`
- Health: `http://<VPS_IP>/health`

### 6) How to update MBTiles safely (easy swap)

Upload your new file to the VPS (any path), then:

```bash
./scripts/update-mbtiles.sh belarus /path/to/new/belarus.mbtiles
./scripts/update-area.sh grodno /path/to/new/grodno.mbtiles
```

Fetch only one city by URL (no need to touch other areas):

```bash
./scripts/fetch-mbtiles.sh minsk https://example.com/minsk.mbtiles
./scripts/fetch-mbtiles.sh brest https://example.com/brest.mbtiles
```

Note: updates purge the Nginx cache so new tiles take effect immediately.

Rollback (if needed):

```bash
mv -f data/mbtiles/belarus.mbtiles.bak data/mbtiles/belarus.mbtiles
docker compose kill -s HUP tileserver
```

### 7) Usage optimization (RAM + disk)

#### 7.1 RAM optimization (2GB VPS baseline)

- Use `maptiler/tileserver-gl-light` (already configured): avoids raster renderer pools.
- Keep Node heap capped (already configured): `NODE_OPTIONS=--max-old-space-size=768`
- Keep Nginx cache bounded (already configured): `proxy_cache_path ... max_size=8g`
- Do not expose TileServer directly; proxy through Nginx so clients don’t hammer `/data/*` uncached.
- If you still hit OOM:
  - Lower Node heap: `--max-old-space-size=512`
  - Reduce Nginx cache size to `2g–4g`
  - Disable `serveAllFonts` if you have a huge fonts directory and you want to serve only what styles need

#### 7.2 Disk usage estimate (z0–z14)

- `belarus.mbtiles`: typically **~2–20 GB** depending on layers/detail/feature density.
- each city MBTiles (e.g. `minsk.mbtiles`): typically **~0.05–1.5 GB** depending on the square size and zoom coverage.
- Docker images: **~0.2–0.6 GB** total (TileServer GL light + Nginx alpine).
- Nginx cache: configured up to **8 GB** max.
- Fonts + sprites: typically **~50–250 MB**.

Rule of thumb for a 40 GB disk:
- MBTiles (say 10 GB) + cache (4–8 GB) + images (0.5 GB) + OS/logs/headroom ⇒ comfortable.

### 8) AWS/S3 setup (for automated updates)

#### 8.1 Create bucket (recommended settings)

- Create an S3 bucket (private)
- Enable **Bucket Versioning**
- Keep Block Public Access enabled

Suggested object layout:

```
s3://<bucket>/tilesets/belarus/2026-02-28/belarus.mbtiles
s3://<bucket>/tilesets/grodno/2026-02-28/grodno.mbtiles
s3://<bucket>/tilesets/minsk/2026-02-28/minsk.mbtiles
...
s3://<bucket>/manifests/latest.json
```

Recommended `latest.json` (values are FULL `s3://...` URIs):

```json
{
  "belarus": "s3://<bucket>/tilesets/belarus/2026-02-28/belarus.mbtiles",
  "grodno": "s3://<bucket>/tilesets/grodno/2026-02-28/grodno.mbtiles",
  "minsk": "s3://<bucket>/tilesets/minsk/2026-02-28/minsk.mbtiles"
}
```

#### 8.2 IAM: minimal policies

**VPS deploy user/role (read-only):**
- `s3:GetObject` on `tilesets/*` and `manifests/latest.json`
- `s3:ListBucket` on the bucket

**Build job user/role (write):**
- `s3:PutObject` on `tilesets/*` and `manifests/latest.json`
- `s3:AbortMultipartUpload`, `s3:ListBucketMultipartUploads`, `s3:ListMultipartUploadParts`
- `s3:ListBucket` on the bucket

#### 8.3 Install AWS CLI (so `aws ...` commands work)

- **Ubuntu (VPS):**

```bash
sudo apt-get update
sudo apt-get install -y awscli jq
aws --version
```

- **macOS (local dev):**

```bash
brew install awscli jq
aws --version
```

#### 8.4 Configure AWS credentials (so S3 reads work)

Option A (simple IAM user keys):

```bash
aws configure
# AWS Access Key ID [None]: ...
# AWS Secret Access Key [None]: ...
# Default region name [None]: eu-central-1
# Default output format [None]: json
```

This writes `~/.aws/credentials` and `~/.aws/config`.

Option B (recommended on AWS EC2): use an **instance role** and skip access keys.

Quick check (optional):

```bash
aws sts get-caller-identity
aws s3 ls "s3://<bucket>/"
```

#### 8.5 Recommended workflow: upstream → S3 → servers pull

If your MBTiles come from an open source source (or a build pipeline), you can keep servers simple:

- **Build machine / CI**: download/build MBTiles, upload to S3, update `manifests/latest.json`
- **Servers (VPS)**: periodically pull from S3 using `fetch-mbtiles-s3.sh` (cron)

Example upload (run on your build machine/CI):

```bash
aws s3 cp ./belarus.mbtiles "s3://<bucket>/tilesets/belarus/$(date +%F)/belarus.mbtiles"
aws s3 cp ./grodno.mbtiles  "s3://<bucket>/tilesets/grodno/$(date +%F)/grodno.mbtiles"
```

Then update the manifest (example):

```bash
aws s3 cp ./latest.json "s3://<bucket>/manifests/latest.json" --content-type "application/json"
```

### 9) Download MBTiles from S3 and update the server

Direct S3 URI (one dataset):

```bash
cd yt-tiles-server
./scripts/fetch-mbtiles-s3.sh grodno "s3://<bucket>/tilesets/grodno/2026-02-28/grodno.mbtiles"
```

Via manifest (one dataset):

```bash
cd yt-tiles-server
./scripts/fetch-mbtiles-s3.sh grodno --manifest "s3://<bucket>/manifests/latest.json"
```

### 10) Cron jobs (different frequencies per area)

Install cron (usually already installed on Ubuntu):

```bash
sudo apt-get install -y cron
sudo systemctl enable --now cron
```

Edit crontab:

```bash
crontab -e
```

Example cron entries (use `flock` to avoid overlaps):

```cron
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Belarus (weekly, Sunday 03:10 UTC)
10 3 * * 0 cd /root/yt-tiles-server && flock -n /tmp/yt-belarus.lock ./scripts/fetch-mbtiles-s3.sh belarus --manifest "s3://<bucket>/manifests/latest.json" >>/var/log/yt-belarus.log 2>&1

# Grodno (every 6 hours)
0 */6 * * * cd /root/yt-tiles-server && flock -n /tmp/yt-grodno.lock ./scripts/fetch-mbtiles-s3.sh grodno --manifest "s3://<bucket>/manifests/latest.json" >>/var/log/yt-grodno.log 2>&1

# Minsk (daily 02:20 UTC)
20 2 * * * cd /root/yt-tiles-server && flock -n /tmp/yt-minsk.lock ./scripts/fetch-mbtiles-s3.sh minsk --manifest "s3://<bucket>/manifests/latest.json" >>/var/log/yt-minsk.log 2>&1
```

Tip: if you run the repo under a different user/path, change `cd /root/yt-tiles-server`.
