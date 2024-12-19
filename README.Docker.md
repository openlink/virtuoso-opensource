# OpenLink Virtuoso Open Source Edition 7.2 Docker Image

*Copyright (C) 2019-2026 OpenLink Software <vos.admin@openlinksw.com>*

_Only Docker Containers in [`orgs/openlink/repository`](https://hub.docker.com/orgs/openlink/repositories/) are direct from [OpenLink Software](https://www.openlinksw.com/). We recommend using these container images. If an edited clone provides a necessary feature, please inform us so OpenLink can continue improving Virtuoso._

## Feedback & Support

Please report any issues to the [OpenLink Community Forum](https://community.openlinksw.com/) or as a [Virtuoso GitHub issue](https://github.com/openlink/virtuoso-opensource/issues/).

If covered by a support contract, you can also create a [Support Case through the OpenLink Support Site](https://shop.openlinksw.com/support_system/customers/).

## QuickStart Guide

Docker should be installed on your OS before proceeding.

### Downloading the Image

To pull the latest Virtuoso 7.2 docker image to your local system, use this command:

```txt
$ docker pull openlink/virtuoso-opensource-7
```

To check the version of the Virtuoso binary, use this command:

```txt
$ docker run openlink/virtuoso-opensource-7 version

[openlink/virtuoso-opensource-7:7.2.16-r23.1-g01a90e1-ubuntu]

This Docker image uses this version of Virtuoso:

Virtuoso Open Source Edition (Column Store) (multi threaded)
Version 7.2.16.3242-pthreads as of Oct 14 2025 (a0312daa68)
Compiled for Linux (x86_64-ubuntu_noble-linux-gnu)
Copyright (C) 1998-2025 OpenLink Software

```


### Creating a Sample Virtuoso Instance

Here is a quick example of how to create a new virtuoso instance on your system:

```txt
$ mkdir my_virtdb
$ cd my_virtdb
$ docker run \
    --name my_virtdb \
    --interactive \
    --tty \
    --env DBA_PASSWORD=mysecret \
    --publish 1111:1111 \
    --publish 8890:8890 \
    --volume `pwd`:/database \
    openlink/virtuoso-opensource-7:latest
```

This creates a new Virtuoso database in the `my_virtdb` subdirectory and starts a Virtuoso instance with the HTTP server listening on port `8890` and the ODBC / JDBC / ADO.Net / OLE-DBi / SQL data server listening on port `1111`.

The `-i` or `--interactive` flag runs the container in the foreground, surfacing diagnostic output to the terminal.

You should now be able to contact the Virtuoso HTTP server using this URL:

```
http://localhost:8890/
```

Shutdown Virtuoso by pressing the *CTRL* and *C* buttons in that terminal session.


#### Passwords

When a new database is created, the docker image uses the *Environment* settings `DBA_PASSWORD` and `DAV_PASSWORD` to set passwords for the **`dba`** and **`dav`** user accounts.

If the `DBA_PASSWORD` *Environment* variable is not set, a random password is assigned to the **`dba`** user account and stored on the internal docker filesystem as `/settings/dba_password`.

If the `DAV_PASSWORD` *Environment* variable is not set, it is set to the `DBA_PASSWORD` and stored as `/settings/dav_password`.

These files are only readable by the account starting the image. Commands like this reveal the randomised passwords:

```sh
$ docker exec -i -t my_virtdb cat /settings/dba_password
```

This password is *required* to log into the Virtuoso Conductor or connect via `isql` as the `dba` account.

**NOTE**: Change the password immediately and remove this file from the filesystem.


#### Persistent Storage

To retain changes to the Virtuoso database, store the database documents on the host file system.

The docker image exposes a `/database` volume that can be easily mapped to a local directory on the filesystem. If this directory is empty, the docker image places an initial `virtuoso.ini` into the mapped directory and proceeds to create a new database.

### Stopping the Image

When the docker image runs in foreground mode (with `-i` or `--interactive`), shutdown Virtuoso by pressing the *CTRL* and *C* buttons in that terminal session. Alternatively, use this command in a different terminal:

```sh
$ docker stop my_virtdb
```


### Restarting the Image

Once the docker image is registered with `docker run` or `docker create` on your local system, start it in the background using:

```sh
$ docker start my_virtdb
```

If you prefer to run the instance in foreground mode, use:

```sh
$ docker start -i -a my_virtdb
```


### Checking the Startup Log

If the docker image starts in background (without `-i` or `--interactive`) mode, view the recent output of the `virtuoso` process by running:

```sh
$ docker logs my_virtdb
```


### Using isql to Connect

To connect to your running Virtuoso instance, use this command:

```sh
$ docker exec -i my_virtdb isql 1111
```

You are prompted for the `dba` account password.

**NOTE:** If you provide an incorrect password multiple times, Virtuoso locks the `dba` account for a couple of minutes.


### Using an Existing Database

If the mapped directory contains a `virtuoso.ini` and accompanying database documents, the new docker image attempts to use these.

**NOTE:** Directory paths referenced in the `virtuoso.ini` should be relative to the internal directory structure of the docker image in order to work.

## OpenLink Virtuoso Open Source Edition 7.2 Docker Reference

### Downloading the Image

To pull the latest Virtuoso 7.2 docker image to your local system, use this command:

```sh
$ docker pull openlink/virtuoso-opendsource-7
```

To check the version of the Virtuoso binary, use this command:

```sh
$ docker run openlink/virtuoso-opensource-7 version

[openlink/virtuoso-opensource-7:7.2.16-r23.1-g01a90e1-ubuntu]

This Docker image uses this version of Virtuoso:

Virtuoso Open Source Edition (Column Store) (multi threaded)
Version 7.2.16.3242-pthreads as of Oct 14 2025 (a0312daa68)
Compiled for Linux (x86_64-ubuntu_noble-linux-gnu)
Copyright (C) 1998-2025 OpenLink Software

```

### Configurable Resources

The OpenLink Virtuoso Open Source Edition docker image exposes a number of resources that can be configured or mapped to the local machine.

### Ports

#### Port `1111`

This port can be mapped to provide external access to the docker image to connect using any of the Virtuoso client providers such as **[ODBC](http://data.openlinksw.com/oplweb/glossary-term/ODBC#this), [JDBC](http://data.openlinksw.com/oplweb/glossary-term/JDBC#this), [ADO.Net](http://data.openlinksw.com/oplweb/glossary-term/ADONet#this), [OLE-DB](http://data.openlinksw.com/oplweb/glossary-term/OLEDB#this), iSQL** from either the host system or from another docker image.

To run multiple docker images on the same host system, use the `-p` or `--publish` command-line option to map a free port on the local system (e.g. `1112`) to the default isql port `1111` on the docker system.

```sh
$ docker create .....
  ...
  --publish 1112:1111 \
  ...
```

#### Port `8890`

This port can be mapped to provide external access to the Virtuoso **HTTP** server.

To run multiple docker images on the same host system, use the `-p` or `--publish` command-line option to map a free port on the local system. For example, to make this image the default web-server, map port `80` on the host to the default HTTP port `8890` on the container.

```sh
$ docker create .....
  ...
  --publish 80:8890 \
  ...
```

As soon as the docker image starts, connect to Virtuoso using this URL in your browser:

```
http://localhost/
```

### Volume(s)

#### `/database`

This volume contains the `virtuoso.ini`, `virtuoso.lic` and all the files used by the Virtuoso database.

When creating or running any docker container, two parameters play an important role in data persistence:

* **Named** vs **Unnamed** containers (using the `-n` or `--name` argument)

* **Mapped** or **Unmapped** volumes (using the `-v ` or `--volume` argument)

If you create a docker image without specifying either a name for the resulting (unnamed) container and a volume mapping, this docker image is destroyed the moment the container is stopped and while the directory is not immediately removed from the host filesystem, it may not be easy to locate and recover any data inside.

As long as you at least use the `--name` argument, the docker container can be stopped and restarted without any loss of data.

Creating a docker image without mapping a volume to a local directory forces the docker system to create a directory within its own filesystem (e.g. `/var/lib/docker/containers` on Linux). This can cause space issues on the root filesystem and prevents migrating existing data to newer image versions. An unnamed volume also prevents upgrading the docker image while retaining the existing database.

While unnamed containers with mapped volumes are sometimes preferred, we recommend using both `--name` and `--volume` parameters on all Virtuoso containers created.

### `/initdb.d`

This directory can contain a mix of shell (.sh) and Virtuoso PL (.sql) scripts that can perform functions such as:

  * Installing additional Ubuntu packages
  * Loading data from remote locations such as Amazon S3 buckets, Google Drive or other locations
  * Bulk loading data into the Virtuoso database
  * Installing additional `VAD` packages into the database
  * Adding new Virtuoso users
  * Granting permissions to Virtuoso users
  * Regenerating free-text indexes or other initial data

The scripts run only once, during the initial database creation; subsequent restarts of the docker image do not cause these scripts to be re-run.

The scripts run in alphabetical order. Prefixing script names with sequence numbers makes the execution order explicit.

For security purposes, Virtuoso runs the `.sql` scripts in a special mode and does not respond to connections on its SQL (`1111`) and/or HTTP (`8890`) ports.

At the end of each `.sql` script, Virtuoso automatically performs a `checkpoint`, to make sure the changes are fully written back to the database. This is very important for scripts that use the bulk loader function `rdf_loader_run()` or manually change the ACID mode of the database for any reason.

After all the initialization scripts complete, Virtuoso starts normally and listens to requests on its SQL (`1111`) and HTTP (`8890`) ports.


### Environment Variables

#### `DBA_PASSWORD_FILE`

This environment variable should be set in combination with one of the secure options to pass sensitive information to the docker image. The startup script reads the content from this file on the internal docker filesystem and assigns it to the `DBA_PASSWORD` environment variable internally. In this case the `DBA_PASSWORD` setting is not recorded in the meta data of this docker instance.

Example:

```sh
$ echo -n 'verysecretpw' | docker secret create dba_secret -

$ docker service create .... \
    ...
    --secret dba_secret \
    --env DBA_PASSWORD_FILE=/run/secrets/dba_secret \
    ...
```

See also:

* [docker secrets (docker swarm only)](https://docs.docker.com/engine/swarm/secrets/)
* [kubernetes secrets](https://kubernetes.io/docs/concepts/configuration/secret/)


#### `DAV_PASSWORD_FILE`

See `DBA_PASSWORD_FILE` for more details.


#### `DBA_PASSWORD`

If this environment variable is set via either the command-line options `-e`, `--env`, `--env-file` or the **`environment`** section in a `.yml` file, the value is assigned as the initial password of the **dba** account when creating a new database.

If this variable is set to `ami-id` the docker image attempts to get this value from the **EC2** registry on the Amazon **AMI**. If this fails or if this docker container is not started on an **AMI** the variable is regarded as unset.

If this variable is unset, a *random* password is generated and assigned as the initial password of the **dba** account when creating a new database.

The password is stored inside the docker container in `/settings/dba_password` and we recommend removing this file after changing the **dba** password to some other value, either via the `conductor` web interface or the `isql` command.

Example:

```sh
$ docker create .....
  ...
  --env DBA_PASSWORD=mysecret \
  ...
```

**NOTE:** As environment variables are stored in the meta information of the docker image, the initial password is easily visible to any accounts on the same machine able to run the `docker inspect` command. In cases where this could be an issue, the 'docker secrets' option in combination with the `DBA_PASSWORD_FILE` option is recommended.


#### `DAV_PASSWORD_FILE`

See `DBA_PASSWORD_FILE` for more details.


#### `DAV_PASSWORD`

If this environment variable is set via either the command-line options `-e`, `--env`, `--env-file` or the **`environment`** section in a `.yml` file, the value is assigned as the initial password of the **dav** account when creating a new database.

If this variable is not set, the value of the `DBA_PASSWORD` setting is used for both **dba** and **dav** accounts.

The password is stored inside the docker container in `/settings/dav_password` and we recommend removing this file after changing the **dav** password to some other value, either via the `conductor` web interface or the `isql` command.


#### `VIRTUOSO_INI_FILE`

This environment variable is used in combination with one of these options to pass information to the docker image. The startup script reads the content of this file on the internal docker filesystem and copies it to the '/database/virtuoso.ini` file, instead of installing the default `virtuoso.ini` file from the virtuoso installation.

**Note:** all path settings in `virtuoso.ini` should be based on the *internal* filesystem structure of the docker image and not refer to directory paths on the host system. Additional directories from the host system can be bound into the docker instance using `bind mounts` via command-line options such as `--mount`

After installing a `virtuoso.ini` file, the startup script parses the environment variables to allow additional updates to the `virtuoso.ini` file as detailed in the next paragraph. The startup script also rewrites the `[Plugin]` section to enable all the plugins installed in the `hosting` directory.

See also:

* [docker config](https://docs.docker.com/engine/reference/commandline/config/)
* [docker secrets (docker swarm only)](https://docs.docker.com/engine/swarm/secrets/)
* [kubernetes secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
* [docker bind mount](https://docs.docker.com/storage/bind-mounts/)


### Updating `virtuoso.ini` via Environment Settings

Using environment variables when creating the Virtuoso docker instance via the command-line options `-e`, `--env`, `--env-file` or the **`environment`** section in a `.yml` file, add or overrule any parameter within the `virtuoso.ini` file.

These environment variables must be named like:

```
VIRT_SECTION_KEY=VALUE
```

where

* `VIRT` is common prefix to group such variables together    _(always in upper case)_
* `SECTION` is the name of the `[section]` in `virtuoso.ini`  _(case insensitive)_
* `KEY` is the name of a key within the section               _(case insensitive)_
* `VALUE` is the text to be written into the key              _(case sensitive)_

The `SECTION` and `KEY` parts of these variable names can be written in either uppercase (most commonly used) or mixed case, without having to exactly match the case used inside the `virtuoso.ini` file. There is no validation on the `SECTION` and `KEY` name parts, so any mistake may result in a non-functional setting.

The following names all refer to the same setting:

* `VIRT_Parameters_NumberOfBuffers` (case matching the section and key name in `virtuoso.ini`)
* `VIRT_PARAMETERS_NUMBEROFBUFFERS` (recommended way to name environment variables)
* `VIRT_parameters_numberofbuffers` (optional)

The `VALUE` is a case-sensitive string and should be surrounded by either single (`'`) or double (`"`) quotes if there are spaces or other special characters in the string.

If the `VALUE` is set to '-', the `KEY` entry is removed from the `SECTION`.

Example:

```sh
$ docker create .... \
  ... \
  -e VIRT_PARAMETERS_NUMBEROFBUFFERS=1000000 \
  -e VIRT_HTTPSERVER_MaxClientConnections=100 \
  -e VIRT_HTTPSERVER_SSL_PROTOCOLS="TLS1.1, TLS1.2" \
  ...
```

**Note:** all path settings in `virtuoso.ini` should be based on the *internal* filesystem structure of the docker image and cannot directly refer to directory paths on the host system. Additional directories from the host system can be bound into the docker instance using `bind mounts` via command-line options such as `--mount`

See also:

* [docker bind mount](https://docs.docker.com/storage/bind-mounts/)
