terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
    }
  }
  backend "azurerm" {
    # use_oidc             = true                                    # Can also be set via `ARM_USE_OIDC` environment variable.
    use_azuread_auth     = true                                    # Can also be set via `ARM_USE_AZUREAD` environment variable.
    storage_account_name = "inwardechodevtf"                              # Can be passed via `-backend-config=`"storage_account_name=<storage account name>"` in the `init` command.
    container_name       = "tfstate"                               # Can be passed via `-backend-config=`"container_name=<container name>"` in the `init` command.
    key                  = "sampleapp/dev/terraform.tfstate"                # Can be passed via `-backend-config=`"key=<blob key name>"` in the `init` command.
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# terraform {
#   backend "azurerm" {
#     use_oidc             = true                                    # Can also be set via `ARM_USE_OIDC` environment variable.
#     use_azuread_auth     = true                                    # Can also be set via `ARM_USE_AZUREAD` environment variable.
#     storage_account_name = "inwardechodevtf"                              # Can be passed via `-backend-config=`"storage_account_name=<storage account name>"` in the `init` command.
#     container_name       = "tfstate"                               # Can be passed via `-backend-config=`"container_name=<container name>"` in the `init` command.
#     key                  = "sampleapp/dev/terraform.tfstate"                # Can be passed via `-backend-config=`"key=<blob key name>"` in the `init` command.
#   }
# }
