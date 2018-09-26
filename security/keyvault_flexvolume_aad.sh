#!/bin/bash

. demo-magic.sh

RG=ignite-demo
K8S_NAME=ignite-demo
LOCATION=eastus
MC_RG=MC_ignite-demo_ignite-demo_eastus
keyvault_name=aksignitekv
secret_name=testsecret

pe "clear"


# Get Credentials
pe "az aks get-credentials --resource-group $RG --name $K8S_NAME"

# Get nodes
pe "kubectl get nodes"


# Create KeyVault
p "az keyvault create --resource-group $MC_RG --name aksignitekv --location eastus"

p "az keyvault secret set --vault-name aksignitekv --name testsecret --file secret.txt"


# Deploy KeyVault Flexvolume
pe "kubectl create -f deploy/infra/kv-flexvol-installer.yaml"

pe "kubectl get pods -n kv"

# Deploy Pod Identity Infra
pe "kubectl create -f deploy/infra/deployment-rbac.yaml"

SUB_ID=$(az account show | jq -r .id)

# Create an Azure User Identity 

pe "export principalid=$(az identity create --name demo-aad1 --resource-group $MC_RG --query 'principalId' -o tsv)"

# Assign Reader role to the MC RG
az role assignment create --role Reader --assignee $principalid --scope /subscriptions/$SUB_ID/resourcegroups/$MC_RG


# Assign Reader Role to new Identity for your keyvault
pe "az role assignment create --role Reader --assignee $principalid --scope /subscriptions/$SUB_ID/resourcegroups/$MC_RG/providers/Microsoft.KeyVault/vaults/$keyvault_name"




# Deploy  identity to k8s
client_id=$(az identity show -n demo-aad1 -g ${MC_RG} | jq -r .clientId)

resource_id=$(az identity show -n demo-aad1 -g ${MC_RG} | jq -r .id)

file="deploy/demo/aadpodidentity.yaml"

perl -pi -e "s/CLIENT_ID/${client_id}/" ${file}
perl -pi -e "s/RESOURCE_ID/${resource_id//\//\\/}/" ${file}


pe "vim ${file}"
pe "kubectl apply -f ${file}"



# Deploy binding to k8s
pe "vim deploy/demo/aadpodidentitybinding.yaml"

pe "kubectl apply -f deploy/demo/aadpodidentitybinding.yaml"




# Deploy demo app
file="deploy/demo/nginx-flex-kv-podidentity.yaml"

tenant_id=$(az account show --query tenantId)

perl -pi -e "s/KEYVAULT_NAME/${keyvault_name}/" ${file}
perl -pi -e "s/SECRET_NAME/${secret_name}/" ${file}
perl -pi -e "s/RESOURCE_GROUP/${MC_RG}/" ${file}
perl -pi -e "s/SECRET_VERSION/testversion/" ${file}
perl -pi -e "s/SUB_ID/${SUB_ID}/" ${file}
perl -pi -e "s/TENANT_ID/${tenant_id}/" ${file}

pe "vim deploy/demo/nginx-flex-kv-podidentity.yaml"

pe "kubectl apply -f deploy/demo/nginx-flex-kv-podidentity.yaml"


#Validate the pod has access to the secret from key vault
pe "kubectl exec -it nginx-flex-kv-podid cat /kvmnt/testsecret"