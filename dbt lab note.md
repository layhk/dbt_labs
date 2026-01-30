# Google Big Query
----------
1. **No need to setup connection** like AWS or Azure.
   
   Just sign in to the Google account and type `SELECT` statement, then we can view the public dataset or any dataset for which we are granted permission.

   The permission is at the **dataset** level, not the bucket or container level.

# DBT
----
1. The **dbt_project.yml** file at the root configuration will set the config global.
   
   _this file also set project name_
   
   *Example*: If set `default output = materialized table`, then when we execute any model, the output will be saved as a table in the data platform.
 
   > **Note**: The default setting in dbt is actually `view`.

   > **To override global setting**: Set *Jinja* macro in individual model file.
   > *Example*: `{{ config(materialized='view') }}`

1. **Modular**: Trying to break down to module or smaller piece, like a complex stored proc that has many CTE, save each CTE as a single model.

   **Benefit**:
   * **Reusability**: each model can be referenced in another model using `ref` macro.
     * *Example*: `select * from {{ ref('stg_jaffle_shop_customers') }}` 
   * **Data lineage is formed**: easy for maintenance and tracking.

1. **Deploy model** to the data platform can include the dependencies.

   *Example*: `dbt run --select +customer`
   > This means deploy customer model and its **upstream** dependencies.
   
   **Benefit**:
   * **Resolve dependencies**: We don't need to manually deploy objects one by one and in sequence in other platforms (such as Snowflake).
  
1. **Source control**:
   * **Source file** can be created as `_stg_table.yml` that specify the source (db, schema, table) and destination model (table) used.
   * *Example*:
     ```yaml
     sources:
       - name: jaffle_shop
         database: dbt-tutorial
         schema: jaffle_shop
         # Config block if moved here (before tables), it becomes global for all tables
         tables:
           - name: customers 
           - name: orders
             config:
               # Freshness checks if the data is "stale" (outdated)
               freshness:
                 warn_after:
                   count: 12
                   period: hour # Warn if no new data in 12 hours
                 error_after: 
                   count: 1
                   period: day  # Error if no new data in 24 hours
               
               # Specifies which column dbt should check to see when data was last loaded
               loaded_at_field: _etl_loaded_at
     ```
   * Later in destination model, use the **source macro** e.g. `from {{ source('jaffle_shop', 'orders') }}` to reference it.
   * **Check freshness** of data using `dbt source freshness` - it will warn or error if data is stale based on the **config** in source yml above.
   * **Config block**: If moved up to before defining `tables`, then it will be global to all tables below. The example above is for `orders` table only.

1. **Installing packages**: 
   * Create `packages.yml` at root folder and paste the package definition from the [dbt Hub](https://hub.getdbt.com/).
   * Run `dbt deps` command to install the package.
   * **E.g. codegen package**: used to generate code automatically instead of typing manually.
     1. Open a new file and paste the command, then click **compile** button:
        `{{ codegen.generate_source(schema_name= 'jaffle_shop', database_name= 'dbt-tutorial') }}`
     2. This generates the source YAML content; copy-paste it into a new file and save as `_src_jaffle_shop.yml`.
     3. In the `_src_` file, click **generate model** above the table to populate the model code in a new window.
     4. **Auto-population**: The code includes the `source` macro and follows the `stg_<db>_<table>` naming convention with all source columns.
     5. Save the model file and refresh the **data lineage** to see the new model linked to the source.

1. **The dbt Boundary: Sources vs. Files**
   
   > **The Golden Rule**: dbt can ONLY query **existing tables or views** already inside the data platform (Snowflake/BigQuery). It cannot "read" or "ingest" raw files (CSV, JSON, Parquet) from a cloud drive like Azure Blob or S3.

   * **The Handoff**:
     * **Ingestion (DE Task)**: Use **ADF**, **Snowpipe**, or **Python** to move the file from Blob storage into a "Raw" table.
     * **Transformation (AE Task)**: dbt takes over *after* the data has landed in that table.
   
   * **What is a "Source" in dbt?**
     * It is **NOT** a file. It is a **Raw Table** that already exists in the database but was created by a process *outside* of dbt (like ADF/Snowflake pipeline).
    
1. **Data Quality Testing**:
> External Packages:<br>
    > Refer [dbt-utils](https://hub.getdbt.com/dbt-labs/dbt_utils/latest/) for ready-made queries.<br>
    > Refer [dbt-expectations](https://hub.getdbt.com/metaplane/dbt_expectations/latest/) for ready-made test cases.
> 
   * **a. Generic Tests**: Defined in the **YAML** file, can be applied in different models and columns.
     * _Pre-built functions_: `unique`, `not_null`, `accepted_values`, `relationships`.
     * _Implementation_: Place this in the staging folder (e.g., `_stg_jaffle_shop.yml`) to define the testing for each model.
     
     ```yaml
     # models/staging/jaffle_shop/_stg_jaffle_shop.yml
     models:
       - name: tableA
         columns:
           - name: customer_id
             data_tests:
               - unique
               - not_null
       - name: tableB
         columns:
           - name: user_id
             data_tests:
               - unique
           - name: location
             data_tests:
               - accepted_values:
                   values:
                     - EU
                     - Non-EU
           - name: user_id
             data_tests:
               - relationships:
                   to: ref('stg_jaffle_shop_customers_cleaned')
                   field: customer_id
     ```

   * **b. Singular Tests**: Custom query in another SQL file, for **complex business logics**.
     * _Example_: `tests/assert_positive_total_for_payments.sql`
     
     ```sql
     -- Refunds have a negative amount, so the total amount should always be >= 0.
     -- Therefore return records where this isn't true to make the test fail.
     select
         order_id,
         sum(amount) as total_amount
     from {{ ref('stg_stripe__payments') }}
     group by 1
     having total_amount < 0
     ```

   * **c. dbt Commands for Testing**:
     * `dbt test`: Runs all tests in the project.
     * `dbt test --select table`: Runs only a specific model (table).
     * `dbt test --select test_type:generic`: Runs only generic tests.
     * `dbt test --select test_type:singular`: Runs only singular tests.
     * _Note_: The same testing technique can be applied to the **source**. Not only can we apply a freshness check, but we can also run a generic test for the same file.
       * `dbt test --select source:jaffle_shop` for specific source.
       * `dbt test --select source:*` for all sources.
       * The `dbt test` on source is only for generic or singular tests. It does **not** include the freshness check.

   * **d. Best Practices**:
     * **Testing source**: Ensure data source has no known issues (generic tests, e.g., no null values or non-unique).
     * **Testing model**: Use singular tests to check that the business logic of the transformation is applied.

   * **e. dbt build Command**:
     * performs a `run` followed by a `test` for both source and models (singular + generic only, excluding freshness).
     * essential for **deployment**: allows us to see the results before committing and pushing to production.
     * **Difference vs `dbt run`**: `dbt build` will fail and skip downstream models if a test fails.

   * **f. AI-integrated**:
     * **AI/Copilot**: dbt has integrated Copilot to generate test cases in YML files. It studies your data structure (DDL) and populates the code.
     > It suggests based on DDL, which may not match and need update.
            
     _Note_: All dbt SQL queries **must not** include a `;` or it will throw an error.
