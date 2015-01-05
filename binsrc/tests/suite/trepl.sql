--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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
ECHO BOTH "STARTED: WebDAV transactional replication test\n"
CONNECT;

SET ARGV[0] 0;
SET ARGV[1] 0;

set DSN=$U{ds1};
RECONNECT;

create procedure DAVcommand (in host varchar, in port integer, in meth varchar, in path varchar, in dst varchar, in sz integer)
{
  declare r any;
  declare b any;
  declare hdr varchar;
  declare body varchar;

  hdr := sprintf ('Authorization: Basic %s', encode_base64 ('dav:dav'));
  if (dst is not null)
    hdr := concat (hdr, sprintf ('\r\nDestination: %s', dst));
  if (sz)
    body := repeat ('x', sz);
  if (not sz)
    b := http_get (sprintf ('http://%s:%d%s', host, port, path), r, meth, hdr);
  else
    b := http_get (sprintf ('http://%s:%d%s', host, port, path), r, meth, hdr, body);
  if (isarray (r) and aref (r, 0) not like 'HTTP/1.1 2__ %')
    signal ('TREPL', aref (r, 0));
  return b;
};

-- cleanup WebDAV repository
delete from WS.WS.SYS_DAV_RES;
--delete from WS.WS.SYS_DAV_COL where COL_ID > 1;
select DAV_DELETE (WS.WS.COL_PATH (COL_ID), 0, 'dav', 'dav') from WS.WS.SYS_DAV_COL where COL_PARENT = 1;

select count(*) from WS.WS.SYS_DAV_RES;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The initial state of WebDAV repository checked : " $LAST[1] " items found\n";
select count(*) from WS.WS.SYS_DAV_COL;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The initial state of WebDAV repository checked : " $LAST[1] " collections found\n";

