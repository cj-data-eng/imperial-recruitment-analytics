"""
Generate fake (synthetic) student recruitment data.

Why fake data? Real applicant data is personal data. Faking it lets us
build and share the whole project safely, and we control the "story"
hidden in the data (e.g. alumni referrals convert best) so we can check
our analysis later finds it.

Run it with:
    uv run python -m recruitment_analytics.generate_data
"""

from datetime import date, timedelta

import numpy as np
import pandas as pd
from faker import Faker

from recruitment_analytics import config

# Some countries get written several ways in real systems.
COUNTRY_SPELLINGS = {
    "United Kingdom": ["UK", "U.K.", "united kingdom"],
    "United States": ["USA", "US", "United States of America"],
}


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

def term_start_date(intake_year):
    """Teaching starts on 15 September of the intake year."""
    return date(intake_year, 9, 15)


def application_deadline(intake_year):
    """Applications close on 31 August of the intake year."""
    return date(intake_year, 8, 31)


def chance(rng, probability):
    """Return True with the given probability (0.3 means about 30% of the time)."""
    return rng.random() < probability


def random_delay(rng, days_range):
    """Pick a random number of days between the two values in days_range."""
    fewest, most = days_range
    return timedelta(days=int(rng.integers(fewest, most + 1)))


def pick_enquiry_dates(rng, intake_year, how_many):
    """
    Pick random enquiry dates for one intake cycle.

    Enquiries arrive between 1 Oct (the year before) and 31 Aug, and some
    months are busier than others (see MONTH_WEIGHTS in config.py).
    """
    first_day = date(intake_year - 1, 10, 1)
    last_day = application_deadline(intake_year)
    all_days = [first_day + timedelta(days=i) for i in range((last_day - first_day).days + 1)]

    # Give every day a weight based on its month, then turn weights into
    # probabilities that add up to 1.
    weights = np.array([config.MONTH_WEIGHTS[day.month] for day in all_days])
    probabilities = weights / weights.sum()

    chosen = rng.choice(len(all_days), size=how_many, p=probabilities)
    return [all_days[position] for position in chosen]


# ---------------------------------------------------------------------------
# Step 1: enquiries (what a CRM would export)
# ---------------------------------------------------------------------------

def generate_enquiries(rng, fake):
    """One row per person who got in touch. Includes personal data (PII)."""
    channel_names = list(config.CHANNELS)
    channel_shares = [config.CHANNELS[name]["share"] for name in channel_names]
    country_names = list(config.COUNTRIES)
    country_shares = list(config.COUNTRIES.values())

    rows = []
    enquiry_number = 0

    for intake_year in config.INTAKE_YEARS:
        for programme in config.PROGRAMMES:
            dates = pick_enquiry_dates(rng, intake_year, programme["enquiries"])

            for enquiry_date in dates:
                enquiry_number += 1
                first_name = fake.first_name()
                last_name = fake.last_name()
                email = f"{first_name}.{last_name}{enquiry_number}@example.com"

                rows.append({
                    "enquiry_id": f"ENQ-{enquiry_number:06d}",
                    "enquiry_date": enquiry_date,
                    "programme_id": programme["programme_id"],
                    "intake_year": intake_year,
                    "channel": str(rng.choice(channel_names, p=channel_shares)),
                    "country": str(rng.choice(country_names, p=country_shares)),
                    "first_name": first_name,
                    "last_name": last_name,
                    "email": email.lower().replace(" ", "").replace("'", ""),
                })

    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# Step 2: applications (what the admissions system would export)
# ---------------------------------------------------------------------------

def generate_applications(rng, enquiries):
    """
    Walk every enquiry down the funnel and record how far they got.

    A date of None means "never reached this stage". The funnel is:
        enquiry -> application -> offer -> acceptance -> enrolment
    """
    offer_rate_by_programme = {p["programme_id"]: p["offer_rate"] for p in config.PROGRAMMES}

    rows = []
    application_number = 0

    for enquiry in enquiries.itertuples():
        quality = config.CHANNELS[enquiry.channel]["quality"]
        term_start = term_start_date(enquiry.intake_year)

        # Stage 1: does this person apply at all?
        apply_chance = min(config.APPLY_RATE * quality, 0.95)
        if not chance(rng, apply_chance):
            continue

        application_date = enquiry.enquiry_date + random_delay(rng, config.APPLY_DELAY_DAYS)
        if application_date > application_deadline(enquiry.intake_year):
            continue  # too late, applications have closed

        offer_date = None
        acceptance_date = None
        enrolment_date = None

        # Stage 2: does the school make an offer?
        if chance(rng, offer_rate_by_programme[enquiry.programme_id]):
            offer_date = application_date + random_delay(rng, config.OFFER_DELAY_DAYS)

            # Stage 3: does the applicant accept it?
            accept_chance = min(config.ACCEPT_RATE * quality, 0.95)
            if chance(rng, accept_chance):
                acceptance_date = offer_date + random_delay(rng, config.ACCEPT_DELAY_DAYS)

                # Stage 4: do they turn up? (Accepting after term starts is too late.)
                if acceptance_date < term_start and chance(rng, config.ENROL_RATE):
                    enrolment_date = term_start

        application_number += 1
        rows.append({
            "application_id": f"APP-{application_number:06d}",
            "enquiry_id": enquiry.enquiry_id,
            "programme_id": enquiry.programme_id,
            "application_date": application_date,
            "offer_date": offer_date,
            "acceptance_date": acceptance_date,
            "enrolment_date": enrolment_date,
        })

    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# Step 3: make the data messy, like real life
