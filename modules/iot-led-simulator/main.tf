resource "azurerm_app_service_plan" "iot_sim_asp" {
  name                = "iot-sim-asp"
  location            = "West Europe"
  resource_group_name = "${var.env_name}-rg"
  kind                = "FunctionApp"
  reserved            = true

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_storage_account" "function_app_sa" {
  name                     = "eattohphdsa"
  resource_group_name      = "${var.env_name}-rg"
  location                 = "West Europe"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


resource "azurerm_function_app" "iot_led_simulator" {
  name = "iot-led-simulator"
  depends_on = [
    azurerm_storage_account.function_app_sa
  ]
  location                   = "West Europe"
  resource_group_name        = "${var.env_name}-rg"
  app_service_plan_id        = azurerm_app_service_plan.iot_sim_asp.id
  storage_account_name       = azurerm_storage_account.function_app_sa.name
  storage_account_access_key = azurerm_storage_account.function_app_sa.primary_access_key
  os_type                    = "linux"
  version                    = "~3"
  https_only                 = true
  tags = {
    project = "ea_phd"
    env     = var.env_name
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python"
  }

  site_config {
    linux_fx_version          = "Python|3.8"
    use_32_bit_worker_process = false
  }
}