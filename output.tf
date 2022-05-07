output "resource_group_name" {
    value = azurerm_resource_group.rg.name
}


output "storage_account_primary_access_key" {
   value = azurerm_storage_account.sa.primary_access_key
   sensitive = true
}

output "storage_account_primary_dfs_endpoint" {
   value = azurerm_storage_account.sa.primary_dfs_endpoint
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

output "azsqlserver_name" {
  value       = azurerm_mssql_server.azsqlserver.name
  description = "Azure SQL Server Name"
}
output "azsqldb_name" {
  value       = azurerm_mssql_database.azsqldb.name
  description = "Azure SQL Database Name"
}

output "azsqlserver_user" {
  value = azurerm_mssql_server.azsqlserver.administrator_login
}

output "azsqlserver_pwd" {
  value = azurerm_mssql_server.azsqlserver.administrator_login_password
  sensitive = true
}

output "azsqlserver_connstr" {
  value = "Server=tcp:${azurerm_mssql_server.azsqlserver.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.azsqldb.name};Persist Security Info=False;User ID=${azurerm_mssql_server.azsqlserver.administrator_login};Password=${azurerm_mssql_server.azsqlserver.administrator_login_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  sensitive = true
}

output "azsqlserver_jdbc" {
  value = "jdbc:sqlserver://${azurerm_mssql_server.azsqlserver.fully_qualified_domain_name}:1433;database=${azurerm_mssql_database.azsqldb.name};user=${azurerm_mssql_server.azsqlserver.administrator_login}@${azurerm_mssql_server.azsqlserver.name};password=${azurerm_mssql_server.azsqlserver.administrator_login_password};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"
  sensitive = true
}