# -*- mode: ruby -*-
# vi: set ft=ruby :

### Define environment variables to pass on to provisioner

# Define Vault version
VAULT_VER = ENV['VAULT_VER'] || "1.17.2+ent"

# Define Consul version
CONSUL_VER = ENV['CONSUL_VER'] || "1.19.1+ent"

# Define Terraform version
TF_VER = ENV['TF_VER'] || "1.9.2"

VAULT_NUM_INSTANCES = ENV['VAULT_NUM_INSTANCES'] || '1'
VAULT_NUM_DR_INSTANCES = ENV['VAULT_NUM_DR_INSTANCES'] || '0'
VAULT_NUM_PR_INSTANCES = ENV['VAULT_NUM_PR_INSTANCES'] || '0'

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
         v1.vm.provision "shell", path: "scripts/setupConsulServer.sh", env: {'STORAGE_CONSUL' => STORAGE ,'TF_VER' => TF_VER,'CONSUL_VER' => CONSUL_VER, 'VAULT_VER' => VAULT_VER, 'HOST' => "v#{i}"}
      end
      v1.vm.provision "shell", path: "scripts/setupPrimVaultServer.sh", env: {'STORAGE_CONSUL' => STORAGE , 'TF_VER' => TF_VER, 'VAULT_VER' => VAULT_VER, 'HOST' => "v#{i}"}
    end
  end
end

Vagrant.configure("2") do |config|
  config.vm.box = "starboard/ubuntu-arm64-20.04.5"
  config.vm.box_version = "20221120.20.40.0"
  config.vm.box_download_insecure = true
  #config.vm.network :private_network, auto_config: true

  (1..VAULT_NUM_DR_INSTANCES.to_i).each do |i|
    config.vm.provider "vmware_desktop" do |vmware|
        vmware.allowlist_verified = true
        vmware.vmx["ethernet0.pcislotnumber"] = "160"
        vmware.ssh_info_public = true
        vmware.linked_clone = false
        vmware.gui = true
        vmware.vmx["ethernet0.virtualdev"] = "e1000e"
        #print (vmware)
    end
    config.vm.define "vault-dr#{i}" do |v1|
      v1.vm.hostname = "v-dr-#{i}"
      v1.vm.synced_folder ".", "/vagrant", owner: "vagrant", group: "vagrant"
      #v1.vm.network "private_network", type: "dhcp"
      if (STORAGE=="consul") then
         v1.vm.provision "shell", path: "scripts/setupConsulServer.sh", env: {'STORAGE_CONSUL' => STORAGE ,'TF_VER' => TF_VER,'CONSUL_VER' => CONSUL_VER, 'VAULT_VER' => VAULT_VER, 'HOST' => "v-dr-#{i}"}
      end
      v1.vm.provision "shell", path: "scripts/setupPrimVaultServer.sh", env: {'STORAGE_CONSUL' => STORAGE , 'TF_VER' => TF_VER, 'VAULT_VER' => VAULT_VER, 'HOST' => "v-dr-#{i}"}
    end
  end

end


Vagrant.configure("2") do |config|
  config.vm.box = "starboard/ubuntu-arm64-20.04.5"
  config.vm.box_version = "20221120.20.40.0"
  config.vm.box_download_insecure = true
  #config.vm.network :private_network, auto_config: true

  (1..VAULT_NUM_PR_INSTANCES.to_i).each do |i|
    config.vm.provider "vmware_desktop" do |vmware|
        vmware.allowlist_verified = true
        vmware.vmx["ethernet0.pcislotnumber"] = "160"
        vmware.ssh_info_public = true
        vmware.linked_clone = false
        vmware.gui = true
        vmware.vmx["ethernet0.virtualdev"] = "e1000e"
        #print (vmware)
    end
    config.vm.define "vault-pr#{i}" do |v1|
      v1.vm.hostname = "v-pr-#{i}"
      v1.vm.synced_folder ".", "/vagrant", owner: "vagrant", group: "vagrant"
      #v1.vm.network "private_network", type: "dhcp"
      if (STORAGE=="consul") then
         v1.vm.provision "shell", path: "scripts/setupConsulServer.sh", env: {'STORAGE_CONSUL' => STORAGE ,'TF_VER' => TF_VER,'CONSUL_VER' => CONSUL_VER, 'VAULT_VER' => VAULT_VER, 'HOST' => "v-pr-#{i}"}
      end
      v1.vm.provision "shell", path: "scripts/setupPrimVaultServer.sh", env: {'STORAGE_CONSUL' => STORAGE , 'TF_VER' => TF_VER, 'VAULT_VER' => VAULT_VER, 'HOST' => "v-pr-#{i}"}
    end
  end

end
