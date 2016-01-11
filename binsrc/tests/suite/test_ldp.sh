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
# 

DSN=$PORT
. ./test_fn.sh

#PARAMETERS FOR TEST
USERS=6
nreq=100
CLICKS=1000
THOST=localhost
TPORT=$HTTPPORT
HTTPPORT1=`expr $HTTPPORT + 1`
HTTPPORT2=`expr $HTTPPORT + 2`

LOGFILE=`pwd`/tldp.output
export LOGFILE
. ./test_fn.sh

HTTPPORT=8990

BANNER "STARTED SERIES OF LDP TESTS"
ECHO "LDP Server test $HTTPPORT"

curl --verbose -iX PUT --data-binary @ldp/a.ttl -u dav:dav -H 'Content-Type: text/turtle' http://localhost:$HTTPPORT/DAV/test1.ttl > ldp/ldp0.log

curl --verbose -iH "Accept: text/turtle, */*;q=0.1" -u dav:dav http://localhost:$HTTPPORT/DAV/test1.ttl > ldp/ldp1.log
if grep 'HTTP/1.1 200 OK' ldp/ldp1.log > /dev/null ; then
  LOG 'PASSED: Status-Code = 2xx'
else
  LOG '***FAILED: Status-Code = 2xx'
fi
if grep 'ETag:' ldp/ldp1.log > /dev/null ; then
  LOG 'PASSED: ETag exists'
else
  LOG '***FAILED: ETag exists'
fi
if grep 'Link: <http://www.w3.org/ns/ldp#Resource>;' ldp/ldp1.log > /dev/null ; then
  LOG 'PASSED: Link includes ldp:Resource; rel="type"'
else
  LOG '***FAILED: Link includes ldp:Resource; rel="type"'
fi

curl --verbose -I -H "Accept: text/turtle, */*;q=0.1" -u dav:dav http://localhost:$HTTPPORT/DAV/test1.ttl > ldp/ldp2.log
if grep 'HTTP/1.1 200 OK' ldp/ldp2.log > /dev/null ; then
  LOG 'PASSED: Status-Code = 2xx'
else
  LOG '***FAILED: Status-Code = 2xx'
fi
if grep 'ETag:' ldp/ldp2.log > /dev/null ; then
  LOG 'PASSED: ETag exists'
else
  LOG '***FAILED: ETag exists'
fi
if grep 'Link: <http://www.w3.org/ns/ldp#Resource>;' ldp/ldp2.log > /dev/null ; then
  LOG 'PASSED: Link includes ldp:Resource; rel="type"'
else
  LOG '***FAILED: Link includes ldp:Resource; rel="type"'
fi

curl --verbose -iX OPTIONS -H "Accept: text/turtle, */*;q=0.1" -u dav:dav http://localhost:$HTTPPORT/DAV/test1.ttl > ldp/ldp3.log
if grep 'HTTP/1.1 200 OK' ldp/ldp3.log > /dev/null ; then
  LOG 'PASSED: Status-Code = 2xx'
else
  LOG '***FAILED: Status-Code = 2xx'
fi
if grep 'ETag:' ldp/ldp3.log > /dev/null ; then
  LOG 'PASSED: ETag exists'
else
  LOG '***FAILED: ETag exists'
fi
if grep 'Link: <http://www.w3.org/ns/ldp#Resource>;' ldp/ldp3.log > /dev/null ; then
  LOG 'PASSED: Link includes ldp:Resource; rel="type"'
else
  LOG '***FAILED: Link includes ldp:Resource; rel="type"'
fi
if grep 'Allow:' ldp/ldp3.log > /dev/null ; then
  LOG 'PASSED: Allow exists'
else
  LOG '***FAILED: Allow exists'
fi

curl -iX DELETE -H "Accept: text/turtle, */*;q=0.1" -u dav:dav http://localhost:$HTTPPORT/DAV/test1.ttl

curl --verbose -iH "Accept: text/turtle, */*;q=0.1" -u dav:dav http://localhost:$HTTPPORT/DAV/ > ldp/ldp4.log
if grep 'HTTP/1.1 200 OK' ldp/ldp4.log > /dev/null ; then
  LOG 'PASSED: Status-Code = 2xx'
else
  LOG '***FAILED: Status-Code = 2xx'
fi
if grep 'ETag:' ldp/ldp4.log > /dev/null ; then
  LOG 'PASSED: ETag exists'
else
  LOG '***FAILED: ETag exists'
fi
if grep 'Link: <http://www.w3.org/ns/ldp#Resource>;' ldp/ldp4.log > /dev/null ; then
  LOG 'PASSED: Link includes ldp:Resource; rel="type"'
else
  LOG '***FAILED: Link includes ldp:Resource; rel="type"'
fi
if grep 'Link: <http://www.w3.org/ns/ldp#BasicContainer>;' ldp/ldp4.log > /dev/null ; then
  LOG 'PASSED: Link includes ldp:BasicContainer;rel="type"'
else
  LOG '***FAILED: Link includes ldp:BasicContainer;rel="type"'
fi
if grep 'ldp:contains' ldp/ldp4.log > /dev/null ; then
  LOG 'PASSED: contain <LDP-BC URI> ldp:contains <?x>'
else
  LOG '***FAILED: does not contain <LDP-BC URI> ldp:contains <?x>'

fi

curl --verbose -iX PUT --data-binary @ldp/a.ttl -u dav:dav -H 'Content-Type: text/turtle' http://localhost:$HTTPPORT/DAV/test1.ttl > ldp/ldp0.log

curl --verbose -iH "Accept: text/turtle, */*;q=0.1" -u dav:dav http://localhost:$HTTPPORT/DAV/ > ldp/ldp5.log
if grep 'HTTP/1.1 200 OK' ldp/ldp5.log > /dev/null ; then
  LOG 'PASSED: Status-Code = 2xx'
else
  LOG '***FAILED: Status-Code = 2xx'
fi
if grep 'ETag:' ldp/ldp5.log > /dev/null ; then
  LOG 'PASSED: ETag exists'
else
  LOG '***FAILED: ETag exists'
fi
if grep 'Link: <http://www.w3.org/ns/ldp#Resource>;' ldp/ldp5.log > /dev/null ; then
  LOG 'PASSED: Link includes ldp:Resource; rel="type"'
else
  LOG '***FAILED: Link includes ldp:Resource; rel="type"'
fi
if grep 'Link: <http://www.w3.org/ns/ldp#BasicContainer>;' ldp/ldp5.log > /dev/null ; then
  LOG 'PASSED: Link includes ldp:BasicContainer;rel="type"'
else
  LOG '***FAILED: Link includes ldp:BasicContainer;rel="type"'
fi
if grep 'ldp:contains' ldp/ldp5.log > /dev/null ; then
  LOG 'PASSED: contains <LDP-BC URI> ldp:contains <C URI>'
else
  LOG '***FAILED: contains <LDP-BC URI> ldp:contains <C URI>'
fi

CHECK_LOG
BANNER "COMPLETED SERIES OF LDP TESTS"
