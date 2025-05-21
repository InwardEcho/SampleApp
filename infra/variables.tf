variable "application_name" {
  type        = string
  description = "The name of the application."
  default     = "sampleapp"
}

variable "environment_name" {
  type        = string
  description = "The name of the environment (e.g., dev, staging, prod)."
  # No default, should be provided per environment
}

variable "location" {
  type        = string
  description = "The Azure region where resources will be deployed."
  # No default, should be provided
}

variable "location_short" {
  type        = string
  description = "A short name for the Azure region (e.g., uks, eus)."
  # No default, should be provided
}

variable "azure_tenant_id" {
  type        = string
  description = "The Azure Tenant ID where the resources are deployed."
  # No default, should be provided (e.g., via environment variable TF_VAR_azure_tenant_id or .tfvars)
}

variable "azure_admin_object_id" {
  type        = string
  description = "The Object ID of the user or service principal that will be granted initial admin access to Key Vault."
  # No default, should be provided
}

variable "sql_admin_login" {
  type        = string
  description = "The administrator login name for the SQL Server."
  # No default, should be provided
}

variable "sql_admin_password" {
  type        = string
  description = "The administrator password for the SQL Server. This should be a strong password."
  sensitive   = true # Marks this variable as sensitive, so Terraform won't output it in logs.
  # No default, should be provided (e.g., via environment variable TF_VAR_sql_admin_password or a secrets file)
}

variable "app_service_plan_sku_name" {
  type        = string
  description = "The SKU name for the App Service Plan (e.g., B1, S1, P1V2)."
  default     = "B1" # Default to Basic tier for dev/testing
}

# Add other variables as needed