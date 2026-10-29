-- One row per application, with real dates instead of text.
-- Blank means "never reached this stage", which becomes NULL.

with source as (

    select * from {{ source('raw', 'admissions_applications') }}

)

select
    application_id,
    enquiry_id,
    programme_id,
    try_cast(nullif(application_date, '') as date) as application_date,
    try_cast(nullif(offer_date, '') as date)       as offer_date,
    try_cast(nullif(acceptance_date, '') as date)  as acceptance_date,
    try_cast(nullif(enrolment_date, '') as date)   as enrolment_date
from source