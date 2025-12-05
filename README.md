# 📦 DWS - Bertelsmann License Export

This project defines a 4-stage Azure DevOps pipeline that provisions infrastructure, configures modules, and deploys a PowerShell runbook to an Azure Automation Account. It is designed to support multi-tenant setups via parameterized execution.

---

## 📋 Pipeline Overview

This pipeline is defined in **`azure-pipelines-1.yml`** and includes the following stages:

| Stage                   | Description                                                                 |
|-------------------------|-----------------------------------------------------------------------------|
| `CI`                    | Validates the syntax of the PowerShell runbook (`export-book.ps1`)         |
| `Terraform_Deployment`  | Installs Terraform, provisions Azure infrastructure, and imports state     |
| `Module_Configuration`  | Installs required Microsoft.Graph modules into the Automation Account      |
| `CD_Deployment`         | Publishes the runbook after manual approval and Key Vault secret injection |

---

## ⚙️ Required Files

- **`azure-pipelines-1.yml`** – Main pipeline definition
- **`export-book.ps1`** – PowerShell runbook script to be deployed
- **Terraform folder (`/terraform`)** – Must include `main.tf`, `variables.tf`, etc.

---

## 🛡️ Required Azure DevOps Setup

### 🔸 1. Service Connection

- An Azure DevOps service connection must exist (e.g. `DWS-Automation-Pipeline`)
- It must be authorized for pipeline use
- Passed as a runtime parameter: `serviceConnection`

### 🔸 2. Variable Group

Each tenant must have its own variable group named exactly as the value passed into the `tenant` parameter.

Required variables in the group:

| Name                  | Description                                  |
|-----------------------|----------------------------------------------|
| `runbookFilePath`     | Path to the runbook                          |
| `runbookName`         | Name of the runbook in Azure                 |
| `tenantId`            | Azure tenant ID                              |
| `subscriptionId`      | Azure subscription ID                        |
| `objectId`            | SP object ID (used for Terraform)            |
| `resourceGroupName`   | Resource group for Automation Account        |
| `automationAccountName` | Name of the Automation Account           |
| `keyVaultName`        | Name of the Key Vault                        |
| `secretName`          | Name of the secret for SAS token             |
| `storageAccountName`  | Used in Automation variable                  |
| `containerName`       | Used in Automation variable                  |
| `location`            | Azure region (e.g., `westeurope`)            |

> 💡 Ensure "Allow access to all pipelines" is enabled for the variable group.

---

## 🧪 How to Use

1. Go to Azure DevOps → Pipelines → Run pipeline
2. Enter the desired values for:
   - `tenant`: Name of the variable group (e.g., `DWS-LAB`)
   - `serviceConnection`: Name of the Azure DevOps service connection
3. Click **Run**

The pipeline will:
- Validate the runbook syntax
- Deploy infrastructure and register state
- Pause before Stage 4 (approval gate)
- Let the tenant admin inject the **SAS token manually into Key Vault**
- Deploy and publish the runbook

---

## 🔐 SAS Token Flow

To maintain security:
- The SAS token is **not stored** in the variable group
- It must be **manually added** by the tenant admin to Key Vault (using `secretName`) after Stage 3
- Stage 4 resumes after approval and uses this token securely

---

## ✅ Approvals

The final stage (`CD_Deployment`) uses:

```yaml
environment: manual-approval-deploy
