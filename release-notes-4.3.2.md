!not-ready-for-release!

#### Version Number
${version-number}

#### New Features
- D1057069: Add optional `"SERVICE_"ADMIN_DB_NAME` environment variable.  
The value of this is the name of the admin database which is used for the initial database connection in the database creation script, the default value is `postgres`.  
This means that there no longer needs to be a database with the same name as the user used to connect to postgreSQL.

#### Known Issues
