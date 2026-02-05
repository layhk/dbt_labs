<<<<<<< HEAD
select
        id as customer_id,
        first_name,
        last_name

 from {{ source('jaffle_shop', 'customers') }}
=======
with 

source as (

    select * from {{ source('jaffle_shop', 'customers') }}

),

renamed as (

    select
        id,
        first_name,
        last_name

    from source

)

select * from renamed
>>>>>>> 057d33527327fbf06e4dfc96162611d72b560b0e