# ---------------------------------------------------------------------------

def make_data_messy(rng, enquiries, applications):
    """
    Add the kinds of problems real exports have. We will detect and fix
    every one of these later with dbt tests and cleaning models, which is
    the "data quality" part of the project.
    """
    enquiries = enquiries.copy()
    applications = applications.copy()
    number_of_enquiries = len(enquiries)

    # Problem 1: the same country spelled different ways.
    for clean_name, spellings in COUNTRY_SPELLINGS.items():
        is_this_country = enquiries["country"] == clean_name
        gets_messed_up = rng.random(number_of_enquiries) < config.COUNTRY_VARIANT_RATE
        rows_to_change = is_this_country & gets_messed_up
        enquiries.loc[rows_to_change, "country"] = rng.choice(spellings, size=rows_to_change.sum())

    # Problem 2: some people never gave a country.
    missing = rng.random(number_of_enquiries) < config.MISSING_COUNTRY_RATE
    enquiries.loc[missing, "country"] = None

    # Problem 3: channel names typed in capitals.
    shouting = rng.random(number_of_enquiries) < config.SHOUTY_CHANNEL_RATE
    enquiries.loc[shouting, "channel"] = enquiries.loc[shouting, "channel"].str.upper()

    # Problem 4: duplicate rows (e.g. a CRM sync that ran twice).
    duplicates = enquiries.sample(frac=config.DUPLICATE_ROW_RATE, random_state=config.RANDOM_SEED)
    enquiries = pd.concat([enquiries, duplicates], ignore_index=True)

    # Problem 5: applications dated BEFORE the enquiry, which is impossible.
    enquiry_date_by_id = dict(zip(enquiries["enquiry_id"], enquiries["enquiry_date"]))
    is_impossible = rng.random(len(applications)) < config.IMPOSSIBLE_DATE_RATE
    for row_position in applications.index[is_impossible]:
        enquiry_date = enquiry_date_by_id[applications.at[row_position, "enquiry_id"]]
        applications.at[row_position, "application_date"] = enquiry_date - timedelta(days=5)

    return enquiries, applications


# ---------------------------------------------------------------------------
# Put it all together
# ---------------------------------------------------------------------------

def main():
    config.RAW_DATA_DIR.mkdir(parents=True, exist_ok=True)

    rng = np.random.default_rng(config.RANDOM_SEED)
    fake = Faker("en_GB")
    Faker.seed(config.RANDOM_SEED)

    programmes = pd.DataFrame(config.PROGRAMMES)[["programme_id", "programme_name", "programme_type"]]
    enquiries = generate_enquiries(rng, fake)
    applications = generate_applications(rng, enquiries)
    enquiries, applications = make_data_messy(rng, enquiries, applications)

    programmes.to_csv(config.RAW_DATA_DIR / "programmes.csv", index=False)
    enquiries.to_csv(config.RAW_DATA_DIR / "crm_enquiries.csv", index=False)
    applications.to_csv(config.RAW_DATA_DIR / "admissions_applications.csv", index=False)

    print(f"programmes:   {len(programmes):>7,}")
    print(f"enquiries:    {len(enquiries):>7,}  (includes duplicates)")
    print(f"applications: {len(applications):>7,}")
    print(f"offers:       {applications['offer_date'].notna().sum():>7,}")
    print(f"accepted:     {applications['acceptance_date'].notna().sum():>7,}")
    print(f"enrolled:     {applications['enrolment_date'].notna().sum():>7,}")
    print(f"Files written to {config.RAW_DATA_DIR}/")


if __name__ == "__main__":
    main()