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

  key_permissions    = ["get", "create", "list", "restore", "recover", "unwrapkey", "wrapkey", "purge", "encrypt", "decrypt", "sign", "verify"]
  secret_permissions = ["get"]
}

resource "azurerm_key_vault_access_policy" "client" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions    = ["get", "create", "delete", "list", "restore", "recover", "unwrapkey", "wrapkey", "purge", "encrypt", "decrypt", "sign", "verify"]
  secret_permissions = ["set", "get", "delete", "purge", "recover"]
}

resource "azurerm_key_vault_secret" "sakey1" {
  name         = var.storage_account_name
  value        = data.azurerm_storage_account.sa.primary_access_key
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_access_policy.client,
    azurerm_key_vault_access_policy.storage,
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
  name         = azurerm_eventhub.eh.name
  value        = data.azurerm_eventhub_authorization_rule.ehar.primary_connection_string
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_access_policy.client,
    azurerm_key_vault_access_policy.storage,
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
  storage_account_type  = "LRS"

  tags = {
    environment = "PoC"
  }

}