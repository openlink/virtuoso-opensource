#!/bin/sh
#
#  $Id$
#
#  Security tests
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2012 OpenLink Software
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


LOGFILE=tsec.output
export LOGFILE
. ./test_fn.sh


BANNER "STARTED SECURITY TEST (tsec.sh)"

SHUTDOWN_SERVER
rm -f $DBLOGFILE
rm -f $DBFILE
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
START_SERVER $PORT 1000

RUN $INS $DSN 20 100
# note that the test script filename has to be given as the fourth
# argument for isql (file to be loaded) so that $ARGV[4] in
# "STARTED: " and "COMPLETED: " headings will show the correct filename.

RUN $ISQL $DSN dba dba tsecini.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***ABORTED: tsecini.sql -- Initialization"
  exit 1
fi
RUN $ISQL $DSN 'U1RUS' 'Абракадабра2' '"EXEC=ECHO BOTH 'Logging in as U1RUS with UTF-8 password set as wide before';"' PROMPT=OFF ERRORS=STDOUT 2> /dev/null
if test $STATUS -eq 0
then
  LOG "PASSED: Lets U1RUS in with an UTF-8 password"
else
  LOG "***FAILED: Does not let U1RUS in with an UTF-8 password"
  exit 1
fi
RUN $ISQL $DSN 'U1RUS' 'Абракадабра1' '"EXEC=ECHO BOTH 'Trying to get in as U1RUS with the wrong password';"' PROMPT=OFF ERRORS=STDOUT 2> /dev/null
if test $STATUS -eq 0
then
  LOG "***ABORTED: Lets the U1RUS in with a wrong password"
  exit 1
else
  LOG "PASSED: Does not let U1RUS in with a wrong password"
fi
RUN $ISQL $DSN U1 U1 tsecu1-1.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***ABORTED: tsecu1-1.sql -- Privileges of user u1, part 1"
  exit 1
fi

RUN $ISQL $DSN U1 U1PASS tsecu1-2.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***ABORTED: tsecu1-2.sql -- Privileges of user u1, part 2"
  exit 1
fi

RUN $ISQL $DSN U3 U3 tsecu3-1.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***ABORTED: tsecu3-1.sql -- Privileges of user u3, part 1"
  exit 1
fi


RUN $ISQL $DSN dba dba tsecini-1.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***ABORTED: tsecini-1.sql -- Privileges of user u3, part 1"
  exit 1
fi


RUN $ISQL $DSN U5 U5 tsecu5-1.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***ABORTED: tsecu5-1.sql -- Changing and Revoking User Privileges"
  exit 1
fi

RUN $ISQL $DSN U3 U3 tsecu3-2.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***ABORTED: tsecu3-2.sql -- Privileges of user u3, part 2"
  exit 1
fi

RUN $ISQL $DSN dba dba tmulgrp.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***ABORTED: tmulgrp.sql -- secondary group tests"
  exit 1
fi

RUN $ISQL $DSN dba dba tsecend.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***ABORTED: tsecend.sql -- Ending and Cleanup"
  exit 1
fi

RUN $ISQL $DSN dba wrongpwd '"EXEC=ECHO BOTH 'Trying to get in as DBA with the wrong password';"' PROMPT=OFF ERRORS=STDOUT 2> /dev/null
if test $STATUS -eq 0
then
  LOG "***ABORTED: Lets the dba in with a wrong password"
  exit 1
else
  LOG "PASSED: Does not let dba in with a wrong password"
fi

RUN $ISQL $DSN dba dba tsec_proc.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***ABORTED: tsec_proc.sql -- Procedures security tests"
  exit 1
fi

RUN $ISQL $DSN dba dba tsec_role.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***ABORTED: tsec_role.sql -- Security role tests"
  exit 1
fi

RUN $ISQL $DSN dba dba rls_create.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***ABORTED: rls_create.sql -- Row level security tests"
  exit 1
fi

RUN $ISQL $DSN dba dba rls.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***ABORTED: rls.sql -- Row level security tests"
  exit 1
fi


SHUTDOWN_SERVER
START_SERVER $PORT 1000

#BUGZILLA 6057

RUN $ISQL $DSN R W error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login R W"
else
  LOG "PASSED: valid login R W"
fi

RUN $ISQL $DSN R W1 error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "PASSED: invalid login R W1"
else
  LOG "***FAILED: valid login R W"
fi

RUN $ISQL $DSN O O error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login O O"
else
  LOG "PASSED: valid login O O"
