--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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
ECHO BOTH "started with HOST=" $U{HOST} "\n";

create procedure rc (in code integer)
{
  if (code < 200 or code > 299)
    signal ('.....', sprintf ('Failed with code (%d)', code));
  return 0;
}


create procedure c_mkcol (in uri varchar)
{
  declare hdr, body any;
  declare code integer;
  body := http_get (uri, hdr, 'MKCOL', 'Authorization: Basic ZGF2OmRhdg==');
  code := c_resp (hdr, body);
  return (rc (code));
}

create procedure c_del (in uri varchar, in lck varchar)
{
  declare hdr, body any;
  declare code integer;
  declare h_line varchar;
  if (not isstring (lck))
    body := http_get (uri, hdr, 'DELETE', 'Authorization: Basic ZGF2OmRhdg==');
  else
    {
      h_line := sprintf ('If: (%s)\r\nAuthorization: Basic ZGF2OmRhdg==', lck);
      body := http_get (uri, hdr, 'DELETE', h_line);
    }

  code := c_resp (hdr, body);
  return (rc (code));
}

create procedure c_put (in uri varchar, in cnt varchar, in lck varchar)
{
  declare hdr, body any;
  declare code integer;
  declare h_line varchar;
  if (not isstring (lck))
    body := http_get (uri, hdr, 'PUT', 'Authorization: Basic ZGF2OmRhdg==', cnt);
  else
    {
      h_line := sprintf ('If: (%s)\r\nAuthorization: Basic ZGF2OmRhdg==', lck);
      body := http_get (uri, hdr, 'PUT', h_line, cnt);
    }
  code := c_resp (hdr, body);
  return (rc (code));
}

create procedure c_get (in uri varchar, inout cnt varchar, in lck varchar)
{
  declare hdr any;
  declare code integer;
  declare h_line varchar;
  if (not isstring (lck))
    cnt := http_get (uri, hdr, 'GET', 'Authorization: Basic ZGF2OmRhdg==');
  else
    {
      h_line := sprintf ('If: (%s)\r\nAuthorization: Basic ZGF2OmRhdg==', lck);
      cnt := http_get (uri, hdr, 'GET', h_line);
    }
  code := c_resp (hdr, cnt);
  return (rc (code));
}

create procedure c_mv (in uri varchar, in dst varchar, in lck varchar)
{
  declare hdr, body any;
  declare code integer;
  declare h_line varchar;
  if (not isstring (lck))
    h_line :=
      sprintf ('Overwrite: T\r\nAuthorization: Basic ZGF2OmRhdg==\r\nDestination: %s\r\nDepth: infinity', dst);
  else
    h_line :=
      sprintf ('If: (%s)\r\nOverwrite: T\r\nAuthorization: Basic ZGF2OmRhdg==\r\nDestination: %s\r\nDepth: infinity', lck, dst);
  body := http_get (uri, hdr, 'MOVE', h_line);
  code := c_resp (hdr, body);
  return (rc (code));
}

create procedure c_cp (in uri varchar, in dst varchar)
{
  declare hdr, body any;
  declare code integer;
  declare h_line varchar;
  h_line := sprintf ('Overwrite: T\r\nAuthorization: Basic ZGF2OmRhdg==\r\nDestination: %s\r\nDepth: infinity', dst);
  body := http_get (uri, hdr, 'COPY', h_line);
  code := c_resp (hdr, body);
  return (rc (code));
}

create procedure c_lck (in uri varchar, inout lck varchar)
{
  declare hdr, body any;
  declare code integer;
  declare h_line varchar;
  if (isstring (lck))
    h_line := sprintf ('If: (%s)\r\nAuthorization: Basic ZGF2OmRhdg==\r\nTimeout: Second-120', lck);
  else
    h_line := sprintf ('Authorization: Basic ZGF2OmRhdg==\r\nTimeout: Second-120');
  body := http_get (uri, hdr, 'LOCK', h_line);
  code := c_resp (hdr, body);
  if (code > 199 and code < 300)
    {
      if (not isstring (lck))
        lck := WS.WS.FIND_KEYWORD (hdr, 'Lock-Token:');
    }
  return (rc (code));
}

