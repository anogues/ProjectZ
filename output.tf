output "resource_group_name" {
    value = azurerm_resource_group.rg.name
}


output "storage_account_primary_access_key" {
   value = azurerm_storage_account.sa.primary_access_key
   sensitive = true
}

output "databricks_workspace_url" {
  value = data.azurerm_databricks_workspace.adb.workspace_url
}

output "databricks_token" {
  value     = databricks_token.pat.token_value
  sensitive = true
}

output "eventhub_namespace_connstr" {
  value = data.azurerm_eventhub_namespace.ehn.default_primary_connection_string
  sensitive = true
}

output "eventhub_connstr" {
  value = data.azurerm_eventhub_authorization_rule.ehar.primary_connection_string
  sensitive = true
}
