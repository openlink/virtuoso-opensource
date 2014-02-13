--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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
--use XMLA;

--drop type xmla_discover;

create type xmla_discover as
    (
      request_type varchar,
      restrictions any,
      properties   any,
      metadata	   any
    ) --temporary self as ref
constructor method xmla_discover (request_type varchar, restrictions any, properties any),
method xmla_discover_datasources () returns any,
method xmla_discover_properties () returns any,
method xmla_discover_schema_rowsets () returns any,
method xmla_discover_enumerators () returns any,
method xmla_discover_keywords () returns any,
method xmla_discover_literals () returns any,
method xmla_dbschema_catalogs () returns any,
method xmla_dbschema_columns () returns any,
method xmla_dbschema_foreign_keys () returns any,
method xmla_dbschema_primary_keys () returns any,
method xmla_dbschema_provider_types () returns any,
method xmla_dbschema_tables () returns any,
method xmla_dbschema_tables_info () returns any,
method xmla_get_restriction (pname varchar, deflt any) returns any,
method xmla_get_property (pname varchar, deflt any) returns any,
method xmla_command () returns any
;

--#IF VER=5
call exec_quiet ('alter type xmla_discover add method xmla_dbschema_foreign_keys () returns any')
;

call exec_quiet ('alter type xmla_discover add method xmla_dbschema_primary_keys () returns any')
;
--#ENDIF

create constructor method
xmla_discover (in request_type varchar, in restrictions any, in properties any) for xmla_discover
{
  self.request_type := request_type;
  self.restrictions := restrictions;
  self.properties   := properties;
}
;

create method
xmla_command () for xmla_discover
{
  declare h any;
  declare res any;
  h := udt_implements_method (self, fix_identifier_case ('xmla_' || lcase (self.request_type)));
  if (h)
    {
      res := call (h) (self);
      return res;
    }
  signal ('22023', 'Not supported request : ' || self.request_type, 'XMLA0');
}
;

create method
xmla_get_restriction (in pname varchar, in deflt any) for xmla_discover
{
  declare restr_list any;
  if (self.restrictions is not null)
    {
      restr_list := get_keyword ('RestrictionList', self.restrictions);
      if (restr_list is null)
	restr_list := get_keyword ('urn:schemas-microsoft-com:xml-analysis:RestrictionList', self.restrictions);
      if (restr_list is not null)
	{
	  declare val any;
          val := get_keyword (pname, restr_list);
	  if (val is null)
	    val := get_keyword ('urn:schemas-microsoft-com:xml-analysis:'||pname, restr_list, deflt);
	  return val;
	}
    }
  return deflt;
}
;

create method
xmla_get_property (in pname varchar, in deflt any) for xmla_discover
{
  return xmla_get_property (self.properties , pname, deflt);
}
;

create procedure
xmla_get_property (inout properties any, in pname varchar, in deflt any)
{
  declare prop_list, ses_prop, val any;
  declare i, l int;
  val := null;
  if (properties is not null)
    {
      prop_list := get_keyword ('PropertyList', properties, NULL);
      if (prop_list is null)
	prop_list := get_keyword ('urn:schemas-microsoft-com:xml-analysis:PropertyList', properties, NULL);
      if (prop_list is not null)
	{
	  val := get_keyword (pname, prop_list);
	  if (val is null)
	    val := get_keyword ('urn:schemas-microsoft-com:xml-analysis:'||pname, prop_list);
	}
      if (val is not null)
	return val;
    }
  ses_prop := connection_get ('XMLA_Properties');
  i := 0; l := length (ses_prop);
  while (i < l)
    {
      declare elm any;
      elm := ses_prop[i];
      if (elm[0] = pname)
        return elm[5];
      i := i + 1;
    }
  return deflt;
}
;


create procedure
xmla_result_xsd (in name varchar, in typ varchar, in typ_name varchar)
{
  return xslt ('http://local.virt/soap_sch',
       xml_tree_doc ('<complexType name="' || name ||
	  '" xmlns="http://www.w3.org/2001/XMLSchema"' ||
	  ' xmlns:tns="urn:schemas-microsoft-com:xml-analysis:rowset" targetNamespace="urn:schemas-microsoft-com:xml-analysis">' ||
	  '<all><element name="' || typ_name || '" type="tns:' || typ || '" /></all></complexType>'));
}
;

create procedure
xmla_session (in begin_session any, in end_session any, inout _session any, in properties any)
{
  declare sid varchar;
  if (_session is not null)
    {
      declare copy_ses, saved_props any;
      copy_ses := _session;
      _session := null;
      sid := xpath_eval ('/Session/@SessionID', xml_tree_doc (copy_ses), 1);
      saved_props :=
       (select deserialize (S_VARS) from WS.WS.SESSION where S_ID = cast (sid as varchar) and S_REALM = 'XMLA');
      connection_set ('XMLA_Properties', saved_props);
      properties := xmla_set_props (properties);
      update WS.WS.SESSION set S_VARS = serialize (properties), S_EXPIRE = dateadd ('minute', 10, now ())
             where S_ID = cast (sid as varchar) and S_REALM = 'XMLA';
      connection_set ('XMLA_Properties', properties);
      commit work;
    }
  else if (begin_session is not null)
    {
      sid := md5 (cast (now() as varchar) || 'XMLA');
      properties := xmla_set_props (properties);
      insert into WS.WS.SESSION (S_ID, S_EXPIRE, S_VARS, S_REALM)
	  values (sid, dateadd ('minute', 10, now ()), serialize (properties), 'XMLA');
      _session := xml_tree_doc (
		    '<XA:Session xmlns:XA="urn:schemas-microsoft-com:xml-analysis"'
		    || ' mustUnderstand="1" SessionID="' || sid || '"/>'
		    );
      connection_set ('XMLA_Properties', properties);
      commit work;
    }
  else if (end_session is not null)
    {
      sid := xpath_eval ('/EndSession/@SessionID', xml_tree_doc (end_session), 1);
      delete from WS.WS.SESSION where S_ID = cast (sid as varchar) and S_REALM = 'XMLA';
      commit work;
    }
}
;

create procedure
xmla_make_codes (in code varchar) returns varchar
{
  declare i, l int;
  declare res varchar;
  res := '';
  i := 0; l := length (code);
  while (i < l)
    {
      if (code[i] >= ascii ('0') and code[i] <= ascii ('9'))
        res := res || chr (code[i]);
      else
        res := res || sprintf ('%d', code[i]);
      i := i + 1;
    }
  return res;
}
;

create procedure
"Discover" (in  "RequestType" varchar,
    	    in  "Restrictions" any := NULL
	    --__soap_type 'http://openlinksw.com/virtuoso/xmla/types:Discover.Restrictions'
	    , in  "Properties" any
    	    --__soap_type 'http://openlinksw.com/virtuoso/xmla/types:Discover.Properties'
	    , in "BeginSession" any __soap_header '__XML__'
	    , in "EndSession" any __soap_header '__XML__'
	    , inout "Session" any __soap_header '__XML__'
	    , out "Error" any __soap_fault '__XML__'
	    , out "ws_xmla_xsd" any
	    )
	__soap_options (__soap_type:='__ANY__',
                 "soapAction":='urn:schemas-microsoft-com:xml-analysis:Discover',
                 "RequestNamespace":='urn:schemas-microsoft-com:xml-analysis',
                 "ResponseNamespace":='urn:schemas-microsoft-com:xml-analysis',
                 "PartName":='return'
	       )
{
  declare res, mdta any;
  declare discover xmla_discover;
  declare res_xsd any;
  declare exit handler for sqlstate '*'
    {
      declare xcode int;
      xcode := atoi (xmla_make_codes (__SQL_STATE));
      "Error" :=
	  xml_tree_doc (sprintf (
		'<Error ErrorCode="%d" Description="[%s] %V" Source="XML for Analysis Provider" HelpFile="" />',
		xcode, __SQL_STATE, __SQL_MESSAGE));
       http_request_status ('HTTP/1.1 500 Internal Server Error');
       connection_set ('SOAPFault', vector (sprintf ('XMLAnalysisError.0x%08x', xcode),
	     'The XML for Analysis provider encountered an error'));
       return;
    };
  xmla_session ("BeginSession", "EndSession", "Session", "Properties");
  discover := new xmla_discover ("RequestType", "Restrictions", "Properties");
  res := discover.xmla_command ();
  -- res needs to be reorganized
  mdta := discover.metadata;
  "ws_xmla_xsd" := vector_concat (vector (xmla_result_xsd ('return', 'root', 'root')) , DB.DBA.SOAP_LOAD_SCH (mdta, NULL, 1));
  return soap_box_structure ('root', vector_concat (vector (discover.metadata), res));
}
;

