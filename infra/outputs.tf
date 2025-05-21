output "resource_group_name" {
  description = "The name of the Azure Resource Group."
  value       = azurerm_resource_group.rg.name
}

output "key_vault_name" {
  description = "The name of the Azure Key Vault."
  value       = azurerm_key_vault.kv.name
}

output "key_vault_uri" {
  description = "The URI of the Azure Key Vault."
  value       = azurerm_key_vault.kv.vault_uri
}

output "db_connection_string_secret_name" {
  description = "The name of the secret in Key Vault that stores the DB connection string."
  value       = azurerm_key_vault_secret.db_connection_string_secret.name
}

output "sql_server_name" {
  description = "The name of the Azure SQL Server."
  value       = azurerm_mssql_server.sql_server.name
}

output "sql_server_fqdn" {
  description = "The fully qualified domain name of the Azure SQL Server."
  value       = azurerm_mssql_server.sql_server.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "The name of the Azure SQL Database."
  value       = azurerm_mssql_database.sql_db.name
}

output "app_service_plan_name" {
  description = "The name of the Azure App Service Plan."
  value       = azurerm_service_plan.app_service_plan.name
}

output "app_service_name" {
  description = "The name of the Azure App Service."
  value       = azurerm_linux_web_app.app_service.name
}

output "app_service_default_hostname" {
  description = "The default hostname of the Azure App Service."
  value       = azurerm_linux_web_app.app_service.default_hostname
}