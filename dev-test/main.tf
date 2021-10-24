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

  env_name = "dev-test"
}


module "solid" {
  source = "../modules/solid"

  env_name = "dev-test"
}

module "iot-led-simulator" {
  source = "../modules/iot-led-simulator"

  env_name = "dev-test"
}
