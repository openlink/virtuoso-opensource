--
--  bpel_eng.sql
--
--  $Id$
--
--  BPEL Script compilation & utilities
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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

-- the BPEL4WS BASE URI replaced in vad install
create procedure BPEL.BPEL.res_base_uri ()
{
  return 'file://vad/vsp/';
}
;

create procedure BPEL.BPEL.vdir_base ()
{
  if (BPEL.BPEL.res_base_uri () like 'file:%')
    return '/vad/vsp';
  else
    return '/DAV/VAD';
}
;

create procedure DB.DBA.TRANSFORM_XML_TO_TEXT (in a any)
{
        return replace (serialize_to_UTF8_xml (a), '\047', '\\\047');
}
;

create procedure BPEL.BPEL.obj_print (in o any)
{
	;
}
;
create procedure BPEL.BPEL.dbgprintf (in format varchar,
	in x1 any := null,
	in x2 any := null,
	in x3 any := null,
	in x4 any := null,
	in x5 any := null,
	in x6 any := null,
	in x7 any := null
	)
{
	;
}
;

create procedure BPEL.BPEL._encode_base64 (in str varchar)
{
  if (length (str))
    return encode_base64 (str);
  else
    return '';
}
;

grant execute on BPEL.BPEL._encode_base64 to public
;

grant execute on DB.DBA.TRANSFORM_XML_TO_TEXT to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:transform_xml_to_text',
	        fix_identifier_case ('DB.DBA.TRANSFORM_XML_TO_TEXT'))
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:encode_base64',
	        fix_identifier_case ('BPEL.BPEL._encode_base64'))
;

create procedure BPEL.BPEL.format_date (in str varchar)
{
	return substring (str, 1, 19);
}
;

grant execute on BPEL.BPEL.format_date to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:format_date',
                fix_identifier_case ('BPEL.BPEL.format_date'))
;


-- Oracle extension
create procedure BPEL.BPEL.ora_countNodes (in var_name varchar,
	in part_name varchar := null,
	in xpath_expr varchar := null)
{
	declare scope, scope_inst, inst int;
	declare var_val any;
        declare xml_ent, qry any;
	declare xq, nod, txt any;
	declare xmlnss_pre varchar;


	scope := connection_get ('BPEL_scope');
	scope_inst := connection_get ('BPEL_scope_inst');
	xmlnss_pre := connection_get ('BPEL_xmlnss_pre');
	if (xmlnss_pre is null)
	  xmlnss_pre := '';
	inst := connection_get ('BPEL_inst');

	var_val := BPEL..get_var (var_name, inst, scope, scope_inst);

        if (not isentity (var_val) or (length (part_name) = 0 and length (xpath_expr) = 0))
	  return 1;

        -- query is provided as second argument
        if (part_name like '/%' and length (xpath_expr) = 0)
          {
            xpath_expr := part_name;
            part_name := '';
          }
        qry := '';
        if (length (part_name))
	  qry := sprintf ('count (/message/part[@name="%s"]', part_name);
        if (length (xpath_expr))
          qry := concat (qry, xpath_expr);
        if (length (part_name))
	  qry := concat (qry, ')');

	xq := BPEL.BPEL.xpath_evaluate (xmlnss_pre || qry, var_val);
        if (xq is not null)
	  return xq;
	return 0;
}
;


create procedure BPEL.BPEL.getVariableData (in var_name varchar,
	in part_name varchar := null,
	in xpath_expr varchar := null)
{
	declare scope, scope_inst, inst int;
	declare var_val any;
        declare xml_ent, qry any;
	declare ret, xq, nod, txt any;
	declare xmlnss_pre varchar;


	scope := connection_get ('BPEL_scope');
	scope_inst := connection_get ('BPEL_scope_inst');
	xmlnss_pre := connection_get ('BPEL_xmlnss_pre');
	if (xmlnss_pre is null)
	  xmlnss_pre := '';
	inst := connection_get ('BPEL_inst');

	var_val := BPEL..get_var (var_name, inst, scope, scope_inst);

        if (not isentity (var_val) or (length (part_name) = 0 and length (xpath_expr) = 0))
          {
            --dbg_obj_print ('no entity', var_val);
            return var_val;
          }

        -- query is provided as second argument
        if (part_name like '/%' and length (xpath_expr) = 0)
          {
            xpath_expr := part_name;
            part_name := '';
          }
        qry := '';
        if (length (part_name))
          {
            qry := sprintf ('/message/part[@name="%s"]', part_name);
          }

        if (length (xpath_expr))
          qry := concat (qry, xpath_expr);
	else
          qry := concat (qry);

	xq := BPEL.BPEL.xpath_evaluate (xmlnss_pre || qry, var_val);
        ret := null;
        if (xq is not null)
          {
            xq := xml_cut (xq);
            if ((nod := xpath_eval ('*', xq, 0)) is not null and length (nod) = 1)
              ret := xml_cut (nod[0]);
            else if ((txt := xpath_eval ('node()', xq, 0)) is not null and length (txt) = 1)
	      ret := xml_cut (txt[0]);
            else
              ret := xq;
          }
        --dbg_obj_print ('ret:val:',ret);
        --dbg_obj_print ('getvariableData', ret);
	return ret;
noxml:
        --dbg_obj_print ('noxml ret:val:', var_val);
	return var_val;
}
;

create procedure BPEL.BPEL.setVariableData (in var_name varchar,
	in val any,
	in part_name varchar := '',
	in xpath_expr varchar := '')
{
	declare scope, scope_inst, inst int;
	declare xmlnss_pre varchar;

	scope := connection_get ('BPEL_scope');
	scope_inst := connection_get ('BPEL_scope_inst');
	xmlnss_pre := coalesce (connection_get ('BPEL_xmlnss_pre'), '');
	inst := connection_get ('BPEL_inst');

	declare var, qry, xq, sty any;
	var := BPEL..get_var (var_name, inst, scope, scope_inst, 0);
        if (isinteger (val))
          val := cast (val as varchar);

	if (not isentity (var) or (xpath_expr = '' and part_name = ''))
          {
	    BPEL..set_var (var_name, inst, scope, val, scope_inst);
	    return 1;
	  }

        qry := sprintf ('/message/part[@name="%s"]', part_name);

	if (xpath_expr = '' and cast (xpath_eval (qry||'/@style', var) as varchar) = '0')
	  qry := concat (qry, '/', part_name);

        if (xpath_expr <> '')
          qry := concat (qry, xpath_expr);

	--dbg_obj_print (qry);

	qry := concat (xmlnss_pre, qry);
	BPEL..set_value_to_var (qry, val, var);
	BPEL..set_var (var_name, inst, scope, var, scope_inst);
	return 1;
}
;


create procedure BPEL.BPEL.setVariableData (in var_name varchar,
	in val any,
	in part_name varchar := '',
	in xpath_expr varchar := '')
{
	declare scope, scope_inst, inst int;
	declare xmlnss_pre varchar;

	scope := connection_get ('BPEL_scope');
	scope_inst := connection_get ('BPEL_scope_inst');
	xmlnss_pre := coalesce (connection_get ('BPEL_xmlnss_pre'), '');
	inst := connection_get ('BPEL_inst');

	declare var, qry, xq, sty any;
	var := BPEL..get_var (var_name, inst, scope, scope_inst, 0);
        if (isinteger (val))
          val := cast (val as varchar);

	if (not isentity (var) or (xpath_expr = '' and part_name = ''))
          {
	    BPEL..set_var (var_name, inst, scope, val, scope_inst);
	    return 1;
	  }

        qry := sprintf ('/message/part[@name="%s"]', part_name);

	if (xpath_expr = '' and cast (xpath_eval (qry||'/@style', var) as varchar) = '0')
	  qry := concat (qry, '/', part_name);

        if (xpath_expr <> '')
          qry := concat (qry, xpath_expr);

	qry := concat (xmlnss_pre, qry);
	BPEL..set_value_to_var (qry, val, var);
	BPEL..set_var (var_name, inst, scope, var, scope_inst);
	return 1;
}
;


create procedure BPEL.BPEL.getLinkStatus (in linkname varchar)
{
  declare scope, scope_inst, inst, scr, act_id int;
  declare activs, links varbinary;
  declare cr cursor for select bl_act_id from BPEL..links
	where bl_name = linkname and bl_script = scr and bl_act_id <= scope;
  declare inst cursor for select bi_activities_bf, bi_link_status_bf
	from BPEL.BPEL.instance where bi_id = inst;

  scope := connection_get ('BPEL_scope');
  scope_inst := connection_get ('BPEL_scope_inst');
  inst := connection_get ('BPEL_inst');
  scr := connection_get ('BPEL_script_id');

  declare exit handler for not found {
	  return 0;
	};

  open cr (prefetch 1);
  fetch cr into act_id;
  close cr;

  open inst (prefetch 1);
  fetch inst into activs, links;
  close inst;

  if (bit_is_set (activs, act_id) and bit_is_set (links, act_id))
    return 1;
  return 0;
}
;

grant execute on BPEL.BPEL.ora_countNodes to public
;

grant execute on BPEL.BPEL.getVariableData to public
;

grant execute on BPEL.BPEL.getLinkStatus to public
;

xpf_extension ('http://schemas.oracle.com/xpath/extension:countNodes',
	fix_identifier_case ('BPEL.BPEL.ora_countNodes'))
;

xpf_extension ('http://schemas.xmlsoap.org/ws/2003/03/business-process/:getVariableData',
	fix_identifier_case ('BPEL.BPEL.getVariableData'))
;

xpf_extension ('http://schemas.xmlsoap.org/ws/2003/03/business-process/:getLinkStatus',
	fix_identifier_case ('BPEL.BPEL.getLinkStatus'))
;

create procedure BPEL.BPEL.GET_NAMESPACES (in uri varchar, in std any := null)
{
  declare prefs, arr any;
  prefs := connection_get ('BpelNamespaces', vector ());
  if (length (prefs) = 0 and std is not null)
    {
      arr := xpath_eval ('/stub/ns', std, 0);
      foreach (any elm in arr) do
        {
          declare ns, ur any;
          ns := cast (xpath_eval ('@pref', elm) as varchar);
          ur := cast (xpath_eval ('@uri', elm) as varchar);
          --dbg_obj_print ('putNs', ur, ns);
          prefs := vector_concat (prefs, vector (ur, ns));
	}
    }
  if (not position (uri, prefs) and length (uri) > 0)
    {
      --dbg_obj_print ('putNs', uri, length (uri));
      prefs := vector_concat (prefs, vector (uri, sprintf ('ns%d', length (prefs)/2)));
    }
  connection_set ('BpelNamespaces', prefs);
  --dbg_obj_print ('prefs:', prefs);
  return;
}
;

create procedure BPEL.BPEL.GET_ALL_NAMESPACES (in clear int := 0)
{
  declare prefs, ss, i, l any;

  if (clear)
    {
      connection_set ('BpelNamespaces', vector ());
      return;
    }

  ss := string_output ();
  prefs := connection_get ('BpelNamespaces', vector ());
  --dbg_obj_print (prefs);
  http ('<stub>', ss);
  l := length (prefs);
  for (i:=0;i<l;i:=i+2)
    {
      if (length (prefs[i]) > 0)
	http (sprintf ('<ns uri="%s" pref="%s"/>', prefs[i], prefs[i+1]), ss);
    }
  http ('</stub>', ss);
  return xml_tree_doc (xml_tree (ss));
}
;


create procedure BPEL.BPEL.RESOLVE_NAMESPACE (in uri any)
{
  declare prefs, rc any;
  prefs := connection_get ('BpelNamespaces', vector ());
  rc := get_keyword (uri, prefs, '');
  if (length (rc))
    rc := rc || ':';
  --dbg_obj_print (prefs, uri, rc);
  return rc;
}
;

grant execute on BPEL.BPEL.RESOLVE_NAMESPACE to public
;

grant execute on BPEL.BPEL.GET_NAMESPACES to public
;

grant execute on BPEL.BPEL.GET_ALL_NAMESPACES to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:getNamespaces', fix_identifier_case ('BPEL.BPEL.GET_NAMESPACES'))
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:getAllNamespaces', fix_identifier_case ('BPEL.BPEL.GET_ALL_NAMESPACES'))
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:resolveNamespace', fix_identifier_case ('BPEL.BPEL.RESOLVE_NAMESPACE'))
;

create procedure BPEL.BPEL.add_correlation_set (in script int, in qname varchar, in props varchar)
{
  declare idx integer;
  declare propv any;
  declare corr_id int;

  --insert into BPEL.BPEL.correlation_set (css_script, css_qname) values (script, qname);
  --corr_id := identity_value ();

  propv := split_and_decode (props, 0, '\0\0 ');
  idx := 0;
  while (idx < length (propv))
    {
	declare prop any;
	prop := aref (propv, idx);
	idx := idx + 1;
	insert soft BPEL.BPEL.correlation_props (cpp_script, cpp_corr, cpp_prop_name)
               values (script, qname, BPEL..get_nc_name (prop));
    }
}
;


create procedure BPEL.BPEL.dots_strip (in s varchar)
{
	declare colon int;
	colon := strrchr (s, ':');
        if (colon is not null)
           return substring (s, colon+2, length (s));
	else
	   return s;
}
;

create procedure BPEL.BPEL.default_endpoint_base (in host varchar)
{
   if (length (host) = 0)
     host := 'localhost:' || server_http_port();
   return concat ('http://', host, '/BPEL');
}
;

create procedure BPEL.BPEL.vector_push (inout vec any, in elem any, in vector_type varchar:='long')
{
	declare new_vec any;
	new_vec := make_array (length (vec) + 1, vector_type);
	declare idx int;
	idx:=0;
	while (idx < length (vec))
	{
		aset (new_vec, idx, aref (vec, idx));
		idx:=idx+1;
	}
	aset (new_vec, idx, elem);
	return new_vec;
}
;


create constructor method place_expr (in expr varchar) for BPEL.BPEL.place_expr
{
	SELF.bp_query_prefix := BPEL..expr_prefix ();
	SELF.ba_exp := decode_base64(expr);
}
;

create constructor method place_vpa (in v varchar, in part varchar, in query varchar) for BPEL.BPEL.place_vpa
{
	SELF.ba_var := v;
	SELF.ba_part := part;
	SELF.bp_query_prefix := BPEL..expr_prefix ();
	SELF.ba_query := query;
}
;
create constructor method place_vq (in v varchar, in query varchar) for BPEL.BPEL.place_vq
{
	SELF.ba_var := v;
	SELF.bp_query_prefix := BPEL..expr_prefix ();
	SELF.ba_query := query;
}
;
create constructor method place_text (in text varchar) for BPEL.BPEL.place_text
{
	SELF.ba_text := text;
}
;

create constructor method place_plep (in pl varchar, in ep any) for BPEL.BPEL.place_plep
{
  self.ba_pl := pl;
  self.ba_ep := case when ep = 'myRole' then 0 else 1 end;
}
;

create procedure BPEL.BPEL.parse_time_spec (in dt varchar)
{
  declare tm_part_idx,sign, ba_seconds integer;
  declare dt_part varchar;

  tm_part_idx := strchr (dt, 'T');
  dt_part := dt;
  sign := 1;
  ba_seconds := 0;
  if (tm_part_idx is not null)
    {
	declare tm varchar;
	declare secs integer;
	declare regexp any;
	tm := subseq (dt, tm_part_idx);
	secs := 0;
	regexp := regexp_parse ('T([0-9]+H)?([0-9]+M)?([0-9\.]+S)?', tm, 0);
	--dbg_obj_print (regexp);
	if (regexp is null)
	  signal ('BPELX', 'Wrong time duration value');
	if (length (regexp) > 2 and aref (regexp, 2) <> -1)
	  secs := secs + 3600 * atoi (subseq (tm, aref (regexp, 2), aref (regexp, 3)));
	if (length (regexp) > 4 and aref (regexp, 4) <> -1)
	  secs := secs + 60 * atoi (subseq (tm, aref (regexp, 4), aref (regexp, 5)));
	if (length (regexp) > 6 and aref (regexp, 6) <> -1)
	  secs := secs + atoi (subseq (tm, aref (regexp, 6), aref (regexp, 7)));
	ba_seconds := secs;
	dt_part := subseq (dt, 0, tm_part_idx);
    }
  if (dt_part like '-%')
    {
	dt_part := subseq (dt_part, 1);
	sign := -1;
    }
  if (length (dt_part) > 1)
    {
	declare secs integer;
	declare regexp any;
	secs := 0;
	regexp := regexp_parse ('P([0-9]+D)?([0-9]+M)?', dt_part, 0);
	if (regexp is null)
	  signal ('BPELX', 'Wrong date duration value');
	if (aref (regexp, 2) <> -1)
	  secs := secs + 24 * 3600 * atoi (subseq (dt, aref (regexp, 2), aref (regexp, 3)));
	if (aref (regexp, 4) <> -1)
	  secs := secs + 24 * 3600 * 30 * atoi (subseq (dt, aref (regexp, 4), aref (regexp, 5)));
	ba_seconds := ba_seconds + secs;
    }
  ba_seconds := ba_seconds * sign;
  return ba_seconds;
}
;

-- Activity\'s Constructors

create constructor method wait (in dt varchar) for BPEL.BPEL.wait
{
  SELF.ba_type := 'Wait';
  SELF.ba_seconds := BPEL.BPEL.parse_time_spec (dt);
}
;

