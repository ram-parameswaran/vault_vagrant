#!/usr/bin/env bash

echo "Inside setupConsulServer.sh"

export DEBIAN_FRONTEND="noninteractive"
export PATH="$PATH:/usr/local/bin"

echo "Installing dependencies ..."
apt-get -y install unzip curl

echo "Installing Consul Enterprise version ..."
#CONSUL_VERSION="$CONSUL_VER"
#echo "$CONSUL_VERSION"

if [[ "$CONSUL_VER" == "" ]]; then
  CONSUL_VERSION=$(curl -s https://releases.hashicorp.com/consul/ | grep -o 'href="/consul/[0-9]*\.[0-9]*\.[0-9]*/"' | sed 's/href="//;s/"//g' | sed 's|/consul/||;s|/$||' | sort -V | tail -n 1)
else
  CONSUL_VERSION="$CONSUL_VER"
fi
echo "$CONSUL_VERSION"

OS_ARCHITECTURE=$(dpkg --print-architecture)
arm64="arm64"

if [[ $(curl -s https://releases.hashicorp.com/consul/ | grep "$CONSUL_VERSION") && $(ls /vagrant/consul_builds | grep "$CONSUL_VERSION") ]]; then
  cp -r /vagrant/consul_builds/"$CONSUL_VERSION"/consul /usr/local/bin/consul;
else
  if curl -s -f -o /vagrant/consul_builds/"$CONSUL_VERSION"/consul.zip --create-dirs https://releases.hashicorp.com/consul/"$CONSUL_VERSION"/consul_"$CONSUL_VERSION"_linux_"$OS_ARCHITECTURE".zip; then
    unzip /vagrant/consul_builds/"$CONSUL_VERSION"/consul.zip -d /vagrant/consul_builds/"$CONSUL_VERSION"/
    rm /vagrant/consul_builds/"$CONSUL_VERSION"/consul.zip
    cp -r /vagrant/consul_builds/"$CONSUL_VERSION"/consul /usr/local/bin/consul;
  else
    echo "####### Consul version not found #########"
  fi
fi

echo "Creating Consul service account ..."
useradd -r -d /etc/consul -s /bin/sh consul

echo "Creating Consul directory structure ..."
mkdir -p /etc/consul/{config.d,pki}
chown -R root:consul /etc/consul
chmod -R 0750 /etc/consul

echo "Creating Consul configuration ..."
echo ' export CONSUL_LICENSE_PATH=/vagrant/consul.license '

mkdir /var/{lib,log}/consul
chown consul:consul /var/{lib,log}/consul
chmod 0750 /var/{lib,log}/consul

echo "Creating Consul configuration file ..."
NETWORK_INTERFACE=$(ls -1 /sys/class/net | grep -v lo | sort -r | head -n 1)
IP_ADDRESS=$(ip address show $NETWORK_INTERFACE | awk '{print $2}' | egrep -o '([0-9]+\.){3}[0-9]+')
HOSTNAME=$(hostname -s)

echo "IP Address is ${IP_ADDRESS}  Host Name is ${HOSTNAME}"

echo "Creating Consul configuration ..."
echo ' export CONSUL_LICENSE_PATH=/vagrant/consul.license ' | tee /etc/profile.d/consul.sh

cat > /etc/consul/config.d/consul.hcl << EOF
{
  "server": true,
  "node_name": "${HOSTNAME}",
  "datacenter": "${HOSTNAME}",
  "data_dir": "/var/run/consul/data",
  "bind_addr": "0.0.0.0",
  "client_addr": "0.0.0.0",
  "advertise_addr": "${IP_ADDRESS}",
  "bootstrap_expect": 1,
  "ui": true,
  "log_level": "TRACE",
  "enable_syslog": true,
  "acl_enforce_version_8": false,
  "license_path" : "/vagrant/consul.license"
}
EOF

chown root:consul /etc/consul/config.d/*
chmod 0640 /etc/consul/config.d/*

# Systemd configuration
echo "Setting up Consul system service ..."
cat > /etc/systemd/system/consul.service << EOF
[Unit]
Description=Consul server agent
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul/config.d/consul.hcl

[Service]
User=consul
Group=consul
PIDFile=/var/run/consul/consul.pid
PermissionsStartOnly=true
ExecStartPre=-/bin/mkdir -p /var/run/consul
ExecStartPre=/bin/chown -R consul:consul /var/run/consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul/config.d -pid-file=/var/run/consul/consul.pid
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
RestartSec=42s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

echo "Starting Consul service ..."
systemctl daemon-reload
systemctl enable consul
systemctl restart consul
