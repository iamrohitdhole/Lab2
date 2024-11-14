{% snapshot rsi_calculations_snapshot %}
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
    rsi
FROM 
    {{ ref('rsi_calculations') }}
{% endsnapshot %}