create constructor method sql_exec (in _text varchar) for BPEL.BPEL.sql_exec
{
	declare uuid varchar;
	uuid := replace (uuid (), '-', '_');
	SELF.ba_type := 'EXEC/SQL';
	SELF.ba_sql_text := decode_base64 (_text);
	SELF.ba_proc_name := concat ('BPEL.BPEL.sql_exec_', uuid);
	EXEC (sprintf ('
		CREATE PROCEDURE BPEL.BPEL.sql_exec_%s (in inst int, in scope int)
		{
			%s
			;
		}', uuid, SELF.ba_sql_text));
}
;

create constructor method java_exec (in _name varchar, in _text varchar, in _imports varchar) for BPEL.BPEL.java_exec
{
	self.ba_type := 'EXEC/Java';
	declare scp_id int;
	declare name, path varchar;
	if (sys_stat ('st_dbms_name') not like '%Java%')
	  signal ('BPELX', 'Compiling BPEL process that contains JAVA code can not be accomplished with server which is not Java enabled.
Please start virtuoso-odbc-javavm-t.exe or other Java enabled server.');
	path := BPEL..get_conf_param ('JavaClassesDir', 'classlib') || '/';
	BPEL..make_dir (path);
	BPEL.BPEL.java_init ();
	if (0)
	  {
	string_to_file (path || '/BpelVarsAdaptor.java',
'public class BpelVarsAdaptor {\n' ||
'    static {\n' ||
'        System.loadLibrary("virtjavaclasses");\n' ||
'    }\n' ||
'    public native Object get_var_data (String var, String part, String query, String vars, String xmlnss);\n' ||
'    public native void set_var_data (String var, String part, String query, Object val, String vars, String xmlnss);\n' ||
'}'
			,-2);
	  }

--	name := _name || ((uuid := replace (uuid(), '-', '_')));
	self.ba_class_name := name := 'bpel_' || replace (uuid (),'-','_') || _name;
	scp_id := connection_get ('BPEL_script_id');
	insert into BPEL.BPEL.hosted_classes (hc_script, hc_name)
		values (scp_id, name);
	declare class_text long varchar;
	class_text := _imports;
	class_text := class_text ||
'public class ' || name  || ' extends BpelVarsAdaptor {\n' ||
'    String variables,\n' ||
'           xmlnss_pre;\n' ||
'    ' || name  || ' (String vars, String _xmlnss_pre)\n' ||
'    {\n' ||
'        xmlnss_pre = _xmlnss_pre;\n' ||
'        variables = vars;\n' ||
'    }\n' ||
'    public String getVariableData (String var, String part, String query)\n' ||
'    {\n' ||
'        return (String) get_var_data (var, part, query, variables, xmlnss_pre);\n' ||
'    }\n' ||
'    public void setVariableData (String var, String part, String query, Object val)\n' ||
'    {\n' ||
'        variables = set_var_data (var, part, query, val, variables, xmlnss_pre);\n' ||
'    }\n' ||
'    public String bpel_eval() throws Exception {\n' ||
'        ' || decode_base64 (_text) || '\n' ||
'        return variables;\n' ||
'    }\n' ||
'}\n'
	;
	declare java_name varchar;
	java_name := name || '.java';
	whenever sqlstate '42000' goto next;
	file_unlink (path || java_name);
  next:
	whenever sqlstate '42000' goto next1;
	file_unlink (path || name || '.class');
  next1:
	whenever sqlstate '42000' default;
	string_to_file (path || java_name, class_text, -2);
	whenever sqlstate '42001' goto nosystem;
	system ('javac ' || path || java_name);
	whenever sqlstate '42001' default;
	declare exit handler for sqlstate '39000' {
	  signal ('BPELX', 'Compilatation of java code for ' || _name || ' failed. Try to call "javac ' || path || java_name || '" for details');
	};
	declare class_res long varbinary;
	class_res := file_to_string ( path || name || '.class');
	update BPEL.BPEL.hosted_classes
		set hc_text = class_res,
		  hc_load_method = 'bpel_eval',
		  hc_path = path || name || '.class'
		where hc_script = scp_id
		  and hc_type = 'java'
		  and hc_name = name;
	file_unlink (path || java_name);
	java_load_class (name);
	return;
nosystem:
	signal ('BPELX', 'The "system" call is disabled, it is needed for use java code in BPEL4WS scripts');
}
;

create procedure BPEL..make_dll_path (in path varchar)
{
  return replace (path, '\\', '/');
}
;

create constructor method clr_exec (in _name varchar, in _text varchar, in _imports varchar, in clr_refs any) for BPEL.BPEL.clr_exec
{
	self.ba_type := 'EXEC/CLR';
	declare scp_id int;
	declare name, path, dllname varchar;
	path := BPEL..get_conf_param ('CLRAssembliesDir');
	if ((sys_stat ('st_dbms_name') not like '%CLR%') and
		(sys_stat ('st_dbms_name') not like '%Mono%'))
	  signal ('BPELX', 'Compiling BPEL process that contains  C# code can not be accomplished with server which is not CLR or Mono  enabled.
Please start virtuoso-odbc-clr-t.exe or other CLR or Mono enabled server.');
	if (path is null)
	  signal ('BPELX', 'CLRAssembliesDir is not configured, please initialize it by the path where Virtuoso image is stored.');
	BPEL..make_dir (http_root() || '/classlib/');
	self.ba_class_name := name := 'bpel_' || replace (uuid (),'-','_') || _name;
	dllname := BPEL..make_dll_path (http_root () || '/classlib/' || name || '.dll');
	scp_id := connection_get ('BPEL_script_id');
	insert into BPEL.BPEL.hosted_classes (hc_script, hc_name)
		values (scp_id, name);
	__dotnet_add_reference (path || '/virt_bpel4ws.dll');
	__dotnet_add_reference (path || '/OpenLink.Data.VirtuosoClient.dll');
	__dotnet_add_reference (path || '/virtclr.dll');
	declare idx int;
	idx := length (clr_refs);
	while ( (idx:=idx-1) >= 0 )
	  {
	    declare _ref varchar;
	    _ref := clr_refs [idx];
	    if ((_ref[0] = '/') or ((length (_ref) > 2) and (_ref[1] = 58))) -- 58 == ':'
		__dotnet_add_reference (_ref);
	    else
		__dotnet_add_reference (path || '/' || _ref);
	  }
	declare class_text long varchar;
	class_text := '\nusing OpenLink.Data.VirtuosoClient;\n' || 'using OpenLink. BPEL4WS;\n'
	  || 'using System.Security.Permissions;\n' || _imports;
	class_text := class_text ||
'[assembly: VirtuosoPermission(SecurityAction.RequestMinimum, Unrestricted=true)]\n' ||
'public class ' || name  || ': BpelVarsAdaptor {\n' ||
'    String variables,\n' ||
'           xmlnss_pre;\n' ||
'    public ' || name  || ' (String _xp, String _v)\n' ||
'    {\n' ||
'	xmlnss_pre = _xp; variables = _v;\n' ||
'    }\n' ||
'    public Object getVariableData (String var, String part, String query)\n' ||
'    {\n' ||
'        return get_var_data (var, part, query, variables, xmlnss_pre);\n' ||
'    }\n' ||
'    public void setVariableData (String var, String part, String query, Object val)\n' ||
'    {\n' ||
'        variables = set_var_data (var, part, query, val, variables, xmlnss_pre);\n' ||
'    }\n' ||
'    public String bpel_eval() {\n' ||
'        ' || decode_base64 (_text) || '\n' ||
'        return variables;\n' ||
'    }\n' ||
'}\n'
	;
	--dbg_obj_print (class_text);
	whenever sqlstate '42000' goto next1;
	file_unlink (dllname);
  next1:
	whenever sqlstate '42000' default;
	--  compilation
	declare res varchar;
	res := cast (aref (__dotnet_compile (dllname, class_text), 0) as varchar);
	--dbg_obj_print (res);
	if (res <> 'OK')
	  signal ('BPELX', 'Compilatation of C# code for ' || _name || ' failed:\n\n' || res);

	update BPEL.BPEL.hosted_classes
	  set hc_text = file_to_string ( dllname),
		  hc_load_method = 'bpel_eval',
		  hc_path = path || name || '.dll'
		where hc_script = scp_id
		  and hc_type = 'CLR'
		  and hc_name = name;
	connection_set ('BPEL_set_qualifiers', 1);
	import_clr (vector (dllname), vector (name), unrestricted=>1);
}
;


create procedure BPEL..expr_prefix ()
{
  declare xpath_pre varchar;
  if ((xpath_pre := connection_get ('BPEL_script_xmlnss')) is not null)
    {
      return xpath_pre;
    }
  return '';
}
;


create procedure BPEL..make_xpath_expr (in expr varchar)
{
  declare xpath_pre varchar;
  if ((xpath_pre := connection_get ('BPEL_script_xmlnss')) is not null)
    {
      return concat (xpath_pre, expr);
    }
  return expr;
}
;

create constructor method while_st (in cond varchar) for BPEL.BPEL.while_st
{
	SELF.ba_type := 'While';
	SELF.ba_condition := BPEL..make_xpath_expr (decode_base64(cond));
}
;

create constructor method switch () for BPEL.BPEL.switch
{
	SELF.ba_type := 'Switch';
}
;
create constructor method case1 (in cond varchar) for BPEL.BPEL.case1
{
	SELF.ba_type := 'Case';
	SELF.ba_condition := BPEL..make_xpath_expr(decode_base64(cond));
}
;


create constructor method otherwise () for BPEL.BPEL.otherwise
{
	SELF.ba_type := 'Otherwise';
}
;

create constructor method assign (inout _from BPEL.BPEL.place) for BPEL.BPEL.assign
{
        SELF.ba_type := 'Assign';
	SELF.ba_from := _from;
}
;

create method add_to (inout _to BPEL.BPEL.place) for BPEL.BPEL.assign
{
	SELF.ba_to := _to;
	return 1;
}
;



-- the inst arg here is actually the script_id
create constructor method node (inout act BPEL.BPEL.activity, in inst int, in parent BPEL.BPEL.node)
	for BPEL.BPEL.node
{
	declare node_id int;
	node_id := sequence_next ('BPEL_NODE_ID');

	self.bn_id := node_id;
	self.bn_parent := -1;
	self.bn_parent_node := parent;
	self.bn_script_id := inst;
	if (parent is null)
          {
	    self.bn_top_node := self;
	    self.bn_parent := -1;
	    self.bn_top_node.bn_cnt := 0;
          }
	else
          {
	    self.bn_parent := parent.bn_id;
	    self.bn_top_node := parent.bn_top_node;
            parent.add_child (self);
          }
	self.bn_top_node.bn_cnt := self.bn_top_node.bn_cnt + 1;
	act.ba_id := self.bn_top_node.bn_cnt;
	if (parent is not null)
	  act.ba_parent_id := parent.bn_activity.ba_id;
	self.bn_activity := act;
	insert into BPEL.BPEL.graph (bg_script_id, bg_node_id, bg_activity) values (inst, node_id, act);
}
;

create constructor method sequence () for BPEL.BPEL.sequence
{
	SELF.ba_type := 'Sequence';
--	SELF.ba_childs := null;
}
;

create constructor method flow () for BPEL.BPEL.flow
{
	SELF.ba_type := 'Flow';
--	SELF.ba_childs := null;
}
;

create constructor method compensate (in _scope varchar) for BPEL.BPEL.compensate
{
	SELF.ba_type := 'Compensate';
	SELF.ba_scope_name := _scope;
}
;

create constructor method scope (in nm varchar) for BPEL.BPEL.scope
{
	SELF.ba_type := 'Scope';
	SELF.ba_name := nm;
}
;
create constructor method scope () for BPEL.BPEL.scope
{
	SELF.ba_type := 'Scope';
	SELF.ba_name := NULL;
}
;

create constructor method compensation_handler () for BPEL.BPEL.compensation_handler
{
	SELF.ba_type := 'CompensationHandler';
}
;

create constructor method compensation_handler_end () for BPEL.BPEL.compensation_handler_end
{
	SELF.ba_type := 'CompensationHandlerEnd';
}
;

create constructor method jump (in act_id int, in node_id int) for BPEL.BPEL.jump
{
   self.ba_type := 'Jump';
   self.ba_act_id := act_id;
   self.ba_node_id := node_id;
}
;

create constructor method link (in name varchar) for BPEL.BPEL.link
{
   self.ba_type := 'Link';
   self.ba_name := name;
}
;

create constructor method empty () for BPEL.BPEL.empty
{
   self.ba_type := 'Empty';
}
;

create constructor method throw (in fault varchar) for BPEL.BPEL.throw
{
   self.ba_type := 'Throw';
   self.ba_fault := fault;
}
;

create constructor method server_failure () for BPEL.BPEL.server_failure
{
  self.ba_type := 'serverFailure';
}
;

create constructor method catch (in fault varchar, in var varchar) for BPEL.BPEL.catch
{
   self.ba_type := 'Catch';
   self.ba_fault := BPEL.BPEL.get_nc_name (fault);
   self.ba_var := var;
}
;

create constructor method fault_handlers () for BPEL.BPEL.fault_handlers
{
	SELF.ba_type := 'FaultHandler';
}
;

create constructor method scope_end (inout events any, in scope_name any, in comps int) for BPEL.BPEL.scope_end
{
	self.ba_type := 'ScopeEnd';
	self.se_events := events;
	self.se_scope_name := scope_name;
	self.se_comp_act := comps;
}
;

create constructor method catch_fault (in nm varchar,
	in var varchar,
	in node_id int) for BPEL.BPEL.catch_fault
{
	SELF.cf_name := BPEL.BPEL.dots_strip (nm);
	SELF.cf_var := var;
	SELF.cf_node_id := node_id;
}
;

create constructor method terminate () for BPEL.BPEL.terminate
{
   self.ba_type := 'Terminate';
}
;

create constructor method pick (in flag varchar) for BPEL.BPEL.pick
{
   self.ba_type := 'Pick';
   self.ba_create_inst := case when flag = 'yes' then 1 else 0 end;
}
;

create constructor method onalarm (in for_exp varchar, in until_exp varchar) for BPEL.BPEL.onalarm
{
   self.ba_type := 'onAlarm';
   self.ba_for_exp := BPEL..make_xpath_expr (decode_base64 (for_exp));
   self.ba_until_exp := BPEL..make_xpath_expr (decode_base64 (until_exp));
   self.ba_seconds := BPEL.BPEL.parse_time_spec (decode_base64 (for_exp));
}
;

create constructor method onmessage
	(
	 in _partner_link	varchar,
	 in _port_type		varchar,
	 in _operation		varchar,
	 in _var		varchar,
	 in _create_inst	varchar,
	 in _corrs 		any,
	 in _one_way 		int
	) for BPEL.BPEL.onmessage
{
	self.ba_type := 'onMessage';
	self.ba_partner_link := _partner_link;
        self.ba_port_type := _port_type;
	self.ba_operation := _operation;
	self.ba_var := _var;
	self.ba_one_way := _one_way;
	self.ba_create_inst := case when _create_inst = 'yes' then 1 else 0 end;
	self.ba_correlations := _corrs;
}
;


create constructor method reply (
                in _partnerLink varchar,
                in _portType varchar,
	        in _operation varchar,
	        in _variable varchar,
	        in _name varchar,
		in _corrs any,
		in _fault any
) for BPEL.BPEL.reply
{
	SELF.ba_type := 'Reply';

	SELF.ba_partnerLink := _partnerLink;
	SELF.ba_portType := _portType;
        SELF.ba_operation := _operation;
	SELF.ba_variable := _variable;
	SELF.ba_name := _name;
	self.ba_correlations := _corrs;
	if (length (_fault))
	  self.ba_fault := _fault;
}
;


create constructor method receive (
		in _name		varchar,
		in _partner_link	varchar,
	        in _port_type	varchar,
		in _operation	varchar,
		in _var		varchar,
		in _create_inst	varchar,
		in _corrs any,
		in _one_way int) for BPEL.BPEL.receive
{
	SELF.ba_type := 'Receive';

	SELF.ba_name := _name;
	SELF.ba_partner_link := _partner_link;
        SELF.ba_port_type := _port_type;
	SELF.ba_operation := _operation;
	SELF.ba_var := _var;
	SELF.ba_one_way := _one_way;
	if (_create_inst = 'yes')
		SELF.ba_create_inst := 1;
	else
		SELF.ba_create_inst := 0;

	SELF.ba_correlations := _corrs;
}
;

create constructor method invoke (in _partnerLink varchar,
                in _portType varchar,
                in _operation varchar,
                in _inputVariable varchar,
		in _outputVariable varchar,
		in _corrs any
		) for  BPEL.BPEL.invoke
{
	SELF.ba_type := 'Invoke';
	SELF.ba_partner_link := _partnerLink;
	SELF.ba_port_type := _portType;
	SELF.ba_operation := _operation;
	SELF.ba_input_var := _inputVariable;
	if (_outputVariable is not null) {
		SELF.is_sync := 1;
		SELF.ba_output_var := _outputVariable;
	} else {
		SELF.is_sync := 0;
	}
	self.ba_correlations := _corrs;
}
;

create method add_child (inout child BPEL.BPEL.node) for BPEL.BPEL.node
{
	if (SELF.bn_childs is not null)
		SELF.bn_childs := BPEL.BPEL.vector_push (SELF.bn_childs, child.bn_id);
	else
		SELF.bn_childs := lvector (child.bn_id);
	return length (SELF.bn_childs);
}
;


create static method new_activity (inout parent BPEL.BPEL.node, in inst int) for BPEL.BPEL.node
{
	declare node BPEL.BPEL.node;

	node := BPEL.BPEL.node (BPEL.BPEL.activity(), inst, parent);
	return node;
}
;

create static method new_compensation_handler (inout parent BPEL.BPEL.node, in inst int) for BPEL.BPEL.node
{
	declare node BPEL.BPEL.node;

	node := BPEL.BPEL.node (BPEL.BPEL.compensation_handler(), inst, parent);
	return node;
}
;

create static method new_fault_handlers (inout parent BPEL.BPEL.node, in inst int) for BPEL.BPEL.node
{
	declare node BPEL.BPEL.node;

	node := BPEL.BPEL.node (BPEL.BPEL.fault_handlers(), inst, parent);

	return node;
}
;

create static method new_compensate (inout parent BPEL.BPEL.node, in inst int, in _scope varchar) for BPEL.BPEL.node
{
	declare node BPEL.BPEL.node;
	node := BPEL.BPEL.node (BPEL.BPEL.compensate(_scope), inst, parent);
	return node;
}
;


create static method new_scope (inout parent BPEL.BPEL.node, in inst int, in nm varchar) for BPEL.BPEL.node
{
	declare node BPEL.BPEL.node;


	if (parent is null)
	  {
	    node := BPEL.BPEL.node (BPEL.BPEL.scope(), inst, parent);
	    if (nm = '__fault') {
		node.bn_parent := -2;
	    } else {
	    	node.bn_parent := -1;
	    }
	  }
	else
	  {
	    if (nm is null) {
	    	node := BPEL.BPEL.node (BPEL.BPEL.scope(), inst, parent);
	    } else {
	       	node := BPEL.BPEL.node (BPEL.BPEL.scope(nm), inst, parent);
	    }
	  }
	return node;
}
;

create static method new_sequence (inout parent BPEL.BPEL.node, in inst int) for BPEL.BPEL.node
{
	declare node BPEL.BPEL.node;

	node := BPEL.BPEL.node (BPEL.BPEL.sequence(), inst, parent);
	return node;
}
;

create static method new_node (inout parent BPEL.BPEL.node,
	inout curr BPEL.BPEL.activity,
	in inst int
	) for BPEL.BPEL.node
{
	declare node BPEL.BPEL.node;
	declare _cints int;

	node := BPEL.BPEL.node (curr, inst, parent);
	return node;
}
;



create static method new_invoke (inout parent BPEL.BPEL.node, in inst int,
	        in _partnerLink varchar,
                in _portType varchar,
                in _operation varchar,
                in _inputVariable varchar,
		in _outputVariable varchar,
		in _corrs any
		) for BPEL.BPEL.node
{
	declare node BPEL.BPEL.node;

	node := BPEL.BPEL.node (BPEL.BPEL.invoke(_partnerLink,_portType,_operation,_inputVariable, _outputVariable, _corrs), inst, parent);
        insert soft BPEL..remote_operation (ro_script, ro_partner_link, ro_operation, ro_port_type)
		values (inst, _partnerLink, _operation, _portType);

	return node;
}
;

create static method new_flow (inout parent BPEL.BPEL.node, in inst int) for BPEL.BPEL.node
{
	declare node BPEL.BPEL.node;
	node := BPEL.BPEL.node (BPEL.BPEL.flow(), inst, parent);
	return node;
}
;




create procedure BPEL.BPEL.store_new_node (inout curr_node BPEL.BPEL.node, inout pmask varbinary, in nodes_cnt int, in current_scope int, in ctx BPEL..comp_ctx)
{
	-- set the serial
	declare act BPEL.BPEL.activity;
        declare internal_id varchar;

        internal_id := ctx.c_internal_id;
	--dbg_obj_print (curr_node.bn_activity.ba_type, ctx.c_event);
	BPEL..set_predecessor_mask (curr_node, ctx.c_event);
	BPEL..set_init_mask (curr_node, nodes_cnt);
	BPEL..set_pickup_mask (curr_node, pmask, ctx.c_tgtlinks, ctx.c_event);

	act := curr_node.bn_activity;
	act.ba_scope := current_scope;
	act.ba_enc_scps := ctx.c_enc_scps;
	act.ba_parent_id := curr_node.bn_parent;
        act.ba_fault_hdl := ctx.c_current_fault;
        act.ba_fault_hdl_bit := ctx.c_current_fault_bit;
	act.ba_is_event := ctx.c_event;
	act.ba_in_comp := ctx.c_in_comp;

	if (length (ctx.c_enc_scps))
	  {
	    declare pscp int;
	    pscp := ctx.c_enc_scps [length (ctx.c_enc_scps) - 1];
	    act.ba_pscope_idx := position (pscp, ctx.c_scopes);
	  }
	else
	  act.ba_pscope_idx := 0;

	act.ba_scope_idx := position (current_scope, ctx.c_scopes);

	act.ba_src_links := ctx.c_srclinks;
	act.ba_tgt_links := ctx.c_tgtlinks;

	act.ba_src_line := ctx.c_src_line;

        if (length (ctx.c_join_cond))
	  act.ba_join_cond := BPEL..make_xpath_expr (decode_base64 (ctx.c_join_cond));
        act.ba_suppress_join_fail := case when ctx.c_supp_join = 'yes' then 1 else 0 end;

        curr_node.bn_activity := act;
	BPEL..set_links (curr_node);
	act := curr_node.bn_activity;

	UPDATE BPEL.BPEL.graph
		SET bg_activity = act,
		bg_childs = curr_node.bn_childs,
		bg_parent = curr_node.bn_parent,
                bg_src_id = internal_id
	WHERE bg_node_id = curr_node.bn_id;
}
;

create procedure BPEL.BPEL.create_new_partner_link (
	in script_id int,
	in name varchar,
	in partner_link_type varchar,
	in my_role varchar,
	in partner_role varchar)
{
   BPEL.BPEL.dbgprintf ('create_new_partner_link %s %s %s %s\n',
	name, partner_link_type, my_role, partner_role);
   insert into BPEL.BPEL.partner_link_init (bpl_script,bpl_name,bpl_partner,bpl_role, bpl_type, bpl_myrole)
	values (
		script_id,
		name,
		null,
		partner_role,
		partner_link_type,
		my_role
	       );

    for select plc_endpoint from BPEL.BPEL.partner_link_conf where plc_name = name do
      {
 	update BPEL.BPEL.partner_link_init set bpl_endpoint = plc_endpoint where bpl_name = name;
      }
}
;

create procedure BPEL.BPEL.get_nc_name (in x varchar)
{
  declare pos int;
  pos := strrchr (x, ':');
  if (pos)
    return subseq (x, pos+1, length (x));
  return x;
}
;

create procedure BPEL.BPEL.get_ns_uri (in x varchar)
{
  declare pos int;
  pos := strrchr (x, ':');
  if (pos)
    return subseq (x, 0, pos);
  return '';
}
;


create procedure BPEL.BPEL.split_ns (in full_name varchar, out ns varchar, out name varchar)
{
	declare inx integer;
	inx := strrchr (full_name, ':');
	if (inx is not null) {
		ns := substring (full_name, 1, inx );
		name := substring (full_name, inx + 2, length (full_name));
	}
}
;

create procedure BPEL.BPEL.my_addr (in script_uri varchar, in host varchar)
{
  if (not length (host))
    host := concat ('localhost:', server_http_port());
  return concat ('http://', host, '/BPELGUI/bpel.vsp?script=', script_uri);
}
;


create procedure BPEL.BPEL.is_null2 (in x any)
{
	if (x is not null) {
		return x;
	} else {
		return '';
	}
}
;

create procedure BPEL.BPEL.is_null (in x any)
{
	if (x is not null) {
		return '*';
	} else {
		return '';
	}
}
;

create procedure BPEL.BPEL.xpath_evaluate (in expr varchar, in doc any)
{
  if (substring (expr, 1, 1) <> '[')
    expr := concat (coalesce (connection_get ('BPEL_xmlnss_pre'), ''), expr);
  if (substring (expr, 1, 1) <> '[')
    expr := concat ('[ xmlns:bpws="http://schemas.xmlsoap.org/ws/2003/03/business-process/" ] ', expr);
  return xpath_eval (expr,doc);
}
;

create procedure BPEL.BPEL.xpath_evaluate0 (in expr varchar)
{
  declare doc any;
  if ((doc := connection_get ('BPEL_dummy_xml')) is null)
    connection_set ('BPEL_dummy_xml', (doc := xtree_doc ('<a/>')));
  return xpath_eval (expr,doc);
}
;




create method http_output (in mode varchar) for BPEL.BPEL.activity
{
        return '';
}
;

create method http_output (in mode varchar) for BPEL.BPEL.while_st
{
        declare _rs varchar;
        _rs := '<node>';
        _rs := sprintf('%s<Ntag><name>Condition:</name><value>%s</value></Ntag>', _rs, SELF.ba_condition);
        _rs := concat(_rs,'</node>');
        return _rs;
}
;
create method http_output (in mode varchar) for BPEL.BPEL.wait
{
        declare _rs varchar;
        _rs := '<node>';
        _rs := sprintf('%s<Ntag><name>For:</name><value>%d</value></Ntag>', _rs, SELF.ba_seconds);
        _rs := concat(_rs,'</node>');
        return _rs;
}
;
create method http_output (in mode varchar) for BPEL.BPEL.sql_exec
{
        declare _rs varchar;
        _rs := '<node>';
        _rs := sprintf('%s<Ntag><name>PL/SQL Text:</name><value><![CDATA[%s]]></value></Ntag>', _rs,SELF.ba_sql_text);
        _rs := concat(_rs,'</node>');
        return _rs;
}
;

create method http_output (in mode varchar) for BPEL.BPEL.java_exec
{
        declare _rs varchar;
        _rs := '<node>';
        _rs := sprintf('%s<Ntag><name>Java class:</name><value><![CDATA[%s]]></value></Ntag>', _rs,SELF.ba_class_name);
        _rs := concat(_rs,'</node>');
        return _rs;
}
;

create method http_output (in mode varchar) for BPEL.BPEL.reply
{
        declare _rs varchar;
        _rs := '<node>';
        _rs := sprintf('%s<Ntag><name>PartnerLink:</name><value>%s</value></Ntag>', _rs, BPEL.BPEL.is_null2 (SELF.ba_partnerLink));
        _rs := sprintf('%s<Ntag><name>portType:</name><value>%s</value></Ntag>', _rs, BPEL.BPEL.is_null2 (SELF.ba_portType));
        _rs := sprintf('%s<Ntag><name>Operation:</name><value>%s</value></Ntag>', _rs, BPEL.BPEL.is_null2 (SELF.ba_operation));
        _rs := sprintf('%s<Ntag><name>Variable:</name><value>%s</value></Ntag>', _rs, BPEL.BPEL.is_null2 (SELF.ba_variable));
        _rs := concat(_rs,'</node>');
        return _rs;
}
;

create method http_output (in mode varchar) for BPEL.BPEL.invoke
{
        declare _rs varchar;
        _rs := '<node>';
        _rs := sprintf('%s<Ntag><name>PartnerLink:</name><value>%s</value></Ntag>', _rs,BPEL.BPEL.is_null2 (SELF.ba_partner_link));
        _rs := sprintf('%s<Ntag><name>portType:</name><value>%s</value></Ntag>', _rs, BPEL.BPEL.is_null2 (SELF.ba_port_type));
        _rs := sprintf('%s<Ntag><name>Operation:</name><value>%s</value></Ntag>', _rs, BPEL.BPEL.is_null2 (SELF.ba_operation));
        _rs := sprintf('%s<Ntag><name>Input Variable:</name><value>%s</value></Ntag>', _rs, BPEL.BPEL.is_null2 (SELF.ba_input_var));
        _rs := sprintf('%s<Ntag><name>Output Variable:</name><value>%s</value></Ntag>', _rs, BPEL.BPEL.is_null2 (SELF.ba_output_var));
        _rs := sprintf('%s<Ntag><name>Name:</name><value>%s</value></Ntag>',_rs,  BPEL.BPEL.is_null2 (SELF.ba_name));
        _rs := concat(_rs,'</node>');
        return _rs;
}
;

create method http_output (in mode varchar) for BPEL.BPEL.case1
{

        declare _rs varchar;
        _rs := '<node>';
        _rs := sprintf('%s<Ntag><name>Condition:</name><value>%s</value></Ntag>', _rs,BPEL.BPEL.is_null2 (SELF.ba_condition));
        _rs := concat(_rs,'</node>');
        return _rs;
}
;

create method http_output (in mode varchar) for BPEL.BPEL.scope
{
        declare _rs varchar;
        _rs := '<node>\n';
        _rs := sprintf('%s<Ntag><name>Parent Scope:</name><value>%s</value></Ntag>\n', _rs,BPEL.BPEL.is_null2 (SELF.ba_parent_scope));
        _rs := sprintf('%s<Ntag><name>Exception:</name><value>%s</value></Ntag>\n', _rs, BPEL.BPEL.is_null2 (SELF.ba_exception));
        _rs := sprintf('%s<Ntag><name>Compensation:</name><value>%s</value></Ntag>\n', _rs, BPEL.BPEL.is_null2 (SELF.ba_compensation));
        _rs := sprintf('%s<Ntag><name>Variables:</name><value>%s</value></Ntag>\n', _rs, BPEL.BPEL.is_null (SELF.ba_vars));
        _rs := sprintf('%s<Ntag><name>Childs:</name><value>%s</value></Ntag>\n', _rs, BPEL.BPEL.is_null (SELF.ba_childs));
        _rs := concat(_rs,'</node>\n');
        return _rs;
	--return 1;
}
;

create method http_output (in mode varchar) for BPEL.BPEL.sequence
{
        return '';
}
;


create method http_output (in mode varchar) for BPEL.BPEL.compensation_handler
{
        return '';
}
;

create method http_output (in mode varchar) for BPEL.BPEL.compensation_handler_end
{
        return '';
}
;

create method http_output (in mode varchar) for BPEL.BPEL.fault_handlers
{
	declare idx int;
        declare _rs varchar;
        _rs := '<node>';

	if (SELF.bfh_cfs is not null) {
		idx := 0;
		while (idx < length (SELF.bfh_cfs)) {
			declare ch BPEL.BPEL.catch_fault;
			ch := aref (SELF.bfh_cfs, idx);
         _rs := sprintf('%s<Ntag><name>%s</name><value>%s</value></Ntag>',_rs,ch.cf_name,ch.cf_var);
			idx := idx + 1;
		}
	}
        _rs := concat(_rs,'</node>');
        return _rs;
}
;

create method http_output (in mode varchar) for BPEL.BPEL.scope_end
{
  return '';
};


create method http_output (in mode varchar) for BPEL.BPEL.assign
{
        return '';
}
;

create method http_output (in mode varchar) for BPEL.BPEL.receive
{
        declare _rs varchar;
        _rs := '<node>';
        _rs :=sprintf ('%s<Ntag><name>Name:</name><value>%s</value></Ntag>\n', _rs,BPEL.BPEL.is_null2 (SELF.ba_name));
        _rs :=sprintf ('%s<Ntag><name>Partner Link:</name><value>%s</value></Ntag>\n', _rs, BPEL.BPEL.is_null2 (SELF.ba_partner_link));
        _rs :=sprintf ('%s<Ntag><name>Port Type:</name><value>%s</value></Ntag>\n', _rs, BPEL.BPEL.is_null2 (SELF.ba_port_type));
        _rs :=sprintf ('%s<Ntag><name>Operation:</name><value>%s</value></Ntag>\n', _rs, BPEL.BPEL.is_null2 (SELF.ba_operation));
        _rs :=sprintf ('%s<Ntag><name>inputVariable:</name><value>%s</value></Ntag>\n', _rs, BPEL.BPEL.is_null2 (SELF.ba_var));
	if (SELF.ba_create_inst = 1)
	        _rs :=sprintf ('%s<Ntag><name>createInst:</name><value>Yes</value></Ntag>\n', _rs);
	else
	        _rs :=sprintf ('%s<Ntag><name>createInst:</name><value>No</value></Ntag>\n', _rs);
	if (SELF.ba_one_way = 1)
	        _rs :=sprintf ('%s<Ntag><name>OneWay:</name><value>Yes</value></Ntag>\n', _rs);
	else
	        _rs :=sprintf ('%s<Ntag><name>OneWay:</name><value>No</value></Ntag>\n', _rs);
        _rs := concat(_rs,'</node>');
        return _rs;
}
;

create method http_output (in mode varchar) for BPEL.BPEL.compensate
{
        return '';
}
;
--
-- BPEL API functions
--


-- old style wrapper for PL definition, for tests only do not preserve the source in sources table
create procedure BPEL.BPEL.wsdl_process_remote (in partner_link varchar, in wsdl_uri varchar, in scp_id any)
{
    declare sqltext varchar;
    declare xe, dummy, bsrc, wsrc any;
    declare script_id, stat int;
    stat := null;
    whenever not found goto errorend;
    if (isinteger (scp_id))
      {
	select bs_id, bs_state into script_id, stat from BPEL.BPEL.script where bs_id = scp_id;
      }
    else
      {
	select bs_id, bs_state into script_id, stat from BPEL.BPEL.script where bs_name = scp_id;
      }
    select bsrc_text into bsrc from BPEL..script_source where bsrc_script_id = script_id and bsrc_role = 'bpel-exp';
    if (stat is not null)
      {
        update BPEL.BPEL.script set bs_state = 2 where bs_id = script_id;
        BPEL..wsdl_upload (script_id, wsdl_uri, null, partner_link);
        update BPEL.BPEL.script set bs_state = stat where bs_id = script_id;
      }

    select bsrc_text into wsrc from BPEL..script_source where bsrc_script_id = script_id and bsrc_role = partner_link;
    sqltext := BPEL..bpel_wsdl_import (script_id, partner_link, wsdl_uri, wsrc, bsrc);
    --dbg_obj_print (sqltext);
    return;
errorend:
    signal ('22023', 'No such process');
}
;

-- expands and register a particular PL via wsdl
create procedure BPEL..bpel_wsdl_import (in script_id int, in partner varchar, in url varchar, inout src any, inout bsrc any)
{
  declare wsdl_expn, wsdl, pl, ses any;
  declare sqltext, dummy any;

  if (src is null)
    {
      wsdl := DB.DBA.XML_URI_GET ('', url);
      wsdl := xtree_doc (wsdl, 0, url);
      wsdl_expn := xslt ('http://local.virt/wsdl_expand', wsdl);
      --wsdl_expn := xslt ('file:/wsdl_expand.xsl', wsdl);
      --wsdl_expn := xslt ('http://local.virt/wsdl_parts', wsdl_expn);
    }
  else
    wsdl_expn := src;

  for select xmlagg (xmlelement ('partner',
		xmlelement ('name', bpl_name),
		xmlelement('role',bpl_role),
		xmlelement('myrole',bpl_myrole),
		xmlelement ('type', BPEL.BPEL.get_nc_name (bpl_type)))
		) as result
	from BPEL..partner_link_init where bpl_script = script_id and bpl_name = partner do
  {
    pl := result;
  }
  sqltext := xslt (BPEL.BPEL.res_base_uri() || 'bpel4ws/1.0/bpelwsdl.xsl', wsdl_expn, vector ('id', script_id, 'partner', pl));
  --dbg_obj_print (sqltext);
  ses := string_output ();
  http (sprintf ('create procedure BPEL.BPEL.bpel_wsdl_import_%d ()', script_id), ses);
  http_value (sqltext, null, ses);
  sqltext := string_output_string (ses);
  EXEC (sqltext);
  EXEC (sprintf ('BPEL.BPEL.bpel_wsdl_import_%d ()', script_id));
  EXEC (sprintf ('DROP PROCEDURE BPEL.BPEL.bpel_wsdl_import_%d', script_id));
  BPEL.BPEL.wsdl_messages (script_id, wsdl_expn, 1, bsrc);
  return sqltext;
}
;

create procedure BPEL.BPEL.wsdl_messages (in scp_id int, inout src any, in rem int, inout bsrc any)
{
  declare msgs, oper, xp, ses, sqltext any;
  msgs := xslt (BPEL.BPEL.res_base_uri() || 'bpel4ws/1.0/bpelmsg.xsl', src, vector ());
  oper := xslt (BPEL.BPEL.res_base_uri() || 'bpel4ws/1.0/bpeloper.xsl', src, vector ('scp_id', scp_id, 'rem', rem, 'src', xml_cut(bsrc)));
  xp := xpath_eval ('//message[@name]', msgs, 0);
  foreach (any elm in xp) do
    {
      declare elm1, nam any;
      elm1 := xml_cut (elm);
      nam := cast(xpath_eval ('//message/@name', elm1) as varchar);
      --dbg_obj_print (nam, elm1);
      insert replacing BPEL..types_init (vi_script, vi_name, vi_type, vi_value)
	values (scp_id, BPEL..get_nc_name (nam), 0, elm1);
    }
  xp := xpath_eval ('//element[@name]', msgs, 0);
  foreach (any elm in xp) do
    {
      declare elm1, nam any;
      elm1 := xml_cut (elm);
      nam := cast(xpath_eval ('//element/@name', elm1) as varchar);
      --dbg_obj_print (nam, elm1);
      insert replacing BPEL..types_init (vi_script, vi_name, vi_type, vi_value)
	values (scp_id, BPEL..get_nc_name (nam), 1, xpath_eval ('/element/*', elm1));
    }
  ses := string_output ();
  http (sprintf ('create procedure BPEL.BPEL.bpel_wsdl_oper_%d ()', scp_id), ses);
  http_value (oper, null, ses);
  sqltext := string_output_string (ses);
  --dbg_obj_print (sqltext);
  EXEC (sqltext);
  EXEC (sprintf ('BPEL.BPEL.bpel_wsdl_oper_%d ()', scp_id));
  EXEC (sprintf ('DROP PROCEDURE BPEL.BPEL.bpel_wsdl_oper_%d', scp_id));
}
;

-- triggers for consistensy
create trigger inst_delete after delete on BPEL.BPEL.instance
{
  declare bpel_nm varchar;
  if ((bpel_nm := connection_get ('BPEL/ScriptName')) is null)
    {
      for select bs_name from BPEL.BPEL.script
		   where bs_id = bi_script
      do {
	bpel_nm := bs_name;
      }
    }


  if (connection_get ('BPEL_leave_wait') is null)
    delete from BPEL..wait where bw_instance = bi_id;

  delete from BPEL..variables where v_inst = bi_id;
  delete from BPEL..compensation_scope where tc_inst = bi_id;
  delete from BPEL..wsa_messages where wa_inst = bi_id;
  delete from BPEL..reply_wait where rw_inst = bi_id;
  delete from BPEL..time_wait where tw_inst = bi_id;
  delete from BPEL..partner_link where pl_inst = bi_id;
  delete from BPEL..dbg_message where bdm_sender_inst = bi_id;

  BPEL..delete_audit (bi_id, bpel_nm);
}
;

create trigger hc_delete after delete on BPEL.BPEL.hosted_classes
{
whenever sqlstate '42000' goto relax;
  if (hc_path is not null)
    file_unlink (hc_path);
relax:
  ;
}
;

create trigger scp_delete after delete on BPEL.BPEL.script
{
  declare script_id int;
  connection_set ('BPEL/ScriptName', bs_name);
  script_id := bs_id;

  for select (bg_activity as BPEL.BPEL.sql_exec).ba_proc_name as ProcName
	from BPEL.BPEL.graph
	where bg_script_id = script_id and
	      (bg_activity as BPEL.BPEL.activity).ba_type = 'EXEC/SQL'
  do {
	EXEC (concat ('CREATE PROCEDURE ', ProcName, '() { ; }'));
	EXEC (concat ('DROP PROCEDURE ', ProcName));
     }
  delete from BPEL.BPEL.remote_operation where ro_script = script_id;
  delete from BPEL.BPEL.graph where bg_script_id = script_id;
  delete from BPEL.BPEL.instance where bi_script = script_id;
  delete from BPEL.BPEL.operation where bo_script = script_id;
  delete from BPEL.BPEL.partner_link_init where bpl_script = script_id;
  delete from BPEL.BPEL.property_alias where pa_script = script_id;
  delete from BPEL.BPEL.property where bpr_script = script_id;
  delete from BPEL..links where bl_script = script_id;
  delete from BPEL..script_source where bsrc_script_id = script_id;
  delete from BPEL..message_parts where mp_script = script_id;
  delete from BPEL..types_init where vi_script = script_id;
  delete from BPEL..queue where bq_script = script_id;
  delete from BPEL..correlation_props where cpp_script = script_id;
  delete from BPEL.BPEL.hosted_classes where hc_script = script_id;
  BPEL..process_clear_stats (script_id);
  if (bs_lpath is not null)
    DB.DBA.VHOST_REMOVE (lpath=>bs_lpath);
}
;



-- delete a script, XXX: have to check and signal an error

create procedure BPEL.BPEL.delete_script (in script_id integer)
{
  delete from BPEL.BPEL.script where bs_id = script_id;
}
;

create procedure BPEL..audit_check_line (in line varchar, inout x any, in num integer)
{
  declare rxp any;
  declare sTime varchar;
  rxp := regexp_parse ('\\[(.*)\\]\\[(.*)\\]([-0-9]*):([A-Za-z/]*):(.*)', line, 0);
  if (length (rxp) <> 12)
    signal ('42000', sprintf ('Unknown BPEL Audit format line %s', line));

  http ('<AuditEntry ', x);
  http ('Id="', x);
   http (subseq (line, aref (rxp, 6), aref (rxp, 7)), x);
   http ('" ', x);
  http ('Node="', x);
   http (subseq (line, aref (rxp, 8), aref (rxp, 9)), x);
   http ('" ', x);
  http (sprintf ('AuditId="%d" ', num),x);

  --sTime := subseq (line, aref (rxp, 4), aref (rxp, 5));
  --if (not(equ(sTime,''))) sTime := BPEL.BPEL.date_interval(cast(sTime as datetime));

  http (sprintf ('DateT="%s"><![CDATA[', subseq (line, aref (rxp, 4), aref (rxp, 5)), 'DateT'),x);
  --http (sprintf ('DateT="%s"><![CDATA[',sTime, 'DateT'),x);
  http (subseq (line, aref (rxp, 10), aref (rxp, 11)),  x);
  http (']]></AuditEntry>',x);


}
;

create procedure BPEL..make_audit_report (in inst integer)
{
  declare cr cursor for select bs_name from BPEL.BPEL.script, BPEL.BPEL.instance
	where bi_script = bs_id
	and bi_id = inst;

  declare bpel_nm, file_nm varchar;
  open cr (prefetch 1);
  fetch cr into bpel_nm;

  declare au_file_output any;

  declare x any;
  declare offset_0, offset_last, last, sz integer;

  BPEL..audit_file_output (inst, bpel_nm, au_file_output);
  sz := length (au_file_output);

  offset_0 := 0;
  offset_last := offset_0 + 1024;
  if (offset_last > sz)
    offset_last := sz;

  last := 0;

  x := string_output ();
  http (sprintf ('<Inst Id="%d">\n\r',inst), x);

  declare cnt integer;
  declare part, line varchar;
  line := '';
  part := replace (substring (au_file_output, offset_0+1, offset_last-offset_0), '\r' ,'');
  cnt := 0;
  while (1=1)
    {
      declare endline integer;
      endline := strchr (part, '\n');
      if (endline is null)
	{
	  line := concat (line, part);
	  offset_0 := offset_last;
	  offset_last := offset_last + 1024;
	  if (offset_0 >= sz)
	    goto ret;
	  if (offset_last > sz)
	    offset_last := sz;
	  part := replace ( substring (au_file_output, offset_0+1, offset_last-offset_0), '\r' ,'');
	}
      else
	{
	  cnt := cnt + 1;
	  line := concat (line, subseq (part, 0, endline));
	  BPEL..audit_check_line (line, x, cnt);
	  line := '';
	  part := subseq (part, endline+1);
	}
    }
 ret:
  http ('</Inst>\n\r', x);
  return string_output_string (x);
}
;

-- this is to upload a BPEL script
-- if content is empty it will be retrieved via url
--
create procedure BPEL.BPEL.script_upload (in name varchar, in url varchar, in content any := null) returns int
{
  declare id int;
  declare expn, deploy, base_decl any;

  whenever sqlstate '22007' goto relax;

  if (length (content) = 0)
    {
      content := DB.DBA.XML_URI_GET ('', url);
    }


  BPEL.BPEL.xml_validate(content,url);

  content := xtree_doc (content, 256, url);

  if ((name = '') or (name is null))
    name := xpath_eval ('process/@name', content);

  if (url = '')
    {
      --update BPEL..script set bs_uri = id where bs_id = id;
      url := sprintf ('%s', name);
      base_decl := '';
    }
  else
    {
      base_decl := sprintf ('[__base_uri "%s"]', url);
    }

  if (exists(select 1 from BPEL.BPEL.script where bs_name = name))
     signal ('22023', sprintf( 'There is already uploaded process with the name %s. Operation can not be done.',name ) );

  -- state edit (2)
  -- we will put url for now , but this should be removed
  insert into BPEL..script (bs_uri, bs_name, bs_state, bs_date) values (url, name, 2, now ());

  id := identity_value ();

  -- bpel
  insert into BPEL..script_source (bsrc_script_id, bsrc_role, bsrc_text, bsrc_url) values (id, 'bpel', content, url);

  expn :=  xslt (BPEL.BPEL.res_base_uri() || 'bpel4ws/1.0/bpelexpn.xsl', content);
  -- bpel-exp
  insert into BPEL..script_source (bsrc_script_id, bsrc_role, bsrc_text, bsrc_url) values (id, 'bpel-exp', expn, url);
  -- deploy
  -- deploy :=  xslt (BPEL.BPEL.res_base_uri() || 'bpel4ws/1.0/bpeldeploy.xsl', expn);
  -- insert into BPEL..script_source (bsrc_script_id, bsrc_role, bsrc_text, bsrc_url) values (id, 'deploy', deploy, url);

  -- need to be removed
  update BPEL..script_source set bsrc_temp = base_decl||xmlnss_xpath_pre (xpath_eval ('//process', content, 1), 'http://schemas.xmlsoap.org/ws/2003/03/business-process/', vector ('bpws', 'bpel')) where bsrc_role = 'bpel-exp' and bsrc_script_id = id;


  return id;
  relax:
   rollback work;
   signal('42000','The file is not a xml document');return;
}
;

-- updates the script source
create procedure BPEL.BPEL.script_source_update (in scp_id int, in url varchar, in content any := null)
{
  declare id int;
  declare expn, base_decl any;

  whenever sqlstate '22007' goto relax;

  if (not exists (select 1 from BPEL..script where bs_id = scp_id and bs_state = 2))
    signal ('22023', 'The process with given id does not exist or it is not in edit mode');

  if (content is null)
    {
      content := DB.DBA.XML_URI_GET ('', url);
    }

  --content := xtree_doc (content);

  BPEL.BPEL.xml_validate(content,url);

  content := xtree_doc (content, 256, url);

  id := scp_id;

  delete from BPEL..script_source where bsrc_script_id = scp_id and bsrc_role in ('bpel','bpel-exp','deploy');
  -- bpel
  insert into BPEL..script_source (bsrc_script_id, bsrc_role, bsrc_text, bsrc_url) values (id, 'bpel', content, url);
  expn :=  xslt (BPEL.BPEL.res_base_uri() || 'bpel4ws/1.0/bpelexpn.xsl', content);
  -- bpel-exp
  insert into BPEL..script_source (bsrc_script_id, bsrc_role, bsrc_text, bsrc_url) values (id, 'bpel-exp', expn, url);
  -- deploy
  -- deploy :=  xslt (BPEL.BPEL.res_base_uri() || 'bpel4ws/1.0/bpeldeploy.xsl', expn);
  -- insert into BPEL..script_source (bsrc_script_id, bsrc_role, bsrc_text, bsrc_url) values (id, 'deploy', deploy, url);

  if (url = '')
     base_decl := '';
  else
     base_decl := sprintf ('[__base_uri "%s"]', url);

  update BPEL..script_source set bsrc_temp = base_decl||xmlnss_xpath_pre (xpath_eval ('//process', content, 1), 'http://schemas.xmlsoap.org/ws/2003/03/business-process/', vector ('bpws', 'bpel')) where bsrc_role = 'bpel-exp' and bsrc_script_id = id;

  return id;
  relax:
   rollback work;
   signal('42000','The file is not a xml document');return;
}
;

-- this is to copy a script into a new version
-- set 1-st state to 1 and second to 2
create procedure BPEL.BPEL.copy_script (in scp_id int) returns int
{
  declare id int;
  declare f, iState int;
  declare sName varchar;

  f := 0;

  -- the script ia already in edit mode ( has not been compiled when registered)
  if ( exists (select 1 from BPEL..script where bs_id = scp_id and bs_state = 2))
    return scp_id;
  -- the script is in current mode
  --if (not exists (select 1 from BPEL..script where bs_id = scp_id and bs_state = 0))
  --  signal ('22023', 'The process with given id does not exist or it is not current');

  if (not exists (select 1 from BPEL..script where bs_id = scp_id))
     signal ('22023', 'The process with given id does not exist.');

  select bs_name, bs_state into sName,iState from BPEL..script where bs_id = scp_id;
  -- there is no current version

  if ( iState = 1 )
  {
    if (exists (select 1 from BPEL..script where bs_id <> scp_id and (bs_state = 0 or bs_state = 2) and bs_name = sName))
      signal ('22023', sprintf('There is already process with state edit or current for the %s',sName) );
  };

  if ( iState = 0 )
  {
    if (exists (select 1 from BPEL..script where bs_id <> scp_id and bs_state = 2 and bs_name = sName))
      signal ('22023', sprintf('There is already process with state edit for the given %s',sName) );
  };

  --if (not(f)) update BPEL..script set bs_state = 1 where bs_id = scp_id;
  insert into BPEL..script (bs_uri, bs_name, bs_state, bs_date, bs_parent_id, bs_version)
	select bs_uri, bs_name, 2, now (), bs_id, bs_version from BPEL..script where bs_id = scp_id;
  id := identity_value ();
  insert into BPEL..script_source (bsrc_script_id, bsrc_role, bsrc_text, bsrc_url, bsrc_temp)
	select id, bsrc_role, bsrc_text, bsrc_url, bsrc_temp from BPEL..script_source where bsrc_script_id = scp_id;
  return id;
}
;

-- this is to upload a wsdl for a given PL
create procedure BPEL.BPEL.wsdl_upload (in scp_id int, in url varchar, in content any := null, in pl varchar := 'wsdl')
{
  declare wsdl, wsdl_expn any;

  if (not exists (select 1 from BPEL..script where bs_id = scp_id and bs_state = 2))
    signal ('22023', 'The process with given id does not exist or it is not in edit mode');

  if (length (content) = 0)
    {
      content := DB.DBA.XML_URI_GET ('', url);
    }
  else if (length (content) > 0)
    {
      BPEL.BPEL.check_relative(content);
    };
  wsdl := xtree_doc (content, 0, url);

  xml_validate_schema (content, 0, url, 'UTF-8', 'x-any',
  	  'Validation=RIGOROUS Fsa=ERROR FsaBadWs=IGNORE BuildStandalone=ENABLE '||
  	  ' AttrMissing=ERROR AttrMisformat=ERROR AttrUnknown=ERROR MaxErrors=200 SignalOnError=ENABLE',
  	  'xs:', ':xs',
  	  BPEL.BPEL.res_base_uri() || 'bpel4ws/1.0/wsdl.xsd');

  wsdl_expn := xslt ('http://local.virt/wsdl_expand', wsdl);
  --wsdl_expn := xslt ('file:/wsdl_expand.xsl', wsdl);
  --wsdl_expn := xslt ('http://local.virt/wsdl_parts', wsdl_expn);
  insert replacing BPEL..script_source (bsrc_script_id, bsrc_role, bsrc_text, bsrc_url)
     values (scp_id, pl, wsdl_expn, url);

}
;

-- returns xml fragment
create procedure BPEL.BPEL.get_partner_links (in scp_id int) returns any
{
  declare xp, pl, plx any;
  declare cr cursor for select bsrc_text from BPEL..script_source where bsrc_script_id = scp_id and
	bsrc_role = 'bpel-exp';
  whenever not found goto nf;
  open cr (exclusive, prefetch 1);
  fetch cr into xp;
  pl := xpath_eval ('/process/partnerLinks', xp, 1);
  close cr;
  return xml_cut (pl);
  nf:
  close cr;
  signal ('22023', 'The process with given id does not exist');
}
;

-- compile the bpel script
create procedure BPEL.BPEL.compile_script (in scp_id int, in vdir varchar := null, in opts any := null, in no_check int := 0)
{
  declare ss, nd, nm, xt, src, xp_xmlnss, scp_name any;
  declare fnd, parent_id, cr_id, dretr, ncnt, acnt int;

  dretr := BPEL..max_deadlock_cnt ();

  if (not exists (select 1 from BPEL..script where bs_id = scp_id and bs_state = 2))
    signal ('22023', 'The process with given id does not exist or is not being edited');
  -- increase version & state = 0 if all is ok

  select bs_parent_id, bs_name into parent_id, scp_name
    from BPEL..script
   where bs_id = scp_id;

  declare cr cursor for
   select bs_id
     from BPEL.BPEL.script
    where bs_name = scp_name;

  declare exit handler for sqlstate '40001'
  {
    rollback work;
    close cr;
    if (dretr <= 0)
      {
        resignal;
      }
    dretr := dretr - 1;
    goto again;
  };

  again:
  whenever not found goto nf;
  open cr (exclusive);
  fetch cr into cr_id;

  fnd := 0;
  for select bsrc_text, bsrc_temp from BPEL..script_source
	where bsrc_script_id = scp_id and bsrc_role = 'bpel-exp'
    do
      {
	 if (not no_check)
	   BPEL.BPEL.check_partner_links(bsrc_text, scp_id);
         src := bsrc_text;
         ss := string_output ();
	 connection_set ('BPEL_script_xmlnss', bsrc_temp);
	 connection_set ('BPEL_script_id', scp_id);
	 xt :=  xslt (BPEL.BPEL.res_base_uri() || 'bpel4ws/1.0/bpelcomp.xsl',  src, vector ('id', scp_id));
	 http_value (xt, null, ss);
	 --dbg_obj_print(string_output_string (ss));
	 --string_to_file ('src1.sql', string_output_string (ss), -2);
         EXEC (string_output_string (ss));
         EXEC (sprintf ('BPEL.BPEL.update_nodes_%d()', scp_id));
         EXEC (sprintf ('DROP PROCEDURE BPEL.BPEL.update_nodes_%d', scp_id));
         fnd := 1;
      }

  if (not fnd)
    signal ('42000', 'No source found for this process');

  fnd := 0;
  for select bsrc_text from BPEL..script_source
      where bsrc_script_id = scp_id and bsrc_role = 'wsdl' do
    {
       declare wsdl_expn any;
       declare inx int;
       declare inv_ent any;

       BPEL.BPEL.wsdl_messages (scp_id, bsrc_text, 1, src);
       fnd := 1;
    }

  if (not fnd)
    signal ('42000', 'No WSDL found for this process');


  for select bsrc_text, bsrc_role from BPEL..script_source
      where bsrc_script_id = scp_id and bsrc_role not in ('bpel', 'bpel-exp', 'deploy', 'wsdl') do
    {
      declare sqltext varchar;
      sqltext := BPEL..bpel_wsdl_import (scp_id, bsrc_role, null, bsrc_text, src);
	--dbg_obj_print (sqltext);
    }

  declare parent_state, parent_version int;
  declare parent_vdir varchar;

  parent_state := -1;
  declare continue handler for NOT FOUND parent_vdir := null;
  select bs_lpath, bs_state, bs_version into parent_vdir, parent_state, parent_version
    from BPEL..script
   where bs_id = parent_id;

  if (parent_id is not null)
  {
    if (not exists (select 1 from BPEL..script where bs_id = parent_id and (bs_state = 0 or bs_state = 1)))
      signal ('22023', 'The process with given id has no previous version.');

    if ( parent_state = 0) update BPEL..script set bs_state = 1 where bs_id = parent_id;
  };

  -- all done, set the flag and increase the version
  update BPEL..script set bs_state = 0, bs_version = bs_version + 1, bs_lpath = vdir  where bs_id = scp_id;

  -- check the activities number
  select bs_act_num into ncnt from BPEL..script where bs_id = scp_id;
  select count(*) into acnt from BPEL..graph where bg_script_id = scp_id;

  if (ncnt <> acnt)
    {
      signal ('42000', 'The number activities compiled is different than expected.');
    }

 if (vdir is not null and vdir <> '')
    {
      declare vdir_opts any;

      if (not(subseq(vdir,0,1)='/')) vdir := concat('/',vdir);

      if (exists(  select bs_id
           from BPEL..script
          where bs_lpath = vdir
            and bs_name <> scp_name))
         signal ('22023', sprintf('There is already defined virtual directory %s. Please choose another name.',vdir));


      update BPEL..script set bs_lpath = vdir  where bs_id = scp_id;

      if ( (parent_id is null) or ( parent_id is not null and vdir <> parent_vdir) )
        {
          vdir_opts := vector ('scp_id', scp_id, 'scp_name', scp_name);
          if (opts is not null)
            vdir_opts := vector_concat (opts, vdir_opts);
          DB.DBA.VHOST_DEFINE
	    (
	       lpath=>vdir,
  	       ppath=>BPEL.BPEL.vdir_base () || '/bpel4ws/1.0/bpel.vsp',
      	       vsp_user=>'BPEL',
      	       soap_opts=>vdir_opts,
	       is_dav=>(case when BPEL.BPEL.vdir_base () like '/DAV/%' then 1 else 0 end)
	    );
        };
    }
  BPEL..stat_init (scp_id);

  commit work;
  close cr;

  nf:
  close cr;
  return;
}
;

--
-- IMPORTANT: THIS IS A OLD STYLE API; USED IN TESTSUITE ONLY
-- PLEASE DO NOT USE OUTSIDE OF TEST SCRIPTS
--
create procedure BPEL.BPEL.upload_script (
	in base_uri varchar,
	in bpel_name varchar,
	in wsdl_name varchar,
        in virtual_dir varchar := null)
{
   declare bpel_uri,wsdl_uri varchar;
   declare scp int;
   whenever sqlstate '*' goto relax;
   bpel_uri := DB.DBA.XML_URI_RESOLVE_LIKE_GET (base_uri, bpel_name);
   wsdl_uri := DB.DBA.XML_URI_RESOLVE_LIKE_GET (base_uri, wsdl_name);

   scp := BPEL..script_upload (bpel_uri, bpel_uri, null);
   BPEL..wsdl_upload (scp, wsdl_uri);
   BPEL..compile_script (scp, virtual_dir, null, 1);

  -- statistics
  BPEL..stat_init (scp);

   return null;
relax:
   rollback work;
   return __SQL_MESSAGE;
}
;

create procedure BPEL.BPEL.script_delete (in script int, in delete_instances int)
{
  if (not delete_instances and exists (select 1 from BPEL..instance where bi_script = script))
    signal ('42000', 'The process has existing instances');
  delete from BPEL..script where bs_id = script;
}
;

create procedure BPEL.BPEL.script_obsolete (in script int)
{
  update BPEL..script set bs_state = 1 where bs_id = script;
  if (not row_count ())
    signal ('22023', 'No such process');
}
;

create procedure BPEL.BPEL.script_version_cleanup (in script int)
{
  signal ('42000', 'Not implemented');
}
;

create procedure BPEL.BPEL.purge_instance (in completed_before datetime, in make_archive int := 1)
{
  declare cr cursor for select bi_id from BPEL..instance
	where bi_state in (2,3) and bi_last_act < completed_before;
  declare id, i, dretr int;
  dretr := BPEL..max_deadlock_cnt ();
  if (make_archive)
    BPEL.BPEL.archive_instances (completed_before);
  whenever not found goto nf;
  declare exit handler for sqlstate '40001'
  {
    rollback work;
    close cr;
    if (dretr <= 0)
      {
        resignal;
      }
    dretr := dretr - 1;
    goto again;
  };
  i := 0;
again:
  open cr (prefetch 10);
  while (1)
    {
      fetch cr into id;
      delete from BPEL..instance where current of cr;
      if (mod (i, 50) = 0)
        {
          --dbg_obj_print ('committing...', i);
          commit work;
        }
      i := i + 1;
    }
  nf:
  close cr;
  return;
}
;

create procedure BPEL.BPEL.instance_delete (in id int)
{
  -- tell trigger to do not delete waits
  connection_set ('BPEL_leave_wait', 1);
  delete from BPEL..instance where bi_id = id;
  connection_set ('BPEL_leave_wait', null);
}
;

create procedure BPEL.BPEL.stop_process (in script_id int)
{
   for select bi_id from BPEL.BPEL.instance where bi_script = script_id do
      {
	BPEL.BPEL.stop_instance (bi_id);
      }
}
;

create procedure BPEL.BPEL.stop_instance (in inst int)
{
   delete from BPEL.BPEL.wait where bw_instance = inst;
   update BPEL.BPEL.instance set bi_state = 3 where bi_id = inst and bi_state <> 2;
}
;

create procedure BPEL.BPEL.register_script (
        in bpel_name varchar,
	in bpel_url varchar := '',
        in wsdl_url varchar := '',
	in bpel_content any := null,
	in wsdl_content any := null)
{
   declare scp int;
   --whenever sqlstate '*' goto relax;
   if (bpel_url is null)
     bpel_url := '';
   scp := BPEL..script_upload (bpel_name, bpel_url, bpel_content);
   BPEL..wsdl_upload (scp, wsdl_url, wsdl_content);
   return scp;
--relax:
 --  { dbg_obj_print('relax');
  -- rollback work;
  -- return __SQL_MESSAGE;
 --  };
}
;

create procedure BPEL.BPEL.process_data(in script_id int)
{
  declare pr_name, pr_vdir, pr_parent_vdir varchar;
  declare pr_compile, parent_id int;
  declare aXML any;

  select bs_name, bs_state, bs_lpath, bs_parent_id into pr_name, pr_compile, pr_vdir, parent_id
    from BPEL.BPEL.script
   where bs_id = script_id;

  declare continue handler for NOT FOUND pr_parent_vdir := null;
  select bs_lpath into pr_parent_vdir
    from BPEL..script
   where bs_id = parent_id;

  if (parent_id is null)-- the process is registered for first time
    pr_vdir := pr_name;
  else
    pr_vdir := pr_parent_vdir;

  aXML := XMLELEMENT('page',
                      XMLELEMENT('bpel_name',pr_name),
                      XMLELEMENT('bpel_state',pr_compile),
                      XMLELEMENT('bpel_vdir',pr_vdir)
                     );
  return aXML;
}
;


create procedure BPEL.BPEL.check_process_new (in base_uri varchar, in script_source varchar)
{
		declare _log varchar;
		_log := xml_validate_schema (script_source, 0, base_uri, 'UTF-8', 'x-any',
			'Validation=SGML FsaBadWs=IGNORE BuildStandalone=ENABLE MaxErrors=100',
			'xs:', ':xs',
			BPEL.BPEL.res_base_uri () || 'bpel.xsd');
		return _log;
}
;

create procedure BPEL.BPEL.script_revert (in scp_id int)
{
  declare parent_id int;

  if (not exists (select 1 from BPEL..script where bs_id = scp_id and bs_state = 2))
    signal ('22023', 'The process with given id does not exist or it is not in edit mode');

  declare continue handler for NOT FOUND parent_id := null;
  select bs_parent_id into parent_id
    from BPEL..script
   where bs_id = scp_id;


  if (parent_id is null)
    signal ('22023', 'The process with given id has no previous version to be reverted to.');

  if (not exists (select 1 from BPEL..script where bs_id = parent_id and bs_state = 1))
    signal ('22023', 'The process with given id has no previous version to be reverted to.');

  BPEL..script_delete(scp_id,1);

  update BPEL..script
     set bs_state = 0
   where bs_id = parent_id;

  return parent_id;
}
;

create procedure BPEL.BPEL.import_script( in base_uri varchar, in base_name varchar, inout scp_id int )
{
  declare deploy_content, bpel_source any;
  declare bpel_name, bpel_def,bpel_url, wsdl_name, wsdl_def, wsdl_url varchar;
  declare i int;
  declare node, loc varchar;

  --dbg_obj_print('-------- Import--------');

  if (scp_id > 0)
  {
    if (not exists (select 1 from BPEL..script where bs_id = scp_id and bs_state = 2))
      signal ('22023', 'The process with given id does not exist or it is not in edit mode');
  };

  deploy_content := DB.DBA.XML_URI_GET ('', base_uri);
  deploy_content := xtree_doc (deploy_content);

  bpel_def := cast(xpath_eval('/BPELSuitcase/BPELProcess/@src/.',deploy_content) as varchar);
  bpel_name := cast(xpath_eval('/BPELSuitcase/BPELProcess/@id/.',deploy_content) as varchar);
  bpel_url := DB.DBA.XML_URI_RESOLVE_LIKE_GET(base_uri,bpel_def);

  bpel_source := DB.DBA.XML_URI_GET ('', bpel_url);
  bpel_source := xtree_doc (bpel_source, 256, bpel_url);

  wsdl_name := BPEL.BPEL.get_wsdl_name(bpel_source, deploy_content);
  wsdl_def := cast(xpath_eval( sprintf('/BPELSuitcase/BPELProcess/partnerLinkBindings/partnerLinkBinding[@name="%s"]/property/.',wsdl_name ),deploy_content) as varchar);
  wsdl_url := DB.DBA.XML_URI_RESOLVE_LIKE_GET(base_uri,wsdl_def);

  if (scp_id = 0)
 {
    scp_id := BPEL.BPEL.register_script(base_name, bpel_url, wsdl_url);
  }
  else
  {
    BPEL..script_source_update(scp_id, bpel_url, null);
    BPEL..wsdl_upload(scp_id, wsdl_url, null);
  };

  -- insert wsdl for partenr links
  i := 1;
  deploy_content := xpath_eval('/BPELSuitcase/BPELProcess/partnerLinkBindings',deploy_content);

  while(i){
    node := cast(xpath_eval('//partnerLinkBinding/@name',deploy_content,i) as varchar);
    if (node is not null)
      {
        loc := cast(xpath_eval('//partnerLinkBinding/property',deploy_content,i) as varchar);
        loc := DB.DBA.XML_URI_RESOLVE_LIKE_GET (base_uri, loc);
        if (not(loc = wsdl_def))
          {
            BPEL..wsdl_upload(scp_id, loc, null, node);
          };
        i := i + 1;
      }
    else
    {
      i := 0;
    };
  };

  return;
}
;

/*
   partner link options
*/
create procedure BPEL.BPEL.plink_get_option (in script varchar, in plink varchar, in opt varchar)
{
  declare scp int;
  declare opts, xp, flag any;

  whenever not found goto nf;
  select bs_id into scp from BPEL.BPEL.script where bs_name = script;

  select bpl_opts into opts from BPEL.BPEL.partner_link_init where bpl_script = scp and bpl_name = plink;

  if (not isstring (opt))
    signal ('22023', 'Option name must be a string');

  opt := lower (opt);

  flag := 1;

  if (opt = 'wsa')
    {
      xp := '/wsOptions/addressing/@version';
    }
  else if (opt = 'http-auth-uid')
    {
      xp := '/wsOptions/security/http-auth/@username';
    }
  else if (opt = 'http-auth-pwd')
    {
      xp := '/wsOptions/security/http-auth/@password';
    }
  else if (opt = 'wss-priv-key')
    {
      xp := '/wsOptions/security/key/@name';
    }
  else if (opt = 'wss-pub-key')
    {
      xp := '/wsOptions/security/pubkey/@name';
    }
  else if (opt = 'wss-in-encrypt')
    {
      xp := '/wsOptions/security/in/encrypt/@type';
    }
  else if (opt = 'wss-in-signature')
    {
      xp := '/wsOptions/security/in/signature/@type';
    }
  else if (opt = 'wss-in-signers')
    {
      xp := '/wsOptions/security/in/keys/key/@name';
      flag := 0;
    }
  else if (opt = 'wss-out-encrypt-key')
    {
      xp := '/wsOptions/security/out/encrypt/@type';
    }
  else if (opt = 'wss-out-signature-type')
    {
      xp := '/wsOptions/security/out/signature/@type';
    }
  else if (opt = 'wss-out-signature-function')
    {
      xp := '/wsOptions/security/out/signature/@function';
    }
  else if (opt = 'wsrm-in-type')
    {
      xp := '/wsOptions/delivery/in/@type';
    }
  else if (opt = 'wsrm-out-type')
    {
      xp := '/wsOptions/delivery/out/@type';
    }
  else
    signal ('22023', 'Bad option "'||opt||'"');

  return xpath_eval (xp, opts, flag);

  nf:
  signal ('22023', 'The specified script does not exist');
}
;

create procedure BPEL.BPEL.check_ekey (in kn varchar)
{
  set_user_id ('BPEL');
  if (xenc_key_exists (kn))
    return 1;
  return 0;
}
;

create procedure BPEL.BPEL.plink_set_option (in script varchar, in plink varchar, in opt varchar, in val any)
{
  declare scp int;
  declare opts, xp, repl, tmp any;

  whenever not found goto nf;
  select bs_id into scp from BPEL.BPEL.script where bs_name = script;

  select bpl_opts into opts from BPEL.BPEL.partner_link_init where bpl_script = scp and bpl_name = plink;

  if (not isstring (opt))
    signal ('22023', 'Option name must be a string');

  opt := lower (opt);

  if (opt = 'wsa')
    {
      xp := '/wsOptions/addressing';
      if (val not like 'http://schemas.xmlsoap.org/ws/%/addressing')
	signal ('22023', 'Not valid WS-Addresing version');
      repl := sprintf ('<addressing version="%s"/>', val);
    }
  else if (opt = 'http-auth-uid')
    {
      tmp := cast (xpath_eval ('/wsOptions/security/http-auth/@password', opts) as varchar);
      xp := '/wsOptions/security/http-auth';
      repl := sprintf ('<http-auth username="%s" password="%s"/>', val, tmp);
    }
  else if (opt = 'http-auth-pwd')
    {
      tmp := cast (xpath_eval ('/wsOptions/security/http-auth/@username', opts) as varchar);
      xp := '/wsOptions/security/http-auth';
      repl := sprintf ('<http-auth username="%s" password="%s"/>', tmp, val);
    }
  else if (opt = 'wss-priv-key')
    {
      xp := '/wsOptions/security/key';
      if (not BPEL.BPEL.check_ekey (val))
	signal ('22023', 'The key does not exist in BPEL user repository');
      repl := sprintf ('<key name="%s"/>', val);
    }
  else if (opt = 'wss-pub-key')
    {
      xp := '/wsOptions/security/pubkey';
      if (not BPEL.BPEL.check_ekey (val))
	signal ('22023', 'The key does not exist in BPEL user repository');
      repl := sprintf ('<pubkey name="%s"/>', val);
    }
  else if (opt = 'wss-in-encrypt')
    {
      if (val not in ('Mandatory','Optional','NONE'))
	signal ('22023', 'Value must be one of [Mandatory,Optional,NONE]');
      xp := '/wsOptions/security/in/encrypt';
      repl := sprintf ('<encrypt type="%s"/>', val);
    }
  else if (opt = 'wss-in-signature')
    {
      if (val not in ('Mandatory','Optional','NONE'))
	signal ('22023', 'Value must be one of [Mandatory,Optional,NONE]');
      xp := '/wsOptions/security/in/signature';
      repl := sprintf ('<signature type="%s"/>', val);
    }
  else if (opt = 'wss-in-signers')
    {
      if (val is not null and not isarray (val))
	signal ('22023', 'Value must be an array');
      xp := '/wsOptions/security/in/keys';
      repl := '<keys>';
      foreach (any x in val) do
	{
          if (not BPEL.BPEL.check_ekey (x))
	    signal ('22023', 'The key does not exist in BPEL user repository');
	  repl := repl || sprintf ('<key name="%s"/>', x);
	}
      repl := repl || '</keys>';
    }
  else if (opt = 'wss-out-encrypt-key')
    {
      if (val not in ('3DES','AES128','AES192','AES256','NONE'))
	signal ('22023', 'Value must be one of [3DES,AES128,AES192,AES256,NONE]');
      xp := '/wsOptions/security/out/encrypt';
      repl := sprintf ('<encrypt type="%s"/>', val);
    }
  else if (opt = 'wss-out-signature-type')
    {
      if (val not in ('Default','Custom','NONE'))
	signal ('22023', 'Value must be one of [Default,Custom,NONE]');
      tmp := cast (xpath_eval ('/wsOptions/security/out/signature/@function', opts) as varchar);
      xp := '/wsOptions/security/out/signature';
      repl := sprintf ('<signature type="%s" function="%s"/>', val, tmp);
    }
  else if (opt = 'wss-out-signature-function')
    {
      tmp := cast (xpath_eval ('/wsOptions/security/out/signature/@type', opts) as varchar);
      if (length (val) and __proc_exists (val) is null)
	signal ('22023', 'No such procedure "'||val||'"');
      xp := '/wsOptions/security/out/signature';
      repl := sprintf ('<signature type="%s" function="%s"/>', tmp, val);
    }
  else if (opt = 'wsrm-in-type')
    {
      if (val not in ('ExactlyOnce','InOrder','NONE'))
	signal ('22023', 'Value must be one of [ExactlyOnce,InOrder,NONE]');
      xp := '/wsOptions/delivery/in';
      repl := sprintf ('<in type="%s"/>', val);
    }
  else if (opt = 'wsrm-out-type')
    {
      if (val not in ('ExactlyOnce','InOrder','NONE'))
	signal ('22023', 'Value must be one of [ExactlyOnce,InOrder,NONE]');
      xp := '/wsOptions/delivery/out';
      repl := sprintf ('<out type="%s"/>', val);
    }
  else
    signal ('22023', 'Bad option "'||opt||'"');

  repl := xtree_doc (repl);

  XMLReplace (opts, xpath_eval (xp, opts), repl);

  update BPEL.BPEL.partner_link_init set bpl_opts = opts where bpl_script = scp and bpl_name = plink;

  return;

  nf:
  signal ('22023', 'The specified script does not exist');
}
;

create procedure BPEL..return_reply (in id int, in repl any := null)
{
  declare conn, resp any;
  for select bdm_inout, bdm_sender_inst, bdm_plink,
	bdm_recipient, bdm_activity, bdm_conn, bdm_action from BPEL..dbg_message where bdm_id = id do
   {
     if (bdm_conn is null)
       goto ends;
     resp := repl;
     conn := http_recall_session (bdm_conn);
     if (resp is null)
       {
	 ses_write ('HTTP/1.1 202 Accepted\r\n', conn);
	 ses_write (sprintf ('Content-Length: %d\r\n', 0), conn);
	 ses_write ('Server: Virtuoso (BPEL 1.0)\r\n\r\n', conn);
       }
     else
       {
	 ses_write ('HTTP/1.1 200 OK\r\n', conn);
	 ses_write ('Content-Type: text/xml\r\n', conn);
	 ses_write (sprintf ('Content-Length: %d\r\n', length (resp)), conn);
	 ses_write ('Server: Virtuoso (BPEL 1.0)\r\n\r\n', conn);
	 ses_write (resp, conn);
       }
   }
  ends:
  delete from BPEL..dbg_message where bdm_id = id;
}
;


create procedure BPEL..forward_to_ultimate (in id int)
{
  declare conn, resp, req, ohdr any;
  declare hdr any;

  for select bdm_text, bdm_inout, bdm_sender_inst, bdm_plink,
	bdm_recipient, bdm_activity, bdm_conn, bdm_action from BPEL..dbg_message where bdm_id = id do
   {
     req := blob_to_string (bdm_text);
     ohdr := sprintf ('Content-Type: text/xml\r\nSOAPAction: "%s"', bdm_action);
     commit work;
     resp := http_get (bdm_recipient, hdr, 'POST', ohdr, req);
     --dbg_obj_print (hdr, resp);
     if (bdm_conn is null)
       goto ends;
     conn := http_recall_session (bdm_conn);
     foreach (any h in hdr) do
       {
         ses_write (h, conn);
       }
     ses_write ('\r\n', conn);
     ses_write (resp, conn);
   }
  ends:
  delete from BPEL..dbg_message where bdm_id = id;
}
;

create procedure BPEL.BPEL.DEBUG_CALLBACK (inout ses any, inout cd any)
{
  declare resp, msg, oper any;
  declare inst, node, rc, dummy, scp_inst, scp_id, mtype, style, pl int;
  declare script varchar;
  set_user_id ('BPEL', 0);
  --dbg_obj_print ('BPEL.BPEL.DEBUG_CALLBACK');
  resp := soap_receive (ses, 11, 64+128);
  --dbg_obj_print ('RESPONSE FROM SERVICE', resp);
  resp := xml_tree_doc (resp);
  --dbg_obj_print (resp);
  pl := ''; script := ''; scp_id := cd[0]; oper := cd[1]; node := -1; inst := -1;
  insert into BPEL..dbg_message
       (bdm_text, bdm_ts, bdm_inout, bdm_sender_inst, bdm_plink,
	bdm_recipient, bdm_activity, bdm_conn, bdm_action, bdm_oper, bdm_script)
     values (serialize_to_UTF8_xml (resp), now(), 2, inst, pl, script, node, null, null, oper, scp_id);
}
;

create procedure BPEL.BPEL.check_file(in scp_id int, in scp_role varchar)
{
  if(exists( select distinct(bsrc_text)
                   from BPEL..script_source
		  where bsrc_script_id = scp_id
                    and bsrc_role = scp_role ))
    { return 1; }
  else
    { return 0;};
};


create procedure BPEL..get_conf_param (in name varchar, in default_val any:=null)
{
  for select conf_value, conf_long_value from BPEL..configuration
	       where conf_name = name
  do {
    if (conf_long_value is null)
      {
	if (conf_value is null)
	  return default_val;
	return conf_value;
      }
    else
      return conf_long_value;
  }
  return default_val;
}
;

create procedure BPEL..set_conf_param (in name varchar, in val any)
{
  update BPEL..configuration set conf_value = val
               where conf_name = name;
  if (row_count() = 0)
    insert into BPEL..configuration (conf_name, conf_value) values (name, val);
}
;


create trigger set_conf_update after update on BPEL..configuration
{
  if (conf_name = 'Statistics')
    {
      if (conf_value = 1)
	{
	  for select bs_id from BPEL.BPEL.script
	  do {
	    BPEL..stat_init (bs_id);
	  }
	}
    }
}
;

create procedure BPEL..default_smtp_server ()
{
  declare mail_server varchar;
  mail_server := BPEL..get_conf_param ('MailServer');
  if (mail_server is null)
    return cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
  return mail_server;
}
;

create procedure BPEL..bpel_mail_address ()
{
  return BPEL..get_conf_param ('EngineMailAddress');
}
;

create procedure BPEL..send_mail_to (in subject varchar, in mail_address varchar, in content varchar)
{
  -- MUST NOT abort main task
  whenever sqlstate '*' goto err;
  declare _smtp_server, from_address, mail_header varchar;
  _smtp_server := BPEL..default_smtp_server();
  if (_smtp_server is null)
    return;
  if (mail_address is null)
    goto err;
  if (content is null)
    goto err;
  if ((from_address := BPEL..bpel_mail_address ()) is null)
    goto err;
  if ((mail_header := BPEL..get_conf_param ('CommonEmailHeader')) is null)
    goto err;

  content := mail_header || content;

  content := replace (replace (replace (replace (replace (content,
			'{SUBJECT}', subject),
			'{TO}', mail_address),
			'{FROM}', from_address),
		      -- needed to unify the unix/win caret return styles
			'\n\r','\n'),
			'\n','\r\n');
  smtp_send (_smtp_server, mail_address, from_address, content);
err:
  ;
}
;

-- report an error

create procedure BPEL..error_report (in inst integer, in err_vec any:=null)
{
  declare script_name, err, report varchar;
  declare cr cursor for select bs_name from BPEL.BPEL.script, BPEL.BPEL.instance
				     where bs_id = bi_script and bi_id = inst;
  declare exit handler for sqlstate '*' {
    return 'Error during creating the error report';
  };
  if (err_vec is not null)
    {
      err := sprintf ('[%s] %s', aref (err_vec, 0), aref (err_vec, 1));
    }
  else
    err := connection_get ('BPEL/Error');

  if (inst < 0)
    {
      script_name := 'Unknown';
    }
  else
    {
      open cr (prefetch 1);
      fetch cr into script_name;
      close cr;
    }
  report := BPEL..get_conf_param ('ErrorReportSkeleton');
  if (report is null)
    return NULL;
  report := replace (report, '{SCRIPT}', script_name);
  report := replace (report, '{ERROR}', err);
  report := replace (report, '{DATE}', cast (now() as varchar));
  report := replace (report, '{INSTANCE}', cast (inst as varchar));
  return report;
}
;

create procedure BPEL..error_alert (in err any)
{
  declare report varchar;
  report := BPEL..get_conf_param ('ErrorAlertSkeleton');
  if (report is null or not isstring (err))
    return;

  report := replace (report, '{ERROR}', err);
  report := replace (report, '{DATE}', cast (now() as varchar));
  return report;
}
;

create procedure BPEL..send_error_mail (in inst int, in e_state varchar, in e_message varchar)
{
  BPEL..send_mail_to (BPEL..get_conf_param ('ErrorSubject'),
		      BPEL..bpel_mail_address (),
		      BPEL..error_report(inst, vector (e_state, e_message)));
}
;

create procedure BPEL..send_error_alert (in e_str varchar)
{
  BPEL..send_mail_to (BPEL..get_conf_param ('AlertSubject'),
		      BPEL..bpel_mail_address (),
		      BPEL..error_alert (e_str));
}
;

create procedure BPEL.BPEL.strip_nsdecl (in cond any)
{
  declare tmp any;
  tmp := regexp_match ('^(\\[[^\\]]+\\])?[[:space:]]*(\\[[^\\]]+\\])?', cond);
  if (tmp is not null)
    cond := substring (cond, length (tmp) + 1, length (cond));
  return cond;
}
;

create procedure BPEL.BPEL.get_node(
  in scp_id int,
  in inst int,
  in intern_id varchar,
  in activs varbinary,
  in links varbinary,
  in name varchar )
{
  declare act,act1 BPEL.BPEL.activity;
  declare node_id, parent_id,iSet,iTgt,iSrc int;
  declare vName,vType,vLink varchar;
  declare cnt,iLink int;
  declare link_cond1,link_cond2 int;
  --dbg_obj_print('--begin------');


  declare cr cursor for select bg_activity, bg_node_id, bg_parent from BPEL..graph where bg_script_id = scp_id
    and bg_src_id = intern_id;

  declare exit handler for not found
  {
    close cr;
    goto notfn;
  };

  open cr (prefetch 1);
  fetch cr into act, node_id, parent_id;
  close cr;

  cnt := 0;
  BPEL.BPEL.get_pos(cnt,parent_id);
  iLink := bit_is_set (links, act.ba_id);
  vType := act.ba_type;

  iSet := bit_is_set (activs, act.ba_id);
  iTgt := length (act.ba_tgt_links);
  iSrc := length (act.ba_src_links);
  link_cond1 :=0;
  link_cond2 :=0;

  if (length (act.ba_tgt_links))
  {
    link_cond1 := 1;
    foreach (int lnk_id in act.ba_tgt_links) do
    {
      if (not bit_is_set (activs, lnk_id))
        link_cond1 := 0;
    }
  };

  if (length (act.ba_src_links))
  {
    declare i, l,lnk_id int;
    link_cond2 := 1;
    l := length (act.ba_src_links);
    for (i := 0; i < l; i := i + 2)
    {
      lnk_id := act.ba_src_links[i];
      if (not bit_is_set (activs, lnk_id))
        link_cond2 := 0;
    }
  };

  if (iTgt and iSrc)
  {
    if (link_cond1 and link_cond2)
      iSet := 1;
    else
      iSet := 0;
  }
  else if (iTgt)
  {
    if (link_cond1)
      iSet := 1;
    else
      iSet := 0;
  }
  else if (iSrc)
  {
    if (link_cond2)
      iSet := 1;
    else
      iSet := 0;
  };



  if (iSet)
  {
    connection_set ('BPEL_scope', act.ba_scope);
    connection_set ('BPEL_scope_inst', 0); -- ne se polzva
    connection_set ('BPEL_inst', inst);
    connection_set ('BPEL_script_id', scp_id);

    if (name = 'receive')
    {
      return XMLELEMENT('node',XMLATTRIBUTES((cnt*5) as "len",
                                              '1' as "valid",
                                              iLink as "bl",
                                              (act as BPEL.BPEL.receive).ba_name as "name",
                                              (act as BPEL.BPEL.receive).ba_partner_link as "plink",
                                              (act as BPEL.BPEL.receive).ba_port_type as "port",
                                              (act as BPEL.BPEL.receive).ba_operation as "oper",
                                              (act as BPEL.BPEL.receive).ba_var as "var",
                                              (act as BPEL.BPEL.receive).ba_create_inst as "ins",
                                              (act as BPEL.BPEL.receive).ba_one_way as "way",
                                              vType as "type",
                                              act.ba_id as "aid"
                                            ));
    }
    else if (name = 'reply')
    {
      return XMLELEMENT('node',XMLATTRIBUTES((cnt*5) as "len",
                                              '1' as "valid",
                                              iLink as "bl",
                                              (act as BPEL.BPEL.reply).ba_name as "name",
                                              vType as "type",
                                              vLink as "link",
                                              (act as BPEL.BPEL.reply).ba_partnerLink as "plink",
                                              (act as BPEL.BPEL.reply).ba_portType as "port",
                                              (act as BPEL.BPEL.reply).ba_operation as "oper",
                                              (act as BPEL.BPEL.reply).ba_variable as "var",
                                              act.ba_id as "aid"
                                            ));
    }
    else if (name = 'invoke')
    {
     --dbg_obj_print(BPEL..get_var ((act as BPEL.BPEL.invoke).ba_input_var, inst, 0));
      return XMLELEMENT('node',XMLATTRIBUTES((cnt*5) as "len", '1' as "valid", vType as "type",
                                              iLink as "bl",
                                              (act as BPEL.BPEL.invoke).ba_partner_link as "plink",
                                              (act as BPEL.BPEL.invoke).ba_port_type as "port",
                                              (act as BPEL.BPEL.invoke).ba_operation as "oper",
                                              (act as BPEL.BPEL.invoke).ba_input_var as "input",
                                              (act as BPEL.BPEL.invoke).ba_output_var as "output",
                                              act.ba_id as "aid"
                                            ));
    }
    else if (name = 'scope')
    {
      return XMLELEMENT('node',XMLATTRIBUTES((cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              (act as BPEL.BPEL.scope).ba_name as "name",
                                              act.ba_id as "aid"
                                             ));
    }
    else if (name = 'sequence')
     {
      --dbg_printf('sequence link=%d',iLink);
      return XMLELEMENT('node',XMLATTRIBUTES((cnt*5) as "len", '1' as "valid", iLink as "bl", vType as "type",
                                              act.ba_id as "aid"
                                             ));
    }
     else if (name = 'copy')
     {
      return XMLELEMENT('node',XMLATTRIBUTES((cnt*5) as "len", '1' as "valid", iLink as "bl",
                                              act.ba_id as "aid"
                                             ));
     }
     else if (name = 'while')
     {
      return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              BPEL.BPEL.strip_nsdecl ((act as BPEL.BPEL.while_st).ba_condition) as "cond",
                                              act.ba_id as "aid"
                                             ));
     }
     else if (name = 'case')
     {
      return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              BPEL.BPEL.strip_nsdecl ((act as BPEL.BPEL.case1).ba_condition) as "cond",
                                              act.ba_id as "aid"
                                             ));
     }
     else if (name = 'empty')
     {
      return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              (act as BPEL.BPEL.empty).ba_type as "type",
                                              act.ba_id as "aid"
                                             ));
     }
     else if (name = 'throw')
     {
      return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              (act as BPEL.BPEL.throw).ba_fault as "fault",
                                              act.ba_id as "aid"
                                             ));
     }
     else if (name = 'switch')
     {
       return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              act.ba_id as "aid"
                                            ));
     }
     else if (name = 'pick')
     {
       return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              act.ba_id as "aid"
                                            ));
     }
     else if (name = 'comphandler')
     {
       return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              act.ba_id as "aid"
                                            ));
     }
     else if (name = 'compensate')
     {
       return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              (act as BPEL.BPEL.compensate).ba_scope_name as "name",
                                              act.ba_id as "aid"
                                            ));
     }
     else if (name = 'catch')
     {
       return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              (act as BPEL.BPEL.catch).ba_fault as "fault",
                                              (act as BPEL.BPEL.catch).ba_var as "input",
                                              act.ba_id as "aid"
                                            ));
     }
     else if (name = 'fault')
     {
       return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              (act as BPEL.BPEL.fault_handlers).ba_type as "type",
                                              act.ba_id as "aid"
                                            ));
     }
     else if (name = 'flow')
     {
       return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              act.ba_id as "aid"
                                            ));
     }
     else if (name = 'onalarm')
     {
      return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              (act as BPEL.BPEL.onalarm).ba_for_exp as "for",
                                              (act as BPEL.BPEL.onalarm).ba_until_exp as "until",
                                              act.ba_id as "aid"
                                            ));
     }
     else if (name = 'onmessage')
     {
      return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              (act as BPEL.BPEL.receive).ba_partner_link as "plink",
                                              (act as BPEL.BPEL.receive).ba_port_type as "port",
                                              (act as BPEL.BPEL.receive).ba_operation as "oper",
                                              (act as BPEL.BPEL.receive).ba_var as "input",
                                              act.ba_id as "aid"
                                            ));
     }
     else if (name = 'link')
     {
      return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              (act as BPEL.BPEL.link).ba_name as "name",
                                              act.ba_id as "aid"
                                           ));
     }
     else if (name = 'terminate')
     {
      return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              act.ba_id as "aid"
                                            ));
     }
     else if (name = 'scope')
     {
      return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              act.ba_id as "aid"
                                            ));
     }
     else if (name = 'otherwise')
     {
      return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              act.ba_id as "aid"
                                            ));
     }
     else if (name = 'wait')
     {
      return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              (act as BPEL.BPEL.wait).ba_seconds as "value",
                                              act.ba_id as "aid"
                                            ));
     }
     else if (name = 'exec')
     {
       if (act.ba_type = 'EXEC/SQL')
	 return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              (act as BPEL.BPEL.sql_exec).ba_proc_name as "name",
                                              (act as BPEL.BPEL.sql_exec).ba_sql_text as "stext",
                                              act.ba_id as "aid"
                                            ));
       if (act.ba_type = 'EXEC/Java')
	 return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              (act as BPEL.BPEL.java_exec).ba_class_name as "name",
                                              act.ba_id as "aid"
                                            ));
       if (act.ba_type = 'EXEC/CLR')
	 return XMLELEMENT('node',XMLATTRIBUTES( (cnt*5) as "len", '1' as "valid",
                                              iLink as "bl",
                                              vType as "type",
                                              (act as BPEL.BPEL.clr_exec).ba_class_name as "name"
                                            ));
     }
     else
     {
       --dbg_obj_print('not case');
       return XMLELEMENT('node',XMLATTRIBUTES((cnt*5) as "len", '1' as "valid",vType as "type", iLink as "bl",
                                              act.ba_id as "aid"));
     };

  }
  else
    {
      --dbg_obj_print('not set');
      return XMLELEMENT('node',XMLATTRIBUTES((cnt*5) as "len", '0' as "valid"));
    };

  notfn: {
          --dbg_obj_print('not found');
          return XMLELEMENT('node',XMLATTRIBUTES((cnt*5) as "len", '2' as "valid"));
         };
}
;

