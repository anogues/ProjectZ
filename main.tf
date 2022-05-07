data "azurerm_client_config" "current" {
}
data "azurerm_storage_account" "sa" {
  name                = azurerm_storage_account.sa.name
  resource_group_name = azurerm_resource_group.rg.name
}

data "azurerm_databricks_workspace" "adb" {
  name                = azurerm_databricks_workspace.adb.name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "random_string" "strapp" {
  length  = 5
  lower = true
  upper = false
  special = false
}

resource "azurerm_resource_group" "rg" {
  name = join("", [var.resource_group_name,random_string.strapp.result])
  location  = var.resource_group_location

  tags = {
    environment = "PoC"
  }
}

resource "azurerm_storage_account" "sa" {
  name                     = join("", [var.storage_account_name,random_string.strapp.result])
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = "PoC"
  }
}

/*
data "azurerm_storage_container" "raw" {
  name                 = "raw"
  storage_account_name = "example-storage-account-name"
}
*/

resource "azurerm_storage_data_lake_gen2_filesystem" "raw" {
  name               = "raw"
  storage_account_id = azurerm_storage_account.sa.id
}

resource "azurerm_storage_data_lake_gen2_path" "dataset" {
  path               = "dataset"
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.raw.name
  storage_account_id = azurerm_storage_account.sa.id
  resource           = "directory"
}

resource "azurerm_role_assignment" "data-contributor-role" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault" "kv" {
  name                = join("", [var.key_vault_name,random_string.strapp.result])
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  purge_protection_enabled = false
}


resource "azurerm_key_vault_access_policy" "storage" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_storage_account.sa.identity[0].principal_id

  key_permissions    = ["Get", "Create", "List", "Restore", "Recover", "UnwrapKey", "WrapKey", "Purge", "Encrypt", "Decrypt", "Sign", "Verify"]
  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_access_policy" "client" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions    = ["Get", "Create","Delete", "List", "Restore", "Recover", "UnwrapKey", "WrapKey", "Purge", "Encrypt", "Decrypt", "Sign", "Verify"]
  secret_permissions = ["Set", "Get", "Delete", "Purge", "Recover"]
}

resource "azurerm_key_vault_secret" "sakey1" {
  name         = join("-", [azurerm_storage_account.sa.name, "sa"])
  value        = data.azurerm_storage_account.sa.primary_access_key
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_access_policy.client,
    azurerm_key_vault_access_policy.storage,
    azurerm_storage_account.sa
  ]
}


resource "azurerm_databricks_workspace" "adb" {
  name                = "DatabricksAlbertNogues"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "trial"

  tags = {
    Environment = "PoC"
  }
}

//Upload test data
resource "azurerm_storage_blob" "ds_locations" {
  name                   = "dataset/locations.json"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_data_lake_gen2_filesystem.raw.name
  type                   = "Block"
  source                 = "dataset/locations.json"
  content_type           = "application/json"
}

resource "azurerm_storage_blob" "ds_transactions" {
  name                   = "dataset/transactions.json"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_data_lake_gen2_filesystem.raw.name
  type                   = "Block"
  source                 = "dataset/transactions.json"
  content_type           = "application/json"
}

//EvenHub Part
resource "azurerm_eventhub_namespace" "ehn" {
  name                = join("", [var.evenhub_namespace_name,random_string.strapp.result])
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"
  capacity            = 1

  tags = {
    environment = "PoC"
  }
}

data "azurerm_eventhub_namespace" "ehn" {
  name = azurerm_eventhub_namespace.ehn.name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_eventhub" "eh" {
  name                = var.evenhub_name
  namespace_name      = azurerm_eventhub_namespace.ehn.name
  resource_group_name = azurerm_resource_group.rg.name
  partition_count     = 2
  message_retention   = 1
}

/*
output "eventhub_authorization_rule_id" {
  value = data.azurem_eventhub_namespace_authorization_rule.example.id
}
*/

