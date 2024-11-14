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
), moving_avg_stddev AS (
    SELECT
        date,
        symbol,
        close_price,
        -- Calculate using a 20-day moving window, allowing NULLs for the first 19 days
        AVG(close_price) OVER (
            PARTITION BY symbol
            ORDER BY date
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS moving_avg_20d,
        STDDEV(close_price) OVER (
            PARTITION BY symbol
            ORDER BY date
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS stddev_20d
    FROM 
        __dbt__cte__stg_market_data
)

SELECT
    date,
    symbol,
    close_price,
    COALESCE(moving_avg_20d, LAST_VALUE(moving_avg_20d IGNORE NULLS) OVER (PARTITION BY symbol ORDER BY date)) AS moving_avg_20d,
    COALESCE(moving_avg_20d + (2 * stddev_20d), LAST_VALUE(moving_avg_20d + (2 * stddev_20d) IGNORE NULLS) OVER (PARTITION BY symbol ORDER BY date)) AS upper_band,
    COALESCE(moving_avg_20d - (2 * stddev_20d), LAST_VALUE(moving_avg_20d - (2 * stddev_20d) IGNORE NULLS) OVER (PARTITION BY symbol ORDER BY date)) AS lower_band
FROM 
    moving_avg_stddev