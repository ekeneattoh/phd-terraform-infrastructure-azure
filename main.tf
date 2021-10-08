terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  features {}
}

data "azurerm_subscription" "current" {
}

resource "azurerm_management_group" "parent_group" {
  display_name = "ParentGroup"

  subscription_ids = [
    data.azurerm_subscription.current.subscription_id,
  ]
}

resource "azurerm_management_group" "child_group" {
  display_name               = "EA-PHD"
  parent_management_group_id = azurerm_management_group.parent_group.id

  subscription_ids = [
    data.azurerm_subscription.current.subscription_id
  ]
  # other subscription IDs can go here
}