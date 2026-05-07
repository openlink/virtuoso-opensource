# Building on Windows

*Copyright (C) 1998-2026 OpenLink Software <vos.admin@openlinksw.com>*

This page gives instructions for building Virtuoso Open-Source Edition on Windows 32- or 64-bit platforms.

Install these development tools and software:

  * Microsoft Visual Studio 2003
  * Cygwin bash with developer tools (gawk, flex, bison):

	Package   Version
	flex      2.5.33
	bison     2.3
	gperf     3.0.1
	gawk      3.1.1

These versions are the minimum recommended versions of these packages. Older versions of these packages can sometimes be used but could cause build problems.

  * Active Perl, available from http://www.activestate.com/ActivePerl
  * OpenSSL version 1.0.2 static libraries for Windows and header files.

Optionally install:

  * Java Development Kit (JDK) for Windows version 1.4 or above, available from java.sun.com
  * PHP library for Windows version 4 and header files.
  * Active Python, available from http://www.activestate.com/ActivePython
  * ImageMagick library, available from http://www.imagemagick.org/


# Building the OpenSSL Library

The OpenSSL library needs to be built as a static library using Visual Studio. The detailed instructions for building OpenSSL can be found in the INSTALL.W32 document in the OpenSSL source distribution.

IMPORTANT: by default the OpenSSL library is built using MSVCRT compile flags, leading to conflicts when linking the Virtuoso Open-Source binaries. To resolve the conflicts, after unpacking the OpenSSL source tarball, edit /util/pl/VC-32.pl and change the "cflags" to use the "/MT" and "/MTd" compiler parameters instead of the "/MD" and "/MDd".

Finally copy the libeay32.lib and ssleay32.lib from /out32 and files from /inc32/ openssl to the <Virtuoso Open Source dir>/win32/openssl/

## Microsoft Visual Studio (VS) 2003 Settings

In order to allow VS to find the Cygwin developer tools (gawk, bison, flex), add the path to the Cygwin programs (e.g. c:\cygwin\bin) to standard settings.

To do this, execute these steps:

  * Open Microsoft VS 2003 IDE
  * Open "Tools", then "Options"
  * In the "Options" menu select "Projects" settings
  * From "Projects" settings select "VC++ Directories"
  * Add the Cygwin programs path to the list for "Executable files", before the /system32 directory so it uses cygwin's "find" command
  * Confirm the changes.

## Microsoft Visual Studio (VS) 2005 Settings
  * The same as for VS 2003
  * As the projects and solution are maintained under VS 2003, they must be converted to the VS 2005 format. To do this just open the solution under VS 2005 and confirm project conversion.
  * When asked for conversion follow the instructions on screen.

## Windows 64 Bit
  * The prerequisites are the same as for Windows 32-bit except VS 2005 should be used.
  * To build the Windows 64-bit targets use the solution (VS 2005 format) from /win64.


# Known Issues
  * Bison version 2.1 coming with Cygwin bash generates buggy code. To resolve this, upgrade bison to 2.3 or edit the generated files (sql3.c and turtle_p.c in libsrc/Wi) and remove the ';' after the 'yyparse' function begin:

...
#else
int
yyparse ()
;                       <-- remove this
#endif
#endif
...

  * The Virtuoso OLEDB provider cannot be built under VS 2005; it should be disabled.

# Build Targets

## Core Components

  * virtuoso_t - the Virtuoso Server
  * isql, isqlo - SQL command line tools
  * virtoledb - Virtuoso OLEDB provider
  * wi, wic, dk1t, dksrv, threads, threadw, xml, zlib, tidy, util - library modules

## Optional Components

  * tpcc, blobs, scroll, burstoff, cutter, cursor - test suite programs
  * libvirtuoso_t - the Virtuoso server shared object, needed for hosting servers
  * virtodbc - Virtuoso ODBC Driver
  * virtuoso_clr_t - .NET CLR-hosting server (requires .NET Framework SDK v1.1)
  * virtuoso_javavm_t - Java hosting server (requires Java SDK)
  * virtuoso_sample_t - sample of the Virtuoso server with extensions
  * hosting_perl - Perl hosting plugin (requires Active Perl)
  * hosting_python - Python hosting plugin (requires Active Python)
  * wikiv - Virtuoso Wiki plugin
  * im - ImageMagick plugin (requires ImageMagick library)


# Building Virtuoso Open Source with Microsoft Visual Studio 2003

  * Open the IDE
  * Open the solution file from /win32/virtuoso-opensource.sln
  * Select desired configuration (Debug or Release)
  * Build the solution

## Building Optional Components

## PHP5 Library Notes

Place these directories with the header files from the PHP5 source tree under /win32/php5/:

  * ext/
  * main/
  * regex/
  * TSRM/
  * win32/
  * Zend/


## Building the Virtuoso Open-Source Java hosting binary under Visual Studio 2003

  * Ensure JDK 1.4 or later is installed (a JRE is not sufficient)
  * Add environment setting JDK_PATH with value of JDK installation directory (e.g. c:\jdk1.5)
  * Start the Visual Studio IDE and enable the virtuoso_javavm_t target in the solution.
  * Build the virtuoso_javavm_t target

