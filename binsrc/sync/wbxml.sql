--  
--  $Id$
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
create procedure wbxml_getbyte (inout _wbsrc varchar, inout _pos integer)
  returns integer
{
  declare _b integer;
  _b := _wbsrc[_pos];
  _pos := _pos + 1;
  return _b;
}
;

create procedure wbxml_getint (inout _wbsrc varchar, inout _pos integer)
  returns integer
{
  declare _b integer;
  declare _res integer;

  _b := wbxml_getbyte (_wbsrc, _pos);
  _res := bit_and (_b, 127); -- 0x7f

  while (bit_and (_b, 128))  -- 0x80
    {
      _b := wbxml_getbyte (_wbsrc, _pos);
      _res := bit_shift (_res, 7) + bit_and (_b, 127);
    }
  return _res;
}
;

create procedure wbxml_getint_test (in _wbsrc varchar, in _pos integer)
  returns integer
{
  return wbxml_getint (_wbsrc, _pos);
}
;

create procedure wbxml_gettbl (inout _wbsrc varchar, inout _pos integer)
  returns any
{
  declare _tbllen integer;
  _tbllen := wbxml_getint (_wbsrc, _pos);
  --dbg_printf ('wxbml_gettbl: length %#x', _tbllen);

  -- start of string table
  declare _start integer;
  _start := _pos;

  -- string table
  declare _tbl any;
  _tbl := vector();

  declare _b integer;
  declare _strstart integer;
  declare _curstr varchar;
  _curstr := null;
  _strstart := _pos - _start;
  while (_pos < _start + _tbllen)
    {
      _b := wbxml_getbyte(_wbsrc, _pos);
      if (_b = 0)
        {
          if (_curstr is not null)
            {
              _tbl := vector_concat (_tbl, vector (_strstart, _curstr));
              _curstr := null;
            }
          _strstart := _pos - _start;
        }
      else
        _curstr := concat (_curstr, chr (_b));
    }
  if (_curstr is not null)
    _tbl := vector_concat (_tbl, vector (_strstart, _curstr));
  return _tbl;
}
;

create procedure wbxml_syncml_tags()
{
  return vector (
      'Add', 5,               -- 0x05
      'Alert', 6,             -- 0x06
      'Archive', 7,           -- 0x07
      'Atomic', 8,            -- 0x08
      'Chal', 9,              -- 0x09
      'Cmd', 10,              -- 0x0a
      'CmdID', 11,            -- 0x0b
      'CmdRef', 12,           -- 0x0c
      'Copy', 13,             -- 0x0d
      'Cred', 14,             -- 0x0e
      'Data', 15,             -- 0x0f
      'Delete', 16,           -- 0x10
      'Exec', 17,             -- 0x11
      'Final', 18,            -- 0x12
      'Get', 19,              -- 0x13
      'Item', 20,             -- 0x14
      'Lang', 21,             -- 0x15
      'LocName', 22,          -- 0x16
      'LocURI', 23,           -- 0x17
      'Map', 24,              -- 0x18
      'MapItem', 25,          -- 0x19
      'Meta', 26,             -- 0x1a
      'MsgID', 27,            -- 0x1b
      'MsgRef', 28,           -- 0x1c
      'NoResp', 29,           -- 0x1d
      'NoResults', 30,        -- 0x1e
      'Put', 31,              -- 0x1f
      'Replace', 32,          -- 0x20
      'RespURI', 33,          -- 0x21
      'Results', 34,          -- 0x22
      'Search', 35,           -- 0x23
      'Sequence', 36,         -- 0x24
      'SessionID', 37,        -- 0x25
      'SftDel', 38,           -- 0x26
      'Source', 39,           -- 0x27
      'SourceRef', 40,        -- 0x28
      'Status', 41,           -- 0x29
      'Sync', 42,             -- 0x2a
      'SyncBody', 43,         -- 0x2b
      'SyncHdr', 44,          -- 0x2c
      'SyncML', 45,           -- 0x2d
      'Target', 46,           -- 0x2e
      'TargetRef', 47,        -- 0x2f
      'Reserved', 48,         -- 0x30
      'VerDTD', 49,           -- 0x31
      'VerProto', 50,         -- 0x32
      'NumberOfChanges', 51,  -- 0x33
      'MoreData', 52          -- 0x34
  );
}
;

