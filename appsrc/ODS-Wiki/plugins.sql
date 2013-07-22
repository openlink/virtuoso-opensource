--
--  $Id$
--
--  Atom publishing protocol support.
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

use WV
;

create function MAX_PLUGINS()
{
  return 100;
}
;

create function PLUGIN_NAME (in idx int)
{
  return 'WikiV name ' || cast (idx as varchar);
}
;

create function PLUGIN_LEXER (in idx int)
{
  return 'WikiV lexer ' || cast (idx as varchar);
}
;

create procedure LEXER (in _cluster_name varchar, out _lexer varchar, out _lexer_name varchar)
{
  _lexer_name := WV.WIKI.CLUSTERPARAM (_cluster_name, 'plugin');
  _lexer := PLUGIN_BY_ID (_lexer_name);
  _lexer_name := NAME_BY_ID (_lexer_name);
  if (__proc_exists (_lexer, 2) is null)
    { 
    _lexer := PLUGIN_BY_ID (null);
      _lexer_name := NAME_BY_ID (null);
    }
}
;

create function PLUGINS ()
{
  declare idx, _len int;
  _len := MAX_PLUGINS();
  declare res any;
  vectorbld_init(res);
  idx := 1;
  while (idx < _len)
    {
      if (__proc_exists ('WikiV name ' || cast (idx as varchar), 2))
        {
	  declare x int;
	  x := idx;
	  vectorbld_acc (res, x);
	}
      idx := idx + 1;
    }
  vectorbld_final(res);
  return res;
}
; 

create function PLUGIN_NAMES()
{
  declare ids any;
  ids := PLUGINS ();
  
  declare res any;
  vectorbld_init (res);
  declare idx int;
  for (idx:=0; idx<length (ids); idx:=idx+1)
    {
       vectorbld_acc (res, vector (ids[idx], call (PLUGIN_NAME(ids[idx])) ()));
    }
  vectorbld_final (res);
  return res;
}
;

create function POSTFIX_BY_ID (in idx varchar)
{
  if (idx is null or idx = '0')
    return '';
  else
    return ' ' || idx;
}
;

create function PLUGIN_BY_ID (in idx varchar)
{
  return 'WikiV lexer' || POSTFIX_BY_ID (idx);
}
;

create function NAME_BY_ID (in idx varchar)
{
  return 'WikiV name' || POSTFIX_BY_ID (idx);
}
;


use DB
;
