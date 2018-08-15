#!/bin/sh
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2018 OpenLink Software
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

if test ! -f mono-1.1.7.tar.gz
then
    wget http://www.go-mono.com/sources/mono-1.1/mono-1.1.7.tar.gz
fi

if test ! -d mono-1.1.7
then
    gzip -c -d mono-1.1.7.tar.gz | tar xf -
    patch -p0 -i mono-1.1.7.diff 
fi

echo "Mono install dir $TOP/mono"

if test ! -f mono-1.1.7/Makefile
then
    cd $TOP/binsrc/mono/mono-1.1.7 && ./configure --prefix=$TOP/mono
    cd $TOP/binsrc/mono
fi

if test ! -f mono-1.1.7/mono/mini/.libs/libmono.a
then
    unset SUBDIRS
    cd $TOP/binsrc/mono/mono-1.1.7 && { make; }
    cd $TOP/binsrc/mono
fi

if test ! -f $TOP/mono/lib/libmono.a 
then
    unset SUBDIRS
    cd $TOP/binsrc/mono/mono-1.1.7 && make install 
    cp mono/metadata/tabledefs.h $TOP/mono/include/mono/metadata/
fi

