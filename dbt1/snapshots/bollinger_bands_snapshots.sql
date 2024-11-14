{% snapshot bollinger_bands_snapshot %}
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
    moving_avg_20d,
    close_price,
    upper_band,
    lower_band
FROM 
    {{ ref('bollinger_bands') }}
{% endsnapshot %}

