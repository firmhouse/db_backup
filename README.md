# db_backup

db_backup is a utility where we can snapshot our databases as sql dumps and store them securely on S3.
It is a single Ruby script that uses a config.yml for configuration.

It is meant to run as a scheduled job via Cron.

## configuration

This is a sample of the configuration file:

``` yml
aws_secret_access_key: secret_access_key
aws_access_key_id: access_key_id
region: eu-west-1
bucket_name: mycompany-sql-backups
mysql:
  hostname: rds-instance.eu-west-1.rds.amazonaws.com
  username: snapshot_user
  password: snapshot_user_password
lifecycle: 60 (number of days to retain backups in the bucket)
databases:
  - application_production
  - application_staging
```