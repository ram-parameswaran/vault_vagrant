#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

export PATH=$PATH:/usr/local/bin

#installing vault
VAULT_VER="${VAULT_VER:-}"
if [[ "$VAULT_VER" == "" ]]; then
  VAULT_VERSION=$(curl -sSf --max-time 30 https://releases.hashicorp.com/vault/ | grep -o 'href="/vault/[0-9]*\.[0-9]*\.[0-9]*/"' | sed 's/href="//;s/"//g' | sed 's|/vault/||;s|/$||' | sort -V | tail -n 1)+"ent"
else
  VAULT_VERSION="$VAULT_VER"
fi
echo "$VAULT_VERSION"

#installing terraform
TF_VER="${TF_VER:-}"
if [[ "$TF_VER" == "" ]]; then
  TERRAFORM_VERSION=$(curl -sSf --max-time 30 https://releases.hashicorp.com/terraform/ | grep -o 'href="/terraform/[0-9]*\.[0-9]*\.[0-9]*/"' | sed 's/href="//;s/"//g' | sed 's|/terraform/||;s|/$||' | sort -V | tail -n 1)
else
  TERRAFORM_VERSION="$TF_VER"
fi
echo "$TERRAFORM_VERSION"

#if installing consul
STORAGE="${STORAGE_CONSUL:-}"
echo "$STORAGE"

echo "<REDACTED>"
echo "<REDACTED>"
echo "<REDACTED>"

echo "Setting Timezone to local TZ"
sudo timedatectl set-timezone Australia/Melbourne

echo "Installing dependencies ..."
apt-get update 
apt-get -y install unzip curl gnupg software-properties-common 
apt-get -y install jq

echo "check OS architecure" ; dpkg --print-architecture
OS_ARCHITECTURE=$(dpkg --print-architecture)

# Unified function to install HashiCorp binaries
install_hashicorp_binary() {
  local PRODUCT=$1
  local VERSION=$2
  local BINARY_NAME=$(echo "$PRODUCT" | tr '[:upper:]' '[:lower:]')
  local BUILD_DIR="/vagrant/${BINARY_NAME}_builds"
  local CHECKSUM_URL="https://releases.hashicorp.com/${BINARY_NAME}/${VERSION}/${BINARY_NAME}_${VERSION}_SHA256SUMS"
  
  echo "Installing $PRODUCT version ... $VERSION"
  
  # Check if binary already exists locally
  if [[ $(curl -sSf --max-time 10 https://releases.hashicorp.com/$BINARY_NAME/ | grep "$VERSION") && -f "$BUILD_DIR/$VERSION/$BINARY_NAME" ]]; then
    echo "Linking $PRODUCT build"
    cp -r "$BUILD_DIR/$VERSION/$BINARY_NAME" /usr/local/bin/$BINARY_NAME
    chmod 755 /usr/local/bin/$BINARY_NAME
    [[ "$PRODUCT" == "terraform" ]] && terraform version
    return 0
  fi
  
  # Download and install
  echo "Downloading $PRODUCT installer from releases.hashicorp.com"
  local ZIP_FILE="$BUILD_DIR/$VERSION/$BINARY_NAME.zip"
  
  if curl -sSf --max-time 300 -o "$ZIP_FILE" --create-dirs \
    "https://releases.hashicorp.com/$BINARY_NAME/$VERSION/${BINARY_NAME}_${VERSION}_linux_${OS_ARCHITECTURE}.zip"; then
    
    # Download and verify checksum (CVE mitigation)
    echo "Verifying checksum..."
    if curl -sSf --max-time 30 -o "$BUILD_DIR/$VERSION/SHA256SUMS" "$CHECKSUM_URL"; then
      cd "$BUILD_DIR/$VERSION"
      if sha256sum --ignore-missing -c SHA256SUMS 2>/dev/null | grep -q "${BINARY_NAME}_${VERSION}_linux_${OS_ARCHITECTURE}.zip: OK"; then
        echo "Checksum verification passed"
      else
        echo "####### Checksum verification failed! Possible tampering detected #########"
        rm -f "$ZIP_FILE" SHA256SUMS
        return 1
      fi
      cd - > /dev/null
    else
      echo "WARNING: Could not download checksums, skipping verification"
    fi
    
    # Validate zip file
    if unzip -t "$ZIP_FILE" > /dev/null 2>&1; then
      echo "$PRODUCT zip file validated successfully"
      unzip -o "$ZIP_FILE" -d "$BUILD_DIR/$VERSION/"
      rm -f "$ZIP_FILE"
      chmod 755 "$BUILD_DIR/$VERSION/$BINARY_NAME"
      cp "$BUILD_DIR/$VERSION/$BINARY_NAME" /usr/local/bin/$BINARY_NAME
      [[ "$PRODUCT" == "terraform" ]] && terraform version
      echo "Installed $PRODUCT successfully, version ... $VERSION"
    else
      echo "####### Downloaded $PRODUCT zip file is corrupted, removing it #########"
      rm -f "$ZIP_FILE"
      echo "####### Please re-run provisioning to retry download #########"
      return 1
    fi
  else
    echo "####### $PRODUCT version not found or download failed #########"
    return 1
  fi
}

# Install Terraform and Vault
install_hashicorp_binary "terraform" "$TERRAFORM_VERSION"
install_hashicorp_binary "vault" "$VAULT_VERSION"

echo "Creating Vault service account ..."
if ! id -u vault > /dev/null 2>&1; then
  useradd -r -d /etc/vault -s /bin/sh vault
else
  echo "Vault user already exists, skipping creation"
fi

echo "Creating directory structure ..."
mkdir -p /etc/vault/pki
mkdir -p /opt/vault
chown vault:vault /opt/vault
chown -R root:vault /etc/vault
chmod -R 0750 /etc/vault

mkdir -p /var/{lib,log}/vault
chown vault:vault /var/{lib,log}/vault
chmod 0750 /var/{lib,log}/vault

sudo cp -f /vagrant/certs/ca.pem /usr/local/share/ca-certificates/ca.pem 2>/dev/null || true
sudo cp -f /vagrant/certs/ca.pem /etc/ssl/certs/ca.pem 2>/dev/null || true
sudo update-ca-certificates --fresh

NETWORK_INTERFACE=$(ls -1 /sys/class/net | grep -v lo | head -n 1)
#NETWORK_INTERFACE=$(ls -1 /sys/class/net | grep -v lo | sort -r | head -n 1)
echo "NETWORK_INTERFACE = $NETWORK_INTERFACE "
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

license_path = "/vagrant/vault.license"

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
# access_key = "\$AWS_KEY_ID"
# secret_key = "\$AWS_SECRET"
# kms_key_id = "\$AWS_KMS_KEY_ID"
#}
EOF
else
tee /etc/vault/vault.hcl << EOF
api_addr = "http://${IP_ADDRESS}:8200"
cluster_addr = "http://${IP_ADDRESS}:8201"
ui = true
log_level="trace"
disable_mlock=false
license_path = "/vagrant/vault.license"

storage "raft" {
  path = "/opt/vault"
  #node_id = "${HOST}"
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
# access_key = "\$AWS_KEY_ID"
# secret_key = "\$AWS_SECRET"
# kms_key_id = "\$AWS_KMS_KEY_ID"
#}

# this will disable perf standby even if the license allows
#disable_performance_standby = true

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
ExecReload=/bin/kill -HUP \$MAINPID
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


systemctl daemon-reload
systemctl enable vault
systemctl restart vault
vault -autocomplete-install 2>/dev/null || echo "Vault autocomplete already installed or failed"

### Init vault server or join cluster
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_CLUSTER_ADDR="http://127.0.0.1:8201"

# Determine if this is the first node (leader)
IS_LEADER=false
if [[ "$HOSTNAME" =~ ^v1$ ]] || [[ "$HOSTNAME" =~ ^v-dr-1$ ]] || [[ "$HOSTNAME" =~ ^v-pr-1$ ]]; then
  IS_LEADER=true
fi

echo "Node: $HOSTNAME, Leader: $IS_LEADER"
sleep 10
sudo systemctl restart vault
sleep 20

if [ "$IS_LEADER" = true ]; then
  echo "Initializing Vault cluster on leader node: $HOSTNAME"
  
  # Check if Vault is already initialized
  if vault status 2>/dev/null | grep -q "Initialized.*true"; then
    echo "Vault is already initialized, skipping initialization"
    if [ ! -f /home/vagrant/VaultCreds.json ] && [ -f /vagrant/VaultCreds.json ]; then
      cp /vagrant/VaultCreds.json /home/vagrant/VaultCreds.json
    fi
  else
    vault operator init -key-shares=1 -key-threshold=1 -format=json > /home/vagrant/VaultCreds.json
    sleep 10
    
    # Add leader IP to credentials file
    LEADER_IP="$IP_ADDRESS"
    jq --arg leader_ip "$LEADER_IP" '. + {leader_ip: $leader_ip}' /home/vagrant/VaultCreds.json > /home/vagrant/VaultCreds.tmp.json
    mv /home/vagrant/VaultCreds.tmp.json /home/vagrant/VaultCreds.json
    
    # Copy credentials to shared location for follower nodes
    cp /home/vagrant/VaultCreds.json /vagrant/VaultCreds.json
  fi
  
  export VAULT_UNSEAL_KEY=$(cat /home/vagrant/VaultCreds.json | jq -r .unseal_keys_b64[0])
  vault operator unseal "$VAULT_UNSEAL_KEY"
  sleep 5
  
  export VAULT_TOKEN=$(cat /home/vagrant/VaultCreds.json | jq -r .root_token)
  echo 'export VAULT_ADDR="http://127.0.0.1:8200" ; export VAULT_UNSEAL_KEY=$(cat /home/vagrant/VaultCreds.json | jq -r .unseal_keys_b64[0]) ; export VAULT_RAFT_AUTOPILOT_DISABLE=true ; export VAULT_TOKEN=$(cat /home/vagrant/VaultCreds.json | jq -r .root_token)' | tee /etc/profile.d/vault.sh
  vault login "$VAULT_TOKEN"
  vault status
  
  echo "Leader node initialized successfully at IP: $LEADER_IP"
else
  echo "Joining Vault cluster as follower node: $HOSTNAME"
  
  # Wait for leader credentials to be available
  RETRY_COUNT=0
  MAX_RETRIES=30
  while [ ! -f /vagrant/VaultCreds.json ] && [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; do
    echo "Waiting for leader initialization... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT + 1))
  done
  
  if [ ! -f /vagrant/VaultCreds.json ]; then
    echo "ERROR: Leader credentials not found after waiting. Cannot join cluster."
    exit 1
  fi
  
  # Get leader IP from credentials file
  LEADER_IP=$(cat /vagrant/VaultCreds.json | jq -r .leader_ip)
  
  if [ -z "$LEADER_IP" ] || [ "$LEADER_IP" = "null" ]; then
    echo "ERROR: Leader IP not found in credentials file"
    exit 1
  fi
  
  echo "Leader IP from credentials: $LEADER_IP"
  
  # Join the Raft cluster
  export VAULT_TOKEN=$(cat /vagrant/VaultCreds.json | jq -r .root_token)
  vault operator raft join "http://${LEADER_IP}:8200"
  sleep 5
  
  # Unseal the follower node
  export VAULT_UNSEAL_KEY=$(cat /vagrant/VaultCreds.json | jq -r .unseal_keys_b64[0])
  vault operator unseal "$VAULT_UNSEAL_KEY"
  sleep 5
  
  # Copy credentials locally
  cp /vagrant/VaultCreds.json /home/vagrant/VaultCreds.json
  echo 'export VAULT_ADDR="http://127.0.0.1:8200" ; export VAULT_UNSEAL_KEY=$(cat /home/vagrant/VaultCreds.json | jq -r .unseal_keys_b64[0]) ; export VAULT_RAFT_AUTOPILOT_DISABLE=true ; export VAULT_TOKEN=$(cat /home/vagrant/VaultCreds.json | jq -r .root_token)' | tee /etc/profile.d/vault.sh
  
  vault status
  echo "Follower node joined cluster successfully using leader IP: $LEADER_IP"
fi


## print servers IP address
echo "The IP of the host $(hostname) is $(hostname -I | awk '{print $1}')"
