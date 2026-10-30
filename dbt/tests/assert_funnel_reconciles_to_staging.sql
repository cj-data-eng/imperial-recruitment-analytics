-- Fails (returns a row) if the funnel table's totals don't match staging.
-- This catches a join that duplicates or drops people.

with funnel as (

    select
        count(*)                 as enquiries_in_funnel,
        sum(reached_application) as applications_in_funnel
    from {{ ref('fct_enquiry_funnel') }}

),

staging as (

    select
        (select count(*) from {{ ref('stg_enquiries') }})    as enquiries_in_staging,
        (select count(*) from {{ ref('stg_applications') }}) as applications_in_staging

)

select *
from funnel
cross join staging
where enquiries_in_funnel <> enquiries_in_staging
   or applications_in_funnel <> applications_in_staging