create procedure
"Execute"  (in  "Command" varchar
            --__soap_type 'http://openlinksw.com/virtuoso/xmla/types:Execute.Command'
	    , in  "Properties" any
	    --__soap_type 'http://openlinksw.com/virtuoso/xmla/types:Execute.Properties'
	    , in "BeginSession" any __soap_header '__XML__'
	    , in "EndSession" any __soap_header '__XML__'
	    , inout "Session" any __soap_header '__XML__'
	    , out "Error" any __soap_fault '__XML__'
	    , out "ws_xmla_xsd" any
	   )
	__soap_options ( __soap_type:='__ANY__',
                 "soapAction":='urn:schemas-microsoft-com:xml-analysis:Execute',
                 "RequestNamespace":='urn:schemas-microsoft-com:xml-analysis',
                 "ResponseNamespace":='urn:schemas-microsoft-com:xml-analysis',
                 "PartName":='return'
	       )
{
  declare res, mdta, dta any;
  declare cat, fmt, axis_fmt, what, dsn, state, msg, stmt, tree, blob_limit, stmt_is_ddl any;
  declare uname, passwd varchar;

  declare exit handler for sqlstate '*'
    {
      declare xcode int;
      xcode := atoi (xmla_make_codes (__SQL_STATE));
      "Error" :=
	  xml_tree_doc (sprintf (
		'<Error ErrorCode="%d" Description="[%s] %V" Source="XML for Analysis Provider" HelpFile="" />',
		xcode, __SQL_STATE, __SQL_MESSAGE));
       http_request_status ('HTTP/1.1 500 Internal Server Error');
       connection_set ('SOAPFault', vector (sprintf ('XMLAnalysisError.0x%08x', xcode),
	     'The XML for Analysis provider encountered an error'));
       return;
    };
  xmla_session ("BeginSession", "EndSession", "Session", "Properties");
  dsn := xmla_get_property ("Properties", 'DataSourceInfo', xmla_service_name ());
  dsn := xmla_get_dsn_name (dsn);

  uname := xmla_get_property ("Properties", 'UserName', null);
  passwd := xmla_get_property ("Properties", 'Password', null);

  if (uname is null and is_https_ctx ())
    {
      uname := connection_get ('SPARQLUserId'); -- if WebID ACL is checked
      passwd := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = uname);
    }

  -- XMLA command, no statement
  if (stmt is null and ("BeginSession" is not null or "EndSession" is not null))
    return xml_tree_doc ('<root xmlns="urn:schemas-microsoft-com:xml-analysis:empty" />');

  if (uname is null or passwd is null)
    signal ('00002', 'Unable to process the request, because the UserName property is not set or incorrect');

  state := '00000';
  stmt := get_keyword ('Statement', "Command");
  if (stmt is null)
    stmt := get_keyword ('urn:schemas-microsoft-com:xml-analysis:Statement', "Command");

  xmla_cursor_stmt_change ("Properties", stmt);

  cat := xmla_get_property ("Properties", 'Catalog', 'DB');
  fmt := xmla_get_property ("Properties", 'Format', 'Tabular');
  axis_fmt := xmla_get_property ("Properties", 'AxisFormat', 'TupleFormat');

  -- Allow only tabular data
  if (fmt not in ('Tabular') or axis_fmt not in ('TupleFormat'))
    signal ('00003', 'Unable to process the request, because the Format or AxisFormat property is not supported');

  what := xmla_get_property ("Properties", 'Content', 'SchemaData');

  set_user_id (uname, 1, passwd);
  set_qualifier (cat);

  dta := vector ();
  stmt_is_ddl := 0;
  if (not xmla_not_local_dsn (dsn))
    {
--	mxla_fk_pk_check_local (stmt, mdta, dta);
	tree := sql_parse (stmt);
	if (tree [0] = 609)
	  {
	    stmt := sprintf ('SELECT CAST (%s as VARCHAR)', stmt);
	    tree := sql_parse (stmt);
	  }
	if (tree [0] <> 100 and tree[0] <> 113)
	  {
	    if (registry_get ('XMLA-DML') = '1')
	      {
		exec_metadata ('select 1 as res', null, null, mdta);
		stmt_is_ddl := 1;
	      }
	    else
	      signal ('00004', 'Only select statements are supported via XML for Analysis provider');
	  }
	res := exec (stmt, state, msg, vector (), 0, mdta, dta);
	if (isinteger (dta))
	  dta := vector (vector (dta));
        if ((1 = length (dta)) and (1 = length (dta[0])) and (214 = __tag (dta[0][0])))
	  {
	    declare triples, inx any;
	    triples := dict_list_keys (dta[0][0], 1);
	    for (inx := 0; inx < length (triples); inx := inx + 1)
	      {
		declare trip any;
		trip := triples [inx];
		trip [0] := __ro2sq (trip[0]);
		trip [1] := __ro2sq (trip[1]);
		trip [2] := __ro2sq (trip[2]);
		triples [inx] := trip;
	      }
	    dta := triples;
	    exec_metadata ('select \'\' as S, \'\' as P, \'\' as O any', state, msg, mdta);
	  }
--  	if (strstr (stmt, 'FROM DB.DBA.SYS_FOREIGN_KEYS'))
--    	   xmla_add_quot_to_table (dta);
	blob_limit := atoi (xmla_get_property ("Properties", 'BLOBLimit', '0'));
	if (blob_limit > 0)
	   connection_set ('SOAPBlobLimit', blob_limit);
     }
   else
     {
--	mxla_fk_pk_check (dsn, stmt, mdta, dta);
	dsn := xmla_get_dsn_name (dsn);
	rexecute (dsn, stmt, state, msg, vector (), 0, mdta, dta);
     }

  if (state <> '00000')
    signal (state, msg);

  -- data needs to be re-organized
  xmla_format_mdta (mdta);
  if (not stmt_is_ddl)
  xmla_make_cursors_state ("Properties", dta, stmt);
  xmla_sparql_result (mdta, dta, stmt);
  xmla_make_struct (mdta, dta);
  "ws_xmla_xsd" := vector_concat (vector (xmla_result_xsd ('return', 'root', 'root')) , DB.DBA.SOAP_LOAD_SCH (mdta, NULL, 1));
  return soap_box_structure ('root', case what when 'Data' then dta
                   when 'Schema' then vector (mdta)
                   else vector_concat (vector(mdta), dta) end);
}
;


create procedure
xmla_not_local_dsn (in dsn varchar)
{
  declare nfo varchar;
  if (dsn is null)
    return 1;
  nfo := split_and_decode (dsn,0,'\0\0=');
  if (nfo[0] = xmla_service_name ())
    return 0;
  return 1;
}
;

create procedure
xmla_make_meta (in dta any)
{
  declare i, l, i1 int;
  declare res any;
  i := 0; l := length (dta);
  if (not isarray(dta) or l < 1)
    return NULL;
  dta := dta[0];
  l := length (dta);
  if (__tag(dta[0]) <> 255 or mod(l,2) <> 0 or l < 2)
    return NULL;
  res := make_array ((l/2) - 1, 'any'); i1 := 0; i := 2;
  while (i < l)
    {
      declare dtp any;
      dtp := __tag (dta[i+1]);
      aset (res, i1, vector (dta[i],
	      case when dtp = 193 and length(dta[i+1]) = 2 then 'boolean' else dtp end
	    ));
      i1 := i1 + 1;
      i := i + 2;
    }
  return res;
}
;


-- DataSources, for now this is a only local DSN and Tabular Data Provider, authentication
-- TBD: remote DSNs
create method
xmla_discover_datasources () returns any for xmla_discover
{
  declare dta, mdta, _all any;
  declare idx, has_vdb int;

  has_vdb := sys_stat ('st_has_vdb');
  if (has_vdb)
    _all := sql_data_sources (1);
  else
    _all := vector ();

  dta := vector (
         soap_box_structure (
	   'DataSourceName', 'Local Server',
	   'DataSourceDescription', 'Virtuoso Server',
	   'URL', soap_current_url (),
	   'DataSourceInfo', 'DSN=' || xmla_service_name(),
	   'ProviderName', 'Virtuoso XML for Analysis',
	   'ProviderType', soap_box_structure (
	   	'TDP', ''
	   	--'MDP', '',
	   	--'DMP', ''
	     ),
	   'AuthenticationMode', 'Authenticated'
	   ));

	 for (idx := 0; idx < length (_all); idx := idx + 1)
	   {
	     if (exists (select 1 from DB.DBA.SYS_DATA_SOURCE where DS_DSN = _all[idx][0]))
		{
		     dta := vector_concat (dta, vector (soap_box_structure (
		       'DataSourceName', _all[idx][0],
		       'DataSourceDescription', _all[idx][1],
		       'URL', soap_current_url (),
		       'DataSourceInfo', 'DSN=' || _all[idx][0],
		       'ProviderName', 'Virtuoso XML for Analysis',
		       'ProviderType', soap_box_structure (
			    'TDP', ''
			 ),
		       'AuthenticationMode', 'Authenticated'
		       )));
		}
	    };

  mdta := xmla_make_meta (dta);
  xmla_make_xsd (mdta);
  self.metadata := mdta;
  return dta;
}
;


create method
xmla_discover_properties () returns any for xmla_discover
{
  declare res, props, _dsn any;
  declare i, l int;

  _dsn := self.xmla_get_property ('DataSourceInfo', null);

  props := xmla_get_props (_dsn);
  l := length (props);
  i := 0;
  res := make_array (l, 'any');

  while (i < l)
    {
      declare prop any;
      prop := props[i];
      aset (res, i,
           soap_box_structure ('PropertyName', prop[0],
	                       'PropertyDescription', prop[1],
	       'PropertyType', prop[2],
	       'PropertyAccessType', case prop[3] when 'R' then 'Read' when 'W' then 'Write' else 'ReadWrite' end,
	       'IsRequired', soap_boolean(prop[4]),
	       'Value', prop[5])
	  );
      i := i + 1;
    }
  declare mdta any;
  mdta := xmla_make_meta (res);
  xmla_make_xsd (mdta);
  self.metadata := mdta;
  return res;
}
;

create method
xmla_discover_schema_rowsets () returns any for xmla_discover
{
  declare res, schs any;
  declare i, l int;

  schs := xmla_get_schs ();
  l := length (schs);
  i := 0;
  res := make_array (l, 'any');
  while (i < l)
    {
      declare sch any;
      sch := schs[i];
      aset (res, i,
           soap_box_structure ('SchemaName', sch[0],
	                       'Restrictions', sch[1],
	       		       'Description', sch[2])
	  );
      i := i + 1;
    }
  declare mdta any;
  mdta := xmla_make_meta (res);
  xmla_make_xsd (mdta);
  self.metadata := mdta;
  return res;
}
;


create method
xmla_discover_enumerators () returns any for xmla_discover
{
  declare res, enums any;
  declare i, l int;

  enums := xmla_get_enums ();
  l := length (enums);
  i := 0;
  res := make_array (l, 'any');
  while (i < l)
    {
      declare enum any;
      enum := enums[i];
      aset (res, i,
           soap_box_structure ('EnumName', enum[0],
	                       'EnumDescription', enum[1],
	       		       'EnumType', enum[2],
			       'ElementName', enum[3],
	       		       'ElementDescription', enum[4],
 		 	       'EnumValue', enum[5])
	  );
      i := i + 1;
    }
  declare mdta any;
  mdta := xmla_make_meta (res);
  xmla_make_xsd (mdta);
  self.metadata := mdta;
  return res;
}
;

create method
xmla_discover_keywords () returns any for xmla_discover
{
  declare kwds, res any;
  declare i, l int;
  declare dsn any;

  dsn := self.xmla_get_property ('DataSourceInfo', xmla_service_name ());
  dsn := xmla_get_dsn_name (dsn);

  if (not xmla_not_local_dsn (dsn))
     kwds := xmla_get_kwds ();
  else
    {
       declare _all any;
       dsn := xmla_get_dsn_name (dsn);
       _all := get_keyword (89, vdd_dsn_info(dsn), '');
       kwds := split_and_decode (_all, 0, '\0\0,');
    }

  l := length (kwds);
  i := 0;
  res := make_array (l, 'any');
  while (i < l)
    {
      aset (res, i,
           soap_box_structure ('Keyword', kwds[i])
	   );
      i := i + 1;
    }
  declare mdta any;
  mdta := xmla_make_meta (res);
  xmla_make_xsd (mdta);
  self.metadata := mdta;
  return res;
}
;

create method
xmla_discover_literals () returns any for xmla_discover
{
  declare res, lits any;
  declare i, l int;

  lits := xmla_get_literals ();
  l := length (lits);
  i := 0;
  res := make_array (l, 'any');
  while (i < l)
    {
      declare lit any;
      lit := lits[i];
      aset (res, i,
           soap_box_structure ('LiteralName', lit[0],
	                       'LiteralValue', lit[1],
	       		       'LiteralInvalidChars', lit[2],
			       'LiteralInvalidStartingChars', lit[3],
	       		       'LiteralMaxLength', lit[4]
 		 	       )
	  );
      i := i + 1;
    }
  declare mdta any;
  mdta := xmla_make_meta (res);
  xmla_make_xsd (mdta);
  self.metadata := mdta;
  return res;
}
;

