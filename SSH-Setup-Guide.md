# SSH Setup Guide

## Overview
This guide documents the SSH configuration needed to securely connect your devices (laptop, mobile, tablets, network devices) with your cloud services (GitHub, Digital Ocean, RunPod, Docker hosts) through Cloudflare tunnels where appropriate.

## Table of Contents
- [SSH Key Generation Strategy](#ssh-key-generation-strategy)
- [Device Configuration](#device-configuration)
- [Service Configuration](#service-configuration)
- [Cloudflare Tunnel Setup](#cloudflare-tunnel-setup)
- [Security Best Practices](#security-best-practices)
- [Advanced Security Considerations](#advanced-security-considerations)
- [IP Leak Prevention](#ip-leak-prevention)
- [Troubleshooting](#troubleshooting)

---

## SSH Key Generation Strategy

### Key Pair Architecture
Generate separate key pairs for different security contexts:

1. **GitHub Keys** (per device)
   - Laptop: `~/.ssh/id_ed25519_github_laptop`
   - Mobile: `~/.ssh/id_ed25519_github_mobile`
   - Tablet: `~/.ssh/id_ed25519_github_tablet`

2. **Infrastructure Keys** (per device, shared across DO/RunPod/Docker)
   - Laptop: `~/.ssh/id_ed25519_infra_laptop`
   - Mobile: `~/.ssh/id_ed25519_infra_mobile`
   - Tablet: `~/.ssh/id_ed25519_infra_tablet`

3. **Network Device Keys** (management)
   - Admin workstation: `~/.ssh/id_ed25519_network_admin`

### Generate Keys

```bash
# GitHub key (example for laptop)
ssh-keygen -t ed25519 -C "laptop-github-$(date +%Y%m%d)" -f ~/.ssh/id_ed25519_github_laptop

# Infrastructure key (example for laptop)
ssh-keygen -t ed25519 -C "laptop-infra-$(date +%Y%m%d)" -f ~/.ssh/id_ed25519_infra_laptop

# Network admin key
ssh-keygen -t ed25519 -C "network-admin-$(date +%Y%m%d)" -f ~/.ssh/id_ed25519_network_admin
```

**Important**: Use strong passphrases for all keys. Store passphrases in a password manager.

---

## Device Configuration

### Laptop Setup

#### SSH Config (`~/.ssh/config`)

```ssh-config
# Global settings
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    AddKeysToAgent yes
    IdentitiesOnly yes
    # Prevent IP leaks and enhance security
    Compression yes
    TCPKeepAlive no
    # Prevent connection reuse attacks
    ControlMaster no
    # Prevent DNS leaks
    VerifyHostKeyDNS no
    # Disable potentially insecure features
    GSSAPIAuthentication no
    HostbasedAuthentication no
    # Use only secure ciphers and algorithms
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group18-sha512
    HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
    PubkeyAcceptedKeyTypes ssh-ed25519,rsa-sha2-512,rsa-sha2-256

# GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github_laptop
    PreferredAuthentications publickey

# Digital Ocean Droplets
Host do-*
    User root
    IdentityFile ~/.ssh/id_ed25519_infra_laptop
    StrictHostKeyChecking ask

Host do-prod
    HostName <DIGITAL_OCEAN_IP>
    User deploy
    Port 22

Host do-staging
    HostName <DIGITAL_OCEAN_IP>
    User deploy
    Port 22

# RunPod Instances
Host runpod-*
    User root
    IdentityFile ~/.ssh/id_ed25519_infra_laptop
    StrictHostKeyChecking ask

Host runpod-gpu-1
    HostName <RUNPOD_IP>
    User root
    Port 22

# Docker Hosts (via Cloudflare Tunnel)
Host docker-*
    User docker-admin
    IdentityFile ~/.ssh/id_ed25519_infra_laptop
    ProxyCommand cloudflared access ssh --hostname %h

Host docker-prod
    HostName docker-prod.yourdomain.com
    User docker-admin

Host docker-staging
    HostName docker-staging.yourdomain.com
    User docker-admin

# Network Devices
Host router
    HostName 192.168.1.1
    User admin
    IdentityFile ~/.ssh/id_ed25519_network_admin
    Port 22

Host switch
    HostName 192.168.1.2
    User admin
    IdentityFile ~/.ssh/id_ed25519_network_admin
    Port 22
```

#### Tasks for Laptop
- [ ] Generate SSH keys for GitHub and infrastructure
- [ ] Create `~/.ssh/config` with above configuration
- [ ] Set proper permissions: `chmod 600 ~/.ssh/id_* && chmod 644 ~/.ssh/*.pub`
- [ ] Add public keys to respective services
- [ ] Configure SSH agent to auto-load keys
- [ ] Test connections to all services

---

### Mobile Setup (Termux/SSH Client App)

#### Android (Termux)
```bash
# Install Termux from F-Droid
pkg update && pkg upgrade
pkg install openssh git

# Generate keys
ssh-keygen -t ed25519 -C "mobile-github-$(date +%Y%m%d)" -f ~/.ssh/id_ed25519_github_mobile
ssh-keygen -t ed25519 -C "mobile-infra-$(date +%Y%m%d)" -f ~/.ssh/id_ed25519_infra_mobile

# Set permissions
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
```

#### iOS (Blink Shell / Secure ShellFish)
- Generate keys within the app
- Export public keys
- Configure hosts in app settings

#### Tasks for Mobile
- [ ] Install SSH client (Termux/Blink Shell/Secure ShellFish)
- [ ] Generate SSH keys for GitHub and infrastructure
- [ ] Add public keys to services
- [ ] Configure host profiles in SSH client
- [ ] Test connections via mobile network and WiFi
- [ ] Set up Cloudflare WARP for secure tunnel access

---

### Tablet Setup

Similar to mobile setup, choose appropriate SSH client:
- **Android**: Termux, JuiceSSH, ConnectBot
- **iOS**: Blink Shell, Secure ShellFish

#### Tasks for Tablet
- [ ] Install SSH client
- [ ] Generate SSH keys
- [ ] Add public keys to services
- [ ] Configure host profiles
- [ ] Test connections

---

## Service Configuration

### GitHub

#### Add SSH Keys
1. Copy public key: `cat ~/.ssh/id_ed25519_github_laptop.pub`
2. Go to GitHub → Settings → SSH and GPG keys → New SSH key
3. Add key with descriptive title (e.g., "Laptop - Ubuntu 2025")
4. Repeat for each device

#### Test Connection
```bash
ssh -T git@github.com
```

#### Tasks
- [ ] Add laptop SSH public key to GitHub
- [ ] Add mobile SSH public key to GitHub
- [ ] Add tablet SSH public key to GitHub
- [ ] Verify each device can clone/push repos
- [ ] Configure git to use SSH URLs by default

---

### Digital Ocean

#### Add SSH Keys to Account
1. Go to Digital Ocean → Settings → Security → SSH Keys
2. Add public key for each device infrastructure key
3. Name keys clearly (e.g., "Laptop Infrastructure Key 2025")

#### Configure Droplets
```bash
# On each droplet, ensure your keys are in authorized_keys
ssh root@<droplet-ip>
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "<PUBLIC_KEY>" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Create non-root user with sudo
adduser deploy
usermod -aG sudo deploy
mkdir -p /home/deploy/.ssh
cp ~/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
```

#### Harden SSH on Droplets
Edit `/etc/ssh/sshd_config`:
```
# Authentication
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
PermitEmptyPasswords no
UsePAM yes
AuthenticationMethods publickey

# User restrictions
AllowUsers deploy
MaxAuthTries 3
MaxSessions 2
LoginGraceTime 30

# Disable insecure features
X11Forwarding no
PermitTunnel no
AllowAgentForwarding no
AllowTcpForwarding no
GatewayPorts no
PermitUserEnvironment no
PrintMotd no
PrintLastLog yes
TCPKeepAlive no

# Network security
Port 22
Protocol 2
ListenAddress 0.0.0.0
AddressFamily inet

# Cryptography - Use only secure algorithms
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group18-sha512,diffie-hellman-group16-sha512
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256

# Key configuration
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Environment
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

# Rate limiting and connection management
ClientAliveInterval 300
ClientAliveCountMax 2
MaxStartups 10:30:60
```

Additional hardening steps:
```bash
# Remove weak host keys
sudo rm /etc/ssh/ssh_host_dsa_key* /etc/ssh/ssh_host_ecdsa_key* 2>/dev/null

# Regenerate strong host keys if needed
sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
sudo ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ""

# Set proper permissions
sudo chmod 600 /etc/ssh/ssh_host_*_key
sudo chmod 644 /etc/ssh/ssh_host_*_key.pub

# Test configuration before restarting
sudo sshd -t

# Restart SSH
systemctl restart sshd
```

#### Tasks
- [ ] Add infrastructure keys to Digital Ocean account
- [ ] Add keys to all droplet `authorized_keys`
- [ ] Create non-root users on each droplet
- [ ] Harden SSH configuration on all droplets
- [ ] Set up UFW firewall rules
- [ ] Configure fail2ban for SSH protection
- [ ] Test connections from each device

---

### RunPod

#### Configure GPU Instances
```bash
# SSH into RunPod instance (usually exposed on custom port)
ssh root@<runpod-ip> -p <custom-port>

# Add your infrastructure keys
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "<PUBLIC_KEY>" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

#### Tasks
- [ ] Document RunPod instance IPs and ports
- [ ] Add infrastructure keys to each RunPod instance
- [ ] Test connections from laptop
- [ ] Set up persistent storage for SSH keys
- [ ] Configure RunPod firewall rules (if available)
- [ ] Consider using Cloudflare Tunnel for RunPod access

---

### Docker Hosts

#### Setup Docker User
```bash
# On each Docker host
adduser docker-admin
usermod -aG docker docker-admin
mkdir -p /home/docker-admin/.ssh
chmod 700 /home/docker-admin/.ssh

# Add infrastructure keys
echo "<PUBLIC_KEY>" >> /home/docker-admin/.ssh/authorized_keys
chmod 600 /home/docker-admin/.ssh/authorized_keys
chown -R docker-admin:docker-admin /home/docker-admin/.ssh
```

#### Secure Docker Daemon
Edit `/etc/docker/daemon.json`:
```json
{
  "hosts": ["unix:///var/run/docker.sock"],
  "tls": true,
  "tlscert": "/etc/docker/certs/server-cert.pem",
  "tlskey": "/etc/docker/certs/server-key.pem",
  "tlsverify": true,
  "tlscacert": "/etc/docker/certs/ca.pem"
}
```

#### Tasks
- [ ] Create docker-admin users on all Docker hosts
- [ ] Add infrastructure keys to docker-admin authorized_keys
- [ ] Set up Docker TLS certificates
- [ ] Configure Docker to use Cloudflare Tunnel
- [ ] Test Docker commands over SSH
- [ ] Document Docker host access patterns

---

## Cloudflare Tunnel Setup

### Install cloudflared

#### On Laptop
```bash
# Linux
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# macOS
brew install cloudflared
```

#### On Mobile (Termux)
```bash
pkg install cloudflared
```

### Authenticate
```bash
cloudflared tunnel login
```

### Create Tunnels for Services

#### Docker Host Tunnel
```bash
# Create tunnel
cloudflared tunnel create docker-prod

# Configure tunnel
cat > ~/.cloudflared/config.yml << EOF
tunnel: <TUNNEL_ID>
credentials-file: /home/user/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: docker-prod.yourdomain.com
    service: ssh://localhost:22
  - service: http_status:404
EOF

# Route DNS
cloudflared tunnel route dns docker-prod docker-prod.yourdomain.com

# Run tunnel as service
cloudflared service install
systemctl enable cloudflared
systemctl start cloudflared
```

### Configure Cloudflare Access

1. Go to Cloudflare Zero Trust Dashboard
2. Access → Applications → Add an application
3. Choose "Self-hosted"
4. Set application name: "Docker Production SSH"
5. Set subdomain: `docker-prod.yourdomain.com`
6. Add access policies:
   - Policy name: "Authorized Users"
   - Action: Allow
   - Include: Emails (add your email addresses)
7. Save application

### Client Configuration

Add to `~/.ssh/config`:
```ssh-config
Host *.yourdomain.com
    ProxyCommand cloudflared access ssh --hostname %h
```

#### Tasks
- [ ] Install cloudflared on laptop
- [ ] Install cloudflared on mobile devices
- [ ] Authenticate cloudflared with Cloudflare account
- [ ] Create tunnels for each Docker host
- [ ] Create tunnels for RunPod instances (if needed)
- [ ] Configure Cloudflare Access policies
- [ ] Set up DNS routes
- [ ] Test SSH through Cloudflare Tunnel from each device
- [ ] Configure tunnel as system service on servers
- [ ] Set up monitoring for tunnel health

---

## Security Best Practices

### Key Management
- [ ] Use separate keys for different services/contexts
- [ ] Use strong passphrases on all private keys
- [ ] Store passphrases in password manager
- [ ] Never share private keys between devices
- [ ] Regularly rotate keys (every 6-12 months)
- [ ] Remove old/unused keys from authorized_keys
- [ ] Keep private keys encrypted on disk
- [ ] Use `ssh-agent` for key management, not plaintext keys

### SSH Hardening
- [ ] Disable password authentication
- [ ] Disable root login
- [ ] Use non-standard ports where possible
- [ ] Implement fail2ban or similar
- [ ] Use UFW/iptables for firewall rules
- [ ] Enable two-factor authentication where supported
- [ ] Use SSH certificates for larger deployments
- [ ] Monitor SSH logs regularly
- [ ] Set up alerts for failed login attempts

### Network Security
- [ ] Use Cloudflare Tunnel for exposing services
- [ ] Implement Zero Trust access policies
- [ ] Use VPN for accessing network devices
- [ ] Segment network (separate VLAN for management)
- [ ] Enable firewall on all devices
- [ ] Use SSH key forwarding carefully (security risk)
- [ ] Disable SSH forwarding when not needed
- [ ] Use bastion/jump hosts for production access

### Monitoring and Auditing
- [ ] Set up centralized logging (syslog/ELK)
- [ ] Monitor SSH access logs
- [ ] Set up alerts for suspicious activity
- [ ] Regular security audits of authorized_keys
- [ ] Document all SSH access patterns
- [ ] Review Cloudflare Access logs regularly
- [ ] Keep inventory of all SSH keys and their purposes

---

## Advanced Security Considerations

### IP Leak Prevention

#### Understanding IP Leak Vectors

IP leaks can occur through multiple vectors when using SSH and related services:

1. **DNS Leaks**: DNS queries bypass VPN/tunnel and reveal your location
2. **WebRTC Leaks**: Browser-based SSH clients may leak local IP
3. **SSH Connection Metadata**: Connection timing and patterns can reveal identity
4. **IPv6 Leaks**: IPv6 traffic bypasses IPv4-only VPN tunnels
5. **Application Leaks**: Applications making direct connections outside SSH tunnel
6. **Time Zone Leaks**: System time zone information in logs
7. **SSH Agent Forwarding Leaks**: Forwarded agents expose authentication to compromised hosts

#### DNS Leak Prevention

**On Linux:**
```bash
# Configure systemd-resolved to use encrypted DNS
sudo tee /etc/systemd/resolved.conf << EOF
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com
DNSOverTLS=yes
DNSSEC=yes
Domains=~.
EOF

sudo systemctl restart systemd-resolved

# Verify DNS is not leaking
dig whoami.akamai.net +short
```

**Alternative: Use dnscrypt-proxy**
```bash
# Install dnscrypt-proxy
sudo apt install dnscrypt-proxy

# Configure to use DoH (DNS over HTTPS)
sudo tee /etc/dnscrypt-proxy/dnscrypt-proxy.toml << EOF
server_names = ['cloudflare', 'cloudflare-ipv6']
listen_addresses = ['127.0.0.1:53']
force_tcp = true
require_dnssec = true
require_nolog = true
require_nofilter = true
EOF

# Restart and enable
sudo systemctl enable dnscrypt-proxy
sudo systemctl restart dnscrypt-proxy

# Configure NetworkManager to use local DNS
sudo tee /etc/NetworkManager/conf.d/dns.conf << EOF
[main]
dns=none
systemd-resolved=false
EOF

echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
sudo chattr +i /etc/resolv.conf  # Make immutable
```

**On Mobile (Android with Termux):**
```bash
# Use Cloudflare's 1.1.1.1 app or configure Private DNS in Android settings
# Settings → Network & Internet → Advanced → Private DNS
# Set to: 1dot1dot1dot1.cloudflare-dns.com
```

#### IPv6 Leak Prevention

Many VPNs and tunnels only route IPv4 traffic, allowing IPv6 to leak:

```bash
# Disable IPv6 system-wide (Linux)
sudo tee /etc/sysctl.d/99-disable-ipv6.conf << EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 0
EOF

sudo sysctl -p /etc/sysctl.d/99-disable-ipv6.conf

# Verify IPv6 is disabled
ip -6 addr show

# Alternative: Use ip6tables to block all IPv6
sudo ip6tables -P INPUT DROP
sudo ip6tables -P FORWARD DROP
sudo ip6tables -P OUTPUT DROP
```

**Test for IPv6 leaks:**
```bash
curl -6 https://ipv6.icanhazip.com  # Should fail if IPv6 is disabled
```

#### SSH Tunnel and Port Forwarding Security

**SOCKS5 Proxy for Application Traffic:**
```bash
# Create SOCKS5 proxy through SSH tunnel
ssh -D 8080 -C -N user@remote-host

# Configure applications to use SOCKS proxy
export ALL_PROXY=socks5://127.0.0.1:8080
export HTTP_PROXY=socks5://127.0.0.1:8080
export HTTPS_PROXY=socks5://127.0.0.1:8080

# Test proxy is working
curl --proxy socks5://127.0.0.1:8080 https://ipinfo.io/ip
```

**Prevent DNS leaks through SOCKS proxy:**
```ssh-config
# Add to ~/.ssh/config
Host secure-tunnel
    HostName remote-server.com
    User username
    DynamicForward 8080
    # Force DNS through the tunnel
    RemoteForward 53 localhost:53
    Compression yes
    ServerAliveInterval 60
```

#### Cloudflare WARP for Zero Trust Access

WARP provides encrypted tunnel with IP leak protection:

```bash
# Install Cloudflare WARP (Linux)
curl https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt update && sudo apt install cloudflare-warp

# Register and connect
warp-cli register
warp-cli connect

# Verify connection
warp-cli status
curl https://www.cloudflare.com/cdn-cgi/trace/

# Enable DNS over HTTPS
warp-cli set-mode warp+doh
```

**On Mobile:**
- Install Cloudflare WARP app from Play Store/App Store
- Enable "WARP+" mode for full encryption
- Configure to auto-connect on untrusted networks

#### Network Namespace Isolation (Advanced Linux)

Create isolated network namespace for SSH connections:

```bash
#!/bin/bash
# Create network namespace for secure SSH
sudo ip netns add secure_ssh

# Create veth pair
sudo ip link add veth0 type veth peer name veth1

# Move one end to namespace
sudo ip link set veth1 netns secure_ssh

# Configure namespace networking
sudo ip netns exec secure_ssh ip addr add 10.200.1.2/24 dev veth1
sudo ip netns exec secure_ssh ip link set veth1 up
sudo ip netns exec secure_ssh ip link set lo up
sudo ip netns exec secure_ssh ip route add default via 10.200.1.1

# Configure host side
sudo ip addr add 10.200.1.1/24 dev veth0
sudo ip link set veth0 up

# Enable NAT for the namespace
sudo iptables -t nat -A POSTROUTING -s 10.200.1.0/24 -j MASQUERADE
sudo iptables -A FORWARD -i veth0 -j ACCEPT
sudo iptables -A FORWARD -o veth0 -j ACCEPT

# Run SSH in namespace
sudo ip netns exec secure_ssh sudo -u $USER ssh user@remote-host
```

#### MAC Address Randomization

Prevent device tracking via MAC address:

```bash
# Randomize MAC address on connection (NetworkManager)
sudo tee /etc/NetworkManager/conf.d/mac-randomization.conf << EOF
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF

sudo systemctl restart NetworkManager

# Verify randomization
ip link show | grep ether
```

#### Time Zone and Locale Obfuscation

System information can leak through SSH:

```bash
# Set timezone to UTC to avoid location leaks
sudo timedatectl set-timezone UTC

# Verify
timedatectl

# Use UTC in SSH sessions
echo 'export TZ=UTC' >> ~/.bashrc

# Minimize locale information
echo 'export LC_ALL=C' >> ~/.bashrc
```

### Advanced Threat Protection

#### SSH Tarpit (Slow Down Attackers)

```bash
# Install endlessh - SSH tarpit
sudo apt install endlessh

# Configure to run on port 22 (move real SSH to different port first)
sudo tee /etc/endlessh/config << EOF
Port 22
Delay 10000
MaxLineLength 32
MaxClients 4096
LogLevel 1
EOF

# Move real SSH to different port (e.g., 2222)
# Edit /etc/ssh/sshd_config and set: Port 2222

# Start endlessh
sudo systemctl enable endlessh
sudo systemctl start endlessh
```

#### Port Knocking

Add layer of obscurity with port knocking:

```bash
# Install knockd
sudo apt install knockd

# Configure knock sequence
sudo tee /etc/knockd.conf << EOF
[options]
    UseSyslog

[SSH]
    sequence    = 7000,8000,9000
    seq_timeout = 15
    command     = /sbin/iptables -A INPUT -s %IP% -p tcp --dport 2222 -j ACCEPT
    tcpflags    = syn
    cmd_timeout = 3600
    stop_command = /sbin/iptables -D INPUT -s %IP% -p tcp --dport 2222 -j ACCEPT
    stop_sequence = 9000,8000,7000
EOF

# Enable and start
sudo systemctl enable knockd
sudo systemctl start knockd

# Client side - knock before connecting
knock -v server.com 7000 8000 9000
ssh -p 2222 user@server.com
```

#### Intrusion Detection with AIDE

```bash
# Install AIDE (Advanced Intrusion Detection Environment)
sudo apt install aide aide-common

# Initialize database
sudo aideinit

# Copy database
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Create daily check cron job
echo '0 2 * * * root /usr/bin/aide --check | mail -s "AIDE Report $(date)" your@email.com' | sudo tee -a /etc/crontab

# Manual check
sudo aide --check
```

#### Kernel Hardening

```bash
# Apply kernel hardening parameters
sudo tee /etc/sysctl.d/99-security-hardening.conf << EOF
# Network security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_all = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Kernel security
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 2
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2

# File system hardening
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.suid_dumpable = 0
EOF

sudo sysctl -p /etc/sysctl.d/99-security-hardening.conf
```

### SSH Connection Fingerprinting Prevention

SSH connections can be fingerprinted by timing analysis:

```bash
# Add random delays to SSH traffic
# Add to ~/.ssh/config
Host *
    # Random traffic padding (requires OpenSSH 7.9+)
    SetEnv SSH_RANDOM_PADDING=yes
```

**Use multiplexing carefully** (can help or hurt privacy):
```ssh-config
# Connection multiplexing (reduces fingerprinting by reusing connections)
# But can also leak information if not properly secured
Host trusted-host
    ControlMaster auto
    ControlPath ~/.ssh/control-%h-%p-%r
    ControlPersist 10m
    # Only for trusted hosts
```

### Hardware Security Key Integration

Use hardware security keys (YubiKey, etc.) for SSH:

```bash
# Generate SSH key on YubiKey (FIDO2)
ssh-keygen -t ed25519-sk -C "hardware-key-$(date +%Y%m%d)"

# Or use FIDO2 with PIN
ssh-keygen -t ecdsa-sk -O verify-required -C "hardware-key-pin-$(date +%Y%m%d)"

# Configure SSH to require hardware key
# Add to ~/.ssh/config
Host critical-server
    HostName server.example.com
    IdentityFile ~/.ssh/id_ed25519_sk
    IdentitiesOnly yes
```

**Server-side configuration:**
```
# /etc/ssh/sshd_config
PubkeyAuthOptions verify-required
```

### Secure SSH Agent Configuration

SSH agent forwarding is dangerous but sometimes necessary:

```bash
# Use SSH agent with confirmation prompt
ssh-add -c ~/.ssh/id_ed25519_infra_laptop

# Set timeout for agent keys (1 hour)
ssh-add -t 3600 ~/.ssh/id_ed25519_infra_laptop

# Alternative: Use GPG agent as SSH agent (more secure)
# Add to ~/.bashrc or ~/.zshrc
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
```

**Create GPG-based SSH key:**
```bash
# Generate GPG key with authentication capability
gpg --expert --full-gen-key
# Choose (8) RSA (set your own capabilities)
# Toggle S, E off, A on (authentication only)

# Export SSH public key
gpg --export-ssh-key YOUR_KEY_ID > ~/.ssh/gpg_auth.pub
```

### Egress Filtering and Application Sandboxing

Prevent applications from leaking data:

```bash
# Use firejail to sandbox SSH and related applications
sudo apt install firejail

# Run SSH in sandbox
firejail --net=none --private ssh user@host

# Create profile for SSH client
sudo tee /etc/firejail/ssh-custom.profile << EOF
include /etc/firejail/ssh.profile
# Additional restrictions
blacklist /tmp
blacklist /var/tmp
caps.drop all
nonewprivs
noroot
protocol unix,inet,inet6
seccomp
EOF

# Use custom profile
firejail --profile=/etc/firejail/ssh-custom.profile ssh user@host
```

### Canary Tokens and Honeypots

Deploy canary tokens to detect intrusions:

```bash
# Create fake SSH keys as canary tokens
ssh-keygen -t ed25519 -f ~/.ssh/HONEYPOT_DO_NOT_USE -C "canary-$(date +%Y%m%d)"

# Monitor for access attempts
sudo auditctl -w ~/.ssh/HONEYPOT_DO_NOT_USE -p ra -k ssh_canary

# View audit log
sudo ausearch -k ssh_canary

# Set up alert
echo '*/5 * * * * root ausearch -k ssh_canary -ts recent | grep -q "HONEYPOT" && echo "Canary token accessed!" | mail -s "SECURITY ALERT" your@email.com' | sudo tee -a /etc/crontab
```

### Metadata Removal

Remove identifying information from SSH sessions:

```bash
# Disable SSH banner
# Add to /etc/ssh/sshd_config
DebianBanner no
Banner none

# Minimize information in prompts
echo 'export PS1="\$ "' >> ~/.bashrc

# Disable last login information
touch ~/.hushlogin

# Clear command history on logout
echo 'trap "history -c" EXIT' >> ~/.bash_logout
```

### Quantum-Resistant SSH (Future-Proofing)

Prepare for quantum computing threats:

```bash
# OpenSSH 9.0+ supports hybrid key exchange
# Use post-quantum key exchange methods when available
# Add to ~/.ssh/config
Host quantum-safe
    HostName future-server.com
    KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256
```

**Note**: Full post-quantum SSH is still in development. Monitor OpenSSH releases.

### Tasks for Advanced Security
- [ ] Configure DNS over HTTPS/TLS on all devices
- [ ] Disable IPv6 or ensure it's tunneled properly
- [ ] Set up network namespace isolation for sensitive connections
- [ ] Enable MAC address randomization on all devices
- [ ] Configure time zone to UTC for all SSH sessions
- [ ] Implement SSH tarpit on exposed servers
- [ ] Set up port knocking for additional security layer
- [ ] Install and configure AIDE for intrusion detection
- [ ] Apply kernel hardening parameters
- [ ] Consider hardware security keys for critical systems
- [ ] Configure secure SSH agent with GPG
- [ ] Deploy canary tokens for intrusion detection
- [ ] Remove metadata and identifying information
- [ ] Test all configurations for IP leaks regularly
- [ ] Document all security measures and test procedures

---

## IP Leak Prevention

### Testing for IP Leaks

Regular testing is crucial to ensure no information is leaking:

#### DNS Leak Tests
```bash
# Test DNS leak
dig +short myip.opendns.com @resolver1.opendns.com

# Test DNS over HTTPS
curl -H 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name=whoami.akamai.net&type=A'

# Comprehensive DNS leak test
bash <(curl -s https://raw.githubusercontent.com/macvk/dnsleaktest/master/dnsleaktest.sh)
```

#### IP Leak Tests
```bash
# Check your public IP
curl https://ipinfo.io/ip
curl https://ifconfig.me
curl https://icanhazip.com

# Check for IPv6 leak
curl -6 https://ipv6.icanhazip.com

# Check through SOCKS proxy
curl --proxy socks5://127.0.0.1:8080 https://ipinfo.io/json

# WebRTC leak test (in browser)
# Visit: https://browserleaks.com/webrtc
```

#### Comprehensive Security Check
```bash
#!/bin/bash
# Save as: check-security.sh

echo "=== IP Leak Security Check ==="
echo ""

echo "1. Public IPv4:"
curl -s https://ipinfo.io/ip
echo ""

echo "2. Public IPv6:"
curl -s -6 https://ipv6.icanhazip.com 2>&1 || echo "IPv6 disabled (good)"
echo ""

echo "3. DNS Servers:"
cat /etc/resolv.conf | grep nameserver
echo ""

echo "4. DNS Leak Test:"
dig +short whoami.akamai.net
echo ""

echo "5. Cloudflare WARP Status:"
warp-cli status 2>/dev/null || echo "WARP not installed"
echo ""

echo "6. Active SSH Connections:"
ss -tnp | grep ssh
echo ""

echo "7. SSH Agent Keys:"
ssh-add -l 2>/dev/null || echo "No agent running"
echo ""

echo "8. MAC Address Randomization:"
ip link show | grep -A1 "state UP" | grep "link/ether"
echo ""

echo "9. UFW Status:"
sudo ufw status
echo ""

echo "10. Fail2ban Status:"
sudo fail2ban-client status sshd 2>/dev/null || echo "Fail2ban not configured"
echo ""

echo "=== Check Complete ==="
```

#### Automated Leak Detection
```bash
# Create monitoring script
sudo tee /usr/local/bin/leak-monitor.sh << 'EOF'
#!/bin/bash

EXPECTED_IP="YOUR_VPN_IP_HERE"
CURRENT_IP=$(curl -s https://ipinfo.io/ip)

if [ "$CURRENT_IP" != "$EXPECTED_IP" ]; then
    echo "IP LEAK DETECTED! Current: $CURRENT_IP, Expected: $EXPECTED_IP" | \
    mail -s "IP LEAK ALERT" your@email.com

    # Kill all SSH connections
    killall ssh

    # Log the event
    logger -p auth.crit "IP leak detected: $CURRENT_IP"
fi
EOF

sudo chmod +x /usr/local/bin/leak-monitor.sh

# Run every 5 minutes
echo "*/5 * * * * /usr/local/bin/leak-monitor.sh" | sudo crontab -
```

### Kill Switch Configuration

Automatically disconnect if VPN/tunnel drops:

```bash
# UFW-based kill switch
# Only allow connections through VPN interface

# Reset UFW
sudo ufw --force reset

# Default deny
sudo ufw default deny incoming
sudo ufw default deny outgoing

# Allow local network
sudo ufw allow out on lo
sudo ufw allow in on lo

# Allow VPN interface (replace with your VPN interface)
sudo ufw allow out on tun0
sudo ufw allow in on tun0

# Allow Cloudflare WARP (if using)
sudo ufw allow out to 162.159.192.0/24
sudo ufw allow out to 162.159.193.0/24

# Allow SSH only through VPN
sudo ufw allow out on tun0 to any port 22

# Enable UFW
sudo ufw enable

# Verify rules
sudo ufw status verbose
```

**Alternative: Use systemd to enforce tunnel:**
```bash
sudo tee /etc/systemd/system/ssh-killswitch.service << EOF
[Unit]
Description=SSH Kill Switch
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'if ! ip link show tun0 up > /dev/null 2>&1; then killall ssh; fi'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable ssh-killswitch
sudo systemctl start ssh-killswitch
```

### Mobile Device Specific Protections

#### Android (with Termux)
```bash
# Install torsocks for routing through Tor
pkg install tor torsocks

# Start Tor
tor &

# Use SSH through Tor
torsocks ssh user@host

# Or use with Cloudflare WARP app
# Settings → WARP → Connect
```

#### iOS
- Use Cloudflare WARP app for all traffic
- Configure "On-Demand" VPN rules
- Use Blink Shell's "Session Recording" feature to detect tampering
- Enable "Secure Enclave" for SSH key storage

### Network-Level Protection

#### Router Configuration
```bash
# Enable strict DNS on router (if using pfSense/OPNsense)
# 1. System → Settings → General
# 2. DNS Servers: 1.1.1.1, 1.0.0.1
# 3. Enable "DNS Query Forwarding"
# 4. Enable "Do not use system DNS"

# Block IPv6 at router level if not using VPN with IPv6
# Firewall → Rules → WAN
# Add rule: Block IPv6 any to any
```

#### VLAN Isolation
```
# Create management VLAN for SSH access
VLAN 10: Management (SSH, admin access)
VLAN 20: General network
VLAN 30: IoT devices

# Configure firewall rules:
- VLAN 20/30 cannot reach VLAN 10
- VLAN 10 can reach all VLANs
- Only specific MAC addresses allowed in VLAN 10
```

### Continuous Monitoring

#### Set Up Prometheus + Grafana for SSH Monitoring
```bash
# Install node_exporter for metrics
sudo apt install prometheus-node-exporter

# Install textfile collector for custom metrics
sudo tee /usr/local/bin/ssh-metrics.sh << 'EOF'
#!/bin/bash
echo "# HELP ssh_active_connections Number of active SSH connections"
echo "# TYPE ssh_active_connections gauge"
echo "ssh_active_connections $(ss -tn | grep -c :22)"

echo "# HELP ssh_failed_attempts Number of failed SSH attempts"
echo "# TYPE ssh_failed_attempts counter"
echo "ssh_failed_attempts $(grep -c "Failed password" /var/log/auth.log)"
EOF

sudo chmod +x /usr/local/bin/ssh-metrics.sh

# Run every minute
echo "* * * * * /usr/local/bin/ssh-metrics.sh > /var/lib/prometheus/node-exporter/ssh.prom" | sudo crontab -
```

### Tasks for IP Leak Prevention
- [ ] Set up DNS over HTTPS/TLS on all devices
- [ ] Test for DNS leaks regularly
- [ ] Test for IPv6 leaks regularly
- [ ] Configure kill switch on all devices
- [ ] Set up automated leak monitoring
- [ ] Test all configurations with online leak testing tools
- [ ] Configure router-level protections
- [ ] Set up VLAN isolation for management network
- [ ] Deploy continuous monitoring with alerts
- [ ] Document all test procedures and results
- [ ] Schedule monthly security audits
- [ ] Create incident response plan for detected leaks

---

## Troubleshooting

### Connection Issues

#### Debug SSH Connection
```bash
ssh -vvv user@host
```

#### Common Issues
1. **Permission denied (publickey)**
   - Check key permissions: `ls -la ~/.ssh`
   - Verify key is in authorized_keys on server
   - Ensure IdentityFile is specified correctly in config
   - Check server logs: `journalctl -u sshd -f`

2. **Connection timeout**
   - Check firewall rules
   - Verify host is reachable: `ping <host>`
   - Check SSH service is running: `systemctl status sshd`
   - Verify correct port: `nmap -p 22 <host>`

3. **Host key verification failed**
   - Remove old key: `ssh-keygen -R <hostname>`
   - Verify host fingerprint before accepting

4. **Cloudflare Tunnel not working**
   - Check tunnel status: `cloudflared tunnel list`
   - View tunnel logs: `journalctl -u cloudflared -f`
   - Verify DNS records in Cloudflare dashboard
   - Check Access policies are configured correctly

### Key Issues

#### Locked out of server
- Access via Digital Ocean/RunPod console
- Add emergency key via console
- Review authorized_keys file

#### Compromised key
1. Immediately remove from all authorized_keys files
2. Generate new key pair
3. Update all services with new public key
4. Review access logs for suspicious activity
5. Rotate any other potentially compromised credentials

---

## Quick Reference

### Service Access Matrix

| Service | Laptop | Mobile | Tablet | Key Type |
|---------|--------|--------|--------|----------|
| GitHub | ✓ | ✓ | ✓ | GitHub keys |
| Digital Ocean | ✓ | ✓ | ✓ | Infra keys |
| RunPod | ✓ | ✓ | ○ | Infra keys |
| Docker Hosts | ✓ | ✓ | ○ | Infra keys (via Cloudflare) |
| Network Devices | ✓ | ○ | ○ | Network admin key |

✓ = Primary access, ○ = Optional/limited access

### Emergency Contacts
- Digital Ocean Support: https://cloud.digitalocean.com/support
- RunPod Support: https://www.runpod.io/support
- Cloudflare Support: https://dash.cloudflare.com/support

### Backup and Recovery
- [ ] Export SSH keys to encrypted backup
- [ ] Document recovery procedures
- [ ] Test recovery process quarterly
- [ ] Store emergency access credentials securely
- [ ] Keep offline backup of critical configurations

---

## Maintenance Schedule

### Monthly
- [ ] Review SSH access logs
- [ ] Check for software updates on all hosts
- [ ] Verify Cloudflare Tunnel health
- [ ] Test SSH access from all devices

### Quarterly
- [ ] Audit authorized_keys files
- [ ] Review and update firewall rules
- [ ] Test backup/recovery procedures
- [ ] Review Cloudflare Access policies

### Annually
- [ ] Rotate SSH keys
- [ ] Security audit of entire setup
- [ ] Update this documentation
- [ ] Review and update emergency procedures

---

## Notes
- Replace `<DIGITAL_OCEAN_IP>`, `<RUNPOD_IP>`, `<TUNNEL_ID>`, and `yourdomain.com` with actual values
- Update device-specific paths for mobile/tablet setups
- Customize user names and ports based on your infrastructure
- Add specific network device models and their SSH quirks
- Document any service-specific authentication requirements

**Last Updated**: 2025-11-19
**Next Review Date**: 2025-12-19

---

## Additional Security Resources

### Security Checklists
- [CIS SSH Hardening Guidelines](https://www.cisecurity.org/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [OWASP Security Testing Guide](https://owasp.org/)

### Online Testing Tools
- DNS Leak Test: https://dnsleaktest.com/
- IP Leak Test: https://ipleak.net/
- Browser Leak Test: https://browserleaks.com/
- WebRTC Leak Test: https://www.expressvpn.com/webrtc-leak-test
- Cloudflare Security Check: https://www.cloudflare.com/ssl/encrypted-sni/

### Security Monitoring Services
- Shodan: Monitor exposed services - https://www.shodan.io/
- Have I Been Pwned: Check for compromised credentials - https://haveibeenpwned.com/
- URLScan: Check for malicious domains - https://urlscan.io/

### Recommended Reading
- "SSH Mastery" by Michael W. Lucas
- "Practical Cryptography" by Niels Ferguson and Bruce Schneier
- OpenSSH Security Advisories: https://www.openssh.com/security.html
- Cloudflare Zero Trust Docs: https://developers.cloudflare.com/cloudflare-one/
