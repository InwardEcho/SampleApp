# Plan for SampleApp

This document outlines the plan for creating `SampleApp`, a demonstration application designed to test GitHub Organizational Workflow Templates.

## I. Core Task and Objectives

*   **Primary Goal**: Develop a simple C# application with an EF Core-managed SQL Server database and Terraform-managed Azure infrastructure.
*   **Purpose**: Serve as a testbed for existing GitHub Organizational Workflow Templates, particularly for build, test, IaC, database migration, and deployment.
*   **Demonstrate**:
    *   Application build and test processes.
    *   Infrastructure provisioning via Terraform.
    *   EF Core database migrations (initial schema and a subsequent schema change).
    *   Application deployment to Azure.
    *   Integration with organizational workflow templates.

## II. Application Design (`SampleApp.WebApp`)

1.  **Application Type**: ASP.NET Core Razor Pages.
    *   Provides a simple single-page UI for displaying data.
2.  **Database Entity (`MyEntity.cs`)**:
    *   `Id` (int, Primary Key, Identity)
    *   `Name` (string)
    *   *Migration Demo Field*: `Description` (string, nullable) - to be added later.
3.  **EF Core Setup**:
    *   `AppDbContext` within the `SampleApp.WebApp` project.
    *   `DbSet<MyEntity>`.
    *   Connection string configured to be read from environment variables (e.g., `ConnectionStrings__DefaultConnection`) to align with migration and deployment workflows.
    *   `SampleApp.WebApp` will serve as both the EF Core migrations project and the startup project.
4.  **User Interface (`Pages/Index.cshtml`)**:
    *   Displays a list of `MyEntity` records (Id, Name).
    *   Will be updated to show `Description` after the migration demo.
5.  **Unit Tests (`SampleApp.Tests`)**:
    *   Separate xUnit test project.
    *   Basic unit tests for page models or services.
    *   Configured to produce Cobertura code coverage reports.
6.  **Health Check Endpoint**:
    *   Simple `/health` endpoint in the Razor Pages app for deployment workflow health checks.

## III. Infrastructure Design (Terraform for Azure)

*   **Location**: `infra/` directory within `SampleApp`.
*   **Cloud Provider**: Microsoft Azure.
*   **Terraform State**: Remote state managed in Azure Blob Storage, configured per environment (e.g., `dev`, `prod`).
    *   Example `backend.tf`:
        ```terraform
        terraform {
          backend "azurerm" {
            # Configuration will be passed via -backend-config or a backend config file per environment
            # key = "sampleapp/{env}/terraform.tfstate"
          }
        }
        ```
*   **Resources to be Defined by Terraform**:
    1.  Azure Resource Group.
    2.  Azure SQL Server instance.
    3.  Azure SQL Database.
    4.  Azure App Service Plan.
    5.  Azure App Service (for the .NET Razor Pages application).
    6.  Configuration for App Service:
        *   Connection string for SQL Database (set via App Settings, ideally using Key Vault references).
    7.  Azure Key Vault (for storing secrets like the DB connection string).

## IV. Project Structure

```
SampleApp/
├── .github/
│   └── workflows/
│       ├── ci-build-test.yml
│       └── deploy-environment.yml  # This will call the org-environment-orchestrator.yml
├── .gitignore
├── README.md
├── SampleApp.sln
├── src/
│   └── SampleApp.WebApp/
│       ├── SampleApp.WebApp.csproj
│       ├── Program.cs
│       ├── appsettings.json
│       ├── appsettings.Development.json
│       ├── Models/
│       │   └── MyEntity.cs
│       ├── Data/
│       │   ├── AppDbContext.cs
│       │   └── Migrations/  # EF Core migrations will be generated here
│       └── Pages/
│           ├── Index.cshtml
│           └── Index.cshtml.cs
│       └── wwwroot/
├── tests/
│   └── SampleApp.Tests/
│       ├── SampleApp.Tests.csproj
│       └── # Unit test files
└── infra/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── backend.tf # Defines backend type, actual config per env
    ├── dev.tfvars # Example environment-specific variables
    └── prod.tfvars # Example environment-specific variables
```

