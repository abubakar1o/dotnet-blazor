# outputs.tf

output "kube_config" {
  value = azurerm_kubernetes_cluster.aks.kube_config_raw
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}
