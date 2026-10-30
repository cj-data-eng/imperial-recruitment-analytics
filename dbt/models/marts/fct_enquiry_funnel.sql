-- One row per enquiry (the "grain"), showing how far that person got.
-- Every dashboard and analysis reads from this table.

with enquiries as (

    select * from {{ ref('stg_enquiries') }}

),

applications as (

    select * from {{ ref('stg_applications') }}

),

programmes as (

    select * from {{ ref('stg_programmes') }}

)

select
    enquiries.enquiry_id,
    enquiries.applicant_key,
    enquiries.intake_year,
    enquiries.channel,
    enquiries.country,
    enquiries.programme_id,
    programmes.programme_name,
    programmes.programme_type,

    applications.application_id,
    enquiries.enquiry_date,
    applications.application_date,
    applications.offer_date,
    applications.acceptance_date,
    applications.enrolment_date,

    -- Stage flags: 1 if the person reached that stage, otherwise 0.
    -- Adding up a flag counts people, which keeps the maths simple later.
    case when applications.application_id is not null then 1 else 0 end as reached_application,
    case when applications.offer_date is not null then 1 else 0 end as reached_offer,
    case when applications.acceptance_date is not null then 1 else 0 end as reached_acceptance,
    case when applications.enrolment_date is not null then 1 else 0 end as reached_enrolment,

    -- Data quality flag: an application can't come before the enquiry.
    -- We keep these rows (the application did happen) but flag them.
    coalesce(applications.application_date < enquiries.enquiry_date, false)
        as application_before_enquiry,

    -- Speed metric: only calculated when the dates are in a sensible order,
    -- so impossible dates don't produce negative days.
    case
        when applications.application_date >= enquiries.enquiry_date
        then date_diff('day', enquiries.enquiry_date, applications.application_date)
    end as days_enquiry_to_application

from enquiries
left join applications on enquiries.enquiry_id = applications.enquiry_id
left join programmes on enquiries.programme_id = programmes.programme_id