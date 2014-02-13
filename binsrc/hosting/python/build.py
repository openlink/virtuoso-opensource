#
#  build.py
#
#  $Id$
#
#  Python Makefile for the OpenLink python plugin
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2014 OpenLink Software
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

import os
import sys
import os.path
import string;
import distutils.sysconfig

top_dir='TOPDIRREPLACEME'

if sys.hexversion < 0x020202F0:
    raise "Python version should be at least 2.2.2"

install=None
if (not os.path.exists ('virt_handler.c')):
    infile=file ("virt_handler.py", "r")
    outfile=file ("virt_handler.c", "w")
    outfile.write ("static char *virt_handler = \n")
    _line = "__start"

    while _line != "":
       _line = infile.readline ();
       line=string.rstrip (_line);
       line=string.replace (line, '\\', '\\\\');
       line=string.replace (line, '\"', '\\\"');
       outfile.write ('"' + line + '\\n"\n')
    outfile.write (";\n")

if os.name == 'nt':
        tgt="hosting_python.dll"
	cl='cl -Iinclude /Zi -I' 
	cl=cl + distutils.sysconfig.get_config_var ("INCLUDEPY")
	cl=cl + ' hosting_python.c /link /dll /LIBPATH:'
        cl=cl + distutils.sysconfig.get_config_var ("exec_prefix")
	cl=cl + "/libs /OUT:hosting_python.dll"

elif os.name == 'posix':	
        tgt=top_dir + "/bin/hosting/hosting_python.la"
	cl='libtool --mode=compile cc -Iinclude -g -c '
	cl=cl + '-I' + distutils.sysconfig.get_config_var ("INCLUDEPY")
        cl=cl + ' hosting_python.c -o hosting_python.lo '

	link='libtool --mode=link cc -Iinclude -g '
	link=link + ' -module -export-dynamic -rpath ' + top_dir + "/bin/hosting "
        link=link + ' hosting_python.lo -o hosting_python.la '
        link=link + distutils.sysconfig.get_config_var ("LIBS") + " "
        link=link + distutils.sysconfig.get_config_var ("SYSLIBS") + " "
        link=link + distutils.sysconfig.get_config_var ("LDFLAGS") + " "
        link=link + distutils.sysconfig.get_config_var ("LIBPL") + "/libpython"
	link=link + distutils.sysconfig.get_config_var ("VERSION") + ".a "

	install="libtool --mode=install cp hosting_python.la " + top_dir + "/bin/hosting/hosting_python.la"

else:
	raise "unknown OS"
	exit ()


if (not os.path.exists (tgt)):     
    print cl
    os.system (cl)
    if link != None:
	    print link
	    os.system (link)
    if install != None:
	    print install
	    os.system (install)
