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

module "landing-zone" {
  source = "../modules/landing-zone"

  env_name = "dev-test"
}