create method
xmla_dbschema_catalogs () for xmla_discover
{
  declare dta, mdta, cat any;
  declare dsn any;

  dsn := self.xmla_get_property ('DataSourceInfo', xmla_service_name ());
  dsn := xmla_get_dsn_name (dsn);
  cat := self.xmla_get_restriction ('CATALOG_NAME', '%');
  if (cat is null)
    cat := '%';

  if (not xmla_not_local_dsn (dsn))
    {
      exec ('select distinct name_part(KEY_TABLE,0) as CATALOG_NAME,
	     NULL as DESCRIPTION
	     from DB.DBA.SYS_KEYS where name_part(KEY_TABLE,0) like ?', null, null,
	  vector (cat), 0, mdta, dta);
    }
  else
    {
	declare tables, temp, _last any;
	declare idx int;

	tables := sql_tables (dsn, NULL, NULL, NULL, 'TABLE');
	temp := make_array (length (tables), 'any');
	for (idx := 0; idx < length (tables); idx := idx + 1)
	   if (tables[idx][0] is NULL)
	     aset (temp, idx, tables[idx][1]);
	   else
	     aset (temp, idx, tables[idx][0]);
	temp := __vector_sort (temp);
	if (length (temp) > 0)
	   _last := temp [0];
	dta := vector (_last, NULL, NULL);
	for (idx := 0; idx < length (temp); idx := idx + 1)
	  {
	     if (_last <> temp[idx])
	       {
		  _last := temp [idx];
		  dta := vector_concat (dta, vector (_last, NULL, NULL));
	       }
	  }
        exec ('select distinct name_part(KEY_TABLE,0) as CATALOG_NAME,
	     NULL as DESCRIPTION
	     from DB.DBA.SYS_KEYS where name_part(KEY_TABLE,0) like ?', null, null,
	  vector (cat), 0, mdta);
	dta := vector (dta);
    }
--    signal ('00005', 'Unable to process the request, because the DataSourceInfo property was missing or not correctly specified');

  xmla_make_struct (mdta, dta);
  self.metadata := mdta;
  return dta;
}
;

create procedure
xmla_make_xsd (inout mdta any)
{
  declare i, l int;
  declare ses any;
  declare xsd varchar;
  ses := string_output ();
  http ('<schema  xmlns="http://www.w3.org/2001/XMLSchema"  targetNamespace="urn:schemas-microsoft-com:xml-analysis:rowset" elementFormDefault="qualified" xmlns:sql="urn:schemas-microsoft-com:xml-sql" xmlns:tns="urn:schemas-microsoft-com:xml-analysis:rowset">\n', ses);
  http ('<element name="root" type="tns:root" />\n', ses);
  http ('<complexType name="root">\n', ses);
  http (  '<sequence minOccurs="0" maxOccurs="unbounded">\n', ses);
  http (    '<element name="row" type="tns:row" />\n', ses);
  http (  '</sequence>\n', ses);
  http ('</complexType>\n', ses);
  http ('<complexType name="row">\n', ses);
  http (  '<choice maxOccurs="unbounded" minOccurs="0" >\n', ses);
  i := 0; l := length (mdta);
  while (i < l)
    {
      declare _name varchar;
      declare _type, _type_name, nill int;
      _name := mdta[i][0];
      _type := mdta[i][1];
      if (length (mdta[i]) > 4)
        nill := mdta[i][4];
      else
        nill := 0;
      if (_type <> 193)
	{
	  if (isstring (_type))
	    _type_name := _type;
	  else
            _type_name := dv_to_soap_type (_type);
          http (sprintf ('<element name="%V" type="%s" sql:field="%s" nillable="%d" />\n', _name, _type_name, _name, nill), ses);
	}
      else
	{
          http (sprintf ('<element name="%V" sql:field="%s">\n', _name, _name), ses);
          http ('<complexType>\n', ses);
	  http (    '<sequence minOccurs="0" maxOccurs="unbounded">\n', ses);
	  http (      '<any processContents="lax" maxOccurs="unbounded"/>\n', ses);
	  http (    '</sequence>\n', ses);
          http ('</complexType>\n', ses);
          http ('</element>\n', ses);
	}
      i := i + 1;
    }
  http (  '</choice>\n', ses);
  http ('</complexType>\n', ses);
  http ('</schema>', ses);
  xsd := string_output_string (ses);
  mdta := xml_tree_doc (xsd);
  return;
}
;

create procedure xmla_make_struct (inout mdta any, inout dta any)
{
  declare res any;
  declare i, l int;
  mdta := mdta[0];
  i := 0; l := length (dta);
  res := make_array (l, 'any');
  while (i < l)
    {
      aset (res, i, xmla_make_element (mdta, dta[i]));
      i := i + 1;
    }
  dta := res;
  xmla_make_xsd (mdta);
}
;

create procedure
xmla_make_element (in mdta any, in dta any)
{
  declare res any;
  declare i, l, i1, i2 int;
  i := 0; l := length (mdta); i1 := 2; i2 := 3;
  res := make_array (2 + (l*2), 'any');
  aset (res, 0, composite ());
  aset (res, 1, '<structure>');
  while (i < l)
    {
      aset (res, i1, mdta[i][0]);
      if (mdta[i][1] = 131 and not isblob(dta[i]))
	 aset (res, i2, cast (dta[i] as varbinary));
      else if (mdta[i][1] = 219 and 219 <> __tag (dta[i]))
	 aset (res, i2, cast (dta[i] as decimal));
      else
         aset (res, i2, dta[i]);
      i := i + 1;
      i1 := i1 + 2;
      i2 := i1 + 1;
    }
  return res;
}
;


create method xmla_dbschema_columns () for xmla_discover
{
  declare dta, mdta any;
  declare dsn, cat, tb, col, sch any;

  dsn := self.xmla_get_property ('DataSourceInfo', xmla_service_name ());
  dsn := xmla_get_dsn_name (dsn);
  cat := self.xmla_get_restriction ('TABLE_CATALOG', '%');
  sch := self.xmla_get_restriction ('TABLE_SCHEMA', '%');
  tb := self.xmla_get_restriction ('TABLE_NAME', '%');
  col := self.xmla_get_restriction ('COLUMN_NAME', '%');
  if (cat is null)
    cat := '%';
  if (sch is null)
    sch := '%';
  if (tb is null)
    tb := '%';
  if (col is null)
    col := '%';

  if (not xmla_not_local_dsn (dsn))
    {
      declare uname, passwd varchar;
      uname := self.xmla_get_property ('UserName', null);
      passwd := self.xmla_get_property ('Password', null);
      if (uname is null or passwd is null)
	signal ('00002', 'Unable to process the request, because the UserName property is not set or incorrect');
      set_user_id (uname, 1, passwd);
      exec('select
	 name_part(KEY_TABLE, 0) as TABLE_CATALOG,
	 name_part(KEY_TABLE, 1) as TABLE_SCHEMA,
	 name_part(KEY_TABLE, 2) as TABLE_NAME,
	 "COLUMN" as COLUMN_NAME,
	 NULL as COLUMN_GUID,
	 NULL as COLUMN_PROPID INTEGER,
	 (select count(*) from DB.DBA.SYS_COLS where "TABLE" = KEY_TABLE and COL_ID <= c.COL_ID and "COLUMN" <> ''_IDN'') as ORDINAL_POSITION INTEGER,
	 case when deserialize(COL_DEFAULT) is null then 0 else -1 end as COLUMN_HASDEFAULT SMALLINT,
         cast (deserialize(COL_DEFAULT) as NVARCHAR) as COLUMN_DEFAULT NVARCHAR(254),
         cast (DB.DBA.oledb_dbflags(COL_DTP, COL_NULLABLE) as integer) as COLUMN_FLAGS INTEGER,
	 case COL_NULLABLE when 1 then -1 else 0 end as IS_NULLABLE SMALLINT,
	 cast (DB.DBA.oledb_dbtype(COL_DTP) as integer) as DATA_TYPE SMALLINT,
	 NULL as TYPE_GUID,
	 cast (DB.DBA.oledb_char_max_len(COL_DTP, COL_PREC) as integer) as CHARACTER_MAXIMUM_LENGTH INTEGER,
	 cast (DB.DBA.oledb_char_oct_len(COL_DTP, COL_PREC) as integer) as CHARACTER_OCTET_LENGTH INTEGER,
	 cast (DB.DBA.oledb_num_prec(COL_DTP, COL_PREC) as smallint) as NUMERIC_PRECISION SMALLINT,
	 cast (DB.DBA.oledb_num_scale(COL_DTP, COL_SCALE) as smallint) as NUMERIC_SCALE SMALLINT,
	 cast (DB.DBA.oledb_datetime_prec(COL_DTP, COL_PREC) as integer) as DATETIME_PRECISION INTEGER,
	 NULL as CHARACTER_SET_CATALOG NVARCHAR(1),
	 NULL as CHARACTER_SET_SCHEMA NVARCHAR(1),
	 NULL as CHARACTER_SET_NAME NVARCHAR(1),
	 NULL as COLLATION_CATALOG NVARCHAR(1),
	 NULL as COLLATION_SCHEMA NVARCHAR(1),
	 NULL as COLLATION_NAME NVARCHAR(1),
	 NULL as DOMAIN_CATALOG NVARCHAR(1),
	 NULL as DOMAIN_SCHEMA NVARCHAR(1),
	 NULL as DOMAIN_NAME NVARCHAR(1),
	 NULL as DESCRIPTION NVARCHAR(1)
    	from DB.DBA.SYS_KEYS, DB.DBA.SYS_KEY_PARTS, DB.DBA.SYS_COLS c
    	where
	 __any_grants(KEY_TABLE) and
	 name_part(KEY_TABLE, 0) = ? and
	 name_part(KEY_TABLE, 1) like ? and
	 name_part(KEY_TABLE, 2) like ? and
	 "COLUMN" like ? and
	 "COLUMN" <> ''_IDN'' and
	 KEY_IS_MAIN = 1 and
	 KEY_MIGRATE_TO is null and
	 KP_KEY_ID = KEY_ID and
	 COL_ID = KP_COL order by KEY_TABLE, 7'
       , null, null,
      vector (cat, sch, tb, col), 0, mdta, dta);
    }
  else
    {
       dsn := xmla_get_dsn_name (dsn);

       exec ('select TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, COLUMN_GUID, COLUMN_PROPID,' ||
		    'ORDINAL_POSITION, COLUMN_HASDEFAULT, COLUMN_DEFAULT, IS_NULLABLE, DATA_TYPE,' ||
		    'TYPE_GUID, CHARACTER_MAXIMUM_LENGTH, CHARACTER_OCTET_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE,' ||
		    'DATETIME_PRECISION, CHARACTER_SET_CATALOG, CHARACTER_SET_SCHEMA, CHARACTER_SET_NAME,' ||
		    'COLLATION_CATALOG, COLLATION_SCHEMA, COLLATION_NAME, DOMAIN_CATALOG, DOMAIN_SCHEMA,' ||
		    'DOMAIN_NAME, DESCRIPTION ' ||
	       'from DB.DBA.XMLA_VDD_DBSCHEMA_COLUMNS where cat = ? and tb = ? and col = ? and dsn = ?'
		  , null, null, vector (cat, tb, col, dsn), 0, mdta, dta);
    }

  xmla_make_struct (mdta, dta);
  self.metadata := mdta;
  return dta;
}
;


