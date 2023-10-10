# vault_vagrant
full raft cluster 

### notes about the variables used for spining up Vault on Vagrant
VAULT_NUM_INSTANCES - Number of Vault instances needed to be spun up
CONSUL_VERSION - Specify the version of Consul that needs to be spun up.  - https://releases.hashicorp.com/consul/
  STORAGE=consul - This needs to be specified when Vault needs to know Consul is the storage backend
VAULT_VER - Specify the version of Consul that needs to be spun up - Should match the folder under - https://releases.hashicorp.com/vault/

### to spin up a vault node with Consul as the storage backend
VAULT_NUM_INSTANCES=1 CONSUL_VER="1.13.0+ent" VAULT_VER="1.15.0+ent" STORAGE=consul vagrant up

### to spin up a vault node with Raft as the storage backend
VAULT_NUM_INSTANCES=1 VAULT_VER="1.15.0+ent" vagrant up

### To create TLS certs for Vault with TLS enabled - follow the below notes
- Create certs via tls.tf (with thanks to https://github.com/martinhristov90/Terraform_PKI) into a /certs folder
- Add AWS KMS deets to the vard in the Vagrant file that are presently set to "...."
- Ignore the consul stuff, it wont work
- Comment in and out clusters as needed (recomended to leave as 2 unless required to aid in rebuilds)
- Set required vault ver in Vagrantfile var (it will grab it from the repo for you if you dont have it in vault builds folder)