create procedure wbxml_metinf_tags()
{
  return vector (
      'Anchor', 5,        -- 0x05
      'EMI', 6,           -- 0x06
      'Format', 7,        -- 0x07
      'FreeID', 8,        -- 0x08
      'FreeMem', 9,       -- 0x09
      'Last', 10,         -- 0x0a
      'Mark', 11,         -- 0x0b
      'MaxMsgSize', 12,   -- 0x0c
      'Mem', 13,          -- 0x0d
      'MetInf', 14,       -- 0x0e
      'Next', 15,         -- 0x0f
      'NextNonce', 16,    -- 0x10
      'SharedMem', 17,    -- 0x11
      'Size', 18,         -- 0x12
      'Type', 19,         -- 0x13
      'Version', 20       -- 0x14
  );
}
;

create procedure wbxml_devinf_tags()
{
  return vector (
      'CTCap', 5,                   -- 0x05
      'CTType', 6,                  -- 0x06
      'DataStore', 7,               -- 0x07
      'DataType', 8,                -- 0x08
      'DevID', 9,                   -- 0x09
      'DevInf', 10,                 -- 0x0a
      'DevTyp', 11,                 -- 0x0b
      'DisplayName', 12,            -- 0x0c
      'DSMem', 13,                  -- 0x0d
      'Ext', 14,                    -- 0x0e
      'FwV', 15,                    -- 0x0f
      'HwV', 16,                    -- 0x10
      'Man', 17,                    -- 0x11
      'MaxGUIDSize', 18,            -- 0x12
      'MaxID', 19,                  -- 0x13
      'MaxMem', 20,                 -- 0x14
      'Mod', 21,                    -- 0x15
      'OEM', 22,                    -- 0x16
      'ParamName', 23,              -- 0x17
      'PropName', 24,               -- 0x18
      'Rx', 25,                     -- 0x19
      'Rx-Pref', 26,                -- 0x1a
      'SharedMem', 27,              -- 0x1b
      'Size', 28,                   -- 0x1c
      'SourceRef', 29,              -- 0x1d
      'SwV', 30,                    -- 0x1e
      'SyncCap', 31,                -- 0x1f
      'SyncType', 32,               -- 0x20
      'Tx', 33,                     -- 0x21
      'Tx-Pref', 34,                -- 0x22
      'ValEnum', 35,                -- 0x23
      'VerCT', 36,                  -- 0x24
      'VerDTD', 37,                 -- 0x25
      'Xnam', 38,                  -- 0x26
      'Xval', 39,                   -- 0x27
      'UTC', 40,                    -- 0x28
      'SupportNumberOfChanges', 41, -- 0x29
      'SupportLargeObjs', 42        -- 0x2a
  );
}
;

create procedure wbxml_gettags (in _pubid integer, in _cp integer)
{
  declare _tags any;
  _tags := null;
  if (_pubid = 4049 or _pubid = 4051)
    {
      if (_cp = 0)
        _tags := wbxml_syncml_tags();
      else if (_cp = 1)
        _tags := wbxml_metinf_tags();
    }
  else if (_pubid = 4050 or _pubid = 4052)
    {
      if (_cp = 0)
        _tags := wbxml_devinf_tags();
    }
  -- XXX die if _tags is null
  return _tags;
}
;

create procedure wbxml_getrevtags (in _pubid integer, in _cp integer)
{
  declare _tags, _ret any;
  _tags := wbxml_gettags(_pubid, _cp);

  declare _ix, _len integer;
  _ix := 0;
  _len := length (_tags);
  _ret := make_array (_len, 'any');
  while (_ix < _len)
    {
      _ret[_ix] := _tags[_ix + 1];
      _ret[_ix + 1] := _tags[_ix];
      _ix := _ix + 2;
    }
  return _ret;
}
;