## V. GitHub Actions Workflow Integration (Local Callers in `SampleApp`)

The primary local workflow will be `deploy-environment.yml`, which will call the new `org-environment-orchestrator.yml` organizational template.

1.  **`SampleApp/.github/workflows/ci-build-test.yml`**:
    *   **Triggers**: `push` to all branches, `pull_request` to default/develop.
    *   **Calls**: Existing `org-build-test-dotnet.yml` organizational template.
    *   **Purpose**: Build, test, generate coverage, package application, and upload `SampleApp-deployment-package` artifact.

2.  **`SampleApp/.github/workflows/deploy-environment.yml`**:
    *   **Triggers**: `workflow_dispatch` (manual) with inputs for `environment_to_deploy` (dev, prod) and artifact source details.
    *   **Calls**: The new `org-environment-orchestrator.yml` organizational template.
    *   **Purpose**: Orchestrates the deployment of a complete environment (IaC, DB Migration, App Deploy) by leveraging the organizational orchestrator.
    *   **Secrets**: Passes necessary secrets (e.g., `AZURE_CREDENTIALS`) to the orchestrator.

## VI. Demonstration Flow

1.  **Initial Setup**:
    *   Create the `SampleApp` project structure.
    *   Implement the basic `MyEntity` (Id, Name) and `AppDbContext`.
    *   Create the initial EF Core migration.
    *   Develop basic Terraform files for Azure resources.
    *   Develop the `ci-build-test.yml` workflow.
    *   Develop the `deploy-environment.yml` workflow to call the (yet to be developed) `org-environment-orchestrator.yml`.
2.  **Develop `org-environment-orchestrator.yml`** (See separate plan).
3.  **Workflow Execution (Round 1 - Initial Deploy)**:
    *   Trigger `deploy-environment.yml` for 'dev' environment.
        *   Orchestrator calls `org-iac-terraform.yml` (creates infra, stores DB conn string in Key Vault).
        *   Orchestrator calls `org-database-migration-efcore.yml` (applies initial schema, fetches conn string from Key Vault).
        *   Orchestrator calls `org-deploy-azure-app-service.yml` (deploys app, app reads conn string from App Settings via Key Vault ref).
    *   Verify: App is accessible and shows an empty list or seeded data.
4.  **Migration Demo**:
    *   Add `Description` property to `MyEntity.cs`.
    *   Generate a new EF Core migration (e.g., `AddEntityDescription`).
    *   Update `Index.cshtml` to display the `Description`.
    *   Commit changes. `ci-build-test.yml` runs, creates new artifact.
5.  **Workflow Execution (Round 2 - Deploy Update with Migration)**:
    *   Trigger `deploy-environment.yml` for 'dev' environment again (pointing to the new build artifact).
        *   Orchestrator calls `org-iac-terraform.yml` (likely no changes to infra).
        *   Orchestrator calls `org-database-migration-efcore.yml` (applies the new `AddEntityDescription` migration).
        *   Orchestrator calls `org-deploy-azure-app-service.yml` (deploys updated app).
    *   Verify: App shows the new `Description` field; database schema is updated.
6.  **Production Deployment Demo**:
    *   Trigger `deploy-environment.yml` for 'prod' environment.
    *   Demonstrate GitHub Environment approval gates for each stage within the orchestrator.

## VII. Key Strategies

*   **Deployment Order**: IaC -> DB Migration -> App Deployment, orchestrated by `org-environment-orchestrator.yml`.
*   **Approvals**: GitHub Environments for 'prod' (and other non-dev) to gate sensitive operations.
*   **Secrets**: Azure Key Vault for DB connection strings; GitHub secrets for Azure credentials.
*   **Terraform State**: Remote backend in Azure Blob Storage.
*   **Artifact Management**: Clear linking of build artifacts to deployments.