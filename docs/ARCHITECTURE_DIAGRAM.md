# 🏗️ DataOps Project - Architecture Diagrams

> **Visual representation of the complete DataOps pipeline architecture**
> Version: 1.0 | Last Updated: 2024-01-15

---

## 📋 Table of Contents

1. [High-Level Architecture](#high-level-architecture)
2. [Data Flow Architecture](#data-flow-architecture)
3. [Infrastructure Architecture](#infrastructure-architecture)
4. [CI/CD Pipeline Architecture](#cicd-pipeline-architecture)
5. [DBT Model Lineage](#dbt-model-lineage)
6. [Deployment Architecture](#deployment-architecture)
7. [Network Architecture](#network-architecture)

---

## 🌐 High-Level Architecture

```mermaid
graph TB
    subgraph "Source System"
        A1[(SQL Server<br/>AdventureWorks 2014)]
    end

    subgraph "DataOps Pipeline"
        B1[DBT Transformation<br/>Bronze → Silver → Gold]
        B2[Apache Airflow<br/>Orchestration]
        B3[(PostgreSQL<br/>Airflow Metadata)]
    end

    subgraph "CI/CD Pipeline"
        C1[GitHub Actions<br/>CI Workflows]
        C2[GitHub Actions<br/>CD Workflows]
    end

    subgraph "Analytics Layer"
        D1[Power BI<br/>Dashboards]
        D2[Jupyter Notebooks<br/>Ad-hoc Analysis]
        D3[DBT Docs<br/>Data Catalog]
    end

    subgraph "Monitoring"
        E1[Airflow UI<br/>Pipeline Monitoring]
        E2[GitHub Actions<br/>Deployment Status]
        E3[Database Monitoring<br/>Performance Metrics]
    end

    A1 -->|Extract| B1
    B1 -->|Transform| B1
    B1 -->|Load| A1
    B2 -->|Orchestrate| B1
    B2 -->|Metadata| B3

    C1 -->|Test & Validate| B1
    C2 -->|Deploy| B1
    C2 -->|Deploy| B2

    B1 -->|Query| D1
    B1 -->|Query| D2
    B1 -->|Document| D3

    B2 -->|Monitor| E1
    C2 -->|Status| E2
    B1 -->|Metrics| E3

    style A1 fill:#e1f5ff
    style B1 fill:#fff3e0
    style B2 fill:#f3e5f5
    style C1 fill:#e8f5e9
    style C2 fill:#e8f5e9
    style D1 fill:#fce4ec
    style E1 fill:#f1f8e9
```

---

## 🔄 Data Flow Architecture

### Medallion Architecture (Bronze → Silver → Gold)

```mermaid
graph LR
    subgraph "Source"
        S1[SalesOrderHeader]
        S2[SalesOrderDetail]
        S3[Customer]
        S4[Person]
        S5[Product]
        S6[ProductCategory]
    end

    subgraph "Bronze Layer<br/>(Staging)"
        B1[brnz_sales_orders<br/>VIEW]
        B2[brnz_customers<br/>VIEW]
        B3[brnz_products<br/>VIEW]
    end

    subgraph "Silver Layer<br/>(Business Logic)"
        SL1[slvr_sales_orders<br/>TABLE]
        SL2[slvr_customers<br/>TABLE]
        SL3[slvr_products<br/>TABLE]
    end

    subgraph "Gold Layer<br/>(Analytics Marts)"
        G1[gld_sales_summary<br/>TABLE]
        G2[gld_customer_metrics<br/>TABLE]
        G3[gld_product_performance<br/>TABLE]
    end

    subgraph "Consumers"
        C1[📊 Power BI]
        C2[📈 Tableau]
        C3[🔬 Jupyter]
    end

    S1 --> B1
    S2 --> B1
    S3 --> B2
    S4 --> B2
    S5 --> B3
    S6 --> B3

    B1 --> SL1
    B2 --> SL2
    B3 --> SL3

    SL1 --> G1
    SL2 --> G2
    SL3 --> G3

    G1 --> C1
    G2 --> C1
    G3 --> C1

    G1 --> C2
    G2 --> C2
    G3 --> C2

    G1 --> C3
    G2 --> C3
    G3 --> C3

    style B1 fill:#ffd54f
    style B2 fill:#ffd54f
    style B3 fill:#ffd54f
    style SL1 fill:#c0c0c0
    style SL2 fill:#c0c0c0
    style SL3 fill:#c0c0c0
    style G1 fill:#ffd700
    style G2 fill:#ffd700
    style G3 fill:#ffd700
```

### Data Transformation Flow

```mermaid
flowchart TD
    A[Raw Source Data] -->|Extract| B{Data Quality Check}
    B -->|Valid| C[Bronze Layer<br/>Standardization]
    B -->|Invalid| X[Quarantine<br/>Error Handling]

    C -->|Clean & Type| D[Silver Layer<br/>Business Logic]

    D -->|Enrich| E[Add Time Intelligence]
    D -->|Calculate| F[Add Business Metrics]
    D -->|Segment| G[Add Customer Segmentation]

    E --> H[Gold Layer<br/>Aggregation]
    F --> H
    G --> H

    H -->|Daily Summary| I[gld_sales_summary]
    H -->|Customer Analytics| J[gld_customer_metrics]
    H -->|Product KPIs| K[gld_product_performance]

    I --> L[Analytics Dashboards]
    J --> L
    K --> L

    L -->|Feedback| M{Data Issues?}
    M -->|Yes| N[Create Data Quality Ticket]
    M -->|No| O[✅ Success]

    N --> P[Fix in Bronze/Silver]
    P --> C

    style C fill:#ffd54f
    style D fill:#c0c0c0
    style H fill:#ffd700
    style L fill:#4caf50
    style X fill:#f44336
```

---

## 🏢 Infrastructure Architecture

### Docker Compose Stack

```mermaid
graph TB
    subgraph "Docker Network: dataops-project_default"
        subgraph "Database Layer"
            D1[SQL Server 2019<br/>Port: 1433<br/>Source & Target DB]
            D2[PostgreSQL 13<br/>Port: 5432<br/>Airflow Metadata]
        end

        subgraph "Orchestration Layer"
            O1[Airflow Webserver<br/>Port: 8080<br/>UI & API]
            O2[Airflow Scheduler<br/>Background Jobs]
        end

        subgraph "Transformation Layer"
            T1[DBT Container<br/>Python 3.9<br/>DBT Core 1.5]
        end

        subgraph "Documentation Layer"
            DOC1[DBT Docs Server<br/>Port: 8001<br/>Static Site]
        end
    end

    subgraph "Local Filesystem"
        V1[./dbt → /usr/app/dbt]
        V2[./airflow/dags → /opt/airflow/dags]
        V3[./sqlserver/data → /var/opt/mssql/data]
    end

    O1 --> D2
    O2 --> D2
    O1 --> T1
    O2 --> T1
    T1 --> D1

    V1 -.-> T1
    V2 -.-> O1
    V2 -.-> O2
    V3 -.-> D1

    DOC1 -.->|Serves| V1

    style D1 fill:#e1f5ff
    style D2 fill:#e1f5ff
    style O1 fill:#f3e5f5
    style O2 fill:#f3e5f5
    style T1 fill:#fff3e0
    style DOC1 fill:#e8f5e9
```

### Container Dependencies

```mermaid
graph TD
    A[docker-compose up] --> B{Health Checks}

    B --> C[SQL Server<br/>HEALTHCHECK: sqlcmd query]
    B --> D[PostgreSQL<br/>HEALTHCHECK: pg_isready]

    C --> E{SQL Server Healthy?}
    D --> F{Postgres Healthy?}

    E -->|Yes| G[Start DBT Container]
    E -->|No| H[Wait & Retry<br/>30s timeout]

    F -->|Yes| I[Start Airflow Webserver]
    F -->|Yes| J[Start Airflow Scheduler]
    F -->|No| K[Wait & Retry<br/>30s timeout]

    G --> L[DBT Ready]
    I --> M[Airflow UI Available<br/>localhost:8080]
    J --> N[Airflow Scheduler Running]

    H --> E
    K --> F

    L --> O[✅ All Services Ready]
    M --> O
    N --> O

    style O fill:#4caf50
    style H fill:#ff9800
    style K fill:#ff9800
```

---

## 🚀 CI/CD Pipeline Architecture

### Complete CI/CD Flow

```mermaid
graph TB
    subgraph "Developer Workflow"
        A1[Developer<br/>Creates Feature Branch]
        A2[Push Code<br/>to GitHub]
        A3[Create Pull Request]
    end

    subgraph "CI Pipeline (Pull Requests)"
        B1[DBT Test Workflow<br/>✅ Compile, Parse, Debug]
        B2[Lint Workflow<br/>✅ SQL, Python, YAML]
        B3[PR Validation Workflow<br/>✅ Title, Description, Files]
    end

    subgraph "Code Review"
        C1{All CI Checks Pass?}
        C2[Code Review<br/>by Team Member]
        C3{Approved?}
    end

    subgraph "CD Pipeline (Deployment)"
        D1{Which Branch?}
        D2[Deploy to Dev<br/>develop branch]
        D3[Deploy to Prod<br/>main branch]

        D4[Pre-Deployment Checks]
        D5[Create Backup<br/>Production Only]
        D6[Run dbt deps]
        D7[Run dbt run]
        D8[Run dbt test]
        D9[Source Freshness Check]
        D10[Generate Documentation]
        D11[Health Check]
        D12[Send Notifications]
    end

    subgraph "Post-Deployment"
        E1{Deployment Success?}
        E2[✅ Merge Complete]
        E3[❌ Rollback Triggered]
        E4[Restore Previous Version]
        E5[Post-Incident Review]
    end

    A1 --> A2 --> A3
    A3 --> B1 & B2 & B3
    B1 --> C1
    B2 --> C1
    B3 --> C1

    C1 -->|Pass| C2
    C1 -->|Fail| A1
    C2 --> C3
    C3 -->|Yes| D1
    C3 -->|No| A1

    D1 -->|develop| D2
    D1 -->|main| D3

    D2 --> D4
    D3 --> D4

    D4 --> D5
    D5 --> D6
    D6 --> D7
    D7 --> D8
    D8 --> D9
    D9 --> D10
    D10 --> D11
    D11 --> D12

    D12 --> E1
    E1 -->|Yes| E2
    E1 -->|No| E3
    E3 --> E4 --> E5

    style B1 fill:#e8f5e9
    style B2 fill:#e8f5e9
    style B3 fill:#e8f5e9
    style D7 fill:#fff3e0
    style E2 fill:#4caf50
    style E3 fill:#f44336
```

### CI Workflow Details

```mermaid
stateDiagram-v2
    [*] --> PR_Created

    PR_Created --> CI_DBT_Test
    PR_Created --> CI_Lint
    PR_Created --> CI_PR_Validation

    state CI_DBT_Test {
        [*] --> Checkout_Code
        Checkout_Code --> Setup_Python
        Setup_Python --> Install_DBT
        Install_DBT --> DBT_Deps
        DBT_Deps --> DBT_Compile
        DBT_Compile --> DBT_Parse
        DBT_Parse --> DBT_Debug
        DBT_Debug --> Upload_Artifacts
        Upload_Artifacts --> [*]
    }

    state CI_Lint {
        [*] --> Checkout_Code_L
        Checkout_Code_L --> SQL_Lint
        Checkout_Code_L --> Python_Lint
        Checkout_Code_L --> YAML_Lint
        Checkout_Code_L --> Markdown_Lint
        SQL_Lint --> [*]
        Python_Lint --> [*]
        YAML_Lint --> [*]
        Markdown_Lint --> [*]
    }

    state CI_PR_Validation {
        [*] --> Validate_Title
        [*] --> Check_Merge_Conflicts
        [*] --> Check_File_Sizes
        [*] --> Validate_Changed_Files
        [*] --> Check_Description
        [*] --> Suggest_Labels
        Validate_Title --> [*]
        Check_Merge_Conflicts --> [*]
        Check_File_Sizes --> [*]
        Validate_Changed_Files --> [*]
        Check_Description --> [*]
        Suggest_Labels --> [*]
    }

    CI_DBT_Test --> All_CI_Complete
    CI_Lint --> All_CI_Complete
    CI_PR_Validation --> All_CI_Complete

    All_CI_Complete --> Code_Review
    Code_Review --> PR_Approved
    PR_Approved --> [*]
```

### CD Workflow Details

```mermaid
stateDiagram-v2
    [*] --> Merge_to_Branch

    Merge_to_Branch --> Determine_Environment

    state Determine_Environment {
        [*] --> Check_Branch
        Check_Branch --> Dev: develop branch
        Check_Branch --> Prod: main branch
        Dev --> [*]
        Prod --> [*]
    }

    Determine_Environment --> Pre_Deployment_Checks

    state Pre_Deployment_Checks {
        [*] --> Setup_DBT
        Setup_DBT --> Install_Packages
        Install_Packages --> Validate_Project
        Validate_Project --> Check_Breaking_Changes
        Check_Breaking_Changes --> [*]
    }

    Pre_Deployment_Checks --> Create_Backup

    state Create_Backup {
        [*] --> Check_If_Prod
        Check_If_Prod --> Skip: dev environment
        Check_If_Prod --> Backup_Metadata: prod environment
        Backup_Metadata --> Upload_Backup
        Upload_Backup --> [*]
        Skip --> [*]
    }

    Create_Backup --> Deploy_DBT

    state Deploy_DBT {
        [*] --> DBT_Deps
        DBT_Deps --> DBT_Run
        DBT_Run --> Upload_Results
        Upload_Results --> [*]
    }

    Deploy_DBT --> Run_Tests

    state Run_Tests {
        [*] --> DBT_Test
        DBT_Test --> Generate_Test_Results
        Generate_Test_Results --> Upload_Test_Results
        Upload_Test_Results --> [*]
    }

    Run_Tests --> Post_Deployment

    state Post_Deployment {
        [*] --> Check_Freshness
        [*] --> Generate_Docs
        [*] --> Health_Check
        Check_Freshness --> [*]
        Generate_Docs --> [*]
        Health_Check --> [*]
    }

    Post_Deployment --> Notify_Team
    Notify_Team --> [*]
```

---

## 📊 DBT Model Lineage

### Complete Data Lineage

```mermaid
graph TD
    subgraph "Source Tables"
        S1[(SalesOrderHeader)]
        S2[(SalesOrderDetail)]
        S3[(Customer)]
        S4[(Person)]
        S5[(Product)]
        S6[(ProductCategory)]
        S7[(ProductSubcategory)]
    end

    subgraph "Bronze Layer (Staging)"
        B1[brnz_sales_orders<br/>─────────────<br/>📄 VIEW<br/>🔑 sales_order_id<br/>📦 ~32K rows]
        B2[brnz_customers<br/>─────────────<br/>📄 VIEW<br/>🔑 customer_id<br/>📦 ~19K rows]
        B3[brnz_products<br/>─────────────<br/>📄 VIEW<br/>🔑 product_id<br/>📦 ~500 rows]
    end

    subgraph "Silver Layer (Business Logic)"
        SL1[slvr_sales_orders<br/>─────────────<br/>📊 TABLE<br/>🔑 order_detail_id<br/>📦 ~121K rows<br/>+ time_intelligence<br/>+ order_categorization<br/>+ shipping_metrics]
        SL2[slvr_customers<br/>─────────────<br/>📊 TABLE<br/>🔑 customer_id<br/>📦 ~19K rows<br/>+ RFM_segmentation<br/>+ lifetime_value<br/>+ customer_lifecycle]
        SL3[slvr_products<br/>─────────────<br/>📊 TABLE<br/>🔑 product_id<br/>📦 ~500 rows<br/>+ performance_metrics<br/>+ profitability<br/>+ sales_trends]
    end

    subgraph "Gold Layer (Analytics)"
        G1[gld_sales_summary<br/>─────────────<br/>🥇 TABLE<br/>🔑 order_date<br/>📦 ~1.5K rows<br/>+ daily_aggregates<br/>+ moving_averages<br/>+ YTD_metrics]
        G2[gld_customer_metrics<br/>─────────────<br/>🥇 TABLE<br/>🔑 customer_id<br/>📦 ~19K rows<br/>+ customer_360<br/>+ churn_prediction<br/>+ CLV_analysis]
        G3[gld_product_performance<br/>─────────────<br/>🥇 TABLE<br/>🔑 product_id<br/>📦 ~500 rows<br/>+ product_KPIs<br/>+ inventory_insights<br/>+ recommendations]
    end

    %% Source to Bronze
    S1 -->|SalesOrderID<br/>OrderDate<br/>CustomerID| B1
    S2 -->|SalesOrderDetailID<br/>ProductID<br/>OrderQty| B1
    S3 -->|CustomerID<br/>PersonID| B2
    S4 -->|BusinessEntityID<br/>FirstName<br/>LastName| B2
    S5 -->|ProductID<br/>Name<br/>ListPrice| B3
    S6 -->|ProductCategoryID<br/>Name| B3
    S7 -->|ProductSubcategoryID<br/>Name| B3

    %% Bronze to Silver
    B1 -->|Enrich & Transform| SL1
    B2 -->|Calculate RFM| SL2
    B3 -->|Add Metrics| SL3

    %% Silver to Gold
    SL1 -->|Aggregate by Date| G1
    SL2 -->|Customer 360 View| G2
    SL3 -->|Product KPIs| G3

    %% Cross-layer relationships
    SL1 -.->|customer_id| SL2
    SL1 -.->|product_id| SL3

    style S1 fill:#e3f2fd
    style S2 fill:#e3f2fd
    style S3 fill:#e3f2fd
    style S4 fill:#e3f2fd
    style S5 fill:#e3f2fd
    style S6 fill:#e3f2fd
    style S7 fill:#e3f2fd
    style B1 fill:#fff9c4
    style B2 fill:#fff9c4
    style B3 fill:#fff9c4
    style SL1 fill:#e0e0e0
    style SL2 fill:#e0e0e0
    style SL3 fill:#e0e0e0
    style G1 fill:#fff9c4,stroke:#ffd700,stroke-width:3px
    style G2 fill:#fff9c4,stroke:#ffd700,stroke-width:3px
    style G3 fill:#fff9c4,stroke:#ffd700,stroke-width:3px
```

### Column-Level Lineage Example (Sales Orders)

```mermaid
graph LR
    subgraph "Source"
        A1[SalesOrderHeader<br/>SalesOrderID]
        A2[SalesOrderHeader<br/>OrderDate]
        A3[SalesOrderDetail<br/>LineTotal]
        A4[SalesOrderDetail<br/>OrderQty]
    end

    subgraph "Bronze"
        B1[brnz_sales_orders<br/>sales_order_id]
        B2[brnz_sales_orders<br/>order_date]
        B3[brnz_sales_orders<br/>line_total]
        B4[brnz_sales_orders<br/>order_qty]
    end

    subgraph "Silver"
        C1[slvr_sales_orders<br/>sales_order_id]
        C2[slvr_sales_orders<br/>order_date]
        C3[slvr_sales_orders<br/>order_year]
        C4[slvr_sales_orders<br/>order_month]
        C5[slvr_sales_orders<br/>line_total]
        C6[slvr_sales_orders<br/>order_value_tier]
    end

    subgraph "Gold"
        D1[gld_sales_summary<br/>order_date]
        D2[gld_sales_summary<br/>total_revenue]
        D3[gld_sales_summary<br/>ytd_revenue]
    end

    A1 --> B1 --> C1
    A2 --> B2 --> C2
    C2 --> C3
    C2 --> C4
    A3 --> B3 --> C5
    C5 --> C6
    A4 --> B4

    C2 --> D1
    C5 --> D2
    D2 --> D3

    style A1 fill:#e3f2fd
    style A2 fill:#e3f2fd
    style A3 fill:#e3f2fd
    style A4 fill:#e3f2fd
    style B1 fill:#fff9c4
    style B2 fill:#fff9c4
    style B3 fill:#fff9c4
    style B4 fill:#fff9c4
    style C1 fill:#e0e0e0
    style C2 fill:#e0e0e0
    style C3 fill:#e0e0e0
    style C4 fill:#e0e0e0
    style C5 fill:#e0e0e0
    style C6 fill:#e0e0e0
    style D1 fill:#fffde7
    style D2 fill:#fffde7
    style D3 fill:#fffde7
```

---

## 🌍 Deployment Architecture

### Multi-Environment Architecture

```mermaid
graph TB
    subgraph "Development Environment"
        DEV1[Local Docker<br/>SQL Server]
        DEV2[DBT Dev Target<br/>localhost:1433]
        DEV3[Airflow Dev<br/>Manual Triggers]
    end

    subgraph "Staging Environment (Optional)"
        STG1[Staging SQL Server<br/>staging.company.com]
        STG2[DBT Staging Target<br/>staging DB]
        STG3[Airflow Staging<br/>Nightly Schedule]
    end

    subgraph "Production Environment"
        PROD1[Production SQL Server<br/>prod.company.com]
        PROD2[DBT Prod Target<br/>production DB]
        PROD3[Airflow Production<br/>Daily 1AM UTC]
        PROD4[Monitoring<br/>Alerts & SLA]
    end

    subgraph "GitHub Actions Runners"
        GHA1[CI Runner<br/>ubuntu-latest]
        GHA2[CD Runner<br/>ubuntu-latest]
    end

    DEV1 -.->|Test Locally| DEV2
    DEV2 -.->|Manual Deploy| DEV3

    GHA1 -->|Validate| DEV2
    GHA2 -->|Auto Deploy| STG2
    GHA2 -->|Auto Deploy| PROD2

    STG1 -->|Promote| PROD1
    STG2 -->|Promote| PROD2

    PROD2 --> PROD3
    PROD3 --> PROD4

    style DEV1 fill:#e8f5e9
    style STG1 fill:#fff3e0
    style PROD1 fill:#ffebee
    style PROD4 fill:#f3e5f5
```

### Deployment Flow with Approvals

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant CI as CI Pipeline
    participant DevEnv as Dev Environment
    participant StagingEnv as Staging Environment
    participant ProdEnv as Production Environment
    participant Slack as Slack Notifications

    Dev->>GH: Push to feature branch
    GH->>CI: Trigger CI workflows
    CI->>CI: Run DBT tests
    CI->>CI: Run linting
    CI->>CI: Validate PR
    CI-->>GH: CI status ✅

    Dev->>GH: Create Pull Request
    GH->>Dev: Request code review
    Dev->>GH: Approve PR

    Dev->>GH: Merge to develop
    GH->>DevEnv: Auto deploy
    DevEnv->>DevEnv: Run DBT models
    DevEnv->>DevEnv: Run tests
    DevEnv-->>Slack: Deployment success

    Note over Dev,DevEnv: Test in Dev for 1-2 days

    Dev->>GH: Merge develop → main
    GH->>ProdEnv: Auto deploy

    ProdEnv->>ProdEnv: Pre-deployment checks
    ProdEnv->>ProdEnv: Create backup
    ProdEnv->>ProdEnv: Run DBT models
    ProdEnv->>ProdEnv: Run tests
    ProdEnv->>ProdEnv: Health checks

    alt Deployment Success
        ProdEnv-->>Slack: ✅ Deployment success
        ProdEnv-->>GH: Update deployment status
    else Deployment Failure
        ProdEnv->>ProdEnv: Auto rollback
        ProdEnv-->>Slack: ❌ Deployment failed (rolled back)
        ProdEnv-->>Dev: Create incident ticket
    end
```

---

## 🌐 Network Architecture

### Docker Network Topology

```mermaid
graph TB
    subgraph "Host Machine"
        H1[localhost:1433<br/>SQL Server]
        H2[localhost:5432<br/>PostgreSQL]
        H3[localhost:8080<br/>Airflow UI]
        H4[localhost:8001<br/>DBT Docs]
    end

    subgraph "Docker Bridge Network: dataops-project_default"
        subgraph "Database Services"
            N1[sqlserver:1433<br/>Internal]
            N2[postgres:5432<br/>Internal]
        end

        subgraph "Application Services"
            N3[airflow-webserver:8080<br/>Internal]
            N4[airflow-scheduler<br/>No external port]
            N5[dbt<br/>No external port]
        end
    end

    H1 -.->|Port Mapping| N1
    H2 -.->|Port Mapping| N2
    H3 -.->|Port Mapping| N3
    H4 -.->|Volume Mount| N5

    N3 -->|PostgreSQL Connection| N2
    N4 -->|PostgreSQL Connection| N2
    N3 -->|Exec DBT Commands| N5
    N4 -->|Exec DBT Commands| N5
    N5 -->|SQL Server Connection| N1

    style N1 fill:#e1f5ff
    style N2 fill:#e1f5ff
    style N3 fill:#f3e5f5
    style N4 fill:#f3e5f5
    style N5 fill:#fff3e0
```

### Security Architecture

```mermaid
graph TB
    subgraph "Security Layers"
        S1[GitHub Secrets<br/>Encrypted Credentials]
        S2[Environment Variables<br/>Runtime Secrets]
        S3[Docker Secrets<br/>Container Isolation]
        S4[Database Permissions<br/>Least Privilege]
    end

    subgraph "Access Control"
        A1[GitHub Teams<br/>Code Access]
        A2[Service Accounts<br/>Deployment Access]
        A3[Read-Only Users<br/>Analytics Access]
    end

    subgraph "Network Security"
        N1[Docker Network Isolation<br/>Internal Communication]
        N2[Firewall Rules<br/>Port Restrictions]
        N3[TLS/SSL<br/>Encrypted Connections]
    end

    subgraph "Monitoring & Audit"
        M1[GitHub Audit Log<br/>Code Changes]
        M2[Airflow Logs<br/>Pipeline Execution]
        M3[Database Audit<br/>Query Tracking]
    end

    S1 --> S2 --> S3 --> S4
    A1 --> A2 --> A3
    N1 --> N2 --> N3
    M1 --> M2 --> M3

    style S1 fill:#c8e6c9
    style A1 fill:#ffccbc
    style N1 fill:#b3e5fc
    style M1 fill:#f0f4c3
```

---

## 📊 Performance Architecture

### Query Optimization Strategy

```mermaid
graph LR
    subgraph "Bronze Layer"
        B1[VIEWs<br/>Lightweight<br/>Real-time Data]
    end

    subgraph "Silver Layer"
        S1[TABLEs<br/>Pre-computed<br/>Business Logic]
        S2[Indexes on:<br/>- customer_id<br/>- product_id<br/>- order_date]
    end

    subgraph "Gold Layer"
        G1[TABLEs<br/>Aggregated<br/>Fast Queries]
        G2[Materialized<br/>Daily Refresh]
    end

    subgraph "Query Performance"
        Q1[Bronze Queries:<br/>~1-2 seconds]
        Q2[Silver Queries:<br/>~0.5-1 second]
        Q3[Gold Queries:<br/>~0.1-0.3 seconds]
    end

    B1 -.->|SELECT *| Q1
    S1 -->|Indexed JOIN| Q2
    G1 -->|Pre-aggregated| Q3

    style Q3 fill:#4caf50
    style Q2 fill:#8bc34a
    style Q1 fill:#cddc39
```

---

## 📈 Scalability Architecture

### Horizontal Scaling Strategy

```mermaid
graph TB
    subgraph "Current (Single Instance)"
        C1[1x Airflow Scheduler]
        C2[1x Airflow Webserver]
        C3[1x DBT Container]
        C4[1x SQL Server]
    end

    subgraph "Future (Scaled)"
        F1[3x Airflow Scheduler<br/>Load Balanced]
        F2[2x Airflow Webserver<br/>Behind Load Balancer]
        F3[Multiple DBT Workers<br/>Kubernetes Pods]
        F4[SQL Server with<br/>Read Replicas]
    end

    subgraph "Scaling Triggers"
        T1[Pipeline Duration > 2 hours]
        T2[Database CPU > 80%]
        T3[Concurrent DAG runs > 10]
    end

    C1 -.->|When| T1
    C2 -.->|When| T2
    C3 -.->|When| T3

    T1 --> F1
    T2 --> F2
    T3 --> F3

    style F1 fill:#4caf50
    style F2 fill:#4caf50
    style F3 fill:#4caf50
    style F4 fill:#4caf50
```

---

## 📝 Diagram Legend

### Symbols and Colors

```mermaid
graph LR
    A[(Database<br/>Cylinder)]
    B[Service<br/>Rectangle]
    C{Decision<br/>Diamond}
    D([Event<br/>Stadium])

    E[Source System]
    F[Bronze Layer]
    G[Silver Layer]
    H[Gold Layer]
    I[Consumer]
    J[Success]
    K[Failure]

    style E fill:#e3f2fd
    style F fill:#fff9c4
    style G fill:#e0e0e0
    style H fill:#fffde7
    style I fill:#f3e5f5
    style J fill:#4caf50
    style K fill:#f44336
```

### Node Types

- **Cylinder** [(Database)]: Database or storage system
- **Rectangle** [Service]: Application service or component
- **Diamond** {Decision}: Conditional logic or gateway
- **Stadium** ([Event]): Event or trigger point

### Color Coding

| Color | Meaning | Example |
|-------|---------|---------|
| Light Blue (#e3f2fd) | Source Systems | SQL Server source tables |
| Yellow (#fff9c4) | Bronze Layer | Staging views |
| Gray (#e0e0e0) | Silver Layer | Business logic tables |
| Light Yellow (#fffde7) | Gold Layer | Analytics marts |
| Purple (#f3e5f5) | Orchestration | Airflow components |
| Green (#4caf50) | Success | Successful deployment |
| Red (#f44336) | Failure | Failed deployment |

---

## 🔗 Related Documentation

- **Architecture Overview**: [ARCHITECTURE.md](./ARCHITECTURE.md)
- **Data Lineage Details**: [DATA_LINEAGE.md](./DATA_LINEAGE.md)
- **Deployment Runbook**: [DEPLOYMENT_RUNBOOK.md](./DEPLOYMENT_RUNBOOK.md)
- **CI/CD Guide**: [CI_CD_GUIDE.md](./CI_CD_GUIDE.md)
- **Multi-Environment Setup**: [MULTI_ENVIRONMENT_SETUP.md](./MULTI_ENVIRONMENT_SETUP.md)

---

**Last Updated**: 2024-01-15
**Maintained By**: Data Engineering Team
**Version**: 1.0

For questions or updates, please create an issue or contact the data engineering team.
