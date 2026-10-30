-- Funnel counts and conversion rates for each marketing channel.

select
    channel,

    -- How many people reached each stage
    count(*)                    as enquiries,
    sum(reached_application)    as applications,
    sum(reached_offer)          as offers,
    sum(reached_acceptance)     as acceptances,
    sum(reached_enrolment)      as enrolments,

    -- Step-by-step conversion rates (each one divides by the previous stage).
    -- cast(... as double) stops SQL doing whole-number division, which would give 0.
    -- nullif(..., 0) avoids dividing by zero if a stage is empty.
    round(cast(sum(reached_application) as double) / count(*), 4)
        as enquiry_to_application_rate,
    round(cast(sum(reached_offer) as double) / nullif(sum(reached_application), 0), 4)
        as application_to_offer_rate,
    round(cast(sum(reached_acceptance) as double) / nullif(sum(reached_offer), 0), 4)
        as offer_to_acceptance_rate,
    round(cast(sum(reached_enrolment) as double) / nullif(sum(reached_acceptance), 0), 4)
        as acceptance_to_enrolment_rate,

    -- The headline number: of everyone who enquired, how many enrolled?
    round(cast(sum(reached_enrolment) as double) / count(*), 4)
        as enquiry_to_enrolment_rate

from {{ ref('fct_enquiry_funnel') }}
group by channel