resource "azurerm_eventhub_authorization_rule" "ehar" {
  name                = "albertnoguescom"
  namespace_name      = azurerm_eventhub_namespace.ehn.name
  eventhub_name       = azurerm_eventhub.eh.name
  resource_group_name = azurerm_resource_group.rg.name
  listen              = true
  send                = true
  manage              = true
}

data "azurerm_eventhub_authorization_rule" "ehar" {
  name = azurerm_eventhub_authorization_rule.ehar.name
  resource_group_name = azurerm_resource_group.rg.name
  namespace_name      = azurerm_eventhub_namespace.ehn.name
  eventhub_name       = azurerm_eventhub.eh.name
}

//Add EH connstr in the KeyVault
resource "azurerm_key_vault_secret" "ehkey1" {
  name         = join("-", [azurerm_eventhub.eh.name, "eh"])
  value        = data.azurerm_eventhub_authorization_rule.ehar.primary_connection_string
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_access_policy.client,
    azurerm_key_vault_access_policy.storage,
    azurerm_eventhub.eh
  ]
}

//AzureSQL DB

resource "random_string" "azsqlpass" {
  length  = 16
  lower = true
}
resource "azurerm_mssql_server" "azsqlserver" {
  name                         = join("", [var.azuresqlserver_name,random_string.strapp.result])
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.azuresqlserver_location //azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "albertnoguescom"
  administrator_login_password = random_string.azsqlpass.result

  tags = {
    environment = "PoC"
  }
}

resource "azurerm_mssql_database" "azsqldb" {
  name                  = var.azuresqldb_name
  server_id             = azurerm_mssql_server.azsqlserver.id
  collation             = "SQL_Latin1_General_CP1_CI_AS"
  //license_type          = "LicenseIncluded"
  max_size_gb           = 2
  sku_name              = "Basic"
  storage_account_type  = "Local"

  tags = {
    environment = "PoC"
  }

}

resource "azurerm_mssql_firewall_rule" "azdbfw" {
  name             = "FirewallRuleAzureServices"
  server_id        = azurerm_mssql_server.azsqlserver.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"

    depends_on = [
    azurerm_mssql_server.azsqlserver
  ]
}

resource "azurerm_key_vault_secret" "azsqldbconnstr" {
  name         = join("-", [azurerm_mssql_database.azsqldb.name, "connstr"])
  value        = "Server=tcp:${azurerm_mssql_server.azsqlserver.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.azsqldb.name};Persist Security Info=False;User ID=${azurerm_mssql_server.azsqlserver.administrator_login};Password=${azurerm_mssql_server.azsqlserver.administrator_login_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_access_policy.client,
    azurerm_key_vault_access_policy.storage,
    azurerm_mssql_database.azsqldb
  ]
}

resource "azurerm_key_vault_secret" "azsqldbjdbc" {
  name         = join("-", [azurerm_mssql_database.azsqldb.name, "jdbc"])
  value        = "jdbc:sqlserver://${azurerm_mssql_server.azsqlserver.fully_qualified_domain_name}:1433;database=${azurerm_mssql_database.azsqldb.name};user=${azurerm_mssql_server.azsqlserver.administrator_login}@${azurerm_mssql_server.azsqlserver.name};password=${azurerm_mssql_server.azsqlserver.administrator_login_password};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_access_policy.client,
    azurerm_key_vault_access_policy.storage,
    azurerm_mssql_database.azsqldb
  ]
}

// Data Factory
resource "azurerm_data_factory" "adf" {
  name                = join("", [var.adf_name,random_string.strapp.result])
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = "PoC"
  }
}
resource "azurerm_key_vault_access_policy" "adfap" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = azurerm_data_factory.adf.identity[0].tenant_id
  object_id    = azurerm_data_factory.adf.identity[0].principal_id

  secret_permissions = ["List", "Get"]

  depends_on = [
    azurerm_data_factory.adf
  ]
}
