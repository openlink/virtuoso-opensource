# Building VOS from Source

*Copyright (C) 1998-2026 OpenLink Software <vos.admin@openlinksw.com>*

## Jena, RDF4j and JDBC Drivers

Virtuoso JDBC drivers as well as Jena and RDF4j providers can be downloaded from [Maven Central](https://central.sonatype.com/search?q=com.openlinksw).


## Package Dependencies

### Core Dependencies

For a minimal build with core VOS functionality, ensure you have these packages and recommended versions installed:

| Package   | Minimum | Up to  | From                                  |
| --------- | ------- | ------ | ------------------------------------- |
| autoconf  | 2.57    | 2.69   | http://www.gnu.org/software/autoconf/ |
| automake  | 1.9     | 1.16.1 | http://www.gnu.org/software/automake/ |
| libtool   | 1.5     | 2.4.6  | http://www.gnu.org/software/libtool/  |
| flex      | 2.5.33  | 2.6.4  | http://flex.sourceforge.net/          |
| bison     | 2.3     | 3.5.1  | http://www.gnu.org/software/bison/    |
| gperf     | 3.0.1   | 3.1    | http://www.gnu.org/software/gperf/    |
| gawk      | 3.1.1   | 5.3.0  | http://www.gnu.org/software/gawk/     |
| m4        | 1.4.1   | 1.4.18 | http://www.gnu.org/software/m4/       |
| make      | 3.79.1  | 4.2.1  | http://www.gnu.org/software/make/     |
| OpenSSL   | 0.9.8e  | 3.6.x  | http://www.openssl.org/               |

The `Minimum` and `Up to` columns specify known-good versions for each package. Other versions, both older and newer, *might* work, but are untested and could cause problems.

Test the installed version of each package by running it with `--version`, except for OpenSSL, where the command is `openssl version`.

### Recommended Packages

In addition to the core packages, these are recommended:

| Package | Recommended Version | From                               |
| ------- | ------------------- | ---------------------------------- |
| libedit | 20240517-3.1        | https://www.thrysoee.dk/editline/  |
| bzip2   | 1.0.8               | https://sourceware.org/pub/bzip2/  |
| xz      | 5.2.12              | https://tukaani.org/xz/            |

* libedit makes the `isql` commandline utility more usable.
* bzip2 and xz are useful for bulk-loading large amounts of RDF data.

### Specific Usage Cases

The following packages are required for specific use-cases:

| Package     | Recommended Version | From                                 |
| ----------- | ------------------- | ------------------------------------ |
| openldap    | >= 2.6.8            | https://www.openldap.org/            |
| proj        | == 4.9.3            | https://proj4.org/                   |
| geos        | == 3.5.1            | https://www.osgeo.org/projects/geos/ |
| shapefileio | == 1.6.0            | https://shapelib.maptools.org/       |
| imagemagick | >= 6.9.13           | https://download.imagemagick.org/    |

Virtuoso has support for GeoSPARQL functions which requires the `proj4`, `geos` and `shapefileio` plugins. Building these is the subject of a separate document: [README.GeoSPARQL.md](README.GeoSPARQL.md).

## Installing Dependencies

To install the dependencies, pick one of these lines for your OS/distribution and then resume at the "Building" section below:


### Linux

<details>
<summary>On Ubuntu or Debian</summary>

```
$ sudo apt install git
$ sudo apt install build-essential autoconf automake libtool flex bison gperf gawk m4 make libssl-dev
```

Optionally:
```
$ sudo apt install libreadline-dev libbz2-dev liblzma-dev
```
</details>


<details>
<summary>On Alma or Rocky Linux</summary>

```
$ sudo yum install git
$ sudo yum install autoconf automake gcc libtool flex bison gperf gawk m4 make openssl openssl-devel
```

Optionally:
```
$ sudo yum install bzip2-devel xz-devel libedit-devel
```
</details>

<details>
<summary>On RedHat Enterprise Linux</summary>

On RedHat Linux 7, first add this repository:
```
$ sudo yum install git
$ sudo yum --enablerepo=rhui-REGION-rhel-server-optional install gperf
```

On RedHat Enterprise Linux 8 (and newer), first add this repository:

```
$ sudo yum --enablerepo=PowerTools install gperf
```

And on all versions, install all dependencies as follows:

```
$ sudo yum install autoconf automake gcc libtool flex bison gperf gawk m4 make openssl openssl-devel
```
</details>

<details>
<summary>On OpenSuSE</summary>

```
$ sudo zypper install git
$ sudo zypper install autoconf automake gcc libtool flex bison gperf gawk m4 make openssl libopenssl-3-devel
```

Optionally:
```
$ sudo zypper install libedit-devel libbz2-devel xz-devel
```
</details>

### macOS

<details>
<summary>On macOS</summary>

First, install [Xcode](https://developer.apple.com/xcode/) using the Mac App Store.

Second, run this to install the command line developer tools:

```xcode-select --install```

Third, many of those utilities were removed from Xcode, so install [Homebrew](https://brew.sh/), then run

```
brew install autoconf automake gcc libtool flex bison gperf gawk m4 make openssl@3.0
```
</details>

-------

## Cloning the Repository

Checkout a clone of the git repository:

```sh
$ git clone https://github.com/openlink/virtuoso-opensource.git
$ cd virtuoso-opensource
```

The default and recommended branch is `develop/7`. Users requiring a slower update cycle may prefer `stable/7` instead.

## Building

To regenerate the configure script and all related build files, use the supplied script in your working directory:

```sh
$ ./autogen.sh
```

Assuming this runs successfully,

   * on most OSs, run:

```sh
$ ./configure \
   --enable-maintainer-mode \
   --prefix=/opt/virtuoso-opensource \
   --with-layout=openlink
```

   * on macOS, add a pointer to find OpenSSL from homebrew:

```sh
$ ./configure \
   --enable-maintainer-mode \
   --prefix=/opt/virtuoso-opensource \
   --with-layout=openlink \
   --enable-openssl=/opt/homebrew/Cellar/openssl@3.0/3.0.20/
```

and then:

```sh
$ make -j4
```

Running the test suite is optional. First, ensure the `bzip2`, `curl`, `gunzip`, `gzip`, `tar`, `unzip` `wget` and `zip`
package, for your OS/distribution are installed, then run:

```sh
$ make check
```

Finally:

```sh
$ sudo make install
```

## VOS Configure Options

VOS can be configured with many options and VAD packages, for example libshape, libgeos, libproj, ImageMagick and other hosting modules. Many of these require further development versions of supporting libraries of their own.

For further information, run:

```sh
$ ./configure --help
```


Certain build targets are only enabled when running `configure` with the `--enable-maintainer-mode` option.

`make install` obeys the `--with-layout=` parameter for filesystem layouts.


## Disk Space Requirements

The build produces a demo database and Virtuoso application packages that are quite large. At least 4 GiB of free space should be available in the build file system.

When running `make install`, the target file system should have about 500 MiB free. By default, the install target directories are under `/opt/virtuoso-opensource/`.

Running the testsuite requires approximately 2 GiB extra disk space.

The minimum working configuration consists of the server executable and config files plus database, no more than a few MiB for the server executable, depending on platform and options.


# Starting Virtuoso

Change into the installation's `database/` subdirectory and start the server:

```sh
$ cd /opt/virtuoso-opensource/database
$ ls
virtuoso.ini
```

For the first run, to illustrate the potential console output, run it in debug foreground mode:

```sh
$ ../bin/virtuoso-t -df
```

The server takes a few seconds to start, installs the Conductor VAD and eventually says it is online:

```
...
15:14:08 INFO: PL LOG: Installation with dependencies complete
15:14:08 INFO: Checkpoint started
15:14:08 INFO: Checkpoint finished, log reused
15:14:08 INFO: HTTP/WebDAV server online at 8890
15:14:08 INFO: Server online at 1111 (pid 50403)
```

In normal use, the server can be run without any arguments
```
../bin/virtuoso-t
```
and it detaches from the console, leaving its output only in virtuoso.log.

At this point, open http://localhost:8890/ in your browser. This is the welcome home page with links to Conductor (`http://localhost:8890/conductor`) and the SPARQL endpoint (`http://localhost:8890/sparql`).

Additionally, from the terminal, run
```
../bin/isql
```
for the SQL interface (port 1111 by default).
