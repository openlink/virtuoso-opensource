#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2016 OpenLink Software
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

PORT=1603
HTTPPORT=`expr $PORT + 7000`
TEST_DRIVER='time /usr/java/latest/bin/java -Xmx2048m -cp bin:lib/ssj.jar:lib/log4j-1.2.15.jar:lib/virtjdbc3.jar benchmark.testdriver.TestDriver'

#Plain WS run
#$TEST_DRIVER -runs 128 -w 32 -virtuoso -dg BSBM http://localhost:$HTTPPORT/sparql

#Plain Virtuoso SPARQL/JDBC run
#$TEST_DRIVER -runs 128 -w 32 -dg BSBM -dbconnect -virtuoso -dbdriver virtuoso.jdbc3.Driver -connuser dba -connpwd dba jdbc:virtuoso://localhost:$PORT/UID=dba/PWD=dba

#Plain Virtuoso SQL run
$TEST_DRIVER -runs 128 -w 32 -dg BSBM -dbconnect -sql -virtuoso -qdir SQLqueries -dbdriver virtuoso.jdbc3.Driver -connuser dba -connpwd dba jdbc:virtuoso://localhost:$PORT/UID=dba/PWD=dba
