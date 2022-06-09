# contains the resources necessary for cocuisson mvp

resource "azurerm_private_dns_zone" "function_apis_private_zone" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = var.resourcegroup_name

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_private_dns_zone" "cosmos_db_private_zone" {
  name                = "privatelink.mongo.cosmos.azure.com"
  resource_group_name = var.resourcegroup_name

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

/* resource "azurerm_private_dns_zone" "cosmos_db_private_zone_2" {
  name                = "privatelink.documents.azure.com"
  resource_group_name = var.resourcegroup_name

  tags = {
    project = var.project_name
    env     = var.env_name
  }
} */

resource "azurerm_virtual_network" "private_resource_vnet" {

  name = "private-resource-vnet"
  depends_on = [
    azurerm_private_dns_zone.function_apis_private_zone
  ]
  location            = var.location
  resource_group_name = var.resourcegroup_name
  address_space       = ["10.0.0.0/27"]

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_subnet" "private_resources_subnet" {
  name = "private-resources-subnet"
  depends_on = [
    azurerm_virtual_network.private_resource_vnet
  ]
  resource_group_name  = var.resourcegroup_name
  virtual_network_name = azurerm_virtual_network.private_resource_vnet.name
  address_prefixes     = ["10.0.0.0/29"]

  enforce_private_link_service_network_policies = true
}

