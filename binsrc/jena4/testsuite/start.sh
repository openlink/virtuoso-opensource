#!/bin/sh
#
#  $Id$
#
#  Jena tests
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2024 OpenLink Software
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

export TSUITE_CLASSPATH=".:../lib/junit-4.13.2.jar:../lib/jena-arq-4.3.1.jar:../lib/jena-iri-4.3.1.jar:../lib/jena-core-4.3.1.jar:../lib/jena-core-4.3.1-tests.jar:../lib/jena-base-4.3.1.jar:../../../libsrc/JDBCDriverType4/virtjdbc4.jar:../virt_jena4.jar:../lib/jena-shaded-guava-4.3.1.jar:../lib/commons-lang3-3.12.0.jar:../lib/commons-compress-1.21.jar:../lib/libthrift-0.15.0.jar:../lib/collection-0.7.jar:../lib/commons-cli-1.5.jar:../lib/commons-codec-1.15.jar:../lib/commons-csv-1.9.jar:../lib/commons-io-2.11.jar:../lib/jena-rdfconnection-4.3.1.jar:../lib/jena-tdb-4.3.1.jar:../lib/jsonld-java-0.13.3.jar:../lib/jackson-annotations-2.13.0.jar:../lib/jackson-core-2.13.0.jar:../lib/jackson-databind-2.13.0.jar:../lib/httpclient-4.5.13.jar:../lib/httpclient-cache-4.5.13.jar:../lib/httpcore-4.4.13.jar:../lib/jena-cmds-4.3.1.jar:../lib/jcl-over-slf4j-1.7.32.jar:../lib/log4j-api-2.17.0.jar:../lib/log4j-core-2.17.0.jar:../lib/log4j-slf4j-impl-2.17.0.jar:../lib/slf4j-api-1.7.32.jar"


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
