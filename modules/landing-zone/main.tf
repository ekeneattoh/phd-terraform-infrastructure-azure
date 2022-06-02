# contains resource group definitions as well as compulsory
# tags that they must have

resource "azurerm_resource_group" "resource_group" {
  name     = "${var.env_name}-rg"
  location = "West Europe"
  tags = {
    project = var.project_name
    env = var.env_name
  }
}