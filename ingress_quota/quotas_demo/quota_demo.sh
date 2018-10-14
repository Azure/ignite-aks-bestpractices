#!/usr/bin/env bash

########################
# include the magic
########################
. demo-magic.sh

#
# speed at which to simulate typing. bigger num = faster
#
TYPE_SPEED=20

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# hide the evidence
#clear

#switch context to aksdemo cluster
#kctx aksdemo-westeurope


#create a name space
pe "kubectl create namespace ignite"

#describe the namespace
pe "kubectl describe namespace ignite"

#change context to the ingite namespace
pe "kns ignite"

#apply the compute and objects quotas
pe "kubectl create -f ignite_compute_resources.yaml"

#query and describe the quotas
pe "kubectl describe namespace ignite"

#create a pod with no quote
pe "kubectl create -f nginx_noquote.yaml"

#create a deployment with quota applied
pe "kubectl create -f nginx_quota_dep.yaml"
pe "kubectl get pods"
pe "kubectl describe namespace ignite"

#clean up everything
pe "kubectl delete -f ."
kubectl delete namespace ignite
