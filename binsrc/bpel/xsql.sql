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
create function SYS_XSQL_LIB_VERSION ()
{
  return subseq ('
--#$$Id$$',
  4);
}
;

grant execute on SYS_XSQL_LIB_VERSION to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xsql:lib-version',
  fix_identifier_case ('DB.DBA.SYS_XSQL_LIB_VERSION'))
;


create function SYS_XSQL_TRANSLATE_PARAMS_IN_SQL (in txt varchar, in fake_params integer)
{
  declare pairs any;
  declare in_string integer;
  declare res, tail varchar;
  declare param varchar;
  if (txt is null)
    return '';
  txt := cast (txt as varchar);
  in_string := 0;
  res := '';
  tail := txt;
--  dbg_obj_print('\n\nSYS_XSQL_TRANSLATE_PARAMS_IN_SQL has got',txt);
again:
--  dbg_obj_print('in-string=',in_string,'tail=',tail);
  if (in_string)
    {
      pairs := regexp_parse (
        '^(([^''{]|([{][^''{@])|([\\\\].)|([''][''])|(\\n))*)([{]@[a-zA-Z_][a-zA-Z0-9_-]*[}])',
	tail, 0 );
      if (pairs is not null)
        {
--	  dbg_obj_print('pairs=',pairs);
	  param := subseq (tail, pairs[14] + 2, pairs[15] - 1);
	  if (fake_params)
	    param := sprintf ('(''fake value of "page-param-%s"'')', param);
	  else
	    param := sprintf ('(cast ("page-param-%s" as varchar))', param);
	  res := res || subseq (tail, 0, pairs[3]) || ''' || ' ||
	    param || ' || ''';
	  tail := subseq (tail, pairs[1]);
	  goto again;
	}
      pairs := regexp_parse (
        '^((([^''{]|([\\\\].)|(['']['']))+)|[{])',
	tail, 0 );
      if (pairs is not null)
        {
--	  dbg_obj_print('pairs=',pairs);
	  res := res || subseq (tail, 0, pairs[3]);
	  tail := subseq (tail, pairs[1]);
	  goto again;
	}
      if (tail = '')
        signal ('37000', sprintf ('Unterminated string constant in SQL expression in XSQL: %s', txt));
      if (tail[0] <> ''''[0])
        signal ('42000', sprintf ('Internal error (%d) in SYS_XSQL_TRANSLATE_PARAMS_IN_SQL, txt=%s', 1, txt));
      res := res || '''';
      tail := subseq (tail, 1);
      in_string := 0;
      goto again;
    }
  pairs := regexp_parse (
    '^(([^{''-]|([{][^''@{-])|(--[^\\n]*\\n)|(-[^-])|(['']([^''{]|([{][^''@{])|([\\\\].)|(['']['']))*[''])|(\\n))+)',
    tail, 0 );
  if (pairs is not null)
    {
--      dbg_obj_print('pairs=',pairs);
      res := res || subseq (tail, 0, pairs[3]);
      tail := subseq (tail, pairs[1]);
      goto again;
    }
  pairs := regexp_parse (
    '^(--[^\\n]*)\044', tail, 0 );
  if (pairs is not null)
    {
--      dbg_obj_print('pairs=',pairs);
      res := res || tail || '\n';
--      dbg_obj_print('res=',res);
      return res;
    }
  pairs := regexp_parse (
    '^([{]@[a-zA-Z_][a-zA-Z0-9_-]*[}])', tail, 0 );
  if (pairs is not null)
    {
--      dbg_obj_print('pairs=',pairs);
      param := subseq (tail, pairs[2] + 2, pairs[3] - 1);
      if (fake_params)
	param := sprintf ('(''fake value of "page-param-%s"'')', param);
      else
	param := sprintf ('("page-param-%s")', param);
      res := res || param;
      tail := subseq (tail, pairs[1]);
      goto again;
    }
  pairs := regexp_parse (
    '^''([{]@[a-zA-Z_][a-zA-Z0-9_-]*[}])''', tail, 0 );
  if (pairs is not null)
    {
--      dbg_obj_print('pairs=',pairs);
      param := subseq (tail, pairs[2] + 2, pairs[3] - 1);
      if (fake_params)
	param := sprintf ('(''fake value of "page-param-%s"'')', param);
      else
	param := sprintf ('( cast ("page-param-%s" as varchar))', param);
      res := res || param;
      tail := subseq (tail, pairs[1]);
      goto again;
    }
  if (tail = '')
    {
--      dbg_obj_print('res=',res);
      return res;
    }
  if (tail[0] = ''''[0])
    {
      res := res || '''';
      tail := subseq (tail, 1);
      in_string := 1;
      goto again;
    }
  res := res || subseq (tail, 0, 1);
  tail := subseq (tail, 1);
  goto again;
}
;

grant execute on SYS_XSQL_TRANSLATE_PARAMS_IN_SQL to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xsql:translate-params-in-sql',
  fix_identifier_case ('DB.DBA.SYS_XSQL_TRANSLATE_PARAMS_IN_SQL'))
