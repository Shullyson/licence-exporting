provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "licence_export_rg" {
  name     = var.resource_name
  location = var.location
}

resource "azurerm_key_vault" "licence_export_kv" {
  name                      = var.resource_name
  location                  = azurerm_resource_group.licence_export_rg.location
  resource_group_name       = azurerm_resource_group.licence_export_rg.name
  tenant_id                 = var.tenant_id
  sku_name                  = "standard"
  purge_protection_enabled  = true
  enable_rbac_authorization = true
}

resource "azurerm_role_assignment" "kv_admin_role" {
  scope                = azurerm_key_vault.licence_export_kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.object_id
}

resource "time_sleep" "wait_for_kv_rbac" {
  depends_on      = [azurerm_role_assignment.kv_admin_role]
  create_duration = "333s"
}

resource "azurerm_key_vault_secret" "licence_export_secret" {
  depends_on   = [time_sleep.wait_for_kv_rbac]
  name         = "licence-export-secret"
  value        = "my-super-secret-value"
  key_vault_id = azurerm_key_vault.licence_export_kv.id
}

resource "azurerm_automation_account" "licence_export_aa" {
  name                = var.resource_name
  location            = azurerm_resource_group.licence_export_rg.location
  resource_group_name = azurerm_resource_group.licence_export_rg.name
  sku_name            = "Basic"
}

resource "azurerm_automation_schedule" "monthly_schedule_15th" {
  name                    = "monthly-15th-schedule"
  resource_group_name     = azurerm_resource_group.licence_export_rg.name
  automation_account_name = azurerm_automation_account.licence_export_aa.name

  frequency   = "Month"
  interval    = 1
  start_time  = "2025-07-15T09:00:00Z"
  timezone    = "UTC"
  month_days  = [15]

  description = "Runs the runbook every 15th of the month at 9:00 AM UTC"
}

resource "azurerm_automation_job_schedule" "runbook_monthly_job" {
  resource_group_name     = azurerm_resource_group.licence_export_rg.name
  automation_account_name = azurerm_automation_account.licence_export_aa.name
  schedule_name           = azurerm_automation_schedule.monthly_schedule_15th.name
  runbook_name            = azurerm_automation_runbook.licence_export_runbook.name
}

resource "azurerm_automation_variable_string" "var_container_name" {
  name                    = "container-name"
  resource_group_name     = azurerm_resource_group.licence_export_rg.name
  automation_account_name = azurerm_automation_account.licence_export_aa.name
  value                   = "placeholder-container"
  encrypted               = false
}

resource "azurerm_automation_variable_string" "var_key_vault_name" {
  name                    = "key-vault-name"
  resource_group_name     = azurerm_resource_group.licence_export_rg.name
  automation_account_name = azurerm_automation_account.licence_export_aa.name
  value                   = var.resource_name
  encrypted               = false
}

resource "azurerm_automation_variable_string" "var_secret_name" {
  name                    = "licence-export-secret"
  resource_group_name     = azurerm_resource_group.licence_export_rg.name
  automation_account_name = azurerm_automation_account.licence_export_aa.name
  value                   = "licence-export-secret"
  encrypted               = false
}

resource "azurerm_automation_variable_string" "var_storage_account_name" {
  name                    = "storage-account-name"
  resource_group_name     = azurerm_resource_group.licence_export_rg.name
  automation_account_name = azurerm_automation_account.licence_export_aa.name
  value                   = "placeholderstorageacct"
  encrypted               = false
}

resource "azurerm_automation_runbook" "licence_export_runbook" {
  name                    = var.resource_name
  location                = azurerm_resource_group.licence_export_rg.location
  resource_group_name     = azurerm_resource_group.licence_export_rg.name
  automation_account_name = azurerm_automation_account.licence_export_aa.name
  log_verbose             = true
  log_progress            = true
  runbook_type            = "PowerShell72"
  content                 = filebase64("../runbooks/dummy.ps1")
  description             = "Runbook for automated licence export"
}
