{% snapshot volatility_measures_snapshot %}
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
    volatility_30d
FROM 
    {{ ref('volatility_measures') }}
{% endsnapshot %}

