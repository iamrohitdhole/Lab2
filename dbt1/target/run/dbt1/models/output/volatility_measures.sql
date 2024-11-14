
  
    

        create or replace transient table stock.analytics.volatility_measures
         as
        (-- Step 1: Calculate daily returns for each stock symbol by comparing the current day's closing price with the previous day's closing price
WITH  __dbt__cte__stg_market_data as (
-- staging table for market_data
WITH source_data AS (
    SELECT
        symbol,
        date,
        open,
        high,
        low,
        close,
        volume
    FROM stock.stocks.market_data
)

SELECT
    symbol,
    date,
    CAST(open AS FLOAT) AS open_price,   -- Standardize column names and data types
    CAST(high AS FLOAT) AS high_price,
    CAST(low AS FLOAT) AS low_price,
    CAST(close AS FLOAT) AS close_price,
    volume
FROM source_data
), daily_returns AS (
    SELECT
        date,  -- The date of the stock data
        symbol,  -- The symbol representing the stock
        close_price,  -- Closing price of the stock on a given day
        COALESCE(
            (close_price - LAG(close_price) OVER (PARTITION BY symbol ORDER BY date)) / 
            NULLIF(LAG(close_price) OVER (PARTITION BY symbol ORDER BY date), 0), 0
        ) AS daily_return 
    FROM 
        __dbt__cte__stg_market_data  -- Pull data from the 'market_data' table in the 'stocks' source
)

-- Step 2: Calculate volatility as the 30-day rolling standard deviation of daily returns
, volatility AS (
    SELECT
        date,  -- The date of the stock data
        symbol,  -- The symbol representing the stock
        STDDEV(daily_return) OVER (
            PARTITION BY symbol
            ORDER BY date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS volatility_30d  -- 30-day rolling volatility
    FROM 
        daily_returns  -- Use the CTE holding daily returns
)

-- Step 3: Return the calculated volatility for each stock symbol
SELECT 
    date,  -- The date of the stock data
    symbol,  -- The symbol representing the stock
    volatility_30d  -- 30-day rolling volatility
FROM 
    volatility  -- Use the CTE holding volatility calculations
        );
      
  