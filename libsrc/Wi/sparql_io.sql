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

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_RSET_XML_WRITE_NS (inout ses any)
{
  -- http ('<?xml version="1.0" ?>\n', ses);
  http ('<sparql xmlns="http://www.w3.org/2005/sparql-results#" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.w3.org/2001/sw/DataAccess/rf1/result2.xsd">', ses);
}
;


--!AWK PUBLIC
create procedure DB.DBA.SPARQL_RSET_XML_WRITE_HEAD (inout ses any, in colnames any)
{
  declare i, col_count integer;
  http ('\n <head>', ses);
  i := 0; col_count := length (colnames);
  while (i < col_count)
    {
      http (sprintf ('\n  <variable name="%s"/>', colnames[i]), ses);
      i := i + 1;
    }
  http ('\n </head>', ses);
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_RSET_XML_WRITE_ROW_OLD (inout ses any, inout colnames any, inout row any)
{
  declare i, col_count integer;
  -- dbg_obj_princ ('DB.DBA.SPARQL_RSET_XML_WRITE_ROW (..., ',colnames, row, ')');
  --http ('<result/>', ses);
  --return;
  http ('\n <result>', ses);
  i := 0; col_count := length (colnames);
  for (i := 0; i < col_count; i := i + 1)
    {
      declare _name varchar;
      declare _val any;
      _val := aref_set_0 (row, i);
      if (_val is null)
        goto end_of_binding;
      if (isiri_id (_val))
        {
          if (_val >= min_bnode_iri_id ())
            http (sprintf ('\n   <binding name="%s"><bnode>%s</bnode></binding>', colnames[i], id_to_iri (_val)), ses);
	  else
	    {
              declare res varchar;
              res := id_to_iri (_val);
--              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = _val));
              if (res is null)
                res := sprintf ('bad://%d', iri_id_num (_val));
              http (sprintf ('\n   <binding name="%s"><uri>', colnames[i]), ses);
              http_value (res, 0, ses);
              http ('</uri></binding>', ses);
	    }
	}
      else if (isstring (_val) and (1 = __box_flags (_val)))
        {
          if (_val like 'nodeID://%')
            http (sprintf ('\n   <binding name="%s"><bnode>%s</bnode></binding>', colnames[i], _val), ses);
          else
            http (sprintf ('\n   <binding name="%s"><uri>%V</uri></binding>', colnames[i], _val), ses);
        }
      else
        {
	  declare lang, dt varchar;
	  declare is_xml_lit int;
	  declare sql_val any;
	  if (__tag (_val) in (185, 230)) -- string output or an XML entity
	    {
              http (sprintf ('\n   <binding name="%s"><literal>', colnames[i]), ses);
	      http_value (_val, 0, ses);
              http ('</literal></binding>', ses);
              goto end_of_binding;
	    }
	  lang := DB.DBA.RDF_LANGUAGE_OF_LONG (_val, null);
	  dt := DB.DBA.RDF_DATATYPE_IRI_OF_LONG (_val, null);
	  if (dt = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral')
	    is_xml_lit := 1;
	  else
            is_xml_lit := 0;
	  if (lang is not null)
	    {
	      if (dt is not null)
                http (sprintf ('\n   <binding name="%s"><literal xml:lang="%V" datatype="%V">',
		    colnames[i], cast (lang as varchar), cast (dt as varchar)), ses);
	      else
                http (sprintf ('\n   <binding name="%s"><literal xml:lang="%V">',
		    colnames[i], cast (lang as varchar)), ses);
	    }
	  else
	    {
	      if (dt is not null)
                http (sprintf ('\n   <binding name="%s"><literal datatype="%V">',
		    colnames[i], cast (dt as varchar)), ses);
	      else
                http (sprintf ('\n   <binding name="%s"><literal>', colnames[i]), ses);
	    }
	  sql_val := __rdf_sqlval_of_obj (_val, 1);
	  if (isentity (sql_val))
	    is_xml_lit := 1;
	  if (__tag (sql_val) = __tag of varchar) -- UTF-8 value kept in a DV_STRING box
	    sql_val := charset_recode (sql_val, 'UTF-8', '_WIDE_');
	  if (is_xml_lit) http ('<![CDATA[', ses);
	  http_value (sql_val, 0, ses);
	  if (is_xml_lit) http (']]>', ses);
          http ('</literal></binding>', ses);
        }
end_of_binding: ;
      aset_zap_arg (row, i, _val);
    }

  http ('\n  </result>', ses);
}
;

