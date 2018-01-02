--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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

create procedure rc (in code integer)
{
  return code;
  if (code < 200 or code > 299)
    signal ('.....', sprintf ('Failed with code (%d)', code));
}

create procedure c_mkcol (in uri varchar)
{
  declare hdr any;
  declare code integer;
  http_get (uri, hdr, 'MKCOL', 'Authorization: Basic ZGF2OmRhdg==');
  code := c_resp (hdr);
  return (rc (code));
}

create procedure c_del (in uri varchar, in lck varchar := null)
{
  declare hdr any;
  declare code integer;
  declare h_line varchar;
  if (not isstring (lck))
    http_get (uri, hdr, 'DELETE', 'Authorization: Basic ZGF2OmRhdg==');
  else
    {
      h_line := sprintf ('If: (%s)\r\nAuthorization: Basic ZGF2OmRhdg==', lck);
      http_get (uri, hdr, 'DELETE', h_line);
    }

  code := c_resp (hdr);
  return (rc (code));
}

create procedure c_put (in uri varchar, in cnt varchar, in lck varchar := null)
{
  declare hdr any;
  declare code integer;
  declare h_line varchar;
  if (not isstring (lck))
    http_get (uri, hdr, 'PUT', 'Authorization: Basic ZGF2OmRhdg==', cnt);
  else
    {
      h_line := sprintf ('If: (%s)\r\nAuthorization: Basic ZGF2OmRhdg==', lck);
      http_get (uri, hdr, 'PUT', h_line, cnt);
    }
  code := c_resp (hdr);
  return (rc (code));
}

create procedure c_get (in uri varchar, inout cnt varchar, in lck varchar := null)
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
  code := c_resp (hdr);
  return (rc (code));
}

create procedure c_mv (in uri varchar, in dst varchar, in lck varchar := null)
{
  declare hdr any;
  declare code integer;
  declare h_line varchar;
  if (not isstring (lck))
    h_line :=
      sprintf ('Overwrite: T\r\nAuthorization: Basic ZGF2OmRhdg==\r\nDestination: %s\r\nDepth: infinity', dst);
  else
    h_line :=
      sprintf ('If: (%s)\r\nOverwrite: T\r\nAuthorization: Basic ZGF2OmRhdg==\r\nDestination: %s\r\nDepth: infinity', lck, dst);
  http_get (uri, hdr, 'MOVE', h_line);
  code := c_resp (hdr);
  return (rc (code));
}

create procedure c_cp (in uri varchar, in dst varchar)
{
  declare hdr any;
  declare code integer;
  declare h_line varchar;
  h_line := sprintf ('Overwrite: T\r\nAuthorization: Basic ZGF2OmRhdg==\r\nDestination: %s\r\nDepth: infinity', dst);
  http_get (uri, hdr, 'COPY', h_line);
  code := c_resp (hdr);
  return (rc (code));
}

create procedure c_lck (in uri varchar, inout lck varchar)
{
  declare hdr any;
  declare code integer;
  declare h_line varchar;
  if (isstring (lck))
    h_line := sprintf ('If: (%s)\r\nAuthorization: Basic ZGF2OmRhdg==\r\nTimeout: Second-120', lck);
  else
    h_line := sprintf ('Authorization: Basic ZGF2OmRhdg==\r\nTimeout: Second-120');
  http_get (uri, hdr, 'LOCK', h_line);
  code := c_resp (hdr);
  if (code > 199 and code < 300)
    {
      if (not isstring (lck))
        lck := WS.WS.FIND_KEYWORD (hdr, 'Lock-Token:');
    }
  return (rc (code));
}

create procedure c_ulck (in uri varchar, in lck varchar)
{
  declare hdr any;
  declare code integer;
  declare h_line varchar;
  if (isstring (lck))
    h_line := sprintf ('Lock-Token: %s\r\nAuthorization: Basic ZGF2OmRhdg==', lck);
  else
    h_line := sprintf ('Authorization: Basic ZGF2OmRhdg==');
  http_get (uri, hdr, 'UNLOCK', h_line);
  code := c_resp (hdr);
  if (code > 199 and code < 300)
    {
      lck := null;
    }
  return (rc (code));
}

create procedure c_resp (in hdr any)
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
  return code;
}
;


registry_set ('tdav_perf', '1');

create procedure dav_test (in n_threads int)
{
  declare cnt, rc any;
  registry_set ('tdav_perf', '1');
  rc := DAV_RES_UPLOAD ('/DAV/tdav.vsp', '<?vsp http_flush (); tdav_perf (atoi({?\'n\'})); ?>', 'text/html', '111111111N', 'dav', 'administrators', 'dav' , 'dav');
  if (rc < 0)
    signal ('22023', 'Can not upload the vsp');
  for (declare i int, i := 0; i < n_threads; i := i + 1)
    {
      commit work;
      c_get (tdav_uri (sprintf ('/tdav.vsp?n=%d', i)), cnt);
      delay (1);
    }
}
;

