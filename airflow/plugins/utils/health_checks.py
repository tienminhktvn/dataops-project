from airflow.providers.microsoft.mssql.hooks.mssql import MsSqlHook


def check_pipeline_health(**context):
    print("🏥 Running REAL pipeline health checks...")

    CONN_ID = "sqlserver_default"
    hook = MsSqlHook(mssql_conn_id=CONN_ID)

    errors = []

    # Helper function to check row counts
    def check_has_data(layer_name, schema, table):
        sql = f"SELECT COUNT(*) FROM {schema}.{table}"
        try:
            count = hook.get_first(sql)[0]
            if count > 0:
                print(f"   ✅ {layer_name}: {schema}.{table} has {count} rows.")
                return True
            else:
                errors.append(f"{layer_name} Error: {schema}.{table} is empty!")
                return False
        except Exception as e:
            errors.append(f"Connection Error checking {table}: {str(e)}")
            return False

    # --- 1. Bronze Check (Raw Data Exists) ---
    check_has_data("Bronze", "bronze", "brnz_products")

    # --- 2. Silver Check (Processing Happened) ---
    check_has_data("Silver", "silver", "slvr_products")

    # --- 3. Gold Check (Marts Updated) ---
    check_has_data("Gold", "gold", "gld_product_performance")

    # --- 4. Orphaned Records Check ---
    # Logic: Are there any Gold products that don't exist in Silver? (Should be 0)
    print("   🔍 Checking for orphaned records...")
    orphan_sql = """
        SELECT COUNT(*)
        FROM gold.gld_product_performance g
        LEFT JOIN silver.slvr_products s ON g.product_id = s.product_id
        WHERE s.product_id IS NULL
    """
    try:
        orphan_count = hook.get_first(orphan_sql)[0]
        if orphan_count == 0:
            print("   ✅ Integrity Check: 0 orphaned records found.")
        else:
            errors.append(
                f"Integrity Error: Found {orphan_count} orphaned records in Gold layer!"
            )
    except Exception as e:
        errors.append(f"Query Error during orphan check: {str(e)}")

    # --- Final Result ---
    if not errors:
        print("✅ ALL CHECKS PASSED")
        return True
    else:
        print("❌ HEALTH CHECKS FAILED")
        for err in errors:
            print(f"   - {err}")
        raise Exception(f"Pipeline Health Check Failed: {len(errors)} errors found.")
