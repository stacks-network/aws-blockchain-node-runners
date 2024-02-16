source /etc/environment
CONFIG_DIR=stacks/config/follower

# TODO: Set any environment variables here.

sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/
sudo mkdir -p /var/stacks/data/

envsubst < /opt/$CONFIG_DIR/node-config.toml > /var/stacks/node-config.toml
cp /opt/$CONFIG_DIR/cw-agent.json /opt/aws/amazon-cloudwatch-agent/etc/custom-amazon-cloudwatch-agent.json

# TODO: move Prometheus metric specifications here.