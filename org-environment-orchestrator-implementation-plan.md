# Plan to Create `org-environment-orchestrator.yml`

This plan outlines the steps to create the GitHub Actions organizational workflow template, `org-environment-orchestrator.yml`, based on the specifications in `OrgEnvironmentOrchestrator_Plan.md` and user-provided information.

**GitHub Organization**: `InwardEcho`
**Templates Repository**: `.github`

This means the reusable workflow references in the `org-environment-orchestrator.yml` will look like:
*   IaC template: `InwardEcho/.github/.github/workflows/org-iac-terraform.yml@main`
*   DB Migration template: `InwardEcho/.github/.github/workflows/org-database-migration-efcore.yml@main`
*   App Deployment template: `InwardEcho/.github/.github/workflows/org-deploy-azure-app-service.yml@main`
(Assuming `@main` as the default branch/tag).

**1. File Location:**

*   The new workflow template will be created at: `../InwardEcho.github/.github/workflows/org-environment-orchestrator.yml`
    *   *(This assumes placement directly into the central template repository structure. If it should be developed within `SampleApp` first and then moved, this would need adjustment.)*

**2. Core Structure (based on `OrgEnvironmentOrchestrator_Plan.md`):**

*   **`name`**: `Organizational Environment Orchestrator`
*   **`on: workflow_call`**:
    *   **Inputs**: Define all inputs as specified in Section III.A of the `OrgEnvironmentOrchestrator_Plan.md`. This includes:
        *   `environment_name` (string, required)
        *   `application_name` (string, required)
        *   `app_build_artifact_name_pattern` (string, optional, default: `{{application_name}}-deployment-package`)
        *   `app_build_artifact_run_id` (string, optional)
        *   `app_build_source_branch` (string, optional)
        *   `version_tag` (string, optional)
        *   **IaC Stage Inputs**:
            *   `iac_org_template_ref` (string, required, default: `InwardEcho/.github/.github/workflows/org-iac-terraform.yml@main`)
            *   `iac_working_directory` (string, default: `./infra`)
            *   `iac_variables_file_path_pattern` (string, default: `{working_directory}/{env}.tfvars`)
            *   `iac_backend_config_file_path_pattern` (string, optional)
            *   `iac_cloud_provider` (string, default: `azure`)
            *   `iac_terraform_command` (string, default: `apply`)
            *   `iac_azure_credentials_secret_name` (string, default: `AZURE_CREDENTIALS`)
        *   **Database Migration Stage Inputs**:
            *   `db_migration_org_template_ref` (string, required, default: `InwardEcho/.github/.github/workflows/org-database-migration-efcore.yml@main`)
            *   `db_migration_efcore_project_path` (string, required)
            *   `db_migration_startup_project_path` (string, optional)
            *   `db_connection_string_source` (string, required, choice: `keyVault`, `iacOutput`, `secret`)
            *   `db_key_vault_name_iac_output_name` (string, optional, default: `key_vault_name`)
            *   `db_connection_secret_name_in_kv_iac_output_name` (string, optional, default: `db_connection_string_secret_name`)
            *   `db_connection_string_iac_output_name` (string, optional, default: `database_connection_string`)
            *   `db_connection_string_github_secret_name` (string, optional)
            *   `db_azure_credentials_secret_name_for_kv` (string, default: `AZURE_CREDENTIALS`)
        *   **Application Deployment Stage Inputs**:
            *   `app_deploy_org_template_ref` (string, required, default: `InwardEcho/.github/.github/workflows/org-deploy-azure-app-service.yml@main`)
            *   `app_deploy_target_name_iac_output_name` (string, optional, default: `app_service_name`)
            *   `app_deploy_azure_credentials_secret_name` (string, default: `AZURE_CREDENTIALS`)
    *   **Secrets**: Define inherited secrets as per Section III.B of `OrgEnvironmentOrchestrator_Plan.md` (e.g., `AZURE_CREDENTIALS`).
    *   **Outputs**: Define outputs as specified in Section III.C of `OrgEnvironmentOrchestrator_Plan.md` (e.g., `iac_outcome`, `iac_outputs_json`, `db_migration_outcome`, `app_deployment_outcome`, `app_url`, `overall_status`).

