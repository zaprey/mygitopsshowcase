
# ArgoCD Installation

# (1)
resource "helm_release" "argocd" {
  chart            = "argo-cd"
  name             = "argocd"
  namespace        = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  create_namespace = true
    set {
    name  = "server.service.type"
    value = "NodePort"
  }
}
# (2)
# Sealed-secret-key for encryption needs to be in the same namespace as the sealed secret controller
resource "kubernetes_secret" "sealed-secrets-key" {
  depends_on = [helm_release.argocd]
  metadata {
    name      = "sealed-secrets-key"
    namespace = "argocd"
  }
  data = {
    "tls.crt" = file("keys/mytls.crt")
    "tls.key" = file("keys/mytls.key")
  }
  type = "kubernetes.io/tls"
}

# (3)
resource "helm_release" "argocd-apps" {
  depends_on = [helm_release.argocd]
  chart      = "argocd-apps"
  name       = "argocd-apps"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"

  # (4)
  values = [
    file("../../argocd/terraform/applications.yaml")  
  ]
}