create method xmla_dbschema_foreign_keys () for xmla_discover
{
  declare dta, mdta, stmt, state, msg any;
  declare dsn any;
  declare p_cat, p_tbl, p_sch any;
  declare f_cat, f_tbl, f_sch any;
  declare _ptbl, _ftbl varchar;

  dsn := self.xmla_get_property ('DataSourceInfo', xmla_service_name ());
  dsn := xmla_get_dsn_name (dsn);

  p_cat := self.xmla_get_restriction ('PK_TABLE_CATALOG', '%');
  p_sch := self.xmla_get_restriction ('PK_TABLE_SCHEMA', '%');
  p_tbl := self.xmla_get_restriction ('PK_TABLE_NAME', '%');
  f_cat := self.xmla_get_restriction ('FK_TABLE_CATALOG', '%');
  f_sch := self.xmla_get_restriction ('FK_TABLE_SCHEMA', '%');
  f_tbl := self.xmla_get_restriction ('FK_TABLE_NAME', '%');

  if (p_cat is null) 
  {
    if (f_cat is not null)
      p_cat := f_cat;
    else
      p_cat := '%';
  }

  if (f_cat is null)
  { 
    if (p_cat is not null)
      f_cat := p_cat;
    else
      f_cat := '%';
  }

  if (p_sch is null)
    p_sch := '%';
  if (p_tbl is null)
    p_tbl := '%';
  if (f_sch is null)
    f_sch := '%';
  if (f_tbl is null)
    f_tbl := '%';

  p_cat := trim (p_cat, '"');
  p_sch := trim (p_sch, '"');
  p_tbl := trim (p_tbl, '"');
  f_cat := trim (f_cat, '"');
  f_sch := trim (f_sch, '"');
  f_tbl := trim (f_tbl, '"');
  _ptbl := p_cat || '.' || p_sch || '.' || p_tbl;
  _ftbl := f_cat || '.' || f_sch || '.' || f_tbl;

  if (not xmla_not_local_dsn (dsn))
    {
      declare uname, passwd varchar;
      uname := self.xmla_get_property ('UserName', null);
      passwd := self.xmla_get_property ('Password', null);
      if (uname is null or passwd is null)
	signal ('00002', 'Unable to process the request, because the UserName property is not set or incorrect');
      set_user_id (uname, 1, passwd);
      exec('select
    	 name_part (PK_TABLE, 0) as PK_TABLE_CATALOG varchar (128),
    	 name_part (PK_TABLE, 1) as PK_TABLE_SCHEMA varchar (128),
    	 name_part (PK_TABLE, 2) as PK_TABLE_NAME varchar (128),
    	 PKCOLUMN_NAME as PK_COLUMN_NAME,
    	 NULL as PK_COLUMN_GUID,
    	 NULL as PK_COLUMN_PROPID INTEGER,
    	 name_part (FK_TABLE, 0) as FK_TABLE_CATALOG varchar (128),
	 name_part (FK_TABLE, 1) as FK_TABLE_SCHEMA varchar (128),
    	 name_part (FK_TABLE, 2) as FK_TABLE_NAME varchar (128),
    	 FKCOLUMN_NAME as FK_COLUMN_NAME,
    	 NULL as FK_COLUMN_GUID,
    	 NULL as FK_COLUMN_PROPID INTEGER,
    	 (KEY_SEQ + 1) as ORDINAL INTEGER,
    	 (case UPDATE_RULE when 0 then ''NO ACTION'' when 1 then ''CASCADE'' when 2 then ''SET NULL'' when 3 then ''SET DEFAULT'' else NULL end) as UPDATE_RULE varchar(20),
    	 (case DELETE_RULE when 0 then ''NO ACTION'' when 1 then ''CASCADE'' when 2 then ''SET NULL'' when 3 then ''SET DEFAULT'' else NULL end) as DELETE_RULE varchar(20),
	 PK_NAME, 
	 FK_NAME,
    	 3 as DEFERRABILITY SMALLINT
    	from DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS
    	where name_part (PK_TABLE, 0) like ?
    	 and name_part (PK_TABLE, 1) like ?
    	 and name_part (PK_TABLE, 2) like ?
    	 and name_part (FK_TABLE, 0) like ?
    	 and name_part (FK_TABLE, 1) like ?
    	 and name_part (FK_TABLE, 2) like ?
    	order by 1, 2, 3, 7, 8, 9, 13 '
    	, null, null,
      	vector(p_cat, p_sch, p_tbl, f_cat, f_sch, f_tbl), 0, mdta, dta);
    }
  else
    {
       dsn := xmla_get_dsn_name (dsn);
       stmt := 'SELECT * FROM DB.DBA.SYS_FOREIGN_KEYS_VIEW WHERE PK_TABLE = ''' 
       		|| _ptbl || ''' AND FK_TABLE = ''' || _ftbl
	       	|| ''' AND DSN = ''' || dsn || '''';
       exec (stmt, state, msg, vector (), 0, mdta, dta);
    }

  xmla_make_struct (mdta, dta);
  self.metadata := mdta;
  return dta;
}
;


create method xmla_dbschema_primary_keys () for xmla_discover
{
  declare state, msg, dta, mdta, stmt any;
  declare dsn, cat, tb, col, sch any;
  declare _tbl varchar;

  dsn := self.xmla_get_property ('DataSourceInfo', xmla_service_name ());
  dsn := xmla_get_dsn_name (dsn);
  cat := self.xmla_get_restriction ('TABLE_CATALOG', '%');
  sch := self.xmla_get_restriction ('TABLE_SCHEMA', '%');
  tb := self.xmla_get_restriction ('TABLE_NAME', '%');

  if (cat is null)
    cat := '%';
  if (sch is null)
    sch := '%';
  if (tb is null)
    tb := '%';
  
  cat := trim (cat, '"');
  sch := trim (sch, '"');
  tb := trim (tb, '"');
  _tbl := cat || '.' || sch || '.' || tb;

  if (not xmla_not_local_dsn (dsn))
    {
      declare uname, passwd varchar;
      uname := self.xmla_get_property ('UserName', null);
      passwd := self.xmla_get_property ('Password', null);
      if (uname is null or passwd is null)
	signal ('00002', 'Unable to process the request, because the UserName property is not set or incorrect');
      set_user_id (uname, 1, passwd);
      exec('select
    	 name_part(KEY_TABLE, 0) AS TABLE_CATALOG NVARCHAR(128),
    	 name_part(KEY_TABLE, 1) AS TABLE_SCHEMA NVARCHAR(128),
    	 name_part(KEY_TABLE, 2) AS TABLE_NAME NVARCHAR(128),
    	 "COLUMN" as COLUMN_NAME NVARCHAR(128),
    	 NULL as COLUMN_GUID,
    	 NULL as COLUMN_POPID INTEGER,
    	 (KP_NTH + 1) as ORDINAL,
    	 name_part(KEY_NAME, 2) as PK_NAME
    	from DB.DBA.SYS_KEYS, DB.DBA.SYS_KEY_PARTS, DB.DBA.SYS_COLS
    	where
    	 __any_grants(KEY_TABLE) and
    	 name_part(KEY_TABLE, 0) LIKE ? and
    	 name_part(KEY_TABLE, 1) LIKE ? and
    	 name_part(KEY_TABLE, 2) LIKE ? and
    	 KEY_IS_MAIN = 1 and
    	 KEY_MIGRATE_TO is null and
    	 KP_KEY_ID = KEY_ID and
    	 KP_NTH < KEY_DECL_PARTS and
    	 COL_ID = KP_COL and
    	 "COLUMN" <> ''_IDN''
    	order by KEY_TABLE'
       	, null, null,
      vector(cat, sch, tb), 0, mdta, dta);
    }
  else
    {
        dsn := xmla_get_dsn_name (dsn);
	stmt := 'SELECT * FROM DB.DBA.SYS_PRIMARY_KEYS_VIEW WHERE PK_TABLE = ''' || _tbl || ''' AND DSN = ''' || dsn || '''';
        exec (stmt, state, msg, vector (), 0, mdta, dta);
    }

  xmla_make_struct (mdta, dta);
  self.metadata := mdta;
  return dta;
}
;


create method xmla_dbschema_provider_types () for xmla_discover
{
  declare dta, mdta any;
  declare dsn any;
  declare t, m int;

  dsn := self.xmla_get_property ('DataSourceInfo', xmla_service_name ());
  dsn := xmla_get_dsn_name (dsn);
  --cat := self.xmla_get_property ('Catalog', 'DB');
  t := self.xmla_get_restriction ('DATA_TYPE', NULL);
  m := self.xmla_get_restriction ('BEST_MATCH', NULL);
  if (not xmla_not_local_dsn (dsn))
    {
      exec ('select
	 gt.TYPE_NAME,
	 gt.DATA_TYPE,
	 gt.COLUMN_SIZE,
	 gt.LITERAL_PREFIX,
	 gt.LITERAL_SUFFIX,
	 gt.CREATE_PARAMS,
	 gt.IS_NULLABLE,
	 gt.CASE_SENSITIVE,
	 gt.SEARCHABLE,
	 gt.UNSIGNED_ATTRIBUTE,
	 gt.FIXED_PREC_SCALE,
	 gt.AUTO_UNIQUE_VALUE,
	 gt.LOCAL_TYPE_NAME,
	 gt.MINIMUM_SCALE,
	 gt.MAXIMUM_SCALE,
	 gt.GUID,
	 gt.TYPELIB,
	 gt.VERSION,
	 gt.IS_LONG,
	 gt.BEST_MATCH,
	 gt.IS_FIXEDLENGTH
	from DB.DBA.oledb_get_types(t, m)
	(
	 TYPE_NAME NVARCHAR(32),
	 DATA_TYPE SMALLINT,
	 COLUMN_SIZE INTEGER,
	 LITERAL_PREFIX NVARCHAR(5),
	 LITERAL_SUFFIX NVARCHAR(5),
	 CREATE_PARAMS NVARCHAR(64),
	 IS_NULLABLE SMALLINT,
	 CASE_SENSITIVE SMALLINT,
	 SEARCHABLE INTEGER,
	 UNSIGNED_ATTRIBUTE SMALLINT,
	 FIXED_PREC_SCALE SMALLINT,
	 AUTO_UNIQUE_VALUE SMALLINT,
	 LOCAL_TYPE_NAME NVARCHAR(32),
	 MINIMUM_SCALE SMALLINT,
	 MAXIMUM_SCALE SMALLINT,
	 GUID NVARCHAR,
	 TYPELIB NVARCHAR,
	 VERSION NVARCHAR(32),
	 IS_LONG SMALLINT,
	 BEST_MATCH SMALLINT,
	 IS_FIXEDLENGTH SMALLINT
	) gt
	where
	 t = ? and m = ?' , null, null,
	  vector (t, m), 0, mdta, dta);
    }
  else
    {
       dsn := xmla_get_dsn_name (dsn);

       exec ('select TYPE_NAME, DATA_TYPE, COLUMN_SIZE, LITERAL_PREFIX, LITERAL_SUFFIX,
		 CREATE_PARAMS, IS_NULLABLE, CASE_SENSITIVE, SEARCHABLE, UNSIGNED_ATTRIBUTE,
		 FIXED_PREC_SCALE, AUTO_UNIQUE_VALUE, LOCAL_TYPE_NAME, MINIMUM_SCALE, MAXIMUM_SCALE,
		 GUID, TYPELIB, VERSION, IS_LONG, BEST_MATCH, IS_FIXEDLENGTH
		 from DB..XMLA_VDD_DBSCHEMA_PROVIDER_TYPES where tb = ? and cat = ? and dsn = ? ',
	   null, null, vector (t, m, dsn), 0, mdta, dta);
    }
  xmla_make_struct (mdta, dta);
  self.metadata := mdta;
  return dta;
}
;


create method xmla_dbschema_tables () for xmla_discover
{
  declare dta, mdta any;
  declare dsn, cat, sch, tb any;

  dsn := self.xmla_get_property ('DataSourceInfo', xmla_service_name ());
  dsn := xmla_get_dsn_name (dsn);
  cat := self.xmla_get_restriction ('TABLE_CATALOG', 'DB');
  sch := self.xmla_get_restriction ('TABLE_SCHEMA', '%');
  tb := self.xmla_get_restriction ('TABLE_NAME', '%');

  if (cat is null)
    cat := 'DB';
  if (sch is null)
    sch := '%';
  if (tb is null)
    tb := '%';
  
  if (not xmla_not_local_dsn (dsn))
    {
      declare uname, passwd varchar;
      uname := self.xmla_get_property ('UserName', null);
      passwd := self.xmla_get_property ('Password', null);
      if (uname is null or passwd is null)
	signal ('00002', 'Unable to process the request, because the UserName property is not set or incorrect');
      set_user_id (uname, 1, passwd);
      exec ('select name_part(KEY_TABLE, 0) as TABLE_CATALOG,
	            name_part(KEY_TABLE, 1) as TABLE_SCHEMA,
		    name_part(KEY_TABLE, 2) as TABLE_NAME,
		    table_type(KEY_TABLE) as TABLE_TYPE,
		    NULL as TABLE_GUID,
		    NULL as DESCRIPTION NVARCHAR,
		    NULL as TABLE_PROPID INTEGER,
		    NULL as DATE_CREATED DATE,
		    NULL as DATE_MODIFIED DATE
		    from DB.DBA.SYS_KEYS where
		    __any_grants(KEY_TABLE) and
		    name_part(KEY_TABLE, 0) like ? and 
		    name_part(KEY_TABLE, 1) like ? and
		    name_part(KEY_TABLE, 2) like ?
		    and KEY_IS_MAIN = 1 and 
		    KEY_MIGRATE_TO is null', null, null,
	  vector (cat, sch, tb), 0, mdta, dta);
    }
  else
    {
      exec ('select TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE, TABLE_GUID,
		    DESCRIPTION, TABLE_PROPID, DATE_CREATED, DATE_MODIFIED
		    from DB.DBA.XMLA_VDD_DBSCHEMA_TABLES where
		    tb = ? and cat = ? and dsn = ? ', null, null,
	  vector (tb, cat, dsn), 0, mdta, dta);
    }

  xmla_make_struct (mdta, dta);
  self.metadata := mdta;
  return dta;
}
;

create method xmla_dbschema_tables_info () for xmla_discover
{
  return self.xmla_dbschema_tables();
}
;

create procedure
xmla_get_schs ()
{
  return vector (
      vector ('DBSCHEMA_CATALOGS', soap_box_structure ('CATALOG_NAME', ''),''),
      vector ('DBSCHEMA_TABLES',
	 soap_box_structure ('TABLE_CATALOG', '', 'TABLE_SCHEMA', '', 'TABLE_NAME', '', 'TABLE_TYPE', '')
	 ,''),
      vector ('DBSCHEMA_TABLES_INFO',
	 soap_box_structure ('TABLE_CATALOG', '', 'TABLE_SCHEMA', '', 'TABLE_NAME', '', 'TABLE_TYPE', '')
	,''),
      vector ('DBSCHEMA_COLUMNS',
	 soap_box_structure ('TABLE_CATALOG', '', 'TABLE_SCHEMA', '', 'TABLE_NAME', '', 'TABLE_TYPE', '', 'COLUMN_NAME', '')
	,''),
      vector ('DBSCHEMA_PRIMARY_KEYS',
	 soap_box_structure ('TABLE_CATALOG', '', 'TABLE_SCHEMA', '', 'TABLE_NAME', '')
	,''),
      vector ('DBSCHEMA_FOREIGN_KEYS',
	 soap_box_structure ('PK_TABLE_CATALOG', '', 'PK_TABLE_SCHEMA', '', 'PK_TABLE_NAME', '',
	   		     'FK_TABLE_CATALOG', '', 'FK_TABLE_SCHEMA', '', 'FK_TABLE_NAME', '')
	,''),
      vector ('DBSCHEMA_PROVIDER_TYPES',
	 soap_box_structure ('DATA_TYPE', '', 'BEST_MATCH', '')
	,''),
      vector ('DISCOVER_DATASOURCES',
	 soap_box_structure ('DataSourceName', '', 'URL', '', 'ProviderName', '', 'ProviderType', '', 'AuthenticationMode', '')
	,''),
      vector ('DISCOVER_PROPERTIES',
	 soap_box_structure ('PropertyName', '')
	,''),
      vector ('DISCOVER_SCHEMA_ROWSETS',
	 soap_box_structure ('SchemaName', '')
	,''),
      vector ('DISCOVER_ENUMERATORS',
	 soap_box_structure ('EnumName', '')
	,''),
      vector ('DISCOVER_KEYWORDS',
	 soap_box_structure ('Keyword', '')
	  ,''),
      vector ('DISCOVER_LITERALS',
	 soap_box_structure ('LiteralName', '')
	  ,'')
      );
}
;

-- XMLA core properties
create procedure
xmla_get_props (in _dsn varchar := NULL)
{
  declare ses_props, _vdd_dsn_info any;
  declare dbms_name, dbms_ver varchar;

  ses_props := connection_get ('XMLA_Properties');
  if (isarray (ses_props))
    return ses_props;

  dbms_name := sys_stat ('st_dbms_name');
  dbms_ver := sys_stat ('st_dbms_ver');
  _dsn := xmla_get_dsn_name (_dsn);

  if (not xmla_is_local_service (_dsn))
    {
        _vdd_dsn_info := vdd_dsn_info(_dsn);
	dbms_name := get_keyword (17, _vdd_dsn_info, '');
	dbms_ver := get_keyword (18, _vdd_dsn_info, '');
    }

  return vector (
        vector ('AxisFormat'	, '', 'string', 'W', 0, 'TupleFormat'),
        vector ('BeginRange'	, '', 'int', 'W', 0, '-1'),
        vector ('Catalog'   	, '', 'string', 'R/W', 0, 'DB'),
        vector ('Content'   	, '', 'string', 'W', 0, ''),
        vector ('DataSourceInfo', '', 'string', 'R/W', 0, ''),
        vector ('EndRange'	, '', 'int', 'W', 0, '-1'),
        vector ('Format'	, '', 'string', 'W', 0, 'Tabular'),
        vector ('LocaleIdentifier','','int', 'R/W', 0, NULL),
        vector ('MDXSupport'	, '', 'string', 'R', 0, 'None'),
        vector ('Password'	, '', 'string', 'W', 0, ''),
        vector ('ProviderName'	, '', 'string', 'R', 0, dbms_name),
        vector ('ProviderVersion','', 'string', 'R', 0, dbms_ver),
        vector ('StateSupport'	, '', 'string', 'R', 0, 'Sessions'),
        vector ('Timeout'	, '', 'int', 'R/W', 0, NULL),
        vector ('BLOBLimit'	, '', 'int', 'R/W', 0, NULL),
        vector ('UserName'	, '', 'string', 'R/W', 0, '')
      );
}
;

create procedure
xmla_get_dsn_name (in _dsn varchar)
{
   return replace (_dsn, 'DSN=', '');
   return _dsn;
}
;

create procedure
xmla_is_local_service (in _dsn varchar)
{
   if (_dsn <> xmla_service_name())
     return 0;
   return 1;
}
;

create procedure
xmla_set_props (in properties any)
{
  declare prop_list, def_prop any;
  declare i, l int;
  def_prop := xmla_get_props ();
  l := length (def_prop); i := 0;
  while (i < l)
    {
      declare elm, val any;
      elm := def_prop[i];
      if (elm[3] in ('R/W', 'W'))
	{
          val := xmla_get_property (properties, elm[0], elm[5]);
	  aset (elm, 5, val);
	}
      aset (def_prop, i, elm);
      i := i + 1;
    }
  return def_prop;
}
;

create procedure
xmla_get_enums ()
{
  return vector (
		vector('ProviderType','','string','TDP','',1),
		--vector('ProviderType','','string','MDP','',2),
		--vector('ProviderType','','string','DMP','',3),
		--vector('ProviderType','','string','DOCSOURCE','',4),
		vector('AuthenticationMode','','string','Unauthenticated','',5),
		vector('AuthenticationMode','','string','Authenticated','',6),
		--vector('AuthenticationMode','','string','Integrated','',7),
		vector('PropertyAccessType','','string','Read','',8),
		vector('PropertyAccessType','','string','Write','',9),
		vector('PropertyAccessType','','string','ReadWrite','',10),
		vector('StateSupport','','string','None','',11),
		--vector('StateSupport','','string','Sessions','',12),
		--vector('StateActionVerb','','string','BeginSession','',13),
		--vector('StateActionVerb','','string','EndSession','',14),
		--vector('StateActionVerb','','string','Session','',15),
		vector('ResultsetFormat','','string','Tabular','',16),
		--vector('ResultsetFormat','','string','Multidimensional','',17),
		vector('ResultsetAxisFormat','','string','TupleFormat','',18),
		--vector('ResultsetAxisFormat','','string','ClusterFormat','',19),
		--vector('ResultsetAxisFormat','','string','CustomFormat','',20),
		vector('ResultsetContents','','string','None','',21),
		vector('ResultsetContents','','string','Schema','',22),
		vector('ResultsetContents','','string','Data','',23),
		vector('ResultsetContents','','string','SchemaData','',24),
		vector('MDXSupportLevel','','string','None','',25)
      );
}
;

create procedure
xmla_get_literals ()
{
  return vector (
	vector ('DBLITERAL_CATALOG_NAME', '', '.', '0123456789 ', 100),
	vector ('DBLITERAL_CATALOG_SEPARATOR', '.', '', '', 0),
	vector ('DBLITERAL_COLUMN_ALIAS', '', '\'"[]', '0123456789 ', 100),
	vector ('DBLITERAL_COLUMN_NAME', '', '.', '0123456789 ', 100),
	vector ('DBLITERAL_CORRELATION_NAME', '', '\'"[]', '0123456789 ', 100),
	vector ('DBLITERAL_PROCEDURE_NAME', '', '.', '0123456789 ', 100),
	vector ('DBLITERAL_TABLE_NAME', '', '.', '0123456789 ', 100),
	vector ('DBLITERAL_TEXT_COMMAND', '', '', '', 0),
	vector ('DBLITERAL_USER_NAME', '', '', '', 0),
	vector ('DBLITERAL_QUOTE', '"', '', '', 0),
--	vector ('DBLITERAL_CUBE_NAME', '', '.', '0123456789 ', 24),
--	vector ('DBLITERAL_DIMENSION_NAME', '', '.', '0123456789 ', 14),
--	vector ('DBLITERAL_HIERARCHY_NAME', '', '.', '0123456789 ', 10),
--	vector ('DBLITERAL_LEVEL_NAME', '', '.', '0123456789 ', 255),
--	vector ('DBLITERAL_MEMBER_NAME', '', '.', '0123456789 ', 255),
	vector ('DBLITERAL_PROPERTY_NAME', '', '.', '0123456789 ', 100),
	vector ('DBLITERAL_QUOTE_SUFFIX', '"', '', '', 0)
      );
}
;


create procedure
xmla_service_name ()
{
  return 'Local_Instance';
}
;


create procedure
xmla_get_kwds ()
{
  return vector (
'__SOAP_DOC', '__SOAP_DOCW', '__SOAP_HEADER', '__SOAP_HTTP', '__SOAP_NAME', '__SOAP_TYPE',
'__SOAP_XML_TYPE', '__SOAP_FAULT', '__SOAP_DIME_ENC', '__SOAP_MIME_ENC', '__SOAP_OPTIONS',
'ADA', 'ADD', 'ADMIN', 'AFTER', 'AGGREGATE', 'ALL', 'ALTER', 'AND', 'ANY', 'ARE', 'AS',
'ASC', 'ATTACH', 'ATTRIBUTE', 'AUTHORIZATION', 'BACKUP', 'BEFORE', 'BEGIN', 'BEST',
'BETWEEN', 'BINARY', 'BY', 'C', 'CALL', 'CALLED', 'CASCADE', 'CASE', 'CAST', 'CHAR',
'CHARACTER', 'CHECK', 'CHECKED', 'CHECKPOINT', 'CLOSE', 'CLUSTERED', 'CLR', 'COALESCE',
'COBOL', 'COLLATE', 'COLUMN', 'COMMIT', 'CONSTRAINT', 'CONSTRUCTOR', 'CONTAINS', 'CONTINUE',
'CONVERT', 'CORRESPONDING', 'CREATE', 'CROSS', 'CURRENT', 'CURRENT_DATE', 'CURRENT_TIME',
'CURRENT_TIMESTAMP', 'CURSOR', 'DATA', 'DATE', 'DATETIME', 'DECIMAL', 'DECLARE', 'DEFAULT',
'DELETE', 'DESC', 'DETERMINISTIC', 'DISCONNECT', 'DISTINCT', 'DO', 'DOUBLE', 'DROP', 'DTD',
'DYNAMIC', 'ELSE', 'ELSEIF', 'ENCODING', 'END', 'ESCAPE', 'EXCEPT', 'EXCLUSIVE', 'EXECUTE',
'EXISTS', 'EXTERNAL', 'EXTRACT', 'EXIT', 'FETCH', 'FINAL', 'FLOAT', 'FOR', 'FOREIGN',
'FORTRAN', 'FOUND', 'FROM', 'FULL', 'FUNCTION', 'GENERAL', 'GENERATED', 'GO', 'GOTO',
'GRANT', 'GROUP', 'HANDLER', 'HAVING', 'HASH', 'IDENTITY', 'IDENTIFIED', 'IF', 'IN',
'INCREMENTAL', 'INDEX', 'INDICATOR', 'INNER', 'INOUT', 'INPUT', 'INSERT', 'INSTANCE',
'INSTEAD', 'INT', 'INTEGER', 'INTERSECT', 'INTERNAL', 'INTERVAL', 'INTO', 'IS',
'JAVA', 'JOIN', 'KEY', 'KEYSET', 'LANGUAGE', 'LEFT', 'LIKE', 'LOCATOR', 'LOG', 'LONG',
'LOOP', 'METHOD', 'MODIFY', 'MODIFIES', 'MODULE', 'MUMPS', 'NAME', 'NATURAL', 'NCHAR',
'NEW', 'NONINCREMENTAL', 'NOT', 'NO', 'NULL', 'NULLIF', 'NUMERIC', 'NVARCHAR', 'OBJECT_ID',
'OF', 'OFF', 'OLD', 'ON', 'OPEN', 'OPTION', 'OR', 'ORDER', 'OUT', 'OUTER', 'OVERRIDING',
'PASCAL', 'PASSWORD', 'PERCENT', 'PERSISTENT', 'PLI', 'PRECISION', 'PREFETCH', 'PRIMARY',
'PRIVILEGES', 'PROCEDURE', 'PUBLIC', 'PURGE', 'READS', 'REAL', 'REF', 'REFERENCES', 'REFERENCING',
'REMOTE', 'RENAME', 'REPLACING', 'REPLICATION', 'RESIGNAL', 'RESTRICT', 'RESULT', 'RETURN',
'RETURNS', 'REVOKE', 'RIGHT', 'ROLLBACK', 'ROLE', 'SCHEMA', 'SELECT', 'SELF', 'SET',
'SHUTDOWN', 'SMALLINT', 'SNAPSHOT', 'SOFT', 'SOME', 'SOURCE', 'SPECIFIC', 'SQL',
'SQLCODE', 'SQLEXCEPTION', 'SQLSTATE', 'SQLWARNING', 'STATIC', 'STYLE', 'SYNC', 'SYSTEM',
'TABLE', 'TEMPORARY', 'TEXT', 'THEN', 'TIES', 'TIME', 'TIMESTAMP', 'TO', 'TOP', 'TYPE',
'TRIGGER', 'UNDER',
'UNION', 'UNIQUE', 'UPDATE', 'USE', 'USER', 'USING', 'VALUE', 'VALUES',
'VARBINARY', 'VARCHAR', 'VARIABLE', 'VIEW', 'WHEN', 'WHENEVER', 'WHERE', 'WHILE', 'WITH', 'WORK', 'XML', 'XPATH'
      );
}
;


create procedure DB.DBA.xmla_vdd_dbschema_tables_rpoc (in tb varchar, in cat varchar, in dsn varchar)
{
   declare _all, temp any;
   declare TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE, TABLE_GUID varchar;
   declare DESCRIPTION nvarchar;
   declare TABLE_PROPID, idx int;
   declare DATE_CREATED, DATE_MODIFIED date;

   _all := sql_tables (dsn, NULL, NULL, NULL, 'TABLE');
   temp := sql_tables (dsn, NULL, NULL, NULL, 'VIEW');
   _all := vector_concat (_all, temp);
   temp := sql_tables (dsn, NULL, NULL, NULL, 'SYSTEM TABLE');
   _all := vector_concat (_all, temp);

   result_names (TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE, TABLE_GUID, DESCRIPTION,
		 TABLE_PROPID, DATE_CREATED, DATE_MODIFIED);

   for (idx := 0; idx < length (_all); idx := idx + 1)
     {
	declare _line any;
	_line := _all[idx];
	 result (_line[0], _line[1], _line[2], 'TABLE', NULL, NULL, NULL, NULL, NULL);
     }

}
;

create procedure DB.DBA.xmla_vdd_dbschema_columns_rpoc (in tb varchar, in cat varchar, in col varchar, in dsn varchar)
{
   declare _all any;
   declare TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, COLUMN_GUID, TYPE_GUID varchar;
   declare COLUMN_DEFAULT, CHARACTER_SET_CATALOG, CHARACTER_SET_SCHEMA, CHARACTER_SET_NAME, COLLATION_CATALOG nvarchar;
   declare idx, COLUMN_PROPID, ORDINAL_POSITION, COLUMN_HASDEFAULT, COLUMN_FLAGS, IS_NULLABLE, DATA_TYPE int;
   declare CHARACTER_MAXIMUM_LENGTH, CHARACTER_OCTET_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, DATETIME_PRECISION int;
   declare COLLATION_SCHEMA, COLLATION_NAME, DOMAIN_CATALOG, DOMAIN_SCHEMA, DOMAIN_NAME, DESCRIPTION nvarchar;


   _all := DB.DBA.sql_columns (dsn, tb, NULL, cat, NULL);

   if (_all = vector ())
     _all := DB.DBA.sql_columns (dsn, NULL, NULL, cat, NULL);  -- Oracle

   result_names (TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, COLUMN_GUID, COLUMN_PROPID,
		 ORDINAL_POSITION, COLUMN_HASDEFAULT, COLUMN_DEFAULT, COLUMN_FLAGS, IS_NULLABLE,
		 DATA_TYPE, TYPE_GUID, CHARACTER_MAXIMUM_LENGTH, CHARACTER_OCTET_LENGTH, NUMERIC_PRECISION,
		 NUMERIC_SCALE, DATETIME_PRECISION, CHARACTER_SET_CATALOG, CHARACTER_SET_SCHEMA,
		 CHARACTER_SET_NAME, COLLATION_CATALOG, COLLATION_SCHEMA, COLLATION_NAME, DOMAIN_CATALOG,
		 DOMAIN_SCHEMA, DOMAIN_NAME, DESCRIPTION);

   for (idx := 0; idx < length (_all); idx := idx + 1)
     {
	declare _line any;
	declare _is_null any;
	_line := _all[idx];
	_is_null := 0;
	if (_line[17] = 'YES') _is_null := 1;
	result (_line[0], _line[1], _line[2], _line[3], NULL, NULL, _line[16], NULL, cast (_line[12] as nvarchar), NULL, _is_null,
		_line[4], NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,  NULL, NULL,
		cast (_line[11] as nvarchar));
     }
}
;

--drop view XMLA_VDD_DBSCHEMA_COLUMNS;

create procedure view XMLA_VDD_DBSCHEMA_COLUMNS as DB.DBA.xmla_vdd_dbschema_columns_rpoc (cat, tb, col, dsn)
(TABLE_CATALOG varchar, TABLE_SCHEMA varchar, TABLE_NAME varchar, COLUMN_NAME varchar, COLUMN_GUID varchar,
 COLUMN_PROPID int, ORDINAL_POSITION int, COLUMN_HASDEFAULT int, COLUMN_DEFAULT nvarchar, COLUMN_FLAGS int,
 IS_NULLABLE int, DATA_TYPE int, TYPE_GUID varchar, CHARACTER_MAXIMUM_LENGTH int, CHARACTER_OCTET_LENGTH int,
 NUMERIC_PRECISION int, NUMERIC_SCALE int, DATETIME_PRECISION int, CHARACTER_SET_CATALOG NVARCHAR(1),
 CHARACTER_SET_SCHEMA NVARCHAR(1), CHARACTER_SET_NAME NVARCHAR(1), COLLATION_CATALOG NVARCHAR(1),
 COLLATION_SCHEMA NVARCHAR(1), COLLATION_NAME NVARCHAR(1), DOMAIN_CATALOG NVARCHAR(1), DOMAIN_SCHEMA NVARCHAR(1),
 DOMAIN_NAME NVARCHAR(1), DESCRIPTION NVARCHAR(1))
;

--drop view XMLA_VDD_DBSCHEMA_TABLES;

create procedure view XMLA_VDD_DBSCHEMA_TABLES as DB.DBA.xmla_vdd_dbschema_tables_rpoc (tb, cat, dsn)
(TABLE_CATALOG varchar, TABLE_SCHEMA varchar, TABLE_NAME varchar, TABLE_TYPE varchar, TABLE_GUID varchar,
 DESCRIPTION nvarchar, TABLE_PROPID int, DATE_CREATED date, DATE_MODIFIED date)
;

--drop view XMLA_VDD_DBSCHEMA_PROVIDER_TYPES;

create procedure view XMLA_VDD_DBSCHEMA_PROVIDER_TYPES as DB.DBA.xmla_vdd_dbschema_provider_types_rpoc (tb, cat, dsn)
(TYPE_NAME varchar, DATA_TYPE int, COLUMN_SIZE int, LITERAL_PREFIX varchar, LITERAL_SUFFIX varchar,
 CREATE_PARAMS varchar, IS_NULLABLE int, CASE_SENSITIVE int, SEARCHABLE int, UNSIGNED_ATTRIBUTE int,
 FIXED_PREC_SCALE int, AUTO_UNIQUE_VALUE int, LOCAL_TYPE_NAME varchar, MINIMUM_SCALE int, MAXIMUM_SCALE int,
 GUID varchar, TYPELIB varchar, VERSION varchar, IS_LONG int, BEST_MATCH int, IS_FIXEDLENGTH int)
;

create procedure xmla_vdd_dbschema_provider_types_rpoc (in tb int, in cat int, in dsn varchar)
{
   declare _all any;
   declare idx int;

   declare TYPE_NAME, LITERAL_PREFIX, LITERAL_SUFFIX, CREATE_PARAMS, GUID, TYPELIB, VERSION, LOCAL_TYPE_NAME varchar;
   declare IS_NULLABLE, CASE_SENSITIVE, SEARCHABLE, UNSIGNED_ATTRIBUTE int;
   declare FIXED_PREC_SCALE, AUTO_UNIQUE_VALUE, MINIMUM_SCALE, MAXIMUM_SCALE int;
   declare IS_LONG, BEST_MATCH, IS_FIXEDLENGTH int;
   declare DATA_TYPE, COLUMN_SIZE int;


   _all := vdd_dsn_info(dsn)[1];
   result_names (TYPE_NAME, DATA_TYPE, COLUMN_SIZE, LITERAL_PREFIX, LITERAL_SUFFIX,
		 CREATE_PARAMS, IS_NULLABLE, CASE_SENSITIVE, SEARCHABLE, UNSIGNED_ATTRIBUTE,
		 FIXED_PREC_SCALE, AUTO_UNIQUE_VALUE, LOCAL_TYPE_NAME, MINIMUM_SCALE, MAXIMUM_SCALE,
		 GUID, TYPELIB, VERSION, IS_LONG, BEST_MATCH, IS_FIXEDLENGTH);

   for (idx := 0; idx < length (_all); idx := idx + 1)
     {
	declare _line any;

	_line := _all[idx];
	result (_line[0], _line[1], _line[2], _line[3], _line[4], _line[5], _line[6], _line[7],
		_line[8], _line[9], _line[10], _line[11], _line[12], _line[13], _line[14], NULL,
		NULL, NULL, NULL, NULL, NULL);
     }
}
;


create procedure mxla_fk_pk_check (in dsn varchar, inout stmt varchar, inout mdta any, inout dta any)
{
   declare state, msg any;
   declare _new any;

   _new := split_and_decode (stmt, 0, '\0\0''');

   if (strstr (stmt, 'DB.DBA.SYS_FOREIGN_KEYS'))
     {
	stmt := 'SELECT * FROM DB.DBA.SYS_FOREIGN_KEYS_VIEW WHERE PK_TABLE = ''' || _new[1] || ''' AND FK_TABLE = ''' || _new[3]
		|| ''' AND DSN = ''' || dsn || '''';
     }

   if (strstr (stmt, 'XMLA_VIRTUOSO_DUMMY_PK'))
     {
	stmt := 'SELECT * FROM DB.DBA.SYS_PRIMARY_KEYS_VIEW WHERE PK_TABLE = ''' || _new[1] || ''' AND DSN = ''' || dsn || '''';
     }

   exec (stmt, state, msg, vector (), 0, mdta, dta);
}
;


create procedure mxla_fk_pk_check_local (inout stmt varchar, inout mdta any, inout dta any)
{
   declare _new, l_name, _schema, _catalog, _name, idx, _line any;

   if (strstr (stmt, 'XMLA_VIRTUOSO_DUMMY_PK'))
     {
	_new := split_and_decode (stmt, 0, '\0\0''');
	_new := _new[1];

	_catalog := name_part (_new, 0);
	_schema := name_part (_new, 1);
	_name := name_part (_new, 2);
	_catalog := trim (_catalog, '"');
	_schema := trim (_schema, '"');
	_name := trim (_name, '"');
	stmt := sprintf ('SELECT COLUMN_NAME FROM %s.INFORMATION_SCHEMA.TABLE_CONSTRAINTS LEFT JOIN %s.INFORMATION_SCHEMA.KEY_COLUMN_USAGE ON %s.INFORMATION_SCHEMA.TABLE_CONSTRAINTS.CONSTRAINT_NAME = %s.INFORMATION_SCHEMA.KEY_COLUMN_USAGE.CONSTRAINT_NAME WHERE  CONSTRAINT_TYPE = ''PRIMARY KEY'' AND %s.INFORMATION_SCHEMA.TABLE_CONSTRAINTS.TABLE_NAME=''%s'' AND %s.INFORMATION_SCHEMA.TABLE_CONSTRAINTS.TABLE_SCHEMA=''%s'' AND %s.INFORMATION_SCHEMA.TABLE_CONSTRAINTS.CONSTRAINT_SCHEMA=''%s'' AND %s.INFORMATION_SCHEMA.KEY_COLUMN_USAGE.TABLE_SCHEMA=''%s'' AND %s.INFORMATION_SCHEMA.KEY_COLUMN_USAGE.CONSTRAINT_SCHEMA=''%s''', _catalog, _catalog, _catalog, _catalog, _catalog, _name, _catalog, _schema, _catalog, _schema, _catalog, _schema, _catalog, _schema);
     }

   if (strstr (stmt, 'FROM DB.DBA.SYS_FOREIGN_KEYS'))
     {
	declare _dsn, r_name, fk_tables any;
	declare state, msg any;

	_new := split_and_decode (stmt, 0, '\0\0''');
	_new := _new[1];
	_new := replace (_new, '"', '');

	if (exists (select 1 from DB.DBA.SYS_REMOTE_TABLE where RT_NAME = _new))
	   select RT_DSN, RT_REMOTE_NAME into _dsn, r_name  from DB.DBA.SYS_REMOTE_TABLE where RT_NAME = _new;
	else
	   {
	     stmt := replace (stmt, '"', '');
	     return;
	   }

	stmt := 'SELECT * FROM DB.DBA.SYS_FOREIGN_KEYS_VIEW WHERE PK_TABLE = ''' || r_name || ''' AND FK_TABLE = ''' || _new
		|| ''' AND DSN = ''' || _dsn || '''';

   	exec (stmt, state, msg, vector (), 0, mdta, dta);

	for (idx := 0; idx < length (dta); idx := idx + 1)
	  {
	     _line := dta[idx];

	     if (exists (select 1 from DB.DBA.SYS_REMOTE_TABLE where _line[0] like '%' || RT_REMOTE_NAME))
	      {
		select RT_NAME into l_name  from DB.DBA.SYS_REMOTE_TABLE where _line[0] like '%' || RT_REMOTE_NAME;

		aset (_line, 2, _new);
		aset (_line, 0, l_name);
	      }
	     aset (dta, idx, _line);
	  }

     }
}
;

--drop view DB.DBA.SYS_FOREIGN_KEYS_VIEW
--;

--drop view DB.DBA.SYS_PRIMARY_KEYS_VIEW
--;

create procedure view DB.DBA.SYS_FOREIGN_KEYS_VIEW as DB.DBA."XMLA_GET_FK" (PK_TABLE, FK_TABLE, DSN)
(PK_TABLE_SCHEMA VARCHAR,
PK_TABLE_NAME VARCHAR,
PK_COLUMN_NAME VARCHAR,
FK_TABLE_SCHEMA VARCHAR,
FK_TABLE_NAME VARCHAR,
FK_COLUMN_NAME VARCHAR,
KEY_SEQ SMALLINT,
UPDATE_RULE SMALLINT,
DELETE_RULE SMALLINT,
FK_NAME VARCHAR)
;

create procedure view DB.DBA.SYS_PRIMARY_KEYS_VIEW as DB.DBA."XMLA_GET_PK" (PK_TABLE, DSN)
(COLUMN_NAME VARCHAR)
;

create procedure DB.DBA."XMLA_GET_PK" (in _pk_table varchar, in dsn varchar)
{
   declare COLUMN_NAME VARCHAR;
   declare pk_tables, _pk_tables, idx any;

   declare exit handler for sqlstate 'VD052'
     {
	return;
     };

   result_names (COLUMN_NAME);

   pk_tables := DB.DBA.sql_primary_keys (dsn, name_part (_pk_table, 0, null),
				       	      name_part (_pk_table, 1, null),
				              name_part (_pk_table, 2, null));

   for (idx := 0; idx < length (pk_tables); idx := idx + 1)
     {
	_pk_tables := pk_tables [idx];
--	result (_pk_tables[0] || '.' || _pk_tables[1] || '.' || _pk_tables[2] || '.' || _pk_tables[3]);
	result (_pk_tables[3]);
     }
}
;

create procedure DB.DBA."XMLA_GET_FK" (in _pk_table varchar, in _fk_table varchar, in dsn varchar)
{
   declare PK_TABLE_SCHEMA VARCHAR;
   declare PK_TABLE_NAME VARCHAR;
   declare PK_COLUMN_NAME VARCHAR;
   declare FK_TABLE_SCHEMA VARCHAR;
   declare FK_TABLE_NAME VARCHAR;
   declare FK_COLUMN_NAME VARCHAR;
   declare KEY_SEQ SMALLINT;
   declare UPDATE_RULE SMALLINT;
   declare DELETE_RULE SMALLINT;
   declare FK_NAME VARCHAR;

   declare fk_tables, _fk_tables, idx, _n1, _n2, _n3, _dsn any;

   declare exit handler for sqlstate '*VD052'
     {
   	fk_tables := sql_foreign_keys (dsn, NULL, NULL, NULL, name_part (_pk_table, 0, null),
							      name_part (_pk_table, 1, null),
							      name_part (_pk_table, 2, null));
   	for (idx := 0; idx < length (fk_tables); idx := idx + 1)
     	  {
	    _fk_tables := fk_tables [idx];
	     result (_fk_tables [0] || '.' || _fk_tables[1] || '.' || _fk_tables [2], _fk_tables[3], _pk_table, _fk_tables[7],
		   _fk_tables[8], _fk_tables[9], _fk_tables[10], _fk_tables[11], _fk_tables[12]);
     	  }
	return;
     };

   declare exit handler for sqlstate 'VD052'
     {
	return;
     };

   result_names (PK_TABLE_SCHEMA, PK_TABLE_NAME, PK_COLUMN_NAME, FK_TABLE_SCHEMA, FK_TABLE_NAME, FK_COLUMN_NAME,
		 KEY_SEQ, UPDATE_RULE, DELETE_RULE, FK_NAME);

   _n1 := name_part (_pk_table, 0, null);
   _n2 := name_part (_pk_table, 1, null);
   _n3 := name_part (_pk_table, 2, null);
   _dsn := dsn;
   fk_tables := vector ();

   for (select TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, DSN as LOC_DSN from DB.DBA.XMLA_VDD_DBSCHEMA_TABLES
	where tb = _n3 and cat = _n1 and dsn = _dsn) do
	  {
             fk_tables := vector_concat (fk_tables, sql_foreign_keys
		(_dsn, NULL, NULL, NULL, TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME));
	  }

   for (idx := 0; idx < length (fk_tables); idx := idx + 1)
     {
	_fk_tables := fk_tables [idx];
	if (_pk_table <> _fk_table)
	  result (name_part (_fk_table, 1, null), _fk_tables[2], _fk_tables[3],
	 	  name_part (_fk_table, 1, null), _fk_tables[6], _fk_tables[7],
		  _fk_tables[8], _fk_tables[9], _fk_tables[10], _fk_tables[11]);
	else
	  result (_fk_tables[1], _fk_tables[2], _fk_tables[3],
	 	  _fk_tables[5], _fk_tables[6], _fk_tables[7],
		  _fk_tables[8], _fk_tables[9], _fk_tables[10], _fk_tables[11]);
     }
}
;

create procedure XMLA_USER_INIT ()
{
  if (exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'XMLA'))
    return;
  DB.DBA.USER_CREATE ('XMLA', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'XMLA'));
}
;

XMLA_USER_INIT ()
;

DB.DBA.VHOST_REMOVE (lpath=>'/XMLA')
;

DB.DBA.VHOST_DEFINE (lpath=>'/XMLA', ppath=>'/SOAP/', soap_user=>'XMLA',
              soap_opts => vector ('ServiceName', 'XMLAnalysis', 'elementFormDefault', 'qualified'))
;

grant execute on DB.."Discover" to "XMLA"
;

grant execute on DB.."Execute" to "XMLA"
;

grant execute on DB.DBA."xmla_vdd_dbschema_columns_rpoc" to "XMLA"
;

grant execute on DB.DBA."XMLA_VDD_DBSCHEMA_COLUMNS" to "XMLA"
;

grant all privileges on DB.DBA."XMLA_VDD_DBSCHEMA_COLUMNS" to "XMLA"
;

grant execute on DB.DBA."xmla_vdd_dbschema_tables_rpoc" to "XMLA"
;

grant execute on DB.DBA."XMLA_VDD_DBSCHEMA_TABLES" to "XMLA"
;

grant all privileges on DB.DBA."XMLA_VDD_DBSCHEMA_TABLES" to "XMLA"
;

grant all privileges on DB.DBA."XMLA_VDD_DBSCHEMA_PROVIDER_TYPES" to "XMLA"
;

grant execute on DB.DBA."xmla_vdd_dbschema_provider_types_rpoc" to "XMLA"
;

grant execute on DB.DBA."XMLA_GET_FK" to "XMLA"
;

grant execute on DB.DBA."XMLA_GET_PK" to "XMLA"
;

grant all privileges on DB.DBA."SYS_FOREIGN_KEYS_VIEW" to "XMLA"
;

grant all privileges on DB.DBA."SYS_PRIMARY_KEYS_VIEW" to "XMLA"
;


create procedure
xmla_cursor_stmt_change (in _props any, inout _stmt varchar)
{
  declare _direction, new_stmpt, _left_str, _left_str_u varchar;
  declare _skip, _n_rows, _return_bookmark, _bookmark_from, _return_row_count integer;

  _left_str := '';

  _direction := xmla_get_property (_props, 'direction', 'forward');
  _bookmark_from := xmla_get_property (_props, 'bookmark-from', NULL);
  _skip := xmla_get_property (_props, 'skip', 0);
  _skip := xmla_make_skip (_bookmark_from, _skip, 1);

  _n_rows := xmla_get_property (_props, 'n-rows', null);
  _return_bookmark := xmla_get_property (_props, 'return-bookmark', 0);
  _return_row_count := xmla_get_property (_props, 'retrieve-row-count', 0);

  new_stmpt := 'select ';

  if (_direction = 'forward')
    {
      if (_skip)
	{
	  _skip := cast (_skip as varchar);
	  if (_n_rows is null)
	    new_stmpt := new_stmpt || 'top ' || _skip || ' ';
	  else
	    new_stmpt := new_stmpt || 'top ' || _skip || ', ' || cast (_n_rows as varchar) || ' ';
	}
      else if (_n_rows > 0)
	  new_stmpt := new_stmpt || 'top ' || cast (_n_rows as varchar) || ' ';
    }

  if (_return_bookmark)
    new_stmpt := new_stmpt || '''_dummy_'' AS BOOKMARK, ';

  if (_return_row_count)
    new_stmpt := new_stmpt || '1 AS ROWCOUNT, ';

  _stmt := trim (_stmt);

  if (length (_stmt) > 6)
    _left_str := "LEFT" (_stmt, 6);

  _left_str_u := ucase (_left_str, 6);

  if (_left_str_u = 'SELECT')
    _stmt := new_stmpt || ' * FROM (' || _stmt || ') __xml_dt0' ;

    --_stmt := replace (_stmt, _left_str, new_stmpt, 1);

}
;

