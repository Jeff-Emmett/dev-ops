# FCDM Website Deployment - Manual Steps

**Droplet IP**: `143.198.39.165`
**Status**: Steps 1-5 completed automatically (system updated, Docker installed, firewall configured, files extracted, Cloudflared installed)

---

## Completed Steps ✅

- ✅ System updated
- ✅ Docker installed and started
- ✅ Firewall configured (UFW with SSH, HTTP, HTTPS)
- ✅ Website files extracted to `/opt/websites/FCDM-website-new-kt`
- ✅ Cloudflared installed

---

## Remaining Steps

### Step 1: SSH into Droplet

```bash
ssh root@143.198.39.165
```

---

### Step 2: Authenticate with Cloudflare

Run this command on the droplet:

```bash
cloudflared tunnel login
```

**Action Required**:
1. Copy the URL that appears in the terminal
2. Open it in your browser
3. Log in to your Cloudflare account
4. Select domain: `fullcircledigitalmarketing.ca`
5. Click "Authorize"

---

### Step 3: Create the Tunnel

```bash
cloudflared tunnel create fcdm-multi-site
```

**Important**: Save the Tunnel ID that appears (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)

**Tunnel ID**: _______________________________________

---

### Step 4: Configure the Tunnel

Replace `<TUNNEL_ID>` with your actual tunnel ID from Step 3:

```bash
mkdir -p ~/.cloudflared

cat > ~/.cloudflared/config.yml << 'EOF'
tunnel: <TUNNEL_ID>
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: fullcircledigitalmarketing.ca
    service: http://localhost:80
    originRequest:
      noTLSVerify: true
      connectTimeout: 10s
      httpHostHeader: fullcircledigitalmarketing.ca

  - hostname: www.fullcircledigitalmarketing.ca
    service: http://localhost:80
    originRequest:
      httpHostHeader: fullcircledigitalmarketing.ca

  - service: http_status:404

loglevel: info
EOF
```

---

### Step 5: Configure DNS

```bash
cloudflared tunnel route dns fcdm-multi-site fullcircledigitalmarketing.ca
cloudflared tunnel route dns fcdm-multi-site www.fullcircledigitalmarketing.ca
```

---

### Step 6: Start Cloudflare Tunnel Service

```bash
cloudflared service install
systemctl start cloudflared
systemctl enable cloudflared
systemctl status cloudflared
```

**Verify**: Service should show "active (running)"

---

### Step 7: Build Docker Image

```bash
cd /opt/websites/FCDM-website-new-kt
docker build -t fcdm-site:latest -f Dockerfile .
```

**Note**: This will take 3-5 minutes to complete

---

### Step 8: Start Multi-Site Stack

```bash
cd /opt/websites/FCDM-website-new-kt/multi-site
docker-compose -f docker-compose.production.yml up -d
```

---

### Step 9: Verify Deployment

```bash
# Check running containers
docker ps

# Check Cloudflare tunnel status
systemctl status cloudflared

# View nginx logs
docker logs nginx-proxy

# View FCDM site logs
docker logs fcdm-site
```

**Expected Output**:
- `nginx-proxy` container: running
- `fcdm-site` container: running
- cloudflared service: active (running)

---

### Step 10: Test Website

Wait 1-2 minutes for DNS propagation, then visit:

- **Main site**: https://fullcircledigitalmarketing.ca
- **WWW redirect**: https://www.fullcircledigitalmarketing.ca

---

## Troubleshooting

### If containers aren't starting:

```bash
# Check Docker logs
docker logs nginx-proxy
docker logs fcdm-site

# Restart containers
docker-compose -f /opt/websites/FCDM-website-new-kt/multi-site/docker-compose.production.yml restart
```

### If tunnel isn't connecting:

```bash
# Check tunnel status
systemctl status cloudflared

# View tunnel logs
journalctl -u cloudflared -f

# Restart tunnel
systemctl restart cloudflared
```

### If website isn't accessible:

```bash
# Test local access
curl http://localhost:80

# Check DNS propagation
dig fullcircledigitalmarketing.ca

# Verify tunnel routes
cloudflared tunnel route dns list
```

---

## Useful Commands

```bash
# View all running containers
docker ps

# Stop all containers
docker-compose -f /opt/websites/FCDM-website-new-kt/multi-site/docker-compose.production.yml down

# Start all containers
docker-compose -f /opt/websites/FCDM-website-new-kt/multi-site/docker-compose.production.yml up -d

# View real-time logs
docker logs -f nginx-proxy
docker logs -f fcdm-site

# Check tunnel configuration
cat ~/.cloudflared/config.yml

# List all tunnels
cloudflared tunnel list
```

---

## File Locations

- **Website files**: `/opt/websites/FCDM-website-new-kt`
- **Docker Compose**: `/opt/websites/FCDM-website-new-kt/multi-site/docker-compose.production.yml`
- **Nginx config**: `/opt/websites/FCDM-website-new-kt/multi-site/nginx/nginx.conf`
- **Cloudflare config**: `~/.cloudflared/config.yml`
- **Cloudflare credentials**: `~/.cloudflared/<TUNNEL_ID>.json`

---

## Next Steps After Deployment

1. Add additional websites to the multi-site stack
2. Set up monitoring (Portainer, Grafana)
3. Configure backups
4. Set up CI/CD pipeline for automatic deployments
5. Add SSL certificate monitoring

---

## Notes

- **Droplet**: DigitalOcean $12/month (2GB RAM, 2 vCPU, Toronto region)
- **OS**: Ubuntu 24.04.3 LTS
- **Security**: UFW firewall enabled, fail2ban installed
- **Tunnel**: Cloudflare Tunnel (zero exposed ports)
- **Containers**: Nginx reverse proxy + FCDM site
