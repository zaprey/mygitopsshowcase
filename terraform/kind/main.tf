provider "kind" {}


locals {
    k8s_config_path = pathexpand("~/.kube/config")
}

resource "kind_cluster" "default" {
    name           = "mygitopscluster"
    wait_for_ready = true

  kind_config {
      kind        = "Cluster"
      api_version = "kind.x-k8s.io/v1alpha4"

      node {
          role = "control-plane"

          kubeadm_config_patches = [
              "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\"\n"
          ]

          extra_port_mappings {
              container_port = 80
              host_port      = 80
          }
          extra_port_mappings {
              container_port = 443
              host_port      = 443
          }
              extra_port_mappings {
              container_port = 30443
              host_port      = 9443

      }
              extra_port_mappings {
              container_port = 32001
              host_port      = 9501

      }


  }
}
}