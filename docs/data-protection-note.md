# Data protection note

A design note for this portfolio project: how personal data is handled, and what
would change with real applicant data. It is not legal advice.

## What personal data exists

The raw CRM export contains first name, last name, email and country for each
enquirer. In this project all of it is synthetic (generated with Faker), but the
pipeline is built as if it were real personal data under UK GDPR.

## Where personal data stops

| Layer | Contains | Notes |
|---|---|---|
| Raw (S3 `raw/`, Glue `recruitment_raw`) | Names, emails, country | The only place direct identifiers exist |
| Staging (`stg_enquiries`) | `applicant_key` only | Names and emails dropped at the first transformation |
| Marts and dashboards | No direct identifiers | Aggregated or row-level without names/emails |

Data minimisation: analysts never need names or emails, so the pipeline removes
them at the earliest point.

## Pseudonymisation, not anonymisation

`applicant_key` is a SHA-256 hash of the lower-cased email. Anyone who knows an
email address can recompute the hash and find that person, so this is
pseudonymised data, which is still personal data. With real data I would use a
keyed hash (HMAC) with the secret held in AWS Secrets Manager.

Small groups can also identify people (for example one applicant from one
country on one programme), so published dashboards should suppress small counts.

## Retention

Currently the only lifecycle rule expires Athena query results after 7 days.
With real data I would agree a retention schedule with the Data Protection
Officer, for example deleting raw enquiry details for people who never applied
after a fixed period, implemented as an S3 lifecycle rule on the raw prefix.

## Access control

The project uses a single IAM identity, which is fine for a demo. With real data:

- keep raw personal data in a separate, tightly restricted bucket or prefix
- use Lake Formation column-level permissions so analysts can query staging and
  marts but cannot see name or email columns
- audit access with CloudTrail

## Individual rights

Requests to delete or access a person's data need a way to find every record
about them. The email hash lets me locate a person across tables without
exposing the email in downstream layers. Deletion means removing the raw rows
and rebuilding the models.

## Before using real data

Complete a Data Protection Impact Assessment with the DPO, document the lawful
basis for processing, and confirm retention and access rules.