resource "azurerm_container_registry" "acr" {
  name                = "eaphd"
  resource_group_name = "${var.env_name}-rg"
  location            = "West Europe"
  sku                 = "Basic"
  admin_enabled       = false
  identity {
    type = "SystemAssigned"
  }
  tags = {
    project = "ea_phd"
    env     = var.env_name
  }
}

resource "azurerm_app_service_plan" "solid_asp" {
  name                = "solid-asp"
  location            = "West Europe"
  resource_group_name = "${var.env_name}-rg"
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Basic"
    size = "B1"
  }
}

resource "azurerm_app_service" "solid_server" {
  name                = "ea-solid-server"
  location            = "West Europe"
  resource_group_name = "${var.env_name}-rg"
  app_service_plan_id = azurerm_app_service_plan.solid_asp.id

  site_config {
    linux_fx_version                     = "DOCKER|eaphd.azurecr.io/solid-ea-phd:latest"
    acr_use_managed_identity_credentials = true
    app_command_line = "-b https://ea-solid-server.azurewebsites.net/"
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "DOCKER_REGISTRY_SERVER_URL"          = "https://eaphd.azurecr.io"
  }

  identity {
    type = "SystemAssigned"
  }
}

data "azurerm_container_registry" "acr_registry" {
  name                = "eaphd"
  resource_group_name = "${var.env_name}-rg"
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = "/subscriptions/201e612c-a95e-4c2e-aefe-5aef9c0cafb3/resourceGroups/dev-test-rg/providers/Microsoft.ContainerRegistry/registries/eaphd"
  role_definition_name = "AcrPull"
  principal_id         = azurerm_app_service.solid_server.identity.0.principal_id
}