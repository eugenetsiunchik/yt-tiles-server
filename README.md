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

For Git hosting providers (GitHub/GitLab/etc) an `ed25519` key is recommended:

```bash
ssh-keygen -t ed25519 -C "you@example.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key to clipboard (pick one):
# - macOS:
pbcopy < ~/.ssh/id_ed25519.pub
# - Linux (X11):
# xclip -selection clipboard < ~/.ssh/id_ed25519.pub
# - Linux (Wayland):
# wl-copy < ~/.ssh/id_ed25519.pub
# - Anywhere (just print it and copy manually):
# cat ~/.ssh/id_ed25519.pub
```

- Add the copied public key to your Git hosting provider (GitHub/GitLab/etc).
- Verify:

```bash
ssh -T git@github.com  # replace github.com with your Git host
```

If you need an `ssh-rsa` key (some VPS panels reject `ssh-ed25519` and only accept public keys that start with `ssh-rsa ...`):

```bash
ssh-keygen -t rsa -b 4096 -o -a 64 -f ~/.ssh/id_rsa_yt_tiles -C "root@176.223.129.1"
cat ~/.ssh/id_rsa_yt_tiles.pub
```

Connect using that key:

```bash
ssh -i ~/.ssh/id_rsa_yt_tiles -o IdentitiesOnly=yes root@176.223.129.1
```

Or use this repo’s helper script (opens iTerm2 and runs SSH):

```bash
./ssh-terminal2.sh
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
# Option A: build from open data (OSM) using an open-source generator (recommended if you don't already host MBTiles)
# ./scripts/fetch-mbtiles-open.sh belarus belarus
#
# Option B: download from an HTTP(S) URL (recommended if you already have a published .mbtiles)
# ./scripts/fetch-mbtiles.sh belarus "https://example.com/belarus.mbtiles"
# ./scripts/fetch-mbtiles.sh grodno  "https://example.com/grodno.mbtiles"
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
sudo apt-get install -y ufw
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
# Option B: build from open data (OSM) using an open-source generator
# ./scripts/fetch-mbtiles-open.sh belarus belarus
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

### 8) Build MBTiles from open data (OSM) with Planetiler/OpenMapTiles

This repo includes `scripts/fetch-mbtiles-open.sh`, which uses the open-source Planetiler OpenMapTiles Docker image to **download OSM data and generate** an OpenMapTiles-compatible `.mbtiles`.

Example (Belarus, \(z0–z14\)):

```bash
cd yt-tiles-server
MAXZOOM=14 ./scripts/fetch-mbtiles-open.sh belarus belarus
```

- If you hit `java.lang.OutOfMemoryError: Java heap space`, rerun with a larger heap (and/or reduce Docker Desktop memory):

```bash
cd yt-tiles-server
JAVA_XMX=8g MAXZOOM=14 ./scripts/fetch-mbtiles-open.sh belarus belarus
```

- The script defaults to `--storage=mmap` (stores the node location cache on disk instead of heap). If you have plenty of RAM, you can speed it up with:

```bash
cd yt-tiles-server
STORAGE=ram JAVA_XMX=16g MAXZOOM=14 ./scripts/fetch-mbtiles-open.sh belarus belarus
```

- The second argument (`area`) is passed through to Planetiler’s `--area=...`.
- If you need a different region name/format, check the upstream docs: [openmaptiles/planetiler-openmaptiles](https://github.com/openmaptiles/planetiler-openmaptiles).

Production tip: building MBTiles can be CPU/disk heavy. A common approach is to build on a separate machine/CI and then have servers update via `./scripts/fetch-mbtiles.sh <dataset> https://.../<dataset>.mbtiles` or `scp` + `./scripts/update-mbtiles.sh`.

### 9) Cron jobs (different frequencies per area)

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
10 3 * * 0 cd /root/yt-tiles-server && flock -n /tmp/yt-belarus.lock MAXZOOM=14 ./scripts/fetch-mbtiles-open.sh belarus belarus >>/var/log/yt-belarus.log 2>&1

# Grodno (every 6 hours)
0 */6 * * * cd /root/yt-tiles-server && flock -n /tmp/yt-grodno.lock ./scripts/fetch-mbtiles.sh grodno "https://example.com/grodno.mbtiles" >>/var/log/yt-grodno.log 2>&1

# Minsk (daily 02:20 UTC)
20 2 * * * cd /root/yt-tiles-server && flock -n /tmp/yt-minsk.lock ./scripts/fetch-mbtiles.sh minsk "https://example.com/minsk.mbtiles" >>/var/log/yt-minsk.log 2>&1
```

Tip: if you run the repo under a different user/path, change `cd /root/yt-tiles-server`.
