#!/bin/bash

INIT_COMPLETED_FILE=/var/stacks/data/init-completed

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq .region -r)
EC2_INTERNAL_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S%:z")

if [ -f "$INIT_COMPLETED_FILE" ]; then
    STACKS_BLOCK_HEIGHT=$(curl -s -X POST -H "Content-Type: application/json" -d ' {"jsonrpc":"2.0","id":1,"method":"getBlockHeight"}' http://$EC2_INTERNAL_IP:8899 | jq .result)
    STACKS_SLOTS_BEHIND_DATA=$(curl -s -X POST -H "Content-Type: application/json" -d ' {"jsonrpc":"2.0","id":1, "method":"getHealth"}' http://$EC2_INTERNAL_IP:8899 | jq .error.data)
    STACKS_SLOTS_BEHIND=$(echo $STACKS_SLOTS_BEHIND_DATA | jq .numSlotsBehind -r)

    if [ $STACKS_SLOTS_BEHIND == "null" ]
    then
        STACKS_SLOTS_BEHIND=0
    fi

    if [ -z "$STACKS_SLOTS_BEHIND" ]
    then
        STACKS_SLOTS_BEHIND=0
    fi

    if [ -z "$STACKS_BLOCK_HEIGHT" ]
    then
        STACKS_BLOCK_HEIGHT=0
    fi

    aws cloudwatch put-metric-data --metric-name stacks_block_height --namespace CWAgent --value $STACKS_BLOCK_HEIGHT --timestamp $TIMESTAMP --dimensions  InstanceId=$INSTANCE_ID --region $REGION
    aws cloudwatch put-metric-data --metric-name stacks_slots_behind --namespace CWAgent --value $STACKS_SLOTS_BEHIND --timestamp $TIMESTAMP --dimensions  InstanceId=$INSTANCE_ID --region $REGION
else
    aws cloudwatch put-metric-data --metric-name stacks_block_height --namespace CWAgent --value 0 --timestamp $TIMESTAMP --dimensions  InstanceId=$INSTANCE_ID --region $REGION
fi
