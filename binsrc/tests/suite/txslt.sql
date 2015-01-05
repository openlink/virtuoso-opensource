--  
--  $Id: txslt.sql,v 1.5.10.2 2013/01/02 16:15:37 source Exp $
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
create procedure DO_XSLT (in _xml varchar, in _xsl varchar)
{
  declare _ses, _tree any;
  declare _content, _res, _r_name varchar;
  _ses := string_output ();
  http (concat ('\n============ ' , _xml, ' <- ', _xsl, '============\n'), _ses);
  select blob_to_string (RES_CONTENT), RES_NAME
      into _content, _r_name from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _xml;
  _tree := xslt (concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', _xsl),
	       xml_tree_doc (xml_tree (_content)));
  http_value (_tree, 0, _ses);
  http (concat ('\n============ END ============\n'), _ses);
  _res := string_output_string (_ses);
  string_to_file ('txslt.result', _res, -1);
  return _res;
}

create procedure DO_DAV_XSLT_SH (in f varchar)
{
 declare _res varchar;
 _res := '';
 for select a.RES_FULL_PATH as xml_doc, b.RES_FULL_PATH as xsl_sheet
   from WS.WS.SYS_DAV_RES a, WS.WS.SYS_DAV_RES b
   where a.RES_FULL_PATH like '%xslsamples%.xml'
         and b.RES_FULL_PATH like '%xslsamples%.xsl'
	 and a.RES_COL = b.RES_COL order by a.RES_ID do
	 {
           _res := concat ( _res, 'ISQL DS1 dba dba "EXEC=DO_XSLT (''', xml_doc,''', ''', xsl_sheet,''')" ERRORS=stdout >> LOG\n');
	 }
  string_to_file (f, _res, 0);
}

create procedure DAV_RES_UPLOAD (in _ppath varchar, in _time datetime, in __own varchar, in __grp varchar,
    in _perms varchar, in _type varchar, in _content any)
{
  declare _c_id integer;
  declare _name varchar;
  declare _path, _ses any;
  declare _ix, _len integer;
  declare _own, _grp integer;

  if (isstring (_content))
    _ses := _content;
  else if (__tag (_content) = 193)
    {
      _len := length (_content);
      _ses := string_output ();
      _ix := 0;
      while (_ix < _len)
	{
	  http (aref (_content, _ix), _ses);
          _ix := _ix + 1;
	}
    }
  else
    _ses := null;

--  dbg_obj_print ('RES INS: ', _ppath);
  if (not isstring (_ppath) and __tag (_ppath) <> 193)
    signal ('.....', 'Function DAV_RES_I needs string or array as path');
  if (isstring (_ppath))
    _path := WS.WS.HREF_TO_ARRAY (_ppath, '');
  else
    _path := _ppath;
  if (length (_path) < 1)
    signal ('.....', 'The first parameter is not valid path string');
  WS.WS.FINDCOL (WS.WS.PARENT_PATH (_path), _c_id);
  if (not WS.WS.ISCOL (WS.WS.PARENT_PATH (_path)))
    signal ('.....', 'Non-existing collection');
  _name := aref (_path, length (_path) - 1);

  declare own, grp varchar;
  own := null; grp := null;
  whenever not found goto nfuser;
  select TI_DAV_USER, TI_DAV_GROUP into own, grp from DB.DBA.SYS_TP_ITEM where
     TI_TYPE = 1 and TI_ITEM = substring (_ppath, 1, length (TI_ITEM));
nfuser:

  if (own is null)
     _own := coalesce ((select U_ID from WS.WS.SYS_DAV_USER where U_NAME = __own), 0);
  else
     _own := coalesce ((select U_ID from WS.WS.SYS_DAV_USER where U_NAME = own), 0);

  if (grp is null)
    _grp := coalesce ((select G_ID from WS.WS.SYS_DAV_GROUP where G_NAME = __grp), 0);
  else
    _grp := coalesce ((select G_ID from WS.WS.SYS_DAV_GROUP where G_NAME = grp), 0);

  if (_grp = 0 and __grp <> '' and own is null)
    {
      _grp := DAV_ADD_GROUP_INT (__grp);
    }
  if (_own = 0 and __own <> '' and grp is null)
    {
      _own := DAV_ADD_USER_INT (__own, __own, __grp, '110110110R', 1, NULL, 'REPLICATION', NULL);
    }

  insert into WS.WS.SYS_DAV_RES (RES_ID, RES_NAME, RES_CR_TIME, RES_MOD_TIME,
      RES_OWNER, RES_GROUP, RES_PERMS, RES_TYPE, RES_CONTENT, RES_FULL_PATH, RES_COL)
      values (WS.WS.GETID ('R'), _name, _time, _time, _own, _grp, _perms, _type, _ses, _ppath, _c_id);
  return;
}
;

