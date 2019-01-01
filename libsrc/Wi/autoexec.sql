--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

create procedure DB.DBA.ddl_load_script (in _filename varchar)
{
  declare cnt, parts, errors any;
  cnt := file_to_string (_filename);
  parts := sql_split_text (cnt);
  foreach (varchar s in parts) do
    {
      declare stat, msg any;
      stat := '00000';
      exec (s, stat, msg);
      if (stat <> '00000')
	{
	  log_message (sprintf ('Error in autoexec.isql: [%s] %s', stat, msg));
	  rollback work;
	}
      else
	{
	  commit work;
	}
    }
}
;

create procedure DB.DBA.ddl_load_script_safe (in _filename varchar)
{
  declare _status, _message varchar;
  _status := '';
  _message := 'OK';
  if (not file_stat (_filename))
    return;
  exec (concat ('DB.DBA.ddl_load_script (', WS.WS.STR_SQL_APOS(_filename), ')'), _status, _message);
  if (_message<>'OK')
    {
      dbg_printf ('\nError on loading file \'%s\'', _filename );
      dbg_printf ('Status returned: %s %s', _status, _message);
    }
}
;

create procedure ddl_autoexec (in _filename varchar)
{
  if (_filename = '')
    _filename := 'autoexec.isql';
-- Uncomment this if you want to use this feature
DB.DBA.ddl_load_script_safe (_filename);
}
;

create procedure ddl_dav_replicate_rdf_quad ()
{
  if (1 <> sys_stat ('cl_run_local_only'))
    return;
  DB.DBA.DAV_AUTO_REPLICATE_TO_RDF_QUAD ();
}
;

--!AFTER
ddl_dav_replicate_rdf_quad ()
;

--!AFTER
VAD.DBA.VAD_AUTO_UPGRADE ()
;

--!AFTER
ddl_autoexec ('')
;
