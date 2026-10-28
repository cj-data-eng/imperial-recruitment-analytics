# A catalogue "folder" for our raw tables.
resource "aws_glue_catalog_database" "raw" {
  name = "recruitment_raw"
}

# Each raw table is just a name plus its column names.
# Every column is a string on purpose: raw data is untrusted, so we store it
# exactly as it arrived and do the type conversion (and cleaning) in dbt.
locals {
  raw_tables = {
    programmes = [
      "programme_id", "programme_name", "programme_type",
    ]
    crm_enquiries = [
      "enquiry_id", "enquiry_date", "programme_id", "intake_year",
      "channel", "country", "first_name", "last_name", "email",
    ]
    admissions_applications = [
      "application_id", "enquiry_id", "programme_id", "application_date",
      "offer_date", "acceptance_date", "enrolment_date",
    ]
  }
}

# One Glue table per entry above (for_each loops over the map).
resource "aws_glue_catalog_table" "raw" {
  for_each      = local.raw_tables
  name          = each.key
  database_name = aws_glue_catalog_database.raw.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL                 = "TRUE"
    classification           = "csv"
    "skip.header.line.count" = "1" # first row of each file is column names
  }

  storage_descriptor {
    # Each table reads every file in its own folder in S3.
    location      = "s3://${aws_s3_bucket.raw.id}/raw/${each.key}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"

      parameters = {
        separatorChar = ","
        quoteChar     = "\""
        escapeChar    = "\\"
      }
    }

    # Build one column entry per name in the list.
    dynamic "columns" {
      for_each = each.value

      content {
        name = columns.value
        type = "string"
      }
    }
  }
}

# A workgroup is Athena's "settings profile": where results go and a cost guard.
resource "aws_athena_workgroup" "recruitment" {
  name          = "recruitment"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration = true

    # Cost guard: cancel any query that would scan more than 1 GB.
    bytes_scanned_cutoff_per_query = 1073741824

    result_configuration {
      output_location = "s3://${aws_s3_bucket.raw.id}/athena-results/"
    }
  }
}