create procedure tget_fname ()
{
  declare txt int;
  return get_fname (txt);
}
;

create procedure get_fname (inout txt any)
{
  declare nam, cnam int;
  declare tmp, ret varchar;

  nam := rnd (2000);
  if (rnd (100) < 10)
    txt := 1;
  else
    txt := 0;

  tmp := sprintf ('%d', nam);
  cnam := tmp[0];
  if (txt)
    tmp := tmp || '.txt';

  ret := sprintf ('/%c/%s', cnam, tmp);
  --dbg_obj_print (ret);
  return tdav_uri (ret);
}
;

create procedure get_cnt (in txt int)
{
  declare siz, rng, pos int;
  declare cnt, tmp any;
  rng := rnd (100);
  if (rng < 20) -- 1-10 K
    {
      siz := rnd (9000)+1000;
    }
  else if (rng < 90) -- 100-400K
    {
      siz := rnd (300000) + 100000;
    }
  else -- 1-10M
    {
      siz := rnd (9000000) + 999999;
    }
  siz := siz - 32; -- for check sum
  if (txt)
    {
      pos := rnd (10000000 - siz);
      cnt := file_to_string ('txt.txt', pos, siz);
      tmp := md5 (cnt);
      --dbg_obj_print (tmp, length (cnt));
      cnt := concat (tmp, cnt);
    }
  else
    {
      pos := 0;
      cnt := file_to_string ('bin.bin', pos, siz);
      tmp := md5 (cnt);
      --dbg_obj_print (tmp, length (cnt));
      cnt := concat (tmp, cnt);
    }
  --dbg_obj_print (siz, pos);
  return cnt;
}
;

create procedure tdav_check ()
{
  declare pp, cc, tmp, chk, chk1 any;
  declare cr cursor for select res_full_path, res_content from ws..sys_dav_res where
      res_full_path like '/DAV/_/%';
  set isolation='committed';
  whenever not found goto nf;
  open cr;
  while (1)
    {
      fetch cr into pp, cc;
      cc := blob_to_string (cc);
      chk := subseq (cc, 0, 32);
      tmp := subseq (cc, 32, length (cc));
      chk1 := md5 (tmp);
      --dbg_obj_print (chk, chk1);
      if (chk <> chk1)
	{
	  registry_set ('tdav_perf', '0');
	  signal ('42000', sprintf ('The resource %s do not match signature', pp));
	}
    }
  nf:
  close cr;
}
;

create procedure tdav_uri (in u any)
{
  return sprintf ('http://localhost:%s/DAV%s', server_http_port (), u);
}
;

create procedure tdav_perf (in nthr int)
{
  declare fname, cname, ccname, cont, rc, resp any;
  declare txt int;
  declare i int;
  declare dt int;
  i := 0;

  dbg_obj_print (nthr);

  c_mkcol (tdav_uri ('/0'));
  c_mkcol (tdav_uri ('/1'));
  c_mkcol (tdav_uri ('/2'));
  c_mkcol (tdav_uri ('/3'));
  c_mkcol (tdav_uri ('/4'));
  c_mkcol (tdav_uri ('/5'));
  c_mkcol (tdav_uri ('/6'));
  c_mkcol (tdav_uri ('/7'));
  c_mkcol (tdav_uri ('/8'));
  c_mkcol (tdav_uri ('/9'));

  commit work;

  declare exit handler for sqlstate '*'
    {
      dbg_obj_print (sprintf ('\n*** dav perf test driver exiting with %s: %s\n', __sql_state, __sql_message));
      rollback work;
      goto again;
      --signal (__sql_state, __sql_message);
    };
  declare exit handler for sqlstate '40001'
    {
      rollback work;
      goto again;
    }
  ;

again:
  while (registry_get ('tdav_perf') = '1')
    {
      -- get
      cname := get_fname (txt);
      do_init_sample (dt);
      commit work;
      rc := c_get (cname, cont);
      do_sample (rc, dt, length (cont), 'GET');
      -- put
      cname := get_fname (txt);
      cont := get_cnt (txt);
      do_init_sample (dt);
      commit work;
      rc := c_put (cname, cont);
      do_sample (rc, dt, length (cont), 'PUT');
      -- copy
      cname := get_fname (txt);
      ccname := get_fname (txt);
      do_init_sample (dt);
      commit work;
      rc := c_cp (cname, ccname);
      do_sample (rc, dt, 0, 'COPY');
      -- delete
      cname := get_fname (txt);
      do_init_sample (dt);
      commit work;
      rc := c_del (cname);
      do_sample (rc, dt, 0, 'DELETE');
      commit work;
--      if (nthr = 0 and mod (i, 1000) = 0)
--        tdav_check ();
      i := i + 1;
    }
}
;


create procedure do_init_sample (inout dt any)
{
  dt := msec_time ();
}
;

create procedure do_sample (in rc int, in dt int, in len int, in mtd varchar)
{
  if (rc > 299)
    return;
  prof_sample ('davperf', msec_time () - dt, 1);
}
;





