resource "azurerm_role_assignment" "blob-data-reader-adf" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_data_factory.adf.identity[0].principal_id
}

resource "azurerm_role_assignment" "data-reader-adf" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Reader"
  principal_id         = azurerm_data_factory.adf.identity[0].principal_id
}

resource "azurerm_data_factory_linked_service_key_vault" "adfkv" {
  name            = "KeyVault_LS"
  data_factory_id = azurerm_data_factory.adf.id
  key_vault_id    = azurerm_key_vault.kv.id
}
/*
// Thereis no AzureSQL linked service in terraform for azuresql ¿?
resource "azurerm_data_factory_linked_service_sql_server" "adfsql" {
  name              = "SQLDatabase_LS"
  data_factory_id   = azurerm_data_factory.adf.id
  key_vault_connection_string {
    linked_service_name = azurerm_data_factory_linked_service_key_vault.adfkv.name
    secret_name         = azurerm_key_vault_secret.azsqldbconnstr.name
  }
}
*/
resource "azurerm_data_factory_linked_custom_service" "adfsql" {
  name                 = "SQLDatabase_LS"
  data_factory_id      = azurerm_data_factory.adf.id
  type                 = "AzureSqlDatabase"
  description          = "Azure SQL DB Linked Service"
  type_properties_json = <<JSON
{
  "connectionString": {
                "type": "AzureKeyVaultSecret",
                "store": {
                    "referenceName": "${azurerm_data_factory_linked_service_key_vault.adfkv.name}",
                    "type": "LinkedServiceReference"
                },
                "secretName": "${azurerm_key_vault_secret.azsqldbconnstr.name}"
    }
}
JSON
}
resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "adfadlsgen2" {
  name                  = "DataLake_LS"
  data_factory_id       = azurerm_data_factory.adf.id
  url                   = replace(azurerm_storage_account.sa.primary_dfs_endpoint,".net/",".net")
  use_managed_identity  = true
}

// Locations json Dataset
resource "azurerm_data_factory_dataset_json" "locations" {
  name                = "Locations_json_DS"
  data_factory_id     = azurerm_data_factory.adf.id
  linked_service_name = azurerm_data_factory_linked_service_data_lake_storage_gen2.adfadlsgen2.name

  azure_blob_storage_location {
    container    = "raw"
    path         = "dataset"
    filename     = "locations.json"
  }

  encoding = "UTF-8"
  
}
/*
// Table Auto creation does not work for sql server dataset and there is no dataset in terraform for azuresql ¿?
resource "azurerm_data_factory_dataset_sql_server_table" "locationstable" {
  name                = "Locations_dbtable_DS"
  data_factory_id     = azurerm_data_factory.adf.id
  linked_service_name = azurerm_data_factory_linked_service_sql_server.adfsql.name
  table_name          = "dbo.locations"
}
*/

resource "azurerm_data_factory_custom_dataset" "locationstable" {
  name                 = "Locations_dbtable_DS"
  data_factory_id      = azurerm_data_factory.adf.id
  type                 = "AzureSqlTable"
  linked_service {
    name = azurerm_data_factory_linked_custom_service.adfsql.name
  }

  type_properties_json = <<JSON
    {
      "schema": "dbo",
      "table": "locations"
    }
  JSON

  schema_json = <<JSON
{
}
JSON
}


resource "azurerm_data_factory_pipeline" "loadlocations" {
  name            = "Load_Locations_Pipeline"
  data_factory_id = azurerm_data_factory.adf.id

  activities_json = <<JSON
        [
            {
                "name": "Copy Locations from DataLake to SqlDB",
                "type": "Copy",
                "dependsOn": [],
                "policy": {
                    "timeout": "7.00:00:00",
                    "retry": 0,
                    "retryIntervalInSeconds": 30,
                    "secureOutput": false,
                    "secureInput": false
                },
                "userProperties": [],
                "typeProperties": {
                    "source": {
                        "type": "JsonSource",
                        "storeSettings": {
                            "type": "AzureBlobFSReadSettings",
                            "recursive": true,
                            "enablePartitionDiscovery": false
                        },
                        "formatSettings": {
                            "type": "JsonReadSettings",
                            "compressionProperties": null
                        }
                    },
                    "sink": {
                        "type": "AzureSqlSink",
                        "writeBehavior": "insert",
                        "sqlWriterUseTableLock": false,
                        "tableOption": "autoCreate",
                        "disableMetricsCollection": false
                    },
                    "enableStaging": false
                },
                "inputs": [
                    {
                        "referenceName": "${azurerm_data_factory_dataset_json.locations.name}",
                        "type": "DatasetReference"
                    }
                ],
                "outputs": [
                    {
                        "referenceName": "${azurerm_data_factory_custom_dataset.locationstable.name}",
                        "type": "DatasetReference"
                    }
                ]
            }
        ]
  JSON
}