grant execute on BPEL.BPEL.get_node to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:get_node',
	        fix_identifier_case ('BPEL.BPEL.get_node'))
;

create procedure BPEL.BPEL.xpath_eval1(in expr varchar, in doc any)
{
  return cast(xpath_eval(concat('//@',expr), doc) as varchar);
}
;

grant execute on BPEL.BPEL.xpath_eval1 to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:xpath_eval1',
	        fix_identifier_case ('BPEL.BPEL.xpath_eval1'))
;


create procedure BPEL.BPEL.get_pos(inout cnt int, in node_id int)
{

  for select bg_parent from BPEL.BPEL.graph
		where bg_node_id = node_id
  do
   {
     cnt := cnt + 1;
     BPEL.BPEL.get_pos(cnt, bg_parent);
   };
}
;

create procedure BPEL..make_error (in st varchar, in text varchar)
{
  if (text is null)
    return null;
  return vector (st, text);
}
;

create procedure BPEL.BPEL.get_assign(in scp_id int, in intern_id varchar, in mode int)
{
  declare act BPEL.BPEL.activity;
  declare vFrom,vTo BPEL.BPEL.place;
  declare node_id int;
  declare vName varchar;

  declare cr cursor for select bg_activity, bg_node_id from BPEL..graph where bg_script_id = scp_id
    and bg_src_id = intern_id;

  declare exit handler for not found
  {
    close cr;
    goto notfn;
  };

  open cr (prefetch 1);
  fetch cr into act, node_id;
  close cr;

  vFrom := (act as BPEL.BPEL.assign).ba_from;
  vTo := (act as BPEL.BPEL.assign).ba_to;

  if (mode = 1)
  {
    if (udt_instance_of (vFrom, 'BPEL.BPEL.place_vpa')) -- mode = 1
    {
      return XMLELEMENT('node',XMLATTRIBUTES(((vFrom as BPEL.BPEL.place_vpa).ba_var) as "var",
                                             ((vFrom as BPEL.BPEL.place_vpa).ba_part) as "part",
                                             ((vFrom as BPEL.BPEL.place_vpa).ba_query) as "query"
                                            ));
    }
    else if (udt_instance_of (vFrom, 'BPEL.BPEL.place_vpr')) -- mode = 2
    {
      return XMLELEMENT('node',XMLATTRIBUTES(((vFrom as BPEL.BPEL.place_vpr).ba_var) as "var",
                                             ((vFrom as BPEL.BPEL.place_vpr).ba_property) as "property"
                                            ));
    }
    else if (udt_instance_of (vFrom, 'BPEL.BPEL.place_plep')) -- mode = 3
    {
      return XMLELEMENT('node',XMLATTRIBUTES(((vFrom as BPEL.BPEL.place_plep).ba_pl) as "pl",
                                             ((vFrom as BPEL.BPEL.place_plep).ba_ep) as "ep"
                                            ));
    }
    else if (udt_instance_of (vFrom, 'BPEL.BPEL.place_expr')) -- mode = 4
    {
      return XMLELEMENT('node',XMLATTRIBUTES(((vFrom as BPEL.BPEL.place_expr).ba_exp) as "expr"
                                            ));
    }
    else if (udt_instance_of (vFrom, 'BPEL.BPEL.place_text')) -- mode = 5
    {
      --dbg_obj_print((vFrom as BPEL.BPEL.place_text).ba_text);
      return XMLELEMENT('node',XMLATTRIBUTES(((vFrom as BPEL.BPEL.place_text).ba_text) as "txt"
                                            ));
    }
  }
  else if (mode = 2)
  {
    if (udt_instance_of (vTo, 'BPEL.BPEL.place_vpa')) -- mode = 6
    {
      return XMLELEMENT('node',XMLATTRIBUTES(((vTo as BPEL.BPEL.place_vpa).ba_var) as "var",
                                             ((vTo as BPEL.BPEL.place_vpa).ba_part) as "part",
                                             ((vTo as BPEL.BPEL.place_vpa).ba_query) as "query"
                                            ));
    }
    else if (udt_instance_of (vTo, 'BPEL.BPEL.place_vpr')) -- mode = 7
    {
      return XMLELEMENT('node',XMLATTRIBUTES(((vTo as BPEL.BPEL.place_vpr).ba_var) as "var",
                                             ((vTo as BPEL.BPEL.place_vpr).ba_property) as "property"
                                            ));
    }
    else if (udt_instance_of (vTo, 'BPEL.BPEL.place_plep')) -- mode = 8
    {
      return XMLELEMENT('node',XMLATTRIBUTES(((vTo as BPEL.BPEL.place_plep).ba_pl) as "pl"
                                            ));
    }
    else if (udt_instance_of (vTo, 'BPEL.BPEL.place_vq')) -- mode = 9
    {
      return XMLELEMENT('node',XMLATTRIBUTES(((vTo as BPEL.BPEL.place_vq).ba_var) as "var",
                                             ((vTo as BPEL.BPEL.place_vq).ba_query) as "query"
                                            ));
    };
  };

  notfn: {
          --dbg_obj_print('not found');
          return '';
         };
}
;


