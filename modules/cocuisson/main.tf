# contains the resources necessary for cocuisson mvp

resource "azurerm_private_dns_zone" "shared_services_private_zone" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = var.resourcegroup_name

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_virtual_network" "private_resource_vnet" {

  name = "private-resource-vnet"
  depends_on = [
    azurerm_private_dns_zone.shared_services_private_zone
  ]
  location            = var.location
  resource_group_name = var.resourcegroup_name
  address_space       = ["10.0.0.0/27"]

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_subnet" "function_subnet" {
  name = "function-subnet"
  depends_on = [
    azurerm_virtual_network.private_resource_vnet
  ]
  resource_group_name  = var.resourcegroup_name
  virtual_network_name = azurerm_virtual_network.private_resource_vnet.name
  address_prefixes     = ["10.0.0.0/28"]

  enforce_private_link_service_network_policies = true
}

resource "azurerm_subnet" "private_endpoint_subnet" {
  name = "private-endpoint-subnet"
  depends_on = [
    azurerm_virtual_network.private_resource_vnet
  ]
  resource_group_name  = var.resourcegroup_name
  virtual_network_name = azurerm_virtual_network.private_resource_vnet.name
  address_prefixes     = ["10.0.0.16/28"]

  enforce_private_link_service_network_policies = true
}

resource "azurerm_private_dns_zone_virtual_network_link" "shared_services_link" {
  name                  = "shared-services-link"
  resource_group_name   = var.resourcegroup_name
  private_dns_zone_name = azurerm_private_dns_zone.shared_services_private_zone.name
  virtual_network_id    = azurerm_virtual_network.private_resource_vnet.id
  registration_enabled  = true

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_service_plan" "cocuisson_asp" {
  name                = "${var.project_name}-sp"
  location            = var.location
  resource_group_name = var.resourcegroup_name
  os_type             = "Linux"
  sku_name            = "P1v2"

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_storage_account" "api_sa" {
  name                     = "${var.project_name}sa"
  resource_group_name      = var.resourcegroup_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_application_insights" "app_insights" {
  name                = "api-insights"
  location            = var.location
  resource_group_name = var.resourcegroup_name
  application_type    = "other"

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_linux_function_app" "cosmos_crud_api" {
  name = "cosmos-crud-api"
  depends_on = [
    azurerm_storage_account.api_sa
  ]
  location                    = var.location
  resource_group_name         = var.resourcegroup_name
  service_plan_id             = azurerm_service_plan.cocuisson_asp.id
  storage_account_name        = azurerm_storage_account.api_sa.name
  storage_account_access_key  = azurerm_storage_account.api_sa.primary_access_key
  functions_extension_version = "~4"
  https_only                  = true
  tags = {
    project = var.project_name
    env     = var.env_name
  }

  site_config {
    application_stack {
      python_version = "3.9"
    }
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.app_insights.instrumentation_key
    "MONGO_DB_URL"                   = var.mongo_url
  }
}

