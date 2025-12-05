output "resource_group_name" {
  value = azurerm_resource_group.licence_export_rg.name
}

output "automation_account_name" {
  value = azurerm_automation_account.licence_export_aa.name
}

output "key_vault_name" {
  value = azurerm_key_vault.licence_export_kv.name
}
