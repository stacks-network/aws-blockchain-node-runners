#!/bin/bash
set +e

# General system environment variables
DATA_VOLUME_PATH=/var/lib/stacks
ASSETS_VOLUME_PATH=/var/stacks

CLOUD_ASSETS_DOWNLOAD_PATH=/tmp/assets.zip
CLOUD_ASSETS_PATH=/var/tmp/assets

# Setup environment variables provided by from CDK template on local machine.
echo "AWS_REGION=${_AWS_REGION_}" >> /etc/environment
echo "CLOUD_ASSETS_S3_PATH=${_ASSETS_S3_PATH_}" >> /etc/environment
echo "STACK_NAME=${_STACK_NAME_}" >> /etc/environment
echo "STACK_ID=${_STACK_ID_}" >> /etc/environment
echo "RESOURCE_ID=${_NODE_CF_LOGICAL_ID_}" >> /etc/environment
echo "STACKS_VERSION=${_STACKS_VERSION_}" >> /etc/environment
echo "STACKS_NODE_CONFIGURATION=${_STACKS_NODE_CONFIGURATION_}" >> /etc/environment
# Stacks network config
echo "STACKS_NETWORK=${_STACKS_NETWORK_}" >> /etc/environment
echo "STACKS_BOOTSTRAP_NODE=${_STACKS_BOOTSTRAP_NODE_}" >> /etc/environment
echo "STACKS_CHAINSTATE_ARCHIVE=${_STACKS_CHAINSTATE_ARCHIVE_}" >> /etc/environment
echo "STACKS_P2P_PORT=${_STACKS_P2P_PORT_}" >> /etc/environment
echo "STACKS_RPC_PORT=${_STACKS_RPC_PORT_}" >> /etc/environment
# Bitcoin network config
echo "BITCOIN_PEER_HOST=${_BITCOIN_PEER_HOST_}" >> /etc/environment
echo "BITCOIN_RPC_USERNAME=${_BITCOIN_RPC_USERNAME_}" >> /etc/environment
echo "BITCOIN_RPC_PASSWORD=${_BITCOIN_RPC_PASSWORD_}" >> /etc/environment
echo "BITCOIN_P2P_PORT=${_BITCOIN_P2P_PORT_}" >> /etc/environment
echo "BITCOIN_RPC_PORT=${_BITCOIN_RPC_PORT_}" >> /etc/environment
# Cloud resource config
echo "STACKS_MINER_SECRET_ARN=${_STACKS_SIGNER_SECRET_ARN_}" >> /etc/environment
echo "STACKS_SIGNER_SECRET_ARN=${_STACKS_MINER_SECRET_ARN_}" >> /etc/environment
echo "DATA_VOLUME_TYPE=${_DATA_VOLUME_TYPE_}" >> /etc/environment
echo "DATA_VOLUME_SIZE=${_DATA_VOLUME_SIZE_}" >> /etc/environment
echo "ASSETS_VOLUME_TYPE=${_ASSETS_VOLUME_TYPE_}" >> /etc/environment
echo "ASSETS_VOLUME_SIZE=${_ASSETS_VOLUME_SIZE_}" >> /etc/environment
echo "LIFECYCLE_HOOK_NAME=${_LIFECYCLE_HOOK_NAME_}" >> /etc/environment
echo "ASG_NAME=${_ASG_NAME_}" >> /etc/environment
echo "STACKS_CHAINSTATE_ARCHIVE=${_STACKS_CHAINSTATE_ARCHIVE_}" >> /etc/environment
# Place shared environment variables here.
echo "DATA_VOLUME_PATH=$DATA_VOLUME_PATH" >> /etc/environment
echo "ASSETS_VOLUME_PATH=$ASSETS_VOLUME_PATH" >> /etc/environment
echo "CLOUD_ASSETS_PATH=$CLOUD_ASSETS_PATH" >> /etc/environment

source /etc/environment

exec >> /node.sh.log
exec 2>> /node.sh.elog

# Show environment file in the logs.
cat /etc/environment

# Export environment variables so calls to `envsubst` inherit the evironment variables.
while read -r line; do export "$line"; done < /etc/environment

# Update packages.
sudo yum -y update
sudo yum -y install time

# Download cloud assets.
echo "Downloading assets zip file"
aws s3 cp $CLOUD_ASSETS_S3_PATH $CLOUD_ASSETS_DOWNLOAD_PATH --region $AWS_REGION
unzip -qo $CLOUD_ASSETS_DOWNLOAD_PATH -d $CLOUD_ASSETS_PATH