fi

RUN $ISQL $DSN PI PI error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login PI PI"
else
  LOG "PASSED: valid login PI PI"
fi

RUN $ISQL $DSN BI DO error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login BI DO"
else
  LOG "PASSED: valid login BI DO"
fi

RUN $ISQL $DSN UFO UFO error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login UFO UFO"
else
  LOG "PASSED: valid login UFO UFO"
fi

RUN $ISQL $DSN MAN LEN error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login MAN LEN"
else
  LOG "PASSED: valid login MAN LEN"
fi

RUN $ISQL $DSN ZORO ZORO error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login ZORO ZORO"
else
  LOG "PASSED: valid login ZORO ZORO"
fi

RUN $ISQL $DSN ZIPO LIGHT error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login ZIPO LIGHT"
else
  LOG "PASSED: valid login ZIPO LIGHT"
fi

RUN $ISQL $DSN ZAFIR ZAFIR error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login ZAFIR ZAFIR"
else
  LOG "PASSED: valid login ZAFIR ZAFIR"
fi

RUN $ISQL $DSN TUNAR SONAR error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login TUNAR SONAR"
else
  LOG "PASSED: valid login TUNAR SONAR"
fi

RUN $ISQL $DSN ZUMOSO ZUMOSO error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login ZUMOSO ZUMOSO"
else
  LOG "PASSED: valid login ZUMOSO ZUMOSO"
fi

RUN $ISQL $DSN ZURANA VINOTE error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login ZURANA VINOTE"
else
  LOG "PASSED: valid login ZURANA VINOTE"
fi

RUN $ISQL $DSN ABALLAR ABALLAR error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login ABALLAR ABALLAR"
else
  LOG "PASSED: valid login ABALLAR ABALLAR"
fi

RUN $ISQL $DSN ACHICAR ANIMOSO error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login ACHICAR ANIMOSO"
else
  LOG "PASSED: valid login ACHICAR ANIMOSO"
fi

RUN $ISQL $DSN SCCTRIAL SCCTRIAL error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login SCCTRIAL SCCTRIAL"
else
  LOG "PASSED: valid login SCCTRIAL SCCTRIAL"
fi

RUN $ISQL $DSN ACERILLO AMARIZAR error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login ACERILLO AMARIZAR"
else
  LOG "PASSED: valid login ACERILLO AMARIZAR"
fi

RUN $ISQL $DSN ABATIDERO ABATIDERO error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login ABATIDERO ABATIDERO"
else
  LOG "PASSED: valid login ABATIDERO ABATIDERO"
fi

RUN $ISQL $DSN AMELONADA AMESNADOR error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login AMELONADA AMESNADOR"
else
  LOG "PASSED: valid login AMELONADA AMESNADOR"
fi

RUN $ISQL $DSN ANTORCHERO ANTORCHERO error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login ANTORCHERO ANTORCHERO"
else
  LOG "PASSED: valid login ANTORCHERO ANTORCHERO"
fi

RUN $ISQL $DSN ABANDERADO ABALUARTAR error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login ABANDERADO ABALUARTAR"
else
  LOG "PASSED: valid login ABANDERADO ABALUARTAR"
fi

RUN $ISQL $DSN BARBIRRUCIO BARBIRRUCIO error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login BARBIRRUCIO BARBIRRUCIO"
else
  LOG "PASSED: valid login BARBIRRUCIO BARBIRRUCIO"
fi

RUN $ISQL $DSN BARBIBLANCA ABAJAMIENTO error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login BARBIBLANCA ABAJAMIENTO"
else
  LOG "PASSED: valid login BARBIBLANCA ABAJAMIENTO"
fi

RUN $ISQL $DSN ACABDILLADOR ACABDILLADOR error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login ACABDILLADOR ACABDILLADOR"
else
  LOG "PASSED: valid login ACABDILLADOR ACABDILLADOR"
fi

RUN $ISQL $DSN VIVIFICATIVO ZOROASTRISMO error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login VIVIFICATIVO ZOROASTRISMO"
else
  LOG "PASSED: valid login VIVIFICATIVO ZOROASTRISMO"
fi

RUN $ISQL $DSN VICEALMIRANTE VICEALMIRANTE error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login VICEALMIRANTE VICEALMIRANTE"
else
  LOG "PASSED: valid login VICEALMIRANTE VICEALMIRANTE"
fi

