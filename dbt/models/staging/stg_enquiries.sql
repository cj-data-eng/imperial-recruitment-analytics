-- One row per enquiry, cleaned.
-- Personal data (name, email) stops here: later models only ever see
-- applicant_key, a pseudonymous ID made from the email.

with source as (

    select * from {{ source('raw', 'crm_enquiries') }}

),

cleaned as (

    select
        enquiry_id,

        -- try_cast gives NULL instead of crashing if a date is malformed.
        try_cast(enquiry_date as date) as enquiry_date,

        programme_id,
        try_cast(intake_year as integer) as intake_year,

        -- "PAID_SEARCH" and "paid_search" are the same channel.
        lower(trim(channel)) as channel,

        -- Standardise the different spellings of the same country.
        case lower(trim(country))
            when 'united kingdom'           then 'United Kingdom'
            when 'uk'                       then 'United Kingdom'
            when 'u.k.'                     then 'United Kingdom'
            when 'united states'            then 'United States'
            when 'us'                       then 'United States'
            when 'usa'                      then 'United States'
            when 'united states of america' then 'United States'
            when ''                         then null   -- blank means missing
            else trim(country)
        end as country,

        -- Hash the email so we can recognise the same person without storing it.
        to_hex(sha256(to_utf8(lower(trim(email))))) as applicant_key

    from source

),

-- The CRM sync that ran twice left exact duplicate rows.
-- Number the copies of each enquiry_id and keep only the first.
deduplicated as (

    select
        *,
        row_number() over (partition by enquiry_id order by enquiry_date) as copy_number
    from cleaned

)

select
    enquiry_id,
    enquiry_date,
    programme_id,
    intake_year,
    channel,
    country,
    applicant_key
from deduplicated
where copy_number = 1