create procedure wbxml_getnode (
    in _b integer, inout _wbsrc varchar, inout _pos integer,
    inout _strtab any, inout _pubid integer, inout _tags any)
{
  declare _tag integer;
  declare _tagname varchar;

  again:

  if (_b = 0)         -- SWITCH_PAGE (0x00)
    {
      declare _cp integer;
      _cp := wbxml_getbyte (_wbsrc, _pos);
      --dbg_printf ('wbxml_getnode: SWITCH_PAGE: pubid %#x, cp %#x', _pubid, _cp);
      _tags := wbxml_getrevtags (_pubid, _cp);
      --dbg_obj_print (_tags);

      _b := wbxml_getbyte (_wbsrc, _pos);
    }

  if (_b = 3)         -- STR_I (0x03)
    {
      declare _str varchar;
      _str := '';
      while ((_b := wbxml_getbyte (_wbsrc, _pos)) <> 0) -- END
        _str := concat (_str, chr (_b));
      --dbg_printf ('wbxml_getnode: STR_I: [%s]', _str);
      return _str;
    }
  else if (_b = 131)  -- STR_T (0x83)
    {
      declare _ix integer;
      _ix := wbxml_getint (_wbsrc, _pos);

      declare _str varchar;
      _str := get_keyword (_ix, _strtab);
      -- XXX die if _str is null
      --dbg_printf ('wbxml_getnode: STR_T: [%s]', _str);
      return _str;
    }
  else if (_b = 195)  -- OPAQUE (0xc3)
    {
      declare _len integer;
      _len := wbxml_getint (_wbsrc, _pos);

      declare _str varchar;
      _str := substring (_wbsrc, _pos + 1, _len);
      --dbg_printf ('wbxml_getnode: OPAQUE len=%d: [%s]', _len, _str);
      _pos := _pos + _len;
      -- XXX hack
      if (_str[0] = 2)
        {
	  --_pos := _pos + 1;
	  --_b := wbxml_getint (_wbsrc, _pos);
	  --dbg_obj_print ('ENTITY', _b);
	  --dbg_obj_print ('ENTITY');
	  return wbxml2xml (_str, 0);
	  --goto again;
	}
      return _str;
    }
  else
    {
      ; --dbg_printf ('_b=%#x', _b);
    }


  _tag := bit_and (_b, bit_not (128 + 64));
  _tagname := get_keyword (_tag, _tags);
  if (_tagname is null)
    {
      --dbg_obj_print (_tags);
      signal ('XXXXX', sprintf ('Unknown tag %#x at pos: %#x', _tag, _pos), 'YYYYY');
    }
  --dbg_printf ('wbxml_getnode: [%s] [%#x] (%#x)', _tagname, _tag, _pos);

  declare _acc any;
  xte_nodebld_init (_acc);
  if (bit_and (_b, 64))
    {
      -- has elements
      while ((_b := wbxml_getbyte (_wbsrc, _pos)) <> 1) -- END (0x01)
        {
          xte_nodebld_acc (_acc, wbxml_getnode (_b, _wbsrc, _pos, _strtab, _pubid, _tags));
        }
    }
  xte_nodebld_final (_acc, xte_head (_tagname));
  --dbg_printf ('wbxml_getnode: [%s] END (%#x)', _tagname, _pos);
  return _acc;
}
;

create procedure wbxml2xml (in _wbsrc varchar, in trf int := 1)
{
  if (registry_get ('__syncml_debug') = '1' and trf)
    string_to_file ('wbxml'|| cast (msec_time () as varchar) ||'.input', _wbsrc, -2);
  declare _pos integer;
  _pos := 0;

  -- version
  declare _ver integer;
  _ver := wbxml_getbyte (_wbsrc, _pos);
  --dbg_printf ('wbxml2xml: wbxml version %#x', _ver);

  -- publicid
  declare _pubid integer;
  declare _pubidstr varchar;
  declare _pubid_ix integer;
  _pubid := wbxml_getint (_wbsrc, _pos);
  if (_pubid = 0)
    {
      _pubid_ix := wbxml_getint (_wbsrc, _pos);
      --dbg_printf ('wbxml2xml: pubid offset: %#x', _pubid_ix);
    }
  else
    {
      ; --dbg_printf ('wbxml2xml: pubid %#x', _pubid);
      -- XXX should be 0xfd1 (SyncML, MetInf) or 0xfd2 (DevInf)
    }

  -- charset
  declare _cs integer;
  _cs := wbxml_getint (_wbsrc, _pos);
  --dbg_printf ('wbxml2xml: charset %#x', _cs);

  -- string table
  declare _strtab any;
  _strtab := wbxml_gettbl (_wbsrc, _pos);
  --dbg_printf ('wbxml2xml: string_table (end pos %#x)', _pos);
  --dbg_obj_print (_strtab);

  -- determine pubid and codepage
  declare _cp integer;
  declare _tags any;
  if (_pubid = 0)
    {
      _pubidstr := get_keyword (_pubid_ix, _strtab);
      -- XXX die if _pubidstr is null?
      -- dbg_printf ('wbxml2xml: public id [%s]', _pubidstr);
      if (_pubidstr = '-//SYNCML//DTD SyncML 1.0//EN' or
          _pubidstr = '-//SYNCML//DTD SyncML 1.1//EN')
        {

	  if (_pubidstr = '-//SYNCML//DTD SyncML 1.0//EN')
	    connection_set ('SyncML-ver', '1.0');
	  else
	    connection_set ('SyncML-ver', '1.1');

          _pubid := 4049;    -- 0xfd1
          _cp := 0;
        }
      else if (_pubidstr = '-//SYNCML//DTD MetInf 1.0//EN' or
          _pubidstr = '-//SYNCML//DTD MetInf 1.1//EN')
        {
          _pubid := 4049;    -- 0xfd1
          _cp := 1;
        }
      else if (_pubidstr = '-//SYNCML//DTD DevInf 1.0//EN' or
          _pubidstr = '-//SYNCML//DTD DevInf 1.1//EN')
        {
          _pubid := 4050;    -- 0xfd2
          _cp := 0;
        }
    }
  else
    _cp := 0;
  --dbg_printf ('wbxml2xml: pubid %#x, cp %#x', _pubid, _cp);
  _tags := wbxml_getrevtags (_pubid, _cp);
  --dbg_obj_print (_tags);

  declare _b integer;
  declare _node any;
  _b := wbxml_getbyte (_wbsrc, _pos);
  _node := wbxml_getnode (_b, _wbsrc, _pos, _strtab, _pubid, _tags);
  declare _xdoc any;
  if (trf)
    {
      _xdoc := xml_tree_doc (_node);
      if (registry_get ('__syncml_debug') = '1')
        string_to_file ('synclog.xml', serialize_to_UTF8_xml(_xdoc), -1);
      --dbg_obj_print (_xdoc);
      return _xdoc;
    }
  else
    return _node;
}
;

