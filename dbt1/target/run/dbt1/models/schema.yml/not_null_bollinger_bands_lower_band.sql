select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select lower_band
from stock.analytics.bollinger_bands
where lower_band is null



      
    ) dbt_internal_test