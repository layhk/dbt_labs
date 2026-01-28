# Google Big Query
----------
1. **No need to setup connection** like AWS or Azure.
   
   Just sign in to the Google account and type `SELECT` statement, then we can view the public dataset or any dataset for which we are granted permission.

   The permission is at the **dataset** level, not the bucket or container level.

# DBT
----
1. **The project yml file** at the root configuration will set the config global.
   
   _this file also set project name_
   
   *Example*: If set `default output = materialized table`, then when we execute any model, the output will be saved as a table in the data platform.
 
   > **Note**: The default setting in dbt is actually `view`.

   > **To override global setting**: Set *Jinja* macro in individual model file.
   > *Example*: `{{ config(materialized='view') }}`

3. **Modular**: Trying to break down to module or smaller piece, like a complex stored proc that has many CTE, save each CTE as a single model.

   **Benefit**:
   * **Reusability**: each model can be referenced in another model using `ref` macro.
     * *Example*: `select * from {{ ref('stg_jaffle_shop_customers') }}` 
   * **Data lineage is formed**: easy for maintenance and tracking.

4. **Deploy model** to the data platform can include the dependencies.

   *Example*: `dbt run --select +customer`
   > This means deploy customer model and its **upstream** dependencies.
   
   **Benefit**:
   * **Resolve dependencies**: We don't need to manually deploy objects one by one and in sequence in other platforms (such as Snowflake).
