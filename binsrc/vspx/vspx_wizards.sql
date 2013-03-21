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
create procedure
vspx_wz_data_grid (
                    in name varchar,				-- control name
                    in sql_statement varchar,			-- select SQL statement , parameters are :named
		    in parameters any default null,		-- parameters to SQL stmt
		    in key_columns any default null,		-- key columns for update
		    in editable integer default 0,		-- is editable
		    in edit_button varchar default null,	-- name of edit button if edit
		    in delete_button varchar default null,	-- name of delete button if delete
		    in add_button varchar default null,		-- name of add button if
		    in cursor_type varchar default 'dynamic',	-- cursor type
		    in lines integer default 10,		-- no of lines
		    in style varchar default 'table',		-- style of grid : table, ul, ol, p
		    in scroll_up_label varchar default '<<',	-- scrolling buttons labels
		    in scroll_down_label varchar default '>>',	-- ^^^
		    in column_heading integer default 1,	-- column heading enabled ?
		    in table_name varchar default null		-- name of table to update
                  )
{
  declare tb_meta, cols any;
  declare stat, msg varchar;
  declare i, l int;
  declare res varchar;

  res := string_output ();

  stat := '00000';
  exec_metadata (sql_statement, stat, msg, tb_meta);
  if (stat <> '00000') -- for now we'll just signal
    signal (stat, msg);

  tb_meta := tb_meta[0];
  i := 0; l := length (tb_meta);
  while (i < l)
    {
      if (table_name is null)
       table_name := sprintf ('%s.%s.%s', tb_meta[i][7], tb_meta[i][9], tb_meta[i][10]);
      i := l;
    }

  http (sprintf ('<v:data-grid name="%s" nrows="%d" sql="%s" scrollable="1" cursor-type="%s" edit="%d">\n',
	   name, lines, sql_statement, cursor_type, editable), res);

  i := 0; l := length (tb_meta); cols := make_array (l, 'any');
  while (i < l)
    {
      http (sprintf ('<v:column name="%s"/>\n', tb_meta[i][0]), res);
      aset (cols, i, upper (tb_meta[i][0]));
      i := i + 1;
    }

  i := 0; l := length (parameters);
  while (i < l)
    {
      http (sprintf ('<v:param name="%s" value="%s" />\n', parameters[i], parameters[i+1]), res);
      i := i + 2;
    }

  -- frame template

  http ('\n\n<!-- frame template -->\n', res);

  http (sprintf ('<v:template name="%s_frame" type="frame">\n<p><v:error-summary /></p>\n', name),
        res);

  http (vspx_wz_print_tag ('table', style, vector ('WIDTH','30%','BORDER','1','CELLPADDING','0','CELLSPACING','0')), res);

  if (column_heading)
    {
      http (vspx_wz_print_tag ('tr', style), res);
      if (editable)
	{
          http (vspx_wz_print_tag ('th', style), res);
	  http ('Action', res);
          http (vspx_wz_print_tag ('/th', style), res);
	}
      i := 0; l := length (tb_meta);
      while (i < l)
	{
          http (vspx_wz_print_tag ('th', style), res);
	  http (sprintf ('<v:label name="label_%d_heading" value="--(control.vc_parent as vspx_data_grid).dg_row_meta[%d]" format="%s"/>', i, i, '%s'), res);
          http (vspx_wz_print_tag ('/th', style), res);
	  i := i + 1;
	}
      http (vspx_wz_print_tag ('/tr', style), res);
    }

  http ('<v:rowset />\n', res);
  if (editable and add_button is not null)
    http ('<v:form type="add"/>\n', res);

  http (vspx_wz_print_tag ('tr', style), res);
  if (editable)
    {
      http (vspx_wz_print_tag ('td', style), res);
      http ('&amp;nbsp;', res);
      http (vspx_wz_print_tag ('/td', style), res);
    }

  http (vspx_wz_print_tag ('td', style), res);
  http (sprintf ('<v:button name="%s_prev" action="simple" value="%V" />',
	name, scroll_up_label), res);
  http (vspx_wz_print_tag ('/td', style), res);

  http (vspx_wz_print_tag ('td', style), res);
  http (sprintf ('<v:button name="%s_next" action="simple" value="%V" />\n',
	name, scroll_down_label), res);
  http (vspx_wz_print_tag ('/td', style), res);

  http (vspx_wz_print_tag ('/tr', style), res);

  http (vspx_wz_print_tag ('/table', style), res);
  http ('</v:template>\n', res);

  -- row template
  http ('\n\n<!-- row template -->\n', res);
  http (sprintf ('<v:template name="%s_row" type="row" name-to-remove="%s" set-to-remove="both">\n', name, style),
        res);
  http (vspx_wz_print_tag ('table', style), res);
  http (vspx_wz_print_tag ('tr', style), res);
  if (editable)
    {
      http (vspx_wz_print_tag ('td', style, vector ('nowrap', 'nowrap')), res);
      if (edit_button is not null)
        http (sprintf ('<v:button name="%s_edit" action="simple" value="%s" />\n', name, edit_button), res);
      if (delete_button)
        http (sprintf ('<v:button name="%s_delete" action="simple" value="%s" />\n', name, delete_button), res);
      http (vspx_wz_print_tag ('/td', style), res);
    }
  i := 0; l := length (tb_meta);
  while (i < l)
    {
      http (vspx_wz_print_tag ('td', style, vector ('nowrap', 'nowrap')), res);
      http (sprintf ('<v:label name="label_%d" value="--(control.vc_parent as vspx_row_template).te_rowset[%d]" format="%s"/>', i, i, '%s'), res);
      http (vspx_wz_print_tag ('/td', style), res);
      i := i + 1;
    }
  http (vspx_wz_print_tag ('/tr', style), res);
  http (vspx_wz_print_tag ('/table', style), res);
  http ('</v:template>\n', res);

  -- empty template
  http ('\n\n<!-- empty template -->\n', res);
  http (sprintf ('<v:template name="%s_empty" type="if-not-exists" name-to-remove="%s" set-to-remove="both">\n', name, style),
        res);
  http (vspx_wz_print_tag ('table', style), res);
  http (vspx_wz_print_tag ('tr', style), res);
  http (vspx_wz_print_tag ('td', style), res);
  http ('No rows selected', res);
  http (vspx_wz_print_tag ('/td', style), res);
  http (vspx_wz_print_tag ('/tr', style), res);
  http (vspx_wz_print_tag ('/table', style), res);
  http ('</v:template>\n', res);

  if (editable)
    {
      if (key_columns is null)
	key_columns := ddl_table_pk_cols (table_name);
      -- update template
      if (edit_button is not null)
        {
          http ('\n\n<!-- update template -->\n', res);
	  http (sprintf ('<v:template name="%s_edit" type="edit">\n',
		name),
		res);
	  http (sprintf (
		'<v:form name="%s_update_form" type="update" table="%s" if-not-exists="insert">\n',
		name, table_name), res);

	  -- LOOP over PK cols
	  i := 0; l := length (key_columns);
	  while (i < l)
	    {
 	      http (sprintf ('<v:key column="%s" value="--(control.vc_parent as vspx_data_grid).dg_current_row.te_rowset[%d]" default="null" />\n',
		    key_columns[i], position (upper (key_columns[i]), cols) - 1), res);
	      i := i + 1;
	    }

	  http (sprintf ('<v:template type="if-exists" name-to-remove="%s" set-to-remove="both">\n', style), res);
	  http (vspx_wz_print_tag ('table', style), res);
	  http (vspx_wz_print_tag ('tr', style), res);
	  http (vspx_wz_print_tag ('td', style), res);
          http (sprintf ('<v:button name="%s_update_button" action="submit" value="Update" />\n<input type="submit" name="cancel" value="Cancel" />\n', name), res);
	  http (vspx_wz_print_tag ('/td', style), res);
	  -- LOOP over columns
	  i := 0; l := length (tb_meta);
	  while (i < l)
	    {
	      http (vspx_wz_print_tag ('td', style), res);
  	      http (sprintf ('<v:update-field name="%s_column_%d_u" column="%s" />\n',
		    name, i, tb_meta[i][0]), res);
	      http (vspx_wz_print_tag ('/td', style), res);
	      i := i + 1;
	    }

	  http (vspx_wz_print_tag ('/tr', style), res);
	  http (vspx_wz_print_tag ('/table', style), res);
	  http ('</v:template>\n', res);

	  http ('</v:form>\n', res);
	  http ('</v:template>\n', res);
	}

      -- add template
      if (add_button is not null)
	{
          http ('\n\n<!-- add template -->\n', res);
	  http (sprintf ('<v:template name="%s_add" type="add">\n', name),
		res);
	  http (sprintf (
		'<v:form name="%s_add_form" type="update" table="%s" if-not-exists="insert">\n',
		name, table_name), res);

	  -- LOOP over PK cols
	  i := 0; l := length (key_columns);
	  while (i < l)
	    {
 	      http (sprintf ('<v:key column="%s" value="--NULL" default="null" />\n', key_columns[i]), res);
	      i := i + 1;
	    }

	  http (sprintf ('<v:template type="if-exists" name-to-remove="%s" set-to-remove="both">\n', style), res);
	  http (vspx_wz_print_tag ('table', style), res);
	  http (vspx_wz_print_tag ('tr', style), res);
	  http (vspx_wz_print_tag ('td', style), res);
          http (sprintf ('<v:button name="%s_add_button" action="submit" value="%s" />', name, add_button), res);
	  http (vspx_wz_print_tag ('/td', style), res);
	  -- LOOP over columns
	  i := 0; l := length (tb_meta);
	  while (i < l)
	    {
	      http (vspx_wz_print_tag ('td', style), res);
  	      http (sprintf ('<v:update-field name="%s_column_%d_a" column="%s" />',
		    name, i, tb_meta[i][0]), res);
	      http (vspx_wz_print_tag ('/td', style), res);
	      i := i + 1;
	    }
	  http (vspx_wz_print_tag ('/tr', style), res);
	  http (vspx_wz_print_tag ('/table', style), res);

	  http ('</v:template>\n', res);

	  http ('</v:form>\n', res);
	  http ('</v:template>\n', res);
	}
    }

  http ('</v:data-grid>\n', res);
  return string_output_string (res);
}
;



