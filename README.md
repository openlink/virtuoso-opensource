# Virtuoso Open-Source Edition: Building

Copyright (C) 1998-2023 OpenLink Software <vos.admin@openlinksw.com>

## Table of Contents
- [Introduction](#introduction)
- [Package Dependencies](#package-dependencies)
  * [Development packages](#development-packages)
- [Diskspace Requirements](#diskspace-requirements)
- [Make FAQ](#make-faq)
  * [Recent systems](#recent-systems)
    + [Linux 64-bit](#linux-64-bit)
    + [Mac OS X 10.9-10.15 64-bit](#mac-os-x-109-1015-64-bit)
    + [Mac OS X 11.x Universal](#mac-os-x-11x-universal)
    + [Mac OS X 12.x Universal](#mac-os-x-12x-universal)
    + [FreeBSD 64-bit](#freebsd-64-bit)
  * [Legacy systems](#legacy-systems)
    + [AIX 4.x 64-bit](#aix-4x-64-bit)
    + [AIX 5.x 64-bit](#aix-5x-64-bit)
    + [Digital Unix/OSF1 V5.0 64-bit](#digital-unix-osf1-v50-64-bit)
    + [HP/UX 11.00 64-bit](#hp-ux-1100-64-bit)
    + [HP/UX 11.23 Itanium 64-bit](#hp-ux-1123-itanium-64-bit)
    + [Solaris 2.10 Opteron 64-bit](#solaris-210-opteron-64-bit)
    + [Solaris 2.8 and above SPARC 64-bit](#solaris-28-and-above-sparc-64-bit)
    + [Generic build environment](#generic-build-environment)
- [Installation via Source Code](#installation-from-source-code)
- [Installation via Installer Programs](#installer-packages)
- [Test Suite](#test-suite)
- [Getting Started](#getting-started)
- [VAD Packages](#vad-packages)



## Introduction

This document explains steps to take after obtaining a Virtuoso source
snapshot or git clone.

These sections explain how to compile, test and install and what
components are produced by the make process and how one can interact
with them.

## Package Dependencies

To generate the configure script and all other build files necessary,
please make sure the following packages and recommended versions are
installed on your system.

| Package  | Minimum | Upto   | From                                  |
|----------|-------: |------: |---------------------------------------|
| autoconf | 2.57    | 2.69   | http://www.gnu.org/software/autoconf/ |
| automake | 1.9     | 1.16.1 | http://www.gnu.org/software/automake/ |
| libtool  | 1.5     | 2.4.6  | http://www.gnu.org/software/libtool/  |
| flex     | 2.5.33  | 2.6.4  | http://flex.sourceforge.net/          |
| bison    | 2.3     | 3.5.1  | http://www.gnu.org/software/bison/    |
| gperf    | 3.0.1   | 3.1    | http://www.gnu.org/software/gperf/    |
| gawk     | 3.1.1   | 5.0.1  | http://www.gnu.org/software/gawk/     |
| m4       | 1.4.1   | 1.4.18 | http://www.gnu.org/software/m4/       |
| make     | 3.79.1  | 4.2.1  | http://www.gnu.org/software/make/     |
| OpenSSL  | 0.9.8e  | 3.1.x  | http://www.openssl.org/               |

and any GNU packages required by these. The autogen.sh and configure
scripts check for the presence and right version of some of the required
components.

The `Minimum` column contains the oldest known versions of these
packages capable of building Virtuoso. Older versions of these packages
can sometimes be used, but could cause build problems.

The `Upto` column contains the most recently tested version of these
packages. Newer minor revisions of these packages can likely be used, but 
major version upgrades may cause build problems.

To check the version number of the tools installed on your system, use
one of the following commands:

-   autoconf –version
-   automake –version
-   libtoolize –version
-   flex –version
-   bison –version
-   gperf –version
-   gawk –version
-   m4 –version
-   make –version
-   openssl version

If you have an older version than automake version 1.9 you can edit the
configure.ac script around line 47 using the examples provided for each
version.

If you have a problem porting Virtuoso in your platform, please open a
[Issue on Github](https://github.com/openlink/virtuoso-opensource/issues)
so we can assist you.


### Development packages
Note that many operating systems (particularly all Linux distibutions)
split some of these packages into runtime and development packages, so
users of these platforms may need to run e.g.:

    apt-get install libssl-dev

or

    yum install openssl-devel 

to get development headers & libraries for OpenSSL.

## Diskspace Requirements

The build produces a demo database and Virtuoso application packages
that are quite large. At least 800 MB of free space should be available
in the build file system.

When running \`make install’, the target file system should have about
400 to 600 MB free. By default, the install target directories are under
/usr/local/, but you can specify

    ./configure --prefix=/path/to/dir

instead.

The minimum working configuration consists of the server executable and
config files plus database, no more than a few MB for the server
executable, depending on platform and options.

## Make FAQ

In the root directory of the checkout perform the following commands:

    ./autogen.sh        # should only be needed in git clone
    ./configure
    make

to produce the default binaries, VAD packages and demo database. This
takes some time, principally due to building and filling the demo
database, rendering the XML documentation into several target formats
and composing various Virtuoso application packages. It takes about 30
minutes on a 2GHz machine.

The default configure does not enable most of the runtime-hosting and
extension features. See the links on the building page for instructions
on how to enable these and what additional software is required.

Some builds require additional C compiler and other environment flags to
be set before running the configure command, especially when building
64-bit versions of the server. If your system is not in this list,
please try to run the configure command without any environment
settings.

Warning: if VAD or other packages fail to be built, especially on 64-bit
Linux platforms, ensure you’re not using excessive optimization.
CFLAGS=“-O2” is known to work but there are reports of -O3 failing.

If your system requires additional flags not listed below, please
contact us at <vos.admin@openlinksw.com>.


### Recent systems

#### Linux 64-bit

    CFLAGS="-O2 -m64"
    export CFLAGS
    ./configure ...

#### Mac OS X 10.9-10.15 Intel 64-bit

    CFLAGS="-O -arch x86_64 -mmacosx-version-min=10.9"
    export CFLAGS
    ./configure ...

#### Mac OS X 11.x Universal

    CFLAGS="-O -arch arm64 -arch x86_64 -mmacosx-version-min=10.9"
    export CFLAGS
    ./configure --disable-dependency-tracking ...

#### Mac OS X 12.x Universal

    CFLAGS="-O -arch arm64 -arch x86_64 -mmacosx-version-min=10.9"
    export CFLAGS
    ./configure --disable-dependency-tracking ...

#### FreeBSD 64-bit

    CFLAGS="-O2 -m64"
    export CFLAGS
    ./configure ...


### Legacy systems

#### AIX 4.x 64-bit

    CC=cc_r7
    CFLAGS="-O -q64"
    LDFLAGS="-brtl"
    OBJECT_MODE=64
    export CC CFLAGS LDFLAGS OBJECT_MODE
    ./configure ...

#### AIX 5.x 64-bit

    CC=cc_r
    CFLAGS="-O -q64"
    LDFLAGS="-brtl"
    OBJECT_MODE=64
    export CC CFLAGS LDFLAGS OBJECT_MODE
    ./configure ...

#### Digital Unix/OSF1 V5.0 64-bit

    CFLAGS="-O"
    export CFLAGS
    ./configure ...

#### HP/UX 11.00 64-bit

    CFLAGS="-O -Ae +DA2.0W"
    export CFLAGS
    ./configure ...

#### HP/UX 11.23 Itanium 64-bit

    CFLAGS="-O -Ae +DD64"
    export CFLAGS
    ./configure ...


#### Solaris 2.10 Opteron 64-bit

    CC=cc
    CFLAGS="-O -xtarget=opteron -xarch=amd64"
    PATH=/opt/SUNWspro/bin:/usr/ccs/bin:$PATH
    export CFLAGS CC PATH
    ./configure ...

#### Solaris 2.8 and above SPARC 64-bit

    CC=cc
    CFLAGS="-O -xtarget=ultra -xarch=v9"
    PATH=/opt/SUNWspro/bin:/usr/ccs/bin:$PATH
    export CFLAGS CC PATH
    ./configure ...

#### Generic build environment

    CC=cc
    CFLAGS="-O"
    export CC CFLAGS
    ./configure
    make
    make install



## Installation From Source Code

After running configure && make,

    make install

at the root of the build tree copies the files to the locations
specified by the –prefix option to configure. The default of –prefix is
/usr/local/. You can override this by specifying \`make install
prefix=/opt/virtuoso’ instead, for example.

These subdirectories are all appended to the specified prefix,
i.e. /usr/local/ by default:

-   share/virtuoso/doc/html
-   share/virtuoso/doc/pdf
-   share/virtuoso/vad - VAD packages BPEL, Conductor, tutorials,
    documentation
-   var/lib/virtuoso/db - Empty database
-   var/lib/virtuoso/demo - Demo database - obsolete as of version 5.0.3
-   bin/ - The virtuoso-t, isql, isqlw, virt_mail, virtuoso-sample-t,
    inifile executables
-   lib/ - libvirtuoso-t.a libvirtuoso-t.la virtodbc32.a virtodbc32.la
    virtodbc32 r.a virtodbc32_r.la virtodbc_r.so wikiv.so, plus any
    plugins that may be enabled.
-   lib/virtuoso - hosting sample.a hosting_sample.la hosting_sample.so
    plugin_sample.a plugin_sample.so

Note: as of version 5.0.2, the ./configure script supports different
subdirectory structures with the –with-layout= parameter. If you’ve
specified something other than the default, the above may differ
accordingly.

As of version 5.0.3, the demo is a VAD package, not a separate
directory.

## Installer Packages 

If installation from source code isn't for you, simply download and install using any of the following:

* [GNU/Linux](https://github.com/openlink/virtuoso-opensource/releases/download/v7.2.7/virtuoso-opensource.x86_64-generic_glibc25-linux-gnu.tar.gz)
* [Windows Installer](https://github.com/openlink/virtuoso-opensource/releases/download/v7.2.7/Virtuoso_OpenSource_Server_7.2.x64.exe)
* [macOS (Intel64 and Apple Silicon)](https://github.com/openlink/virtuoso-opensource/releases/download/v7.2.7/Virtuoso_Open_Source_for_macOS.dmg)
* [Docker Container](https://hub.docker.com/r/openlink/virtuoso-opensource-7)

## Test Suite

Optionally, you can run

    make check

at the root of the build tree to start the automated test suite. This
takes about an hour on a 2GHz machine and requires approximately 1 GB of
free disk space.

## Getting Started

Run

    cd var/lib/virtuoso/db 
    virtuoso-t -f &

to start the server in the background. It will not detach from the
shell, so you see the startup messages.

By default, when no -c parameter is specified, virtuoso will use the
virtuoso.ini file in this directory, which is generated as part of
\`make install’.

The first time it’s run, it will create the empty database (no special
commands required) and install the Conductor VAD package. From here, you
can access http://localhost:8890/ and http://localhost:8890/conductor/
and use the System Administration / Packages page to install other
packages such as Demo and the ODS suite (addressbook, weblog, feeds
manager and other applications) etc.

The default login is `dba' with a password of`dba’ for the Conductor and
isql (for DAV functions, the default login is
`dav' with a password of`dav’).

You will see a checkpoint in the terminal for each package selected:

    15:33:54 INFO: Checkpoint made, log reused

To connect with the command line SQL tool,

    isql 1112 dba dba

gives a SQL\> prompt.

If you’ve installed the demo VAD above, type SQL\> use Demo;

to switch to the demo database, containing the Microsoft Northwind
sample tables. The \`help’ command in isql gives further instructions.

To use the web admin interface, point the browser to:

    http://localhost:8890/conductor

To read the documents online:

    http://localhost:8890/doc/html

To experiment with online tutorials you can use the conductor to install
the Tutorial vad package into your database, then point the browser to:

    http://localhost:8890/tutorial

## VAD Packages

The different VAD packages can be installed via ISQL using the following
command (if the installation packages reside in the filesystem):

    SQL> vad_install ('file/system/path/package-name.vad', 0);

Alternatively, you can copy VAD packages to Virtuoso’s DAV repository
and then execute the following command (also from ISQL):

    SQL> vad_install ('webdav/path>/package-name.vad', 1);

at the isql command line. 

*Note*: The DirsAllowed parameter of the Parameters section of the
ini-file must allow access to the directory where the package file
is located.