DAVcommand ('localhost', $U{http1}, 'MKCOL', '/DAV/repl/', NULL, 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Initial collection created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
checkpoint;


-- Publication from first  server 'dav'
DB..REPL_PUBLISH ('dav', 'dav.log');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REPL_PUBLISH : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB..REPL_PUB_ADD ('dav', '/DAV/repl/', 1, 0, null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REPL_PUB_ADD : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Publication from first  server 'dav'
DB..REPL_PUBLISH ('gtpub', 'gtpub.log');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REPL_PUBLISH gtpub : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table GT_TS_ID_PUB;
create table GT_TS_ID_PUB (ID integer identity, TS timestamp, DT varchar, primary key (ID));
insert into DB.DBA.GT_TS_ID_PUB (DT) values ('a');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GT_TS_ID_PUB populated : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB..REPL_PUB_ADD ('gtpub', 'DB.DBA.GT_TS_ID_PUB', 2, 0, null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REPL_PUB_ADD GT_TS_ID_PUB to gtpub: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
checkpoint;

DB..REPL_PUBLISH ('B7113', 'B7113.log');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REPL_PUBLISH B7113 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B7113_FKREPL2;
drop table B7113_FKREPL1;
create table B7113_FKREPL1 (ID integer primary key, TXT varchar);
create table B7113_FKREPL2 (ID integer primary key, FID integer, TXT varchar);
alter table B7113_FKREPL2 add foreign key (FID) references B7113_FKREPL1(ID);

DB..REPL_PUB_ADD ('B7113', 'DB.DBA.B7113_FKREPL1', 2, 0, null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REPL_PUB_ADD B7113_FKREPL1 to B7113 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB..REPL_PUB_ADD ('B7113', 'DB.DBA.B7113_FKREPL2', 2, 0, null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REPL_PUB_ADD B7113_FKREPL2 to B7113 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
checkpoint;

-- Subscription to first 'rep1'
set DSN=$U{ds2};
RECONNECT;
create procedure DAVcommand (in host varchar, in port integer, in meth varchar, in path varchar, in dst varchar, in sz integer)
{
  declare r any;
  declare b any;
  declare hdr varchar;
  declare body varchar;

  hdr := sprintf ('Authorization: Basic %s', encode_base64 ('dav:dav'));
  if (dst is not null)
    hdr := concat (hdr, sprintf ('\r\nDestination: http://%s:%d%s', host, port, dst));
  if (sz)
    body := repeat ('x', sz);
  if (not sz)
    b := http_get (sprintf ('http://%s:%d%s', host, port, path), r, meth, hdr);
  else
    b := http_get (sprintf ('http://%s:%d%s', host, port, path), r, meth, hdr, body);
  if (isarray (r) and aref (r, 0) not like 'HTTP/1.1 2__ %')
    signal ('TREPL', aref (r, 0));
  return b;
};

DB..REPL_SERVER ('rep1', '$U{ds1}', 'localhost:$U{ds1}');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REPL_SERVER : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB..REPL_SUBSCRIBE ('rep1', 'dav', null, null, 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REPL_SUBSCRIBE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB..REPL_INIT_COPY ('rep1', 'dav');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REPL_INIT_COPY : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

-- Initial sync
DB..SYNC_REPL();

DAVcommand ('localhost', $U{http1}, 'MKCOL', '/DAV/repl/1/'    , NULL, 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added collection /DAV/repl/1/ : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'MKCOL', '/DAV/repl/2/'    , NULL, 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added collection /DAV/repl/2/ : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'MKCOL', '/DAV/repl/large/', NULL, 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added collection /DAV/repl/large/ : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'MKCOL', '/DAV/repl/1/11/' , NULL, 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added collection /DAV/repl/1/11/ : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'MKCOL', '/DAV/repl/1/12/' , NULL, 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added collection /DAV/repl/1/12/ : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'MKCOL', '/DAV/repl/2/21/' , NULL, 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added collection /DAV/repl/2/21/ : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'MKCOL', '/DAV/repl/2/22/' , NULL, 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added collection /DAV/repl/2/22/ : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



DAVcommand ('localhost', $U{http1}, 'PUT', '/DAV/repl/res1.txt', NULL, $U{size0});
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added resource /DAV/repl/res1.txt : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'PUT', '/DAV/repl/res1.txt', NULL, $U{size0});
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Updated resource /DAV/repl/res1.txt : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'PUT', '/DAV/repl/1/res1.txt', NULL, $U{size0});
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added resource /DAV/repl/1/res1.txt : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'PUT', '/DAV/repl/large/res2.txt', NULL, $U{size1});
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added resource /DAV/repl/1/res2.txt : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'PUT', '/DAV/repl/1/11/res1.txt', NULL, $U{size0});
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added resource /DAV/repl/1/11/res1.txt : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'PUT', '/DAV/repl/1/11/res3.txt', NULL, $U{size0});
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added resource /DAV/repl/1/11/res3.txt : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'PUT', '/DAV/repl/1/12/res1.txt', NULL, $U{size0});
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added resource /DAV/repl/1/12/res1.txt : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'PUT', '/DAV/repl/1/12/res3.txt', NULL, $U{size0});
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added resource /DAV/repl/1/12/res3.txt : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'PUT', '/DAV/repl/2/21/res1.txt', NULL, $U{size0});
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added resource /DAV/repl/2/21/res1.txt : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'PUT', '/DAV/repl/2/22/res1.txt', NULL, $U{size0});
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Added resource /DAV/repl/2/21/res1.txt : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


DAVcommand ('localhost', $U{http1}, 'MOVE', '/DAV/repl/res1.txt', '/DAV/repl/res2.txt', 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Resource repl/res1.txt moved to repl/res2.txt : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'MOVE', '/DAV/repl/res1.txt', '/DAV/repl2/res_2.txt', 0);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Resource repl/res1.txt moved to repl2/res_2.txt : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'MOVE', '/DAV/repl/1/', '/DAV/repl/3/', 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Collection repl/1/ moved to repl/3/ : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'MOVE', '/DAV/repl/3/', '/DAV/repl/2/3/', 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Collection repl/3/ moved to repl/2/ : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



