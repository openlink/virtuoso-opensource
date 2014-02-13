--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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

create procedure
make_file ()
{
  declare _string any;
  declare _add any;
  declare len, _size integer;
  _size := $U{_SIZE};
  _string := 'This is test file!\n';
  len := length (_string);
  _add := repeat (_string, (_size*1024/len) + 1);
  string_to_file (concat ('$U{_HOME}','/test_dav'), _add, 0);
}
;

delete from WS.WS.SYS_DAV_USER where U_NAME like 'user_%';
delete from WS.WS.SYS_DAV_COL where COL_NAME like 'user_%';
delete from WS.WS.SYS_DAV_RES where RES_FULL_PATH like '/DAV/user_%';

create procedure
make_users ()
{
  declare idx, len integer;
  declare _user, _pass varchar;
  idx := 1;
  len := $U{_USERS} + 1;
  while (idx < len)
    {
      _user := concat ('user_', cast (idx as varchar));
      _pass := concat ('pass_', cast (idx as varchar));
      insert soft WS.WS.SYS_DAV_USER (U_ID, U_NAME, U_FULL_NAME, U_E_MAIL, U_PWD,
	   U_GROUP, U_DEF_PERMS, U_ACCOUNT_DISABLED)
	   values (idx + 2, _user, 'DAV test user', 'test@suite.com', _pass, 1, '110100000', 0);
      insert into WS.WS.SYS_DAV_COL (COL_ID, COL_NAME, COL_PARENT, COL_OWNER,
	   COL_GROUP, COL_PERMS, COL_CR_TIME, COL_MOD_TIME)
           values (WS.WS.GETID ('C'), _user, 1, idx + 2, 1, '110100000R', now (), now ());
      idx := idx + 1;
    }
}
;


create procedure
make_uri ()
{
  declare _text, _name, _user_dir varchar;
  declare idx, len, loops, dlen, rn integer;
  declare dl any;
  idx := 1;
  loops := $U{_LOOPS};
  if ('$U{_SIZE}' = 'random')
    rn := 1;
  else
    rn := 0;
  if (rn)
    {
      dl := sys_dirlist ('$U{_HOME}/files', 1);
      dlen := length (dl);
    }
  len := $U{_USERS} + 1;
  while (idx < len)
    {
      _user_dir := concat ('user_', cast (idx as varchar), '/');
      if (not rn)
	{
          _text := concat ('1 PUT /DAV/', _user_dir, 'test_dav', cast (idx as varchar),'.BIN HTTP/1.1\n');
          _text := concat (_text, '1 GET /DAV/user_', cast (idx as varchar), '/test_dav', cast (idx as varchar),'.BIN HTTP/1.1\n');
	}
      else
	{
	  declare fn varchar;
	  declare ix integer;
          ix := 0;
          _text := '';
	  while (ix < loops)
	    {
              fn := aref (dl, rnd (dlen));
              _text := concat (_text, '1 PUT /DAV/', _user_dir, fn, ' HTTP/1.1\n');
              _text := concat (_text, '1 GET /DAV/', _user_dir, fn, ' HTTP/1.1\n');
              ix := ix + 1;
	    }
	}
      if (not rn)
        _text := repeat (_text, loops);
      _text := concat (sprintf ('localhost %s\n', server_http_port ()), _text);
      string_to_file (concat ('$U{_HOME}', '/uri_', cast (idx as varchar), '.url'), _text, 0);
      idx := idx + 1;
    }
}
;

make_file ();

make_users ();

make_uri ();
