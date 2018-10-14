#!/bin/bash

. demo-magic.sh

RG=ignite-demo
K8S_NAME=ignite-demo
location=eastus
MC_RG=MC_ignite-demo_ignite-demo_eastus
keyvault_name=aksignitekv
secret_name=testsecret
secret=secret.txt
tenant_id=$(az account show --query tenantId -o tsv)
SUB_ID=$(az account show | jq -r .id)

# If running all commands, place after creating the identity
# If running at start, make sure to have the script ready before time (so that these commands run) 
principalid=$(az identity show --name demo-aad1 --resource-group ${MC_RG} --query 'principalId' -o tsv)

client_id=$(az identity show -n demo-aad1 -g ${MC_RG} | jq -r .clientId)

resource_id=$(az identity show -n demo-aad1 -g ${MC_RG} | jq -r .id)

pe "clear"


## Create RG
# p "az group create -n ${RG} -l ${location}"
# cat rg_create.txt


## Create AKS
# p "az aks create -n ${K8S_NAME} -g ${RG} -l ${location} -c 1"
# cat aks_create.txt

## Get Credentials
# pe "az aks get-credentials --resource-group $RG --name $K8S_NAME"

## Get MC_RG if running the full script
# pe "export MC_RG=az group list | jq -r .name | grep MC_${RG} 


## Get nodes
pe "kubectl get nodes"


## Create KeyVault and add secret (printed-only to save time)
p "az keyvault create --resource-group ${MC_RG} --name ${keyvault_name} --location ${location}"
cat keyvault_create.txt
pe "clear"

p "az keyvault secret set --vault-name ${keyvault_name} --name ${secret_name} --file ${secret}"
cat keyvault_secret_create.txt
pe "clear"


## Deploy KeyVault Flexvolume
pe "kubectl apply -f deploy/infra/kv-flexvol-installer.yaml"

pe "kubectl get pods -n kv"

## Deploy Pod Identity Infra
pe "kubectl apply -f deploy/infra/deployment-rbac.yaml"
pe "clear"


## Create an Azure User Identity (printed-only to save time, if set to run make sure to change the variables above)

p "az identity create --name demo-aad1 --resource-group ${MC_RG}"
cat create_identity.txt
pe "clear"


# Assign Reader Role to new Identity for your keyvault
pe "az role assignment create --role Reader --assignee $principalid --scope /subscriptions/$SUB_ID/resourcegroups/${MC_RG}/providers/Microsoft.KeyVault/vaults/$keyvault_name"


## Assign Policy to KeyVault
pe "az keyvault set-policy -n $keyvault_name --secret-permissions get list --spn $client_id" 


## Deploy  identity to k8s
file="deploy/demo/aadpodidentity.yaml"

perl -pi -e "s/CLIENT_ID/${client_id}/" ${file}
perl -pi -e "s/RESOURCE_ID/${resource_id//\//\\/}/" ${file}


pe "vim ${file}"
pe "kubectl apply -f ${file}"



## Deploy binding to k8s
file="deploy/demo/aadpodidentitybinding.yaml"

pe "vim ${file}"

pe "kubectl apply -f ${file}"


## Deploy demo app
file="deploy/demo/nginx-flex-kv-podidentity.yaml"


perl -pi -e "s/KEYVAULT_NAME/${keyvault_name}/" ${file}
perl -pi -e "s/SECRET_NAME/${secret_name}/" ${file}
perl -pi -e "s/RESOURCE_GROUP/${MC_RG}/" ${file}
perl -pi -e "s/SECRET_VERSION/testversion/" ${file}
perl -pi -e "s/SUB_ID/${SUB_ID}/" ${file}
perl -pi -e "s/TENANT_ID/${tenant_id}/" ${file}

pe "vim ${file}"

pe "kubectl apply -f ${file}"

pe "kubectl get pods"

pe "kubectl exec -it nginx-flex-kv-podid cat /kvmnt/testsecret"

## Clean up tasks
az role assignment delete --assignee $principalid --scope /subscriptions/$SUB_ID/resourcegroups/${MC_RG}/providers/Microsoft.KeyVault/vaults/$keyvault_name

kubectl delete pod nginx-flex-kv-podid > /dev/null

# if runnig the whole script
# az identity delete --ids ${resource_id}
# az keyvault secret delete --name ${secret_name} --vault-name ${keyvault_name}
# az keyvault delete -n ${keyvault_name} -g ${MC_RG}

# az group delete -y --no-wait -n ${RG}
