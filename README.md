# vault_vagrant
full raft/consul Vault

# pre-reqs
- To be able to run Enterprise versions of Vault and Consul, request license from [Sales](https://www.hashicorp.com/contact-sales?interest=vault).
- Save the license files for Vault as `vault.license` and/or Consul as `consul.license` and place them in same folder as this README file.

### notes about the variables used for spining up Vault on Vagrant
1. VAULT_NUM_INSTANCES - Number of Vault instances needed to be spun up - Defaults to 1
2. VAULT_VER - Specify the version of Vault that needs to be installed - Should match the folder under - https://releases.hashicorp.com/vault/ - Defaults to 1.15.2+ent if no value specified
3. CONSUL
   - CONSUL_VER - Specify the version of Vault that needs to be installed - Should match the folder under - https://releases.hashicorp.com/consul/ - Defaults to 1.17.0+ent
   - STORAGE=consul - This needs to be specified when Vault needs to know Consul is the storage backend. Defaults to raft if no value is specified
4. TF_VER - Specify the version of Terraform that needs to be installed - Should match the folder under - https://releases.hashicorp.com/terraform/ - Defaults to 1.6.4 if no value specified

### to spin up a vault node with Consul as the storage backend
- STORAGE=consul vagrant up

### to spin up a vault node with Raft as the storage backend
- vagrant up

### To create TLS certs for Vault with TLS enabled - follow the below notes
- Create certs via terraform/tls.tf (with thanks to https://github.com/martinhristov90/Terraform_PKI) into a /certs folder
  