RUN $ISQL $DSN TRANSFORMANTE SIGNIFICATIVO error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login TRANSFORMANTE SIGNIFICATIVO"
else
  LOG "PASSED: valid login TRANSFORMANTE SIGNIFICATIVO"
fi

RUN $ISQL $DSN ZARZAPARRILLAR ZARZAPARRILLAR error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login ZARZAPARRILLAR ZARZAPARRILLAR"
else
  LOG "PASSED: valid login ZARZAPARRILLAR ZARZAPARRILLAR"
fi

RUN $ISQL $DSN SOBREALIMENTAR RAQUIANESTESIA error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login SOBREALIMENTAR RAQUIANESTESIA"
else
  LOG "PASSED: valid login SOBREALIMENTAR RAQUIANESTESIA"
fi

RUN $ISQL $DSN VICTORIOSAMENTE VICTORIOSAMENTE error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login VICTORIOSAMENTE VICTORIOSAMENTE"
else
  LOG "PASSED: valid login VICTORIOSAMENTE VICTORIOSAMENTE"
fi

RUN $ISQL $DSN TRANSUBSTANCIAR SONAR error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login TRANSUBSTANCIAR SONAR"
else
  LOG "PASSED: valid login TRANSUBSTANCIAR SONAR"
fi

RUN $ISQL $DSN RESTRICTIVAMENTE RESTRICTIVAMENTE error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login RESTRICTIVAMENTE RESTRICTIVAMENTE"
else
  LOG "PASSED: valid login RESTRICTIVAMENTE RESTRICTIVAMENTE"
fi

RUN $ISQL $DSN PERCEPTIBLEMENTE PLENIPOTENCIARIA error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login PERCEPTIBLEMENTE PLENIPOTENCIARIA"
else
  LOG "PASSED: valid login PERCEPTIBLEMENTE PLENIPOTENCIARIA"
fi

RUN $ISQL $DSN FIBROCARTILAGINOSO FIBROCARTILAGINOSO error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login FIBROCARTILAGINOSO FIBROCARTILAGINOSO"
else
  LOG "PASSED: valid login FIBROCARTILAGINOSO FIBROCARTILAGINOSO"
fi

RUN $ISQL $DSN DESVERGONZADAMENTE ABANDERADO error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login DESVERGONZADAMENTE ABANDERADO"
else
  LOG "PASSED: valid login DESVERGONZADAMENTE ABANDERADO"
fi

RUN $ISQL $DSN CIRCUNFERENCIALMENTE CIRCUNFERENCIALMENTE error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login CIRCUNFERENCIALMENTE CIRCUNFERENCIALMENTE"
else
  LOG "PASSED: valid login CIRCUNFERENCIALMENTE CIRCUNFERENCIALMENTE"
fi

RUN $ISQL $DSN DESENVERGONZADAMENTE REGLAMENTARIAMENTE error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login DESENVERGONZADAMENTE REGLAMENTARIAMENTE"
else
  LOG "PASSED: valid login DESENVERGONZADAMENTE REGLAMENTARIAMENTE"
fi

RUN $ISQL $DSN BIENINTENCIONADAMENTE BIENINTENCIONADAMENTE error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login BIENINTENCIONADAMENTE BIENINTENCIONADAMENTE"
else
  LOG "PASSED: valid login BIENINTENCIONADAMENTE BIENINTENCIONADAMENTE"
fi

RUN $ISQL $DSN DESPROPORCIONADAMENTE REGLAMENTARIAMENTE error.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***FAILED: valid login DESPROPORCIONADAMENTE REGLAMENTARIAMENTE"
else
  LOG "PASSED: valid login DESPROPORCIONADAMENTE REGLAMENTARIAMENTE"
fi

RUN $ISQL $DSN dba dba tcred.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  LOG "***ABORTED: tcred.sql -- __set_user_id tests"
  exit 1
fi

#The following test should be the last before the shutdown, to prevent side effects on tests that may use SPARQL.
if test -f ../wb/SparqlSec.sql
then
  cat ../wb/SparqlSec.sql | grep -v "set echo on;" > ../wb/SparqlSec_noecho.sql
  RUN $ISQL $DSN dba dba ../wb/SparqlSec_noecho.sql PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
  if test $STATUS -ne 0
  then
    LOG "***ABORTED: ../wb/SparqlSec.sql Sparql graph level security tests"
    exit 1
  fi
fi


SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED SECURITY TESTS (tsec.sh)"

