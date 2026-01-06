#!/bin/sh
#
#  $Id$
#
#  Jena tests
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

export CLASSPATH=.:../../../libsrc/JDBCDriverType4/virtjdbc4_2.jar:../virt_jena5.jar:../lib/jena-arq-5.3.0.jar:../lib/jena-iri-5.3.0.jar:../lib/jena-core-5.3.0.jar:../lib/jena-core-5.3.0-tests.jar:../lib/jena-base-5.3.0.jar:../lib/commons-lang3-3.17.0.jar:../lib/commons-compress-1.27.1.jar:../lib/libthrift-0.21.0.jar:../lib/collection-0.7.jar:../lib/commons-cli-1.9.0.jar:../lib/commons-codec-1.17.2.jar:../lib/commons-csv-1.13.0.jar:../lib/commons-io-2.18.0.jar:../lib/jena-rdfconnection-5.3.0.jar:../lib/jena-tdb1-5.3.0.jar:../lib/jena-tdb2-5.3.0.jar:../lib/gson-2.11.0.jar:../lib/caffeine-3.1.8.jar:../lib/commons-collections4-4.4.jar:../lib/error_prone_annotations-2.27.0.jar:../lib/jakarta.json-2.0.1.jar:../lib/jcl-over-slf4j-2.0.16.jar:../lib/jena-cmds-5.3.0.jar:../lib/jena-dboe-base-5.3.0.jar:../lib/jena-dboe-index-5.3.0.jar:../lib/jena-dboe-storage-5.3.0.jar:../lib/jena-dboe-trans-data-5.3.0.jar:../lib/jena-dboe-transaction-5.3.0.jar:../lib/jena-iri3986-5.3.0.jar:../lib/jena-ontapi-5.3.0.jar:../lib/jena-rdfpatch-5.3.0.jar:../lib/jena-shacl-5.3.0.jar:../lib/jena-shex-5.3.0.jar:../lib/log4j-api-2.24.3.jar:../lib/log4j-core-2.24.3.jar:../lib/log4j-slf4j2-impl-2.24.3.jar:../lib/protobuf-java-4.29.3.jar:../lib/RoaringBitmap-1.3.0.jar:../lib/slf4j-api-2.0.16.jar:../lib/titanium-json-ld-1.4.1.jar:../lib/junit-4.13.2.jar

#
#  Build the testsuite
#
$JAVAC VirtuosoTestGraph.java

#
#  Database should be running at this point
#
STATUS=0
$JAVA -Durl="jdbc:virtuoso://localhost:$PORT" junit.textui.TestRunner VirtuosoTestGraph
STATUS=$?

if test $STATUS -ne 0
then
    echo "***FAILED: VirtuosoTestGraph with Jena provider failed some tests"
    exit 1
else
    echo "PASSED: VirtuosoTestGraph with Jena provider"
fi

exit 0
