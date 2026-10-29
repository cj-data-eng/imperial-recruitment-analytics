export RAW_BUCKET=$(terraform -chdir=terraform output -raw raw_bucket_name)
export DBT_PROFILES_DIR=$PWD/dbt
export DBT_PROJECT_DIR=$PWD/dbt