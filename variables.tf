variable "client_secret" {
}

variable "client_id" {
  description = "Azure ClientID"
}

variable "subscription_id" {
  description = "Azure Subscription ID"
}

variable "tenant_id" {
  description = "Azure TenantID"
}

variable "resource_group_name" {
    default = "albertnoguescom"
    description = "Main Resource Group Name"
}

variable "resource_group_location" {
  default = "westeurope"
  description   = "Location of the resource group."
}

variable "storage_account_name" {
    default = "albertnoguescom"
    description = "Main DataLake name"
}

variable "key_vault_name" {
    default = "albertnoguescom"
    description = "Main Keyvault Name"
}

variable "evenhub_namespace_name" {
    default = "albertnoguescom"
    description = "Evenhub Namespace Name"
}

variable "evenhub_name" {
    default = "transactions"
    description = "Evenhub Transactions Name"
}

variable "azuresqlserver_name" {
    default = "albertnoguescom"
    description = "Azure SQL Server Name"
}

variable "azuresqlserver_location" {
    default = "eastus"
    description = "Azure SQL Server Datacenter Location"
}

variable "azuresqldb_name" {
    default = "albertnoguescom"
    description = "Azure SQL Database Name"
}