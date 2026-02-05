# Pi-hole DNS Ad Blocker

Local DNS-level ad blocking via Colima + Docker. No hardware required.

## Architecture

```
macOS DNS (127.0.0.1)
    │
    ▼
Colima VM (port-forward :53)
    │
    ▼
Pi-hole Container
    ├── DNS queries → Block ads, allow legit
    └── Upstream → Cloudflare (1.1.1.1)
```

## Quick Start

```bash
# Start Pi-hole
./scripts/pihole/setup-pihole.sh start

# Point macOS DNS to Pi-hole
./scripts/pihole/setup-pihole.sh dns-on

# Check status
./scripts/pihole/setup-pihole.sh status
```

Or with Fish shell:

```bash
pihole start
pihole dns-on
pihole status
```

## Commands

| Command | Description |
|---------|-------------|
| `start` | Start Pi-hole container via Colima |
| `stop` | Stop Pi-hole container |
| `restart` | Restart Pi-hole container |
| `status` | Show Pi-hole and DNS status |
| `dns-on` | Point macOS DNS to Pi-hole (127.0.0.1) |
| `dns-off` | Restore Cloudflare DNS (1.1.1.1) |
| `logs` | Tail Pi-hole container logs |
| `update` | Pull latest Pi-hole Docker image |
| `uninstall` | Remove Pi-hole and restore DNS |

## Web Admin

- URL: http://localhost:8053/admin
- Password: Set via `PIHOLE_PASSWORD` env var (default: `changeme`)

```bash
# Set a custom password
PIHOLE_PASSWORD=mysecretpass ./scripts/pihole/setup-pihole.sh start
```

## Configuration

### Docker Compose

`docker-compose.yml` - Pi-hole container configuration:
- DNS on port 53 (TCP/UDP)
- Web admin on port 8053
- Upstream DNS: Cloudflare (1.1.1.1, 1.0.0.1)
- DNSSEC enabled
- Persistent volumes for config and data

### Custom Blocklists

Edit `custom-blocklist.txt` to add domains to block on top of default lists.
Apply changes with:

```bash
docker exec pihole pihole -g
```

## How It Works

1. **Colima** provides a lightweight Linux VM with Docker on macOS
2. **Pi-hole** runs as a Docker container inside Colima
3. **Port forwarding** maps container port 53 to `localhost:53`
4. **macOS DNS** is pointed to `127.0.0.1` (Pi-hole)
5. DNS queries hit Pi-hole, which blocks ad domains and forwards legit queries to Cloudflare

## Prerequisites

Both are already in the Brewfile:
- `colima` - Container runtime for macOS
- `docker` - Docker CLI (via Homebrew, not Docker Desktop)

## Portability

This setup works on any Mac with Colima installed. The Pi-hole configuration is stored in Docker volumes, so it persists across container restarts but is local to each machine.

For network-wide ad blocking across all devices, you'd need to:
1. Run Pi-hole on an always-on server (Raspberry Pi, cloud VM)
2. Configure your router's DHCP to point DNS to that server

## Troubleshooting

### Port 53 conflict
macOS runs `mDNSResponder` on port 53. Colima handles this via its VM's separate network namespace - no conflict.

### DNS not working after dns-on
```bash
# Flush DNS cache
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder

# Verify DNS setting
networksetup -getdnsservers "Wi-Fi"

# Check Pi-hole is responding
dig @127.0.0.1 google.com
```

### Pi-hole not starting
```bash
# Check Colima status
colima status

# Check container logs
docker logs pihole

# Restart everything
./scripts/pihole/setup-pihole.sh restart
```