;


create function SYS_XSQL_TRANSLATE_PARAMS_IN_STRLITERAL (in txt varchar)
{
  declare pairs any;
  declare in_string integer;
  declare res, res_addon, tail varchar;
  declare param varchar;
  if (txt is null)
    return '';
  txt := cast (txt as varchar);
  in_string := 0;
  res := '';
  tail := txt;
--  dbg_obj_print('\n\nSYS_XSQL_TRANSLATE_PARAMS_IN_STRLITERAL has got',txt);
again:
--  dbg_obj_print('in-string=',in_string,'tail=',tail);
  pairs := regexp_parse (
    '^(([^{]|([{][^@{])|(\\n))+)',
    tail, 0 );
  if (pairs is not null)
    {
--      dbg_obj_print('pairs=',pairs);
      res_addon := WS.WS.STR_SQL_APOS (subseq (tail, 0, pairs[3]));
      tail := subseq (tail, pairs[1]);
      goto res_add;
    }
  pairs := regexp_parse (
    '^([{]@[a-zA-Z_][a-zA-Z0-9_-]*[}])', tail, 0 );
  if (pairs is not null)
    {
--      dbg_obj_print('pairs=',pairs);
      param := subseq (tail, pairs[2] + 2, pairs[3] - 1);
--      if (fake_params)
--	res_addon := sprintf ('(''fake value of "page-param-%s"'')', param);
--      else
	res_addon := sprintf ('(cast ("page-param-%s" as varchar))', param);
      tail := subseq (tail, pairs[1]);
      goto res_add;
    }
  if (tail = '')
    {
--      dbg_obj_print('res=',res);
      return res;
    }
  res_addon := WS.WS.STR_SQL_APOS (subseq (tail, 0, 1));
  tail := subseq (tail, 1);
  goto res_add;
res_add:
  if ('' <> res)
    res := res || ' || ';
  res := res || res_addon;
  goto again;
}
;

grant execute on SYS_XSQL_TRANSLATE_PARAMS_IN_STRLITERAL to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xsql:translate-params-in-strliteral',
  fix_identifier_case ('DB.DBA.SYS_XSQL_TRANSLATE_PARAMS_IN_STRLITERAL'))
;


create function SYS_XSQL_GET_RESULT_COLS_OF_SELECT (in query varchar)
{
  declare st, msg varchar;
  declare meta, cols, col, acc any;
  declare col_count, col_idx integer;
  query := cast (query as varchar);
  st := '00000';
  msg := 'OK';
  exec_metadata (query, st, msg, meta);
  if (st <> '00000')
    signal (st, msg);
--  dbg_obj_print ('query=',query,'meta=',meta);
  if (1 <> meta[1])
    signal ('42000', 'Select statement expected, not %.1000s', query);
  cols := meta[0];
  col_count := length (cols);
  col_idx := 0;
  xte_nodebld_init (acc);
  while (col_idx < col_count)
    {
      declare col_dtp, is_long integer;
      declare col_type, var_type varchar;
      col := cols[col_idx];
      col_dtp := col[1];
      col_type := dv_type_title (col_dtp);
      if (col_type like 'LONG %')
        {
	  is_long := 1;
	  var_type := subseq (col_type, 5);
	}
      else
        {
	  is_long := 0;
	  var_type := col_type;
	}
      xte_nodebld_acc (acc, xte_node (xte_head ('column',
            'name', col[0], 'col-dtp', cast (col_dtp as varchar),
	    'col-type', col_type, 'var-type', var_type, 'is-long', cast (is_long as varchar),
	    'nullable', cast (col[4] as varchar) ) ) );
      col_idx := col_idx + 1;
    }
  xte_nodebld_final (acc, xte_head (' root'));
--  dbg_obj_print ('acc=',acc);
  return xml_tree_doc (acc);
}
;

grant execute on SYS_XSQL_GET_RESULT_COLS_OF_SELECT to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xsql:get-result-cols-of-select',
  fix_identifier_case ('DB.DBA.SYS_XSQL_GET_RESULT_COLS_OF_SELECT'))
;


