-- Step 1: Calculate 7-day and 30-day moving averages for each stock symbol
WITH moving_averages AS (
    SELECT
        date,  -- The date of the stock data
        symbol,  -- The symbol representing the stock
        close_price,  -- Closing price of the stock on a given day
        -- Calculate 7-day moving average using a window function
        AVG(close_price) OVER (
            PARTITION BY symbol  -- Group by stock symbol
            ORDER BY date  -- Order by date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW  -- Calculate for the last 7 days (including current day)
        ) AS moving_avg_7d,
        -- Calculate 30-day moving average using a window function
        AVG(close_price) OVER (
            PARTITION BY symbol
            ORDER BY date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW  -- Calculate for the last 30 days (including current day)
        ) AS moving_avg_30d
    FROM 
        {{ ref('stg_market_data') }}  -- Pull data from the 'market_data' table in the 'stocks' source
)

-- Step 2: Select the calculated moving averages for each stock symbol
SELECT * FROM moving_averages  -- Retrieve all columns from the CTE