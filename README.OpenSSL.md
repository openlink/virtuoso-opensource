Virtuoso and OpenSSL
====================

*Copyright (C) 1998-2022 OpenLink Software <vos.admin@openlinksw.com>*

Virtuoso Open Source Edition uses the OpenSSL libraries for cryptographic
operations as well as handling both client-side and server-side secure
connections for both HTTPS as well as iSQL/ODBC transport layers.

Virtuoso can be compiled against OpenSSL 0.9.8i up to OpenSSL v1.0.2p which
is the current Long Term Support (LTS) release of OpenSSL.

The OpenSSL v1.1.x API is incompatible with previous versions. The Virtuoso
development team is currently working on enhancing the Virtuoso code to
support the new API, but this work is not yet completed.

Many new Linux distributions are including OpenSSL v1.1.0 as their base
version, although they typically also supply an OpenSSL v1.0.x development
kit for backward compatibility.

Other operating systems like macOS and Windows do not supply OpenSSL at all,
but require third party ports for this support.

During `configure` time, Virtuoso will check the availability and version of
the installed OpenSSL development headers and libraries on your system and
will report any issues it finds.

macOS
-----
Apple is actively deprecating OpenSSL from macOS, so your system likely
has a pretty old version of `openssl`, and as of High Sierra (10.13),
Apple completely removed the required `include` files from the
`/usr/include/openssl` directory.

We recommend installing the OpenSSL 1.0.2 library using:

    $ brew install openssl

At configure time, you can then use the following:

    $ sh ./configure \
      ..... \
      --enable-openssl=/usr/local/opt/openssl/

More information on porting VOS to macOS can be found in
[`README.MACOSX.md`](README.MACOSX.md).

Ubuntu 18.04 LTS
----------------
Ubuntu installs both an OpenSSL v1.0.2 runtime and an OpenSSL v1.1.0 runtime
in the form of shared libraries which are installed side-by-side on the system.

A developer can choose to install either the 1.0 or the 1.1 software
development kit (SDK) which includes the necessary header files and
development libraries.

To build VOS, you need to run the following command which will uninstall
the 1.1 SDK and replace it with the 1.0 SDK.

    $ sudo apt-get install libssl1.0-dev

Since Ubuntu installs runtime libraries for both versions of OpenSSL
side-by-side, after compiling and installing VOS on your system, you can
re-install the newer 1.1 SDK for compiling other programs by running:

    $ sudo apt-get install libssl-dev

Debian 9
--------
Debian uses the same package names as Ubuntu:

    $ sudo apt-get install libssl1.0-dev

And to switch back:

    $ sudo apt-get install libssl-dev

Fedora 28
---------
Fedora 28 also has separate SDKs for both versions of OpenSSL.

To install the 1.0 SDK use:

    $ sudo dnf install --allowerasing compat-openssl10-devel

To switch back to the 1.1 SDK use:

     $ sudo dnf install --allowerasign openssl-devel

Windows
-------
The OpenSSL library needs to be built as a static library using Visual
Studio. Detailed instructions for building OpenSSL can be found in the
`INSTALL.W32` document in the OpenSSL source distribution.

**IMPORTANT**: By default the OpenSSL library is built using `MSVCRT` compile
flags, leading to conflicts when linking the Virtuoso Open-Source binaries.
To resolve the conflicts, after unpacking the OpenSSL source tarball, you
need to edit `/util/pl/VC-32.pl`, and change the `cflags` to use the `/MT`
and `/MTd` compiler switches instead of the `/MD` and `/MDd`.

Finally, the `libeay32.lib` and `ssleay32.lib` from `/out32` and files from
`/inc32/openssl` must be copied to `<Virtuoso Open Source dir>/win32/openssl/`.

More notes on porting Virtuoso on Windows can be found in
[`README.WINDOWS`](README.WINDOWS).


Custom installation
-------------------
If you have performed a custom build of OpenSSL on your own system, and/or
if OpenSSL is installed in a non-standard location, you can use the
`--enable-openssl` flag during `configure` to point the build system to the
location where your OpenSSL headers and libraries are installed:

    $ sh ./configure \
      ..... \
      --enable-openssl=/opt/openssl/

The `configure` script will also check `/opt/openssl/include` for the
required header files and `/opt/openssl/lib` for the libraries, before any
standard locations embedded in the compiler.