create procedure
xmla_make_cursors_state (in _props any, inout _dta any, in stmt any)
{
  declare _direction varchar;
  declare _return_bookmark, _return_row_count, _skip, idx, idx2, len, _direc_save, _n_rows integer;
  declare line, temp, _bookmark_from any;

  _return_bookmark := xmla_get_property (_props, 'return-bookmark', 0);
  _skip := xmla_get_property (_props, 'skip', 0);
  _n_rows := xmla_get_property (_props, 'n-rows', null);

  _direction := xmla_get_property (_props, 'direction', 'forward');
  _bookmark_from := xmla_get_property (_props, 'bookmark-from', NULL);
  _return_row_count := xmla_get_property (_props, 'retrieve-row-count', 0);

  len := length (_dta);

  if (_return_row_count)
    {
	declare _rows any;

	_rows := xmla_get_rows_from_stmt (stmt);

	for (idx := 0; idx < len; idx := idx + 1)
	 {
	   line := _dta[idx];
	   aset (line, 1, _rows);
  	   aset (_dta, idx, line);
	 }
     }

  _direc_save := 0;
  if (_direction = 'backward')
    _direc_save := len;

  if (_direction = 'backward')
    {
       for (idx := 0; idx < len / 2 + 1; idx := idx + 1)
	 {
	   line := _dta[idx];
	   temp := _dta[len - idx - 1];
	   aset (_dta, idx, temp);
	   aset (_dta, len - idx - 1, line);
	 }
     }

  if (_return_bookmark)
    {
       for (idx := 0; idx < len; idx := idx + 1)
	 {
	   line := _dta[idx];
  	   if (_direction = 'backward')
	     aset (line, 0, encode_base64 (serialize (vector(0, len - idx - 1, _direc_save))));
	   else
	     aset (line, 0, encode_base64 (serialize (vector(_skip, idx, _direc_save))));
	   aset (_dta, idx, line);
	 }
    }


  if (_direction = 'backward')
     {
        declare _new_dta, _end any;

        _skip := xmla_make_skip (_bookmark_from, _skip, 0);
	_new_dta := vector ();
	idx2 := 0;
	_end := _n_rows + _skip;

	if (_end > len)
	  _end := len;

       for (idx := _skip; idx < _end; idx := idx + 1)
	 {
	   line := _dta[idx];
	   _new_dta := vector_concat (_new_dta, vector (line));
	   idx2 := idx2 + 1;
	 }

	_dta := _new_dta;
    }
}
;


