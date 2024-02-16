#!/bin/bash

source /etc/environment

exec >> /setup-instance-store-volumes.sh.log

# Note, it's bad if the DATA_VOLUME_TYPE is `instance-store` because it is
# temporary. We should prevent this from being an option.
if [[ "$DATA_VOLUME_TYPE" == "instance-store" ]]; then
  echo "Data volume type is instance store"
  export DATA_VOLUME_ID=/dev/nvme1n1
fi

if [[ "$ASSETS_VOLUME_TYPE" == "instance-store" ]]; then
  echo "Assets volume type is instance store"
  if [[ "$DATA_VOLUME_TYPE" == "instance-store" ]]; then
    export ASSETS_VOLUME_ID=/dev/nvme2n1
  else
    export ASSETS_VOLUME_ID=/dev/nvme1n1
  fi
fi

if [ -n "$DATA_VOLUME_ID" ]; then
  echo "If Data volume is mounted, dont do anything"
  if [ $(df --output=target | grep -c "$DATA_VOLUME_PATH") -lt 1 ]; then
    echo "Checking fstab for Data volume"

    sudo mkfs.xfs -f $DATA_VOLUME_ID
    sleep 10
    DATA_VOLUME_UUID=$(lsblk -fn -o UUID  $DATA_VOLUME_ID)
    DATA_VOLUME_FSTAB_CONF="UUID=$DATA_VOLUME_UUID $DATA_VOLUME_PATH xfs defaults 0 2"
    echo "DATA_VOLUME_ID="$DATA_VOLUME_ID
    echo "DATA_VOLUME_UUID="$DATA_VOLUME_UUID
    echo "DATA_VOLUME_FSTAB_CONF="$DATA_VOLUME_FSTAB_CONF

    # Check if data disc is already in fstab and replace the line if it is with the new disc UUID
    if [ $(grep -c "data" /etc/fstab) -gt 0 ]; then
      SED_REPLACEMENT_STRING="$(grep -n "$DATA_VOLUME_PATH" /etc/fstab | cut -d: -f1)s#.*#$DATA_VOLUME_FSTAB_CONF#"
      sudo cp /etc/fstab /etc/fstab.bak
      sudo sed -i "$SED_REPLACEMENT_STRING" /etc/fstab
    else
      echo $DATA_VOLUME_FSTAB_CONF | sudo tee -a /etc/fstab
    fi

    sudo mount -a

    sudo chown -R stacks:stacks $DATA_VOLUME_PATH
  else
    echo "Data volume is mounted, nothing changed"
  fi
fi

if [ -n "$ASSETS_VOLUME_ID" ]; then
  echo "If Assets volume is mounted, dont do anything"
  if [ $(df --output=target | grep -c "$ASSETS_VOLUME_PATH") -lt 1 ]; then
    echo "Checking fstab for Assets volume"

    sudo mkfs.xfs -f $ASSETS_VOLUME_ID
    sleep 10
    ASSETS_VOLUME_UUID=$(lsblk -fn -o UUID $ASSETS_VOLUME_ID)
    ASSETS_VOLUME_FSTAB_CONF="UUID=$ASSETS_VOLUME_UUID $ASSETS_VOLUME_PATH xfs defaults 0 2"
    echo "ASSETS_VOLUME_ID="$ASSETS_VOLUME_ID
    echo "ASSETS_VOLUME_UUID="$ASSETS_VOLUME_UUID
    echo "ASSETS_VOLUME_FSTAB_CONF="$ASSETS_VOLUME_FSTAB_CONF

    # Check if assets disc is already in fstab and replace the line if it is with the new disc UUID
    if [ $(grep -c "$ASSETS_VOLUME_PATH" /etc/fstab) -gt 0 ]; then
      SED_REPLACEMENT_STRING="$(grep -n "$ASSETS_VOLUME_PATH" /etc/fstab | cut -d: -f1)s#.*#$ASSETS_VOLUME_FSTAB_CONF#"
      sudo cp /etc/fstab /etc/fstab.bak
      sudo sed -i "$SED_REPLACEMENT_STRING" /etc/fstab
    else
      echo $ASSETS_VOLUME_FSTAB_CONF | sudo tee -a /etc/fstab
    fi

    sudo mount -a

    sudo mkdir -p $ASSETS_VOLUME_PATH/log
    sudo mkdir -p $ASSETS_VOLUME_PATH/src
    sudo mkdir -p $ASSETS_VOLUME_PATH/bin

    sudo chown -R stacks:stacks $ASSETS_VOLUME_PATH

  else
    echo "Assets volume is mounted, nothing changed"
  fi
fi
