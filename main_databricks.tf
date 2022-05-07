
//create PAT token to provision entities within workspace
resource "databricks_token" "pat" {
  comment  = "Terraform Provisioning"
  // 100 day token
  lifetime_seconds = 8640000
}

/*
// output token for other modules
output "databricks_token" {
  value     = databricks_token.pat.token_value
  sensitive = true
}
*/

//Upload Databricks notebook
resource "databricks_notebook" "streaming_notebook" {
  source = "notebooks/Streaming.dbc"
  path   = "/albertnoguescom/1.Streaming"
  format = "DBC"
}

//Create Databricks cluster, we take the smallest one
data "databricks_node_type" "smallest" {
  local_disk = true
  depends_on = [azurerm_databricks_workspace.adb]
}


// Latest LTS version
data "databricks_spark_version" "latest_lts" {
  long_term_support = true
  depends_on = [azurerm_databricks_workspace.adb]
}

resource "databricks_cluster" "singlenode" {
  cluster_name            = "AlbertnoguesCom"
  spark_version           = data.databricks_spark_version.latest_lts.id
  node_type_id            = data.databricks_node_type.smallest.id
  autotermination_minutes = 30
  num_workers = 0 #Single Node

  spark_conf = {
    # Single-node
    "spark.databricks.cluster.profile" : "singleNode"
    "spark.master" : "local[*]"
  }

  custom_tags = {
    "ResourceClass" = "SingleNode"
  }
}

// Install EventHub library in the cluster
resource "databricks_library" "eh" {
  cluster_id = databricks_cluster.singlenode.id
  maven {
    coordinates = "com.microsoft.azure:azure-eventhubs-spark_2.12:2.3.21"
    exclusions  = []
  }
}

/* //Currently it does not work. I'm using Service Principal, maybe we can switch to AZ CLI login. LOOK AT TODO
resource "databricks_secret_scope" "kv" {
  name = "albertnoguescom"

  keyvault_metadata {
    resource_id = azurerm_key_vault.kv.id
    dns_name    = azurerm_key_vault.kv.vault_uri
  }
}
*/