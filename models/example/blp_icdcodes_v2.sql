
/*
    Welcome to your first dbt model!
    Did you know that you can also configure models directly within SQL files?
    This will override configurations stated in dbt_project.yml

    Try changing "table" to "view" below
*/

{{ config(materialized='table') }} -- meaning this will get created as a table
select * from  blp_icdcodes_v2 limit 50
/*
    Uncomment the line below to remove records with null `id` values
*/

-- where id is not null
