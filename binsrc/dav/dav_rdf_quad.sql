--
--  $Id$
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

create procedure DB.DBA.RDF_DELETE_ENTIRE_GRAPH (in new_dav_graph varchar, in param integer)
{
  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (new_dav_graph);
}
;

create function DB.DBA.DAV_FULL_PATH_TO_IRI (in dav_iri varchar, in _str varchar) returns varchar
{
  declare _ses any;
  _ses := string_output();
  http (dav_iri, _ses);
  http_escape (subseq (_str, 4), 7, _ses, 0, 1);
  return string_output_string(_ses);
}
;

create procedure DB.DBA.DAV_AUTO_REPLICATE_TO_RDF_QUAD ()
{
  declare uriqa_default_host, old_dav_graph, new_dav_graph varchar;
  uriqa_default_host := virtuoso_ini_item_value ('URIQA','DefaultHost');
  if (isstring (registry_get ('DB.DBA.DAV_RDF_GRAPH_URI')))
    return;
  if (uriqa_default_host is null or uriqa_default_host = '')
    return;
  DB.DBA.DAV_REPLICATE_ALL_TO_RDF_QUAD (1);
}
;

create procedure DB.DBA.DAV_REPLICATE_ALL_TO_RDF_QUAD (in enable integer)
{
  declare uriqa_default_host, old_dav_graph, new_dav_graph varchar;
  declare trx_size integer;
  uriqa_default_host := virtuoso_ini_item_value ('URIQA','DefaultHost');
  if (uriqa_default_host is null or uriqa_default_host = '')
    signal ('OBLOM', 'No uriqa_default_host!');
  if (virtuoso_ini_item_value ('URIQA', 'DynamicLocal') = '1')
    new_dav_graph := 'local:/DAV/';
  else
    new_dav_graph := sprintf ('http://%s/DAV/', uriqa_default_host);
  exec ('checkpoint');
  __atomic (1);
  DB.DBA.RDF_DELETE_ENTIRE_GRAPH (new_dav_graph, 1);
  old_dav_graph := registry_get ('DB.DBA.DAV_RDF_GRAPH_URI');
  if (isstring (old_dav_graph) and old_dav_graph <> new_dav_graph and old_dav_graph <> '')
    DB.DBA.RDF_DELETE_ENTIRE_GRAPH (old_dav_graph, 1);
  if (not enable)
    {
      registry_set ('DB.DBA.DAV_RDF_GRAPH_URI', '');
      __atomic (0);
      exec ('checkpoint');
      return;
    }
  declare state, msg any;
  declare status varchar;
  state := '00000';
  result_names (status);
  state := '00000';
  exec ('create index SYS_DAV_RES_IID on WS.WS.SYS_DAV_RES (RES_IID)', state, msg, vector ());
  if (state <> '00000')
    result ('warning: index in WS.WS.SYS_DAV_RES');
  state := '00000';
  exec ('create index SYS_DAV_COL_IID on WS.WS.SYS_DAV_COL (COL_IID)', state, msg, vector ());
  if (state <> '00000')
    result ('warning: index in WS.WS.SYS_DAV_COL');
  registry_set ('DB.DBA.DAV_RDF_GRAPH_URI', new_dav_graph);
  trx_size := 0;
  for (select RES_ID, RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_PERMS[6] = 49) do
    {
      trx_size := trx_size + DB.DBA.DAV_REPLICATE_RES_TO_RDF_QUAD (RES_ID, RES_FULL_PATH);
      if (trx_size > 10000)
        {
          commit work;
          trx_size := 0;
        }
    }
  commit work;
  trx_size := 0;
  for (select COL_ID from WS.WS.SYS_DAV_COL where COL_PERMS[6] = 49) do
    {
      trx_size := trx_size + DB.DBA.DAV_REPLICATE_COL_TO_RDF_QUAD (COL_ID);
      if (trx_size > 10000)
        {
          commit work;
          trx_size := 0;
        }
    }
  commit work;
  __atomic (0);
  exec ('checkpoint');
  return;
}
;