create procedure c_ulck (in uri varchar, in lck varchar)
{
  declare hdr, body any;
  declare code integer;
  declare h_line varchar;
  if (isstring (lck))
    h_line := sprintf ('Lock-Token: %s\r\nAuthorization: Basic ZGF2OmRhdg==', lck);
  else
    h_line := sprintf ('Authorization: Basic ZGF2OmRhdg==');
  body := http_get (uri, hdr, 'UNLOCK', h_line);
  code := c_resp (hdr, body);
  if (code > 199 and code < 300)
    {
      lck := null;
    }
  return (rc (code));
}

create procedure c_resp (in hdr any, inout body any)
{
  declare line, code varchar;
  if (hdr is null or __tag (hdr) <> 193)
    return (502);
  if (length (hdr) < 1)
    return (502);
  line := aref (hdr, 0);
  if (length (line) < 12)
    return (502);
  code := substring (line, strstr (line, 'HTTP/1.') + 9, length (line));
  while ((length (code) > 0) and (aref (code, 0) < ascii ('0') or aref (code, 0) > ascii ('9')))
    code := substring (code, 2, length (code) - 1);
  if (length (code) < 3)
    return (502);
  code := substring (code, 1, 3);
  code := atoi (code);
  if ((code = 500) or (code = 404))
    {
      dbg_obj_princ (hdr, body);
    }
  return code;
}
;

create procedure put_test ()
{
  declare ix, rc integer;
  while (ix < 128)
    {
      rc := c_put ('http://$U{HOST}/DAV/TDAV1/PUT_TEST.TXT' , repeat (' ', 1000000), null);
      if (rc <> 0)
        signal ('PUT01', 'Multiple PUT failed');
      ix := ix + 1;
    }
}

DB.DBA.vt_batch_update ('WS.WS.SYS_DAV_RES', 'ON', 120);

