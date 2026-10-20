# Using Virtuoso Open Source Edition GIT Tree

*Copyright (C) 1998-2026 OpenLink Software <vos.admin@openlinksw.com>*


# Introduction

This document describes how to check out a copy of the git tree for development purposes. It also lists the packages that need to be installed prior to generating the necessary scripts and Makefiles to build the project.

Git access is only needed for developers actively tracking progress of the Virtuoso source code and contributing bugfixes or enhancements to the project. It requires basic knowledge of git itself, the general layout of open source and GNU projects, the use of autoconf and automake etc. which is beyond the scope of this document.

Email questions to <vos.admin@openlinksw.com> or open a [GitHub issue](https://github.com/openlink/virtuoso-opensource/issues/).


# Git Archive Server Access

For main development, OpenLink Software publishes the Virtuoso Open Source tree to GitHub and encourages everyone interested in tracking the project to make an account there.

Users mainly wanting to track the code can use this command to get a copy of the tree:

```sh
$ git clone git://github.com/openlink/virtuoso-opensource.git
```


At this point, create your own work branch based on any of the branches available, create bugfixes and commit them to your own branch. You can then submit your changes in either of two ways, whichever you prefer. See the [Contributor Guidelines](CONTRIBUTING.md) for what we expect from a contribution.

* Use the 'git format-patch' command to generate the appropriate diffs and send them to:

      vos.admin@openlinksw.com

* Fork the project on GitHub, push your branch to your fork and send a pull request using the GitHub interface.

Either way, the OpenLink team will examine your changes and incorporate the fixes into the development tree (`develop/7`) for an upcoming release.

GitHub has excellent documentation on how to fork a project, send pull requests, track the project etc. on:

    https://docs.github.com/


OpenLink Software continues to use sourceforge.net for the source tarball releases and certain binary releases and for completeness also provide read-only Git Archive access.

For more information read:

   https://sourceforge.net/scm/?type=git&group_id=161622