create procedure DB.DBA.RDF_CBD_DELETE (inout triple_list any, in graph_id any, in local_dav_uri any)
{
  declare not_deleteable, candidates any;
  declare cand_ctr, cand_first_unconfirmed, cand_count integer;
  -- dbg_obj_princ ('DB.DBA.RDF_CBD_DELETE (', triple_list, graph_id, local_dav_uri, ')');
  set isolation = 'committed';
  not_deleteable := dict_new ();
  again:
  candidates := dict_new ();
  foreach (any triple in triple_list) do
    {
      declare obj any;
      obj := triple[2]; -- i.e. object of the triple
      delete from DB.DBA.RDF_QUAD where G = graph_id and S = triple[0] and P = triple[1] and equ (O, obj);
      if (isiri_id (obj) and not dict_get (not_deleteable, obj, 0))
        dict_put (candidates, obj, 1);
    }
  candidates := dict_list_keys (candidates, 1);
  gvector_sort (candidates, 1, 0, 1);
  cand_count := length (candidates);
  cand_first_unconfirmed := 0;
  for (cand_ctr := 0; cand_ctr < cand_count; cand_ctr := cand_ctr + 1)
    {
      declare obj any;
      obj := candidates [cand_ctr];
      if (not exists (select top 1 1 from DB.DBA.RDF_QUAD where G = graph_id and S = obj))
        goto non_del; -- not deleteable because there's nothing to delete. Like Elusive Joe who is so elusive because nobody wants to catch him.
      if (obj < #i1000000000) -- the object is a URI, not a blank node
        {
          declare qname varchar;
          if (exists (select top 1 1 from DB.DBA.RDF_QUAD where P = obj))
            goto non_del; -- the object appears as predicate in any graph
          if (exists (select top 1 1 from DB.DBA.RDF_DATATYPE where RDT_IID = obj))
            goto non_del; -- the object is a datatype listed in DB.DBA.RDF_DATATYPE
          qname := id_to_iri (obj);
--          qname := (select RU_QNAME from DB.DBA.RDF_URL where RU_IID = obj);
          if (qname is null)
            goto non_del; -- this is possible in case of database corruption; we can't fix it here and we should not interrupt the DAV operation. Show must go on.
          if (qname >= local_dav_uri and qname < concat (local_dav_uri, '\377\377\377\377'))
            goto non_del; -- the object URI starts with local DAV URI
        }

-- if we're here then the candidate object is 'confirmed' as a good candidate
      candidates [cand_first_unconfirmed] := obj;
      cand_first_unconfirmed := cand_first_unconfirmed + 1;
      goto next_cand;

non_del:
      dict_put (not_deleteable, obj, 1);

next_cand: ;
    }

  if (0 = cand_first_unconfirmed) -- no real candidate on future deletion, we've done.
    return;

  vectorbld_init (triple_list);
  for (cand_ctr := 0; cand_ctr < cand_first_unconfirmed; cand_ctr := cand_ctr + 1)
    {
      declare obj any;
      obj := candidates [cand_ctr];
      if (not exists (select top 1 1 from DB.DBA.RDF_QUAD
          where G = graph_id and O = obj option (quietcast) ) )
        {
          for (select P,O from DB.DBA.RDF_QUAD where G = graph_id and S = obj) do
          vectorbld_acc (triple_list, vector (obj,P,O));
    }
    }
  vectorbld_final (triple_list);
  if (0 <> length (triple_list))
    goto again; -- Do the next level of recursion of CBD-delete
}
;

create procedure DB.DBA.DAV_RDF_URI_RESOLVE (in dav_rdf_graph_uri varchar, in iri any, in fullpath varchar, in res_type varchar) returns varchar
{
  declare abs_uri varchar;
  if (iri = 'http://local.virt/this')
    abs_uri := DB.DBA.DAV_FULL_PATH_TO_IRI (dav_rdf_graph_uri, fullpath);
--                           0         1         2
--                           01234567890123456789012
  else if (left (iri, 22) = 'http://local.virt/DAV/')
    {
--      declare uriqa_default_host, old_dav_graph, new_dav_graph varchar;
--      uriqa_default_host := virtuoso_ini_item_value ('URIQA', 'DefaultHost');
--      if (uriqa_default_host is null or uriqa_default_host = '')
--        signal ('OBLOM', 'No uriqa_default_host!');
--      new_dav_graph := sprintf ('http://%s/DAV/', uriqa_default_host);
      abs_uri := dav_rdf_graph_uri || subseq (iri, 22);
    }
  else
    {
      declare base_uri varchar;
      base_uri := DB.DBA.DAV_FULL_PATH_TO_IRI (dav_rdf_graph_uri, fullpath);
      abs_uri := DB.DBA.XML_URI_RESOLVE_LIKE_GET (base_uri, iri);
    }
  return abs_uri;
}
;

create procedure DB.DBA.DAV_RDF_REPLICATE_INT (in res_id integer, in restype varchar, in fullpath varchar)
{
  declare n3v, n3_list, dav_rdf_graph_iid any;
  declare dav_rdf_graph_uri varchar;
  dav_rdf_graph_uri := registry_get ('DB.DBA.DAV_RDF_GRAPH_URI');
  if (not isstring (dav_rdf_graph_uri) or dav_rdf_graph_uri = '')
    return;
  dav_rdf_graph_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (dav_rdf_graph_uri);
  whenever not found goto no_op;
  select xml_tree_doc (deserialize (blob_to_string (PROP_VALUE)))
    into n3v
    from WS.WS.SYS_DAV_PROP
    where PROP_NAME = 'http://local.virt/DAV-RDF' and PROP_TYPE = 'R' and PROP_PARENT_ID = res_id;
  n3v := xslt ('http://local.virt/davxml2n3xml', n3v);
  n3_list := xpath_eval ('/N3', n3v, 0);
  foreach (any n3 in n3_list) do
    {
      declare s, p, o, dt, lang, v varchar;
      s := xpath_eval ('@N3S', n3);
      p := xpath_eval ('@N3P', n3);
      o := xpath_eval ('@N3O', n3);
      s := DB.DBA.DAV_RDF_URI_RESOLVE (dav_rdf_graph_uri, s, fullpath, restype);
      if (o is not null)
        o := DB.DBA.DAV_RDF_URI_RESOLVE (dav_rdf_graph_uri, o, fullpath, restype);
      dt := xpath_eval ('@N3DT', n3);
      lang := xpath_eval ('@xml:lang', n3);
      v := coalesce (xquery_eval ('if (exists(*)) then * else string ()', n3), '');
      if (isarray(v))
        v := v[0];
--      dbg_obj_princ ('add quad:', s, p, o, v, dt, lang);
      if (o is not null)
        DB.DBA.RDF_QUAD_URI (dav_rdf_graph_uri, s, p, o);
      else
        DB.DBA.RDF_QUAD_URI_L_TYPED (dav_rdf_graph_uri, s, p, v, dt, lang);
--      dbg_obj_princ ('added quad:', s, p, o, v, dt, lang);
    }
  no_op:;
}
;

create procedure DB.DBA.DAV_RDF_CBD_DELETE_PROP (in n3v any, in fullpath varchar, in restype varchar, in dav_rdf_graph_iid IRI_ID, in dav_rdf_graph_uri varchar)
{
  declare n3_list, triple_list any;
  -- dbg_obj_princ ('DB.DBA.DAV_RDF_CBD_DELETE_PROP (', n3v, fullpath, restype, dav_rdf_graph_iid, dav_rdf_graph_uri,')');
  n3v := xslt ('http://local.virt/davxml2n3xml', n3v);
  n3_list := xpath_eval ('/N3', n3v, 0);
  vectorbld_init (triple_list);
  foreach (any n3 in n3_list) do
    {
      declare lang, v, app_env varchar;
      declare s, p, o, dt any;
      s := xpath_eval ('@N3S', n3);
      p := xpath_eval ('@N3P', n3);
      o := xpath_eval ('@N3O', n3);
      s := DB.DBA.DAV_RDF_URI_RESOLVE (dav_rdf_graph_uri, s, fullpath, restype);
      if (o is not null)
        o := DB.DBA.DAV_RDF_URI_RESOLVE (dav_rdf_graph_uri, o, fullpath, restype);
      dt := xpath_eval ('@N3DT', n3);
      lang := xpath_eval ('@xml:lang', n3);
      v := coalesce (xquery_eval ('if (exists(*)) then * else string ()', n3), '');
      if (isarray(v))
        v := v[0];
      -- dbg_obj_princ ('will remove quad:', s, p, o, v, dt, lang);
      s := DB.DBA.RDF_MAKE_IID_OF_QNAME (s);
      p := DB.DBA.RDF_MAKE_IID_OF_QNAME (p);
      if (o is not null)
        o := DB.DBA.RDF_MAKE_IID_OF_QNAME (o);
      else
        {
          if (dt is not null)
            dt := DB.DBA.RDF_MAKE_IID_OF_QNAME (dt);
          o := DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (v, dt, lang);
        }
      vectorbld_acc (triple_list, vector (s, p, o));
    }
  vectorbld_final (triple_list);
  DB.DBA.RDF_CBD_DELETE (triple_list, dav_rdf_graph_iid, dav_rdf_graph_uri);
}
;

create function DB.DBA.DAV_MAKE_USER_IRI (in userid integer)
{
  declare email varchar;
  email := (select U_E_MAIL from DB.DBA.SYS_USERS where U_ID = userid);
  if (email is null or email='')
    {
      declare uriqa_default_host varchar;
      uriqa_default_host := virtuoso_ini_item_value ('URIQA','DefaultHost');
      if (not isstring (uriqa_default_host))
        signal ('22023', 'Function DB.DBA.DAV_MAKE_USER_IRI() has failed to get "DefaultHost" parameter of [URIQA] section of Virtuoso configuration file');
      email := sprintf ('mailto:UserId%d@%s', userid, uriqa_default_host);
    }
  else
    {
      if (left (email, 7) <> 'mailto:')
        email := concat ('mailto:', email);
    }
  return email;
}
;

create procedure DB.DBA.DAV_REPLICATE_RES_TO_RDF_QUAD (in res_id2 integer, in fullpath varchar)
{
  declare dav_rdf_graph_uri, new_uri, tags, email varchar;
  declare new_iid any;
  dav_rdf_graph_uri := registry_get ('DB.DBA.DAV_RDF_GRAPH_URI');
  if (not isstring (dav_rdf_graph_uri) or dav_rdf_graph_uri = '')
    return;
  DB.DBA.DAV_RDF_REPLICATE_INT (res_id2, 'R', fullpath);
  new_uri := DB.DBA.DAV_FULL_PATH_TO_IRI (dav_rdf_graph_uri, fullpath);
  new_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (new_uri);
  declare cr_time, mod_time datetime;
  declare len, owner integer;
  select RES_CR_TIME, RES_MOD_TIME, length (RES_CONTENT), RES_OWNER into cr_time, mod_time, len, owner from WS.WS.SYS_DAV_RES where RES_ID = res_id2;
  email := DB.DBA.DAV_MAKE_USER_IRI (owner);
  tags := coalesce ((select DT_TAGS from WS.WS.SYS_DAV_TAG where DT_RES_ID = res_id2 and DT_U_ID = http_nobody_uid()));
  DB.DBA.RDF_QUAD_URI_L (dav_rdf_graph_uri, new_uri, 'http://purl.org/dc/terms/created', cr_time);
  DB.DBA.RDF_QUAD_URI_L (dav_rdf_graph_uri, new_uri, 'http://purl.org/dc/terms/modified', mod_time);
  DB.DBA.RDF_QUAD_URI_L (dav_rdf_graph_uri, new_uri, 'http://purl.org/dc/terms/extent', len);
  DB.DBA.RDF_QUAD_URI (dav_rdf_graph_uri, new_uri, 'http://www.openlinksw.com/schemas/DAV#ownerUser', email);
  if (tags is not null)
    {
      declare tag_list any;
      tag_list := split_and_decode (tags, 0, '\0\0,');
      foreach (varchar tag in tag_list) do
        DB.DBA.RDF_QUAD_URI_L (dav_rdf_graph_uri, new_uri, 'http://www.openlinksw.com/schemas/DAV#tag', tag);
    }
  set triggers off;
  update WS.WS.SYS_DAV_RES set RES_IID=new_iid where RES_ID = res_id2;
  set triggers on;
}
;

create procedure DB.DBA.DAV_REPLICATE_COL_TO_RDF_QUAD (in col_id2 integer)
{
  declare dav_rdf_graph_uri, fullpath, new_uri varchar;
  declare new_iid any;
  fullpath := DAV_SEARCH_PATH (col_id2, 'C');
  if (DAV_HIDE_ERROR (fullpath) is null)
    return;
  DB.DBA.DAV_RDF_REPLICATE_INT (col_id2, 'C', fullpath);
  dav_rdf_graph_uri := registry_get ('DB.DBA.DAV_RDF_GRAPH_URI');
  if (not isstring (dav_rdf_graph_uri) or dav_rdf_graph_uri = '')
    return;
  new_uri := DB.DBA.DAV_FULL_PATH_TO_IRI (dav_rdf_graph_uri, fullpath);
  new_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (new_uri);
  declare cr_time, mod_time datetime;
  declare owner integer;
  declare email varchar;
  select COL_CR_TIME, COL_MOD_TIME, COL_OWNER into cr_time, mod_time, owner from WS.WS.SYS_DAV_COL where COL_ID = col_id2;
  email := DB.DBA.DAV_MAKE_USER_IRI (owner);
  DB.DBA.RDF_QUAD_URI_L (dav_rdf_graph_uri, new_uri, 'http://purl.org/dc/terms/created', cr_time);
  DB.DBA.RDF_QUAD_URI_L (dav_rdf_graph_uri, new_uri, 'http://purl.org/dc/terms/modified', mod_time);
--  DB.DBA.RDF_QUAD_URI_L (dav_rdf_graph_uri, new_uri, 'http://purl.org/dc/terms/extent', 0);
  DB.DBA.RDF_QUAD_URI (dav_rdf_graph_uri, new_uri, 'http://www.openlinksw.com/schemas/DAV#ownerUser', email);
  set triggers off;
  update WS.WS.SYS_DAV_COL set COL_IID=new_iid where COL_ID = col_id2;
  set triggers on;
}
;

create trigger SYS_DAV_PROP_AFTER_INSERT_PROP after insert on WS.WS.SYS_DAV_PROP referencing new as N
{
  declare perms varchar;
  if (N.PROP_NAME = 'http://local.virt/DAV-RDF')
    {
      whenever not found goto no_op;
      if (N.PROP_TYPE = 'R')
        {
          declare fullpath varchar;
          select RES_FULL_PATH, RES_PERMS into fullpath, perms from WS.WS.SYS_DAV_RES where RES_ID = N.PROP_PARENT_ID;
          if (perms[6] = 49)
            DB.DBA.DAV_REPLICATE_RES_TO_RDF_QUAD (N.PROP_PARENT_ID, fullpath);
        }
      else if (N.PROP_TYPE = 'C')
        {
          select COL_PERMS into perms from WS.WS.SYS_DAV_COL where COL_ID = N.PROP_PARENT_ID;
          if (perms[6] = 49)
            DB.DBA.DAV_REPLICATE_COL_TO_RDF_QUAD (N.PROP_PARENT_ID);
        }
    }
  no_op: ;
}
;

create trigger SYS_DAV_PROP_RDF_QUAD_BEFORE_DELETE before delete on WS.WS.SYS_DAV_PROP referencing old as O
{
  declare fullpath, perms varchar;
  declare colid integer;
  if (O.PROP_TYPE = 'C')
    select COL_ID, COL_PERMS into colid, perms from WS.WS.SYS_DAV_COL where COL_ID = O.PROP_PARENT_ID;
  else if (O.PROP_TYPE = 'R')
    select RES_PERMS, RES_FULL_PATH into perms, fullpath from WS.WS.SYS_DAV_RES where RES_ID = O.PROP_PARENT_ID;
  if (O.PROP_NAME = 'http://local.virt/DAV-RDF')
    {
      declare n3_tmp_list, res_vec, dav_rdf_graph_iid any;
      declare dav_rdf_graph_uri varchar;
      dav_rdf_graph_uri := registry_get ('DB.DBA.DAV_RDF_GRAPH_URI');
      if (not isstring (dav_rdf_graph_uri) or  dav_rdf_graph_uri = '')
        return;
      dav_rdf_graph_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (dav_rdf_graph_uri);
      n3_tmp_list := xml_tree_doc (deserialize (blob_to_string (O.PROP_VALUE)));
      DB.DBA.DAV_RDF_CBD_DELETE_PROP (n3_tmp_list, fullpath, O.PROP_TYPE, dav_rdf_graph_iid, dav_rdf_graph_uri);
    }
}
;

create trigger SYS_DAV_PROP_RDF_QUAD_AFTER_UPDATE after update on WS.WS.SYS_DAV_PROP referencing new as N, old as O
{
  declare fullpath, perms varchar;
  declare colid integer;
  if ((O.PROP_NAME <> 'http://local.virt/DAV-RDF') and (N.PROP_NAME <> 'http://local.virt/DAV-RDF'))
    return;
  if ((O.PROP_NAME = N.PROP_NAME) and (blob_to_string (O.PROP_VALUE) = blob_to_string (N.PROP_VALUE)))
    return;
  if (N.PROP_TYPE = 'C')
    select COL_ID, COL_PERMS into colid, perms from WS.WS.SYS_DAV_COL where COL_ID = O.PROP_PARENT_ID;
  if (N.PROP_TYPE = 'R')
    select RES_PERMS, RES_FULL_PATH into perms, fullpath from WS.WS.SYS_DAV_RES where RES_ID = O.PROP_PARENT_ID;
  if (perms[6] = 49)
    {
      if (N.PROP_TYPE = 'C')
        fullpath := DAV_SEARCH_PATH (colid, 'C');
      if (O.PROP_NAME = 'http://local.virt/DAV-RDF')
        {
          declare n3_list, res_vec, dav_rdf_graph_iid any;
          declare dav_rdf_graph_uri varchar;
          dav_rdf_graph_uri := registry_get ('DB.DBA.DAV_RDF_GRAPH_URI');
          if (not isstring (dav_rdf_graph_uri) or  dav_rdf_graph_uri = '')
            return;
          dav_rdf_graph_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (dav_rdf_graph_uri);
          n3_list := xml_tree_doc (deserialize (blob_to_string (O.PROP_VALUE)));
          DB.DBA.DAV_RDF_CBD_DELETE_PROP (n3_list, fullpath, O.PROP_TYPE, dav_rdf_graph_iid, dav_rdf_graph_uri);
	}
      if (N.PROP_NAME = 'http://local.virt/DAV-RDF')
        {
          if (N.PROP_TYPE = 'R')
            {
              if (fullpath is not null)
                DB.DBA.DAV_REPLICATE_RES_TO_RDF_QUAD (N.PROP_PARENT_ID, fullpath);
            }
          if (N.PROP_TYPE = 'C')
            DB.DBA.DAV_REPLICATE_COL_TO_RDF_QUAD (N.PROP_PARENT_ID);
        }
    }
}
;


create trigger SYS_DAV_TAG_RDF_QUAD_AFTER_INSERT after insert on WS.WS.SYS_DAV_TAG referencing new as NT
{
  declare tag_list any;
  declare fullpath, dav_rdf_graph_uri, new_uri varchar;
  if (NT.DT_U_ID <> http_nobody_uid())
    return;
  dav_rdf_graph_uri := registry_get ('DB.DBA.DAV_RDF_GRAPH_URI');
  if (not isstring (dav_rdf_graph_uri) or  dav_rdf_graph_uri = '')
    return;
  whenever not found goto nf;
  select RES_FULL_PATH into fullpath from WS.WS.SYS_DAV_RES where RES_ID = NT.DT_RES_ID and RES_PERMS[6] = 49;
  new_uri := DB.DBA.DAV_FULL_PATH_TO_IRI (dav_rdf_graph_uri, fullpath);
  tag_list := split_and_decode (NT.DT_TAGS, 0, '\0\0,');
  foreach (varchar tag in tag_list) do
    DB.DBA.RDF_QUAD_URI_L (dav_rdf_graph_uri, new_uri, 'http://www.openlinksw.com/schemas/DAV#tag', tag);
  nf: ;
}
;


create trigger SYS_DAV_TAG_RDF_QUAD_AFTER_UPDATE after update on WS.WS.SYS_DAV_TAG referencing new as NT
{
  declare tag_list, dav_rdf_graph_iid, new_iid, p_iid any;
  declare fullpath, dav_rdf_graph_uri, new_uri varchar;
  if (NT.DT_U_ID <> http_nobody_uid())
    return;
  dav_rdf_graph_uri := registry_get ('DB.DBA.DAV_RDF_GRAPH_URI');
  if (not isstring (dav_rdf_graph_uri) or  dav_rdf_graph_uri = '')
    return;
  dav_rdf_graph_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (dav_rdf_graph_uri);
  whenever not found goto nf;
  select RES_FULL_PATH into fullpath from WS.WS.SYS_DAV_RES where RES_ID = NT.DT_RES_ID and RES_PERMS[6] = 49;
  new_uri := DB.DBA.DAV_FULL_PATH_TO_IRI (dav_rdf_graph_uri, fullpath);
  new_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (new_uri);
  p_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME ('http://www.openlinksw.com/schemas/DAV#tag');
  delete from DB.DBA.RDF_QUAD where P = p_iid and G = dav_rdf_graph_iid and S = new_iid;
  tag_list := split_and_decode (NT.DT_TAGS, 0, '\0\0,');
  foreach (varchar tag in tag_list) do
    DB.DBA.RDF_QUAD_URI_L (dav_rdf_graph_uri, new_uri, 'http://www.openlinksw.com/schemas/DAV#tag', tag);
  nf: ;
}
;


create trigger SYS_DAV_TAG_RDF_QUAD_BEFORE_DELETE before delete on WS.WS.SYS_DAV_TAG referencing old as OT
{
  declare tag_list, dav_rdf_graph_iid, old_iid, p_iid any;
  declare dav_rdf_graph_uri varchar;
  if (OT.DT_U_ID <> http_nobody_uid())
    return;
  dav_rdf_graph_uri := registry_get ('DB.DBA.DAV_RDF_GRAPH_URI');
  if (not isstring (dav_rdf_graph_uri) or  dav_rdf_graph_uri = '')
    return;
  dav_rdf_graph_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (dav_rdf_graph_uri);
  whenever not found goto nf;
  select RES_IID into old_iid from WS.WS.SYS_DAV_RES where RES_ID = OT.DT_RES_ID and RES_IID is not null;
  p_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME ('http://www.openlinksw.com/schemas/DAV#tag');
  delete from DB.DBA.RDF_QUAD where P = p_iid and G = dav_rdf_graph_iid and S = old_iid;
  nf: ;
}
;


create trigger SYS_DAV_RES_RDF_QUAD_AFTER_INSERT after insert on WS.WS.SYS_DAV_RES order 30 referencing new as N
{
  if (N.RES_PERMS[6] = 49)
    DB.DBA.DAV_REPLICATE_RES_TO_RDF_QUAD (N.RES_ID, N.RES_FULL_PATH);
}
;

create trigger SYS_DAV_RES_RDF_QUAD_AFTER_UPDATE after update (RES_COL, RES_NAME, RES_FULL_PATH, RES_PERMS, RES_OWNER, RES_CONTENT, RES_CR_TIME, RES_MOD_TIME) on WS.WS.SYS_DAV_RES order 30 referencing new as NC, old as OC
{
  declare new_iid, dav_rdf_graph_iid, p_iid any;
  declare new_uri, dav_rdf_graph_uri varchar;
  -- dbg_obj_princ ('trigger SYS_DAV_RES_RDF_QUAD_AFTER_UPDATE: old:', OC.RES_COL, OC.RES_NAME, OC.RES_FULL_PATH, OC.RES_IID);
  -- dbg_obj_princ ('trigger SYS_DAV_RES_RDF_QUAD_AFTER_UPDATE: new:', NC.RES_COL, NC.RES_NAME, NC.RES_FULL_PATH, NC.RES_IID);
  if (OC.RES_PERMS[6] = 49 or NC.RES_PERMS[6] = 49)
    {
      dav_rdf_graph_uri := registry_get ('DB.DBA.DAV_RDF_GRAPH_URI');
      if (not isstring (dav_rdf_graph_uri) or dav_rdf_graph_uri = '')
        return;
      dav_rdf_graph_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (dav_rdf_graph_uri);
    }
  else
    return;
  if (NC.RES_PERMS[6] = 49)
    {
      new_uri := DB.DBA.DAV_FULL_PATH_TO_IRI (dav_rdf_graph_uri, NC.RES_FULL_PATH);
      new_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (new_uri);
    }
  else
    new_uri := new_iid := null;
  if (OC.RES_IID is null)
    {
      DB.DBA.DAV_REPLICATE_RES_TO_RDF_QUAD (NC.RES_ID, NC.RES_FULL_PATH);
      return;
    }
  if (new_iid is null)
    {
      declare spo any;
      select VECTOR_AGG (vector (S, P, O)) into spo from DB.DBA.RDF_QUAD where G=dav_rdf_graph_iid and S=OC.RES_IID;
      RDF_CBD_DELETE (spo, dav_rdf_graph_iid, dav_rdf_graph_uri);
      set triggers off;
      update WS.WS.SYS_DAV_RES set RES_IID=null where RES_ID=NC.RES_ID;
      set triggers on;
      return;
    }
  if (OC.RES_IID <> new_iid)
    {
      delete from DB.DBA.RDF_QUAD where G=dav_rdf_graph_iid and ((isiri_id (O) and O=new_iid) or S=new_iid);
      update DB.DBA.RDF_QUAD set S=new_iid where G=dav_rdf_graph_iid and S=OC.RES_IID;
      update DB.DBA.RDF_QUAD set O=new_iid where G=dav_rdf_graph_iid and isiri_id (O) and O=OC.RES_IID;
      set triggers off;
      update WS.WS.SYS_DAV_RES set RES_IID=new_iid where RES_ID=NC.RES_ID;
      set triggers on;
    }
  if (OC.RES_OWNER <> NC.RES_OWNER)
    {
      declare email varchar;
      email := DB.DBA.DAV_MAKE_USER_IRI (NC.RES_OWNER);
      p_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME ('http://www.openlinksw.com/schemas/DAV#ownerUser');
      delete from DB.DBA.RDF_QUAD where P = p_iid and G = dav_rdf_graph_iid and S = new_iid;
      DB.DBA.RDF_QUAD_URI (dav_rdf_graph_uri, new_uri, 'http://www.openlinksw.com/schemas/DAV#ownerUser', email);
    }
  if (length (OC.RES_CONTENT) <> length (NC.RES_CONTENT))
    {
      p_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME ('http://purl.org/dc/terms/extent');
      delete from DB.DBA.RDF_QUAD where P = p_iid and G = dav_rdf_graph_iid and S = new_iid;
      DB.DBA.RDF_QUAD_URI_L (dav_rdf_graph_uri, new_uri, 'http://purl.org/dc/terms/extent', length (NC.RES_CONTENT));
    }
  if (OC.RES_CR_TIME <> NC.RES_CR_TIME)
    {
      p_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME ('http://purl.org/dc/terms/created');
      delete from DB.DBA.RDF_QUAD where P = p_iid and G = dav_rdf_graph_iid and S = new_iid;
      DB.DBA.RDF_QUAD_URI_L (dav_rdf_graph_uri, new_uri, 'http://purl.org/dc/terms/created', NC.RES_CR_TIME);
    }
  if (OC.RES_MOD_TIME <> NC.RES_MOD_TIME)
    {
      p_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME ('http://purl.org/dc/terms/modified');
      delete from DB.DBA.RDF_QUAD where P = p_iid and G = dav_rdf_graph_iid and S = new_iid;
      DB.DBA.RDF_QUAD_URI_L (dav_rdf_graph_uri, new_uri, 'http://purl.org/dc/terms/modified', NC.RES_MOD_TIME);
    }
}
;


create trigger SYS_DAV_RES_RDF_QUAD_BEFORE_DELETE before delete on WS.WS.SYS_DAV_RES order 30 referencing old as OC
{
  declare spo, dav_rdf_graph_uri, dav_rdf_graph_iid any;
  if (OC.RES_IID is not null)
    {
      dav_rdf_graph_uri := registry_get ('DB.DBA.DAV_RDF_GRAPH_URI');
      if (not isstring (dav_rdf_graph_uri) or  dav_rdf_graph_uri = '')
        return;
      dav_rdf_graph_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (dav_rdf_graph_uri);
      select VECTOR_AGG (vector (S, P, O)) into spo from DB.DBA.RDF_QUAD where G=dav_rdf_graph_iid and S=OC.RES_IID;
      RDF_CBD_DELETE (spo, dav_rdf_graph_iid, dav_rdf_graph_uri);
    }
}
;


create trigger SYS_DAV_COL_RDF_QUAD_AFTER_CREATE after insert on WS.WS.SYS_DAV_COL order 30 referencing new as NC
{
  if (NC.COL_PERMS[6] = 49)
    DB.DBA.DAV_REPLICATE_COL_TO_RDF_QUAD (NC.COL_ID);
}
;


create procedure DB.DBA.DAV_RDF_PROPAGATE_COL_PATH_CHANGE (
  in dav_rdf_graph_uri varchar, in dav_rdf_graph_iid IRI_ID,
  in colid integer, in colispublic integer,
  in coluri varchar, in coliid IRI_ID, in old_coliid IRI_ID )
{
  if (colispublic)
    {
      delete from DB.DBA.RDF_QUAD where G=dav_rdf_graph_iid and ((isiri_id (O) and O=coliid) or S=coliid);
      update DB.DBA.RDF_QUAD set S=coliid where G=dav_rdf_graph_iid and S=old_coliid;
      update DB.DBA.RDF_QUAD set O=coliid where G=dav_rdf_graph_iid and isiri_id (O) and O=old_coliid;
      set triggers off;
      update WS.WS.SYS_DAV_COL set COL_IID=coliid where COL_ID=colid;
      set triggers on;
    }
  for (select sub.COL_ID as subid, sub.COL_NAME as subname, sub.COL_PERMS as subperms, sub.COL_IID as old_subiid
    from WS.WS.SYS_DAV_COL as sub where sub.COL_PARENT = colid ) do
    {
      declare subispublic integer;
      declare suburi_ses, subiid any;
      suburi_ses := string_output ();
      http (coluri, suburi_ses);
      http_escape (subname, 7, suburi_ses, 0, 1);
      http ('/', suburi_ses);
      suburi_ses := string_output_string (suburi_ses);
      if (subperms[6] = 49)
        {
          subispublic := 1;
          subiid := DB.DBA.RDF_MAKE_IID_OF_QNAME (suburi_ses);
        }
      else
        {
          subispublic := 0;
          subiid := NULL;
        }
      DB.DBA.DAV_RDF_PROPAGATE_COL_PATH_CHANGE (
        dav_rdf_graph_uri, dav_rdf_graph_iid,
        subid, subispublic,
        suburi_ses, subiid, old_subiid );
    }
  for (select res.RES_ID as resid, res.RES_IID as old_resiid, res.RES_FULL_PATH as resfullpath
    from WS.WS.SYS_DAV_RES as res where res.RES_COL = colid and res.RES_IID is not null) do
    {
      declare new_uri varchar;
      declare new_iid IRI_ID;
      new_uri := DB.DBA.DAV_FULL_PATH_TO_IRI (dav_rdf_graph_uri, resfullpath);
      new_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (new_uri);
      if (old_resiid <> new_iid)
        {
          delete from DB.DBA.RDF_QUAD where G=dav_rdf_graph_iid and ((isiri_id (O) and O=new_iid) or S=new_iid);
          update DB.DBA.RDF_QUAD set S=new_iid where G=dav_rdf_graph_iid and S=old_resiid;
          update DB.DBA.RDF_QUAD set O=new_iid where G=dav_rdf_graph_iid and isiri_id (O) and O=old_resiid;
          set triggers off;
          update WS.WS.SYS_DAV_RES set RES_IID=new_iid where RES_ID=resid;
          set triggers on;
        }
    }
}
;


create trigger SYS_DAV_COL_RDF_QUAD_AFTER_UPDATE after update (COL_NAME, COL_PARENT, COL_PERMS, COL_OWNER, COL_CR_TIME, COL_MOD_TIME) on WS.WS.SYS_DAV_COL order 30 referencing new as NC, old as OC
{
  declare new_iid, dav_rdf_graph_iid, p_iid any;
  declare new_uri, dav_rdf_graph_uri varchar;
  declare path_change integer;
  if ((OC.COL_NAME <> NC.COL_NAME) or (OC.COL_PARENT <> NC.COL_PARENT))
    path_change := 1;
  else
    path_change := 0;
  if (OC.COL_PERMS[6] = 49 or NC.COL_PERMS[6] = 49 or path_change)
    {
      dav_rdf_graph_uri := registry_get ('DB.DBA.DAV_RDF_GRAPH_URI');
      if (not isstring (dav_rdf_graph_uri) or  dav_rdf_graph_uri = '')
        return;
      dav_rdf_graph_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (dav_rdf_graph_uri);
    }
  else
    return;
  if (NC.COL_PERMS[6] = 49 or path_change)
    {
      declare new_full_path varchar;
      new_full_path := DAV_SEARCH_PATH (NC.COL_ID, 'C');
      new_uri := DB.DBA.DAV_FULL_PATH_TO_IRI (dav_rdf_graph_uri, new_full_path);
      if (NC.COL_PERMS[6] = 49)
        new_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (new_uri);
      else
        new_iid := null;
    }
  else
    new_uri := new_iid := null;
  if (OC.COL_IID is null)
    {
      DB.DBA.DAV_REPLICATE_COL_TO_RDF_QUAD (NC.COL_ID);
      if (path_change)
        DB.DBA.DAV_RDF_PROPAGATE_COL_PATH_CHANGE (dav_rdf_graph_uri, dav_rdf_graph_iid, NC.COL_ID, 0, new_uri, new_iid, null);
      return;
    }
  if (new_iid is null)
    {
      declare spo any;
      select VECTOR_AGG (vector (S, P, O)) into spo from DB.DBA.RDF_QUAD where G=dav_rdf_graph_iid and S=OC.COL_IID;
      RDF_CBD_DELETE (spo, dav_rdf_graph_iid, dav_rdf_graph_uri);
      set triggers off;
      update WS.WS.SYS_DAV_COL set COL_IID=null where COL_ID=OC.COL_ID;
      set triggers on;
      if (path_change)
        DB.DBA.DAV_RDF_PROPAGATE_COL_PATH_CHANGE (dav_rdf_graph_uri, dav_rdf_graph_iid, NC.COL_ID, 0, new_uri, new_iid, null);
      return;
    }
  if (path_change)
    DB.DBA.DAV_RDF_PROPAGATE_COL_PATH_CHANGE (dav_rdf_graph_uri, dav_rdf_graph_iid, NC.COL_ID, 1, new_uri, new_iid, OC.COL_IID);
  if (OC.COL_OWNER <> NC.COL_OWNER)
    {
      declare email varchar;
      email := DB.DBA.DAV_MAKE_USER_IRI (NC.COL_OWNER);
      p_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME ('http://www.openlinksw.com/schemas/DAV#ownerUser');
      delete from DB.DBA.RDF_QUAD where P = p_iid and G = dav_rdf_graph_iid and S = new_iid;
      DB.DBA.RDF_QUAD_URI (dav_rdf_graph_uri, new_uri, 'http://www.openlinksw.com/schemas/DAV#ownerUser', email);
    }
  if (OC.COL_CR_TIME <> NC.COL_CR_TIME)
    {
      p_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME ('http://purl.org/dc/terms/created');
      delete from DB.DBA.RDF_QUAD where P = p_iid and G = dav_rdf_graph_iid and S = new_iid;
      DB.DBA.RDF_QUAD_URI_L (dav_rdf_graph_uri, new_uri, 'http://purl.org/dc/terms/created', NC.COL_CR_TIME);
    }
  if (OC.COL_MOD_TIME <> NC.COL_MOD_TIME)
    {
      p_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME ('http://purl.org/dc/terms/modified');
      delete from DB.DBA.RDF_QUAD where P = p_iid and G = dav_rdf_graph_iid and S = new_iid;
      DB.DBA.RDF_QUAD_URI_L (dav_rdf_graph_uri, new_uri, 'http://purl.org/dc/terms/modified', NC.COL_MOD_TIME);
    }
}
;


create trigger SYS_DAV_COL_RDF_QUAD_BEFORE_DELETE before delete on WS.WS.SYS_DAV_COL order 30 referencing old as OC
{
  declare spo, dav_rdf_graph_uri, dav_rdf_graph_iid any;
  if (OC.COL_PERMS[6] = 49)
    {
      dav_rdf_graph_uri := registry_get ('DB.DBA.DAV_RDF_GRAPH_URI');
      if (not isstring (dav_rdf_graph_uri) or  dav_rdf_graph_uri = '')
        return;
      dav_rdf_graph_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (dav_rdf_graph_uri);
      select VECTOR_AGG (vector (S, P, O)) into spo from DB.DBA.RDF_QUAD where G=dav_rdf_graph_iid and S=OC.COL_IID;
      RDF_CBD_DELETE (spo, dav_rdf_graph_iid, dav_rdf_graph_uri);
    }
}
;
