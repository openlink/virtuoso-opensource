Using Virtuoso Open Source Edition GIT Tree
===========================================

Copyright (C) 1998-2018 OpenLink Software <vos.admin@openlinksw.com>


Introduction
============

This document describes how to checkout a copy of the git tree for
development purposes. It also lists the packages that need to be
installed prior to generating the necessary scripts and Makefiles to
build the project.

Git access is only needed for developers who want to actively track
progress of the Virtuoso source code and contribute bugfixes or
enhancements to the project. It requires basic knowledge of git
itself, the general layout of open source and GNU projects, the use
of autoconf and automake etc, which is beyond the scope of this
document. 

If you have any questions, please email us at <vos.admin@openlinksw.com>.


Git Archive Server Access
=========================

For main development OpenLink Software will publish the Virtuoso
Open Source tree to GitHub and encourage everyone who is interested
in tracking the project, to make an account there.

Users who mainly just want to track the code can use the following
command to get a copy of the tree:

    $ git clone git://github.com/openlink/virtuoso-opensource.git


At this point you can create your own work branch based on any of
the branches available, create bugfixes and commit them to your own
branch and then use the 'git format-patch' command to generate the
appropriate diffs to send to:

    vos.admin@openlinksw.com


Developers are encouraged to fork the project using GitHub, create
their own branches to make enhancements/bugfixes and then send pull
requests using the excellent GitHub interface for the OpenLink team
to examine and incorporate the fixes into the master tree for an
upcoming release.

Github has excellent documentation on how to fork a project, send
pull requests, track the project etc. on:

    http://help.github.com/


OpenLink Software will continue to use sourceforge.net for the
source tarball releases and certain binary releases, and for
completenes will also provides read-only Git Archive access.

For more information read:

   https://sourceforge.net/scm/?type=git&group_id=161622




Package Dependencies
====================

To generate the configure script and all other build files necessary,
please make sure the following packages and recommended versions are
installed on your system.

    Package   Version  From
    autoconf  2.57     http://www.gnu.org/software/autoconf/
    automake  1.9      http://www.gnu.org/software/automake/
    libtool   1.5      http://www.gnu.org/software/libtool/
    flex      2.5.33   http://flex.sourceforge.net/
    bison     2.3      http://www.gnu.org/software/bison/
    gperf     2.7.2    http://www.gnu.org/software/gperf/
    gawk      3.1.1    http://www.gnu.org/software/gawk/
    m4        1.4.1    http://www.gnu.org/software/m4/
    make      3.79.1   http://www.gnu.org/software/make/
    OpenSSL   0.9.8e   http://www.openssl.org/

and any GNU packages required by these. The autogen.sh and configure
scripts check for the presence and right version of some of the required
components.

The above version are the minimum recommended versions of these
packages. Older version of these packages can sometimes be used, but
could cause build problems.

To check the version number of the tools installed on your system,
use one of the following commands:

  * autoconf --version
  * automake --version
  * libtoolize --version
  * flex --version
  * bison --version
  * gperf --version
  * gawk --version
  * m4 --version
  * make --version
  * openssl version

If you have an older version than automake version 1.9 you can edit
the configure.ac script around line 47 using the examples provided for
each version.

Mac OS X 10.10
--------------
Apple removed a number of programs from their Xcode.app commandline
installation including the autoconf, automake, libtool, gperf and
some other tools needed to build Virtuoso from a newly checked out
GIT tree. We suggest using the HomeBrew package manager from
http://brew.sh/ to install these tools.

RedHat Enterprise Linux 7
-------------------------
On RedHat 7, the gperf tool is no longer available from the default
repos, but can be installed using the following command:

  $ sudo yum --enablerepo=rhui-REGION-rhel-server-optional info gperf


Diskspace Requirements
======================

The build produces a demo database and Virtuoso application packages
that are quite large. At least 800 MB of free space should be available
in the build file system.

When running `make install', the target file system should have about 460
MB free. By default, the install target directories are under /usr/local/,
but you can specify

    ./configure --prefix=/path/to/dir

instead.

The minimum working configuration consists of the server executable
and config files plus database, no more than a few MB for the server
executable, depending on platform and options.


Generate build files
====================

To (re)generate the configure script and all related build files,
use use the supplied script in your working directory:

    $ ./autogen.sh

If the above command succeed without any error messages, please use the
following command to check out all the options you can use:

    $ ./configure --help

Certain build targets are only enabled when the --enable-maintainer-mode
flag is added to configure.

Please read the files INSTALL and README in this directory for further
information on how to configure the package and install it on your system.
