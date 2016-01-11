#!/bin/sh
#
#  $Id$
#
#  Jena tests
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

export TSUITE_CLASSPATH=".:../lib/arq-2.8.1.jar:../lib/commons-logging-1.1.1.jar:../lib/icu4j_3_4.jar:../lib/iri-0.7.jar:../lib/jena-2.6.2.jar:../lib/jena-2.6.2-tests.jar:../lib/junit-4.5.jar:../lib/xercesImpl-2.7.1.jar:../lib/xml-apis.jar:../lib/slf4j-api-1.5.11.jar:../lib/slf4j-simple-1.5.11.jar:../virt_jena.jar:../../../libsrc/JDBCDriverType4/virtjdbc3.jar"


#
#  Database should be running at this point
#
STATUS=0
$JAVA -classpath "$TSUITE_CLASSPATH" -Durl="jdbc:virtuoso://localhost:$PORT" junit.textui.TestRunner VirtuosoTestGraph
STATUS=$?

if test $STATUS -ne 0
then
    echo "***FAILED: VirtuosoTestGraph with Jena provider failed some tests"
    exit 1
else
    echo "PASSED: VirtuosoTestGraph with Jena provider"
fi

exit 0
