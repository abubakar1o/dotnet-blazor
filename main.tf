# main.tf

provider "azurerm" {
  features {}

  client_id       = "your-appId"
  client_secret   = "your-password"
  subscription_id = "941c8a6b-7af5-43e0-ad0f-e7a9489547b4"
}

# Resource group
resource "azurerm_resource_group" "rg" {
  name     = "Dev-Testing"
  location = "East US (Zone 1)"
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "myAKSCluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "myakscluster"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    dns_service_ip = "10.2.0.10"
    service_cidr   = "10.2.0.0/24"
    docker_bridge_cidr = "172.17.0.1/24"
  }
}

# Get the credentials for the AKS cluster
resource "null_resource" "kubeconfig" {
  provisioner "local-exec" {
    command = "az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name}"
  }
}

# Kubernetes Provider
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

# Namespace
resource "kubernetes_namespace" "dotnet" {
  metadata {
    name = "dotnet"
  }
}

# Deployment of the .NET application
resource "kubernetes_deployment" "dotnet_app" {
  metadata {
    name      = "dotnet-app"
    namespace = kubernetes_namespace.dotnet.metadata[0].name
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "dotnet-app"
      }
    }
    template {
      metadata {
        labels = {
          app = "dotnet-app"
        }
      }
      spec {
        container {
          name  = "dotnet-app"
          image = "mycontainerregistry.azurecr.io/my-dotnet-app:latest"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# Service for the .NET application
resource "kubernetes_service" "dotnet_service" {
  metadata {
    name      = "dotnet-service"
    namespace = kubernetes_namespace.dotnet.metadata[0].name
  }
  spec {
    selector = {
      app = "dotnet-app"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}
