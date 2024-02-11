#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail
# Remove empty snapshots
find "/var/stacks/data/ledger" -name "snapshot-*" -size 0 -print -exec rm {} \; || true
export RUST_LOG=error
export RUST_BACKTRACE=full
export STACKS_METRICS_CONFIG=__STACKS_METRICS_CONFIG__

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
export EC2_INTERNAL_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)

/home/stacks/bin/stacks-validator \
--ledger /var/stacks/data/ledger \
--identity /home/stacks/config/validator-keypair.json \
--vote-account /home/stacks/config/vote-account-keypair.json \
__KNOWN_VALIDATORS__ \
--expected-genesis-hash __EXPECTED_GENESIS_HASH__ \
__ENTRY_POINTS__ \
--rpc-port 8899 \
--private-rpc \
--rpc-bind-address $EC2_INTERNAL_IP \
--wal-recovery-mode skip_any_corrupted_record \
--init-complete-file /var/stacks/data/init-completed \
--limit-ledger-size \
--accounts /var/stacks/accounts \
--log -