resource "azurerm_private_endpoint" "cosmos_crud_api_pve" {
  name                = "cosmos-crud-api-pve"
  location            = var.location
  resource_group_name = var.resourcegroup_name
  subnet_id           = azurerm_subnet.function_subnet.id

  private_dns_zone_group {
    name                 = "privatednszonegroup"
    private_dns_zone_ids = [azurerm_private_dns_zone.shared_services_private_zone.id]
  }

  private_service_connection {
    name                           = "${azurerm_linux_function_app.cosmos_crud_api.name}-private-service-connection"
    private_connection_resource_id = azurerm_linux_function_app.cosmos_crud_api.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_virtual_network" "external_api_vnet" {

  name                = "external-api-vnet"
  location            = var.location
  resource_group_name = var.resourcegroup_name
  address_space       = ["10.1.0.0/25"]

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_subnet" "cocuisson_subnet" {
  name = "cocuisson-subnet"
  depends_on = [
    azurerm_virtual_network.external_api_vnet
  ]
  resource_group_name  = var.resourcegroup_name
  virtual_network_name = azurerm_virtual_network.external_api_vnet.name
  address_prefixes     = ["10.1.0.0/26"]

}

resource "azurerm_subnet" "management_subnet" {
  name = "management-subnet"
  depends_on = [
    azurerm_virtual_network.external_api_vnet
  ]
  resource_group_name  = var.resourcegroup_name
  virtual_network_name = azurerm_virtual_network.external_api_vnet.name
  address_prefixes     = ["10.1.0.64/26"]

}

resource "azurerm_network_security_group" "apim_nsg" {
  name                = "cocuisson-apim-nsg"
  location            = var.location
  resource_group_name = var.resourcegroup_name

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_network_security_rule" "rule_1" {
  name                        = "allow-in-any-to-vnet"
  priority                    = 3900
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resourcegroup_name
  network_security_group_name = azurerm_network_security_group.apim_nsg.name
}

resource "azurerm_network_security_rule" "rule_2" {
  name                        = "allow-in-apim-to-vnet"
  priority                    = 3800
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3443"
  source_address_prefix       = "ApiManagement"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resourcegroup_name
  network_security_group_name = azurerm_network_security_group.apim_nsg.name
}

resource "azurerm_network_security_rule" "rule_3" {
  name                        = "allow-in-azlb-to-vnet"
  priority                    = 3700
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6390"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resourcegroup_name
  network_security_group_name = azurerm_network_security_group.apim_nsg.name
}

resource "azurerm_network_security_rule" "rule_4" {
  name                        = "allow-out-vnet-to-storage"
  priority                    = 3600
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "Storage"
  resource_group_name         = var.resourcegroup_name
  network_security_group_name = azurerm_network_security_group.apim_nsg.name
}

resource "azurerm_network_security_rule" "rule_5" {
  name                        = "allow-out-vnet-to-sql"
  priority                    = 3500
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "SQL"
  resource_group_name         = var.resourcegroup_name
  network_security_group_name = azurerm_network_security_group.apim_nsg.name
}

resource "azurerm_network_security_rule" "rule_6" {
  name                        = "allow-out-vnet-to-kvl"
  priority                    = 3400
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "AzureKeyVault"
  resource_group_name         = var.resourcegroup_name
  network_security_group_name = azurerm_network_security_group.apim_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "apim_nsg_association" {
  subnet_id                 = azurerm_subnet.management_subnet.id
  network_security_group_id = azurerm_network_security_group.apim_nsg.id
}

resource "azurerm_api_management" "cocuisson_apim" {
  name = "cocuisson-apim"
  depends_on = [
    azurerm_subnet_network_security_group_association.apim_nsg_association
  ]
  location            = var.location
  resource_group_name = var.resourcegroup_name
  publisher_name      = "ONAIDE ASBL"
  publisher_email     = "onaide-asbl@outlook.com"

  sku_name = "Developer_1"

  identity {
    type = "SystemAssigned"
  }
  virtual_network_type = "External"
  virtual_network_configuration {
    subnet_id = azurerm_subnet.management_subnet.id
  }

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_linux_function_app" "shared_private_services" {
  name = "shared-private-services"
  depends_on = [
    azurerm_storage_account.api_sa,
    azurerm_api_management.cocuisson_apim
  ]
  location                    = var.location
  resource_group_name         = var.resourcegroup_name
  service_plan_id             = azurerm_service_plan.cocuisson_asp.id
  storage_account_name        = azurerm_storage_account.api_sa.name
  storage_account_access_key  = azurerm_storage_account.api_sa.primary_access_key
  functions_extension_version = "~4"
  https_only                  = true
  tags = {
    project = var.project_name
    env     = var.env_name
  }

  site_config {
    application_stack {
      python_version = "3.9"
    }
    ip_restriction {
      ip_address = join("",concat(azurerm_api_management.cocuisson_apim.public_ip_addresses,["/32"]))
    }
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.app_insights.instrumentation_key
    "API_BASE_URL" = "https://cosmos-crud-api.azurewebsites.net/api/"
  }
}

resource "azurerm_api_management_backend" "atelier_registration_backend" {
  name = "atelier-registration-backend"
  depends_on = [
    azurerm_linux_function_app.shared_private_services
  ]
  resource_group_name = var.resourcegroup_name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  protocol            = "http"
  url                 = "https://shared-private-services.azurewebsites.net/api/belgian-atelier"
}

resource "azurerm_api_management_api" "atelier_registration_api" {
  name                = "atelier-registration-api"
  resource_group_name = var.resourcegroup_name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  revision            = "1"
  display_name        = "Atelier Registration API"
  protocols           = ["https"]

  service_url = "https://shared-private-services.azurewebsites.net/api"
}

resource "azurerm_api_management_api_operation" "atelier_registration_api_op" {
  operation_id        = "belgian-atelier"
  api_name            = azurerm_api_management_api.atelier_registration_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Register Belgian Atelier"
  method              = "POST"
  url_template        = "/belgian-atelier"
  description         = "This registers a new Belgian Atelier on the platform"

  response {
    status_code = 200
  }
}
