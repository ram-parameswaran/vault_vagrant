# -*- mode: ruby -*-
# vi: set ft=ruby :

### Define environment variables to pass on to provisioner

# Helper to get latest enterprise version (excluding RC)
def get_latest_ent_version(product)
  require 'net/http'
  require 'json'
  require 'uri'
  
  url = URI("https://releases.hashicorp.com/#{product}/index.json")
  begin
    # Use Net::HTTP instead of URI.open (CVE-2021-31799 mitigation)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.open_timeout = 10
    http.read_timeout = 10
    
    request = Net::HTTP::Get.new(url)
    response = http.request(request)
    
    return nil unless response.code == '200'
    
    data = JSON.parse(response.body)
    versions = data['versions'].keys
                   .select { |v| v.include?('+ent') && !v.include?('-rc') && !v.include?('-beta') && !v.include?('-alpha') }
                   .sort_by { |v| Gem::Version.new(v.split('+').first) }
    versions.last
  rescue StandardError => e
    warn "Warning: Could not fetch latest #{product} version: #{e.message}"
    nil
  end
end

# Define Vault version
VAULT_VER = ENV['VAULT_VER'] || ""

# Define Consul version - fetch latest enterprise if not specified
CONSUL_VER = ENV['CONSUL_VER'] || get_latest_ent_version('consul') || "1.19.1+ent"

# Define Terraform version
TF_VER = ENV['TF_VER'] || ""

VAULT_NUM_INSTANCES = ENV['VAULT_NUM_INSTANCES'] || '1'
VAULT_NUM_DR_INSTANCES = ENV['VAULT_NUM_DR_INSTANCES'] || '0'
VAULT_NUM_PR_INSTANCES = ENV['VAULT_NUM_PR_INSTANCES'] || '0'

STORAGE = ENV['STORAGE'] || ''

# Helper method to configure Vault instances
def configure_vault_instance(config, name_prefix, hostname_prefix, count)
  (1..count.to_i).each do |i|
    vm_name = name_prefix.empty? ? "vault#{i}" : "vault-#{name_prefix}#{i}"
    hostname = "#{hostname_prefix}#{i}"
    
    config.vm.define vm_name do |v|
      v.vm.hostname = hostname
      v.vm.synced_folder ".", "/vagrant", owner: "vagrant", group: "vagrant"
      
      # Provision Consul if needed
      if STORAGE == "consul"
        v.vm.provision "shell", path: "scripts/setupConsulServer.sh",
          env: {'STORAGE_CONSUL' => STORAGE, 'TF_VER' => TF_VER, 'CONSUL_VER' => CONSUL_VER,
                'VAULT_VER' => VAULT_VER, 'HOST' => hostname}
      end
      
      # Provision Vault
      v.vm.provision "shell", path: "scripts/setupPrimVaultServer.sh",
        env: {'STORAGE_CONSUL' => STORAGE, 'TF_VER' => TF_VER, 'VAULT_VER' => VAULT_VER,
              'HOST' => hostname}
    end
  end
end

Vagrant.configure("2") do |config|
  config.vm.box = "starboard/ubuntu-arm64-20.04.5"
  config.vm.box_version = "20221120.20.40.0"
  config.vm.box_download_insecure = true
  
  # VMware provider settings
  config.vm.provider "vmware_desktop" do |vmware|
    vmware.allowlist_verified = true
    vmware.vmx["ethernet0.pcislotnumber"] = "160"
    vmware.ssh_info_public = true
    vmware.linked_clone = false
    vmware.gui = true
    vmware.vmx["ethernet0.virtualdev"] = "e1000e"
  end
  
  # Configure all instance types
  configure_vault_instance(config, "", "v", VAULT_NUM_INSTANCES)        # Primary: vault1, vault2, etc.
  configure_vault_instance(config, "dr", "v-dr-", VAULT_NUM_DR_INSTANCES)  # DR: vault-dr1, vault-dr2, etc.
  configure_vault_instance(config, "pr", "v-pr-", VAULT_NUM_PR_INSTANCES)  # PR: vault-pr1, vault-pr2, etc.
end
