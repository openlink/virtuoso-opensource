--  
--  $Id: tdav1.sql,v 1.7.10.1 2013/01/02 16:15:02 source Exp $
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
--  
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--  
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--  
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--  
--  
status ();

create procedure uc_lck ()
{
  declare rc, rc1 integer;
  declare l any;
  l := null;
  rc := c_lck ('http://$U{HOST}/DAV/TDAV1/TRESL.TXT', l);
  if (rc = 0)
     rc1 := c_ulck ('http://$U{HOST}/DAV/TDAV1/TRESL.TXT', l);
  result_names (rc);
  result (rc);
  end_result ();
}

uc_lck ();

ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED" "***FAILED";
ECHO BOTH ": LOCK METHOD TEST (PURGE EXPIRED LOCKS) : RETURN CODE=" $LAST[1] "\n";

select sum (atoi (blob_to_string (RES_CONTENT))) from WS.WS.SYS_DAV_RES where RES_FULL_PATH like '/DAV/TDAV_/%';
ECHO BOTH $IF $EQU $LAST[1] 256  "PASSED" "***FAILED";
ECHO BOTH ": SINGLE RESOURCES CONCURRENCY TEST (lock/get/put/unlock) : UPDATES=" $LAST[1] "\n";

select count (*), sum (atoi (blob_to_string (RES_CONTENT))) from WS.WS.SYS_DAV_RES where
  RES_FULL_PATH like '/DAV/TIDAV/TIRES%';
--ECHO BOTH $IF $NEQ $LAST[1] 256 "***FAILED" $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
--ECHO BOTH ": SINGLE RESOURCES CONCURRENCY TEST inserts (lock/get/put/unlock) : resources =" $LAST[1] " updates =" $LAST[2] "\n";

--select sum (atoi (blob_to_string (RES_CONTENT))) from WS.WS.SYS_DAV_RES where RES_FULL_PATH like '/DAV/TDAV%/%' and RES_FULL_PATH not like '/DAV/TDAV1/%';
--ECHO BOTH $IF $EQU $LAST[1] 128 "PASSED" "***FAILED";
--ECHO BOTH ": MULTIPLE SELECTION CONCURRENCY TEST (lock/get/put/unlock) : UPDATES=" $LAST[1] "\n";

--select count (*) from DAV_HITS;
--ECHO BOTH $IF $EQU $LAST[1] 128 "PASSED" "***FAILED";
--ECHO BOTH ": CLIENTS HITS (lock/get/put/unlock) : HITS=" $LAST[1] "\n";

select count(*) from WS.WS.SYS_DAV_LOCK;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": REMAINING LOCKS (lock/get/put/unlock) : LOCK COUNT=" $LAST[1] "\n";

create procedure id_tst ()
{
  declare a, b integer;
  select count(distinct (RES_ID)) into a from WS.WS.SYS_DAV_RES;
  select count(*) into b from WS.WS.SYS_DAV_RES;
  if (a <> b)
    signal ('DAV05', sprintf ('The number of resources is different of distinct IDs unique (%d) all (%d)', a, b));
}

id_tst ();
--c_mkcol ('http://$U{HOST}/DAV/TDAV1/');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": UNIQUE IDs TEST : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

