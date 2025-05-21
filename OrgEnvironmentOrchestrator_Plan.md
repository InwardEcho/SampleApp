# Plan for `org-environment-orchestrator.yml` GitHub Organizational Workflow Template

This document outlines the plan for creating the `org-environment-orchestrator.yml` organizational workflow template. This template will provide a standardized way to orchestrate multi-stage deployments (IaC, Database Migration, Application Deployment) across different environments.

## I. Purpose and Objectives

*   **Primary Goal**: To create a reusable GitHub Actions organizational workflow template that automates and standardizes the deployment of an application environment.
*   **Key Features**:
    *   Sequential execution of IaC, Database Migration, and Application Deployment stages.
    *   Integration with GitHub Environments for approval gates on sensitive operations (especially for non-dev environments).
    *   Secure handling of secrets, particularly database connection strings, leveraging Azure Key Vault.
    *   Parameterization to allow different repositories and applications to use the orchestrator.
    *   Clear input/output handling between orchestrated stages.

## II. Template Location

*   `YourOrgName/InwardEcho.github/.github/workflows/org-environment-orchestrator.yml` (or your organization's central repository for workflow templates).

## III. Workflow Definition (`on: workflow_call`)

### A. Inputs

*   `environment_name`: (string, required)
    *   Description: Target environment (e.g., "dev", "staging", "prod"). Used for naming, selecting configurations, and associating with GitHub Environments for approvals.
*   `application_name`: (string, required)
    *   Description: Name of the application being deployed (e.g., "SampleApp"). Used for artifact naming conventions and potentially tagging.
*   `app_build_artifact_name_pattern`: (string, optional, default: `{{application_name}}-deployment-package`)
    *   Description: Name or pattern of the application build artifact to deploy.
*   `app_build_artifact_run_id`: (string, optional)
    *   Description: Specific run ID of the build workflow that produced the artifact. If not provided, `app_build_source_branch` is used to find the latest.
*   `app_build_source_branch`: (string, optional)
    *   Description: Branch to fetch the latest artifact from if `app_build_artifact_run_id` is not given (e.g., `main`, `develop`).
*   `version_tag`: (string, optional)
    *   Description: Version string/tag of the application being deployed (for logging, tagging).

*   **IaC Stage Inputs**:
    *   `iac_org_template_ref`: (string, required)
        *   Description: Full ref to the organizational IaC template (e.g., `YourOrg/.github/.github/workflows/org-iac-terraform.yml@main`).
    *   `iac_working_directory`: (string, default: `./infra`)
        *   Description: Path to the Terraform configuration files within the calling repository.
    *   `iac_variables_file_path_pattern`: (string, default: `{working_directory}/{env}.tfvars`)
        *   Description: Pattern for environment-specific Terraform variable files. `{env}` will be replaced by `environment_name`.
    *   `iac_backend_config_file_path_pattern`: (string, optional)
        *   Description: Pattern for environment-specific Terraform backend configuration files.
    *   `iac_cloud_provider`: (string, default: `azure`)
        *   Description: Cloud provider (e.g., `azure`, `aws`).
    *   `iac_terraform_command`: (string, default: `apply`)
        *   Description: Terraform command to execute for this stage (usually `apply`).
    *   `iac_azure_credentials_secret_name`: (string, default: `AZURE_CREDENTIALS`)
        *   Description: Name of the GitHub secret containing Azure credentials for Terraform.

*   **Database Migration Stage Inputs**:
    *   `db_migration_org_template_ref`: (string, required)
        *   Description: Full ref to the organizational DB migration template (e.g., `YourOrg/.github/.github/workflows/org-database-migration-efcore.yml@main`).
    *   `db_migration_efcore_project_path`: (string, required)
        *   Description: Path to the .NET project containing EF Core migrations.
    *   `db_migration_startup_project_path`: (string, optional)
        *   Description: Path to the startup project for EF Core tools. Defaults to `efcore_project_path`.
    *   `db_connection_string_source`: (string, required, choice: `keyVault`, `iacOutput`, `secret`)
        *   Description: Method to obtain the database connection string.
    *   `db_key_vault_name_iac_output_name`: (string, optional, default: `key_vault_name`)
        *   Description: Name of the output from the IaC stage job that provides the Key Vault name (if `db_connection_string_source: keyVault`).
    *   `db_connection_secret_name_in_kv_iac_output_name`: (string, optional, default: `db_connection_string_secret_name`)
        *   Description: Name of the output from the IaC stage job that provides the secret name in Key Vault (if `db_connection_string_source: keyVault`).
    *   `db_connection_string_iac_output_name`: (string, optional, default: `database_connection_string`)
        *   Description: Name of the output from the IaC stage job that provides the raw connection string (if `db_connection_string_source: iacOutput`).
    *   `db_connection_string_github_secret_name`: (string, optional)
        *   Description: Name of the GitHub secret holding the DB connection string (if `db_connection_string_source: secret`).
    *   `db_azure_credentials_secret_name_for_kv`: (string, default: `AZURE_CREDENTIALS`)
        *   Description: Name of the GitHub secret for Azure credentials if Key Vault access is needed by this stage.

*   **Application Deployment Stage Inputs**:
    *   `app_deploy_org_template_ref`: (string, required)
        *   Description: Full ref to the organizational App deployment template (e.g., `YourOrg/.github/.github/workflows/org-deploy-azure-app-service.yml@main`).
    *   `app_deploy_target_name_iac_output_name`: (string, optional, default: `app_service_name`)
        *   Description: Name of the output from the IaC stage job that provides the deployment target name (e.g., Azure App Service name).
    *   `app_deploy_azure_credentials_secret_name`: (string, default: `AZURE_CREDENTIALS`)
        *   Description: Name of the GitHub secret for Azure credentials for app deployment.

### B. Secrets (Inherited by the Orchestrator)

The orchestrator itself will need to inherit secrets that it then passes down to the organizational templates it calls.
*   `AZURE_CREDENTIALS` (or more specific ones like `AZURE_IAC_CREDENTIALS`, `AZURE_DB_KV_CREDENTIALS`, `AZURE_APP_DEPLOY_CREDENTIALS` if granular access is used).
*   Any other secrets required by the specific org templates being called (e.g., a specific `DB_CONNECTION_STRING_PROD_SECRET` if `db_connection_string_source: secret` is used).

### C. Outputs (from the Orchestrator)

*   `iac_outcome`: (string) Success/failure of the IaC stage.
*   `iac_outputs_json`: (string) JSON string of all outputs from the IaC org template.
*   `db_migration_outcome`: (string) Success/failure of the DB migration stage.
*   `app_deployment_outcome`: (string) Success/failure of the App deployment stage.
*   `app_url`: (string) The final URL of the deployed application, if available from the app deployment stage.
*   `overall_status`: (string) Overall success/failure of the orchestration.

## IV. Jobs Structure

The orchestrator will have sequential jobs, each potentially associated with the `inputs.environment_name` for GitHub Environment approvals.

1.  **`resolve_artifact` (Optional, can be integrated into `execute_app_deployment`)**
    *   **Purpose**: Determines the exact `run_id` for `app_build_artifact_name_pattern` if `app_build_artifact_run_id` is not provided, using `app_build_source_branch`.
    *   Uses `actions/github-script` to query GitHub API for the latest successful build run.
    *   **Outputs**: `resolved_artifact_run_id`.

2.  **`execute_iac`**
    *   **Purpose**: Provision or update infrastructure.
    *   **Environment**: `name: ${{ inputs.environment_name }}` (This enables approval gates if the environment is protected).
    *   **Steps**:
        *   Call `inputs.iac_org_template_ref` (e.g., `org-iac-terraform.yml`) with:
            *   `command: ${{ inputs.iac_terraform_command }}`
            *   `working-directory: ${{ inputs.iac_working_directory }}`
            *   `var-file: replacing {env} in inputs.iac_variables_file_path_pattern with inputs.environment_name`
            *   `backend-config-file: (similar pattern replacement for backend config)`
            *   `cloud-provider: ${{ inputs.iac_cloud_provider }}`
            *   Secrets like `AZURE_CREDENTIALS: ${{ secrets[inputs.iac_azure_credentials_secret_name] }}`.
    *   **Outputs**: Collect all outputs from the called `org-iac-terraform.yml` (e.g., `key_vault_name`, `db_connection_string_secret_name_in_kv`, `app_service_name`). Modern reusable workflows can output JSON. Let's assume the org template outputs a JSON string: `iac_step_outputs_json`.

3.  **`execute_db_migration`**
    *   `needs: execute_iac`
    *   **Purpose**: Apply database schema migrations.
    *   **Environment**: `name: ${{ inputs.environment_name }}`.
    *   **Steps**:
        *   Parse `needs.execute_iac.outputs.iac_step_outputs_json` to get specific IaC outputs.
        *   **Securely Obtain Connection String**:
            *   If `inputs.db_connection_string_source == 'keyVault'`:
                *   Use `azure/login@v1` with `secrets[inputs.db_azure_credentials_secret_name_for_kv]`.
                *   Use `azure/get-keyvault-secrets@v1` with Key Vault name and secret name (from parsed IaC outputs).
                *   Set the fetched connection string as an environment variable for the next step.
            *   If `inputs.db_connection_string_source == 'iacOutput'`:
                *   Use the connection string directly from parsed IaC outputs.
            *   If `inputs.db_connection_string_source == 'secret'`:
                *   Use `secrets[inputs.db_connection_string_github_secret_name]`.
        *   Call `inputs.db_migration_org_template_ref` (e.g., `org-database-migration-efcore.yml`) with:
            *   `efcore-project-path: ${{ inputs.db_migration_efcore_project_path }}`
            *   `startup-project-path: ${{ inputs.db_migration_startup_project_path }}`
            *   `environment-name: ${{ inputs.environment_name }}`
            *   The obtained `DB_CONNECTION_STRING` passed as a secret to the org template.

4.  **`execute_app_deployment`**
    *   `needs: execute_db_migration`
    *   **Purpose**: Deploy the application.
    *   **Environment**: `name: ${{ inputs.environment_name }}`.
    *   **Steps**:
        *   Parse `needs.execute_iac.outputs.iac_step_outputs_json` for `app_service_name` (or equivalent based on `inputs.app_deploy_target_name_iac_output_name`).
        *   Download the application artifact:
            *   Use `actions/download-artifact@v4`.
            *   `name: ${{ inputs.app_build_artifact_name_pattern }}` (potentially resolved with `application_name`).
            *   `run-id: ${{ steps.resolve_artifact.outputs.resolved_artifact_run_id || inputs.app_build_artifact_run_id }}`.
            *   `path: ./deployment_package`.
        *   Call `inputs.app_deploy_org_template_ref` (e.g., `org-deploy-azure-app-service.yml`) with:
            *   `environment-name: ${{ inputs.environment_name }}`
            *   `artifact-path: ./deployment_package`
            *   `azure-app-name: (from parsed IaC outputs)`
            *   `version: ${{ inputs.version_tag }}`
            *   Secrets like `AZURE_CREDENTIALS: ${{ secrets[inputs.app_deploy_azure_credentials_secret_name] }}`.
    *   **Outputs**: `app_url` if the deployment template provides it.

## V. Key Design Considerations for the Orchestrator

*   **Error Handling**: If a stage fails, the orchestration should stop.
*   **Output Management**: Efficiently passing structured outputs (like JSON strings) from one job to the next, especially from called reusable workflows.
*   **Approvals**: Ensuring the `environment` property on jobs correctly triggers GitHub Environment protection rules.
*   **Idempotency**: Each called org template should strive for idempotency.
*   **Clarity of Inputs**: Make inputs clear and well-documented.
*   **Versioning**: The orchestrator template itself should be versioned (e.g., callers use `@main` or `@v1`).

## VI. `SampleApp` as the First Consumer

The `SampleApp/.github/workflows/deploy-environment.yml` will be the first workflow to call this `org-environment-orchestrator.yml`. This will serve as a practical test case for the orchestrator's design and functionality.