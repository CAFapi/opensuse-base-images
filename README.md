# openSUSE Base Images

This project builds a number of base images which are based on the latest version of [openSUSE Leap](https://get.opensuse.org/leap) and can be used as base images for various projects.

The images which are built in this project are:
- opensuse-base
  - opensuse-jre8
  - opensuse-jdk8
  - opensuse-jre11
  - opensuse-jdk11
  - opensuse-jre17
  - opensuse-jdk17
  - opensuse-jre21
  - opensuse-jdk21
  - opensuse-nodejs20
  - opensuse-python3
  - opensuse-dotnet6-aspnet
  - opensuse-dotnet6-runtime
  - opensuse-dotnet6-sdk

### Tini
[Tini](https://github.com/krallin/tini) is pre-installed in the containers.  If the image entrypoint is not overwritten then it will be automatically used.

### PostgreSQL Client
[PostgreSQL Client](https://www.postgresql.org/docs/current/static/app-psql.html) is pre-installed in the containers. psql is a terminal-based front-end to PostgreSQL. It enables you to type in queries interactively, issue them to PostgreSQL, and see the query results. Alternatively, input can be from a file or from command line arguments. In addition, psql provides a number of meta-commands and various shell-like features to facilitate writing scripts and automating a wide variety of tasks.

### DejaVu Fonts
[DejaVu Fonts](https://dejavu-fonts.github.io/) is pre-installed in the containers. The DejaVu fonts are a font family based on the Bitstream Vera Fonts. Its purpose is to provide a wider range of characters while maintaining the original look and feel through the process of collaborative development.

### su-exec
[su-exec](https://github.com/ncopa/su-exec) is pre-installed in the containers. `su-exec` allows derived images to run commands as a specified user, rather than as the default user.  

Note: `gosu` has been replaced with `su-exec`, however `gosu` command is still supported as a symlink to `su-exec`.

To use `su-exec`, set the `RUNAS_USER` environment variable in the derived container's Dockerfile. Subsequent commands will then be run as the specified user:

```
ENV RUNAS_USER=my-user
CMD ["whoami"] # Outputs my-user
```

Note: the user specified by the `RUNAS_USER` is expected to already exist, and the `CMD` will fail if this is not the case.

### Startup Scripts
Any executable scripts added to the `/startup/startup.d/` directory will be automatically run each time the containers are started (assuming the image entrypoint is not overwritten).

### Pre-Installed Startup Scripts

#### Certificate Installation
The images come pre-installed with a startup script which provides a mechanism to extend the CA certificates which should be trusted.

#### Export File-Based Secrets Script
The images come pre-installed with a startup script which provides support for file-based secrets.

It works by looking for environment variables ending with the _FILE prefix and setting the environment variable base name to the contents of the file.

For example, given this environment variable ending in the _FILE suffix:
```
ABC_PASSWORD_FILE=/var/somefile.txt
```
the script will read the contents of /var/somefile.txt (for example 'mypassword'), and export an environment variable named ABC_PASSWORD:
```
ABC_PASSWORD=mypassword
```
This feature is disabled by default. To enable it, ensure a `USE_FILE_BASED_SECRETS` environment variable is present, with a value of `true`, for example, `USE_FILE_BASED_SECRETS=true`.

### Pre-Installed Utility Scripts

#### Database Creation Script
The images come pre-installed with a utility script which can be used to check if a PostgreSQL database exists and to create it if it does not.

When the script is called it must be passed an environment variable prefix for the service:

    /scripts/check-create-pgdb.sh SERVICE_

The script then reads the database details from a set of environment variables with the specified prefix:

| **Environment Variable**    |                                          **Description**                                               |
|-----------------------------|--------------------------------------------------------------------------------------------------------|
| `SERVICE_`DATABASE_HOST     | The host name of the machine on which the PostgreSQL server is running.                                |
| `SERVICE_`DATABASE_PORT     | The TCP port on which the PostgreSQL server is listening for connections.                              |
| `SERVICE_`DATABASE_USERNAME | The username to use when establishing the connection to the PostgreSQL server.                         |
| `SERVICE_`DATABASE_PASSWORD | The password to use when establishing the connection to the PostgreSQL server.                         |
| `SERVICE_`DATABASE_APPNAME  | The application name that PostgreSQL should associate with the connection for logging and monitoring.  |
| `SERVICE_`DATABASE_NAME     | The name of the PostgreSQL database to be created.                                                     |
