#!/bin/bash

# Bash shell script for generating self-signed certs. 

export PRIVATEKEY="mytls.key"
export PUBLICKEY="mytls.crt"

# Generate the server private and public key. good for 10 years 
openssl req -x509 -days 3650 -nodes -newkey rsa:4096 -keyout "$PRIVATEKEY" -out "$PUBLICKEY" -subj "/CN=sealed-secret/O=sealed-secret"


mv mytls.crt mytls.key ../terraform/k8s-helm/keys