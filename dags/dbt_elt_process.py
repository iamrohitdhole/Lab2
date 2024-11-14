from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.hooks.base import BaseHook
from pendulum import datetime

# Directory where the DBT project is stored
DBT_PROJECT_DIR = "/opt/airflow/dbt1"

# Fetch Snowflake connection details from Airflow's connection settings
conn = BaseHook.get_connection('snowflake_conn')

# Define the DBT DAG to run transformations and snapshots
with DAG(
    "dbt_elt_process",
    start_date=datetime(2024, 10, 14),
    description="A DAG to run dbt transformations",
    schedule_interval='30 2 * * *',  # Runs at 2:30 AM daily
    catchup=False,  # Disable catchup to avoid running past tasks
    default_args={},
) as dag:

    # Environment variables
    env_vars = {
        "DBT_USER": conn.login,  # Snowflake user
        "DBT_PASSWORD": conn.password,  # Snowflake password
        "DBT_ACCOUNT": conn.extra_dejson.get("account"),  # Snowflake account
        "DBT_SCHEMA": conn.schema,  # Target schema in Snowflake
        "DBT_DATABASE": conn.extra_dejson.get("database"),  # Snowflake database
        "DBT_ROLE": conn.extra_dejson.get("role"),  # Snowflake role
        "DBT_WAREHOUSE": conn.extra_dejson.get("warehouse"),  # Snowflake warehouse
        "DBT_TYPE": "snowflake",  # DBT Snowflake connection
    }

    # Task to run dbt transformations
    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=f"/home/airflow/.local/bin/dbt run --profiles-dir {DBT_PROJECT_DIR} --project-dir {DBT_PROJECT_DIR}",
        env=env_vars,  # Pass environment variables
    )

    # Task to run dbt tests
    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"/home/airflow/.local/bin/dbt test --profiles-dir {DBT_PROJECT_DIR} --project-dir {DBT_PROJECT_DIR}",
        env=env_vars,  # Pass environment variables
    )

    # Task to run dbt snapshots
    dbt_snapshot = BashOperator(
        task_id="dbt_snapshot",
        bash_command=f"/home/airflow/.local/bin/dbt snapshot --profiles-dir {DBT_PROJECT_DIR} --project-dir {DBT_PROJECT_DIR}",
        env=env_vars,  # Pass environment variables
    )

    # Define task dependencies: dbt_run -> dbt_test -> dbt_snapshot
    dbt_run >> dbt_test >> dbt_snapshot
