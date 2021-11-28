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

  env_name     = "dev-test"
  project_name = "ea_phd"
}


module "solid" {
  source = "../modules/solid"

  env_name = "dev-test"
}

module "phd-iot-simulators" {
  source = "../modules/phd-iot-simulators"

  env_name = "dev-test"
}
