variable "location" {
  description = "Azure region to deploy resources in"
  type        = string
  default     = "westeurope"
}

variable "resource_name" {
  description = "Base name for all resources"
  type        = string
  default     = "license-export-testing"
}

variable "tenant_id" {
  description = "Azure Active Directory tenant ID"
  type        = string
}

variable "object_id" {
  description = "Object ID of the identity to grant Key Vault access"
  type        = string
}
