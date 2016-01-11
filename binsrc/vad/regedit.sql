--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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
create procedure "WS"."WS"."MERGE_PARAMS" (in _vect1 any, in _vect2 any) returns any
{
  declare _len1, _len2, _idx1, _idx2 integer;
  declare _name, _value varchar;
  _len1 := length (_vect1)-1;
  _len2 := length (_vect2)-1;
  _idx2 := 0;
  while (_idx2 < _len2)
    {
      _name := aref (_vect2, _idx2);
      _value := cast (aref (_vect2, _idx2+1) as varchar);
      _idx1 := 0;
      while (_idx1 < _len1)
	{
	  if (aref (_vect1, _idx1) = _name)
	    {
	      aset (_vect1, _idx1+1, _value);
	      goto change_merged;
	    }
	  _idx1 := _idx1+2;
	}
      _vect1 := vector_concat (_vect1, vector (_name, _value));
change_merged:
      _idx2 := _idx2+2;
    }
  return _vect1;
}
;

create procedure "WS"."WS"."SPRINT_PARAMS" (in _vect any) returns varchar
{
  declare _len, _idx integer;
  declare _value varchar;
  declare _res any;
  _len := length (_vect)-1;
  if (_len = 0)
    return '';
  _res := string_output();
  _idx := 0;
  while (_idx < _len)
    {
      _value := aref (_vect, _idx+1);
      if (_value is not null)
	{
	  http ('&', _res);
	  http_url (aref (_vect, _idx), null, _res);
	  http ('=', _res);
	  http_url (_value, null, _res);
	}
      _idx := _idx+2;
    }
  _res := string_output_string (_res);
  aset (_res, 0, 63);
  return _res;
}
;

create procedure "DB"."DBA"."VAD_REGEDIT_PRINT_BRANCH_BEGIN" (
  inout	path		any,
  inout	params		any,
  inout	lines		any,
  in	_ctx_key	varchar,
  in	_depth		integer,
  in	_spot_depth	integer,
  in	_rkey_path	any,
  in	_rkey_params	varchar,
  in	_rkey_anchor	varchar,
  in	_r_type		varchar,
  in	_r_value	varchar
)
{
  declare _help_doc varchar;
  declare _help_hint varchar;
  declare _title varchar;
  declare _img varchar;
  declare _tableparams varchar;
  _help_hint := "DB"."DBA"."VAD_RGET" (concat (_ctx_key,'?help=hint'));
  _help_doc := "DB"."DBA"."VAD_RGET" (concat (_ctx_key,'?help=doc'));
  if (_help_hint is null)
    {
      _img := 'rkey.gif';
      _title := '(this key has no description)';
    }
  else
    {
      _img := 'rkey_i.gif';
      _title := _help_hint;
    }
  if (_depth = _spot_depth-1)
    _tableparams := ' BGCOLOR="#EEFFFF"';
  else
    _tableparams := '';
  http('<TR><TD VALIGN=TOP>');
  http('<IMG SRC="'); http_value(_img); http ('" HEIGHT=16 WIDTH=20 BORDER=0 ALT="'); http_value(_ctx_key); http ('" />');
  http('</TD><TD WIDTH="100%"><TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0 WIDTH="100%"'); http(_tableparams); http ('><TR><TD COLSPAN=2>');
  http('<A HREF="regedit.vsp');
  http("WS"."WS"."SPRINT_PARAMS"("WS"."WS"."MERGE_PARAMS"(params, vector('spot', _ctx_key))));
  http('" TARGET="_top" TITLE="'); http_value(_title); http ('"><NOBR>');
  http_value( split_and_decode (aref (_rkey_path, _depth), 0, '%+'));
  http('</NOBR></A></TD></TR>');
}
;

create procedure "DB"."DBA"."VAD_REGEDIT_PRINT_TYPE_SELECT" (
  inout	path		any,
  inout	params		any,
  inout	lines		any,
  in _param_name	varchar,
  in _default_value	varchar
)
{
  declare _type_ctr	integer;
  declare _type_name	varchar;
  http (concat ('<SELECT NAME="', _param_name, '">"'));
  _type_ctr := 0;
  while (_type_ctr < 6)
    {
      _type_name := aref (vector ('(deleted)', 'STRING', 'INTEGER', 'KEY', 'URL', 'XML'), _type_ctr);
      http ('<OPTION');
      if ((_type_name = _default_value) or ((_type_ctr = 0) and (_default_value is null)))
	http (' SELECTED');
      http ('>');
      http (_type_name);
      http ('</OPTION>');
      _type_ctr := _type_ctr + 1;
    }
  http('</SELECT>');
};

