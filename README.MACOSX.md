# Building Virtuoso Open Source Edition on Mac OS X
Copyright (C) 1998-2018 OpenLink Software <vos.admin@openlinksw.com>


## Introduction
This document describes how to checkout a copy of the git tree for development purposes on Mac OS X.

It also lists the packages that need to be installed prior to generating the necessary scripts and
Makefiles to build the project.

If you have any questions, please email us at <mailto:vos.admin@openlinksw.com>.


## Downloading the source code
OpenLink Software frequently pushes updates to the Virtuoso Open Source tree on GitHub.


### Using git on a local machine
Developers who just want to build Virtuoso on their own machine can make a local clone of the source
tree using the following command:

    $ git clone git://github.com/openlink/virtuoso-opensource.git

At this point you can create your own work branch based on any of the branches available, create
bugfixes and commit them to your own branch and then use the 'git format-patch' command to generate
the appropriate diffs to send to <mailto:vos.admin@openlinksw.com>.


### Forking the tree on Github
OpenLink Software encourages developers to create their own account on GitHub, after which they can
fork the project by going to the following URL with any web browser and pressing the **Fork** button:

    https://github.com/openlink/virtuoso-opensource

At this point you can clone your fork to your local Mac OS X system, create your own branches to make
enhancements/bugfixes, push these branches back to GitHub and then send pull requests using the
excellent GitHub interface for the OpenLink team to examine and incorporate the fixes into the
master tree for an upcoming release.

Github has excellent documentation on how to fork a project, send pull requests, track the project
etc. on:

    http://help.github.com/


### Using a source tar archive
Developers who do not want to mess with git can also download a source tar archive from:

    https://github.com/openlink/virtuoso-opensource/archive/develop/7.x.tar.gz

This tar archive can be extracted using the following command:

    $ tar xvfz virtuoso-opensource-development-7.tar.gz

Configuration and building is exactly the same as for the cloned git tree.


## Building on Mac OS X 10.10 and above
Apple removed a number of programs from their Xcode.app command line installation including the
autoconf, automake, libtool, gperf and some other tools needed to build Virtuoso from a newly
checked out git tree.

OpenLink Software suggest using the HomeBrew package manager from http://brew.sh/ to install these
tools.

After the installation of HomeBrew you need to install the following package:

    $ brew install autoconf automake libtool
    $ brew install gperf bison flex git gawk pkg-config

By default brew installs all packages and libraries into subdirectories under the /usr/local
directory.

Comparable packages can also be installed via MacPorts which installs into /opt/local directory.


### Optional features
Optional features like command line editing in the isql tool require:

    $ brew install libedit

or

    $ brew install readline


### OpenSSL on Mac OS X
As Apple is actively deprecating OpenSSL from Mac OS X, your system either has a pretty old version
of openssl, and in case of High Sierra (10.13) Apple removed the required include files from the
/usr/include/openssl directory completely.

We recommend installing the OpenSSL 1.0.2 library using:

    $ brew install openssl

And at configure time you can use the following:

    $ sh ./configure \
      ..... \
      ..... \
      --enable-openssl=/usr/local/opt/openssl/


### ImageMagick on Mac OS X
The ImageMagick plugin requires the following packages to be installed:

    $ brew install pkg-config
    $ brew install imagemagick@6

This installs ImageMagick 6.x together with a number of libraries to work with specific graphic formats.

At configure time you can use the following line:

    $ sh ./configure \
       ..... \
       --enable-imagemagick=/usr/local/opt/imagemagick\@6/


## Example of running configure on Mac OS X
First we set some environment variables:

    $ export CFLAGS="-O -arch x86_64"
    $ export LDFLAGS="-g"
    $ export CC="clang"

Next we (re)generate the configure script and all related build files, using the supplied script in
your working directory:

    $ sh ./autogen.sh

Assuming this did not return an error we can now configure Virtuoso.

For a full list of available `configure` options, including various optional subpackages, check the output of:

    $ sh ./configure --help

The following command includes a number of options we recommend for an initial build of Virtuoso on Mac OS X:

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
        --with-jdk4=/System/Library/Frameworks/JavaVM.framework/Versions/1.6.0 \
        --with-jdk4_1=/Library/Java/JavaVirtualMachines/jdk1.7.0_71.jdk/Contents/Home/ \
        --with-jdk4_2=/Library/Java/JavaVirtualMachines/jdk1.8.0_45.jdk/Contents/Home/

If the above steps return without error you should now be able to build the archive using the following commands:

    $ make

After building you can run the testsuite to verify your binaries are in working order:

    $ make check

And finally to install the resulting binaries into the /usr/local/vos directory:

    $ make install


## Diskspace Requirements
The build produces a demo database and Virtuoso application packages that are quite large.

At least 1.1GB of free space should be available on the build file system.

Running the testsuite requires an additional 2.8GB of free space on the system.

An installation containing the virtuoso server executable and supporting binaries, all the hosting
plugins, VAD packages, config files etc excluding the database will take around 350MB of disk space.


## Generate build files
Please read the files INSTALL and README in this directory for further
information on how to configure the package and install it on your system.
