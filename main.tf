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

}

resource "azurerm_management_group" "child_group" {
  display_name               = "EA-PHD"
  parent_management_group_id = azurerm_management_group.parent_group.id

  subscription_ids = [
    data.azurerm_subscription.current.subscription_id
  ]
  # other subscription IDs can go here
}


resource "azurerm_policy_definition" "allowed_resources" {
  name         = "allowed-resources-policy"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "allowed resources"

  metadata = <<METADATA
    {
    "category": "General"
    }

METADATA


  policy_rule = <<POLICY_RULE
    {
    "if": {
            "not": {
                "field": "type",
                "in": "[parameters('listOfResourceTypesAllowed')]"
            }
        },
        "then": {
            "effect": "deny"
        }
  }
POLICY_RULE


  parameters = <<PARAMETERS
    {
   "listOfResourceTypesAllowed": {
        "type": "Array",
        "metadata": {
            "description": "The list of resource types that can be deployed.",
            "displayName": "Allowed resource types",
            "strongType": "resourceTypes"
        },
        "defaultValue": ["Microsoft.Web/sites/functions/*"]
    }
  }
PARAMETERS

}

resource "azurerm_subscription_policy_assignment" "assignment_1" {
  name                 = "allowed-resources"
  policy_definition_id = azurerm_policy_definition.allowed_resources.id
  subscription_id      = "/subscriptions/201e612c-a95e-4c2e-aefe-5aef9c0cafb3"
  parameters           = <<PARAMETERS
{
  "listOfResourceTypesAllowed": {
    "value": ["Microsoft.Web/sites/functions/*"]
  }
}
PARAMETERS
}