create procedure
vspx_wz_print_tag (in tag varchar, in style varchar, in iattrs any default null)
{
  declare res, attrs varchar;
  declare closing, break int;
  closing := 0; break := 0;
  attrs := '';

  if (tag[0] = ascii ('/'))
    {
      closing := 1;
      tag := ltrim (tag, '/');
    }

  if (tag = 'table' or tag = 'tr' or (closing and tag = 'td'))
    break := 1;

  tag :=
  case tag
      when 'table' then
         (
	  case style
	     when 'table' then 'table'
	     when 'ul'    then 'ul'
	     when 'ol'    then 'ol'
	     when 'p'     then 'p'
	     else tag end
	  )
      when 'tr' then
         (
	  case style
	     when 'table' then 'tr'
	     when 'ul'    then 'li'
	     when 'ol'    then 'li'
	     when 'p'     then 'p'
	     else tag end
	  )
      when 'td' then
         (
	  case style
	     when 'table' then 'td'
	     when 'ul'    then ''
	     when 'ol'    then ''
	     when 'p'     then ''
	     else tag end
	  )
      when 'th' then
         (
	  case style
	     when 'table' then 'th'
	     when 'ul'    then ''
	     when 'ol'    then ''
	     when 'p'     then ''
	     else tag end
	  )
      else
         tag
      end;

  res := '';

  declare i, l int;
  i := 0; l := length (iattrs);
  while (i < l)
    {
      attrs := concat (attrs, sprintf (' %s="%s"', iattrs[i], iattrs[i+1]));
      i := i + 2;
    }

  if (tag <> '')
    res := sprintf ('<%s%s%s>%s', case closing when 1 then '/' else '' end, tag, attrs, case when break then '\n' else '' end);

  return res;
}
;
