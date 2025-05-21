terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~&gt;3.0"
    }
  }
  backend "azurerm" {
    # Configuration for resource_group_name, storage_account_name, container_name, and key
    # will be provided via a backend configuration file (e.g., dev.backend.hcl)
    # during `terraform init -backend-config=dev.backend.hcl`
  }
}

provider "azurerm" {
  features {}
  # Credentials will be supplied by the GitHub Actions workflow
  # or local environment variables for local testing.
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.application_name}-${var.environment_name}-${var.location_short}"
  location = var.location

  tags = {
    environment   = var.environment_name
    application   = var.application_name
    managed_by    = "terraform"
  }
}

# Other resources (SQL Server, SQL DB, App Service Plan, App Service, Key Vault) will be added here.

resource "azurerm_key_vault" "kv" {
  name                        = "kv-${var.application_name}-${var.environment_name}-${var.location_short}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = var.azure_tenant_id
  sku_name                    = "standard" # Or "premium"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false # Consider true for production

  access_policy {
    tenant_id = var.azure_tenant_id
    object_id = var.azure_admin_object_id # Service Principal or User ObjectID to manage KV

    key_permissions = [
      "Get",
    ]
    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover" # Permissions for Terraform to manage secrets
    ]
    certificate_permissions = [
      "Get",
    ]
  }

  # Access policy for the App Service Managed Identity to read secrets
  # This is defined after azurerm_linux_web_app to get its principal_id
  # However, to avoid circular dependency if KV is created first,
  # we might need to create this access policy as a separate resource
  # that depends on both kv and app_service.
  # For now, let's add it here and see if TF can resolve it,
  # or adjust if a separate resource is cleaner.
  # It's generally cleaner to define access policies as separate resources.

  tags = {
    environment   = var.environment_name
    application   = var.application_name
    managed_by    = "terraform"
  }
}

resource "azurerm_key_vault_secret" "db_connection_string_secret" {
  name         = "DbConnectionString--${var.application_name}--${var.environment_name}" # Secret name in Key Vault
  value        = "Server=tcp:${azurerm_mssql_server.sql_server.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.sql_db.name};Persist Security Info=False;User ID=${var.sql_admin_login};Password=${var.sql_admin_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.kv.id

  tags = {
    environment   = var.environment_name
    application   = var.application_name
    managed_by    = "terraform"
    description   = "SQL Database connection string for ${var.application_name} ${var.environment_name}"
  }

  depends_on = [
    azurerm_mssql_database.sql_db # Ensure DB is created before trying to get its name for the connection string
  ]
}

resource "azurerm_mssql_server" "sql_server" {
  name                         = "sql-${var.application_name}-${var.environment_name}-${var.location_short}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0" # Standard SQL Server version
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password

  # Ensure public network access is disabled if not needed, or configure firewall rules.
  # For simplicity in demo, leaving default (likely public access enabled).
  # Consider 'public_network_access_enabled = false' and private endpoints for production.

  tags = {
    environment   = var.environment_name
    application   = var.application_name
    managed_by    = "terraform"
  }
}

resource "azurerm_mssql_database" "sql_db" {
  name           = "sqldb-${var.application_name}-${var.environment_name}"
  server_id      = azurerm_mssql_server.sql_server.id
  collation      = "SQL_Latin1_General_CP1_CI_AS" # Common collation
  sku_name       = "S0" # Basic SKU for demo purposes, choose appropriately for real use.
  # max_size_gb    = 1 # Example size

  tags = {
    environment   = var.environment_name
    application   = var.application_name
    managed_by    = "terraform"
  }
}

resource "azurerm_service_plan" "app_service_plan" {
  name                = "plan-${var.application_name}-${var.environment_name}-${var.location_short}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku_name # e.g., "B1", "S1", "P1V2"

  tags = {
    environment   = var.environment_name
    application   = var.application_name
    managed_by    = "terraform"
  }
}

resource "azurerm_linux_web_app" "app_service" {
  name                = "app-${var.application_name}-${var.environment_name}-${var.location_short}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.app_service_plan.id

  site_config {
    application_stack {
      dotnet_version = "9.0" # Or the .NET version your app targets
    }
    always_on = false # Can be true for higher SKUs to keep app warm
  }

  # Enable Managed Identity for the App Service
  identity {
    type = "SystemAssigned"
  }

  # Connection string for the SQL Database
  # This will be set using a Key Vault reference for better security.
  # For now, placeholder. We'll create a Key Vault secret for the connection string
  # and then reference it here.
  connection_string {
    name  = "DefaultConnection" # Must match the name used in appsettings.json / Program.cs
    type  = "SQLAzure"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.db_connection_string_secret.name})"
  }
  
  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "1" # Recommended for deployment
    # Add other app settings as needed
    "ASPNETCORE_ENVIRONMENT" = var.environment_name # Ensures correct appsettings.{env}.json is loaded
  }

  tags = {
    environment   = var.environment_name
    application   = var.application_name
    managed_by    = "terraform"
  }

  depends_on = [
    azurerm_mssql_database.sql_db, # Ensure DB is ready before app service might try to connect
    azurerm_key_vault.kv
  ]
}

resource "azurerm_key_vault_access_policy" "app_service_kv_access" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = azurerm_linux_web_app.app_service.identity[0].tenant_id #azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.app_service.identity[0].principal_id

  secret_permissions = [
    "Get", "List"
  ]

  depends_on = [
    azurerm_linux_web_app.app_service, # Ensure App Service and its identity exist
    azurerm_key_vault.kv               # Ensure Key Vault exists
  ]
}