{% snapshot moving_averages_snapshot %}
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
    close_price,
    moving_avg_7d,
    moving_avg_30d
FROM 
    {{ ref('moving_averages') }}
{% endsnapshot %}

