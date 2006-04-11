The current directroy is assumed to be '.' i.e '<Some Path>/ImgGen/ImgFiles'
To Compile the programs - The following things must be done/validated

The Sources have C++ style comments and hence the CFLAG 'Allow C++ style
comments in C file' must be turned on.

The Directory gd-1.7.2 must be present in the parent directory
of this directory

The file cjpeg.c must be checked for proper existence of the following
include paths:
../gd-1.7.2/gd.h
../gd-1.7.2/gdfontg.h

The only other file needed from ../gd-1.7.2/ is gdfontg.c

The file jconfig.h must be edited to suite the needs of the target platform

The Makefile must be edited for proper CFLAGS and libraries. The linker
needs the Math-Library

Running make should generate the executable tpcwIMG in the current directory

Pl. Note:
The Directory './RestFiles' have files that were originally in the package
obtained from the TPCW web site but are not used in the binary tpcwIMG

Files added/removed/changed to the original package obtained from TPCW web site.

Added   : Makefile
Added   : ../gd-1.7.2 (Freeware Package)
Added   : ../README
Added   : README.COMPILE
Changed : jconfig.h - for proper #define for Solaris (Platform Specific Changes)
Changed : cjpeg.h   - Path Seperator (from '\' to '/')
Changed : All Files - Got Rid of '^M' from end of each line
Removed : Moved unwanted files into 'RestFiles'
