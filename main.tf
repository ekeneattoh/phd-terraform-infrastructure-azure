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
        "defaultValue": ["Microsoft.Web/sites",
        "Microsoft.Web/serverfarms",
        "Microsoft.Web/sites/functions",
        "Microsoft.Web/sites/functions/keys",
        "Microsoft.Web/sites/config"]
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
    "value": [ "Microsoft.Web/sites",
        "Microsoft.Web/serverfarms",
        "Microsoft.Web/sites/functions",
        "Microsoft.Web/sites/functions/keys",
        "Microsoft.Web/sites/config",
        "Microsoft.ContainerRegistry/registries",
        "Microsoft.Storage/storageAccounts",
        "Microsoft.Insights/components",
        "Microsoft.Network/privateDnsZones",
        "Microsoft.Network/privateDnsZones/virtualNetworkLinks",
        "Microsoft.Network/virtualNetworks",
        "Microsoft.Network/virtualNetworks/subnets",
        "Microsoft.Network/virtualNetworks/virtualNetworkPeerings",
        "Microsoft.Network/privateEndpoints"]
  }
}
PARAMETERS
}

resource "azurerm_policy_definition" "allowed_asp" {
  name         = "allowed-asp-policy"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "allowed app service plans"

  metadata = <<METADATA
    {
    "category": "App Service"
    }

METADATA


  policy_rule = <<POLICY_RULE
    {
    "if": {
            "allOf": [
                {
                    "field": "type",
                    "equals": "Microsoft.Web/serverFarms"
                },
                {
                    "field": "Microsoft.Web/serverFarms/sku.Name",
                    "notIn": [
                        "F1",
                        "D1",
                        "B1",
                        "Y1",
                        "P1v2"
                    ]
                }
            ]
        },
        "then": {
            "effect": "[parameters('effect')]"
        }
  }
POLICY_RULE


  parameters = <<PARAMETERS
    {
    "effect": {
            "type": "String",
            "metadata": {
                "displayName": "Effect",
                "description": "Enable or disable the execution of the policy"
            },
            "allowedValues": [
                "Deny"
            ],
            "defaultValue": "Deny"
    }
  }
PARAMETERS

}

resource "azurerm_subscription_policy_assignment" "assignment_2" {
  name                 = "allowed-asp"
  policy_definition_id = azurerm_policy_definition.allowed_asp.id
  subscription_id      = "/subscriptions/201e612c-a95e-4c2e-aefe-5aef9c0cafb3"
}