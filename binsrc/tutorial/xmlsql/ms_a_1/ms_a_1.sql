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
create procedure dump_large_text(inout _text varchar)
{
  declare _strings any;
  declare _slen, _sctr any;
  declare STRG varchar;
  result_names(STRG);
  _strings := split_and_decode (_text,0,'\0\0\n');
  _slen := length (_strings);
  _sctr := 0;
  while (_sctr < _slen)
    {
      result (aref (_strings, _sctr));
      _sctr := _sctr+1;
    }
}
;

create procedure load_mssql_xsd (in _file varchar, in _base varchar)
{
  dump_large_text (
    concat (_base, _file, '\n',
    xml_load_mapping_schema_decl (
      _base,
      _file,
      'UTF-8',
      'x-any' ) ) );
}
;

create procedure load_ms_a_xsd_files ()
{
  if (registry_get ('ms_a_xsd_files') = '$Id: ')
    return;
  load_mssql_xsd ('Customer_Order.xsd', TUTORIAL_XSL_DIR() || '/tutorial/xmlsql/ms_a_1/');
  load_mssql_xsd ('EmpSchema.xsd', TUTORIAL_XSL_DIR() || '/tutorial/xmlsql/ms_a_1/');
  load_mssql_xsd ('CustOr_constant.xsd', TUTORIAL_XSL_DIR() || '/tutorial/xmlsql/ms_a_1/');
  load_mssql_xsd ('Cust_Order_attr.xsd', TUTORIAL_XSL_DIR() || '/tutorial/xmlsql/ms_a_1/');
  load_mssql_xsd ('Cust_Order_OD.xsd', TUTORIAL_XSL_DIR() || '/tutorial/xmlsql/ms_a_1/');
  load_mssql_xsd ('Cat_Product.xsd', TUTORIAL_XSL_DIR() || '/tutorial/xmlsql/ms_a_1/');
  registry_set ('ms_a_xsd_files', '$Id: ');
}
;

load_ms_a_xsd_files ();
