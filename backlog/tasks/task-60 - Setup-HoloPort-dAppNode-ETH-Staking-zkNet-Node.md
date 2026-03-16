---
id: TASK-60
title: 'Setup HoloPort, dAppNode ETH Staking & zkNet Node'
status: To Do
assignee: []
created_date: '2026-03-10 21:43'
due_date: '2026-04-11'
labels:
  - ethereum
  - staking
  - holoport
  - dappnode
  - zknet
  - infrastructure
dependencies: []
references:
  - 'https://docs.dappnode.io/docs/user/staking/ethereum/solo/mainnet/'
  - 'https://quickstart.holo.host/'
  - 'https://launchpad.ethereum.org'
  - 'https://wagyu.gg'
  - 'https://beaconcha.in'
  - 'https://docs.ethstaker.org'
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up HoloPort for Holochain hosting, dAppNode for Ethereum solo staking (including migrating ETH from Ledger wallet to deposit contract), and zkNet node on home router.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 HoloPort registered and connected to Holo network with Host Console accessible
- [ ] #2 dAppNode OS installed with execution client (Geth/Nethermind/Besu) and consensus client (Lighthouse/Prysm/Teku/Nimbus) fully synced
- [ ] #3 Validator keys generated air-gapped with Wagyu Key Gen and imported to Web3Signer
- [ ] #4 Withdrawal address set to Ledger-controlled ETH address
- [ ] #5 32 ETH deposited to official deposit contract via Ethereum Launchpad, signed on Ledger
- [ ] #6 Validator activated and attesting on beacon chain
- [ ] #7 All seed phrases, mnemonics, and revocation keys securely backed up offline
- [ ] #8 Monitoring and alerts configured for validator uptime
- [ ] #9 zkNet node installed and running on home router
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## PART 1: HoloPort Setup (Holochain Hosting)

### Prerequisites
- HoloPort device powered on and internet-connected
- Registration code from https://register.holo.host/holo
- Included USB drive
- Separate storage device for seed file backup

### Steps
1. Obtain registration code at https://register.holo.host/holo
2. Create strong passphrase — WARNING: cryptographic keys are NOT replaceable
3. Generate & backup master seed file + revocation key to SEPARATE device
4. Create Host Console password for remote management
5. Flash HolOS ISO to USB if needed (~60 sec install, HolOS v0.0.7+)
6. Download config file → transfer to USB → insert when LED solid blue
7. Wait for auto-registration with DNS/VPN services
8. Verify via email link, confirm in browser, access Host Console

### Notes
- HoloPort+ SSD data volume auto-installs
- Edge Nodes extend hosting to other hardware
- Moss integration enables private sovereign networks

---

## PART 2: dAppNode Ethereum Solo Staking

### Hardware Requirements
- CPU: Modern multi-core (Intel NUC or equivalent)
- RAM: 16 GB min, 32 GB recommended
- Storage: 4 TB NVMe SSD min (6-8 TB recommended, blockchain >3 TB)
- Network: Stable broadband, wired Ethernet preferred
- Power: ~20-25W, UPS recommended
- Cost: 32 ETH per validator + hardware + electricity

### Phase A: dAppNode OS Installation
1. Flash dAppNode ISO to USB, boot and install
2. Access admin panel via local network

### Phase B: Client Installation (via Stakers UI)
3. Install Execution Client (one of: Geth, Nethermind, Besu, Erigon)
   - NOTE: Erigon requires 3TB+ storage
4. Install Consensus Client (one of: Lighthouse, Prysm, Teku, Nimbus, Lodestar)
5. Enable Checkpoint Sync for fast initial sync
6. Optional: Enable MEV Boost for maximized rewards

### Phase C: Validator Key Generation
7. Download Wagyu Key Gen from official source
8. DISCONNECT FROM INTERNET → generate keys air-gapped
   - Choose validator count (1 per 32 ETH)
   - Set strong keystore password
   - Set withdrawal address → USE LEDGER ETH ADDRESS (cannot change after deposit!)
   - Save mnemonic phrase securely
9. Backup: mnemonic (paper in safe), keystores (encrypted), deposit_data JSON, exit keys
10. Import keystores to Web3Signer via dAppNode UI

### Phase D: Fund Validator (Ledger → Deposit Contract)
11. Update Ledger firmware + Ethereum app
12. Connect Ledger to MetaMask, verify 32 ETH + gas available
13. Go to https://launchpad.ethereum.org
14. Upload deposit_data JSON
15. Connect MetaMask w/ Ledger → TRIPLE-CHECK deposit contract address on Ledger display
16. Sign and confirm 32 ETH deposit on Ledger device
17. Monitor activation on beaconcha.in (hours to days)

---

## PART 3: Ledger Fund Migration Security Checklist
- Ledger firmware up to date
- Ethereum app latest version
- Withdrawal address is Ledger-controlled
- Test with small transaction first if new address
- Deposit contract verified against official sources
- Transaction signed/verified on Ledger physical display
- Validator mnemonic stored separately from Ledger seed
- Never share validator mnemonic or Ledger seed

---

## PART 4: zkNet Node on Home Router

**Status: Plan TBD — needs further documentation review**

### Placeholder Steps
1. Obtain zkNet node hardware/software
2. Review official zkNet documentation for router compatibility
3. Install and configure on home router
4. Verify node is connected to zkNet network
5. Monitor node status and rewards

> NOTE: Detailed plan to be built once official zkNet documentation is reviewed.

---

## Ongoing Maintenance
- Monitor validator uptime (penalties for downtime)
- Keep execution + consensus clients updated
- Monitor disk space (~1-2 GB/day growth)
- Set up alerts for missed attestations
- Slashing conditions: NO double voting, NO surround voting
- To exit: Web3Signer exit message (queue may take weeks)

## Alternative: Lido CSM (if <32 ETH)
- Lido Community Staking Module for staking with less than 32 ETH
- dAppNode has native CSM integration
<!-- SECTION:PLAN:END -->
