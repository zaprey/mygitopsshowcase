# mygitopsrepo


To start install script: bash ./scripts/install.sh up

Sealed secrets you need to generate a secret with your kubeconfig file to the target cluster:

kubectl create secret generic cluster-config  --from-literal=kubeconfig="`cat ./.kube/config`" --dry-run -o yaml > cluster-config.yaml
kubeseal -n dev --controller-namespace argocd < cluster-config.yaml > cluster-config.json


# To generate a sealed secret we first generate a normal k8s secret
json file example {
    key: "value"
}
kubectl create secret generic mytoken -n example-namespace --from-file=./example.json -o json > mysecret.json

kubeseal --controller-namespace example-namespace  <mysecret.json >mysealedsecret.json


# To get password for argocd ui
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d



# Create your secrets and base64 encode your variables 
echo -n 'token' | base64
---
apiVersion: v1
kind: Secret
metadata:
  name: mytokens
type: Opaque
data:
  API_TOKEN: YWRtaW4=
  FLASK_SECRET_KEY: MWYyZDFlMmU2N2Rm
---
# create sealed secret 
 kubeseal -f secret.yaml -w sample-sealed-secret.yaml \
   --controller-namespace argocd \
   --scope cluster-wide 


# Seal with self made public key

kubeseal --cert "./mytls.crt" --scope cluster-wide < mysecret.yaml -o yaml > mysealedsecret.yaml