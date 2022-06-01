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
  registration_enabled = true

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_app_service_plan" "api_asp" {
  name                = "api-asp"
  location            = var.location
  resource_group_name = var.resourcegroup_name
  kind                = "FunctionApp"
  reserved            = true

  sku {
    tier = "Premium"
    size = "P1v2"
  }

  tags = {
    project = var.project_name
    env     = var.env_name
  }
}

resource "azurerm_storage_account" "api_sa" {
  name                     = "apisa"
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


resource "azurerm_function_app" "shared_private_services" {
  name = "shared-private-services"
  depends_on = [
    azurerm_storage_account.api_sa
  ]
  location                   = var.location
  resource_group_name        = var.resourcegroup_name
  app_service_plan_id        = azurerm_app_service_plan.api_asp.id
  storage_account_name       = azurerm_storage_account.api_sa.name
  storage_account_access_key = azurerm_storage_account.api_sa.primary_access_key
  os_type                    = "linux"
  version                    = "~3"
  https_only                 = true
  tags = {
    project = var.project_name
    env     = var.env_name
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "python"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.app_insights.instrumentation_key
    "MONGO_DB_URL" = var.mongo_url
  }

  site_config {
    linux_fx_version          = "Python|3.9"
    use_32_bit_worker_process = false
  }
}