grant execute on BPEL.BPEL.get_assign to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:get_assign',
	        fix_identifier_case ('BPEL.BPEL.get_assign'))
;


create procedure BPEL.BPEL.get_link(in linkname varchar)
{
  declare scope, scope_inst, inst, scr, act_id int;
  declare activs, links varbinary;
  declare cr cursor for select bl_act_id from BPEL..links
	where bl_name = linkname and bl_script = scr and bl_act_id <= scope;
  declare inst cursor for select bi_activities_bf, bi_link_status_bf
	from BPEL.BPEL.instance where bi_id = inst;

  scope := connection_get ('BPEL_scope');
  scope_inst := connection_get ('BPEL_scope_inst');
  inst := connection_get ('BPEL_inst');
  scr := connection_get ('BPEL_script_id');

   declare exit handler for not found {
	  return 0;
	};

  open cr (prefetch 1);
  fetch cr into act_id;
  close cr;

  open inst (prefetch 1);
  fetch inst into activs, links;
  close inst;

  if (bit_is_set (activs, act_id) and bit_is_set (links, act_id))
    return 1;
  return 0;

}
;


grant execute on BPEL.BPEL.get_link to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:get_link',
	        fix_identifier_case ('BPEL.BPEL.get_link'))
;

create procedure BPEL..get_line (in txt varchar)
{
  return regexp_match ('[^\r\n]*', txt);
}
;

