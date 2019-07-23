#!/bin/sh
#
#  $Id$
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

isql 1376 dba dba exec=shutdown
rm wikiv.db wikiv.lck wikiv.log wikiv.trx wikiv.tdb wikiv.ttx core.*
rm -rf http_recording
virtuoso -w
cat wikiv.log | grep 'Server online at'
isql 1376 dba dba setup.isql > setup.isql.log 2>&1
mkdir http_recording
mkdir test_dump
isql 1376 dba dba test.sql > test.sql.log 2>&1