resource "azurerm_subnet" "cosmos_crud_api_subnet" {
  name = "cosmos-crud-api-subnet"
  depends_on = [
    azurerm_virtual_network.private_resource_vnet
  ]
  resource_group_name  = var.resourcegroup_name
  virtual_network_name = azurerm_virtual_network.private_resource_vnet.name
  address_prefixes     = ["10.0.0.8/29"]

  enforce_private_link_service_network_policies = true

  delegation {
    name = "cocuisson-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

  service_endpoints = ["Microsoft.Storage"]
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

resource "azurerm_network_security_group" "cosmos_crud_api_nsg" {
  name                = "cosmos-crud-api-nsg"
  location            = var.location
  resource_group_name = var.resourcegroup_name

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_network_security_rule" "rule_1_cosmos_crud_api" {
  name                        = "allow-out-vnet-to-cosmos"
  priority                    = 3900
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["10250", "10255", "10256"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "AzureCosmosDB"
  resource_group_name         = var.resourcegroup_name
  network_security_group_name = azurerm_network_security_group.cosmos_crud_api_nsg.name
}

resource "azurerm_network_security_rule" "rule_2_cosmos_crud_api" {
  name                        = "allow-out-vnet-to-cosmos"
  priority                    = 3800
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resourcegroup_name
  network_security_group_name = azurerm_network_security_group.cosmos_crud_api_nsg.name
}

/* resource "azurerm_subnet_network_security_group_association" "cosmos_crud_api_nsg_association" {
  subnet_id                 = azurerm_subnet.cosmos_crud_api_subnet.id
  network_security_group_id = azurerm_network_security_group.cosmos_crud_api_nsg.id
} */


resource "azurerm_private_dns_zone_virtual_network_link" "cosmos_crud_api_link" {
  name                  = "cosmos-crud-api-link"
  resource_group_name   = var.resourcegroup_name
  private_dns_zone_name = azurerm_private_dns_zone.function_apis_private_zone.name
  virtual_network_id    = azurerm_virtual_network.private_resource_vnet.id
  registration_enabled  = true

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "private_resources_link_cosmos" {
  name                  = "private-resources-link-cosmos"
  resource_group_name   = var.resourcegroup_name
  private_dns_zone_name = azurerm_private_dns_zone.cosmos_db_private_zone.name
  virtual_network_id    = azurerm_virtual_network.private_resource_vnet.id
  registration_enabled  = false

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

/* resource "azurerm_private_dns_zone_virtual_network_link" "private_resources_link_cosmos_2" {
  name                  = "private-resources-link-cosmos_2"
  resource_group_name   = var.resourcegroup_name
  private_dns_zone_name = azurerm_private_dns_zone.cosmos_db_private_zone_2.name
  virtual_network_id    = azurerm_virtual_network.private_resource_vnet.id
  registration_enabled  = false

  tags = {
    project = var.project_name
    env     = var.env_name
  }
} */

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

resource "azurerm_service_plan" "private_api_asp" {
  name                = "private-api-sp"
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

resource "azurerm_cosmosdb_account" "cocuisson_db" {
  name                = "${var.project_name}-cosmos-db"
  resource_group_name = var.resourcegroup_name
  location            = var.cosmos_location
  offer_type          = "Standard"
  kind                = "MongoDB"

  enable_automatic_failover = false

  mongo_server_version = "4.0"

  capabilities {
    name = "EnableServerless"
  }

  public_network_access_enabled = false

  backup {
    type                = "Periodic"
    storage_redundancy  = "Local"
    interval_in_minutes = "120"
    retention_in_hours  = "48"
  }

  geo_location {
    location          = var.cosmos_location
    failover_priority = 0
  }

  consistency_policy {
    consistency_level = "Strong"
  }

  ip_range_filter = "104.42.195.92,40.76.54.131,52.176.6.30,52.169.50.45,52.187.184.26"
}

resource "azurerm_cosmosdb_mongo_database" "cocuisson_mongo_db" {
  name                = "${var.project_name}-mongo-db"
  resource_group_name = var.resourcegroup_name
  account_name        = azurerm_cosmosdb_account.cocuisson_db.name
}

resource "azurerm_private_endpoint" "cocuisson_db_pve" {
  name                = "cocuisson-db-pve"
  location            = var.location
  resource_group_name = var.resourcegroup_name
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id

  private_dns_zone_group {
    name                 = "privatednszonegroupcosmos"
    private_dns_zone_ids = [azurerm_private_dns_zone.cosmos_db_private_zone.id]
  }

  private_service_connection {
    name                           = "${azurerm_cosmosdb_account.cocuisson_db.name}-private-service-connection"
    private_connection_resource_id = azurerm_cosmosdb_account.cocuisson_db.id
    is_manual_connection           = false
    subresource_names              = ["MongoDB"]
  }

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
    azurerm_storage_account.api_sa,
    azurerm_cosmosdb_account.cocuisson_db,
    azurerm_subnet.cosmos_crud_api_subnet
  ]
  location                    = var.location
  resource_group_name         = var.resourcegroup_name
  service_plan_id             = azurerm_service_plan.private_api_asp.id
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
    "MONGO_DB_URL"                   = element(azurerm_cosmosdb_account.cocuisson_db.connection_strings, 0),
    "WEBSITE_DNS_SERVER"             = "168.63.129.16"
    "WEBSITE_VNET_ROUTE_ALL"         = 1
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "cosmos_crud_api_vnet_int" {
  app_service_id = azurerm_linux_function_app.cosmos_crud_api.id
  subnet_id      = azurerm_subnet.cosmos_crud_api_subnet.id
}

resource "azurerm_private_endpoint" "cosmos_crud_api_pve" {
  name                = "cosmos-crud-api-pve"
  location            = var.location
  resource_group_name = var.resourcegroup_name
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id

  private_dns_zone_group {
    name                 = "privatednszonegroupfunction"
    private_dns_zone_ids = [azurerm_private_dns_zone.function_apis_private_zone.id]
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

  delegation {
    name = "cocuisson-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

  service_endpoints = ["Microsoft.Storage"]


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

resource "azurerm_virtual_network_peering" "private_resource_peer" {
  name                      = "peerpvttoext"
  resource_group_name       = var.resourcegroup_name
  virtual_network_name      = azurerm_virtual_network.private_resource_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.external_api_vnet.id
}

resource "azurerm_virtual_network_peering" "external_api_peer" {
  name                      = "peerexttopvt"
  resource_group_name       = var.resourcegroup_name
  virtual_network_name      = azurerm_virtual_network.external_api_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.private_resource_vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "external_api_link" {
  name                  = "external-api-link"
  resource_group_name   = var.resourcegroup_name
  private_dns_zone_name = azurerm_private_dns_zone.function_apis_private_zone.name
  virtual_network_id    = azurerm_virtual_network.external_api_vnet.id
  registration_enabled  = true

  tags = {
    project = var.project_name
    env     = var.env_name
  }
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
  name = "cocuisson-apim-dev"
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
      ip_address = join("", concat(azurerm_api_management.cocuisson_apim.public_ip_addresses, ["/32"]))
    }
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.app_insights.instrumentation_key
    "API_BASE_URL"                   = var.api_base_url
    "DB_NAME"                        = var.db_name
    "SENDGRID_API_KEY"               = var.sendgrid_api_key
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "shared_private_services_vnet_int" {
  app_service_id = azurerm_linux_function_app.shared_private_services.id
  subnet_id      = azurerm_subnet.cocuisson_subnet.id
}

resource "azurerm_linux_function_app" "cocuisson_atelier_api" {
  name = "cocuisson-atelier-api"
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
      ip_address = join("", concat(azurerm_api_management.cocuisson_apim.public_ip_addresses, ["/32"]))
    }
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.app_insights.instrumentation_key
    "API_BASE_URL"                   = var.api_base_url
    "DB_NAME"                        = var.db_name
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "cocuisson_atelier_api_vnet_int" {
  app_service_id = azurerm_linux_function_app.cocuisson_atelier_api.id
  subnet_id      = azurerm_subnet.cocuisson_subnet.id
}

resource "azurerm_linux_function_app" "cocuisson_ceramiste_api" {
  name = "cocuisson-ceramiste-api"
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
      ip_address = join("", concat(azurerm_api_management.cocuisson_apim.public_ip_addresses, ["/32"]))
    }
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.app_insights.instrumentation_key
    "API_BASE_URL"                   = var.api_base_url
    "DB_NAME"                        = var.db_name
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "cocuisson_ceramiste_api_vnet_int" {
  app_service_id = azurerm_linux_function_app.cocuisson_ceramiste_api.id
  subnet_id      = azurerm_subnet.cocuisson_subnet.id
}

resource "azurerm_linux_function_app" "cocuisson_order_api" {
  name = "cocuisson-order-api"
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
      ip_address = join("", concat(azurerm_api_management.cocuisson_apim.public_ip_addresses, ["/32"]))
    }
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.app_insights.instrumentation_key
    "API_BASE_URL"                   = var.api_base_url
    "DB_NAME"                        = var.db_name
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "cocuisson_order_api_vnet_int" {
  app_service_id = azurerm_linux_function_app.cocuisson_order_api.id
  subnet_id      = azurerm_subnet.cocuisson_subnet.id
}

resource "azurerm_api_management_backend" "shared_services_backend" {
  name = "shared-services-backend"
  depends_on = [
    azurerm_linux_function_app.shared_private_services
  ]
  resource_group_name = var.resourcegroup_name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  protocol            = "http"
  url                 = "https://shared-private-services.azurewebsites.net/api/"
}

resource "azurerm_api_management_api" "shared_services_api" {
  name                = "shared-services-api"
  resource_group_name = var.resourcegroup_name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  revision            = "1"
  display_name        = "Shared Services API"
  protocols           = ["https"]
  path                = "shared"

  service_url = "https://shared-private-services.azurewebsites.net/api"
}

resource "azurerm_api_management_api_operation" "atelier_registration_api_op" {
  operation_id        = "belgian-atelier"
  api_name            = azurerm_api_management_api.shared_services_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Register a Belgian Atelier"
  method              = "POST"
  url_template        = "/belgian-atelier"
  description         = "This registers a new Belgian Atelier on the platform"

  request {
    description = "Register Belgian Atelier"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 200
    description = "Returns 200 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 400
    description = "Returns 400 if unsuccessful"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_api_operation" "email_notification_api_op" {
  operation_id        = "email-notification"
  api_name            = azurerm_api_management_api.shared_services_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Email Notification"
  method              = "POST"
  url_template        = "/email-notification"
  description         = "This sends email notifications to users"

  request {
    description = "Email Notification"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 200
    description = "Returns 200 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 400
    description = "Returns 400 if unsuccessful"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_backend" "cocuisson_atelier_api_backend" {
  name = "cocuisson-atelier-api-backend"
  depends_on = [
    azurerm_linux_function_app.cocuisson_atelier_api,
    azurerm_linux_function_app.cocuisson_ceramiste_api,
    azurerm_linux_function_app.cocuisson_order_api
  ]
  resource_group_name = var.resourcegroup_name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  protocol            = "http"
  url                 = "https://cocuisson-atelier-api.azurewebsites.net/api/"
}

resource "azurerm_api_management_api" "cocuisson_atelier_api" {
  name                = "cocuisson-atelier-api"
  resource_group_name = var.resourcegroup_name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  revision            = "1"
  display_name        = "Atelier API"
  protocols           = ["https"]
  path                = "atelier"

  service_url = "https://cocuisson-atelier-api.azurewebsites.net/api/"
}

resource "azurerm_api_management_api_operation" "atelier_new_four_api_op" {
  operation_id        = "new-four"
  api_name            = azurerm_api_management_api.cocuisson_atelier_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Create a new four"
  method              = "POST"
  url_template        = "/new-four"
  description         = "This creates a new four on the platform"

  request {
    description = "Create a new four"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 201
    description = "Returns 201 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 400
    description = "Returns 400 if unsuccessful"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_api_operation" "atelier_new_cuisson_availability_api_op" {
  operation_id        = "new-cuisson-avalilability"
  api_name            = azurerm_api_management_api.cocuisson_atelier_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Create a new cuisson availability"
  method              = "POST"
  url_template        = "/new-cuisson-avalilability"
  description         = "This creates a new cuisson availability on the platform"

  request {
    description = "Create a new cuisson availability"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 201
    description = "Returns 201 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 400
    description = "Returns 400 if unsuccessful"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_api_operation" "atelier_fours_api_op" {
  operation_id        = "fours"
  api_name            = azurerm_api_management_api.cocuisson_atelier_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "List all fours"
  method              = "POST"
  url_template        = "/fours"
  description         = "This lists all fours on the platform"

  request {
    description = "List all fours"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 200
    description = "Returns 200 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 404
    description = "Returns 404 if not found"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_api_operation" "atelier_cuisson_update_api_op" {
  operation_id        = "cuisson-update"
  api_name            = azurerm_api_management_api.cocuisson_atelier_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Update cuisson availability"
  method              = "PUT"
  url_template        = "/cuisson-update"
  description         = "This updates a cuisson availability on the platform"

  request {
    description = "Update cuisson availability"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 200
    description = "Returns 200 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 400
    description = "Returns 400 if unsuccessful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 404
    description = "Returns 404 if not found"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_api_operation" "atelier_availability_delete_api_op" {
  operation_id        = "cuisson-availability-delete"
  api_name            = azurerm_api_management_api.cocuisson_atelier_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Delete a cuisson availability"
  method              = "DELETE"
  url_template        = "/cuisson-availability-delete"
  description         = "This deletes a cuisson availabilty from the platform"

  request {
    description = "Delete a cuisson availability"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 200
    description = "Returns 200 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 404
    description = "Returns 404 if not found"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_api_operation" "atelier_cuisson_availabilities_api_op" {
  operation_id        = "cuisson-availabilities"
  api_name            = azurerm_api_management_api.cocuisson_atelier_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Gets all cuisson availabilities"
  method              = "POST"
  url_template        = "/cuisson-availabilities"
  description         = "This gets all availabilties on the platform"

  request {
    description = "Gets all cuisson availabilities"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 200
    description = "Returns 200 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 400
    description = "Returns 400 if unsuccessful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 404
    description = "Returns 404 if not found"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_api_operation" "atelier_atelier_info_api_op" {
  operation_id        = "atelier-info"
  api_name            = azurerm_api_management_api.cocuisson_atelier_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Gets atelier info"
  method              = "POST"
  url_template        = "/atelier-info"
  description         = "This gets atelier info on the platform"

  request {
    description = "Gets atelier info"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 200
    description = "Returns 200 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 404
    description = "Returns 404 if not found"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_backend" "cocuisson_ceramiste_api_backend" {
  name = "cocuisson-ceramiste-api-backend"
  depends_on = [
    azurerm_linux_function_app.cocuisson_atelier_api,
    azurerm_linux_function_app.cocuisson_ceramiste_api,
    azurerm_linux_function_app.cocuisson_order_api
  ]
  resource_group_name = var.resourcegroup_name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  protocol            = "http"
  url                 = "https://cocuisson-ceramiste-api.azurewebsites.net/api/"
}

resource "azurerm_api_management_api" "cocuisson_ceramiste_api" {
  name                = "cocuisson-ceramiste-api"
  resource_group_name = var.resourcegroup_name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  revision            = "1"
  display_name        = "Ceramiste API"
  protocols           = ["https"]
  path                = "ceramiste"

  service_url = "https://cocuisson-ceramiste-api.azurewebsites.net/api/"
}

resource "azurerm_api_management_api_operation" "ceramiste_new_ceramiste_api_op" {
  operation_id        = "new-ceramiste"
  api_name            = azurerm_api_management_api.cocuisson_ceramiste_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Register a new ceramiste"
  method              = "POST"
  url_template        = "/new-ceramiste"
  description         = "This adds a new ceramiste on the platform"

  request {
    description = "Register a new ceramiste"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 201
    description = "Returns 201 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 400
    description = "Returns 400 if unsuccessful"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_api_operation" "ceramiste_ceramiste_info_api_op" {
  operation_id        = "ceramiste-info"
  api_name            = azurerm_api_management_api.cocuisson_ceramiste_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Get ceraminste info"
  method              = "POST"
  url_template        = "/ceramiste-info"
  description         = "This gets ceramiste info on the platform"

  request {
    description = "Get ceraminste info"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 200
    description = "Returns 200 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 404
    description = "Returns 404 if not found"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_api_operation" "ceramiste_cuisson_availabilities_api_op" {
  operation_id        = "availabilities"
  api_name            = azurerm_api_management_api.cocuisson_ceramiste_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Get cuisson availabilities"
  method              = "POST"
  url_template        = "/availabilities"
  description         = "This gets all cuisson availabilities on the platform matching a user's search query"

  request {
    description = "Get cuisson availabilities"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 200
    description = "Returns 200 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 400
    description = "Returns 400 if unsuccessful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 404
    description = "Returns 404 if not found"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_backend" "cocuisson_order_api_backend" {
  name = "cocuisson-order-api-backend"
  depends_on = [
    azurerm_linux_function_app.cocuisson_atelier_api,
    azurerm_linux_function_app.cocuisson_ceramiste_api,
    azurerm_linux_function_app.cocuisson_order_api
  ]
  resource_group_name = var.resourcegroup_name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  protocol            = "http"
  url                 = "https://cocuisson-order-api.azurewebsites.net/api/"
}

resource "azurerm_api_management_api" "cocuisson_order_api" {
  name                = "cocuisson-order-api"
  resource_group_name = var.resourcegroup_name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  revision            = "1"
  display_name        = "Order API"
  protocols           = ["https"]
  path                = "order"

  service_url = "https://cocuisson-order-api.azurewebsites.net/api/"
}

resource "azurerm_api_management_api_operation" "order_orders_api_op" {
  operation_id        = "orders"
  api_name            = azurerm_api_management_api.cocuisson_order_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Get all orders"
  method              = "POST"
  url_template        = "/orders"
  description         = "This gets all orders on the platform"

  request {
    description = "Get all orders"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 200
    description = "Returns 200 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 400
    description = "Returns 400 if unsuccessful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 404
    description = "Returns 404 if not found"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_api_operation" "order_order_delete_api_op" {
  operation_id        = "order-delete"
  api_name            = azurerm_api_management_api.cocuisson_order_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Delete order"
  method              = "DELETE"
  url_template        = "/order-delete"
  description         = "This deletes an order from the platform"

  request {
    description = "Delete order"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 200
    description = "Returns 200 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 404
    description = "Returns 404 if not found"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_api_operation" "order_new_order_api_op" {
  operation_id        = "new-order"
  api_name            = azurerm_api_management_api.cocuisson_order_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Create new order"
  method              = "POST"
  url_template        = "/new-order"
  description         = "This creates a new order on the platform"

  request {
    description = "Create new order"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 201
    description = "Returns 201 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 400
    description = "Returns 400 if unsuccessful"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_api_operation" "order_atelier_order_action_api_op" {
  operation_id        = "atelier-order-action"
  api_name            = azurerm_api_management_api.cocuisson_order_api.name
  api_management_name = azurerm_api_management.cocuisson_apim.name
  resource_group_name = var.resourcegroup_name
  display_name        = "Perform order action"
  method              = "PUT"
  url_template        = "/atelier-order-action"
  description         = "This updates the statis of an order on the platform"

  request {
    description = "Perform order action"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 200
    description = "Returns 200 if successful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 400
    description = "Returns 400 if unsuccessful"
    representation {
      content_type = "application/json"
    }
  }
  response {
    status_code = 404
    description = "Returns 404 if not found"
    representation {
      content_type = "application/json"
    }
  }
}