create procedure BPEL..make_connection_error_string (in sql_st varchar, in sql_mess varchar,
						     in pl varchar,
						     in act_name varchar,
						     in endpoint varchar,
						     in parameters any)
{
  declare xml_text varchar;
   --dbg_obj_print (parameters);
  if (isentity (parameters))
    xml_text := serialize_to_UTF8_xml (parameters);
  else if (isarray (parameters))
    xml_text := serialize_to_UTF8_xml (xml_tree_doc (parameters));
  else if (isstring (parameters))
    xml_text := parameters;
  else
    {
      declare x any;
      x := string_output ();
      http_value (parameters, null, x);
      xml_text := string_output_string (x);
    }
  sql_mess := replace (BPEL..get_line (sql_mess), '\042', '&quot;');
  sql_mess := replace (sql_mess, '\047', '&quot;');
  return xtree_doc (sprintf ('<comFault sqlState="%s" message="%s" partnerLink="%s" activity="%s" partnerURI="%s">
%s</comFault>', sql_st, sql_mess, pl, act_name, endpoint, xml_text));
}
;

create procedure BPEL..make_java_error (in sql_st varchar, in sql_mess varchar)
{
--  dbg_obj_print ( xtree_doc ('<javaFault sqlState="' || sql_st || '"><![CDATA[' || sql_mess || ']]></javaFault>'));
  return xtree_doc ('<javaFault sqlState="' || sql_st || '"><![CDATA[' || sql_mess || ']]></javaFault>');
}
;

create procedure BPEL..make_clr_error (in sql_st varchar, in sql_mess varchar)
{
--  dbg_obj_print ( xtree_doc ('<clrFault sqlState="' || sql_st || '"><![CDATA[' || sql_mess || ']]></clrFault>'));
  return xtree_doc ('<clrFault sqlState="' || sql_st || '"><![CDATA[' || sql_mess || ']]></clrFault>');
}
;

create procedure BPEL..check_link_cond (in act BPEL.BPEL.activity, in links any, in activs any)
{
  declare link_state,link_cond integer;
  link_state := 1;
  if (length (act.ba_tgt_links))
    {
      link_state := 0;
      link_cond := 1;
      foreach (int lnk_id in act.ba_tgt_links) do
	{
	  if (bit_is_set (links, lnk_id))
	    {
	      link_state := 1;
	    }
	  if (not bit_is_set (activs, lnk_id))
	    {
	      link_cond := 0;
	    }
	}
      -- not all links are ready
      if (not link_cond)
	{
	  if (act.ba_join_cond is not null)
	    {
	      -- needed for XPath expressions
	      connection_set ('BPEL_scope', act.ba_scope);
	      link_state := BPEL..xpath_evaluate0 (act.ba_join_cond);
	    }
        }
      else
        link_state := 1;
    }
  return link_state;
}
;

create procedure BPEL..search_undone_node (in inst integer, in links any, in activs any)
{
  declare min_node_id, ser_id, node integer;
  declare preds, activs varbinary;
  declare act BPEL.BPEL.activity;
  min_node_id := null;

  declare ins cursor for select	  bg_node_id,
				  bg_activity,
				  (bg_activity as BPEL.BPEL.activity).ba_preds_bf,
				  bi_activities_bf,
				  (bg_activity as BPEL.BPEL.activity).ba_id
			  from BPEL.BPEL.graph, BPEL.BPEL.script, BPEL.BPEL.instance
			  where bg_script_id = bs_id
				  and bs_id = bi_script
				  and bi_id = inst;
  whenever not found goto notf;
  -- needed for XPath expressions
  connection_set ('BPEL_inst', inst);
  open ins;
  while (1)
    {
      fetch ins into node, act, preds, activs, ser_id;
      if (
	  v_equal (preds, v_bit_and (preds, activs))
	  and not bit_is_set (activs, ser_id)
	  and not bit_is_set (links, ser_id)
	 )
	{
	  --dbg_obj_print (act);
	  if ((min_node_id is null) and BPEL..check_link_cond (act, links, activs))
	    {
	      min_node_id := node;
	      --dbg_obj_print ('restarting from', act.ba_id, act.ba_type);
	      goto notf;
	    }
	}
    }
 notf:
  close ins;
  return min_node_id;
}
;

create procedure BPEL.BPEL.str_param(inout pArray any,in pName varchar)
  {
    declare i, l integer;
    declare aArrayNew any;

    aArrayNew := vector();
    i := 0;
    l := length(pArray);

    if (not BPEL.BPEL.is_vector(pArray))
      signal('9002','Not an Array');

    if(mod(l,2) <> 0)
      signal('9001','Array No Associative');

    while (i < l) {
      if (locate( pName,pArray[i])> 0)
        aArrayNew := vector_concat(aArrayNew, vector(pArray[i+1]));
      i := i + 2;
    };
    return  aArrayNew;
  }
;

create procedure BPEL.BPEL.is_vector(in pVector any)
  {
    if (isarray(pVector) and not isstring(pVector))
      return 1;
    return 0;
  }
;

create procedure BPEL.BPEL.delete_instances(in pArr any)
  {
   declare i, l int;

   l := length(pArr);
   for (i := 0; i < l; i := i + 1)
     {
        BPEL..instance_delete(pArr[i]);
     };
  }
;

create procedure BPEL.BPEL.delete_script_childs(in p_id int)
{

 for select bs_id from BPEL..script
		where bs_parent_id = p_id
  do
   {
     BPEL.BPEL.stop_process(bs_id);
     BPEL..script_delete(bs_id,1);
     BPEL.BPEL.delete_script_childs(bs_id);
   };
}
;

create procedure BPEL.BPEL.delete_script_parents(in p_name varchar)
{

  for select bs_id from BPEL.BPEL.script
		where bs_name = p_name
  do
   {
     BPEL.BPEL.stop_process(bs_id);
     BPEL..script_delete(bs_id,1);
     --BPEL.BPEL.delete_script_childs(p_id);
     --BPEL.BPEL.delete_script_parents(bs_parent_id);

   };
}
;

/* to restart instance */
create procedure BPEL.BPEL.inst_restart (in inst integer)
{
  http_request_status ('HTTP/1.1 202 Accepted');
  http_flush();
  BPEL.BPEL.inst_restart_1 (inst, 1);
}
;

create procedure BPEL.BPEL.inst_restart_1 (in inst integer, in logrest int := 1)
{
  declare cr cursor for select bs_audit, bs_id, bs_first_node_id from BPEL.BPEL.instance, BPEL.BPEL.script
    where bi_id = inst and bs_id = bi_script;
  declare ins cursor for select bi_activities_bf, bi_link_status_bf
	from BPEL.BPEL.instance where bi_id = inst;
  declare links, activs any;
  declare audit_fl, scp_id, first_node int;

  open cr (prefetch 1);
  fetch cr into audit_fl, scp_id, first_node;
  close cr;

  open ins (prefetch 1);
  fetch ins into activs, links;
  close ins;

  declare rc, node int;
  node := BPEL..search_undone_node (inst, links, activs);

   --dbg_obj_print ('wnode=', node);
  commit work;
  if (node is not null)
    {
      declare rc integer;
      if (audit_fl = 1 and logrest)
        BPEL..add_audit_entry (inst, -4, sprintf ('Restarting from node %d', node));
      commit work;
      rc := BPEL..resume (inst, scp_id, null, node);
       --dbg_obj_print ('rc := ', rc);
      rc := BPEL..resume (inst, scp_id, null, node);
       --dbg_obj_print ('rc2 := ', rc);
    }
}
;

create procedure BPEL.BPEL.inst_step (in inst int)
{
  update BPEL.BPEL.instance set bi_state = 1 where bi_state = 0 and bi_id = inst;
  BPEL.BPEL.inst_restart_1 (inst, 0);
}
;

create procedure BPEL.BPEL.restart_instances(in aArr any)
{
  declare l,i int;
  l := length (aArr);
  while (i < l)
    {
      commit work;
      DB.DBA.SOAP_CLIENT (url=>sprintf ('http://localhost:%s/BPEL',server_http_port()),
				 soap_action=>'inst_restart',
				 operation=>'inst_restart',
				 parameters =>  vector ('inst', aArr[i]),
				 direction=>1);
      i := i + 1;
    }
}
;



create procedure BPEL.BPEL.RESTART_ALL_INSTANCES ()
{
  declare ids any;
  ids := vector ();
  for select bi_id from BPEL.BPEL.instance
	       where bi_state <> 2 -- ready_to_restart, suspended, running
  do {
    ids := vector_concat (ids, vector (bi_id));
  }
  update BPEL.BPEL.instance set bi_state = 1 where bi_state = 0;

  declare idx integer;
  declare ret any;
  idx := 0;
  while (idx < length (ids))
    {
      commit work;
      ret := DB.DBA.SOAP_CLIENT (url=>sprintf ('http://localhost:%s/BPEL',server_http_port()),
				 soap_action=>'inst_restart',
				 operation=>'inst_restart',
				 parameters =>  vector ('inst', aref (ids,idx)),
				 direction=>1);
      idx := idx + 1;
    }
  -- load all java classes if exist any
  for select hc_name from BPEL.BPEL.hosted_classes do
    {
whenever sqlstate '42001' goto relax;
      java_load_class (hc_name);
relax:
      ;
    }
}
;

create procedure BPEL..deadlock_delay ()
{
  return 20;
}
;

create procedure BPEL..max_deadlock_cnt ()
{
  return 6;
}
;

create procedure BPEL.BPEL.date_interval(in d datetime) {

  declare date_part varchar;
  declare time_part varchar;

  declare min_diff integer;
  declare day_diff integer;
  --dbg_obj_print (d);

  day_diff := datediff ('day', d, now ());

  if (day_diff < 1)
    {
      min_diff := datediff ('minute', d, now ());

      if (min_diff = 1)
        {
          return ('a minute ago');
  }
      else if (min_diff < 1)
        {
          return ('less than a minute ago');
        }
      else if (min_diff < 60)
  {
    return (sprintf ('%d minutes ago', min_diff));
  }
      else return (sprintf ('today at %d:%02d', hour (d), minute (d)));
    }

  if (day_diff < 2)
    {
      return (sprintf ('yesterday at %d:%02d', hour (d), minute (d)));
    }

  return (sprintf ('%d/%d/%d %d:%02d', year (d), month (d), dayofmonth (d), hour (d), minute (d)));
}
;

grant execute on BPEL.BPEL.date_interval to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:date_interval',
	        fix_identifier_case ('BPEL.BPEL.date_interval'))
;


create procedure BPEL.BPEL.check_audit_report (in inst varchar)
{
  whenever sqlstate '*' goto ign;
  declare inst_id integer;

  inst_id := cast(inst as integer);
  declare cr cursor for select bs_name from BPEL.BPEL.script, BPEL.BPEL.instance
	where bi_script = bs_id
	and bi_id = inst_id;

  declare bpel_nm, file_nm varchar;
  open cr (prefetch 1);
  fetch cr into bpel_nm;

  declare au_file_name varchar;
  declare afile_content long varchar;

  au_file_name := BPEL..audit_file_name(inst_id, bpel_nm);
  afile_content := file_to_string(au_file_name);
  return 1;

  ign: return 0;
}
;

grant execute on BPEL.BPEL.check_audit_report to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:check_audit_report',
	        fix_identifier_case ('BPEL.BPEL.check_audit_report'))
