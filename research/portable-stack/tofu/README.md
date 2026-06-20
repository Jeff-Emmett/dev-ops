# Portable rSpace self-hosting kit (TASK-415.10)

One `tofu apply` to stand up a fresh, federated rSpace node's *structure*: DNS,
spaces, members, and rApp config — across substrates. A new operator clones this,
fills `terraform.tfvars`, and applies.

This kit manages **structure**, not containers. Bring the container up first
(compose, per the rspace-online deploy), then apply this to seed the holarchy.

## Use

```sh
cp terraform.tfvars.example terraform.tfvars   # fill in endpoint, keys, zone
tofu init
tofu plan        # review what will be created
tofu apply
```

State is encrypted at rest (see `backend.tf`) with a passphrase sourced from
Infisical — state stays Mercury-blind and on your node. Never commit `*.tfstate`.

## Drift as audit

`drift-check.sh` runs `tofu plan -detailed-exitcode` on a cron. A non-empty diff
means the live holarchy structure was mutated out-of-band — an audit/security
signal (reinforces the membrane fail-closed keystone, TASK-407). Wire its exit
code 2 into your existing alerting.
