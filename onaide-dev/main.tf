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

variable "mongo_url" {}

module "landing-zone" {
  source = "../modules/landing-zone"

  env_name     = "cocuisson-dev"
  project_name = "cocuisson"
}

module "cocuisson" {
  source = "../modules/cocuisson"
  depends_on = [
    module.landing-zone
  ]

  env_name     = "cocuisson-dev"
  project_name = "cocuisson"
  mongo_url    = var.mongo_url
}
