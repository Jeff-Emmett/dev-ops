---
id: TASK-30
title: 'TEE Integration — Phase 1: EncryptID Guardian Recovery Enclave'
status: To Do
assignee: []
created_date: '2026-02-15 22:31'
labels:
  - security
  - TEE
  - encryptid
  - r*stack
dependencies: []
references:
  - dev-ops/tee-report.pdf
  - dev-ops/tee-report.html
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Integrate Trusted Execution Environments into the r*Stack, starting with EncryptID's guardian recovery flow. The goal is to run Shamir secret sharing reconstruction inside a TEE enclave so the reconstructed master key is never visible to the server operator.

Top contender platforms: Phala Network (JS/TS SDK, on-chain attestation) and Marlin Oyster (Docker deploy, HTTP gateway, EVM-native attestation).

Full analysis in dev-ops/tee-report.pdf covering all 5 platforms evaluated and a 4-phase roadmap across EncryptID, rVote, rSpace, rFiles, and rWallet.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Evaluate Phala Network and Marlin Oyster SDKs hands-on
- [ ] #2 Prototype guardian recovery key reconstruction inside a TEE enclave
- [ ] #3 Verify remote attestation flow works end-to-end
- [ ] #4 Seal SSO JWT signing key inside TEE
- [ ] #5 Document integration pattern for remaining r*Stack apps (Phase 2-4)
<!-- AC:END -->