DAVcommand ('localhost', $U{http1}, 'COPY', '/DAV/repl/2/', '/DAV/repl/4/', 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Collection repl/2/ copied to repl/4/ : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'COPY', '/DAV/repl/res2.txt', '/DAV/repl/res3.txt', 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Resource repl/res2.txt copied to repl/res3.txt  : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'DELETE', '/DAV/repl/res2.txt', NULL, 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Resource repl/res2.txt deleted : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'DELETE', '/DAV/repl/2/', NULL, 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Collection repl/2/ deleted : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Wait for sync
sleep 5;


create procedure WAIT_FOR_SYNC (in srv varchar, in acct varchar)
{
  declare level, stat integer;
  stat := 0;
  repl_status (srv, acct, level, stat);
  while (level < 24 or stat <> 2)
    {
      repl_status (srv, acct, level, stat);
      delay (2);
      if (stat = 3)
	{
--	  dbg_obj_print ('The subscriber is disconnected!');
	  SYNC_REPL ();
          repl_status (srv, acct, level, stat);
	  if (stat = 3)
	    goto end_sync;
	}
    }
  return;
end_sync:
  signal ('TRSYN', 'Replication sync failed');
};

ECHO BOTH "Waiting subscriber to got 'IN SYNC' (on some systems can take more than 15 min)\n";

WAIT_FOR_SYNC ('rep1', 'dav');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The publication is syncronized : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DAVcommand ('localhost', $U{http1}, 'PROPFIND', '/DAV/', NULL, 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": List of publisher in /DAV/  : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
DAVcommand ('localhost', $U{http2}, 'PROPFIND', '/DAV/', NULL, 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": List of subscriber in /DAV/ : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure chf ()
{
  declare a , b any;
  a := DAVcommand ('localhost', $U{http1}, 'PROPFIND', '/DAV/', NULL, 0);
  b := DAVcommand ('localhost', $U{http2}, 'PROPFIND', '/DAV/', NULL, 0);
  a := xml_tree_doc (a);
  b := xml_tree_doc (b);
  a := xpath_eval ('//href',a,0);
  b := xpath_eval ('//href',b,0);
  declare i, l integer;
  declare x , y varchar;
  l := length (a); i := 0;
  while (i < l)
    {
      x := cast (aref (a, i) as varchar);
      y := cast (aref (b, i) as varchar);
      if (x <> y)
	signal ('PROPF', sprintf ('The %s different than %s', x, y));
      i := i + 1;
    }
  return (i);
};


select chf();
--ECHO BOTH $IF $EQU $LAST[1] 18 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": The state of WebDAV repository checked : " $LAST[1] " items found\n";

DB..REPL_SUBSCRIBE ('rep1', 'gtpub', null, null, 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REPL_SUBSCRIBE gtpub : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB..REPL_INIT_COPY ('rep1', 'gtpub');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REPL_INIT_COPY gtpub : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

insert into DB.DBA.GT_TS_ID_PUB (ID, DT) values (20, 'b');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GT_TS_ID_PUB insert on subs side : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select ID, TS from DB.DBA.GT_TS_ID_PUB where DT = 'b';
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GT_TS_ID_PUB no identity cols : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[2] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GT_TS_ID_PUB no ts cols : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB..REPL_SUBSCRIBE ('rep1', 'B7113', null, null, 'dba', 'dba');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REPL_SUBSCRIBE B7113 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB..REPL_INIT_COPY ('rep1', 'B7113');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REPL_INIT_COPY B7113 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from DB.DBA.B7113_FKREPL1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": table B7113_FKREPL1 replicated : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from DB.DBA.B7113_FKREPL2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": table B7113_FKREPL2 replicated : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
checkpoint;


set DSN=$U{ds1};
RECONNECT;

attach table WS.WS.SYS_DAV_COL as WS.WS.REMOTE_COL from '$U{ds2}' user 'dba' password 'dba';
attach table WS.WS.SYS_DAV_RES as WS.WS.REMOTE_RES from '$U{ds2}';


repl_dav_proc ('WS.WS.REMOTE_COL', 'WS.WS.REMOTE_RES', 1, 1);

select RES_FULL_PATH, md5 (blob_to_string (RES_CONTENT)) from WS.WS.SYS_DAV_RES
except
select RES_FULL_PATH, md5 (blob_to_string (RES_CONTENT)) from WS.WS.REMOTE_RES;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " WebDAV resources with different content\n";

select RES_FULL_PATH from WS.WS.SYS_DAV_RES except select RES_FULL_PATH from WS.WS.REMOTE_RES;
ECHO BOTH $IF $EQU $ROWCNT 0  "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " WebDAV resources differ\n";


select count(*) from WS.WS.SYS_DAV_COL a, WS.WS.REMOTE_COL b where WS.WS.COL_PATH (a.COL_ID) = DAV_COL_PATH (b.COL_ID);
ECHO BOTH $IF $EQU $LAST[1] 9  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " WebDAV collections found, should be 9\n";

select count(*) from WS.WS.SYS_DAV_RES a, WS.WS.REMOTE_RES b where a.RES_FULL_PATH = b.RES_FULL_PATH;
ECHO BOTH $IF $EQU $LAST[1] 9  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " WebDAV resources found, should be 9\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: WebDAV transactional replication tests\n";
