#!/bin/bash

. demo-magic.sh

RG=ignite-demo
K8S_NAME=ignite-demo
LOCATION=eastus
MC_RG=MC_ignite-demo_eastus

pe "clear"


# Create Resource group
p "az group create -n ${RG} -l ${LOCATION}"
cat rg-create-log.txt

# Create AKS 
p "az aks create --resource-group $RG --name $K8S_NAME --node-count 1 --generate-ssh-keys"
cat aks-create-log-running.txt
cat aks-create-log.txt

# Get Credentials
pe "az aks get-credentials --resource-group $RG --name $K8S_NAME"

# Deploy necessary components
pe "cat deploy/infra/deployment.yaml"

pe "kubectl apply -f deploy/infra/deployment-rbac.yaml"

pe "export SUB_ID=$(az account show --query id -o tsv | tee /dev/tty)" 

# Create Azure identity
pe "export principalid=$(az identity create --name demo-aad1 --resource-group $MC_RG --query 'principalId' -o tsv)"

pe "az role assignment create --role Reader --assignee $principalid --scope /subscriptions/$SUB_ID/resourcegroups/$MC_RG"


# Deploy Demo
pe "export client_id=$(az identity show -n demo-aad1 -g ${MC_RG} | jq -r .clientId)"

pe "export subscription_id=$(az account show | jq -r .id)"

file="deploy/demo/deployment.yaml"

perl -pi -e "s/CLIENT_ID/${client_id}/" ${file}
perl -pi -e "s/SUBSCRIPTION_ID/${subscription_id}/" ${file}
perl -pi -e "s/RESOURCE_GROUP/${MC_RG}/" ${file}

pe "kubectl apply -f $file"


# Deploy Id to Kubernetes

pe "resource_id=$(az identity show -n demo-aad1 -g ${MC_RG} | jq -r .id)"

file="deploy/demo/aadpodidentity.yaml"

perl -pi -e "s/CLIENT_ID/${client_id}/" ${file}
perl -pi -e "s/RESOURCE_ID/${resource_id//\//\\/}/" ${file}

pe "kubectl apply -f ${file}"


# Deploy Binding to k8s
pe "kubectl apply -f deploy/demo/aadpodidentitybinding.yaml"