;

create procedure BPEL.BPEl.do_redirect(in url varchar, in sid varchar, in realm varchar)
{
  url := concat(url, sprintf ('&sid=%s&realm=%s',sid,realm));
  http_request_status ('HTTP/1.1 302 Found');
  http_header (concat('Location: ',url,'\r\n'));
};

create procedure BPEL.BPEL.xml_validate(in content any, in url varchar)
{
  xml_validate_schema (content, 0, url, 'UTF-8', 'x-any',
  	  'Validation=RIGOROUS Fsa=ERROR FsaBadWs=IGNORE BuildStandalone=ENABLE '||
  	  ' AttrMissing=ERROR AttrMisformat=ERROR AttrUnknown=ERROR MaxErrors=200 SignalOnError=ENABLE',
  	  'xs:', ':xs',
  	  BPEL.BPEL.res_base_uri() || 'bpel4ws/1.0/bpel.xsd');
};

create procedure BPEL.BPEL.check_partner_links (in bsrc_text any , in scp_id int)
{
  declare i, j, inst int;
  declare node,link, pname varchar;
  declare xt,pt any;

  pt := xpath_eval('/process/partnerLinks',bsrc_text);
  xt := xslt (BPEL.BPEL.res_base_uri () || 'bpel4ws/1.0/bpel_plinks.xsl', bsrc_text);
  i := 1;

  while(i){
    node := cast(xpath_eval('//partnerLink',pt,i) as varchar);
    if (node is not null)
    {
      pname := cast(xpath_eval('//partnerLink/@name',pt,i) as varchar);
            j := 1;
            inst := 0;
            while(j){
              link := cast(xpath_eval( '//activities/activity/@name',xt,j) as varchar);
              if (link is not null and link = pname)
              {
                inst := cast(xpath_eval( sprintf('//activities/activity[@name = ''%s'']/@inst',pname),xt,j) as integer);
                if (inst = 1) -- the partner Link is called from the script
                  j := 0;
                else
                  j := j + 1;
              }
              else
              {
                j := 0;
              };
            };
            -- the partner link must have uploaded wsdl file
            if (inst = 0)
            {
              if ( not exists ( select 1 from BPEL..script_source where bsrc_script_id = scp_id and bsrc_role = pname))
                 signal ('22023', sprintf('There is no wsdl file for partner link %s. Please upload such!',pname));
            };

      i := i + 1;
    }
    else
    {
      i := 0;
    };
  };


};

