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
-- DB.DBA.OPENXML_DEFINE (viewname, tablename, datacolumn, xpath_expression, metadata)
-- creates a procedure view over an XML content
-- Parameters:
-- viewname - name of procedure view to be created
-- tablename - name of source table containing the XML documents
--             (if null the datacolumns should be valid XML document)
-- datacolumn - column which contains the XML document or valid XML document if tablename is null
-- xpath_expression - expression to extract the XML
--

create procedure
DB.DBA.OPENXML_DEFINE (in vname varchar, in tb varchar, in data varchar, in xp varchar, in meta any)
{
  declare _vname, pname, vdef, pdef, msg, stat, n0, n1, n2, cols, defs, rnames1, tcols varchar;
  declare mod, i, l integer;
  declare xps, rnames, elm any;
  mod := 0;

  if (tb is null)
    tb := vname;

  tb := complete_table_name (tb, 1);
  vname := complete_table_name (vname, 1);

  if (tb is not null and exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = tb))
    {
      if (not exists (select 1 from SYS_COLS where \TABLE = tb and \COLUMN = data))
	signal ('42S22', 'The data column does not exist', 'XV005');
      mod := 1;
    }

  if (exists (select 1 from DB.DBA.SYS_VIEWS where V_NAME = vname))
    signal ('42S01', 'The XML procedure view already exists', 'XV004');


  if (not mod and xml_tree (data, 0) is null)
    signal ('22023', 'The table does not exist and data is not valid XML', 'XV001');

  if (not isarray (meta))
    signal ('22023', 'The metadata is not supplied', 'XV002');

  n0 := name_part (tb, 0);
  n1 := name_part (tb, 1);
  n2 := name_part (tb, 2);

  xps := vector(); rnames := vector (); defs := ''; cols := '('; rnames1 := ''; tcols := '';
  i := 0; l := length (meta);
  while (i < l)
    {
      elm := meta[i];
      if (not isarray (elm) or length (elm) < 1)
	signal ('22023', 'The metadata is not valid', 'XV003');
      if (length (elm) >= 2)
	{
	  if (length (elm) = 2)
	    xps := vector_concat (xps, vector (elm[0]));
	  else
	    xps := vector_concat (xps, vector (elm[2]));
	  rnames := vector_concat (rnames, vector (elm[0]));
	}
      rnames1 := concat (rnames1, elm[0], ',');
      if (length (elm) > 1)
	{
	  cols := concat (cols, sprintf ('%s %s,', elm[0], elm[1]));
          defs := concat (defs, sprintf ('declare %s %s;\n', elm [0], elm [1]));
	}
      else
	{
          declare ctype varchar;
	  if (tb is not null and not exists (select 1 from SYS_COLS where \TABLE = tb and \COLUMN = elm[0]))
	    signal ('42S22', 'The column does not exist', 'XV005');
	  select dv_type_title (COL_DTP) into ctype from SYS_COLS where \TABLE = tb and \COLUMN = elm[0];
	  cols := concat (cols, sprintf ('%s %s,', elm[0], ctype));
          tcols := concat (tcols, elm [0], ',');
	}
      i := i + 1;
    }
  aset (cols, length(cols) - 1, ascii(')'));
  aset (rnames1, length(rnames1) - 1, ascii(' '));
  vname := sprintf ('"%I"."%I"."%I"', n0, n1, name_part (vname, 2));
  pname := sprintf ('"%I"."%I"."%s_OPENXML_PROC__"', n0, n1, DB.DBA.SYS_ALFANUM_NAME(name_part (vname, 2)));
  vdef := sprintf ('CREATE PROCEDURE VIEW %s AS %s() %s', vname, pname, cols);
  if (not mod)
    {
      pdef := sprintf ('CREATE PROCEDURE %s ()\n{ declare idoc, res any;\ndeclare i, l integer;\n%s\n',
		pname, defs);
      pdef := concat (pdef, sprintf ('idoc := xml_tree_doc (''%s'');\n', data));
      pdef := concat (pdef, sprintf ('res := xpath_eval (''%s'', idoc, 0);\n', xp));
      --pdef := concat (pdef, sprintf ('result_names (%s);\n', rnames1));
      pdef := concat (pdef, 'i:=0; l:=length(res);\n');
      pdef := concat (pdef, 'while (i < l) {\n');
      i := 0; l := length (xps);
      while (i < l)
	{
          pdef := concat (pdef, sprintf ('%s := xpath_eval (''%s'', res[i], 1);\n',rnames[i],xps[i]));
          i := i + 1;
	}
      pdef := concat (pdef, sprintf ('i := i + 1;\nresult (%s);\n}\n', rnames1));
      pdef := concat (pdef, '\n}\n');
    }
  else
    {
      pdef := sprintf ('CREATE PROCEDURE %s ()\n{ %s\n', pname, defs);
      --pdef := concat (pdef, sprintf ('result_names (%s);\n', rnames1));
      pdef := concat (pdef,
	sprintf ('for select %s res from "%I"."%I"."%I" where xpath_contains ("%I", ''%s'', res) do {\n',
		  tcols, n0, n1, n2, data, xp));
      i := 0; l := length (xps);
      while (i < l)
	{
          pdef := concat (pdef, sprintf ('%s := xpath_eval (''%s'', res, 1);\n',rnames[i],xps[i]));
          i := i + 1;
	}
      pdef := concat (pdef, sprintf ('result (%s);\n}\n', rnames1));
      pdef := concat (pdef, '\n}\n');
    }
  -- make a procedure and view
  stat := '00000';
  exec (pdef, stat, msg);
  if (stat <> '00000')
    signal ('22023', 'Bad datatype in metadata', 'XV006');
  stat := '00000';
  exec (vdef, stat, msg);
  if (stat <> '00000')
    signal (stat, msg);
}
;

