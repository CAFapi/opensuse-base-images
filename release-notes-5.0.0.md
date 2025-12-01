#### Version Number
${version-number}

#### Breaking Changes
- D1057069: The admin database used by the database creation script to connect for existence check and creation now defaults to 'postgres' if not supplied via the `"SERVICE_"ADMIN_DB_NAME` environment variable.  
Previously it defaulted to a database with the same name as the user name used to connect to the server.

#### New Features
- D1057069: Add optional `"SERVICE_"ADMIN_DB_NAME` environment variable.  
The value of this is the name of the admin database which is used for the initial database connection in the database creation script, the default value is `postgres`.  
This means that there no longer needs to be a database with the same name as the user used to connect to postgreSQL.

#### Known Issues
- None
