# Crypto ↔ Fiat Bridge Research for MycoFi

**Date:** 2026-02-04
**Status:** Initial Research / Ongoing
**Context:** Evaluating financial infrastructure for MycoFi's economic layer — how to bridge between on-chain (crypto/stablecoin) and traditional fiat (bank accounts, cards) for the "last mile" of value transfer.

---

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Platform Comparison Matrix](#platform-comparison-matrix)
3. [Moov.io — Fiat Infrastructure](#moovio--fiat-infrastructure)
4. [Bridge.xyz (Stripe) — Stablecoin Orchestration](#bridgexyz-stripe--stablecoin-orchestration)
5. [Sulfur.fi — Self-Custodial Off-Ramp](#sulfurfi--self-custodial-off-ramp)
6. [Other Platforms (Revolut, Wise, Robinhood)](#other-platforms)
7. [Crypto↔Fiat Bridge Landscape](#cryptofiat-bridge-landscape)
8. [Open Source & Self-Hosted Alternatives](#open-source--self-hosted-alternatives)
9. [Bridge.xyz Deep Dive — Fees & Stripe Risks](#bridgexyz-deep-dive--fees--stripe-risks)
10. [Recommended Architecture for MycoFi](#recommended-architecture-for-mycofi)
11. [Implementation Phases](#implementation-phases)
12. [Sources](#sources)

---

## Problem Statement

MycoFi (Mycelial Finance) explores economic systems inspired by fungal networks — decentralized, regenerative, mutualistic. The project currently has **no financial infrastructure** (it's an educational site + AI zine generator at `mycofi.earth`). To realize its economic vision, it needs:

1. **On-chain economics** — tokens, governance, programmable value flows
2. **Fiat bridge** — the "last mile" converting between crypto and bank accounts
3. **Spending** — letting ecosystem participants use value in the physical world

The core UX goal: a user never thinks about whether they're in crypto or fiat. "Send" and "receive" just work.

### The Last Mile Problem

Today, moving between crypto and fiat requires:
- Leave your app → go to exchange → KYC again → sell crypto → withdraw → wait 1-5 days
- Or: find an off-ramp → paste wallet address → hope it works → wait

Both break the single-ecosystem feel. The bridge layer should be invisible.

---

## Platform Comparison Matrix

| Dimension | **Moov** | **Bridge (Stripe)** | **Sulfur.fi** | **Revolut** | **Wise** | **Cybrid** |
|-----------|----------|---------------------|---------------|-------------|----------|------------|
| **What it is** | Fiat payment infrastructure API | Stablecoin orchestration (Stripe-owned) | Crypto-to-fiat off-ramp | Consumer/business neobank | Cross-border transfer platform | Fiat↔crypto orchestration |
| **Target user** | Developers building fintech | Developers building on stablecoins | Crypto-native end users | End users & businesses | End users & businesses | Developers building payments |
| **API-first?** | Yes (core product) | Yes (core product) | No (user-facing) | Partially (Business API) | Partially (Platform API) | Yes (core product) |
| **Embeddable?** | Yes (Drops, SDKs) | Yes (APIs, SDKs) | No | Partially (Merchant API) | Partially (for licensed partners) | Yes (APIs, SDKs) |
| **Crypto support** | No (fiat only) | Yes (stablecoin orchestration) | Yes (core product) | Yes (buy/sell/hold) | Limited | Yes (stablecoin + fiat) |
| **Card issuing** | Yes (virtual) | Yes (Visa, LatAm+US) | No | Yes (physical + virtual) | Yes (physical + virtual) | No |
| **Fiat rails** | ACH, RTP, FedNow (2026), Visa Direct | Via Stripe | SEPA, ACH, Fedwire | Via their accounts | Local rails in 40+ currencies | ACH, RTP, FedNow, EFT, Interac |
| **Self-custodial** | N/A | No (custodial) | Yes | No | No | No |
| **White-label** | Yes | Yes | No | No | Partially | Yes |
| **Geographic focus** | US-centric | LatAm, US, EU/APAC 2026 | EU-first, expanding | Global (EU/UK strongest) | Global (160+ countries) | North America focus |
| **Open source** | No | No | No | No | No | No |

### Key Distinction: Infrastructure vs. Application

- **Infrastructure** (build your own product on top): Moov, Bridge, Cybrid
- **Applications** (users interact with them directly): Revolut, Wise, Sulfur.fi
- For MycoFi as a platform, infrastructure is what matters.

---

## Moov.io — Fiat Infrastructure

**Website:** https://moov.io
**Docs:** https://docs.moov.io

Moov is purely fiat rails — no crypto awareness. But it offers deep control over traditional money movement.

### Relevant Capabilities

| Capability | MycoFi Use Case |
|-----------|-----------------|
| **Wallets** | Fiat holding accounts per user — USD balances within ecosystem |
| **ACH debit/credit** | Pull money from user's bank; push money back out |
| **RTP instant payments** | Near-instant deposits/withdrawals 24/7 |
| **Card issuing** | Virtual cards funded from MycoFi wallet — spend anywhere |
| **Payment links** | Accept fiat for services, zines, merchandise on `shop.mycofi.earth` |
| **KYC/onboarding** | Compliance-ready identity verification (~98% auto-approval) |
| **Transfer groups** | Chain/split payments (e.g., creator + platform + community treasury) |
| **Webhooks** | Event-driven — trigger on-chain actions when fiat arrives |

### What Moov Can't Do
- No crypto/blockchain awareness
- Can't hold stablecoins
- Can't interact with smart contracts
- Can't convert between crypto and fiat

### Developer Experience
- REST API with SDKs in Python, TypeScript, Go
- Sandbox with time-simulation for testing
- Kafka-backed webhooks
- Embeddable UI components (Drops)

---

## Bridge.xyz (Stripe) — Stablecoin Orchestration

**Website:** https://www.bridge.xyz
**Docs:** https://apidocs.bridge.xyz
**Acquired by Stripe for $1.1B (closed February 2025)**

### Products

1. **Orchestration** — Move, store, accept stablecoins via single API. Convert between USD, USDC, USDT, PYUSD.
2. **Open Issuance** — Issue your own stablecoin backed by US Treasuries (BlackRock/Fidelity reserves). Earn yield on reserves.
3. **Cards** — Visa card issuing linked to stablecoin balances. Live in Argentina, Colombia, Ecuador, Mexico, Peru, Chile. US + EU/APAC coming 2026.
4. **Wallets** — Digital asset wallets with Bridge handling security and gas.
5. **Cross-Border Payments** — Real-time international transfers 24/7.

### Fee Structure

| Fee Type | Amount | Notes |
|----------|--------|-------|
| Currency conversion spread | Up to **1%** of fiat value | Variable per transaction |
| Gas fees | Variable | Passed through at cost |
| Platform fee (Bridge's cut) | **Not publicly disclosed** | Must negotiate with sales |
| Card issuing fees | Not disclosed | Unknown |
| Issuance fees | Not disclosed | Likely revenue-share on reserve yield |
| Transaction minimum | $1 general, $20 for USDT | Deposits below minimum not returned |

**Developer fee system:** You can charge your own fees on top (fixed USD or percentage). Bridge collects them, pays out monthly on the 5th in USD.

### Stripe Dependency — Risks & Concerns

#### Philosophical Misalignment with MycoFi

MycoFi values: decentralization, mutualism, anti-fragility, community governance.
Stripe/Bridge trajectory: centralized control of the full stablecoin stack.

- **Stripe Tempo** — proprietary blockchain with "select group of validators" (centralized by design)
- **Open Issuance** sounds open, but reserves are managed by BlackRock/Fidelity through Bridge. You don't control the reserves or mint/burn. Bridge does.
- **Privy** (Stripe's wallet acquisition) explicitly argues against decentralization as a design goal
- A "$MYCO stablecoin" via Bridge would be **Stripe's stablecoin with MycoFi's label**

#### Vendor Lock-in

- No published pricing = fees can increase after you've built on their APIs
- Monthly settlement = Bridge holds your revenue for up to 30 days
- If Bridge decides MycoFi doesn't fit their compliance model, they can terminate access
- Stripe abandoned Bitcoin in 2018 after years of support — they're pragmatic, not principled about crypto

#### Compliance as Double-Edged Sword

- Bridge decides who can use your platform (not you)
- Users in countries Bridge doesn't serve are excluded
- Unbanked populations who can't pass KYC are locked out — arguably the people regenerative economics should serve most

#### Regulatory Risk

Bridge has faced [sanctions and fraud compliance issues](https://www.webpronews.com/bridges-stablecoin-ambitions-face-regulatory-headwinds-as-sanctions-and-scam-concerns-mount/). If regulators crack down, platforms built on Bridge go down with them.

#### Strategic Capture

Stripe is building: wallet (Privy) → issuance (Bridge) → orchestration (Bridge) → settlement (Tempo) → spending (cards). Each layer you adopt increases dependency. Classic platform strategy — easy to adopt, hard to leave.

---

## Sulfur.fi — Self-Custodial Off-Ramp

**Website:** https://sulfur.fi
**Built by:** The team behind Colony (DAO infrastructure)

### What It Does
- Crypto-to-fiat off-ramp: "Any token, any chain, in your bank, in minutes"
- Self-custodial model — Sulfur never holds user funds
- Supports IBAN, ACH, Fedwire
- SEPA Instant for EUR

### Alignment with MycoFi
- **Self-custodial** — philosophically aligned with DeFi/decentralization values
- **Colony team** — deep DAO/decentralized organization experience
- **Non-custodial** — reduces trust surface

### Limitations
- User-facing product, not embeddable API infrastructure
- Users leave your platform to use it
- Limited scope (off-ramp only, no on-ramp, no orchestration)
- Feature set still expanding ("coming soon" on several items)

---

## Other Platforms

### Revolut
- Consumer/business neobank with Business API and Merchant API
- Good for accepting payments (like Stripe) and managing your own treasury
- **Not suitable as platform infrastructure** — users are Revolut's customers, not yours
- Useful for MycoFi's own business banking, not for building economic layer

### Wise
- Best for cross-border transfers at real exchange rates (40+ currencies, 160+ countries)
- Wise Platform allows licensed partners to embed multi-currency accounts
- **Requires financial licensing** to use as embedded infrastructure
- Strongest geographic coverage of any option

### Robinhood
- Retail brokerage — irrelevant for MycoFi's use case
- No meaningful developer APIs
- Custodial crypto, non-programmable

---

## Crypto↔Fiat Bridge Landscape

The broader market for crypto↔fiat APIs is growing rapidly. 580 million people now own crypto (2025), stablecoin volume exceeded $20 trillion annually, and 41% of users cite fast fiat withdrawals as their biggest unmet need.

### Key Players

| Platform | Focus | Notable Feature |
|----------|-------|----------------|
| **Transak** | On-ramp aggregator | 136 cryptos, 64 countries, card/bank support |
| **Cybrid** | Single API fiat↔crypto | ACH/RTP/FedNow + stablecoin conversion, SOC 2, built-in compliance |
| **Striga** | Licensed VASP (Estonia) | First MiCA-like licensed VASP, strong compliance culture |
| **Request Technologies** | Off-ramp API | 40+ fiat currencies, keep users on your platform |
| **Onramper** | Aggregator (30+ on-ramps) | Routing engine weighs 70+ factors for optimal path |
| **Cross River** | Enterprise stablecoin infrastructure | Unified stablecoin+fiat, compliant infrastructure |
| **Fipto** | EU stablecoin payments | First dual-licensed (MiCA payment + CASP) in Europe |
| **BVNK (Layer1)** | Enterprise orchestration | Self-managed option, bring your own licenses/custodian |

### Regulatory Context (2025-2026)
- **US:** GENIUS Act signed into law — first federal stablecoin framework
- **EU:** MiCA setting standards for crypto-fiat conversions
- **Trend:** Clearer frameworks accelerating institutional adoption

---

## Open Source & Self-Hosted Alternatives

No single open-source project fully replicates Bridge's end-to-end stablecoin orchestration. But composing several tools gets close:

| Solution | Open Source | Self-Hosted | Stablecoin Focus | Fiat Bridge |
|----------|-----------|-------------|-----------------|-------------|
| **PayRam** | ✅ | ✅ | ✅ (USDT/USDC, smart contracts) | ❌ |
| **Hub20** | ✅ | ✅ | ✅ (ERC20/DAI, Raiden) | ❌ |
| **ZeroPay** | ✅ | ✅ | ✅ (lightweight gateway) | ❌ |
| **BTCPay Server** | ✅ | ✅ | Limited (BTC focus, plugins) | ❌ |
| **SHKeeper** | ✅ | ✅ | ✅ (multi-crypto, no fees) | ❌ |
| **Solana Pay** | ✅ (SDK) | ✅ | ✅ (USDC on Solana) | ❌ |
| **BVNK Layer1** | ❌ | ✅ (self-managed) | ✅ | ✅ (bring own licenses) |
| **Cybrid** | ❌ | ✅ (self-managed) | ✅ | ✅ |

**Key gap:** Open-source tools handle crypto payment acceptance well, but none provide the fiat side (ACH, bank transfers, card issuing). The fiat bridge always requires a licensed intermediary.

### Notable Open-Source Projects

- **[PayRam](https://github.com/PayRam)** — Closest to self-hosted stablecoin orchestration. Smart contract-based fund sweeping, no-server-keys architecture, multi-chain (BTC, EVM, TRON, TON). Supports x402 protocol.
- **[BTCPay Server](https://btcpayserver.org/)** — Most mature self-hosted payment gateway. Bitcoin + Lightning focus but extensible via plugins.
- **[Hub20](https://github.com/mushroomlabs/hub20)** — Ethereum equivalent of BTCPay. Raiden integration for near-free transfers.
- **[ZeroPay](https://github.com/zpaynow/ZeroPay)** — Lightweight, Docker-deployable, REST API + webhooks.

---

## Bridge.xyz Deep Dive — Fees & Stripe Risks

### Fee Comparison Across Platforms

| Platform | Conversion Fee | Other Costs | Transparency |
|----------|---------------|-------------|-------------|
| **Bridge (Stripe)** | Up to 1% spread | Gas + undisclosed platform fee | Low (sales negotiation) |
| **Wise** | 0.35-1.5% | Transparent per-route pricing | High |
| **Coinbase** | ~1.5% | Network fees | Medium |
| **Sulfur.fi** | Not published | Gas fees | Low |
| **Cybrid** | Not published | Compliance + gas | Low (sales negotiation) |
| **Traditional wire** | $15-45 flat | Correspondent bank fees | Medium |
| **SEPA** | Free or <€1 | None typically | High |

### Trust Surface Comparison

| Layer | Bridge Approach | Self-Sovereign Approach |
|-------|----------------|------------------------|
| **Token** | Bridge issues it, controls reserves | You issue ERC-20, community governs |
| **Wallet** | Privy (Stripe-owned) | Self-custodial (MetaMask, Safe) |
| **Treasury** | Bridge holds USD | Gnosis Safe multi-sig, on-chain |
| **Payments** | Bridge orchestration | PayRam / BTCPay (self-hosted) |
| **Off-ramp** | Bridge (locked in) | Sulfur / Cybrid / multiple options |
| **Settlement** | Tempo (Stripe chain) | Ethereum / L2 of your choice |
| **Compliance** | Bridge decides who participates | Progressive — serve who you choose |
| **Kill switch** | Stripe has one | Nobody does |

---

## Recommended Architecture for MycoFi

### Guiding Principle: Minimize Trust Surface

MycoFi's economic layer should be as decentralized as its philosophy. Use self-hosted and open-source tools where possible. Treat fiat bridges as **replaceable plugins**, not foundational infrastructure.

### Architecture

```
MycoFi Economic Layer
│
├── Payment Acceptance (Self-Hosted on Netcup RS 8000)
│   ├── PayRam — self-hosted stablecoin gateway
│   │   ├── USDC/USDT/DAI acceptance
│   │   ├── Smart contract-based fund sweeping
│   │   ├── No intermediary holds your funds
│   │   └── Open source, auditable
│   │
│   └── BTCPay Server — for BTC + Lightning
│       ├── Most mature self-hosted payment infra
│       └── Plugin ecosystem for extensions
│
├── On-Chain Economics (Decentralized)
│   ├── Gnosis Safe / Squads — multi-sig treasury
│   ├── $MYCO token — community-governed ERC-20
│   │   (NOT a Bridge-issued stablecoin — actually yours)
│   ├── Superfluid / Sablier — streaming payments
│   │   (continuous resource flow, like mycelium)
│   └── Snapshot / Tally — governance
│
├── Fiat Off-Ramp (Modular, Swappable)
│   ├── Primary: Sulfur.fi (self-custodial, user-initiated, aligned values)
│   ├── Alternative: Cybrid (API, self-managed deployment available)
│   └── Fallback: Bridge (use ONLY for orchestration, not issuance/wallets)
│       └── Abstract behind own API so provider is swappable
│
├── Fiat On-Ramp (Modular)
│   ├── Transak or Onramper (aggregator — routes to best provider)
│   └── Or: Cybrid (single API for both directions)
│
└── Card Spending (Phase 4, if needed)
    ├── Gnosis Pay — crypto-native Visa card (decentralized)
    ├── Holyheld — DeFi-connected spending card
    └── Bridge cards as pragmatic last resort
```

### Why Not Bridge as the Foundation?

1. **Philosophical**: MycoFi is about decentralization; Bridge/Stripe is centralizing the stablecoin stack
2. **Strategic**: Stripe abandoned crypto before and will pivot again if economics change
3. **Sovereignty**: Bridge-issued stablecoins are Stripe's stablecoins with your label
4. **Access**: Bridge's compliance model excludes unbanked populations MycoFi should serve
5. **Lock-in**: Undisclosed pricing, monthly settlement holds, termination risk

### Where Bridge Could Be Useful (Carefully)

- As one of multiple off-ramp options (not the only one)
- For Visa card issuing if self-sovereign options (Gnosis Pay) don't meet needs
- Only through an abstraction layer so it can be swapped out

---

## Implementation Phases

### Phase 1 — Accept Crypto Payments (Low Effort, No Lock-in)
- Deploy PayRam or BTCPay Server on Netcup RS 8000 (Docker)
- Accept USDC/USDT/DAI on `shop.mycofi.earth` for zines, books, merch
- Treasury goes to Gnosis Safe multi-sig
- Zero vendor dependency. Fully self-hosted.

### Phase 2 — Build Token Economics (Medium Effort, On-Chain)
- Design $MYCO as community-governed token (ERC-20)
- Streaming payments via Superfluid for continuous resource redistribution
- Governance via Snapshot or on-chain voting
- This is where "mycelial economics" lives — programmable, composable

### Phase 3 — Fiat Bridge (When Needed, Stay Modular)
- Offer Sulfur.fi as primary off-ramp (self-custodial, aligned values)
- Add Cybrid or Bridge as additional options (not the only option)
- Abstract fiat bridge behind own API for provider swappability
- The off-ramp is a plugin, not the foundation

### Phase 4 — Spending Cards (Optional, When Volume Justifies)
- Evaluate Gnosis Pay, Holyheld, or Bridge cards
- Only if community members need physical-world spending
- Nice-to-have, not prerequisite

---

## Sources

### Platforms
- [Moov.io — Platform Features](https://moov.io/platform/features/)
- [Moov Documentation](https://docs.moov.io/)
- [Bridge.xyz](https://www.bridge.xyz/)
- [Bridge Developer Fees](https://apidocs.bridge.xyz/docs/developer-fees)
- [Bridge Fee Disclosure](https://www.bridge.xyz/legal/fee-disclosure-statement/overview)
- [Bridge Open Issuance](https://stripe.com/blog/introducing-open-issuance-from-bridge)
- [Bridge + Visa Card Issuing](https://stripe.com/newsroom/news/bridge-partners-with-visa)
- [Sulfur.fi](https://sulfur.fi/)
- [Cybrid Fiat-Crypto Platform](https://www.cybrid.xyz/en/fiat-crypto-on-off-ramp)
- [Revolut Business API](https://developer.revolut.com/docs/business/business-api)
- [Wise Platform API](https://docs.wise.com/)
- [Transak](https://transak.com)
- [BVNK](https://bvnk.com)
- [Fipto](https://www.fipto.com/)
- [Squads API](https://squads.xyz/blog/stablecoin-banking-infrastructure-for-digital-platforms)

### Open Source
- [PayRam (GitHub)](https://github.com/PayRam)
- [BTCPay Server](https://btcpayserver.org/)
- [Hub20 (GitHub)](https://github.com/mushroomlabs/hub20)
- [ZeroPay (GitHub)](https://github.com/zpaynow/ZeroPay)
- [SHKeeper (GitHub)](https://github.com/vsys-host/shkeeper.io)

### Analysis & Context
- [a16z: Stripe/Bridge Acquisition Analysis](https://a16z.com/newsletter/what-stripes-acquisition-of-bridge-means-for-fintech-and-stablecoins-april-2025-fintech-newsletter/)
- [Bridge Compliance Concerns (WebProNews)](https://www.webpronews.com/bridges-stablecoin-ambitions-face-regulatory-headwinds-as-sanctions-and-scam-concerns-mount/)
- [Stripe Tempo & Privy Strategy (The Defiant)](https://thedefiant.io/news/tradfi-and-fintech/henri-stern-privy-ceo-interview)
- [Stripe Stablecoin Announcements](https://stripe.com/newsroom/news/tour-newyork-2025)
- [BVNK vs Bridge vs Zero Hash (Medium)](https://samboboev.medium.com/deep-dive-bvnk-vs-bridge-vs-zero-hash-stablecoin-payment-infrastructure-1235fd4e6d73)
- [Mastercard Crypto On/Off Ramps](https://www.mastercard.com/global/en/news-and-trends/stories/2025/what-are-crypto-on-ramps-crypto-off-ramps.html)
- [Cross River Stablecoin Infrastructure](https://www.crossriver.com/newsroom/cross-river-launches-stablecoin-payments-with-infrastructure-to-power-the-future-of-onchain-finance)
- [GENIUS Act & Stablecoin Regulation](https://www.pymnts.com/blockchain/2025/stablecoin-orchestration-becomes-fintech-battleground-blockchain-payments-surge)
