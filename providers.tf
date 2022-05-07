terraform {

  required_version = ">=0.12"
  
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">=3.5.0"
    }
    databricks = {
      source = "databrickslabs/databricks"
      version = "~>0.5.7"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

provider "databricks" {
  host = data.azurerm_databricks_workspace.adb.workspace_url
  azure_workspace_resource_id = data.azurerm_databricks_workspace.adb.id

  # ARM_USE_MSI environment variable is recommended
  //azure_use_msi = true
  azure_client_id             = var.client_id
  azure_client_secret         = var.client_secret
  azure_tenant_id             = var.tenant_id
}