create function SYS_XSQL_SPLIT_COLUMN_LIST (in col_list varchar)
{
  col_list := cast (col_list as varchar);
  declare acc, pairs any;
  if (
    regexp_parse (
    '^(([ ]*)(((([a-zA-Z0-9_-]+)|(["][^",]+["]))([ ]*,[ ]*(([a-zA-Z0-9_-]+)|(["][^",]+["])))*)|((([a-zA-Z0-9_-]+)|(["][^",]+["]))([ ]*(([a-zA-Z0-9_-]+)|(["][^",]+["])))*))([ ]*))\044',
    col_list, 0) is null )
    signal ('42000', 'Invalid syntax of column list');
  xte_nodebld_init (acc);
  pairs := vector (0, 0);
  while (pairs is not null)
    {
      pairs := regexp_parse ('(([a-zA-Z0-9_-]+)|(["][^",]+["]))', col_list, pairs[1]);
      if (pairs is not null)
        {
	  declare col_name varchar;
	  col_name := subseq (col_list, pairs[0], pairs[1]);
--	  dbg_obj_print ('col_name=',col_name);
	  if (col_name[0] = '"'[0])
	    col_name := subseq (col_name, 1, length (col_name) - 1);
	  else
	    col_name := fix_identifier_case (col_name);
	  xte_nodebld_acc (acc, xte_node (xte_head ('column', 'name', col_name)));
	}
    }
  xte_nodebld_final (acc, xte_head (' root'));
--  dbg_obj_print ('acc=',acc);
  return xml_tree_doc (acc);
}
;

grant execute on SYS_XSQL_SPLIT_COLUMN_LIST to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xsql:split-column-list',
  fix_identifier_case ('DB.DBA.SYS_XSQL_SPLIT_COLUMN_LIST'))
;



create function SYS_PROCESSXSQL (in rel_uri varchar, in arg_ent any, in "!debug-xslt-srcfile" any, in "!ctx" any)
{
  declare uri, procname, sql_text varchar;
  declare xsql_doc any;
  declare len integer;
  declare xsql_xsd_name, xsql_sheet_name, signature varchar;
  declare src_stat any;
  declare base_uri varchar;

  uri := XML_URI_RESOLVE_LIKE_GET ("!debug-xslt-srcfile", rel_uri);
  base_uri := '';
  procname := uri;
  procname := replace (procname, '/', '!');
  procname := replace (procname, ':', '!');
  procname := replace (procname, '.', '!');
  procname := replace (procname, '-', '!');
  procname := replace (procname, ' ', '!');
  procname := replace (procname, '_', '__');
  procname := replace (procname, '!', '_');
  len := length (procname);
  if (len >= 32)
    procname := concat (md5 (procname), subseq (procname, len-31));
  procname := fix_identifier_case (concat ('DB.', USER, '.XSQL_', procname));

  if (uri like 'file:///%')
    src_stat := file_stat (subseq (uri, 7));
  else if (uri like 'file://%')
    src_stat := file_stat (concat (http_root (), subseq (uri, 6)));
--                   0         1         2         3         4         5
--                   0123456789012345678901234567890123456789012345678901
  else if (uri like 'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:%')
    select RES_MOD_TIME into src_stat from WS.WS.SYS_DAV_RES where RES_FULL_PATH = subseq (uri, 51);
  else 
    {
      base_uri := connection_get ('BPEL/ScriptUrl');
      src_stat := xml_uri_get (base_uri, rel_uri);
      uri := xml_uri_resolve_like_get (base_uri, rel_uri);
    }

--    signal ('42000', 'The URI of an XSQL page should be either ''file://...'' or ''virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:...''');
  signature := serialize (vector (src_stat, SYS_XSQL_LIB_VERSION()));
  if ((registry_get (uri) = signature) and exists (select 1 from SYS_PROCEDURES where P_NAME = procname))
    goto proc_ready;
  if ('0' = registry_get ('__external_xsql_xslt'))
    {
      xsql_xsd_name := 'http://local.virt/xsql.xsd';
      xsql_sheet_name := 'http://local.virt/xsql2virtPL.xsl';
    }
  else
    {
      xsql_xsd_name := BPEL.BPEL.res_base_uri () || 'bpel4ws/1.0/xsql.xsd';
      xsql_sheet_name := BPEL.BPEL.res_base_uri () || 'bpel4ws/1.0/xsql2virtPL.xsl';
    }
  xsql_doc := xtree_doc (XML_URI_GET ('', uri), 0, uri);
--	dbg_obj_print (xsql_doc);
  sql_text := cast (xslt (xsql_sheet_name, xsql_doc, vector ('page-name', uri, 'proc-name', procname)) as varchar);
--  dbg_obj_print (sql_text);
  exec (sql_text);
  registry_set (uri, signature);

proc_ready:
  return call (procname)(arg_ent);
}
;

grant execute on SYS_PROCESSXSQL to public
;

xpf_extension ('processXSQL',
  fix_identifier_case ('DB.DBA.SYS_PROCESSXSQL'))
;

xpf_extension ('http://www.openlinksw.com/virtuoso/bpel:processXSQL',
  fix_identifier_case ('DB.DBA.SYS_PROCESSXSQL'))
;