-- statistics

create procedure BPEL..stat_init (in scp_id integer)
{
  for select bo_partner_link, bo_name, bo_init
	       from BPEL.BPEL.operation
	       where
	         bo_script = scp_id
  do {
    if (not exists (select * from BPEL.BPEL.op_stat
    	where bos_process = scp_id and bos_plink = bo_partner_link and bos_op = bo_name))
	{
	    insert into BPEL.BPEL.op_stat (bos_process,bos_plink,bos_op)
		values (scp_id, bo_partner_link, bo_name);
	}


  }
  for select bg_activity
	       from BPEL.BPEL.graph
	       where
	         bg_script_id = scp_id
	         and (bg_activity as BPEL..activity).ba_type = 'Invoke'
  do {
    declare inv BPEL..invoke;
    inv := bg_activity;
    if (not exists (select * from BPEL.BPEL.op_stat
    	where bos_process = scp_id and bos_plink = inv.ba_partner_link and bos_op = inv.ba_operation))
	{
    		insert into BPEL.BPEL.op_stat (bos_process, bos_plink, bos_op) values (scp_id, inv.ba_partner_link,inv.ba_operation);
	}
  }
}
;

create procedure BPEL..stat_update_n_rec (in inst int, in scp_id int, in plink varchar, in op varchar, in val any)
{
  if (connection_get ('BPEL_stat') is null)
    return;
  whenever not found goto notf;
  declare cr cursor for select bos_n_receives, bos_data_in from BPEL.BPEL.op_stat
				 where bos_process = scp_id and bos_plink = plink and bos_op = op;
  declare n_rec, data_in integer;
  open cr (exclusive, prefetch 1);
  fetch cr into n_rec, data_in;
  update BPEL.BPEL.op_stat set bos_n_receives = n_rec + 1, bos_data_in = data_in + BPEL..stat_sz (val)
      where current of cr;
  close cr;
  return;
 notf:
  insert soft BPEL.BPEL.op_stat (bos_n_receives, bos_data_in, bos_process, bos_plink, bos_op)
    values (1, BPEL..stat_sz (val), scp_id, plink, op);
}
;

create procedure BPEL..stat_update_cum_wait (in inst int, in scp_id int, in plink varchar, in op varchar, in start datetime, in now datatime)
{
  if (connection_get ('BPEL_stat') is null)
    return;
  whenever not found goto notf;
  declare cr cursor for select bos_cum_wait from BPEL.BPEL.op_stat
				 where bos_process = scp_id and bos_plink = plink and bos_op = op;
  declare cum_wait numeric;
  open cr (exclusive, prefetch 1);
  fetch cr into cum_wait;

  update BPEL.BPEL.op_stat set bos_cum_wait = cum_wait + datediff ('millisecond', start, now)
    where current of cr;
  close cr;
  return;
 notf:
  insert soft BPEL.BPEL.op_stat (bos_cum_wait, bos_process, bos_plink, bos_op)
    values (datediff ('millisecond', start, now), scp_id, plink, op);
}
;


create procedure BPEL..stat_update_n_inv (in inst int, in scp_id int, in plink varchar, in op varchar, in pars any)
{
  if (connection_get ('BPEL_stat') is null)
    return;
  whenever not found goto notf;
  declare cr cursor for select bos_n_invokes, bos_data_out from BPEL.BPEL.op_stat
				 where bos_process = scp_id and bos_plink = plink and bos_op = op;
  declare n_invokes, data_out integer;
  open cr (exclusive, prefetch 1);
  fetch cr into n_invokes, data_out;

  update BPEL.BPEL.op_stat set bos_n_invokes = n_invokes + 1, bos_data_out = data_out + BPEL..stat_sz (pars)
    where current of cr;
  close cr;
  return;
 notf:
  insert soft BPEL.BPEL.op_stat (bos_n_invokes, bos_data_out, bos_process, bos_plink, bos_op)
    values (1,BPEL..stat_sz (pars), scp_id, plink, op);
}
;

create procedure BPEL..stat_inc_pl_errors (in inst int , in scp_id int, in plink varchar, in op varchar)
{
  if (connection_get ('BPEL_stat') is null)
    return;
  whenever not found goto notf;
  declare cr cursor for select bos_n_errors from BPEL.BPEL.op_stat
				 where bos_process = scp_id and bos_plink = plink and bos_op = op;
  declare n_errs integer;
  open cr (exclusive, prefetch 1);
  fetch cr into n_errs;

  update BPEL.BPEL.op_stat set bos_n_errors = n_errs + 1
    where current of cr;
  close cr;
  return;
 notf:
  insert soft BPEL.BPEL.op_stat (bos_n_errors, bos_process, bos_plink, bos_op)
    values (1, scp_id, plink, op);
}
;

create procedure BPEL..stat_inc_errors (in inst int, in scp_id int)
{
  if (connection_get ('BPEL_stat') is null)
    return;
  whenever not found goto notf;
  declare cr cursor for select bs_n_errors from BPEL.BPEL.script
				 where bs_id = scp_id;
  declare n_errs integer;
  open cr (exclusive, prefetch 1);
  fetch cr into n_errs;

  update BPEL.BPEL.script set bs_n_errors = n_errs + 1
    where current of cr;
  close cr;
 notf:
  ;
}
;


create procedure BPEL..stat_sz (in obj any)
{
  if (connection_get ('BPEL_stat') is null)
    return 0;
  if (isarray (obj))
    {
      declare idx int;
      declare sz int;
      idx := 0;
      sz := 0;
      while (idx < length (obj))
	{
	  sz:=sz + BPEL..stat_sz (aref (obj, idx));
	  idx := idx + 1;
	}
      return sz;
    }
  if (isentity (obj))
    {
      return length (serialize_to_UTF8_xml (obj));
    }
  return raw_length (obj);
}
;

create procedure BPEL..process_clear_stats (in script int)
{
  if (connection_get ('BPEL_stat') is null)
    return 0;
  delete from BPEL.BPEL.op_stat where bos_process = script;
  update BPEL.BPEL.script set bs_n_completed = 0, bs_n_errors = 0, bs_n_create = 0 where bs_id = script;
}
;

