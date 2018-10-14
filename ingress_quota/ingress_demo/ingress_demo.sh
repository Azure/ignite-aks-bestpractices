#!/usr/bin/env bash
cd ~/OneDrive\ -\ Microsoft/ignite/ingress_demo/
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
clear

#switch context to aksdemo cluster
kctx aksdemo-westeurope
pe "kns default"

#show your ingress and the tls certificate 
pe "kubectl get deployment nginx-ingress"


#show the service
pe "kubectl get svc nginx-ingress"

#create the cafe application
pe "kubectl apply -f cafe.yaml"

#check if everything is working, note there is no need for an external IP here, Ingress will handle this for you
pe "kubectl get deployment coffee tea"
pe "kubectl get svc tea-svc coffee-svc"


#create the secret for the TLS cert
pe "kubectl apply -f cafe-secret.yaml"

#create the ingress resource
pe "kubectl apply -f cafe-ingress.yaml"

#create the record in DNS 
pe "dig +short cafe.linux-jo.com"

#check the domain
pe "curl -k https://cafe.linux-jo.com/tea"
pe "curl -k https://cafe.linux-jo.com/tea"
pe "curl -k https://cafe.linux-jo.com/tea"
pe "curl -k https://cafe.linux-jo.com/coffee"


#delete everything
pe "kubectl delete -f ."
