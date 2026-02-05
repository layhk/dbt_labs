<<<<<<< HEAD

select
        id as order_id,
        user_id as customer_id,
        order_date,
        status

from {{ source('jaffle_shop', 'orders') }}
=======
with 

source as (

    select * from {{ source('jaffle_shop', 'orders') }}

),

renamed as (

    select
        id,
        user_id,
        order_date,
        status,
        _etl_loaded_at

    from source

)

select * from renamed
>>>>>>> 057d33527327fbf06e4dfc96162611d72b560b0e
