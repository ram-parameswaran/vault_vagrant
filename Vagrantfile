# -*- mode: ruby -*-
# vi: set ft=ruby :

### Define environment variables to pass on to provisioner

# Define Vault version
VAULT_VER = ENV['VAULT_VER'] || "1.11.2"

# Vault DR needed
VAULT_DR = ENV['VAULT_DR'] || "N"

# Define COnsul version
CONSUL_VER = ENV['CONSUL_VER'] || "1.9.6"

# Define Vault Primary HA server details
VAULT_HA_SERVER_IP_PREFIX = ENV['VAULT_HA_SERVER_IP_PREFIX'] || "10.100.1.1"
VAULT_HA_SERVER_IPS = ENV['VAULT_HA_SERVER_IPS'] || '"10.100.1.11", "10.100.1.12", "10.100.1.13"'

# Define Vault Primary DR server details
VAULT_DR1_SERVER_IP_PREFIX = ENV['VAULT_DR_SERVER_IP_PREFIX'] || "10.100.2.1"
VAULT_DR1_SERVER_IPS = ENV['VAULT_DR1_SERVER_IPS'] || '"10.100.2.11", "10.100.2.12"'

# Define Vault Secondary DR server details
VAULT_DR2_SERVER_IP_PREFIX = ENV['VAULT_DR_SERVER_IP_PREFIX'] || "10.100.4.1"
VAULT_DR2_SERVER_IPS = ENV['VAULT_DR2_SERVER_IPS'] || '"10.100.4.11", "10.100.4.12"'

# Define Vault Secondary Performance Replica server details
VAULT_REPLICA_SERVER_IP_PREFIX = ENV['VAULT_REPLICA_SERVER_IP_PREFIX'] || "10.100.3.1"
VAULT_REPLICA_SERVER_IPS = ENV['VAULT_REPLICA_SERVER_IPS'] || '"10.100.3.11", "10.100.3.12"'

#Define AWS KMS seal details note: must be set in env vars
AWS_KEY_ID = ENV['AWS_KEY_ID'] || "....."
AWS_SECRET = ENV['AWS_SECRET'] || "....."
AWS_KMS_KEY_ID = ENV['AWS_KMS_KEY_ID'] || "....."
VAULT_NUM_INSTANCES = ENV['VAULT_NUM_INSTANCES'] || '1'
STORAGE = ENV['STORAGE'] || ''

Vagrant.configure("2") do |config|
  config.vm.box = "starboard/ubuntu-arm64-20.04.5"
  config.vm.box_version = "20221120.20.40.0"
  config.vm.box_download_insecure = true
  #config.vm.network :private_network, auto_config: true

  # set up the 3 node Vault Primary HA servers
  (1..VAULT_NUM_INSTANCES.to_i).each do |i|
    config.vm.provider "vmware_desktop" do |vmware|
        vmware.allowlist_verified = true
        vmware.vmx["ethernet0.pcislotnumber"] = "160"
        vmware.ssh_info_public = true
        vmware.linked_clone = false
        vmware.gui = true
        vmware.vmx["ethernet0.virtualdev"] = "e1000e"
        #print (vmware)
    end
    config.vm.define "vault#{i}" do |v1|
      v1.vm.hostname = "v#{i}"
      v1.vm.synced_folder ".", "/vagrant", owner: "vagrant", group: "vagrant"
      #v1.vm.network "private_network", type: "dhcp"
      if (STORAGE=="consul") then
         v1.vm.provision "shell", path: "scripts/setupConsulServer.sh", env: {'CONSUL_VER' => CONSUL_VER, 'VAULT_VER' => VAULT_VER, 'HOST' => "v#{i}", 'AWS_KEY_ID' => AWS_KEY_ID, 'AWS_SECRET' => AWS_SECRET, 'AWS_KMS_KEY_ID' => AWS_KMS_KEY_ID}
      end
      #sleep 100
      v1.vm.provision "shell", path: "scripts/setupPrimVaultServer.sh", env: {'STORAGE_CONSUL' => STORAGE ,'VAULT_VER' => VAULT_VER, 'HOST' => "v#{i}", 'AWS_KEY_ID' => AWS_KEY_ID, 'AWS_SECRET' => AWS_SECRET, 'AWS_KMS_KEY_ID' => AWS_KMS_KEY_ID}
    end
  end

if (VAULT_DR=="Y") then
 # set up the 2 node Vault Primary DR servers
 (1..2).each do |i|
    config.vm.provider "vmware_desktop" do |vmware|
        vmware.allowlist_verified = true
        vmware.vmx["ethernet0.pcislotnumber"] = "160"
        vmware.ssh_info_public = true
        vmware.linked_clone = false
        vmware.gui = true
        vmware.vmx["ethernet0.virtualdev"] = "vmxnet3"    
    end
    config.vm.define "vault-dr1#{i}" do |v1|
              v1.vm.hostname = "v-dr1#{i}"
      v1.vm.synced_folder ".", "/vagrant", owner: "vagrant", group: "vagrant"
      v1.vm.network "private_network", type: "dhcp"
      v1.vm.provision "shell", path: "scripts/setupDrVaultServer.sh", env: {'VAULT_VER' => VAULT_VER, 'HOST' => "v-dr1#{i}", 'AWS_KEY_ID' => AWS_KEY_ID, 'AWS_SECRET' => AWS_SECRET, 'AWS_KMS_KEY_ID' => AWS_KMS_KEY_ID}
    end
  end
end

  # set up the 2 node Vault Secondary DR servers
#  (1..2).each do |i|
#    config.vm.define "vault-dr2#{i}" do |v1|
#      v1.vm.hostname = "v-dr2#{i}"
#      v1.vm.network "private_network", ip: VAULT_DR2_SERVER_IP_PREFIX+"#{i}", netmask:"255.255.0.0"
#      v1.vm.provision "shell", path: "scripts/setupDr2VaultServer.sh", env: {'VAULT_VER' => VAULT_VER, 'HOST' => "v#{i}", 'AWS_KEY_ID' => AWS_KEY_ID, 'AWS_SECRET' => AWS_SECRET, 'AWS_KMS_KEY_ID' => AWS_KMS_KEY_ID}
#    end
#  end

  # set up the 2 node Vault Secondary Replication servers
#  (1..2).each do |i|
#    config.vm.define "vault-pr#{i}" do |v1|
#      v1.vm.hostname = "v-pr#{i}"
#      v1.vm.network "private_network", ip: VAULT_REPLICA_SERVER_IP_PREFIX+"#{i}", netmask:"255.255.0.0"
#      v1.vm.provision "shell", path: "scripts/setupRepVaultServer.sh", env: {'VAULT_VER' => VAULT_VER, 'HOST' => "v#{i}", 'AWS_KEY_ID' => AWS_KEY_ID, 'AWS_SECRET' => AWS_SECRET, 'AWS_KMS_KEY_ID' => AWS_KMS_KEY_ID}
#    end
#  end

end
