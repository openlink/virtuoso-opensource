#!/bin/sh
#
#  $Id: release.sh,v 1.1.2.3 2013/01/02 16:14:52 source Exp $
#
#  Call all tests in succession
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2019 OpenLink Software
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

#
#  Read the standard functions
#
LOGFILE=release.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

#
#  Clean up the mess from the last run
#
CURRENT_VIRTUOSO_CAPACITY="single"
CURRENT_VIRTUOSO_TABLE_SCHEME="row"
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

ECHO "generating release ident (release.sh)"

#  Start the server once:
CHECK_IF_SERVER_STARTABLE

#  Make sure that the log file (wi.trx) and the database file (wi.db) are deletable in Windows NT
CHECK_IF_DB_FILES_DELETABLE

#  Start the server again
#CHECK_IF_SERVER_STARTABLE
#CHECK_LOG

ECHO "generating release ident done."
