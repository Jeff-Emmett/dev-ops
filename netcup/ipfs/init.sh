#!/bin/sh
# Kubo init script — runs on first start via /container-init.d/
# Configures storage limits, CORS, and garbage collection

set -e

# Storage limits
ipfs config Datastore.StorageMax "50GB"
ipfs config --json Datastore.StorageGCWatermark 90
ipfs config Datastore.GCPeriod "1h"

# Gateway CORS — allow rNotes/rSpace origins
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["https://rnotes.online","https://*.rnotes.online","https://rspace.online","https://*.rspace.online","https://*.jeffemmett.com","http://localhost:3000"]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["GET","POST","PUT","OPTIONS"]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Headers '["Authorization","Content-Type","X-Requested-With"]'

ipfs config --json Gateway.HTTPHeaders.Access-Control-Allow-Origin '["*"]'
ipfs config --json Gateway.HTTPHeaders.Access-Control-Allow-Methods '["GET","HEAD","OPTIONS"]'

# Listen on all interfaces (needed inside Docker)
ipfs config Addresses.API "/ip4/0.0.0.0/tcp/5001"
ipfs config Addresses.Gateway "/ip4/0.0.0.0/tcp/8080"

# Enable public DHT for network redundancy
ipfs config Routing.Type "dht"

echo "[init] Kubo configured: 50GB storage, CORS enabled, DHT routing"