c_del   ('http://$U{HOST}/DAV/TDAV1/', null);
ECHO BOTH $IF $EQU $STATE OK "***FAILED" "PASSED";
ECHO BOTH ": DELETE /DAV/TDAV1/TRESD.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_mkcol ('http://$U{HOST}/DAV/TDAV1/');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": MKCOL /DAV/TDAV1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_mkcol ('http://$U{HOST}/DAV/TDAV1/');
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": MKCOL (existing collection) /DAV/TDAV1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_put   ('http://$U{HOST}/DAV/TDAV1/TRES1.TXT', '0', null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": PUT /DAV/TDAV1/TRES1.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_put   ('http://$U{HOST}/DAV/TDAVX/TRESX.TXT', '0', null);
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": PUT (nonexistent collection) /DAV/TDAVX/TRESX.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_mv   ('http://$U{HOST}/DAV/TDAV1/TRES1.TXT', 'http://$U{HOST}/DAV/TDAV1/TRES2.TXT', null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": MOVE /DAV/TDAV1/TRES1.TXT -> TRES2.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_mv   ('http://$U{HOST}/DAV/TDAV1/TRESX.TXT', 'http://$U{HOST}/DAV/TDAV1/TRES2.TXT', null);
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": MOVE (nonexistent) /DAV/TDAV1/TRESX.TXT -> TRES2.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_cp   ('http://$U{HOST}/DAV/TDAV1/TRES2.TXT', 'http://$U{HOST}/DAV/TDAV1/TRES1.TXT');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": COPY /DAV/TDAV1/TRES2.TXT -> TRES1.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_cp   ('http://$U{HOST}/DAV/TDAV1/TRES2.TXT', 'http://$U{HOST}/DAV/TDAV1/TRESD.TXT');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": COPY /DAV/TDAV1/TRES2.TXT -> TRESD.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_cp   ('http://$U{HOST}/DAV/TDAV1/TRESX.TXT', 'http://$U{HOST}/DAV/TDAV1/TRESX1.TXT');
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": COPY (non existent resource) /DAV/TDAV1/TRESX.TXT -> TRESX1.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_del   ('http://$U{HOST}/DAV/TDAV1/TRESD.TXT', null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": DELETE /DAV/TDAV1/TRESD.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_del   ('http://$U{HOST}/DAV/TDAV1/TRESD.TXT', null);
ECHO BOTH $IF $EQU $STATE OK  "***FAILED" "PASSED";
ECHO BOTH ": DELETE (already deleted) /DAV/TDAV1/TRESD.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_put   ('http://$U{HOST}/DAV/TDAV1/TRES3.TXT', '0', null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": PUT /DAV/TDAV1/TRES3.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_put   ('http://$U{HOST}/DAV/TDAV1/TRES4.TXT', '0', null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": PUT /DAV/TDAV1/TRES4.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_put   ('http://$U{HOST}/DAV/TDAV1/TRES6.TXT', '0', null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": PUT /DAV/TDAV1/TRES6.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_put   ('http://$U{HOST}/DAV/TDAV1/TRES5.TXT', '0', null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": PUT /DAV/TDAV1/TRES5.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

c_put   ('http://$U{HOST}/DAV/TDAV1/TRESL.TXT', '0', null);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": PUT /DAV/TDAVX/TRESL.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

put_test ();
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": MULTIPLE PUT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure s_lck ()
{
  declare l any;
  declare rc integer;
  l := null;
  rc := c_lck ('http://$U{HOST}/DAV/TDAV1/TRESL.TXT', l);
  --dbg_obj_print ('L-Token: ', l);
  if (rc = 0 and l is not null)
    update WS.WS.SYS_DAV_LOCK set LOCK_TIMEOUT = 5 where concat ('<opaquelocktoken:', LOCK_TOKEN,'>') = l;
  result_names (rc);
  result (rc);
  end_result ();
}

-- Redefinition
create procedure rc (in code integer)
{
  if (code < 200 or code > 299)
    return (code);
  else
    return (0);
}

create procedure l_test ()
{
  declare l, l1 varchar;
  declare rc, ix integer;
  ix := 0;
  while (ix < 10)
    {
      l := null;
      l1 := null;
      rc := c_lck ('http://$U{HOST}/DAV/TDAV1/TRES1.TXT', l);
      if (rc)
	signal ('.....', 'Lock failed');
      rc := c_lck ('http://$U{HOST}/DAV/TDAV1/TRES1.TXT', l1);
      if (not rc)
	signal ('.....', 'Lock over locked resource');
      rc := c_put   ('http://$U{HOST}/DAV/TDAV1/TRES1.TXT', '0', null);
      if (not rc)
	signal ('.....', 'Put over locked resource');
      rc := c_put   ('http://$U{HOST}/DAV/TDAV1/TRES1.TXT', '0', l);
      if (rc)
	signal ('.....', 'Put over self locked resource');
      rc := c_ulck ('http://$U{HOST}/DAV/TDAV1/TRES1.TXT', l);
      if (rc)
	signal ('.....', 'Unlock failed');
      ix := ix + 1;
    }
}

l_test ();
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": MULTIPLE LOCK/PUT/UNLOCK /DAV/TDAV1/TRES1.TXT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from WS.WS.SYS_DAV_LOCK;
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED" "***FAILED";
ECHO BOTH ": LOCK/UNLOCK TEST : LOCK COUNT=" $LAST[1] "\n";

s_lck ();

ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED" "***FAILED";
ECHO BOTH ": LOCK METHOD TEST : RETURN CODE=" $LAST[1] "\n";

select count (*) from WS.WS.SYS_DAV_LOCK;
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
ECHO BOTH ": LOCK TEST : LOCK COUNT=" $LAST[1] "\n";

select * from WS.WS.SYS_DAV_LOCK;

create procedure c_test (in n integer, in n1 integer)
{
  declare stat, msg varchar;
rep:
  stat := '00000'; msg := '';
  exec ('c_test_h (?)', stat, msg, vector (n));
  dbg_obj_princ (sprintf ('c_test_h (%d, %d) status: %s %s', n, n1, stat, msg));
  if (stat <> '00000')
    {
      delay (1);
      goto rep;
    }
  return;
}
;

create procedure c_test_h (in n integer)
{
  declare l varchar;
  declare rc, ix, zz integer;
  declare cnt, ulink varchar;
  set isolation='uncommitted';
  ix := 0;
  cnt := null;
--  while (ix < 64)
    {

nwc1:
      ulink := sprintf ('http://$U{HOST}/DAV/TDAV1/TRES%d.TXT', (rnd (5) + 1));
      dbg_obj_princ ('C_TEST_H=', n, ' URI=', ulink, ' will lock');
      l := null;
      rc := c_lck (ulink, l);
      if (rc <> 0)
        {
          dbg_obj_princ ('C_TEST_H=', n, ' URI=', ulink, ' failed to lock, reason ', rc);
          goto nwc1;
	}
      dbg_obj_princ ('C_TEST_H=', n, ' URI=', ulink, ' locked as ', l);
nwc2:      
      rc := c_get (ulink, cnt, l);
      if (rc <> 0)
        {
          dbg_obj_princ ('C_TEST_H=', n, ' URI=', ulink, ' failed to get, reason ', rc);
          goto nwc2;
	}
      if (cnt is not null)
	{
	  declare num integer;
          num := 0;
          num := atoi (cnt) + 1;
          dbg_obj_princ ('C_TEST_H=', n, ' URI=', ulink, ' read value ', num-1, ' new value set ', num );
          cnt := cast (num as varchar);
	}
      else
        cnt := '1';
nwc3:
      rc := c_put (ulink, cnt, l);
      if (rc <> 0)
        {
          dbg_obj_princ ('C_TEST_H=', n, ' URI=', ulink, ' failed to put, reason ', rc);
          goto nwc3;
	}
      dbg_obj_princ ('C_TEST_H=', n, ' URI=', ulink, ' put with lock ', l, ' status ', rc);
nwc4:
      rc := c_ulck (ulink, l);
      if (rc <> 0)
        {
          dbg_obj_princ ('C_TEST_H=', n, ' URI=', ulink, ' failed to unlock, reason ', rc);
          goto nwc4;
	}
      dbg_obj_princ ('C_TEST_H=', n, ' URI=', ulink, ' unlock lock ', l, ' status ', rc);
      ix := ix + 1;
    }
}

create procedure c_test_col_1 (in ct integer)
{
  declare ix, ix1 integer;
  declare uc varchar;
  ix := 0;
  while (ix < ct)
    {
      uc := sprintf ('http://$U{HOST}/DAV/TDAV_%d/', ix + 1);
      c_mkcol (uc);
      ix1 := 0;
      while (ix1 < ct)
	{
          uc := sprintf ('http://$U{HOST}/DAV/TDAV_%d/TDAV_%d/', ix + 1, ix1 + 1);
	  c_mkcol (uc);
          ix1 := ix1 + 1;
	}
      ix := ix + 1;
    }
}

c_test_col_1 (10);



create table DAV_HITS (DCLI integer, DROUND integer, DCPATH varchar, DRPATH varchar, DRC integer, DAC char(2));
create table DAV_ERR (DI integer, DC integer, DR integer, DP varchar, DL varchar);

create procedure c_test_1 (in n integer)
{
  declare l, uc, ur, ud, cnt, cnt1, l1, cnt_o varchar;
  declare rc, rc1, ix integer;
--set isolation='uncommitted';
  ix := 0;
  while (ix < 32)
    {
nwc1:
      rc := 0;
      if (rnd (100) > 50)
	uc := sprintf ('http://$U{HOST}/DAV/TDAV_%d/', rnd (10) + 1);
      else
	uc := sprintf ('http://$U{HOST}/DAV/TDAV_%d/TDAV_%d/', (rnd (10) + 1), (rnd (10) + 1));
      ur := sprintf (concat (uc, 'TRES_%d.TXT'), rnd (10) + 1);
--      ur := sprintf (concat (uc, 'TRES_%d_%d_O.TXT'), n , ix);

      ud := sprintf (concat (uc, 'TRES_%d_%d.TXT'), n, ix);
--      dbg_obj_print (n ,'collection : ', uc, '\n  resource : ', ur);
      l := null;
      rc := c_lck (uc, l);
      if (rc <> 0)
        goto nwc1;
      --dbg_obj_print (n ,'locked collection : ', uc, '\n   resource : ', ur);

      l1 := null;

      rc := c_get (ur, cnt, l);
      if (rc <> 404 and rc <> 0)
	{
	  insert into DAV_ERR (DI, DC, DR, DP, DL) values (n, ix, rc, ur, l);
          c_ulck (uc, l);
          goto nwc1;
	}

      if (rc = 0 and cnt is not null)
	{
	  declare num integer;
          num := 0;
          num := atoi (cnt) + 1;
          cnt_o := cnt;
          cnt := cast (num as varchar);
	  --dbg_obj_print (n, ' ' , ur, '-> old resource: ', cnt);
	}
      else
	{
          cnt := '1';
          cnt_o := '';
	  --dbg_obj_print (n, ' ', ur, '-> new resource: ', cnt);
	}
        cnt := concat (cnt, ' ', cnt_o, repeat (' ', rnd (500000) + 1));
      rc := c_put (ur, cnt, l);
      if (rc <> 0)
	{
	  insert into DAV_ERR (DI, DC, DR, DP, DL) values (n, ix, rc, ur, l);
          c_ulck (uc, l);
          goto nwc1;
	}
      rc1 := c_get (ur, cnt1, l);
      if (rc1 <> 0 or cnt1 <> cnt)
	{
	  dbg_obj_print ('PUT ERROR :', rc, ' ', atoi(cnt1), ' ',atoi (cnt));
          c_ulck (uc, l);
          goto nwc1;
--	  signal ('DAV03', sprintf ('Put failed cli: %d turn: %d uri: %s', n, ix, ur));
	}
      declare wh integer;
      wh := rnd (100);
      if (wh > 85)
        {
          rc := c_cp (ur, ud);
          rc1 := c_del (ur, l);
	  if (rc1 <> 0 and rc1 <> 404)
	    {
	      dbg_obj_print ('Cannot delete ', ur, rc1);
ag_del:
              rc := c_del (ud, l);
	      if (rc <> 0 and rc <> 404)
                goto ag_del;
              c_ulck (uc, l);
              goto nwc1;
	    }
	  --dbg_obj_print (n, ' cp ', ur, ' -> ', ud);
          rc1 := c_get (ud, cnt1, l);
	  if (rc1 <> 0 or cnt1 <> cnt)
	    {
	      dbg_obj_print ('CP ERROR :', rc1, ' ', atoi(cnt1), ' ',atoi (cnt));
              c_ulck (uc, l);
              goto nwc1;
--	      signal ('DAV01', sprintf ('Copy failed cli: %d turn: %d uri: %s', n, ix, ur));
	    }
          insert into DAV_HITS (DCLI, DROUND, DCPATH, DRPATH, DRC, DAC) values (n, ix, uc, ud, rc, 'CD');
	}
      else if (wh < 15)
        {
mv_new:
          rc := c_mv (ur, ud, l);
	  --dbg_obj_print (n, ' mv ', ur, ' -> ', ud);
          rc1 := c_get (ur, cnt1, l);
	  if (rc1 <> 404)
            {
	      if (rc1 = 0 and rc = 0)
	        goto mv_new;
	      else
		{
		  c_ulck (uc, l);
		  goto nwc1;
		}
--	      signal ('DAV04', sprintf ('Move failed cli: %d turn: %d uri: %s code: %d', n, ix, ur, rc1));
	    }
          rc1 := c_get (ud, cnt1, l);
	  if (rc1 <> 0 or cnt1 <> cnt)
	    {

	      dbg_obj_print ('MV ERROR :', rc1, ' ', atoi(cnt1), ' ',atoi (cnt), ' ', ur);
              c_ulck (uc, l);
              goto nwc1;
--	      signal ('DAV02', sprintf ('Move failed cli: %d turn: %d uri: %s', n, ix, ur));
	    }
          insert into DAV_HITS (DCLI, DROUND, DCPATH, DRPATH, DRC, DAC) values (n, ix, uc, ud, rc, 'MV');
	}
      else
	{
          insert into DAV_HITS (DCLI, DROUND, DCPATH, DRPATH, DRC, DAC) values (n, ix, uc, ur, rc, 'NA');
	}
      --dbg_obj_print (n, 'put with lock :', l, ' result code : ', rc);
      rc := c_ulck (uc, l);
      --dbg_obj_print (n, 'unlock :', l, ' code : ', rc);
      if (rc <> 0)
	insert into DAV_ERR (DI, DC, DR, DP, DL) values (n, ix, rc, uc, l);
      ix := ix + 1;
    }
}
;

c_mkcol ('http://$U{HOST}/DAV/TIDAV/');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": MKCOL /DAV/TIDAV : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure c_itest (in n integer, in n1 integer)
{
  declare stat, msg varchar;
rep:
  stat := '00000'; msg := '';
  exec ('c_itest_h (?, ?)', stat, msg, vector (n, n1));
  dbg_obj_princ (sprintf ('c_itest_h (%d, %d) status: %s %s', n, n1, stat, msg));
  if (stat not like '00000')
    {
      rollback work;
      delay (1);
      goto rep;
    }
  return;
}
;

create procedure c_itest_h (in n integer, in n1 integer)
{
  declare l varchar;
  declare rc integer;
  declare cnt, ulink varchar;
  set isolation='uncommitted';
  cnt := null;
nwc1:
  ulink := sprintf ('http://$U{HOST}/DAV/TIDAV/TIRES%d_%d.TXT', n, n1);
  l := null;
  dbg_obj_princ ('C_ITEST_H=', n, ' URI=', ulink, ' will lock');
  rc := c_lck (ulink, l);
  if (rc <> 0)
    goto nwc1;
nwc2:
  dbg_obj_princ ('C_ITEST_H=', n, ' URI=', ulink, ' will get');
  rc := c_get (ulink, cnt, l);
  if ((rc <> 0) and (cast (rc as integer) <> 404))
    {
      dbg_obj_princ ('C_ITEST_H=', n, ' URI=', ulink, ' failed to get, reason ', rc);
      goto nwc2;
    }
  if (cnt is not null)
    {
      declare num integer;
      num := 0;
      num := atoi (cnt) + 1;
      cnt := cast (num as varchar);
    }
  else
    cnt := '1';
nwc3:
  dbg_obj_princ ('C_ITEST_H=', n, ' URI=', ulink, ' will put ', cnt);
  rc := c_put (ulink, cnt, l);
  if (rc <> 0)
    {
      dbg_obj_princ ('C_ITEST_H=', n, ' URI=', ulink, ' failed to put, reason ', rc);
      goto nwc3;
    }
nwc4:
  rc := c_ulck (ulink, l);
  if (rc <> 0 and rc <> 404)
    {
      dbg_obj_princ ('C_ITEST_H=', n, ' URI=', ulink, ' failed to unlink, reason ', rc);
      goto nwc4;
    }
}
;
