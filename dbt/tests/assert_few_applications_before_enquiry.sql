-- A handful of impossible dates is tolerated (a warning), but more than 100
-- means something has gone wrong upstream (an error).
{{ config(severity='error', warn_if='>0', error_if='>100') }}

select
    application_id,
    enquiry_id,
    enquiry_date,
    application_date
from {{ ref('fct_enquiry_funnel') }}
where application_before_enquiry