create procedure wbxml_putbyte (inout _out varchar, in _b integer)
{
  declare c varchar;
  c := ' ';
  c[0] := _b;
  _out := concat (_out, c);
}
;

create procedure wbxml_putint (inout _out varchar, in _n integer)
{
  declare _s varchar;
  declare _b integer;
  declare c varchar;

  _b := bit_and (_n, 127);
  c := ' ';
  c[0] := _b;
  _s := c;

  while ((_n := bit_shift (_n, -7)) > 0)
    {
      _b := bit_or (bit_and (_n, 127), 128);    -- continuation bit
      c := ' ';
      c[0] := _b;
      _s := concat (c, _s);
    }
  _out := concat (_out, _s);
}
;

create procedure wbxml_putint_test (in _n integer)
  returns integer
{
  declare _out varchar;
  _out := '';
  wbxml_putint (_out, _n);
  return wbxml_getint_test (_out, 0);
}
;

create procedure wbxml_puttbl (inout _out varchar, inout _strtbl any)
{
  declare _len integer;
  if ((_len := length (_strtbl)) = 0)
    {
      wbxml_putint (_out, 0);
      return;
    }

  declare _tbllen integer;
  _tbllen := _strtbl[_len - 1] + length (_strtbl[_len - 2]);
  wbxml_putint (_out, _tbllen);

  declare _ix integer;
  _ix := 0;
  while (_ix < _len)
    {
      _out := concat (_out, _strtbl[_ix]);      -- string
      _ix := _ix + 2;
      if (_ix < _len)
        wbxml_putbyte (_out, 0);                -- separator
    }
}
;