# TODO: Secret stuff here.
# if [[ $NODE_IDENTITY_SECRET_ARN == "none" ]]; then
#     echo "Create node identity"
#     sudo ./stacks-keygen new --no-passphrase -o /home/stacks/config/validator-keypair.json

  # sudo yum -y install npm
  # npm install @stacks/cli
  # sudo mkdir -p /etc/stacks
  # npx @stacks/cli make_keychain 2>/dev/null | jq > /etc/stacks/$STACKS_NODE_CONFIGURATION-keychain.json

# else
#     echo "Get node identity from AWS Secrets Manager"
#     sudo aws secretsmanager get-secret-value --secret-id $NODE_IDENTITY_SECRET_ARN --query SecretString --output text --region $AWS_REGION > ~/validator-keypair.json
#     sudo mv ~/validator-keypair.json /home/stacks/config/validator-keypair.json
# fi

sudo mkdir -p /etc/stacks/
CONFIG_DIR=$CLOUD_ASSETS_PATH/stacks/config/$STACKS_NODE_CONFIGURATION
sudo envsubst < $CONFIG_DIR/stacks.toml > /etc/stacks/stacks.toml

echo "Install CloudWatch Agent"
sudo yum -y install amazon-cloudwatch-agent

echo "Configure Cloudwatch Agent"
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/
cp $CONFIG_DIR/cw-agent.json /opt/aws/amazon-cloudwatch-agent/etc/custom-amazon-cloudwatch-agent.json
# TODO: Publish prometheus metrics as well.

echo "Starting CloudWatch Agent"
amazon-cloudwatch-agent-ctl -a fetch-config -c file:/opt/aws/amazon-cloudwatch-agent/etc/custom-amazon-cloudwatch-agent.json -m ec2 -s
systemctl status amazon-cloudwatch-agent

# Set up stacks user.
echo "Adding stacks user and group"
sudo groupadd -g 1002 stacks
sudo useradd -u 1002 -g 1002 -s /bin/bash stacks
sudo usermod -aG wheel stacks
sudo passwd -d stacks # No password.

# Configure CloudFormation helper scripts. -------------------------------------
sudo mkdir -p /etc/cfn/hooks.d/
if [[ "$STACK_ID" != "none" ]]; then
  echo "Configuring CloudFormation helper scripts"
  sudo envsubst < $CLOUD_ASSETS_PATH/cfn-hup/cfn-hup.conf > /etc/cfn/cfn-hup.conf
  sudo envsubst < $CLOUD_ASSETS_PATH/cfn-hup/cfn-auto-reloader.conf > /etc/cfn/cfn-auto-reloader.conf

  echo "Starting CloudFormation helper scripts as a service"
  cp $CLOUD_ASSETS_PATH/cfn-hup/cfn-hup.service  /etc/systemd/system/cfn-hup.service

  systemctl daemon-reload
  systemctl enable --now cfn-hup
  systemctl start cfn-hup.service

  cfn-signal --stack $STACK_NAME --resource $RESOURCE_ID --region $AWS_REGION
fi

# Start set up volumes -----------------------------------------------------------

echo "Waiting for volumes to be available"
sleep 60

sudo mkdir -p $DATA_VOLUME_PATH
sudo mkdir -p $ASSETS_VOLUME_PATH

if [[ "$DATA_VOLUME_TYPE" == "instance-store" ]]; then
  echo "Data volume type is instance store"

  sudo chmod +x $CLOUD_ASSETS_PATH/setup-instance-store-volumes.sh

  (crontab -l; echo "@reboot $CLOUD_ASSETS_PATH/setup-instance-store-volumes.sh > /tmp/setup-instance-store-volumes.log 2>&1") | crontab -
  crontab -l

  sudo /opt/setup-instance-store-volumes.sh

else
  echo "Data volume type is EBS"

  DATA_VOLUME_ID=/dev/$(lsblk -lnb | awk -v VOLUME_SIZE_BYTES="$DATA_VOLUME_SIZE" '{if ($4== VOLUME_SIZE_BYTES) {print $1}}')
  sudo mkfs -t xfs $DATA_VOLUME_ID
  sleep 10
  DATA_VOLUME_UUID=$(lsblk -fn -o UUID  $DATA_VOLUME_ID)
  DATA_VOLUME_FSTAB_CONF="UUID=$DATA_VOLUME_UUID $DATA_VOLUME_PATH xfs defaults 0 2"
  echo "DATA_VOLUME_ID="$DATA_VOLUME_ID
  echo "DATA_VOLUME_UUID="$DATA_VOLUME_UUID
  echo "DATA_VOLUME_FSTAB_CONF="$DATA_VOLUME_FSTAB_CONF
  echo $DATA_VOLUME_FSTAB_CONF | sudo tee -a /etc/fstab
  sudo mount -a
fi

