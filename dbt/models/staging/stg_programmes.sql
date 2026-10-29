-- Programmes were already clean, so staging just passes them through.
select
    programme_id,
    programme_name,
    programme_type
from {{ source('raw', 'programmes') }}