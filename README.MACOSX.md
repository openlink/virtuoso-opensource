Building Virtuoso Open Source Edition on macOS (a/k/a Mac OS X)
===============================================================

*Copyright (C) 1998-2018 OpenLink Software <vos.admin@openlinksw.com>*


## Introduction
This document describes how to check out a copy of the git tree for development purposes on macOS.

It also lists the packages that need to be installed prior to generating the necessary scripts and
Makefiles to build the project.

If you have any questions, please email us at <mailto:vos.admin@openlinksw.com>.


## Downloading the source code
OpenLink Software frequently pushes updates to the Virtuoso Open Source tree on GitHub.


### Using git on a local machine
Developers who just want to build Virtuoso on their own machine can make a local clone of the source
tree using the following command:

    $ git clone git://github.com/openlink/virtuoso-opensource.git

At this point, you can create your own work branch based on any of the branches available, create
bugfixes and commit them to your own branch, and then use the `git format-patch` command to generate
the appropriate diffs to send to <mailto:vos.admin@openlinksw.com>.


### Forking the tree on Github
OpenLink Software encourages developers to create their own account on GitHub, after which they can
fork the project by going to the following URL with any web browser and pressing the **Fork** button:

    https://github.com/openlink/virtuoso-opensource

At this point you can clone your fork to your local macOS system, create your own branches to make
enhancements/bugfixes, push these branches back to GitHub, and then send pull requests using the
excellent GitHub interface.  The OpenLink team can then examine and incorporate your fixes into the
master tree for an upcoming release.

Github has excellent documentation on how to fork a project, send pull requests, track the project,
etc., on:

    http://help.github.com/


### Using a source tar archive
Developers who do not want to mess with git can also download a source tar archive from:

    https://github.com/openlink/virtuoso-opensource/archive/develop/7.x.tar.gz

This tar archive can be extracted using the following command:

    $ tar xvfz virtuoso-opensource-development-7.tar.gz

Configuration and building is exactly the same as for the cloned git tree.


## Building on macOS Yosemite (10.10) and above
Apple removed a number of programs from their `Xcode.app` command-line installation including 
`autoconf`, `automake`, `libtool`, `gperf`, and some other tools needed to build Virtuoso from 
a newly checked-out git tree.

OpenLink Software suggests using the HomeBrew package manager from http://brew.sh/ to install 
these tools.

After installing HomeBrew, you can simply run the following commands:

    $ brew install autoconf automake libtool
    $ brew install gperf bison flex git gawk pkg-config

By default, brew installs all packages and libraries into subdirectories under the `/usr/local`
directory.

Comparable packages can also be installed via MacPorts which installs into `/opt/local` directory.


### Optional features
Optional features (like command line editing in the isql tool) require:

    $ brew install libedit

or

    $ brew install readline


### OpenSSL on macOS
Apple is actively deprecating OpenSSL from macOS, so your system likely has a pretty old version
of `openssl`, and as of High Sierra (10.13), Apple completely removed the required `include` files 
from the `/usr/include/openssl` directory.

We recommend installing the OpenSSL 1.0.2 library using:

    $ brew install openssl

At configure time, you can then use the following:

    $ sh ./configure \
      ..... \
      --enable-openssl=/usr/local/opt/openssl/


### ImageMagick on macOS
The ImageMagick plugin requires the following packages be installed:

    $ brew install pkg-config
    $ brew install imagemagick@6

This installs ImageMagick 6.x together with a number of libraries to work with specific graphic formats.

At configure time you can then use --

    $ sh ./configure \
       ..... \
       --enable-imagemagick=/usr/local/opt/imagemagick\@6/


### Java on macOS

The Java installations on your machine are are best discovered with the `java_home` tool.  To find this tool on your Mac, use the following command --

    sudo find / -name "java_home"

Then use this command to discover all Java installations on your Mac, from which you can select which to include in your `configure` command --

    /System/Library/Frameworks/JavaVM.framework/Versions/A/Commands/java_home -V

Note that on macOS, Java 6 and earlier are only functional as 32-bit, and Java 8 and later are only functional as 64-bit.  OpenLink Software does not recommend using Java 7 on macOS.


## Example of running configure on macOS
First, we set some environment variables:

    $ export CFLAGS="-O -arch x86_64"
    $ export LDFLAGS="-g"
    $ export CC="clang"

Next we (re)generate the configure script and all related build files, using the supplied script in
your working directory:

    $ sh ./autogen.sh

Assuming this did not return an error, we can now configure Virtuoso.

For a full list of available `configure` options, including various optional subpackages, check the output of --

    $ sh ./configure --help

The following command includes a number of options we recommend for an initial build of Virtuoso on macOS:

    $ sh ./configure \
        --enable-maintainer-mode \
        --enable-silent-rules \
        --prefix=/usr/local/vos \
        --with-layout=openlink \
        --enable-openssl=/usr/local/opt/openssl/ \
        --enable-imagemagick=/usr/local/opt/imagemagick@6/ \
        --enable-openldap \
        --disable-python \
        --with-editline \
        --with-jdk4=/Library/Java/JavaVirtualMachines/1.6.0.jdk/Contents/Home \
        --with-jdk4_2=/Library/Java/JavaVirtualMachines/jdk1.8.0_181.jdk/Contents/Home/


If the above steps return without error, you should be able to build the archive using --

    $ make

After building, you can run the testsuite to verify your binaries are in working order:

    $ make check

Finally, to install the resulting binaries into the `/usr/local/vos` directory --

    $ make install


## Diskspace Requirements
The build produces a demo database and Virtuoso application packages that are quite large.

At least 1.1GB of free space should be available on the build file system.

Running the testsuite will require an additional 2.8GB of free space on the system.

An installation containing the Virtuoso server executable and supporting binaries, all the 
hosting plugins, VAD packages, config files, etc., (excluding the database) will take around 
350MB of disk space.


## Generate build files
Please read the `INSTALL` and `README` files in this directory for further
information on how to configure the package and install it on your system.