**3. Jobs Structure (as per Section IV of `OrgEnvironmentOrchestrator_Plan.md`):**

*   A Mermaid diagram illustrating the job dependencies:
    ```mermaid
    graph TD
        A[resolve_artifact (Optional)] --> C{execute_iac};
        C --> D{execute_db_migration};
        D --> E{execute_app_deployment};
        E --> F[Collect Outputs & Set Overall Status];
    ```

*   **`resolve_artifact` (Job)**:
    *   Conditional execution.
    *   Purpose: Determine `run_id` for the application artifact if not provided.
    *   Uses `actions/github-script`.
    *   Outputs: `resolved_artifact_run_id`.

*   **`execute_iac` (Job)**:
    *   Purpose: Provision/update infrastructure.
    *   `environment: name: ${{ inputs.environment_name }}` for approval gates.
    *   Calls `inputs.iac_org_template_ref` with appropriate inputs and secrets.
    *   Outputs: `iac_step_outputs_json` (JSON string of outputs from the called IaC template).

*   **`execute_db_migration` (Job)**:
    *   `needs: execute_iac`.
    *   Purpose: Apply database schema migrations.
    *   `environment: name: ${{ inputs.environment_name }}`.
    *   Steps:
        *   Parse `needs.execute_iac.outputs.iac_step_outputs_json`.
        *   Implement logic to securely obtain the DB connection string based on `inputs.db_connection_string_source`:
            *   `keyVault`: Use `azure/login` and `azure/get-keyvault-secrets`.
            *   `iacOutput`: Use directly from parsed IaC outputs.
            *   `secret`: Use from `secrets[inputs.db_connection_string_github_secret_name]`.
        *   Calls `inputs.db_migration_org_template_ref` with appropriate inputs and the obtained connection string.

*   **`execute_app_deployment` (Job)**:
    *   `needs: execute_db_migration`.
    *   Purpose: Deploy the application.
    *   `environment: name: ${{ inputs.environment_name }}`.
    *   Steps:
        *   Parse `needs.execute_iac.outputs.iac_step_outputs_json` for deployment target name.
        *   Download application artifact using `actions/download-artifact`.
        *   Calls `inputs.app_deploy_org_template_ref` with appropriate inputs and secrets.
    *   Outputs: `app_url`.

*   **`post_orchestration_status` (Implied final job or steps within last job):**
    *   This job (or steps at the end of `execute_app_deployment`) will determine the `overall_status` output based on the success/failure of previous jobs.
    *   It will also consolidate and set the final outputs of the orchestrator workflow (`iac_outcome`, `db_migration_outcome`, `app_deployment_outcome`, `app_url`).

**4. Key Implementation Details:**

*   **Error Handling**: Ensure `if: success()` or `if: failure()` conditions are used appropriately to manage job flow and set outcome statuses. Orchestration should stop on failure.
*   **Output Management**: Use job outputs to pass data (like `iac_step_outputs_json`) between dependent jobs.
*   **Input Mapping**: Carefully map the orchestrator's inputs to the inputs of the called reusable workflows.
*   **Secret Propagation**: Pass necessary secrets from the orchestrator's `secrets` block to the `secrets` block of the `uses:` steps for child workflows.
*   **Versioning**: The orchestrator itself should be versionable. Callers will use a ref (e.g., `@main` or `@v1`).

**5. `SampleApp` as Consumer:**

*   `SampleApp/.github/workflows/deploy-environment.yml` will be the first consumer. This file will need to be updated to call `InwardEcho/.github/.github/workflows/org-environment-orchestrator.yml@main` (or appropriate version) with the required inputs and secrets.