#!/usr/bin/env bash

export PATH=$PATH:/usr/local/bin

#installing vault
VAULT_VERSION="$VAULT_VER"
echo "$VAULT_VERSION"

#installing terraform
TERRAFORM_VERSION="1.4.4"
echo "$TERRAFORM_VERSION"

#if installing consul
STORAGE=$STORAGE_CONSUL
echo $STORAGE

echo "<REDACTED>"
echo "<REDACTED>"
echo "<REDACTED>"

echo "Setting Timezone to local TZ"
sudo timedatectl set-timezone Australia/Melbourne

echo "Installing dependencies ..."
apt-get update 
apt-get -y install unzip curl gnupg software-properties-common 
apt-get -y install jq

echo "Installing Terraform"
#https://releases.hashicorp.com/terraform/1.3.7/terraform_1.3.7_linux_arm64.zip
echo "check OS architecure" ; dpkg --print-architecture

OS_ARCHITECTURE=$(dpkg --print-architecture)
arm64="arm64"

echo "Installing terraform version ... $TERRAFORM_VERSION "
cp -r /vagrant/terraform_builds/"$TERRAFORM_VERSION"/terraform /usr/local/bin/terraform;
echo "Installed terraform successfully, version ... $TERRAFORM_VERSION "

#if [[ $(curl -s https://releases.hashicorp.com/terraform/ | grep "$TERRAFORM_VERSION") && $(ls /vagrant/terraform_builds | grep -Fx "$TERRAFORM_VERSION") ]]; then
#  echo "Linking terraform build"
#  cp -r /vagrant/terraform_builds/"$TERRAFORM_VERSION"/terraform /usr/local/bin/terraform;
#else
  # https://releases.hashicorp.com/vault/1.9.4+ent/vault_1.9.4+ent_linux_arm64.zip
  # https://releases.hashicorp.com/vault/1.11.2+ent/vault_1.11.2+ent_linux_arm64.zip
  #echo "In else, which means i will fetch the terraform installer from the interweb"
  #if curl -s -f -o /vagrant/terraform_builds/"$TERRAFORM_VERSION"/terraform.zip --create-dirs https://releases.hashicorp.com/terraform/"$TERRAFORM_VERSION"/terraform_"$TERRAFORM_VERSION"_linux_$OS_ARCHITECTURE.zip ; then
  #  unzip /vagrant/terraform_builds/"$TERRAFORM_VERSION"/terraform.zip -d /vagrant/terraform_builds/"$TERRAFORM_VERSION"/
  #  rm /vagrant/terraform_builds/"$TERRAFORM_VERSION"/terraform.zip
  #  cp -r /vagrant/terraform_builds/"$TERRAFORM_VERSION"/terraform /usr/local/bin/terraform;
  #else
  #  echo "####### terraform version not found #########"
  #fi
#fi