create procedure wbxml_putnode (
    inout _out varchar, inout _node any,
    inout _curns varchar, inout _tags any, in inline int := 0)
  returns varchar
{
  --dbg_obj_print (_node);

  declare oldns varchar;
  oldns := _curns;
  if (isstring (_node))
    {
      --dbg_printf ('wbxml_putnode: isstring');

      if (_node = chr(10))
        return;

      -- XXX assume it is a string
      if (not inline)
        {
	  wbxml_putbyte (_out, 195);    -- OPAQUE (0xc3)
	  wbxml_putint (_out, length (_node));
	  --dbg_printf ('wbxml_putnode: OPAQUE len=%#x [%s]', length (_node), _node);
	  _out := concat (_out, _node);
        }
      else
        {
	  wbxml_putbyte (_out, 3);  -- STR_I
	  _out := concat (_out, _node);
	  wbxml_putbyte (_out, 0);
	}
    }
  else if (isarray (_node))
    {
      --dbg_printf ('wbxml_putnode: isarray');

      declare _name, _ns varchar;
      declare _pos integer;
      _pos := strrchr (_node[0][0], ':');
      if (_pos is not null)
        {
          _name := subseq (_node[0][0], _pos + 1);
          _ns := subseq (_node[0][0], 0, _pos);
        }
      else
        {
	  declare nspos int;
	  nspos := position ('xmlns', _node[0]);
	  if (nspos > 0)
	    {
	      --dbg_obj_print ('xmlns=', nspos, _node[0][nspos]);
	      _ns := _node[0][nspos];
	    }
	  else
	    _ns := null;
          _name := _node[0][0];
        }

      -- switch wbxml codepages if needed
      if (_ns is not null and _ns <> _curns)
        {
          declare _cp, page integer;

          if (_ns = 'SYNCML:SYNCML1.1' or _ns = 'SYNCML:SYNCML1.0')
	    {
              _cp := 0;
	      page := 4049;
	    }
          else if (_ns = 'syncml:metinf')
	    {
              _cp := 1;
	      page := 4049;
	    }
	  else if (_ns = 'syncml:devinf')
	    {
	      declare str any;
              _cp := 0;
	      page := 4050;
	      str := xml2wbxml (_node, page);
	      --dbg_obj_print (_node);
	      --string_to_file ('devinf.wb', str, -2);
              wbxml_putnode (_out, str, _curns, _tags, inline);
	      return;
	    }
          --- XXX die is _ns is unknown
          wbxml_putbyte (_out, 0);  -- SWITCH_PAGE (0x00)
          wbxml_putbyte (_out, _cp);
          _tags := wbxml_gettags (page, _cp);
          _curns := _ns;
          --dbg_printf ('wbxml_putnode: SWITCH_PAGE %d %d', page, _cp);
          --dbg_obj_print (_tags);
        }
      --dbg_printf ('wbxml_putnode: element [%s], ns [%s]', _name, _curns);

      declare _tag integer;
      _tag := get_keyword (_name, _tags);
      if (_tag is null)
        signal ('22023', sprintf ('Unknown tag ''%s''', _name), 'WB001');

      declare _len integer;
      if ((_len := length (_node)) > 1)
        {
          wbxml_putbyte (_out, bit_or (_tag, 64));    -- has content
          declare _ix integer;
          _ix := 1;
          while (_ix < _len)
            {
              wbxml_putnode (_out, _node[_ix], _curns, _tags, inline);
              _ix := _ix + 1;
            }
          wbxml_putbyte (_out, 1);                    -- END (0x01)
        }
      else
        wbxml_putbyte (_out, _tag);
    }
}
;

create procedure xml2wbxml (in _node any, in page int := 4049)
  returns varchar
{
  -- XXX obtain doctype
  -- XXX should do xml2wbxml recursively on DevInf data

  if (page = 4049 and registry_get ('__syncml_debug') = '1')
    string_to_file ('synclog.xml', serialize_to_UTF8_xml(xml_tree_doc (_node)), -1);

  -- string table contains 'string' -> offset keywords
  declare _tbl any;
  declare _tags any;
  declare _curns varchar;
  declare inline int;
  declare ver any;

  ver := coalesce (connection_get ('SyncML-ver'), '1.1');

  if (page = 4049)
    {
      _tbl := vector (sprintf ('-//SYNCML//DTD SyncML %s//EN', ver), 0);
      _curns := sprintf ('SYNCML:SYNCML%s', ver);
      inline := 0;
    }
  else if (page = 4050)
    {
      _tbl := vector (sprintf ('-//SYNCML//DTD DevInf %s//EN', ver), 0);
      _curns := 'syncml:devinf';
      inline := 1;
    }
  else
    signal ('22023', 'Unknown page');

  _tags := wbxml_gettags (page, 0);
  --dbg_obj_print (_tags);
  --dbg_obj_print (_node);

  -- XXX string table is not generated
  -- check that _node[1] exists
  declare _out varchar;
  _out := '';
  if (_node[0][0] like ' %')
    _node := _node[1];
  wbxml_putnode (_out, _node, _curns, _tags, inline);

  declare _res varchar;
  _res := '';
  wbxml_putbyte (_res, 2);          -- version
  wbxml_putbyte (_res, 0);          -- publicid
  wbxml_putint (_res, 0);           -- offset of string publicid
  wbxml_putint (_res, 106);         -- charset 0x6a (UTF-8)
  wbxml_puttbl (_res, _tbl);
  _res := concat (_res, _out);
  --if (page = 4049)
  --  string_to_file ('xml2wbxml.output', _res, -2);
  return _res;
}
;

