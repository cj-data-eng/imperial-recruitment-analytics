"""
Settings for the synthetic data generator.

Everything you might want to tweak lives here, so the generator code
itself can stay focused on logic.
"""

from pathlib import Path

# Where the generated CSV files are written.
RAW_DATA_DIR = Path("data/raw")

# Using the same seed means the "random" data is identical on every run,
# so your charts and numbers don't change under your feet.
RANDOM_SEED = 42

# One cycle = the students who start in September of that year.
INTAKE_YEARS = [2024, 2025]

# Fictional programmes.
#   enquiries  = how many enquiries one intake cycle receives
#   offer_rate = share of applicants who get an offer (selective = lower)
PROGRAMMES = [
    {"programme_id": "MBA-FT", "programme_name": "Full-time MBA", "programme_type": "MBA", "enquiries": 1500, "offer_rate": 0.35},
    {"programme_id": "MBA-EX", "programme_name": "Executive MBA", "programme_type": "MBA", "enquiries": 800, "offer_rate": 0.50},
    {"programme_id": "MSC-BA", "programme_name": "MSc Business Analytics", "programme_type": "MSc", "enquiries": 4000, "offer_rate": 0.40},
    {"programme_id": "MSC-FIN", "programme_name": "MSc Finance", "programme_type": "MSc", "enquiries": 4500, "offer_rate": 0.38},
    {"programme_id": "MSC-MGT", "programme_name": "MSc Management", "programme_type": "MSc", "enquiries": 3000, "offer_rate": 0.45},
]

# Where enquiries come from.
#   share   = proportion of all enquiries from this channel (must add up to 1)
#   quality = multiplier on the chance of applying and accepting.
#             Above 1 means these people are more committed than average.
CHANNELS = {
    "paid_search": {"share": 0.25, "quality": 0.9},
    "paid_social": {"share": 0.15, "quality": 0.6},
    "organic_search": {"share": 0.20, "quality": 1.0},
    "email": {"share": 0.10, "quality": 1.2},
    "events": {"share": 0.10, "quality": 1.5},
    "agent_referral": {"share": 0.12, "quality": 1.1},
    "alumni_referral": {"share": 0.08, "quality": 1.8},
}

# Where applicants live, with the share of enquiries from each (adds up to 1).
COUNTRIES = {
    "United Kingdom": 0.20,
    "India": 0.20,
    "China": 0.18,
    "United States": 0.10,
    "Nigeria": 0.06,
    "Germany": 0.06,
    "Brazil": 0.05,
    "United Arab Emirates": 0.05,
    "France": 0.05,
    "Singapore": 0.05,
}

# Relative enquiry volume by calendar month (1 = January).
# Busiest in autumn, when people research next year's courses.
MONTH_WEIGHTS = {
    1: 1.2, 2: 1.0, 3: 0.9, 4: 0.8, 5: 0.7, 6: 0.6,
    7: 0.5, 8: 0.6, 9: 0.9, 10: 1.4, 11: 1.5, 12: 1.0,
}

# Base chance of moving from one funnel stage to the next.
APPLY_RATE = 0.30   # enquiry -> application
ACCEPT_RATE = 0.55  # offer -> offer accepted
ENROL_RATE = 0.85   # accepted -> actually turns up in September

# How long each step takes, as (fewest days, most days).
APPLY_DELAY_DAYS = (7, 90)
OFFER_DELAY_DAYS = (14, 45)
ACCEPT_DELAY_DAYS = (5, 30)

# Real CRM exports are messy. These control how messy ours is.
DUPLICATE_ROW_RATE = 0.02     # share of enquiry rows that appear twice
MISSING_COUNTRY_RATE = 0.03   # share of enquiries with no country
COUNTRY_VARIANT_RATE = 0.10   # share of UK/US rows spelled non-standardly
SHOUTY_CHANNEL_RATE = 0.03    # share of channels typed in UPPERCASE
IMPOSSIBLE_DATE_RATE = 0.01   # share of applications dated before the enquiry