create procedure
xmla_make_skip (in _skip any, in _add int, in _dir int)
{
   declare pos_vec, ret any;

   ret := _add;

   if (_skip is NULL)
     return ret;

   if (_skip <> '')
     {
	pos_vec := deserialize (decode_base64 (_skip));

	if (not isarray (pos_vec))
	   signal ('00006', 'Unable to process the bookmark, because the "bookmark-from" property is incorrect');
	if (_dir)
	  ret := pos_vec[0] + pos_vec[1] + _add;
	else
	  ret := pos_vec[2] - pos_vec[1] + _add - 1;
     }
   else
     signal ('00007', 'Unable to process the bookmark, because the "bookmark-from" property is not set or incorrect');

   return ret;
}
;

create procedure
xmla_get_version ()
{
   return '1.01';
}
;


create procedure
xmla_format_mdta (inout mdta any)
{
   declare idx, _line, _name, temp any;

   temp := mdta[0];

   for (idx := 0; idx < length (temp); idx := idx + 1)
     {
	_line := temp[idx];
	_name := temp[idx][0];
	_name := replace (_name, ' ', '_');
	aset (_line, 0, _name);
	aset (temp, idx, _line);
     }

    aset (mdta, 0, temp);
}
;


create procedure
xmla_get_rows_from_stmt (in stmt any)
{
   declare res, mdta, dta, state, msg any;
   declare new_stmpt, tmp varchar;
   declare pos integer;

   declare exit handler for sqlstate '*'
    {
       return -1;
    };

   new_stmpt := 'SELECT count(*) ';
   stmt := trim (stmt);
   tmp := ucase (stmt);
   pos := strstr (tmp, 'FROM');
   tmp := "LEFT" (stmt, pos);

   stmt := replace (stmt, tmp, new_stmpt, 1);

   res := exec (stmt, state, msg, vector (), 0, mdta, dta);

   return dta[0][0];
}
;


create procedure
xmla_sparql_result (inout mdta any, inout dta any, in stmt any)
{
  declare idx, idx2, tmdta any;

  stmt := ucase (trim (stmt));

  if ("LEFT" (stmt, 6) <> 'SPARQL')
     return;

  tmdta := mdta[0];

  for (idx := 0; idx < length (tmdta); idx := idx + 1)
    {
        declare temp, line any;

  	if (mdta[0][idx][1] = 242)
	  {
	    for (idx2 := 0; idx2 < length (dta); idx2 := idx2 + 1)
	      {
  		 line := dta[idx2];
  		 temp := line[idx];
  		 temp := cast (temp as varchar);
    		 aset (line, idx, temp);
    	         aset (dta, idx2, line);
	       }
	   }
    }
}
;

