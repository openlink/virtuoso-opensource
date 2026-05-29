#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2026 OpenLink Software
#
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#
#


if WITH_ZLIB
noinst_LTLIBRARIES = libz.la
endif

noinst_HEADERS = \
	crc32.h \
	deflate.h \
	gzguts.h \
	inffast.h \
	inffixed.h \
	inflate.h \
	inftrees.h \
	trees.h \
	zconf.h \
	zlib.h \
	zutil.h

libz_la_SOURCES = \
	adler32.c \
	compress.c \
	crc32.c \
	deflate.c \
	gzclose.c \
	gzlib.c \
	gzread.c \
        gzwrite.c \
	infback.c \
	inffast.c \
	inflate.c \
	inftrees.c \
	trees.c \
	uncompr.c \
        zutil.c

libz_la_CFLAGS  = @VIRT_AM_CFLAGS@
libz_la_CFLAGS  += -I$(top_srcdir)/libsrc
libz_la_CFLAGS  += -I$(top_srcdir)/libsrc/Dk
libz_la_LDFLAGS = -prefer-pic


# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	$(srcdir)/*.c \
	$(srcdir)/*.h \
	$(srcdir)/*.txt \
	$(srcdir)/*.xml \
	$(srcdir)/.gitignore \
	$(srcdir)/amiga/Makefile.pup \
	$(srcdir)/amiga/Makefile.sas \
	$(srcdir)/ChangeLog \
	$(srcdir)/configure \
	$(srcdir)/contrib/*.txt \
	$(srcdir)/contrib/ada/*.txt \
	$(srcdir)/contrib/ada/buffer_demo.adb \
	$(srcdir)/contrib/ada/cmake/binder_helper.cmake \
	$(srcdir)/contrib/ada/cmake/compile_helper.cmake \
	$(srcdir)/contrib/ada/cmake/exe_link_helper.cmake \
	$(srcdir)/contrib/ada/cmake/Modules/CMakeADACompiler.cmake.in \
	$(srcdir)/contrib/ada/cmake/Modules/CMakeADAInformation.cmake \
	$(srcdir)/contrib/ada/cmake/Modules/CMakeDetermineADACompiler.cmake \
	$(srcdir)/contrib/ada/cmake/Modules/CMakeTestADACompiler.cmake \
	$(srcdir)/contrib/ada/cmake/shared_link_helper.cmake \
	$(srcdir)/contrib/ada/cmake/static_link_helper.cmake \
	$(srcdir)/contrib/ada/mtest.adb \
	$(srcdir)/contrib/ada/read.adb \
	$(srcdir)/contrib/ada/test.adb \
	$(srcdir)/contrib/ada/zlib-streams.adb \
	$(srcdir)/contrib/ada/zlib-streams.ads \
	$(srcdir)/contrib/ada/zlib-thin.adb \
	$(srcdir)/contrib/ada/zlib-thin.ads \
	$(srcdir)/contrib/ada/zlib.adb \
	$(srcdir)/contrib/ada/zlib.ads \
	$(srcdir)/contrib/ada/zlib.gpr \
	$(srcdir)/contrib/blast/*.c \
	$(srcdir)/contrib/blast/*.h \
	$(srcdir)/contrib/blast/*.txt \
	$(srcdir)/contrib/blast/blastConfig.cmake.in \
	$(srcdir)/contrib/blast/Makefile \
	$(srcdir)/contrib/blast/README \
	$(srcdir)/contrib/blast/test.pk \
	$(srcdir)/contrib/blast/test/*.txt \
	$(srcdir)/contrib/blast/test/add_subdirectory_exclude_test.cmake.in \
	$(srcdir)/contrib/blast/test/add_subdirectory_test.cmake.in \
	$(srcdir)/contrib/blast/test/find_package_no_components_test.cmake.in \
	$(srcdir)/contrib/blast/test/find_package_test.cmake.in \
	$(srcdir)/contrib/blast/test/find_package_wrong_components_test.cmake.in \
	$(srcdir)/contrib/blast/tester.cmake \
	$(srcdir)/contrib/crc32vx/*.c \
	$(srcdir)/contrib/crc32vx/*.h \
	$(srcdir)/contrib/crc32vx/*.txt \
	$(srcdir)/contrib/crc32vx/README \
	$(srcdir)/contrib/delphi/*.txt \
	$(srcdir)/contrib/delphi/ZLib.pas \
	$(srcdir)/contrib/delphi/ZLibConst.pas \
	$(srcdir)/contrib/delphi/zlibd32.mak \
	$(srcdir)/contrib/dotzlib/*.txt \
	$(srcdir)/contrib/dotzlib/DotZLib.build \
	$(srcdir)/contrib/dotzlib/DotZLib.chm \
	$(srcdir)/contrib/dotzlib/DotZLib.sln \
	$(srcdir)/contrib/dotzlib/DotZLib/*.cs \
	$(srcdir)/contrib/dotzlib/DotZLib/DotZLib.csproj \
	$(srcdir)/contrib/gcc_gvmat64/*.S \
	$(srcdir)/contrib/gcc_gvmat64/*.txt \
	$(srcdir)/contrib/infback9/*.c \
	$(srcdir)/contrib/infback9/*.h \
	$(srcdir)/contrib/infback9/*.txt \
	$(srcdir)/contrib/infback9/README \
	$(srcdir)/contrib/iostream/*.h \
	$(srcdir)/contrib/iostream/test.cpp \
	$(srcdir)/contrib/iostream/zfstream.cpp \
	$(srcdir)/contrib/iostream2/*.h \
	$(srcdir)/contrib/iostream2/zstream_test.cpp \
	$(srcdir)/contrib/iostream3/*.h \
	$(srcdir)/contrib/iostream3/*.txt \
	$(srcdir)/contrib/iostream3/iostream3Config.cmake.in \
	$(srcdir)/contrib/iostream3/README \
	$(srcdir)/contrib/iostream3/test.cc \
	$(srcdir)/contrib/iostream3/test/*.txt \
	$(srcdir)/contrib/iostream3/test/add_subdirectory_exclude_test.cmake.in \
	$(srcdir)/contrib/iostream3/test/add_subdirectory_test.cmake.in \
	$(srcdir)/contrib/iostream3/test/find_package_no_components_test.cmake.in \
	$(srcdir)/contrib/iostream3/test/find_package_test.cmake.in \
	$(srcdir)/contrib/iostream3/test/find_package_wrong_components_test.cmake.in \
	$(srcdir)/contrib/iostream3/TODO \
	$(srcdir)/contrib/iostream3/zfstream.cc \
	$(srcdir)/contrib/minizip/*.c \
	$(srcdir)/contrib/minizip/*.h \
	$(srcdir)/contrib/minizip/*.txt \
	$(srcdir)/contrib/minizip/configure.ac \
	$(srcdir)/contrib/minizip/LICENSE.Info-Zip \
	$(srcdir)/contrib/minizip/Makefile \
	$(srcdir)/contrib/minizip/Makefile.am \
	$(srcdir)/contrib/minizip/make_vms.com \
	$(srcdir)/contrib/minizip/miniunzip.1 \
	$(srcdir)/contrib/minizip/minizip.1 \
	$(srcdir)/contrib/minizip/minizip.pc.in \
	$(srcdir)/contrib/minizip/minizipConfig.cmake.in \
	$(srcdir)/contrib/minizip/test/*.txt \
	$(srcdir)/contrib/minizip/test/add_subdirectory_exclude_test.cmake.in \
	$(srcdir)/contrib/minizip/test/add_subdirectory_test.cmake.in \
	$(srcdir)/contrib/minizip/test/find_package_no_components_test.cmake.in \
	$(srcdir)/contrib/minizip/test/find_package_test.cmake.in \
	$(srcdir)/contrib/minizip/test/find_package_wrong_components_test.cmake.in \
	$(srcdir)/contrib/minizip/test/test_helper.cm \
	$(srcdir)/contrib/nuget/nuget.csproj \
	$(srcdir)/contrib/nuget/nuget.sln \
	$(srcdir)/contrib/pascal/*.txt \
	$(srcdir)/contrib/pascal/example.pas \
	$(srcdir)/contrib/pascal/zlibd32.mak \
	$(srcdir)/contrib/pascal/zlibpas.pas \
	$(srcdir)/contrib/puff/*.c \
	$(srcdir)/contrib/puff/*.h \
	$(srcdir)/contrib/puff/*.txt \
	$(srcdir)/contrib/puff/Makefile \
	$(srcdir)/contrib/puff/puffConfig.cmake.in \
	$(srcdir)/contrib/puff/README \
	$(srcdir)/contrib/puff/test/*.txt \
	$(srcdir)/contrib/puff/test/add_subdirectory_exclude_test.cmake.in \
	$(srcdir)/contrib/puff/test/add_subdirectory_test.cmake.in \
	$(srcdir)/contrib/puff/test/find_package_no_components_test.cmake.in \
	$(srcdir)/contrib/puff/test/find_package_test.cmake.in \
	$(srcdir)/contrib/puff/test/find_package_wrong_components_test.cmake.in \
	$(srcdir)/contrib/puff/test/tester-cov.cmake \
	$(srcdir)/contrib/puff/test/tester.cmake \
	$(srcdir)/contrib/puff/zeros.raw \
	$(srcdir)/contrib/README.contrib \
	$(srcdir)/contrib/testzlib/*.c \
	$(srcdir)/contrib/testzlib/*.txt \
	$(srcdir)/contrib/vstudio/*.txt \
	$(srcdir)/contrib/zlib1-dll/*.txt \
	$(srcdir)/doc/*.txt \
	$(srcdir)/doc/crc-doc.1.0.pdf \
	$(srcdir)/examples/*.c \
	$(srcdir)/examples/*.h \
	$(srcdir)/examples/*.html \
	$(srcdir)/examples/README.examples \
	$(srcdir)/FAQ \
	$(srcdir)/INDEX \
	$(srcdir)/Makefile.am \
	$(srcdir)/make_vms.com \
	$(srcdir)/msdos/Makefile.bor \
	$(srcdir)/msdos/Makefile.dj2 \
	$(srcdir)/msdos/Makefile.emx \
	$(srcdir)/msdos/Makefile.msc \
	$(srcdir)/msdos/Makefile.tc \
	$(srcdir)/os400/bndsrc \
	$(srcdir)/os400/make.sh \
	$(srcdir)/os400/README400 \
	$(srcdir)/qnx/package.qpg \
	$(srcdir)/README \
	$(srcdir)/test/*.c \
	$(srcdir)/watcom/watcom_f.mak \
	$(srcdir)/watcom/watcom_l.mak \
	$(srcdir)/win32/*.txt \
	$(srcdir)/win32/Makefile.bor \
	$(srcdir)/win32/Makefile.gcc \
	$(srcdir)/win32/Makefile.msc \
	$(srcdir)/win32/zlib.def \
	$(srcdir)/win32/zlib1.rc \
	$(srcdir)/zconf.h.in \
	$(srcdir)/zlib.3 \
	$(srcdir)/zlib.3.pdf \
	$(srcdir)/zlib.map \
	$(srcdir)/zlib.pc.cmakein \
	$(srcdir)/zlib.pc.in