## Building the Virtuoso Open-Source Perl hosting plugin

  * Make sure Active Perl is installed
  * From the VS.NET 2003 command prompt, go to the /win32
  * Run 'perl mkperlenv.pl'; this produces output like:

    PERL_CFLAGS=...
    PERL_LDFLAGS=...

  * Add the PERL_CFLAGS and PERL_LDFLAGS in the environment with values printed from the step above
  * Start the Visual Studio IDE and enable the hosting_perl target in the solution.
  * Build the hosting_perl plugin

## Building the Virtuoso Open-Source Python hosting plugin

  * Make sure Active Python is installed
  * From the VS.NET 2003 command prompt, go to the /win32
  * Run 'python mkpythonenv.py'; this produces output like:

    PYTHON_CFLAGS=...
    PYTHON_LDFLAGS=...

  * Add the PYTHON_CFLAGS and PYTHON_LDFLAGS in the environment with values printed from the step above
  * Start the Visual Studio IDE and enable the hosting_python target in the solution.
  * Build the hosting_python plugin

## Building the Virtuoso Open-Source ImageMagick plugin

  * Install the ImageMagick library, available from http://www.imagemagick.org/
  * Add the IM_PATH in the environment with a value of ImageMagick installation directory
  * Start the Visual Studio IDE and enable the im target in the solution
  * Build the ImageMagick plugin

# Running the Tests

Make sure these binaries exist in /win32/[Release|Debug]

  * virtuoso-t.exe
  * isql.exe
  * blobs.exe
  * ins.exe
  * scroll.exe

  * Open a Cygwin bash shell
  * Change directory to /
  * Execute these commands

    export HOME=`pwd`
    export PATH=$HOME/win32/Release:$PATH
    export BLOBS=blobs.exe
    export INS=ins.exe
    export ISQL=isql.exe
    export PORT=5555
    export ENABLE_MTS_TEST=0
    export SCROLL=scroll.exe
    export GETDATA=getdata.exe

Note: replace in $PATH the 'Release' with 'Debug' if you are going to run the tests using debug binaries.

  * Change directory to /binsrc/tests/suite
  * Run the tests:

    ./test_server virtuoso-t

# Installation

## ODBC Driver Registration

In order to register the Virtuoso Open-Source ODBC driver, perform these steps:

  * Open a Command prompt
  * cd to the directory where the virtodbc.dll (Virtuoso Open Source ODBC Driver) is built.
  * Execute:

    regsvr32 virtodbc.dll

  * A confirmation dialog stating the driver was registered should be displayed.

# Running the Demo Database

  * Make a folder e.g. c:\dbs\virtuoso
  * Copy the Demo database and default demo.ini file to it

    cd c:
    cd \dbs\virtuoso
    copy <Virtuoso Open Source dir>\binsrc\samples\demo\demo.db
    copy <Virtuoso Open Source dir>\binsrc\samples\demo\demo.ini

  * Create a Windows service to run the Virtuoso Open-Source server:

    SET PATH=<Virtuoso Open Source dir>\win32\Release
    virtuoso-t -c demo -I Demo -S create
    virtuoso-t -c demo -I Demo -S start

To connect with the command line SQL tool,

    isql 1112 dba dba

gives a SQL> prompt.

Type:

    SQL> use Demo;

to switch to the demo database, containing the Microsoft Northwind sample tables. The help command of isql gives further instructions.

To use a web admin interface, point the browser to http://localhost:8890/conductor.

To read the online documentation: http://localhost:8890/doc/html

To experiment with online tutorials http://localhost:8890/tutorial

For VAD Packages read the README file for Linux.

# .NET CLR Hosting Server

In order to run the .NET CLR hosting server (virtuoso-clr-t):

  * Make a folder e.g. c:\dbs\virtuoso
  * Copy the Demo database and default demo.ini file to it

    cd c:
    cd \dbs\virtuoso
    copy <Virtuoso Open Source dir>\binsrc\samples\demo\demo.db
    copy <Virtuoso Open Source dir>\binsrc\samples\demo\demo.ini

  * Register the virt_http.dll in the GAC:

   gacutil /i <Virtuoso Open Source dir>\win32\Release\virt_http.dll

  * Make sure virtclr.dll and virtuoso-clr-t are in the search path
  * To try the tutorial examples the Point.dll and tax.dll from \binsrc\tutorial\hosting\ho_s_2 directory must be copied in \win32\Release directory.

    SET PATH=<Virtuoso Open Source dir>\win32\Release
    virtuoso-clr-t -c demo -I Demo -S create
    virtuoso-clr-t -c demo -I Demo -S start

IMPORTANT: The current version of the .NET CLR hosting server is supported in .NET Framework v1.1 environment

# Java Hosting Server

In order to run the Java hosting server (virtuoso-javavm-t):

  * Make a folder e.g. c:\dbs\virtuoso
  * Copy the Demo database and default demo.ini file to it

    cd c:
    cd \dbs\virtuoso
    copy <Virtuoso Open Source dir>\binsrc\samples\demo\demo.db
    copy <Virtuoso Open Source dir>\binsrc\samples\demo\demo.ini

  * Set the CLASSPATH to the place where Java classes are.
  * Make sure virtuoso-javavm-t is in the search path


    set CLASSPATH=<Virtuoso Open Source dir>\binsrc\tutorial\hosting\ho_s_1;%CLASSPATH%
    SET PATH=<Virtuoso Open Source dir>\win32\Release
    virtuoso-javavm-t -c demo -I Demo -S create
    virtuoso-javavm-t -c demo -I Demo -S start


