{% snapshot stock_data_snapshot %}
 {{ 
    config(
        target_schema='snapshots',
        unique_key='date',
        strategy='timestamp',
        updated_at='date'
    ) 
 }}

SELECT
    symbol,
    date,
    open_price,
    high_price,
    low_price,
    close_price,
    volume
FROM 
    {{ ref('stg_market_data') }}
{% endsnapshot %}

