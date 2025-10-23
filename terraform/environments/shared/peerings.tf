resource "azurerm_virtual_network_peering" "shared_to_dev" {
  name                      = "shared-to-dev"
  resource_group_name       = data.azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.shared.name
  remote_virtual_network_id = data.terraform_remote_state.dev.outputs.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

resource "azurerm_virtual_network_peering" "dev_to_shared" {
  name                      = "dev-to-shared"
  resource_group_name       = data.azurerm_resource_group.main.name
  virtual_network_name      = data.terraform_remote_state.dev.outputs.vnet_name
  remote_virtual_network_id = azurerm_virtual_network.shared.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

# resource "azurerm_virtual_network_peering" "shared_to_staging" {
#   name                      = "shared-to-staging"
#   resource_group_name       = data.azurerm_resource_group.main.name
#   virtual_network_name      = azurerm_virtual_network.shared.name
#   remote_virtual_network_id = data.terraform_remote_state.staging.outputs.vnet_id

#   allow_virtual_network_access = true
#   allow_forwarded_traffic      = true
#   allow_gateway_transit        = false
# }

# resource "azurerm_virtual_network_peering" "staging_to_shared" {
#   name                      = "staging-to-shared"
#   resource_group_name       = data.azurerm_resource_group.main.name
#   virtual_network_name      = data.terraform_remote_state.staging.outputs.vnet_name
#   remote_virtual_network_id = azurerm_virtual_network.shared.id

#   allow_virtual_network_access = true
#   allow_forwarded_traffic      = true
#   allow_gateway_transit        = false
# }

# resource "azurerm_virtual_network_peering" "shared_to_prod" {
#   name                      = "shared-to-prod"
#   resource_group_name       = data.azurerm_resource_group.main.name
#   virtual_network_name      = azurerm_virtual_network.shared.name
#   remote_virtual_network_id = data.terraform_remote_state.prod.outputs.vnet_id

#   allow_virtual_network_access = true
#   allow_forwarded_traffic      = true
#   allow_gateway_transit        = false
# }

# resource "azurerm_virtual_network_peering" "prod_to_shared" {
#   name                      = "prod-to-shared"
#   resource_group_name       = data.azurerm_resource_group.main.name
#   virtual_network_name      = data.terraform_remote_state.prod.outputs.vnet_name
#   remote_virtual_network_id = azurerm_virtual_network.shared.id

#   allow_virtual_network_access = true
#   allow_forwarded_traffic      = true
#   allow_gateway_transit        = false
# }
