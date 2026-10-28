"""Basic sanity checks: the fake data should obey the rules of the funnel."""

import numpy as np
from faker import Faker

from recruitment_analytics.generate_data import (
    generate_applications,
    generate_enquiries,
)


def build_data():
    rng = np.random.default_rng(1)
    enquiries = generate_enquiries(rng, Faker("en_GB"))
    applications = generate_applications(rng, enquiries)
    return enquiries, applications


def test_every_application_belongs_to_an_enquiry():
    enquiries, applications = build_data()
    assert applications["enquiry_id"].isin(enquiries["enquiry_id"]).all()


def test_funnel_dates_never_go_backwards():
    _, applications = build_data()
    offers = applications.dropna(subset=["offer_date"])
    assert (offers["offer_date"] >= offers["application_date"]).all()

    accepted = applications.dropna(subset=["acceptance_date"])
    assert (accepted["acceptance_date"] >= accepted["offer_date"]).all()