create procedure BPEL.BPEL.archive_instance (in inst int, inout ss any)
{
  declare scp_id, activs, links, err, ts, node, st, err1 any;
  declare act BPEL.BPEL.activity;
  declare cr cursor for select bi_script, bi_activities_bf,  bi_link_status_bf, bi_error, bi_last_act, bi_state
	from BPEL.BPEL.instance where bi_id = inst;
  declare gr cursor for select bg_node_id, bg_activity from BPEL.BPEL.graph where bg_script_id = scp_id;
  declare va cursor for select v_name, BPEL..get_var (v_name, inst, 0, 0) from BPEL..variables
	where v_inst = inst and v_scope_inst = 0;
  declare pl cursor for select pl_name, pl_endpoint
	from BPEL..partner_link where pl_inst = inst and pl_scope_inst = 0;

  declare vname, varval any;

  http (sprintf ('<instance id="%d">\n', inst), ss);
  whenever not found goto nf;
  open cr (exclusive, prefetch 1);
  fetch cr into scp_id, activs, links, err, ts, st;
  if (isarray (err) and not isstring (err))
    err1 := regexp_match ('^.*', err[1]);
  else
    err1 := err;
  http (sprintf ('<status code="%d" error="%V" />\n', st, coalesce (err1, '')), ss);
  whenever not found goto nf1;
  open gr;
  http ('<execution>\n', ss);
  while (1)
    {
      fetch gr into node, act;
      if (bit_is_set (activs, act.ba_id) and bit_is_set (links, act.ba_id))
        {
          http (sprintf ('<node id="%d" type="%s"/>\n', act.ba_id, act.ba_type), ss);
        }
    }
  nf1:
  close gr;
  http ('</execution>\n', ss);

  whenever not found goto nf2;
  open va;
  http ('<variables>\n', ss);
  while (1)
    {
      fetch va into vname, varval;
      if (vname not in ('@request@', '@result@'))
        {
	  http (sprintf ('<variable name="%s"><![CDATA[\n', vname), ss);
	  http_value (varval, null, ss);
	  http (sprintf ('\n]]></variable>\n'), ss);
        }
    }
  nf2:
  close va;
  http ('</variables>\n', ss);

  whenever not found goto nf3;
  open pl;
  http ('<partnerLinks>\n', ss);
  while (1)
    {
      fetch pl into vname, varval;
      http (sprintf ('<partnerLink name="%s">\n', vname), ss);
      http (sprintf ('<EndpointReference><Address>%s</Address></EndpointReference>', coalesce (varval, '')),
	 ss);
      http (sprintf ('\n</partnerLink>\n'), ss);
    }
  nf3:
  close pl;
  http ('</partnerLinks>\n', ss);

  nf:
  close cr;
  http ('</instance>', ss);
  return ;
}
;


create procedure BPEL.BPEL.archive_instances (in completed_before any)
{
  declare ss, fn, dt any;
  declare seq, have_one int;

  BPEL..make_archive_dir ();

  dt := now ();
  seq := 0; have_one := 0;
  fn := sprintf ('%s/bpel-%04d%02d%02d%02d%02d%04d', BPEL..archive_dir (),
	year (dt), month (dt), dayofmonth (dt), hour(dt), minute(dt), seq);
  ss := string_output ();
  http ('<instances>', ss);
  for select bi_id from BPEL..instance where bi_last_act < completed_before and bi_state in (3, 2) do
    {
       BPEL.BPEL.archive_instance (bi_id, ss);
       have_one := 1;
       if (length (ss) > 1000000)
         {
           http ('</instances>', ss);
           string_to_file (fn, ss, -2);
 	   seq := seq + 1;
  	   fn := sprintf ('%s/bpel-%04d%02d%02d%02d%02d%04d', BPEL..archive_dir (),
	    year (dt), month (dt), dayofmonth (dt), hour(dt), minute(dt), seq);
           have_one := 0;
           string_output_flush (ss);
           http ('<instances>', ss);
         }
    }
  http ('</instances>', ss);
  if (have_one)
    string_to_file (fn, ss, -2);
  return;
}
;

create procedure BPEL.BPEL.scheduled_tasks ()
{
  declare intl any;
  intl := BPEL..get_conf_param ('InstanceExpiryDelay');
  if (isstring (intl))
    intl := atoi (intl);
  if (intl is not null and intl > 0)
    {
      declare up_to any;
      up_to := dateadd ('hour', -1*intl, now());
      BPEL..purge_instance (up_to);
    }
}
;

insert soft DB.DBA.SYS_SCHEDULED_EVENT (SE_INTERVAL, SE_LAST_COMPLETED, SE_NAME, SE_SQL, SE_START)
	values (10, NULL, 'BPEL_SCHEDULED_TASKS', 'BPEL.BPEL.scheduled_tasks ()', now())
;

create procedure BPEL.BPEL.get_text (in pText varchar, in pSec integer)
{
  declare aArr any;
  if (pText = 'any' or pText is null) return -1;
  aArr := split_and_decode(pText,0,'\0\0,');
  if (not isarray(aArr)) return -1;
  aArr := split_and_decode(aArr[pSec],0,'\0\0:');
  if (not isarray(aArr)) return -1;
  return cast(aArr[1] as integer);
}
;


create procedure BPEL.BPEL.reset_statistics()
{
  update BPEL.BPEL.op_stat
     set bos_n_invokes = 0,
         bos_n_receives = 0,
         bos_cum_wait = 0,
         bos_data_in = 0,
         bos_data_out =0;
  update BPEL.BPEL.script
     set bs_n_completed = 0,
         bs_n_errors = 0,
         bs_n_create = 0,
         bs_cum_wait = 0;
}
;

create procedure BPEL.BPEL.avg_process(in pWait int, in pComp int, in pErr int)
{
  declare iSum int;
  if (pWait = 0) return 0;
  iSum := pComp + pErr;
  if (iSum = 0) return 0;
  return ( pWait/ iSum );

}
;

create procedure BPEL.BPEL.endp_activity(in pProcess_id int, in pPartner_link varchar, in pOperation varchar)
{
  if (exists( select 1 from BPEL.BPEL.operation where bo_script = pProcess_id and bo_name = pOperation and bo_partner_link = pPartner_link))
     return 'receive';
  else if (exists( select 1 from BPEL.BPEL.remote_operation where ro_script = pProcess_id and ro_partner_link = pPartner_link and ro_operation = pOperation))
     return 'invoke';
  else
     return 'undefined';
}
;


create procedure BPEL.BPEL.get_xmldata1()
{
  return vector ( vector ( '1','1','1','1','1','1','1','1','1' ) ) ;
};


create procedure BPEL.BPEL.get_instances(in pQuery varchar, in pCond varchar, in pVal varchar, in pValID varchar, in pProcess varchar)
{
  declare mtd, dta any;
  declare sQuery, sWhere,sWhereAll varchar;
  declare datetime_before, datetime_since datetime;
  declare iVal int;

  sWhere := ' where bi_id ';
  sWhereAll := ' ORDER BY bi_id desc )f,
                  BPEL.BPEL.instance i,
                  BPEL.BPEL.script s
              where f.bi_id = i.bi_id
                and i.bi_script = s.bs_id  ';

  datetime_before := now();
  datetime_since := cast ('1990-01-01' as datetime);

  whenever sqlstate '22005' goto format_error;

  if (pVal = '' or pVal is null)
    pVal := '';

  if (pProcess = '' or pProcess is null)
    pProcess := '';

  sQuery := sprintf(' select f.bi_id,
                        i.bi_state,
                        i.bi_last_act,
                        i.bi_started,
                        BPEL..get_err_msg (i.bi_error),
                        s.bs_id,
                        s.bs_name,
                        s.bs_version,
                        s.bs_audit
                      from (select top 500 bi_id from BPEL.BPEL.instance ');
  --dbg_printf('pQuery=%s',pQuery);
  --if ( pQuery = '' or pQuery is null)
  --  pQuery := '0';


  -- bi_id
    if (pCond = '' or pCond is null)  pCond := ' > ';
    else if (pCond = '0')             pCond := ' > ';
    else if (pCond = '1')             pCond := ' < ';
    else if (pCond = '2')             pCond := ' = ';

    iVal := cast(pValID as integer);

    if (iVal is null)    iVal := 0;

    sWhere := concat(sWhere,pCond,cast(iVal as varchar));
  --

  if (pProcess <> '')
  {
    sWhereAll := concat(sWhereAll, ' and upper(bs_name) like ''%', upper(pProcess),'%''');
  }

  if (pQuery = '1' and pVal <> '')
  {
     datetime_since := BPEL.BPEL.datetime_format_parse (pVal);
     sWhere := sprintf('%s and datediff (''second'', bi_started, cast( ''%s'' as datetime)) < 1', sWhere, cast(datetime_since as varchar));
  }
  else if (pQuery = '2' and pVal <> '')
  {
     datetime_before := BPEL.BPEL.datetime_format_parse (pVal);
     sWhere := sprintf('%s and datediff (''second'', bi_started, cast(''%s'' as datetime)) > 1', sWhere, cast(datetime_before as varchar));
  };

  sQuery := concat(sQuery, sWhere, sWhereAll);
  --dbg_obj_print('------sQuery--------------');
  --dbg_obj_print(sQuery);

  exec (sQuery, null, null, vector (), 0, mtd, dta );
  return dta;

  format_error: BPEL.BPEL.report_error ('error: ', 'Datetime Format error');
}
;

create procedure BPEL.BPEL.set_backup_endpoint_by_name (in scp_uri varchar, in name varchar, in url varchar)
{
  for select bpl_script as scp_id  from BPEL.BPEL.partner_link_init, BPEL.BPEL.script
  	where bpl_script = bs_id and bs_name = scp_uri and bpl_name = name
  do {
    update BPEL.BPEL.partner_link_init set
  	bpl_backup_endpoint = url
	where bpl_script = scp_id and bpl_name = name;
    return url;
  }
  signal ('BPELX', 'Unknown partner link');
}
;

create procedure BPEL.BPEL.set_backup_endpoint (in scp int, in name varchar, in url varchar)
{
  declare cr cursor for select 1 from BPEL.BPEL.partner_link_init
  	where bpl_script = scp and bpl_name = name;
  declare xx int;
  open cr (prefetch 1);
  fetch cr into xx;

  update BPEL.BPEL.partner_link_init set
  	bpl_backup_endpoint = url
	where current of cr;
  close cr;
  return url;
}
;

create procedure BPEL.BPEL.check_relative(in content any)
{
  declare aXml any;
  declare i int;
  declare node varchar;

  aXml := xtree_doc(content);
  i := 1;

  while(i){
     node := cast(xpath_eval('/definitions/import/@location',aXml,i) as varchar);
     if (node is not null)
     {
       if ( locate('http://',node)=0  and  locate('file:/',node)=0 and  locate('https://',node)=0 )
          signal ('22023', 'There is relative path for import at wsdl file. Please entered full path to it.');
       i := i + 1;
     }
     else
     {
       i := 0;
     };
  };

}
;

-- dump all variables for java class...
create procedure BPEL..dump_inst_vars (in inst int, in scope int, in scope_inst int)
{
  declare ss, val any;
  ss := string_output ();
  for select v_name from BPEL..variables
	where v_inst = inst
	and v_scope_inst = scope_inst
  do  {
      http ('<variable Name="' || v_name || '">', ss);
      val := BPEL..get_var (v_name, inst, scope, scope_inst);
      if (isentity (val))
	http (serialize_to_UTF8_xml (val), ss);
      else if (val is not null)
	http (cast (val as varchar), ss);
      http ('</variable>', ss);
  }
  return string_output_string (ss);
}
;
-- set all vars from dump
create procedure BPEL..rest_inst_vars (in inst int, in scope int, in scope_inst int, in vars varchar)
{
  declare doc, var any;
  declare name varchar;
  declare idx int;
  doc := xtree_doc (vars);
  idx := 1;
  while ((var := xpath_eval ('/variable', doc, idx)) is not null)
    {
      name := xpath_eval ('@Name', var);
      declare var_ent any;
      if ((var_ent := xpath_eval ('*', var)) is not null)
	{
	  BPEL..set_var (name, inst, scope, var_ent, scope_inst);
	}
      idx := idx + 1;
    }
}
;

create procedure BPEL..adjust_type_to_varchar (inout val any)
{
  val := cast (val as varchar);
  --dbg_obj_print (val);
}
;

create procedure BPEL.BPEL.get_var_from_dump (in name varchar,
					      in part varchar,
					      in query varchar,
					      in vars varchar,
					      in xmlnss varchar)
{
  --dbg_obj_print ('From BPEL.BPEL.get_var_from_dump: ', name, part, query, vars, xmlnss);
  connection_set ('BPEL_xmlnss_pre', xmlnss);
  declare doc any;
  declare var_val, val, xq, nod, txt any;
  declare qry varchar;

  BPEL..adjust_type_to_varchar (name);
  BPEL..adjust_type_to_varchar (part);
  BPEL..adjust_type_to_varchar (query);
  BPEL..adjust_type_to_varchar (xmlnss);
  BPEL..adjust_type_to_varchar (vars);

  doc := xtree_doc (vars);
  var_val := xpath_eval ('/variable/* [../@Name="' || name || '"]', doc);
  --dbg_obj_print ('/variable/* [../@Name="' || name || '"]');
  --dbg_obj_print ('var_val:= ', var_val);
  if (not isentity (var_val) or (query = '' and part = ''))
    return cast (var_val as varchar);
  if (isentity (var_val))
      var_val := xml_cut (var_val);
  qry := sprintf ('/message/part[@name="%s"]', part);
  --dbg_obj_print ('qry:= ', qry);
  if (query = '' or query like '/%')
    {
      qry := xmlnss || qry || query;
--      qry := qry || query;
      --dbg_obj_print ('qry:= ', qry);
      xq := BPEL.BPEL.xpath_evaluate (qry, var_val);
      --dbg_obj_print ('xq= ', xq);
    }
  else
    {
      declare xq1 any;
      xq1 := BPEL.BPEL.xpath_evaluate (qry, var_val);
      if (xq1 is not null) -- XXX: may be we should prohibit further processing
	var_val := xml_cut (xq1);
      xq := BPEL.BPEL.xpath_evaluate (xmlnss || query, var_val);
--      xq := BPEL.BPEL.xpath_evaluate (query, var_val);
    }
  val := null;
  if (xq is not null and isentity (xq))
    {
      xq := xml_cut (xq);
      if ((nod := xpath_eval ('*', xq, 0)) is not null and length (nod) = 1)
         val := xml_cut (nod[0]);
      else if ((txt := xpath_eval ('node()', xq, 0)) is not null and length (txt) = 1)
         val := xml_cut (txt[0]);
      else
         val := xq;
    }
  else
     val := xq;
  --dbg_obj_print ('val=', val);
  if (isentity (val))
    {
      return serialize_to_UTF8_xml (val);
    }
  return cast (val as varchar);
}
;

create procedure BPEL.BPEL.java_init ()
{
  whenever sqlstate '42001' goto ign;
  BPEL..make_dir (BPEL..get_conf_param ('JavaClassesDir', 'classlib'));
  string_to_file (
    BPEL..get_conf_param ('JavaClassesDir', 'classlib') || '/BpelVarsAdaptor.class',
    uudecode (java_bpel_adaptor_class (),2),
    -2);
 ign:
  ;
}
;


create procedure BPEL.BPEL.set_var_to_dump (in name varchar,
			       in part varchar,
			       in query varchar,
			       in val varchar,
			       in vars varchar,
			       in xmlnss varchar)
{

  --dbg_obj_print ('set var:', name, part, query , val , vars , xmlnss);

  BPEL..adjust_type_to_varchar (name);
  BPEL..adjust_type_to_varchar (part);
  BPEL..adjust_type_to_varchar (query);
  BPEL..adjust_type_to_varchar (xmlnss);
  BPEL..adjust_type_to_varchar (vars);
  BPEL..adjust_type_to_varchar (val);

  declare var, qry, xq, sty any;
  --dbg_obj_print (self.ba_var, inst, scope, scope_inst);

  declare doc any;
  doc := xtree_doc (vars);

  var := xpath_eval ('/variable[@Name="' || name || '"]/*', doc);
  --dbg_obj_print ('/variable[@Name="' || name || '"]/*');
  --dbg_obj_print ('var:= ', var);

  if (not isentity (var) or (query = '' and part = ''))
    {
      --dbg_obj_print ('!!');
      XMLReplace (doc, var, val);
      return serialize_to_UTF8_xml (doc);
    }
  declare var_ent any;
  var_ent := var;
  if (isentity (var))
    var := xml_cut (var);

  qry := sprintf ('/message/part[@name="%s"]', part);
  --dbg_obj_print ('qry:', qry);

  if (query = '' and cast (xpath_eval (qry||'/@style', var) as varchar) = '0')
    qry := qry || '/' || part;
  --dbg_obj_print ('qry:', qry);

  if (query = '')
    qry := concat (qry);
  else
    qry := concat (qry, query);

  qry := xmlnss || qry;
  --dbg_obj_print ('qry:', qry);
  --dbg_obj_print ('var:', var);


  declare exit handler for sqlstate '*' {
    ;
    --dbg_obj_print (__SQL_STATE, __SQL_MESSAGE);
  };
  BPEL..set_value_to_var (qry, val, var);
  --dbg_obj_print ('var:', var);


  XMLReplace (doc, var_ent, var);
  --dbg_obj_print ('result:', doc);
  return serialize_to_UTF8_xml (doc);
}
;



create procedure BPEL.BPEL.get_endpoint(in scp_id int)
{
  declare vdir, url varchar;

  declare continue handler for NOT FOUND vdir := null;
  select bs_lpath, bs_name into vdir, url
    from BPEL..script
   where bs_id = scp_id;

  --dbg_obj_print(http_request_header(plines, 'Host', null, '*** NO HOST IN REQUEST ***'));

  if (vdir <> '' and vdir is not null)
    return  concat(vdir, '?wsdl');
  else
    return  concat('/BPELGUI/bpel.vsp?script=' ,url, '&wsdl');
}
;


grant execute on BPEL.BPEL.get_endpoint to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:get_endpoint',
	        fix_identifier_case ('BPEL.BPEL.get_endpoint'))
;

create procedure BPEL.BPEL.get_wsdl_name( inout content any, inout content_import any )
{
  declare i int;
  declare expn, vec any;
  declare vlink, plink, elm, elm_check varchar;

  expn :=  xslt (BPEL.BPEL.res_base_uri() || 'bpel4ws/1.0/bpelimport.xsl', content);
  vec := vector();
  i := 1;
  while(i){
    vlink := cast(xpath_eval( '//activities/activity/@plink',expn,i) as varchar);
   if ( vlink is not null and  vlink <> '')
    {
      plink := cast(xpath_eval( sprintf('//process/partnerLinks/partnerLink[@name="%s"]/@name',vlink), content) as varchar);
      if (plink is null)
        signal ('22023', 'There is activity with no partner link defined.');

      vec := BPEL.BPEL.vector_push(vec,plink,'any');
      i := i + 1;
    }
    else
    {
      i := 0;
    };
  };

  if ( length(vec) = 0)
    signal ('22023', 'There is no receive activity or pick activity defined which has createInstance = "yes".');

  i := 1;
  elm := vec[0];
  while (i < length (vec))
  {
    if (elm <> vec[i] or vec[i] is null)
      signal ('22023', 'Activities having createInstance = "yes" are more than one and partner links are different.');
    i := i + 1;
  };

  elm_check := cast(xpath_eval( sprintf('/BPELSuitcase/BPELProcess/partnerLinkBindings/partnerLinkBinding[@name="%s"]/property/.',elm ),content_import) as varchar);
  if (elm_check is null)
    signal ('22023', sprintf('There is no partnerLinkBinding defined with attribute name="%s".',elm ));

  return elm;
}
;

create procedure BPEL.BPEL.set_uri_connection(in pusr varchar := null, in ppwd varchar := null)
{
  if (pusr is not null and pusr <> '' and ppwd is not null and ppwd <> '')
    {
      connection_set('HTTP_CLI_UID',pusr);
      connection_set('HTTP_CLI_PWD',ppwd);
    };
  return;
};

create procedure BPEL.BPEL.xpath_eval2(in expr varchar, in doc any, in mode int := 0)
{
  if (mode = 1)
    return cast(xpath_eval(concat('//@',expr), doc) as varchar);
  else
    return '';
}
;

grant execute on BPEL.BPEL.xpath_eval2 to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:xpath_eval2',
	        fix_identifier_case ('BPEL.BPEL.xpath_eval2'))
;