--!AWK PUBLIC
create function DB.DBA.SPARQL_RSET_XML_HTTP_PRE (in colnames any, in accept varchar)
{
  declare ses integer;
  http_header ('Content-Type: ' || subseq (accept, strchr (accept, ' ')+1) || '; charset=UTF-8\r\n');
  http_flush (1);
  ses := 0;
  DB.DBA.SPARQL_RSET_XML_WRITE_NS (ses);
  DB.DBA.SPARQL_RSET_XML_WRITE_HEAD (ses, colnames);
  http ('\n <results>');
  return colnames;
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_RSET_XML_HTTP_INIT (inout env any)
{
  env := 0;
}
;

--!AWK PUBLIC
create function DB.DBA.SPARQL_RSET_XML_HTTP_FINAL (inout env any)
{
  http ('\n    </results>');
  http ('\n  </sparql>');
}
;

--!AWK PUBLIC
create aggregate DB.DBA.SPARQL_RSET_XML_HTTP (inout colnames any, inout row any) from
  DB.DBA.SPARQL_RSET_XML_HTTP_INIT,
  sparql_rset_xml_write_row, -- DB.DBA.SPARQL_RSET_XML_WRITE_ROW_OLD,
  DB.DBA.SPARQL_RSET_XML_HTTP_FINAL
;



--!AWK PUBLIC
create procedure SPARQL_RSET_TTL_WRITE_NS (inout ses any)
{
  http ('@prefix res: <http://www.w3.org/2005/sparql-results#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
_:_ rdf:type res:ResultSet .\n', ses);
}
;

create procedure DB.DBA.SPARQL_RSET_TTL_WRITE_HEAD (inout ses any, in colnames any)
{
  declare i, col_count integer;
  col_count := length (colnames);
  for (i := 0; i < col_count; i := i + 1)
    {
      http ('_:_ res:resultVariable "', ses);
      http_escape (colnames[i], 11, ses, 0, 1);
      http ('" .\n', ses);
    }
}
;
--!AWK PUBLIC
create function DB.DBA.SPARQL_RSET_TTL_HTTP_PRE (in colnames any, in accept varchar)
{
  declare ses, colctr, colcount integer;
  declare res any;
  -- dbg_obj_princ ('DB.DBA.SPARQL_RSET_TTL_HTTP_PRE (', colnames, accept, ')');
  http_header ('Content-Type: ' || accept || '; charset=UTF-8\r\n');
  http_flush (1);
  ses := 0;
  DB.DBA.SPARQL_RSET_TTL_WRITE_NS (ses);
  DB.DBA.SPARQL_RSET_TTL_WRITE_HEAD (ses, colnames);
  colcount := length (colnames);
  res := make_array (colcount * 7, 'any');
  for (colctr := 0; colctr < colcount; colctr := colctr + 1)
    {
      res [colctr * 7] := colnames [colctr];
    }
  return vector (dict_new (16000), 0, '', '', '', 0, 0, res, 0);
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_RSET_TTL_HTTP_INIT (inout env any)
{
  env := 0;
}
;

--!AWK PUBLIC
create function DB.DBA.SPARQL_RSET_TTL_HTTP_FINAL (inout env any)
{
  ;
}
;

--!AWK PUBLIC
create aggregate DB.DBA.SPARQL_RSET_TTL_HTTP (inout colnames any, inout row any) from
  DB.DBA.SPARQL_RSET_TTL_HTTP_INIT,
  sparql_rset_ttl_write_row,
  DB.DBA.SPARQL_RSET_TTL_HTTP_FINAL
;

-----
-- SPARQL protocol client, i.e., procedures to execute remote SPARQL statements.

create procedure DB.DBA.SPARQL_REXEC_INT (
  in res_mode integer,
  in service varchar,
  in query varchar,
  in dflt_graph varchar,
  inout named_graphs any,
  inout req_hdr any,
  in maxrows integer,
  inout metas any,
  inout bnode_dict any
  )
{
  declare req_uri, req_method, req_body, local_req_hdr, ret_body, ret_hdr any;
  declare ret_content_type varchar;
  req_body := string_output();
  http ('query=', req_body);
  http_url (query, 0, req_body);
  if (dflt_graph is not null and dflt_graph <> '')
    {
      http ('&default-graph-uri=', req_body);
      http_url (dflt_graph, 0, req_body);
    }
  foreach (varchar uri in named_graphs) do
    {
      http ('&named-graph-uri=', req_body);
      http_url (uri, 0, req_body);
    }
  if (maxrows is not null)
    http (sprintf ('&maxrows=%d', maxrows), req_body);
  req_body := string_output_string (req_body);
  local_req_hdr := 'Accept: application/sparql-results+xml, text/rdf+n3, text/rdf+ttl, application/turtle, application/x-turtle, application/rdf+xml, application/xml';
  if (length (req_body) + length (service) >= 1900)
    {
      req_method := 'POST';
      req_uri := service;
      local_req_hdr := local_req_hdr || '\r\nContent-Type: application/x-www-form-urlencoded';
    }
  else
    {
      req_method := 'GET';
      req_uri := service || '?' || req_body;
      req_body := '';
    }
  if (length (req_hdr) > 0)
    req_hdr := concat (req_hdr, '\r\n', local_req_hdr );
  else
    req_hdr := local_req_hdr;
  -- dbg_obj_princ ('Request: ', req_method, req_uri);
  -- dbg_obj_princ ('Request: ', req_hdr);
  -- dbg_obj_princ ('Request: ', req_body);
  ret_body := http_get (req_uri, ret_hdr, req_method, req_hdr, req_body);
  -- dbg_obj_princ ('Returned header: ', ret_hdr);
  -- dbg_obj_princ ('Returned body: ', ret_body);
  ret_content_type := http_request_header (ret_hdr, 'Content-Type', null, null);
  if (ret_content_type is null or
    (strstr (ret_content_type, 'application/sparql-results+xml') is null and
      strstr (ret_content_type, 'application/rdf+xml') is null and
      strstr (ret_content_type, 'text/rdf+n3') is null and
      strstr (ret_content_type, 'text/rdf+ttl') is null and
      strstr (ret_content_type, 'application/turtle' ) is null and
      strstr (ret_content_type, 'application/x-turtle' ) is null ) )
    {
      declare ret_begin, ret_html any;
      ret_begin := "LEFT" (ret_body, 1024);
      ret_html := xtree_doc (ret_begin, 2);
      if (xpath_eval ('/html|/xhtml', ret_html) is not null)
        ret_content_type := 'text/html';
      else if (xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] /rset:sparql', ret_html) is not null
            or xpath_eval ('[xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"] /rset2:sparql', ret_html) is not null)
        ret_content_type := 'application/sparql-results+xml';
      else if (xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"] /rdf:rdf', ret_html) is not null)
        ret_content_type := 'application/rdf+xml';
      else if (strstr (ret_begin, '<html>') is not null or
        strstr (ret_begin, '<xhtml>') is not null )
        ret_content_type := 'text/html';
      else
        {
          ret_content_type := 'text/plain';
        }
    }
  if (strstr (ret_content_type, 'application/sparql-results+xml') is not null)
    {
      declare ret_xml, var_list, var_metas, ret_row, out_nulls any;
      declare var_ctr, var_count integer;
      declare vect_acc any;
      declare row_inx integer;
       -- dbg_obj_princ ('application/sparql-results+xml ret_body=', ret_body);
      ret_xml := xtree_doc (ret_body, 0);
      var_list := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] [xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"]
                               /rset:sparql/rset:head/rset:variable | /rset2:sparql/rset2:head/rset2:variable', ret_xml, 0);
      if (0 = length (var_list))
        {
	  declare bool_ret any;
          bool_ret := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] [xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"]
                                   /rset:sparql/rset:boolean | /rset2:sparql/rset2:boolean', ret_xml);
	  if (bool_ret is not null)
	    {
	      bool_ret := cast (bool_ret as varchar);
	      if ('true' = bool_ret)
	        bool_ret := 1;
	      else if ('false' = bool_ret)
	        bool_ret := 0;
	      else
                signal ('RDFZZ', sprintf (
                    'DB.DBA.SPARQL_REXEC(''%.300s'', ...) has received invalid boolean value ''%.300s''',
                    service, bool_ret ) );
              metas :=
	        vector (
		  vector (
	            vector ('__ask_retval', 242, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0) ),
		  1 );
              if (0 = res_mode)
	        {
		  declare __ask_retval integer;
		  result_names (__ask_retval);
		  result (bool_ret);
		}
              else if (1 = res_mode)
	        return vector (vector (bool_ret));
	      return;
	    }
          signal ('RDFZZ', sprintf (
            'DB.DBA.SPARQL_REXEC(''%.300s'', ...) has received result with no variables',
	    service ) );
	}
      var_count := length (var_list);
      var_metas := make_array (var_count, 'any');
      out_nulls := make_array (var_count, 'any');
      for (var_ctr := var_count - 1; var_ctr >= 0; var_ctr := var_ctr - 1)
        {
          declare var_name varchar;
          var_name := cast (xpath_eval ('@name', var_list[var_ctr]) as varchar);
          var_list [var_ctr] := var_name;
          var_metas [var_ctr] := vector (var_name, 242, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0);
          out_nulls [var_ctr] := null;
        }
      -- dbg_obj_princ ('var_metas=', var_metas);
      if (0 = res_mode)
        exec_result_names (var_metas);
      else if (1 = res_mode)
        vectorbld_init (vect_acc);
      row_inx := 0;
      for (ret_row := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] [xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"]
                                   /rset:sparql/rset:results/rset:result | /rset2:sparql/rset2:results/rset2:result', ret_xml);
        ret_row is not null;
        ret_row := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] [xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"]
                                following-sibling::rset:result | following-sibling::rset2:result', ret_row) )
        {
          declare out_fields, ret_cols any;
          declare col_ctr, col_count integer;
          out_fields := out_nulls;
          ret_cols := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] [xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"]
                                   rset:binding | rset2:binding', ret_row, 0);
          col_count := length (ret_cols);
          for (col_ctr := col_count - 1; col_ctr >= 0; col_ctr := col_ctr - 1)
            {
              declare ret_col any;
              declare var_name, var_type, var_strval varchar;
              declare var_pos integer;
              ret_col := ret_cols[col_ctr];
              var_name := cast (xpath_eval ('string(@name)', ret_col) as varchar);
              -- dbg_obj_princ ('var_name=', var_name);
              var_pos := position (var_name, var_list) - 1;
              if (var_pos >= 0)
                {
                  var_type := cast (xpath_eval ('local-name(*)', ret_col) as varchar);
                  var_strval := charset_recode (xpath_eval ('string(*)', ret_col), '_WIDE_', 'UTF-8');
                  -- dbg_obj_princ ('var_type=', var_type);
                  if ('uri' = var_type)
                    out_fields [var_pos] := iri_to_id (var_strval);
                  else if ('bnode' = var_type)
                    {
                      declare local_iid IRI_ID;
                      if (bnode_dict is null)
                        {
                          bnode_dict := dict_new ();
                          local_iid := iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'));
                          dict_put (bnode_dict, var_strval, local_iid);
                        }
                      else
                        {
                          local_iid := dict_get (bnode_dict, var_strval, null);
                          if (local_iid is null)
                            {
                              local_iid := iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'));
                              dict_put (bnode_dict, var_strval, local_iid);
                            }
                        }
                      out_fields [var_pos] := local_iid;
                    }
                  else if ('literal' = var_type)
                    {
                      declare lang, dt varchar;
                      lang := charset_recode (xpath_eval ('*/@xml:lang', ret_col), '_WIDE_', 'UTF-8');
                      dt := charset_recode (xpath_eval ('*/@datatype', ret_col), '_WIDE_', 'UTF-8');
                      out_fields [var_pos] := DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (
                        var_strval, dt, lang );
                    }
                  else
                    signal ('RDFZZ', sprintf (
                        'DB.DBA.SPARQL_REXEC(''%.300s'', ...) contains unsupported type of bound value ''%.300s''',
                        service, var_type ) );
                }
            }
          if (0 = res_mode)
            exec_result (out_fields);
          else if (1 = res_mode)
            vectorbld_acc (vect_acc, out_fields);
          row_inx := row_inx + 1;
          if (maxrows is not null and maxrows > 0 and row_inx >= maxrows)
            ret_row := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] [xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"]
                                    ../rset:result[position() = last()] | ../rset2:result[position() = last()]', ret_row);
        }
      metas := vector (var_metas, 1);
      if (0 = res_mode)
        {
          return;
        }
      else if (1 = res_mode)
        {
          vectorbld_final (vect_acc);
          return vect_acc;
        }
    }
  if (strstr (ret_content_type, 'application/rdf+xml') is not null)
    {
      declare res_dict any;
      res_dict := DB.DBA.RDF_RDFXML_TO_DICT (ret_body,'http://local.virt/tmp','http://local.virt/tmp');
      metas := vector (vector (vector ('res_dict', 242, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0)), 1);
      if (0 = res_mode)
        {
          result_names (res_dict);
          result (res_dict);
          return;
        }
      else if (1 = res_mode)
        return vector (vector (res_dict));
    }
  if (strstr (ret_content_type, 'text/rdf+n3') is not null or
    strstr (ret_content_type, 'text/rdf+ttl') is not null or
    strstr (ret_content_type, 'application/turtle') is not null or
    strstr (ret_content_type, 'application/x-turtle') is not null )
    {
      declare res_dict any;
      res_dict := DB.DBA.RDF_TTL2HASH (ret_body, '');
      metas := vector (vector (vector ('res_dict', 242, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0)), 1);
      if (0 = res_mode)
        {
          result_names (res_dict);
          result (res_dict);
          return;
        }
      else if (1 = res_mode)
        return vector (vector (res_dict));
    }
  if (strstr (ret_content_type, 'text/plain') is not null)
    {
      signal ('RDFZZ', sprintf (
          'DB.DBA.SPARQL_REXEC(''%.300s'', ...) returned Content-Type ''%.300s'' status ''%.300s''\n%.1000s',
          service, ret_content_type, ret_hdr[0], "LEFT" (ret_body, 1024) ) );
    }
  if (strstr (ret_content_type, 'text/html') is not null)
    {
      signal ('RDFZZ', sprintf (
          'DB.DBA.SPARQL_REXEC(''%.300s'', ...) returned Content-Type ''%.300s'' status ''%.300s''\n%.1000s',
          service, ret_content_type, ret_hdr[0],
	  cast (xtree_doc (ret_body, 2) as varchar) ) );
    }
  signal ('RDFZZ', sprintf (
      'DB.DBA.SPARQL_REXEC(''%.300s'', ...) returned unsupported Content-Type ''%.300s''',
      service, ret_content_type ) );
}
;

create procedure DB.DBA.SPARQL_REXEC (
  in service varchar,
  in query varchar,
  in dflt_graph varchar,
  in named_graphs any,
  in req_hdr any,
  in maxrows integer,
  in bnode_dict any
  )
{
  declare metas any;
  DB.DBA.SPARQL_REXEC_INT (0, service, query, dflt_graph, named_graphs, req_hdr, maxrows, metas, bnode_dict);
}
;

create function DB.DBA.SPARQL_REXEC_TO_ARRAY (
  in service varchar,
  in query varchar,
  in dflt_graph varchar,
  in named_graphs any,
  in req_hdr any,
  in maxrows integer,
  in bnode_dict any
  ) returns any
{
  declare metas any;
  return DB.DBA.SPARQL_REXEC_INT (1, service, query, dflt_graph, named_graphs, req_hdr, maxrows, metas, bnode_dict);
}
;

create procedure DB.DBA.SPARQL_REXEC_WITH_META (
  in service varchar,
  in query varchar,
  in dflt_graph varchar,
  in named_graphs any,
  in req_hdr any,
  in maxrows integer,
  in bnode_dict any,
  out metadata any,
  out resultset any
  )
{
  resultset := DB.DBA.SPARQL_REXEC_INT (1, service, query, dflt_graph, named_graphs, req_hdr, maxrows, metadata, bnode_dict);
  -- dbg_obj_princ ('DB.DBA.SPARQL_REXEC_WITH_META (): metadata = ', metadata, ' resultset = ', resultset);
}
;


-----
-- SPARQL SOAP web service (incomplete, do not try to use in applications!)

create procedure "querySoap"  (in  "Command" varchar
	    , in  "Properties" any
	    , out "Error" any __soap_fault '__XML__'
	    , out "ws_sparql_xsd" any
	   )
	__soap_options ( __soap_type:='__ANY__',
                 "soapAction":='urn:FIXME:querySoap',
                 "RequestNamespace":='urn:http://www.w3.org/2005/08/sparql-protocol-query/#',
                 "ResponseNamespace":='urn:http://www.w3.org/2005/08/sparql-protocol-query/#',
                 "PartName":='return'
	       )
{
   declare stmt, state, msg, mdta, dta, res, ses any;
   stmt := get_keyword ('Statement', "Command");
   ses := string_output ();

   -- dbg_obj_princ ('Statement to be executed by querySoap: ', stmt);
   res := exec (stmt, state, msg, vector (), 0, mdta, dta);

   SPARQL_RSET_XML_WRITE_NS (ses);
   SPARQL_RESULTS_XML_WRITE_HEAD (ses, mdta);
   SPARQL_RESULTS_XML_WRITE_RES (ses, mdta, dta);

   -- dbg_obj_princ (mdta);
   http ('</sparql>', ses);

   ses := string_output_string (ses);
   string_to_file ('out.xml', ses, -2);
   res := xml_tree_doc (ses);
   return res;
}
;

--!AWK PUBLIC
create procedure SPARQL_WRITE_EXEC_STATUS (inout ses any, in line_format varchar, inout status any)
{
  declare lctr, lcount integer;
  declare lines any;
  if (status is null)
    return;
  http (sprintf (line_format, 'SQL State', status[0]), ses);
  lines := split_and_decode (status[1], 0, '\0\0\n');
  lcount := length (lines);
  for (lctr := 0; lctr < lcount; lctr := lctr + 1)
    {
      http (sprintf (line_format, case (lctr) when 0 then 'SQL Message' else '' end, lines[lctr]), ses);
    }
  http (sprintf (line_format, 'Exec Time', cast (status[2] as varchar) || ' ms'), ses);
  http (sprintf (line_format, 'DB Activity', cast (status[3] as varchar)), ses);
}
;


create procedure SPARQL_RESULTS_XML_WRITE_HEAD (inout ses any, in mdta any)
{
  declare i, col_count integer;

  http ('\n <head>', ses);

  mdta := mdta[0];
  i := 0; col_count := length (mdta);
  while (i < col_count)
    {
      declare _name varchar;
      declare _type, _type_name, nill int;
      _name := mdta[i][0];
      _type := mdta[i][1];
      if (length (mdta[i]) > 4)
        nill := mdta[i][4];
      else
        nill := 0;
      http (sprintf ('\n  <variable name="%s"/>', _name), ses);
      i := i + 1;
    }
--  http (sprintf ('<link href="%s" />', 'FIX_ME'), ses);
  http ('\n </head>', ses);
}
;

create procedure SPARQL_RESULTS_XML_WRITE_RES (inout ses any, in mdta any, inout dta any)
{
  http ('\n <results distinct="false" ordered="true">', ses);

  for (declare ctr integer, ctr := 0; ctr < length (dta); ctr := ctr + 1)
      SPARQL_RESULTS_XML_WRITE_ROW (ses, mdta, dta[ctr]);

  http ('\n </results>', ses);
}
;

create procedure DB.DBA.SPARQL_RESULTS_XML_WRITE_ROW (inout ses any, in mdta any, inout dta any)
{
  -- dbg_obj_princ ('DB.DBA.SPARQL_RESULTS_XML_WRITE_ROW (..., ',mdta, dta, ')');
  http ('\n  <result>', ses);
  mdta := mdta[0];
  for (declare x any, x := 0; x < length (mdta); x := x + 1)
    {
      declare _name varchar;
      declare _val any;
      _name := mdta[x][0];
      _val := dta[x];
      if (_val is null)
        goto end_of_binding;
      if (isiri_id (_val))
        {
          if (_val >= min_bnode_iri_id ())
            http (sprintf ('\n   <binding name="%s"><bnode>%s</bnode></binding>', _name, id_to_iri (_val)), ses);
	  else
	    {
              declare res varchar;
              res := id_to_iri (_val);
--              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = _val));
              if (res is null)
                res := sprintf ('bad://%d', iri_id_num (_val));
              http (sprintf ('\n   <binding name="%s"><uri>', _name), ses);
              http_value (res, 0, ses);
              http ('</uri></binding>', ses);
	    }
	}
      else if (isstring (_val) and (1 = __box_flags (_val)))
        {
          if (_val like 'nodeID://%')
            http (sprintf ('\n   <binding name="%s"><bnode>%s</bnode></binding>', _name, _val), ses);
          else
            http (sprintf ('\n   <binding name="%s"><uri>%V</uri></binding>', _name, _val), ses);
        }
      else
        {
	  declare lang, dt varchar;
	  declare is_xml_lit int;
	  declare sql_val any;
	  if (__tag (_val) in (185, 230)) -- string output or an XML entity
	    {
              http (sprintf ('\n   <binding name="%s"><literal>', _name), ses);
	      http_value (_val, 0, ses);
              http ('</literal></binding>', ses);
              goto end_of_binding;
	    }
	  lang := DB.DBA.RDF_LANGUAGE_OF_LONG (_val, null);
	  dt := DB.DBA.RDF_DATATYPE_IRI_OF_LONG (_val, null);
	  if (dt = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral')
	    is_xml_lit := 1;
	  else
            is_xml_lit := 0;
	  if (lang is not null)
	    {
	      if (dt is not null)
                http (sprintf ('\n   <binding name="%s"><literal xml:lang="%V" datatype="%V">',
		    _name, cast (lang as varchar), cast (dt as varchar)), ses);
	      else
                http (sprintf ('\n   <binding name="%s"><literal xml:lang="%V">',
		    _name, cast (lang as varchar)), ses);
	    }
	  else
	    {
	      if (dt is not null)
                http (sprintf ('\n   <binding name="%s"><literal datatype="%V">',
		    _name, cast (dt as varchar)), ses);
	      else
                http (sprintf ('\n   <binding name="%s"><literal>',
		    _name), ses);
	    }
	  sql_val := __rdf_sqlval_of_obj (_val, 1);
	  if (isentity (sql_val))
	    is_xml_lit := 1;
	  if (__tag (sql_val) = __tag of varchar) -- UTF-8 value kept in a DV_STRING box
	    sql_val := charset_recode (sql_val, 'UTF-8', '_WIDE_');
	  if (is_xml_lit) http ('<![CDATA[', ses);
	  http_value (sql_val, 0, ses);
	  if (is_xml_lit) http (']]>', ses);
          http ('</literal></binding>', ses);
        }
end_of_binding: ;
    }

  http ('\n  </result>', ses);
}
;

create procedure SPARQL_RESULTS_RDFXML_WRITE_NS (inout ses any)
{
  http ('<rdf:RDF xmlns:res="http://www.w3.org/2005/sparql-results#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:nodeID="rset">
    <rdf:type rdf:resource="http://www.w3.org/2005/sparql-results#ResultSet" />', ses);
}
;

create procedure SPARQL_RESULTS_RDFXML_WRITE_HEAD (inout ses any, in mdta any)
{
  declare i, col_count integer;
  mdta := mdta[0];
  i := 0; col_count := length (mdta);
  while (i < col_count)
    {
      declare _name varchar;
      declare _type, _type_name, nill int;
      _name := mdta[i][0];
      _type := mdta[i][1];
      if (length (mdta[i]) > 4)
        nill := mdta[i][4];
      else
        nill := 0;
      http (sprintf ('\n    <res:resultVariable>%V</res:resultVariable>', _name), ses);
      i := i + 1;
    }
}
;

create procedure SPARQL_RESULTS_RDFXML_WRITE_RES (inout ses any, in mdta any, inout dta any)
{
  for (declare ctr integer, ctr := 0; ctr < length (dta); ctr := ctr + 1)
    {
      http ( sprintf ('\n    <res:solution rdf:nodeID="r%d">', ctr), ses);
      SPARQL_RESULTS_RDFXML_WRITE_ROW (ses, mdta, dta, ctr);
      http ('\n    </res:solution>', ses);
    }
}
;

create procedure SPARQL_RESULTS_RDFXML_WRITE_ROW (inout ses any, in mdta any, inout dta any, in rowno integer)
{
  mdta := mdta[0];
  for (declare x any, x := 0; x < length (mdta); x := x + 1)
    {
      declare _name varchar;
      declare _val any;
      _name := mdta[x][0];
      _val := dta[rowno][x];
      if (_val is null)
        goto end_of_binding;
      http (sprintf ('\n      <res:binding rdf:nodeID="r%dc%d"><res:variable>%V</res:variable><res:value', rowno, x, _name), ses);
      if (isiri_id (_val))
        {
          if (_val >= min_bnode_iri_id ())
	    {
	      http (sprintf (' rdf:nodeID="%s"/></res:binding>', id_to_iri (_val)), ses);
	    }
	  else
	    {
              declare res varchar;
              res := id_to_iri (_val);
--              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = _val));
              if (res is null)
                res := sprintf ('bad://%d', iri_id_num (_val));
              http (sprintf (' rdf:resource="%V"/></res:binding>', res), ses);
	    }
	}
      else if (isstring (_val) and (1 = __box_flags (_val)))
        {
          if (_val like 'nodeID://%')
            http (sprintf (' rdf:nodeID="%s"/></res:binding>', _val), ses);
          else
            http (sprintf (' rdf:resource="%V"/></res:binding>', _val), ses);
        }
      else
        {
	  declare lang, dt varchar;
          declare val_tag integer;
          val_tag := __tag (_val);
	  if (val_tag = 185) -- string output
	    {
              http ('>', ses);
	      http_value (_val, 0, ses);
              http ('</res:value></res:binding>', ses);
              goto end_of_binding;
	    }
	  if (val_tag = 230) -- XML entity
	    {
              http ('rdf:parseType="Literal">', ses);
	      http_value (_val, 0, ses);
              http ('</res:value></res:binding>', ses);
              goto end_of_binding;
	    }
	  lang := DB.DBA.RDF_LANGUAGE_OF_LONG (_val, null);
	  dt := DB.DBA.RDF_DATATYPE_IRI_OF_LONG (_val, null);
	  if (lang is not null)
	    {
	      if (dt is not null)
                http (sprintf (' xml:lang="%V" datatype="%V">', cast (lang as varchar), cast (dt as varchar)), ses);
	      else
                http (sprintf (' xml:lang="%V">', cast (lang as varchar)), ses);
	    }
	  else
	    {
	      if (dt is not null)
                http (sprintf (' datatype="%V">', cast (dt as varchar)), ses);
	      else
                http ('>', ses);
	    }
          if (__tag of datetime = rdf_box_data_tag (_val))
            __rdf_long_to_ttl (_val, ses);
          else
	    {
	      _val := __rdf_sqlval_of_obj (_val, 1);
	      if (__tag (_val) = __tag of varchar) -- UTF-8 value kept in a DV_STRING box
		_val := charset_recode (_val, 'UTF-8', '_WIDE_');
	      http_value (_val, 0, ses);
	    }
          http ('</res:value></res:binding>', ses);
        }
end_of_binding: ;
    }
}
;

create procedure SPARQL_RESULTS_TTL_WRITE_NS (inout ses any)
{
  http ('@prefix res: <http://www.w3.org/2005/sparql-results#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
[] rdf:type res:ResultSet ;', ses);
}
;

create procedure SPARQL_RESULTS_TTL_WRITE_HEAD (inout ses any, in mdta any)
{
  declare i, col_count integer;
  mdta := mdta[0];
  i := 0; col_count := length (mdta);
  while (i < col_count)
    {
      declare _name varchar;
      declare _type, _type_name, nill int;
      _name := mdta[i][0];
      _type := mdta[i][1];
      if (length (mdta[i]) > 4)
        nill := mdta[i][4];
      else
        nill := 0;
      http ('\n  res:resultVariable "', ses);
      http_escape (_name, 11, ses, 0, 1);
      http ('"', ses);
      i := i + 1;
      if (i < col_count)
        http (' ;', ses);
    }
}
;

create procedure SPARQL_RESULTS_TTL_WRITE_RES (inout ses any, in mdta any, inout dta any)
{
  declare ctr, len integer;
  ctr := 0; len := length (dta);
  while (ctr < len)
    {
      http ('\n  res:solution [', ses);
      SPARQL_RESULTS_TTL_WRITE_ROW (ses, mdta, dta, ctr);
      http (' ]', ses);
      ctr := ctr + 1;
      if (ctr < len)
        http (' ;', ses);
    }
}
;

create procedure SPARQL_RESULTS_TTL_WRITE_ROW (inout ses any, in mdta any, inout dta any, in rowno integer)
{
  declare need_semicolon integer;
  mdta := mdta[0];
  need_semicolon := 0;
  for (declare x any, x := 0; x < length (mdta); x := x + 1)
    {
      declare _name varchar;
      declare _val any;
      _name := mdta[x][0];
      _val := dta[rowno][x];
      if (_val is not null)
        {
          if (need_semicolon)
            http (' ;', ses);
          else
            need_semicolon := 1;
          http ('\n      res:binding [ res:variable "', ses);
          http_escape (_name, 11, ses, 0, 1);
          http ('" ; res:value ', ses);
          DB.DBA.RDF_LONG_TO_TTL (_val, ses);
          http (' ]', ses);
        }
    }
}
;

create procedure SPARQL_RESULTS_JAVASCRIPT_HTML_WRITE (inout ses any, inout metas any, inout rset any, in is_js integer := 0, in esc_mode integer := 1)
{
  declare varctr, varcount, resctr, rescount integer;
  varcount := length (metas[0]);
  rescount := length (rset);
  if (is_js)
    {
      http ('document.writeln(''', ses);
      SPARQL_RESULTS_JAVASCRIPT_HTML_WRITE(ses,metas,rset,0,13);
      http (''');', ses);
      return;
   }
  http ('<table class="sparql" border="1">', ses);
  http ('\n  <tr>', ses);
  --http ('\n    <th>Row</th>', ses);
  for (varctr := 0; varctr < varcount; varctr := varctr + 1)
    {
      http('\n    <th>', ses);
      http_escape (metas[0][varctr][0], esc_mode, ses, 0, 1);
      http('</th>', ses);
    }
  http ('\n  </tr>', ses);
  for (resctr := 0; resctr < rescount; resctr := resctr + 1)
    {
      http('\n  <tr>', ses);
      --http('\n    <td>', ses);
      --http(cast((resctr + 1) as varchar), ses);
      --http('</td>', ses);
      for (varctr := 0; varctr < varcount; varctr := varctr + 1)
        {
          declare val any;
          val := rset[resctr][varctr];
          if (val is null)
            {
              http('\n    <td></td>', ses);
              goto end_of_val_print; -- see below
            }
          http('\n    <td>', ses);
          if (isiri_id (val))
            http_escape (id_to_iri (val), esc_mode, ses, 1, 1);
          else if (isstring (val) and (1 = __box_flags (val)))
            http_escape (val, esc_mode, ses, 1, 1);
          else if (__tag of varchar = __tag (val))
            {
              http_escape (val, esc_mode, ses, 1, 1);
            }
	  else if (185 = __tag (val)) -- string output
	    {
              http_escape (cast (val as varchar), esc_mode, ses, 1, 1);
	    }
	  else if (__tag of XML = rdf_box_data_tag (val)) -- string output
	    {
              http (__rdf_strsqlval (val), ses);
	    }
          else
            {
              http_escape (__rdf_strsqlval (val), esc_mode, ses, 1, 1);
            }
          http ('</td>', ses);
end_of_val_print: ;
        }
      http('\n  </tr>', ses);
    }
  http ('\n</table>', ses);
}
;

create procedure SPARQL_RESULTS_JSON_WRITE (inout ses any, inout metas any, inout rset any)
{
  declare varctr, varcount, resctr, rescount integer;
  varcount := length (metas[0]);
  rescount := length (rset);
  http ('\n{ "head": { "link": [], "vars": [', ses);
  for (varctr := 0; varctr < varcount; varctr := varctr + 1)
    {
      if (varctr > 0)
        http(', "', ses);
      else
        http('"', ses);
      http_escape (metas[0][varctr][0], 11, ses, 0, 1);
      http('"', ses);
    }
  http ('] },\n  "results": { "distinct": false, "ordered": true, "bindings": [', ses);
  for (resctr := 0; resctr < rescount; resctr := resctr + 1)
    {
      declare need_comma integer;
      if (resctr > 0)
        http(',\n    {', ses);
      else
        http('\n    {', ses);
      need_comma := 0;
      for (varctr := 0; varctr < varcount; varctr := varctr + 1)
        {
          declare val any;
          val := rset[resctr][varctr];
          if (val is null)
            goto end_of_val_print; -- see below
          if (need_comma)
            http('\t, "', ses);
          else
            {
              http(' "', ses);
              need_comma := 1;
            }
          http_escape (metas[0][varctr][0], 11, ses, 0, 1);
          http('": { ', ses);
          if (isiri_id (val))
            {
              if (val > min_bnode_iri_id ())
                http (sprintf ('"type": "bnode", "value": "%s', id_to_iri (val)), ses);
              else
                {
                  http ('"type": "uri", "value": "', ses);
                  http_escape (id_to_iri (val), 11, ses, 1, 1);
                }
            }
          else if (__tag of rdf_box = __tag (val))
            {
              declare res varchar;
              declare dat, typ any;
              dat := __rdf_sqlval_of_obj (val, 1);
              typ := rdf_box_type (val);
              if (not isstring (dat))
                {
                  http ('"type": "typed-literal", "datatype": "', ses);
                  if (257 <> typ)
                    res := coalesce ((select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = typ));
                  else
                    res := cast (__xsd_type (dat) as varchar);
                  http_escape (res, 11, ses, 1, 1);
                  http ('", "value": "', ses);
                  dat := __rdf_strsqlval (dat);
                }
              else if (257 <> typ)
                {
                  http ('"type": "typed-literal", "datatype": "', ses);
                  res := coalesce ((select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = typ));
                  http_escape (res, 11, ses, 1, 1);
                  http ('", "value": "', ses);
                }
              else if (257 <> rdf_box_lang (val))
                {
                  http ('"type": "literal", "xml:lang": "', ses);
                  res := coalesce ((select lower (RL_ID) from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = rdf_box_lang (val)));
                  http_escape (res, 11, ses, 1, 1);
                  http ('", "value": "', ses);
                }
              else
                http ('"type": "literal", "value": "', ses);
              http_escape (dat, 11, ses, 1, 1);
            }
          else if (__tag of varchar = __tag (val))
            {
              if (1 = __box_flags (val))
                {
                  if (val like 'nodeID://%')
                    http (sprintf ('"type": "bnode", "value": "%s', val), ses);
                  else
                    {
                      http ('"type": "uri", "value": "', ses);
                      http_escape (val, 11, ses, 1, 1);
                    }
                }
              else
                {
                  http ('"type": "literal", "value": "', ses);
                  http_escape (val, 11, ses, 1, 1);
                }
            }
          else if (__tag of varbinary = __tag (val))
            {
              http ('"type": "literal", "value": "', ses);
              http_escape (val, 11, ses, 0, 0);
            }
          else if (185 = __tag (val))
            {
              http ('"type": "literal", "value": "', ses);
              http_escape (cast (val as varchar), 11, ses, 1, 1);
            }
          else if (230 = __tag (val))
            {
              http ('"type": "literal", "value": "', ses);
              http_escape (serialize_to_UTF8_xml (val), 11, ses, 1, 1);
            }
          else
            {
              http ('"type": "typed-literal", "datatype": "', ses);
              http_escape (cast (__xsd_type (val) as varchar), 11, ses, 1, 1);
              http ('", "value": "', ses);
              http_escape (__rdf_strsqlval (val), 11, ses, 1, 1);
            }
          http ('" }', ses);

end_of_val_print: ;
        }
      http('}', ses);
    }
  http (' ] } }', ses);
}
;

create function DB.DBA.SPARQL_RESULTS_WRITE (inout ses any, inout metas any, inout rset any, in accept varchar, in add_http_headers integer, in status any := null) returns varchar
{
  declare singlefield varchar;
  declare ret_mime varchar;
  if (status is not null)
    {
      http_header (concat (coalesce (http_header_get (), ''),
          'X-SQL-State: ', status[0], '\r\nX-SQL-Message: ', status[1],
          '\r\nX-Exec-Milliseconds: ', cast (status[2] as varchar), '\r\nX-Exec-DB-Activity: ', cast (status[3] as varchar),
          '\r\n' ) );
    }
  if ((1 >= length (rset)) and (1 = length (metas[0])))
    singlefield := metas[0][0][0];
  else
    singlefield := NULL;
  -- dbg_obj_princ ('DB.DBA.SPARQL_RESULTS_WRITE: length(rset) = ', length(rset), ' metas=', metas, ' singlefield=', singlefield);
  if ('__ask_retval' = singlefield)
    {
      if (strstr (accept, 'application/sparql-results+json') is not null or strstr (accept, 'application/json') is not null)
        {
          if (strstr (accept, 'application/sparql-results+json') is not null)
            ret_mime := 'application/sparql-results+json';
          else
            ret_mime := 'application/json';
          http (
            concat (
              '{  "head": { "link": [] }, "boolean": ',
              case (length (rset)) when 0 then 'false' else 'true' end,
              '}'),
            ses );
        }
      else
        {
          ret_mime := 'application/sparql-results+xml';
          SPARQL_RSET_XML_WRITE_NS (ses);
          http (
            concat (
              '\n <head></head>\n <boolean>',
              case (length (rset)) when 0 then 'false' else 'true' end,
              '</boolean>\n</sparql>'),
            ses );
        }
      goto body_complete;
    }
  if ((1 = length (rset)) and
    (1 = length (rset[0])) and
    (214 = __tag (rset[0][0])) )
    {
      declare triples any;
      triples := dict_list_keys (rset[0][0], 1);
      if (
        strstr (accept, 'text/rdf+n3') is not null or
        strstr (accept, 'text/rdf+ttl') is not null or
        strstr (accept, 'application/turtle') is not null or
        strstr (accept, 'application/x-turtle') is not null or
        (accept = 'auto') )
        {
          if (strstr (accept, 'text/rdf+n3') is not null)
            ret_mime := 'text/rdf+n3';
          else if (strstr (accept, 'text/rdf+ttl') is not null)
            ret_mime := 'text/rdf+ttl';
          else if (strstr (accept, 'application/turtle') is not null)
            ret_mime := 'application/turtle';
          else if (strstr (accept, 'application/x-turtle') is not null)
            ret_mime := 'application/x-turtle';
          else
            ret_mime := 'text/rdf+n3';
          DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
          if (status is not null)
            SPARQL_WRITE_EXEC_STATUS (ses, '#%015s: %s\n', status);
	}
      else if (strstr (accept, 'application/soap+xml') is not null)
	{
	  declare soap_ns, spt_ns varchar;
	  declare soap_ver int;

	  if (strstr (accept, 'application/soap+xml;11') is not null)
	    soap_ver := 11;
	  else
	    soap_ver := 12;
	  soap_ns := DB.DBA.SPARQL_SOAP_NS (soap_ver);
	  spt_ns := DB.DBA.SPARQL_PT_NS ();
	  if (soap_ver = 12)
	    ret_mime := 'application/soap+xml';
	  else
	    ret_mime := 'text/xml';
	  http ('<soapenv:Envelope xmlns:soapenv="'||soap_ns||'"><soapenv:Body><query-result xmlns="'||spt_ns||'">', ses);
          http ('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" '||
      			'xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">', ses);
          DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 0, ses);
	  http ('</rdf:RDF>', ses);
	  http ('</query-result></soapenv:Body></soapenv:Envelope>', ses);
	  goto body_complete;
	}
      else
        {
          ret_mime := 'application/rdf+xml';
          DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 1, ses);
        }
      goto body_complete;
    }
  if (strstr (accept, 'application/sparql-results+json') is not null or strstr (accept, 'application/json') is not null)
    {
      if (strstr (accept, 'application/sparql-results+json') is not null)
        ret_mime := 'application/sparql-results+json';
      else
        ret_mime := 'application/json';
      if (('callretRDF/XML-0' = singlefield) or ('callretTURTLE-0' = singlefield) or ('callretTTL-0' = singlefield))
        {
          http('"', ses);
          http_escape (cast (rset[0][0] as varchar), 11, ses, 1, 1);
          http('"', ses);
        }
      else
        SPARQL_RESULTS_JSON_WRITE (ses, metas, rset);
      goto body_complete;
    }
  if (('callretRDF/XML-0' = singlefield) and ('auto' = accept))
    {
      ret_mime := 'application/rdf+xml';
      http (rset[0][0], ses);
      goto body_complete;
    }
  if (('callretTURTLE-0' = singlefield) or ('callretTTL-0' = singlefield))
    {
      if (
        strstr (accept, 'text/rdf+n3') is not null or
        strstr (accept, 'text/rdf+ttl') is not null or
        strstr (accept, 'application/turtle') is not null or
        strstr (accept, 'application/x-turtle') is not null or
        (accept = 'auto') )
        {
          if (strstr (accept, 'text/rdf+n3') is not null)
            ret_mime := 'text/rdf+n3';
          else if (strstr (accept, 'text/rdf+ttl') is not null)
            ret_mime := 'text/rdf+ttl';
          else if (strstr (accept, 'application/turtle') is not null)
            ret_mime := 'application/turtle';
          else if (strstr (accept, 'application/x-turtle') is not null)
            ret_mime := 'application/x-turtle';
          else
            ret_mime := 'text/rdf+n3';
        }
      http (rset[0][0], ses);
      if (status is not null)
        SPARQL_WRITE_EXEC_STATUS (ses, '#%015s: %s\n', status);
      goto body_complete;
    }
  if (strstr (accept, 'text/html') is not null)
    {
      ret_mime := 'text/html';
      SPARQL_RESULTS_JAVASCRIPT_HTML_WRITE(ses, metas, rset, 0);
      if (status is not null)
        {
          http ('<hr /><br /><pre>', ses);
          SPARQL_WRITE_EXEC_STATUS (ses, '%015s: %V\n', status);
          http ('</pre>', ses);
        }
      goto body_complete;
    }
  if (strstr (accept, 'application/vnd.ms-excel') is not null)
    {
      ret_mime := 'application/vnd.ms-excel';
      SPARQL_RESULTS_JAVASCRIPT_HTML_WRITE(ses, metas, rset, 0);
      goto body_complete;
    }
  if (strstr (accept, 'application/javascript') is not null)
    {
      ret_mime := 'application/javascript';
      SPARQL_RESULTS_JAVASCRIPT_HTML_WRITE(ses, metas, rset, 1);
      goto body_complete;
    }
  if (strstr (accept, 'application/soap+xml') is not null)
    {
      declare soap_ns, spt_ns varchar;
      declare soap_ver int;

      if (strstr (accept, 'application/soap+xml;11') is not null)
        soap_ver := 11;
      else
        soap_ver := 12;
      soap_ns := DB.DBA.SPARQL_SOAP_NS (soap_ver);
      spt_ns := DB.DBA.SPARQL_PT_NS ();
      if (soap_ver = 12)
        ret_mime := 'application/soap+xml';
      else
        ret_mime := 'text/xml';
      http ('<soapenv:Envelope xmlns:soapenv="'||soap_ns||'"><soapenv:Body><query-result xmlns="'||spt_ns||'">', ses);
      SPARQL_RSET_XML_WRITE_NS (ses);
      SPARQL_RESULTS_XML_WRITE_HEAD (ses, metas);
      SPARQL_RESULTS_XML_WRITE_RES (ses, metas, rset);
      http ('\n</sparql>', ses);
      http ('</query-result></soapenv:Body></soapenv:Envelope>', ses);
      goto body_complete;
    }
  if (strstr (accept, 'application/sparql-results+xml') is null)
    {
      if (
        strstr (accept, 'text/rdf+n3') is not null or
        strstr (accept, 'text/rdf+ttl') is not null or
        strstr (accept, 'application/turtle') is not null or
        strstr (accept, 'application/x-turtle') is not null or
        (accept = 'auto') )
        {
          if (strstr (accept, 'text/rdf+n3') is not null)
            ret_mime := 'text/rdf+n3';
          else if (strstr (accept, 'text/rdf+ttl') is not null)
            ret_mime := 'text/rdf+ttl';
          else if (strstr (accept, 'application/turtle') is not null)
            ret_mime := 'application/turtle';
          else if (strstr (accept, 'application/x-turtle') is not null)
            ret_mime := 'application/x-turtle';
          else
            ret_mime := 'text/rdf+n3';
          SPARQL_RESULTS_TTL_WRITE_NS (ses);
          SPARQL_RESULTS_TTL_WRITE_HEAD (ses, metas);
          if (length (rset) > 0)
            http (' ;', ses);
          SPARQL_RESULTS_TTL_WRITE_RES (ses, metas, rset);
          http (' .', ses);
          goto body_complete;
        }
      if (strstr (accept, 'application/rdf+xml') is not null)
        {
          ret_mime := 'application/rdf+xml';
          SPARQL_RESULTS_RDFXML_WRITE_NS (ses);
          SPARQL_RESULTS_RDFXML_WRITE_HEAD (ses, metas);
          SPARQL_RESULTS_RDFXML_WRITE_RES (ses, metas, rset);
          http ('\n  </rdf:Description>', ses);
          http ('\n</rdf:RDF>', ses);
          goto body_complete;
        }
    }
  ret_mime := 'application/sparql-results+xml';
  SPARQL_RSET_XML_WRITE_NS (ses);
  SPARQL_RESULTS_XML_WRITE_HEAD (ses, metas);
  SPARQL_RESULTS_XML_WRITE_RES (ses, metas, rset);
  http ('\n</sparql>', ses);

body_complete:
  if (add_http_headers)
    http_header ('Content-Type: ' || ret_mime || '; charset=UTF-8\r\n');
  return ret_mime;
}
;

-- CLIENT --
--select -- dbg_obj_princ (soap_client (url=>'http://neo:6666/SPARQL', operation=>'querySoap', target_namespace=>'urn:FIXME', soap_action =>'urn:FIXME:querySoap', parameters=> vector ('Command', soap_box_structure ('Statement' , 'select TEST from DB.DBA.SPARQL_TABLE3'), 'Properties', soap_box_structure ('PropertyList', 'None' )), style=>2));


create procedure WS.WS.SPARQL_VHOST_RESET ()
{
  if (not exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'SPARQL'))
    {
      DB.DBA.USER_CREATE ('SPARQL', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'SPARQL'));
      DB.DBA.EXEC_STMT ('grant SPARQL_SELECT to "SPARQL"', 0);
    }
  if (registry_get ('__SPARQL_VHOST_RESET') = '1')
    return;
  DB.DBA.VHOST_REMOVE (lpath=>'/SPARQL');
  DB.DBA.VHOST_REMOVE (lpath=>'/sparql');
  DB.DBA.VHOST_REMOVE (lpath=>'/services/sparql-query');
  DB.DBA.VHOST_DEFINE (lpath=>'/sparql/', ppath => '/!sparql/', is_dav => 1, vsp_user => 'dba', opts => vector('noinherit', 1));
  DB.DBA.VHOST_REMOVE (lpath=>'/sparql-auth');
  DB.DBA.VHOST_DEFINE (lpath=>'/sparql-auth',
    ppath => '/!sparql/',
    is_dav => 1,
    vsp_user => 'dba',
    opts => vector('noinherit', 1),
    auth_fn=>'DB.DBA.HP_AUTH_SPARQL_USER',
    realm=>'SPARQL',
    sec=>'digest');
--DB.DBA.EXEC_STMT ('grant execute on DB.."querySoap" to "SPARQL", 0);
--VHOST_DEFINE (lpath=>'/services/sparql-query', ppath=>'/SOAP/', soap_user=>'SPARQL',
--              soap_opts => vector ('ServiceName', 'XMLAnalysis', 'elementFormDefault', 'qualified'));
  registry_set ('__SPARQL_VHOST_RESET', '1');
}
;


-----
-- SPARQL HTTP request handler
create procedure DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (
  inout path varchar, inout params any, inout lines any,
  in httpcode varchar, in httpstatus varchar,
  in query varchar, in state varchar, in msg varchar, in accept varchar := null)
{
  -- dbg_obj_princ ('DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (...', httpcode, httpstatus, '...', state, msg, accept);
--  declare exit handler for sqlstate '*' { signal (state, msg); };
  if (httpstatus is null)
    {
      declare errtitle varchar;
      declare delim varchar;
      delim := strchr (msg, '\n');
      if (delim is null)
        errtitle := msg;
      else
        errtitle := subseq (msg, 0, delim);
      httpstatus := sprintf ('Error %s %s', state, errtitle);
    }
  if (accept is not null and strstr (accept, 'application/soap+xml') is not null)
    {
      declare err_str any;
      declare soap_ver int;
      if (strstr (accept, 'application/soap+xml;11') is not null)
	{
	  soap_ver := 11;
	  http_header ('Content-Type: text/xml; charset=UTF-8\r\n');
	}
      else
	{
          soap_ver := 12;
	  http_header ('Content-Type: application/soap+xml; charset=UTF-8\r\n');
	}
      http_request_status (sprintf ('HTTP/1.1 500 %s', httpstatus));
      err_str := soap_make_error ('320', state, msg, soap_ver);
      http (err_str);
      return;
    }
  http_request_status (sprintf ('HTTP/1.1 %s %s', httpcode, httpstatus));
  http_header ('Content-Type: text/plain\r\n');
  http (concat (state, ' Error ', msg));
  if (query is not null)
    {
      http ('\n\nSPARQL query:\n');
      http (query);
    }
}
;

create procedure DB.DBA.SPARQL_WSDL11 (in lines any)
{
  declare host any;
  host := http_request_header (lines, 'Host', null, null);
    http (sprintf ('<?xml version="1.0" encoding="utf-8"?>
    <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
		 xmlns:tns="http://www.w3.org/2005/08/sparql-protocol-query/#"
		 targetNamespace="http://www.w3.org/2005/08/sparql-protocol-query/#">
    <import namespace="http://www.w3.org/2005/08/sparql-protocol-query/#"
    location="http://www.w3.org/TR/sprot11/sparql-protocol-query-11.wsdl"/>
      <service name="SparqlService">
        <port name="SparqlServicePort" binding="tns:QuerySoapBinding">
	  <address location="http://%s/sparql"/>
	</port>
      </service>
    </definitions>', host));
}
;

create procedure DB.DBA.SPARQL_WSDL (in lines any)
{
  declare host any;
  host := http_request_header (lines, 'Host', null, null);
    http (sprintf ('<?xml version="1.0" encoding="utf-8"?>
    <description xmlns="http://www.w3.org/2006/01/wsdl"
		 xmlns:tns="http://www.w3.org/2005/08/sparql-protocol-query/#"
		 targetNamespace="http://www.w3.org/2005/08/sparql-protocol-query/#">
      <include location="http://www.w3.org/TR/rdf-sparql-protocol/sparql-protocol-query.wsdl" />
      <service name="SparqlService" interface="tns:SparqlQuery">
	<endpoint name="SparqlEndpoint" binding="tns:querySoap" address="http://%s/sparql"/>
      </service>
    </description>', host));
}
;

create procedure DB.DBA.SPARQL_SOAP_NS (in ver int)
{
  if (ver = 11)
    return 'http://schemas.xmlsoap.org/soap/envelope/';
  else if (ver = 12)
    return 'http://www.w3.org/2003/05/soap-envelope';
  else
    signal ('42000', 'Un-supported SOAP version');
}
;

create procedure DB.DBA.SPARQL_PT_NS ()
{
  return 'http://www.w3.org/2005/09/sparql-protocol-types/#';
}
;

--!AWK PUBLIC
create function DB.DBA.PARSE_SPARQL_WS_PARAMS (in lst any) returns any
{
  declare pval, parse, res any;
  declare lst_len, ctr integer;
  declare pname, ttl_txt varchar;
  lst_len := length (lst);
  ttl_txt := '';
  vectorbld_init (res);
  for (ctr := 0; ctr < lst_len; ctr := ctr+2)
    {
      pname := lst[ctr];
      pval := lst[ctr+1];
      if (regexp_like (pval, '^(("[^"\\\\]")|(\'[^\'\\\\]\'))\044'))
        parse := subseq (pval, 1, length (pval)-1);
      else if (regexp_like (pval, '^(("""[^"\\\\]""")|(\'\'\'[^\'\\\\]\'\'\'))\044'))
        parse := subseq (pval, 3, length (pval)-3);
      else if (regexp_like ('^<.+>\044', pval))
        {
          parse := (subseq (pval, 1, length (pval)-1));
          __box_flags_set (parse, 1);
        }
      else if (regexp_like (pval, '^([+-]?[0-9]+)\044'))
        parse := cast (pval as integer);
      else if (regexp_like (pval, '^([+-]?[0-9]+\.[0-9]+([eE][+-]?[0-9]+)?)\044'))
        parse := cast (pval as double precision);
      else
        {
          parse := null;
          ttl_txt := concat (ttl_txt, '<', pname, '> <p> ', pval, ' .\n');
        }
      if (parse is not null)

        vectorbld_acc (res, ':' || pname, parse);
    }
  if (ttl_txt <> '')
    {
      declare triples any;
      triples := DB.DBA.RDF_TTL2SQLHASH (ttl_txt, '', '!sparql', 0);
      triples := dict_list_keys (triples, 1);
      foreach (any t in triples) do
        {
          vectorbld_acc (res, ':' || t[0], t[2]);
        }
    }
  vectorbld_final (res);
  return res;
}
;

create procedure DB.DBA.rdf_find_str (in x any)
{
  return cast (x as varchar);
}
;

grant execute on DB.DBA.rdf_find_str to public
;

-- Web service endpoint.

create procedure WS.WS."/!sparql/" (inout path varchar, inout params any, inout lines any)
{
  declare query, full_query, format, should_sponge, debug, def_qry varchar;
  declare dflt_graphs, named_graphs any;
  declare paramctr, paramcount, qry_params, maxrows, can_sponge, start_time integer;
  declare ses, content any;
  declare def_max, add_http_headers, hard_timeout, timeout, client_supports_partial_res, sp_ini, soap_ver int;
  declare http_meth, content_type, ini_dflt_graph, get_user varchar;
  declare state, msg varchar;
  declare metas, rset any;
  declare accept, soap_action, user_id varchar;
  declare exec_time, exec_db_activity any;

  if (registry_get ('__sparql_endpoint_debug') = '1')
    {
      for (declare i int, i := 0; i < length (params); i := i + 2)
        {
	  if (isstring (params[i+1]))
	    dbg_printf ('%s=%s',params[i],params[i+1]);
	  else if (__tag (params[i+1]) = 185)
	    dbg_printf ('%s=%s',params[i],'<strses>');
	  else
	    dbg_printf ('%s=%s',params[i],'<box>');
	}
    }

  set http_charset='utf-8';
  ses := 0;
  query := null;
  format := '';
  should_sponge := '';
  debug := get_keyword ('debug', params, case (get_keyword ('query', params, '')) when '' then '1' else '' end);
  add_http_headers := 1;
  sp_ini := 0;
  dflt_graphs := vector ();
  named_graphs := vector ();
  maxrows := 1024*1024; -- More than enough for web-interface.
  http_meth := http_request_get ('REQUEST_METHOD');
  ini_dflt_graph := cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'DefaultGraph');
  hard_timeout := atoi (coalesce (cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'MaxQueryExecutionTime'), '0')) * 1000;
  timeout := atoi (coalesce (cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'ExecutionTimeout'), '0')) * 1000;
  client_supports_partial_res := 0;
  def_qry := cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'DefaultQuery');
  if (def_qry is null)
    def_qry := 'SELECT * WHERE {?s ?p ?o}';
  def_max := atoi (coalesce (cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'ResultSetMaxRows'), '-1'));
  -- if timeout specified and it's over 1 second
  user_id := connection_get ('SPARQLUserId', 'SPARQL');
  get_user := '';
  soap_ver := 0;
  soap_action := http_request_header (lines, 'SOAPAction', null, null);
  content_type := http_request_header (lines, 'Content-Type', null, '');

  if (content_type = 'application/soap+xml')
    soap_ver := 12;
  else if (soap_action is not null)
    soap_ver := 11;

  content := null;
  can_sponge := coalesce ((select top 1 1
      from DB.DBA.SYS_USERS as sup
        join DB.DBA.SYS_ROLE_GRANTS as g on (sup.U_ID = g.GI_SUPER)
        join DB.DBA.SYS_USERS as sub on (g.GI_SUB = sub.U_ID)
      where sup.U_NAME = 'SPARQL' and sub.U_NAME = 'SPARQL_SPONGE' ), 0);
  declare exit handler for sqlstate '*' {
    DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
      '500', 'SPARQL Request Failed',
      query, __SQL_STATE, __SQL_MESSAGE, format);
     return;
   };

  -- the WSDL
  if (http_path () = '/sparql/services.wsdl')
    {
      http_header ('Content-Type: application/wsdl+xml\r\n');
--      http_header ('Content-Type: text/xml\r\n');
      DB.DBA.SPARQL_WSDL (lines);
      return;
    }
  else if (http_path () = '/sparql/services11.wsdl')
    {
      http_header ('Content-Type: text/xml\r\n');
      DB.DBA.SPARQL_WSDL11 (lines);
      return;
    }

  paramcount := length (params);
  if (((0 = paramcount) or ((2 = paramcount) and ('Content' = params[0]))) and soap_ver = 0)
    {
       declare redir varchar;
       redir := registry_get ('WS.WS.SPARQL_DEFAULT_REDIRECT');
       if (isstring (redir))
         {
            http_request_status ('HTTP/1.1 301 Moved Permanently');
            http_header (sprintf ('Location: %s\r\n', redir));
            return;
         }
http('<html xmlns="http://www.w3.org/1999/xhtml">\n');
http('	<head>\n');
http('		<title>Virtuoso SPARQL Query Form</title>\n');
http('		<style type="text/css">\n');
http('		label.n { display: inline; margin-top: 10pt; }\n');
http('		body { font-family: arial, helvetica, sans-serif; font-size: 9pt; color: #234; }\n');
http('		fieldset { border: 2px solid #86b9d9; }\n');
http('		legend { font-size: 12pt; color: #86b9d9; }\n');
http('		label { font-weight: bold; }\n');
http('		h1 { width: 100%; background-color: #86b9d9; font-size: 18pt; font-weight: normal; color: #fff; height: 4ex; text-align: right; vertical-align: middle; padding-right:  8px; }\n');
http('		textarea { width: 100%; padding: 3px; }\n');
http('		</style>\n');
http('		<script language="JavaScript">\n');
http('var last_format = 1;\n');
http('function format_select(query_obg)\n');
http('{\n');
http('  var query = query_obg.value; \n');
http('  var format = query_obg.form.format;\n');
http('\n');
http('  if (query.match(/construct/i) && last_format == 1) {\n');
http('    for(var i = format.options.length; i > 0; i--)\n');
http('      format.options[i] = null;');
http('    format.options[1] = new Option(\'N3/Turtle\',\'text/rdf+n3\');\n');
http('    format.options[2] = new Option(\'RDF/XML\',\'application/rdf+xml\');\n');
http('    format.selectedIndex = 1;\n');
http('    last_format = 2;\n');
http('  }\n');
http('\n');
http('  if (!query.match(/construct/i) && last_format == 2) {\n');
http('    for(var i = format.options.length; i > 0; i--)\n');
http('      format.options[i] = null;\n');
http('    format.options[1] = new Option(\'HTML\',\'text/html\');\n');
http('    format.options[2] = new Option(\'XML\',\'application/sparql-results+xml\');\n');
http('    format.options[3] = new Option(\'JSON\',\'application/sparql-results+json\');\n');
http('    format.options[4] = new Option(\'Javascript\',\'application/javascript\');\n');
http('    format.selectedIndex = 1;\n');
http('    last_format = 1;\n');
http('  }\n');
http('}\n');
http('		</script>\n');
http('	</head>\n');
http('	<body>\n');
http('		<div id="header">\n');
http('			<h1>OpenLink Virtuoso SPARQL Query</h1>\n');
http('		</div>\n');
http('		<div id="main">\n');
http('			<p>This query page is designed to help you test OpenLink Virtuoso SPARQL protocol endpoint. <br/>\n');
http('			Consult the <a href="http://virtuoso.openlinksw.com/wiki/main/Main/VOSSparqlProtocol">Virtuoso Wiki page</a> describing the service \n');
http('			or the <a href="http://docs.openlinksw.com/virtuoso/">Online Virtuoso Documentation</a> section <a href="http://docs.openlinksw.com/virtuoso/rdfandsparql.html">RDF Database and SPARQL</a>.</p>\n');
http('			<p>There is also a rich Web based user interface with sample queries. \n');
if (DB.DBA.VAD_CHECK_VERSION('iSPARQL') is null)
  http('			In order to use it you must install the iSPARQL package (isparql_dav.vad).</p>\n');
else
  http('			You can access it at: <a href="/isparql">/isparql</a>.</p>\n');
http('			<form action="" method="GET">\n');
http('			<fieldset>\n');
http('			<legend>Query</legend>\n');
http('			  <label for="default-graph-uri">Default Graph URI</label>\n');
http('			  <br />\n');
http('			  <input type="text" name="default-graph-uri" id="default-graph-uri"\n');
http(sprintf ('				  	value="%s" size="80"/>\n', coalesce (ini_dflt_graph, '') ));
http('			  <br /><br />\n');
if (can_sponge)
  {
    declare s_param varchar;
    s_param := get_keyword ('should-sponge', params, '');
http('<select name="should-sponge" id="should-sponge">');
http('  <option' ||
  case (s_param) when '' then ' selected="selected"' else '' end ||
  ' value="">Use only local data (including data retrieved before), but do not retrieve more</option>\n');
http('  <option' ||
  case (s_param) when 'soft' then ' selected="selected"' else '' end ||
  ' value="soft">Retrieve remote RDF data for all missing source graphs</option>\n');
http('  <option' ||
  case (s_param) when 'grab-all' then ' selected="selected"' else '' end ||
  ' value="grab-all">Retrieve all missing remote RDF data that might be useful</option>\n');
http('  <option' ||
  case (s_param) when 'grab-all-seealso' then ' selected="selected"' else '' end ||
  ' value="grab-all-seealso">Retrieve all missing remote RDF data that might be useful, including seeAlso references</option>\n');
http('  <option' ||
  case (s_param) when 'grab-everything' then ' selected="selected"' else '' end ||
  ' value="grab-everything">Try to download all referenced resources (this may be very slow and inefficient)</option>\n');
http('</select>\n');
http('			  <br />\n');
  }
else
  {
declare host_ur varchar;
      host_ur := registry_get ('URIQADefaultHost');

http('			  <i>Security restrictions of this server do not allow you to retrieve remote RDF data.
DBA may wish to grant "SPARQL_SPONGE" privilege to "SPARQL" account to remove the restriction.\n');
http('In order to do this, please perform the following steps:</i>\n');
http('<br />\n');
http('1. Go to the Virtuoso Administration Conductor i.e. \n');
if (not isstring (host_ur))
  {
    http('http://host:port/conductor\n');
  }
else
  {
    http(sprintf('http://%s/conductor\n',host_ur));
  };

http('<br />\n');
http('2. Login as dba user\n');
http('<br />\n');
http('3. Go to System Admin->User Accounts->Roles\n');
http('<br />\n');
http('4. Click the link "Edit" for "SPARQL_SPONGE"\n');
http('<br />\n');
http('5. Select from the list of available user/groups "SPARQL" and click the ">>" button so to add it to the right-positioned list.\n');
http('<br />\n');
http('6. Click the button "Update"\n');
http('<br />\n');
http('7. Access again the sparql endpoint in order to be able to retrieve remote data.\n');
http('<br /><br />\n');
  }
http('			  <label for="query">Query text</label>\n');
http('			  <br />\n');
http('			  <textarea rows="10" cols="80" name="query" id="query" onchange="format_select(this)" onkeyup="format_select(this)">'|| def_qry ||'</textarea>\n');
http('			  <br /><br />\n');
--http('			  <label for="maxrows">Max Rows:</label>\n');
--http('			  <input type="text" name="maxrows" id="maxrows"\n');
--http(sprintf('				  	value="%d"/>',maxrows));
--http('			  <br />\n');
http('			  <label for="format" class="n">Display Results As:</label>\n');
http('			  <select name="format">\n');
http('			    <option value="auto">Auto</option>\n');
http('			    <option value="text/html" selected="selected">HTML</option>\n');
http('			    <option value="application/vnd.ms-excel">Spreadsheet</option>\n');
http('			    <option value="application/sparql-results+xml">XML</option>\n');
http('			    <option value="application/sparql-results+json">JSON</option>\n');
http('			    <option value="application/javascript">Javascript</option>\n');
http('			  </select>\n');
http('&nbsp;&nbsp;&nbsp;\n');
http('<input name="debug" type="checkbox"' || case (debug) when '' then '' else ' checked' end || '/>');
http('&nbsp;<label for="debug" class="n"><nobr>Rigorous check of the query</nobr></label>\n');
http('&nbsp;&nbsp;&nbsp;\n');
http('<input name="timeout" type="text"' || case (isnull (timeout)) when 0 then cast (timeout as varchar) else '' end || '/>');
http('&nbsp;<label for="timeout" class="n"><nobr>Execution timeout, in milliseconds, values less than 1000 are ignored</nobr></label>\n');
http('&nbsp;&nbsp;&nbsp;\n');
http('			  <input type="submit" value="Run Query"/>');
http('&nbsp;<input type="reset" value="Reset"/>\n');
http('			</fieldset>\n');
http('			</form>\n');
http('		</div>\n');
http('	</body>\n');
http('</html>\n');
       return;
    }
  qry_params := dict_new (7);
  for (paramctr := 0; paramctr < paramcount; paramctr := paramctr + 2)
    {
      declare pname, pvalue varchar;
      pname := params [paramctr];
      pvalue := params [paramctr+1];
      if ('query' = pname)
        query := pvalue;
      else if ('find' = pname)
	{
	  declare cls, words, ft, vec, cond varchar;
	  cls := get_keyword ('class', params);
	  maxrows := atoi (get_keyword ('maxrows', params, cast (maxrows as varchar)));
	  if (def_max > 0 and def_max < maxrows)
	    maxrows := def_max;
	  if (cls is not null)
	    cond := sprintf (' ?s a %s . ', cls);
          else
	    cond := '';
	  ft := trim (DB.DBA.FTI_MAKE_SEARCH_STRING_INNER (pvalue, words), '()');
          if (ft is null or length (words) = 0)
            {
              DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
                '400', 'Bad Request',
                query, '22023', 'The value of "find" parameter of web service endpoint is not a valid search string' );
              return;
            }
	  vec := DB.DBA.SYS_SQL_VECTOR_PRINT (words);
	  if (get_keyword ('format', params, '') like '%/rdf+%' or http_request_header (lines, 'Accept', null, '') like '%/rdf+%')
	    query := sprintf ('construct { ?s ?p `bif:search_excerpt (bif:vector (%s), sql:rdf_find_str(?o))` } ' ||
	    'where { ?s ?p ?o . %s filter (bif:contains (?o, ''%s'')) } limit %d', vec, cond, ft, maxrows);
	  else
	    query := sprintf ('select ?s ?p (bif:search_excerpt (bif:vector (%s), sql:rdf_find_str(?o))) ' ||
	    'where { ?s ?p ?o . %s filter (bif:contains (?o, ''%s'')) } limit %d', vec, cond, ft, maxrows);
	}
      else if ('default-graph-uri' = pname and length (pvalue))
        {
	  if (position (pvalue, dflt_graphs) <= 0)
	    dflt_graphs := vector_concat (dflt_graphs, vector (pvalue));
	}
      else if ('named-graph-uri' = pname and length (pvalue))
        {
	  if (position (pvalue, named_graphs) <= 0)
	    named_graphs := vector_concat (named_graphs, vector (pvalue));
	}
      else if ('maxrows' = pname)
        {
	  maxrows := cast (pvalue as integer);
	}
      else if ('should-sponge' = pname)
        {
          if (can_sponge)
            should_sponge := trim(pvalue);
	}
      else if ('format' = pname or 'output' = pname)
        {
	  format := pvalue;
	}
      else if ('timeout' = pname)
        {
          declare t integer;
          t := cast (pvalue as integer) * 1000;
          if (t is not null and t >= 1000)
            {
              if (hard_timeout >= 1000)
                timeout := __min (t, hard_timeout);
              else
                timeout := t;
            }
          client_supports_partial_res := 1;
	}
      else if ('ini' = pname)
        {
	  sp_ini := 1;
	}
      else if (query is null and 'query-uri' = pname and length (pvalue))
	{
	  if (cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'ExternalQuerySource') = '1')
	    {
	      declare uri varchar;
	      declare hf, hdr, charset any;
	      uri := pvalue;
	      if (uri like 'http://%' and uri not like 'http://localdav.virt/%' and uri not like 'http://local.virt/dav/%')
		{
		  query := http_get (uri, hdr);
		  if (hdr[0] not like '% 200%')
		    signal ('22023', concat ('HTTP request failed: ', hdr[0], 'for URI ', uri));
		  charset := http_request_header (hdr, 'Content-Type', 'charset', '');
		  if (charset <> '')
		    {
		      query := charset_recode (query, charset, 'UTF-8');
		    }
		}
	      else
		{
		  query := DB.DBA.XML_URI_GET ('', pvalue);
	        }
	    }
	  else
	    {
	       DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
		    '403', 'Prohibited', query, '22023', 'The external query sources are prohibited.');
	       return;
	    }
	}
      else if ('xslt-uri' = pname and length (pvalue))
	{
	  if (cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'ExternalXsltSource') = '1')
	    {
	      add_http_headers := 0;
	      http_xslt (pvalue);
	    }
	  else
	    {
	       DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
		    '403', 'Prohibited', query, '22023', 'The XSL-T transformation is prohibited');
	       return;
	    }
	}
      else if ('get-login' = pname)
	{
	  get_user := pvalue;
	}
      else if (pname[0] = '?'[0])
        {
          dict_put (qry_params, subseq (pname, 1), pvalue);
        }
    }
  if (format <> '')
  {
    format := (
      case lower(format)
        when 'json' then 'application/sparql-results+json'
        when 'js' then 'application/javascript'
        when 'html' then 'text/html'
        when 'sparql' then 'application/sparql-results+xml'
        when 'xml' then 'application/sparql-results+xml'
        when 'rdf' then 'application/rdf+xml'
        when 'n3' then 'text/rdf+n3'
        else format
      end);
  }

  if (def_max > 0 and def_max < maxrows)
    maxrows := def_max;

  --if (0 = length (dflt_graphs) and length (ini_dflt_graph))
  --  dflt_graphs := vector (ini_dflt_graph);


  -- SOAP 1.2 operation begins
  if (http_meth = 'POST' and soap_ver > 0)
    {
       declare xt, dgs, ngs any;
       declare soap_ns, spt_ns, ns_decl varchar;
       soap_ns := DB.DBA.SPARQL_SOAP_NS (soap_ver);
       spt_ns := DB.DBA.SPARQL_PT_NS ();
       ns_decl := '[ xmlns:soap="'||soap_ns||'" xmlns:sp="'||spt_ns||'" ] ';
       content := http_body_read ();
       if (registry_get ('__sparql_endpoint_debug') = '1')
         dbg_printf ('content=[%s]', string_output_string (content));
       xt := xtree_doc (content);
       query := charset_recode (xpath_eval (ns_decl||'string (/soap:Envelope/soap:Body/sp:query-request/query)', xt), '_WIDE_', 'UTF-8');
       dgs := xpath_eval (ns_decl||'/soap:Envelope/soap:Body/sp:query-request/default-graph-uri', xt, 0);
       ngs := xpath_eval (ns_decl||'/soap:Envelope/soap:Body/sp:query-request/named-graph-uri', xt, 0);
       foreach (any frag in dgs) do
	 {
	   declare pvalue varchar;
	   pvalue := charset_recode (xpath_eval ('string(.)', frag), '_WIDE_', 'UTF-8');
	   if (position (pvalue, dflt_graphs) <= 0)
	     dflt_graphs := vector_concat (dflt_graphs, vector (pvalue));
	 }
       foreach (any frag in ngs) do
	 {
	   declare pvalue varchar;
	   pvalue := charset_recode (xpath_eval ('string(.)', frag), '_WIDE_', 'UTF-8');
	   if (position (pvalue, named_graphs) <= 0)
	     named_graphs := vector_concat (named_graphs, vector (pvalue));
	 }
       format := sprintf('application/soap+xml;%d', soap_ver);
    }
  if (format <> '')
    accept := format;
  else
    accept := http_request_header (lines, 'Accept', null, '');
  if (sp_ini)
    {
      SPARQL_INI_PARAMS (metas, rset);
      goto write_results;
    }

  if (query is null)
    {
      if (strstr (content_type, 'application/xml') is not null)
        {
          DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
            '400', 'Bad Request',
	    query, '22023', 'XML notation of SPARQL queries is not supported' );
	  return;
	}
      DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
        '400', 'Bad Request',
        query, '22023', 'The request does not contain text of SPARQL query', format);
      return;
    }

  full_query := query;
  -- dbg_obj_princ ('dflt_graphs = ', dflt_graphs, ', named_graphs = ', named_graphs);
  declare req_hosts varchar;
  declare req_hosts_split any;
  declare hctr integer;
  req_hosts := http_request_header (lines, 'Host', null, null);
  req_hosts := replace (req_hosts, ', ', ',');
  req_hosts_split := split_and_decode (req_hosts, 0, '\0\0,');
  for (hctr := length (req_hosts_split) - 1; hctr >= 0; hctr := hctr - 1)
    {
      for (select top 1 SH_GRAPH_URI, SH_DEFINES from DB.DBA.SYS_SPARQL_HOST
      where req_hosts_split [hctr] like SH_HOST) do
        {
          if (length (dflt_graphs) = 0 and length (SH_GRAPH_URI))
            dflt_graphs := vector (SH_GRAPH_URI);
          if (SH_DEFINES is not null)
            full_query := concat (SH_DEFINES, ' ', full_query);
          goto host_found;
        }
    }
host_found:

  foreach (varchar dg in dflt_graphs) do
    {
      full_query := concat ('define input:default-graph-uri <', dg, '> ', full_query);
      http_header (sprintf ('X-SPARQL-default-graph: %U\r\n', dg));
    }
  foreach (varchar ng in named_graphs) do
    {
      full_query := concat ('define input:named-graph-uri <', ng, '> ', full_query);
      http_header (sprintf ('X-SPARQL-named-graph: %U\r\n', ng));
    }
  if ((should_sponge = 'soft') or (should_sponge = 'replacing'))
    full_query := concat (sprintf('define get:soft "%s" ',should_sponge), full_query);
  else if (should_sponge = 'grab-all')
    full_query := concat ('define input:grab-all "yes" define input:grab-depth 5 define input:grab-limit 100 ', full_query);
  else if (should_sponge = 'grab-all-seealso')
    full_query := concat ('define input:grab-all "yes" define input:grab-depth 5 define input:grab-limit 200 define input:grab-seealso <http://www.w3.org/2000/01/rdf-schema#seeAlso> define input:grab-seealso <http://xmlns.com/foaf/0.1/seeAlso> ', full_query);
  else if (should_sponge = 'grab-everything')
    full_query := concat ('define input:grab-all "yes" define input:grab-intermediate "yes" define input:grab-depth 5 define input:grab-limit 500 define input:grab-seealso <http://www.w3.org/2000/01/rdf-schema#seeAlso> define input:grab-seealso <http://xmlns.com/foaf/0.1/seeAlso> ', full_query);
--  full_query := concat ('define output:valmode "LONG" ', full_query);
  if (debug <> '')
    full_query := concat ('define sql:signal-void-variables 1 ', full_query);
  if (get_user <> '')
    full_query := concat ('define get:login "', get_user, '" ', full_query);
  if (dict_size (qry_params) > 0)
    {
      declare pnames any;
      pnames := dict_list_keys (qry_params, 0);
      foreach (varchar pname in pnames) do
        {
          full_query := concat ('define sql:param "', pname, '" ', full_query);
        }
      qry_params := DB.DBA.PARSE_SPARQL_WS_PARAMS (dict_to_vector (qry_params, 1));
    }
  else
    qry_params := vector ();
  state := '00000';
  metas := null;
  rset := null;
  if (registry_get ('__sparql_endpoint_debug') = '1')
    dbg_printf ('query=[%s]', full_query);

  declare sc_max int;
  declare sc decimal;
  sc_max := atoi (coalesce (cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'MaxQueryCostEstimationTime'), '-1'));
  if (sc_max < 0)
    sc_max := atoi (coalesce (cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'MaxExecutionTime'), '-1'));
  if (sc_max > 0)
    {
      state := '00000';
      sc := exec_score (concat ('sparql ', full_query), state, msg);
      if ((sc/1000) > sc_max)
	{
	  signal ('42000', sprintf ('The estimated execution time %d (sec) exceeds the limit of %d (sec).', sc/1000, sc_max));
	}
    }

  state := '00000';
  metas := null;
  rset := null;

  if (client_supports_partial_res) -- partial results do not work with chunked encoding
    {
    -- No need to choose accurately if there are no variants.
    -- Disabled due to empty results:
    --  if (strchr (accept, ' ') is null)
    --    {
    --      if (accept='application/sparql-results+xml')
    --        full_query := 'define output:format "HTTP+XML application/sparql-results+xml" ' || full_query;
    ----      else if (accept='application/rdf+xml')
    ----        full_query := 'define output:format "HTTP+RDF/XML application/rdf+xml" ' || full_query;
    --    }
    -- No need to choose accurately if there is the best variant.
    -- Disabled due to empty results:
    --    {
    --      declare fmtxml, fmtttl varchar;
    --      if (strstr (accept, 'application/sparql-results+xml') is not null)
    --        fmtxml := '"HTTP+XML application/sparql-results+xml" ';
    --      if (strstr (accept, 'text/rdf+n3') is not null)
    --        fmtttl := '"HTTP+TTL text/rdf+n3" ';
    --      else if (strstr (accept, 'text/rdf+ttl') is not null)
    --        fmtttl := '"HTTP+TTL text/rdf+ttl" ';
    --      else if (strstr (accept, 'application/turtle') is not null)
    --        fmtttl := '"HTTP+TTL application/turtle" ';
    --      else if (strstr (accept, 'application/x-turtle') is not null)
    --        fmtttl := '"HTTP+TTL application/x-turtle" ';
    --      if (isstring (fmtttl))
    --        {
    --          if (isstring (fmtxml))
    --            full_query := 'define output:format ' || fmtxml || 'define output:dict-format ' || fmtttl || full_query;
    --          else
    --            full_query := 'define output:format ' || fmtttl || full_query;
    --        }
    --    }
    ;
    }
  -- dbg_obj_princ ('accept = ', accept);
  -- dbg_obj_princ ('full_query = ', full_query);
  -- dbg_obj_princ ('qry_params = ', qry_params);
  commit work;
  if (client_supports_partial_res and (timeout > 0))
    {
      set RESULT_TIMEOUT = coalesce (timeout, hard_timeout);
      set TRANSACTION_TIMEOUT=timeout + 10000;
    }
  else if (hard_timeout >= 1000)
    {
      set TRANSACTION_TIMEOUT=hard_timeout;
    }
  set_user_id (user_id);
  start_time := msec_time();
  exec ( concat ('sparql ', full_query), state, msg, qry_params, vector ('max_rows', maxrows, 'use_cache', 1), metas, rset);
  commit work;
  -- dbg_obj_princ ('exec metas=', metas);
  if (state = '00000')
    goto write_results;
  if (state = 'S1TAT')
    {
      exec_time := msec_time () - start_time;
      exec_db_activity := db_activity ();
--  reply := xmlelement ("facets", xmlelement ("sparql", qr), xmlelement ("time", msec_time () - start_time),
--                       xmlelement ("complete", cplete),
--                       xmlelement ("db-activity", db_activity ()), res[0][0]);
    }
  else
    {
      declare state2, msg2 varchar;
      state2 := '00000';
      exec ('isnull (sparql_to_sql_text (?))', state2, msg2, vector (full_query));
      if (state2 <> '00000')
        {
          DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
            '400', 'Bad Request',
            full_query, state2, msg2, format);
          return;
        }
      DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
        '500', 'SPARQL Request Failed',
	full_query, state, msg, format);
      return;
    }
write_results:
  if ((1 <> length (metas[0])) or ('aggret-0' <> metas[0][0][0]))
    {
      declare status any;
      if (isinteger (msg))
        status := NULL;
      else
        status := vector (state, msg, exec_time, exec_db_activity);
      DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, accept, add_http_headers, status);
    }
}
;

registry_set ('/!sparql/', 'no_vsp_recompile')
;



-- SPARUL manipulation by remote resources.

--!AWK PUBLIC
create function DB.DBA.SPARQL_ROUTE_IF_DAV (in graph_iri varchar, in output_format_name varchar)
{
--                    0         1
--                    012345678901234567
  if (graph_iri like 'http://local.virt/DAV/%')
    return subseq (graph_iri, 17);
  return NULL;
}
;

create procedure DB.DBA.SPARQL_ROUTE_DICT_CONTENT_DAV (
  in graph_iri varchar,
  in opname varchar,
  in storage_name varchar,
  in output_storage_name varchar,
  in output_format_name varchar,
  in del_dict any,
  in ins_dict any,
  in env any,
  in uid integer,
  in log_mode integer,
  in compose_report integer )
{
  declare split, in_mime, mime, perr, fake_content varchar;
  declare final_res, triples, out_ses, rc any;
  declare old_perms, uid, pwd varchar;
  declare old_gid, old_uid any;
  declare dir any;
  split := DB.DBA.SPARQL_ROUTE_IF_DAV (graph_iri, output_format_name);
  -- uid := user;
  if ('dba' = uid)
    uid := 'dav';
  pwd := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME=uid);
  -- dbg_obj_princ ('SPARQL_ROUTE_DICT_CONTENT_DAV: uid=', uid, ', pwd=', pwd);
  if (split is not null)
    {
      dir := DAV_DIR_LIST (split, 0, uid, pwd);
      if (isinteger (dir) and (0 > dir))
        signal ('RDFXX', sprintf ('SPARUL %s can not get DAV directory info about "%.200s": %s', opname, split, DB.DBA.DAV_PERROR (dir)));
      if (1 = length (dir))
        {
          if ('c' = dir[0][1])
            signal ('RDFXX', sprintf ('SPARUL %s can not edit "%.200s": it is collection, not a resource', opname, split));
          old_perms := dir[0][5];
          old_gid := dir[0][6];
          old_uid := dir[0][7];
          in_mime := dir[0][9];
        }
      else
        signal ('RDFXX', sprintf ('SPARUL %s can not edit "%.200s": can not get directory listing with it', opname, split));
      fake_content := null;
      mime := DB.DBA.RDF_SPONGE_GUESS_CONTENT_TYPE (graph_iri, in_mime, fake_content);
      if ('application/rdf+xml' = mime)
        {
          if ((output_format_name is not null) and (output_format_name <> 'AUTO') and (output_format_name <> 'RDF/XML'))
            signal ('RDFXX', sprintf ('SPARUL can not update resource "%.200s" because its MIME type "%s" conflicts with directive output:format "%s"', graph_iri, coalesce (in_mime, mime), output_format_name));
        }
      else if ('text/rdf+n3' = mime)
        {
          if ((output_format_name is not null) and (output_format_name <> 'AUTO') and (output_format_name <> 'TURTLE') and (output_format_name <> 'TTL'))
            signal ('RDFXX', sprintf ('SPARUL can not update resource "%.200s" because its MIME type "%s" conflicts with directive output:format "%s"', graph_iri, coalesce (in_mime, mime), output_format_name));
        }
      else
        signal ('RDFXX', sprintf ('SPARUL can not update resource "%.200s" of MIME type "%s" because only "application/rdf+xml" and "text/rdf+n3" are supported', graph_iri, coalesce (in_mime, mime)));
    }
  if ('INSERT' = opname)
    final_res := DB.DBA.SPARQL_INSERT_DICT_CONTENT (graph_iri, ins_dict, uid, log_mode, compose_report);
  else if ('DELETE' = opname)
    final_res := DB.DBA.SPARQL_DELETE_DICT_CONTENT (graph_iri, del_dict, uid, log_mode, compose_report);
  else if ('MODIFY' = opname)
    final_res := DB.DBA.SPARQL_MODIFY_BY_DICT_CONTENTS (graph_iri, del_dict, ins_dict, uid, log_mode, compose_report);
  if (split is not null)
    {
      out_ses := string_output();
      triples := (select VECTOR_AGG (vector ("s", "p", "o")) from
          (sparql define input:storage "" define output:valmode "LONG"
            select ?s ?p ?o where {
                graph `iri(?:graph_iri)` { ?s ?p ?o } }
            order by (str(?s)) (str(?p)) ) as sub );
      if ('application/rdf+xml' = mime)
        DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 1, out_ses);
      else if ('text/rdf+n3' = mime)
        DB.DBA.RDF_TRIPLES_TO_TTL (triples, out_ses);
      rc := DB.DBA.DAV_RES_UPLOAD (split, out_ses, mime, old_perms, old_uid, old_gid, uid, pwd);
      if (isinteger (rc) and rc < 0)
        signal ('RDFXX', sprintf ('Unable to change "%.200s" in DAV: %s', split, DB.DBA.DAV_PERROR (rc)));
    }
  if (not isinteger (final_res))
    return final_res;
}
;

-- WS handlers for .rq files (application/sparql-query)
create procedure
WS.WS.__http_handler_rq (in content any, in params any, in lines any, inout ipath_ostat any)
{
  return DB.DBA.http_rq_file_handler(content, params, lines, ipath_ostat);
}
;

create procedure
WS.WS.__http_handler_head_rq (in content any, in params any, in lines any, inout ipath_ostat any)
{
  return DB.DBA.http_rq_file_handler(content, params, lines, ipath_ostat);
}
;

create procedure
DB.DBA.http_rq_file_handler (in content any, in params any, in lines any, inout ipath_ostat any)
{
  declare accept varchar;
  declare _format varchar;

  accept := http_request_header (lines, 'Accept', null, '');

  _format := get_keyword('format', params, '');
  if (_format <> '')
    {
      _format := (
      case lower(_format)
      when 'json' then 'application/sparql-results+json'
      when 'js' then 'application/javascript'
      when 'html' then 'text/html'
      when 'spreadsheet' then 'application/vnd.ms-excel'
      when 'sparql' then 'application/sparql-results+xml'
      when 'xml' then 'application/sparql-results+xml'
      when 'rdf' then 'application/rdf+xml'
      when 'n3' then 'text/rdf+n3'
      else _format
      end);
    }

  if (_format <> '' or
      strcasestr (accept, 'application/sparql-results+json') is not null or
      strcasestr (accept, 'application/json') is not null or
      strcasestr (accept, 'application/sparql-results+xml') is not null or
      strcasestr (accept, 'text/rdf+n3') is not null or
      strcasestr (accept, 'application/rdf+xml') is not null or
      strcasestr (accept, 'application/javascript') is not null or
      strcasestr (accept, 'application/soap+xml') is not null or
      strcasestr (accept, 'application/rdf+turtle') is not null
     )
    {
      http_request_status ('HTTP/1.1 303 See Other');
      http_header (sprintf('Location: /sparql?query=%U&format=%U\r\n', content, accept));
      return '';
    }
  if (strcasestr (accept, 'application/sparql-query') is not null)
     http_header ('Content-Type: application/sparql-query\r\n');
  else
     http_header ('Content-Type: text/plain\r\n');
  http (content);
  return '';
}
;

create procedure DB.DBA.RDF_GRANT_SPARQL_IO ()
{
  declare state, msg varchar;
  declare cmds any;
  cmds := vector (
    'grant execute on DB.DBA.SPARQL_REXEC to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_REXEC_TO_ARRAY to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_REXEC_WITH_META to SPARQL_SELECT',
    'grant execute on WS.WS."/!sparql/" to "SPARQL"',
    'grant execute on DB.DBA.SPARQL_ROUTE_DICT_CONTENT_DAV to SPARQL_UPDATE' );
  foreach (varchar cmd in cmds) do
    {
      exec (cmd, state, msg);
    }
}
;

--!AFTER __PROCEDURE__ DB.DBA.USER_CREATE !
DB.DBA.RDF_GRANT_SPARQL_IO ()
;