if [[ "$ASSETS_VOLUME_TYPE" == "instance-store" ]]; then
  echo "Assets volume type is instance store"

  if [[ "$DATA_VOLUME_TYPE" != "instance-store" ]]; then
    cd /opt

    sudo chmod +x /opt/setup-instance-store-volumes.sh

    (crontab -l; echo "@reboot $CLOUD_ASSETS_PATH/setup-instance-store-volumes.sh > /tmp/setup-instance-store-volumes.log 2>&1") | crontab -
    crontab -l

    sudo /opt/setup-instance-store-volumes.sh

  else
    echo "Data and Assets volumes are instance stores and should be both configured by now"
  fi

else
  echo "Assets volume type is EBS"
  ASSETS_VOLUME_ID=/dev/$(lsblk -lnb | awk -v VOLUME_SIZE_BYTES="$ASSETS_VOLUME_SIZE" '{if ($4== VOLUME_SIZE_BYTES) {print $1}}')
  sudo mkfs -t xfs $ASSETS_VOLUME_ID
  sleep 10
  ASSETS_VOLUME_UUID=$(lsblk -fn -o UUID $ASSETS_VOLUME_ID)
  ASSETS_VOLUME_FSTAB_CONF="UUID=$ASSETS_VOLUME_UUID $ASSETS_VOLUME_PATH xfs defaults 0 2"
  echo "ASSETS_VOLUME_ID="$ASSETS_VOLUME_ID
  echo "ASSETS_VOLUME_UUID="$ASSETS_VOLUME_UUID
  echo "ASSETS_VOLUME_FSTAB_CONF="$ASSETS_VOLUME_FSTAB_CONF
  echo $ASSETS_VOLUME_FSTAB_CONF | sudo tee -a /etc/fstab

  sudo mount -a
fi

# Setup directories within the volume
sudo mkdir -p $ASSETS_VOLUME_PATH/log
sudo mkdir -p $ASSETS_VOLUME_PATH/src
sudo mkdir -p $ASSETS_VOLUME_PATH/bin

# Ensure proper ownership of the directories
sudo chown -R stacks:stacks $DATA_VOLUME_PATH
sudo chown -R stacks:stacks $ASSETS_VOLUME_PATH

# Show the final state of the drives
lsblk

# Build Binaries & Download Chainstate -----------------------------------------

(
  # Impropperly using the data volume path temporarily because it will have the
  # space required to store the compressed chainstate.
  exec >> /node.sh.download.chainstate.log
  sudo mkdir -p $DATA_VOLUME_PATH/tmp
  wget $STACKS_CHAINSTATE_ARCHIVE \
    -O $DATA_VOLUME_PATH/tmp/chainstate.tar.gz
  tar -vxf $DATA_VOLUME_PATH/tmp/chainstate.tar.gz \
    -C $DATA_VOLUME_PATH
  rm -rf $DATA_VOLUME_PATH/tmp
) &

(
  # Build binaries into $ASSETS_VOLUME_PATH/bin
  exec >> /node.sh.build.log
  exec 2>> /node.sh.build.elog

  cd $ASSETS_VOLUME_PATH
  $CLOUD_ASSETS_PATH/build-binaries.sh
  mv $ASSETS_VOLUME_PATH/src/bin $ASSETS_VOLUME_PATH
) &

wait # Wait for both background processes to finish

# No new directories are made at this point; ensure that the stacks
# user has all necessary permissions.
sudo chown -R stacks:stacks /var/stacks/
sudo chown -R stacks:stacks /var/lib/stacks/

# Setup stacks as a service
echo "Setup stacks as a service"
sudo cp $CLOUD_ASSETS_PATH/stacks.service /etc/systemd/system/stacks.service
sudo systemctl daemon-reload
sudo systemctl enable --now stacks

echo 'Configuring logrotate to rotate Stacks logs'
# TODO: use the env variable $ASSETS_VOLUME_PATH to set where the logs are
sudo cp $CLOUD_ASSETS_PATH/stacks.logrotate /etc/logrotate.d/stacks
sudo systemctl restart logrotate.service

# echo "Configuring syncchecker script"
# cd /opt
# sudo mv /opt/sync-checker/syncchecker-stacks.sh /opt/syncchecker.sh
# sudo chmod +x /opt/syncchecker.sh

# (crontab -l; echo "*/1 * * * * /opt/syncchecker.sh > /tmp/syncchecker.log 2>&1") | crontab -
# crontab -l

# if [[ "$LIFECYCLE_HOOK_NAME" != "none" ]]; then
#   echo "Signaling ASG lifecycle hook to complete"
#   TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
#   INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
#   aws autoscaling complete-lifecycle-action --lifecycle-action-result CONTINUE --instance-id $INSTANCE_ID --lifecycle-hook-name "$LIFECYCLE_HOOK_NAME" --auto-scaling-group-name "$ASG_NAME"  --region $AWS_REGION
# fi

echo "All Done!!"
