--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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
  declare _text varchar;	-- Content of file to load
  declare _cmd varchar;		-- One command from \c _text to execute
  declare _line varchar;	-- Last line
  declare _row_no integer;	-- Number of current line in the file
  declare _first_row integer;	-- Number of first line of group of commands
  declare _errctr integer;	-- Number of errors
  declare _pos integer;		-- Position of the next CR in _text
  declare _status, _message varchar;
  _text := file_to_string (_filename);
--  dbg_printf('\n-- Loading file \'%s\'', _filename);
  _row_no := 0;
  _first_row := 1;
  _errctr := 0;
  _cmd := '';
next_line:
  if(_text = '')
    goto eof;
  _row_no := _row_no+1;
  _pos := strchr (_text, '\n');
  if (_pos is null or _pos = length(_text)-1)
    {
      _cmd := concat(_cmd, '\n', _text);
      _text := '';
      goto cmd_found;
    }
  _line := subseq (_text, 0, _pos);
  _text := subseq (_text, _pos+1);
  if (ltrim (_line, ' \t\r') = '')
    goto cmd_found;
  _cmd := concat(_cmd, '\n', _line);
  goto next_line;
cmd_found:
  _status := '';
  _message := 'OK';
  _cmd := rtrim (_cmd, ' \t\n\r;');
  _cmd := ltrim (_cmd, ' \t\n\r');
  if (_cmd = '')
    goto next_line;
  exec (_cmd, _status, _message);
  if (_message<>'OK')
    {
      dbg_printf ('\nError on loading file \'%s\', lines %d-%d:\n%s',
       _filename, _first_row, _row_no, _cmd );
      dbg_printf ('Status returned: %s %s', _status, _message);
      _errctr := _errctr+1;
    }
  _cmd := '';
  _first_row := _row_no+1;
  goto next_line;
eof:;
--  dbg_printf('\n-- File \'%s\' loaded with %d errors', _filename, _errctr);
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

--!AFTER
DB.DBA.DAV_AUTO_REPLICATE_TO_RDF_QUAD ()
;

--!AFTER
ddl_autoexec ('')
;
