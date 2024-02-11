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
__KNOWN_VALIDATORS__ \
--expected-genesis-hash __EXPECTED_GENESIS_HASH__ \
__ENTRY_POINTS__ \
--no-voting \
--full-rpc-api \
--rpc-port 8899 \
--gossip-port 8800 \
--dynamic-port-range 8800-8814 \
--private-rpc \
--rpc-bind-address $EC2_INTERNAL_IP \
--wal-recovery-mode skip_any_corrupted_record \
--enable-rpc-transaction-history \
--enable-cpi-and-log-storage \
--init-complete-file /var/stacks/data/init-completed \
--require-tower \
--no-wait-for-vote-to-start-leader \
--limit-ledger-size \
--accounts /var/stacks/accounts \
--account-index spl-token-owner \
--account-index program-id \
--account-index spl-token-mint \
--account-index-exclude-key kinXdEcpDQeHPEuQnqmUgtYykqKGVFq6CeVX5iAHJq6 \
--account-index-exclude-key TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA \
--log -
