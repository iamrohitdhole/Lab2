from airflow import DAG
from airflow.decorators import task
from airflow.models import Variable
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook
from airflow.utils.dates import days_ago
import requests
from datetime import datetime, timedelta

# Default arguments for the DAG
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
}

# Create the DAG to extract, transform, and load (ETL) stock data
etl_dag = DAG(
    'etl_stock_data',
    default_args=default_args,
    description='ETL for extracting and loading Microsoft and Meta stock data',
    schedule_interval='0 2 * * *',  # Run daily at 2 AM
    start_date=datetime(2024, 10, 14), 
    catchup=False,  # Disable catchup to avoid running past tasks
)

# Extract task: Fetch the last 90 days of stock data for a given symbol
@task
def extract_last_90d_price(symbol):
    api_key = Variable.get('alpha_vantage_api_key')
    url_template = Variable.get("url")  # URL template for API request
    url = url_template.format(symbol=symbol, vantage_api_key=api_key)

    try:
        response = requests.get(url)
        data = response.json()

        # Check if API response is valid
        if response.status_code != 200 or "Time Series (Daily)" not in data:
            raise ValueError(f"Error in API response for {symbol}: {data}")

        ninety_days_ago = datetime.today() - timedelta(days=90)
        results = []

        for d in data.get("Time Series (Daily)", {}):
            date_obj = datetime.strptime(d, "%Y-%m-%d")
            if date_obj >= ninety_days_ago:
                price_data = {
                    "symbol": symbol,
                    "date": d,
                    "open": data["Time Series (Daily)"][d]["1. open"],
                    "high": data["Time Series (Daily)"][d]["2. high"],
                    "low": data["Time Series (Daily)"][d]["3. low"],
                    "close": data["Time Series (Daily)"][d]["4. close"],
                    "volume": data["Time Series (Daily)"][d]["5. volume"]
                }
                results.append(price_data)
        return results
    except Exception as e:
        print(f"Error fetching data for {symbol}: {e}")
        return []  # Return empty list in case of error

# Transform task: Combine the stock data of MSFT and META into a single list
@task
def transform(msft_data, meta_data):
    return msft_data + meta_data  # Concatenate the two lists

# Load task: Insert or update stock data in the Snowflake table (ensuring idempotency)
@task
def load(records):
    if not records:
        print("No records to load.")
        return

    # Connect to Snowflake
    hook = SnowflakeHook(snowflake_conn_id='snowflake_conn')
    conn = hook.get_conn()
    cur = conn.cursor()
    target_table = "stock.stocks.market_data"

    try:
        # Begin transaction
        cur.execute("BEGIN;")
        
        # Create the target table if it doesn't exist
        cur.execute(f"""
        CREATE TABLE IF NOT EXISTS {target_table} (
            symbol VARCHAR,
            date DATE,
            open NUMBER,
            high NUMBER,
            low NUMBER,
            close NUMBER,
            volume NUMBER,
            PRIMARY KEY (date, symbol)
        )
        """)

        # Insert or update the records using a MERGE statement for idempotency
        for r in records:
            sql = f"""
            MERGE INTO {target_table} AS target
            USING (SELECT '{r['symbol']}' AS symbol, TO_DATE('{r['date']}', 'YYYY-MM-DD') AS date, 
                        {r['open']} AS open, {r['high']} AS high, {r['low']} AS low, {r['close']} AS close, 
                        {r['volume']} AS volume) AS source
            ON target.symbol = source.symbol AND target.date = source.date
            WHEN MATCHED THEN 
                UPDATE SET open = source.open, high = source.high, low = source.low, close = source.close, volume = source.volume
            WHEN NOT MATCHED THEN 
                INSERT (symbol, date, open, high, low, close, volume) 
                VALUES (source.symbol, source.date, source.open, source.high, source.low, source.close, source.volume);
            """
            cur.execute(sql)
        
        conn.commit()
        print(f"Successfully loaded {len(records)} records into {target_table}.")
    except Exception as e:
        conn.rollback()
        print(f"Error loading data into Snowflake: {e}")
    finally:
        cur.close()
        conn.close()

# Define the task sequence for the ETL pipeline
with etl_dag:
    msft_data = extract_last_90d_price('MSFT')
    meta_data = extract_last_90d_price('META')
    transformed_data = transform(msft_data, meta_data)
    load(transformed_data)