echo "Installing Vault enterprise version ... $VAULT_VERSION "
if [[ $(curl -s https://releases.hashicorp.com/vault/ | grep "$VAULT_VERSION") && $(ls /vagrant/vault_builds | grep -Fx "$VAULT_VERSION") ]]; then
  echo "Linking Vault build"
  cp -r /vagrant/vault_builds/"$VAULT_VERSION"/vault /usr/local/bin/vault;
else
  # https://releases.hashicorp.com/vault/1.9.4+ent/vault_1.9.4+ent_linux_arm64.zip
  # https://releases.hashicorp.com/vault/1.11.2+ent/vault_1.11.2+ent_linux_arm64.zip
  echo "In else, which means i will fetch the vault installer from the interweb"
  if curl -s -f -o /vagrant/vault_builds/"$VAULT_VERSION"/vault.zip --create-dirs https://releases.hashicorp.com/vault/"$VAULT_VERSION"/vault_"$VAULT_VERSION"_linux_$OS_ARCHITECTURE.zip ; then
    unzip /vagrant/vault_builds/"$VAULT_VERSION"/vault.zip -d /vagrant/vault_builds/"$VAULT_VERSION"/
    rm /vagrant/vault_builds/"$VAULT_VERSION"/vault.zip
    cp -r /vagrant/vault_builds/"$VAULT_VERSION"/vault /usr/local/bin/vault;
  else
    echo "####### Vault version not found #########"
  fi
fi

echo "Creating Vault service account ..."
useradd -r -d /etc/vault -s /bin/sh vault

echo "Creating directory structure ..."
mkdir -p /etc/vault/pki
mkdir /opt/vault
chown vault:vault /opt/vault
chown -R root:vault /etc/vault
chmod -R 0750 /etc/vault

mkdir /var/{lib,log}/vault
chown vault:vault /var/{lib,log}/vault
chmod 0750 /var/{lib,log}/vault

sudo cp /vagrant/certs/ca.pem /usr/local/share/ca-certificates
sudo cp /vagrant/certs/ca.pem /etc/ssl/certs/ca.pem
sudo cat /vagrant/certs/ca.pem >> /etc/ssl/certs/ca-certificates.crt
sudo update-ca-certificates --fresh

NETWORK_INTERFACE=$(ls -1 /sys/class/net | grep -v lo | head -n 1)
#NETWORK_INTERFACE=$(ls -1 /sys/class/net | grep -v lo | sort -r | head -n 1)
echo "NETWORK_INTERFACE = $INTERFACE "
IP_ADDRESS=$(ip address show $NETWORK_INTERFACE | awk '{print $2}' | egrep -o '([0-9]+\.){3}[0-9]+')
echo "IP_ADDRESS = $IP_ADDRESS "
HOSTNAME=$(hostname -s)
echo "HOSTNAME = $HOSTNAME"

echo "Creating Vault configuration ..."
echo 'export VAULT_ADDR="http://127.0.0.1:8200" ; export VAULT_RAFT_AUTOPILOT_DISABLE=true' | tee /etc/profile.d/vault.sh

if [[ "$STORAGE" == "consul" ]]; then
tee /etc/vault/vault.hcl << EOF
api_addr = "http://${IP_ADDRESS}:8200"
cluster_addr = "http://${IP_ADDRESS}:8201"
ui = true 
log_level="trace"

license_path = "/vagrant/.license"

#storage "raft" {
#  path = "/opt/vault"
#  #node_id = "${HOST}"
#}

storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = "true"
  cluster_address = "0.0.0.0:8201"
  #tls_cert_file = "/vagrant/certs/vault-server-1.crt"
  #tls_key_file  = "/vagrant/certs/vault-server-1.key"
  #tls_client_ca_file = "/vagrant/certs/ca.pem"
  #telemetry {
   #unauthenticated_metrics_access = true
  #}
}
# setup as per https://www.vaultproject.io/docs/configuration/seal/awskms#key-rotation
# need to export your aws key and secret to AWS_KEY_ID and AWS_SECRET respectivly
#seal "awskms" {
# region     = "ap-southeast-2"
# access_key = "$AWS_KEY_ID"
# secret_key = "$AWS_SECRET"
# kms_key_id = "$AWS_KMS_KEY_ID"
#}
EOF
else
tee /etc/vault/vault.hcl << EOF
api_addr = "http://${IP_ADDRESS}:8200"
cluster_addr = "http://${IP_ADDRESS}:8201"
ui = true
log_level="trace"

license_path = "/vagrant/.license"

storage "raft" {
  path = "/opt/vault"
  #node_id = "${HOST}"
}

#storage "consul" {
#  address = "127.0.0.1:8500"
#  path    = "vault/"
#}
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = "true"
  cluster_address = "0.0.0.0:8201"
  #tls_cert_file = "/vagrant/certs/vault-server-1.crt"
  #tls_key_file  = "/vagrant/certs/vault-server-1.key"
  #tls_client_ca_file = "/vagrant/certs/ca.pem"
  #telemetry {
   #unauthenticated_metrics_access = true
  #}
}
# setup as per https://www.vaultproject.io/docs/configuration/seal/awskms#key-rotation
# need to export your aws key and secret to AWS_KEY_ID and AWS_SECRET respectivly
#seal "awskms" {
# region     = "ap-southeast-2"
# access_key = "$AWS_KEY_ID"
# secret_key = "$AWS_SECRET"
# kms_key_id = "$AWS_KMS_KEY_ID"
#}

# this will disable perf standby even if the license allows
disable_performance_standby = true

EOF
fi

chown root:vault /etc/vault/vault.hcl
chmod 0640 /etc/vault/vault.hcl

tee /etc/systemd/system/vault.service << EOF
[Unit]
Description="Vault secret management tool"
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault/vault.hcl
[Service]
User=vault
Group=vault
PIDFile=/var/run/vault/vault.pid
ExecStart=/usr/local/bin/vault server -config=/etc/vault/vault.hcl
StandardOutput=file:/var/log/vault/vault.log
StandardError=file:/var/log/vault/vault.log
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=42
TimeoutStopSec=30
StartLimitInterval=60
StartLimitBurst=3
LimitMEMLOCK=infinity
[Install]
WantedBy=multi-user.target
EOF

tee /etc/telegraf/telegraf.conf << EOF
[global_tags]
  index="vault-metrics"
  datacenter = "testing"
  role       = "vault-server"
  cluster    = "vtl"

# Agent options around collection interval, sizes, jitter and so on
[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  hostname = ""
  omit_hostname = false

# An input plugin that listens on UDP/8125 for statsd compatible telemetry
# messages using Datadog extensions which are emitted by Vault
[[inputs.statsd]]
  protocol = "udp"
  service_address = ":8125"
  metric_separator = "."
  datadog_extensions = true

##[[outputs.file]]
##  files = ["stdout", "/tmp/metrics.out"]
##  data_format = "json"
##  json_timestamp_units = "1s"
EOF


systemctl daemon-reload
systemctl enable vault
systemctl restart vault
vault -autocomplete-install

### Init vault server
#if [[ "$HOSTNAME" == "v1" ]]; then
  echo testing vault up
  export VAULT_ADDR="http://127.0.0.1:8200"
  export VAULT_CLUSTER_ADDR="http://127.0.0.1:8201"
  vault status
  sleep 10
  sudo systemctl restart vault
  sleep 20
  #while [ $? -ne 2 ]; do echo "still testing"; vault status; done
  vault operator init -key-shares=1 -key-threshold=1 -format=json > /home/vagrant/VaultCreds.json
  sleep 10
  vault status
  sleep 5
  cat /home/vagrant/VaultCreds.json
  export VAULT_UNSEAL_KEY=$(cat /home/vagrant/VaultCreds.json | jq -r .unseal_keys_b64[0])
  vault operator unseal $VAULT_UNSEAL_KEY
  #cp -r /home/vagrant/VaultCreds.json /vagrant/VaultCreds.json.${IP_ADDRESS}
  sleep 5
  echo 'export VAULT_ADDR="http://127.0.0.1:8200" ; export VAULT_UNSEAL_KEY=$(cat /home/vagrant/VaultCreds.json | jq -r .unseal_keys_b64[0]) ; export VAULT_RAFT_AUTOPILOT_DISABLE=true ; export VAULT_TOKEN=$(cat /home/vagrant/VaultCreds.json | jq -r .root_token)' | tee /etc/profile.d/vault.sh
  export VAULT_TOKEN=$(cat /home/vagrant/VaultCreds.json | jq -r .root_token)
  vault login $(cat /home/vagrant/VaultCreds.json | jq -r .root_token)
  vault status
#else
 #echo "HOSTNAME = $HOSTNAME vault being launched as a follower"
 #vault status
#fi


## print servers IP address
echo "The IP of the host $(hostname) is $(hostname -I | awk '{print $1}')"
