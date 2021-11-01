terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.80.0"
    }
  }
}
provider "azurerm" {
  features {}
}

module "landing-zone" {
  source = "../modules/landing-zone"

  env_name     = "onaide-dev"
  project_name = "onaide"
}
