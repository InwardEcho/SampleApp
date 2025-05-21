# Example backend configuration for the 'dev' environment
# These values would point to an Azure Storage Account configured for Terraform state.
# Ensure this storage account and container exist before running `terraform init`.

resource_group_name  = "tfstate-rg-dev"      # Name of the Resource Group holding the_state Storage Account
storage_account_name = "tfstatesampleappdev" # Name of the Storage Account for Terraform state
container_name       = "tfstate"             # Name of the Blob Container in the Storage Account
key                  = "sampleapp/dev/terraform.tfstate" # Path to the state file in the container