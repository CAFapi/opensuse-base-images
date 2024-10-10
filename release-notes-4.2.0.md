!not-ready-for-release!

#### Version Number
${version-number}

#### New Features
- US969005: Add support for converting file-based secrets to properties.  
  Example: For each environment variable ending in the `_FILE` suffix:  
  `ABC_PASSWORD_FILE=/var/somefile.txt`  
  The contents of `/var/somefile.txt` (e.g., `mypassword`) will be read and then written to `/maven/secret-props.txt` as:  
  `-DCAF.ABC_PASSWORD=mypassword`  
  Note that the prefix `CAF.` is added to the property name.  
  This functionality is enabled by setting the environment variable `CONVERT_FILE_BASED_SECRETS_TO_PROPS=true`.

#### Known Issues
