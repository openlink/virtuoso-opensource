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

create table WS.WS.URIQA_HANDLER
(
  UH_ID integer not null primary key,
  UH_ORDER integer not null,
  UH_NAME varchar not null unique,
  UH_MATCH_COND varchar not null,
  UH_MATCH_ENV any,
  UH_HANDLER varchar not null,
  UH_HANDLER_ENV any
)
create index URIQA_HANDLER_ORDER_NAME on WS.WS.URIQA_HANDLER (UH_ORDER, UH_NAME)
;

--#IF VER=5
alter table WS.WS.URIQA_HANDLER add UH_MATCH_ENV any
;

alter table WS.WS.URIQA_HANDLER add UH_HANDLER_ENV any
;
--#ENDIF

create function WS.WS.URIQA_CFG_ITEM_VALUE (in param_name varchar, in is_list integer, in dflt_value varchar)
{
  declare ini_path varchar;
  declare string_val varchar;
  declare list_val any;
  ini_path := virtuoso_ini_path ();
  string_val := virtuoso_ini_item_value ('URIQA', param_name);
  if (string_val is not null)
    {
      if (is_list)
        {
	  declare ctr, len integer;
	  list_val := split_and_decode (string_val, 0, '\0\0,');
	  len := length (list_val);
	  for (ctr := 0; ctr < len; ctr := ctr + 1)
	    {
	      list_val[ctr] := trim (list_val[ctr]);
	    }
	  string_val := serialize (list_val);
	}
      if (string_val <> cast (registry_get ('URIQA' || param_name) as varchar))
        registry_set ('URIQA' || param_name, string_val);
      if (is_list)
        return list_val;
      return string_val;
    }
  string_val := registry_get ('URIQA' || param_name);
  if (not isstring (string_val))
    {
      if (dflt_value is null)
        return null;
      registry_set ('URIQA' || param_name, dflt_value);
      return dflt_value;
    }
  if (is_list)
    return deserialize (string_val);
  return string_val;
}
;

create procedure WS.WS.URIQA_LOAD_FROM_INI ()
{
  declare default_host, local_host_names, local_host_masks, our_fingerprint varchar;
  declare ctr integer;
  default_host		:= WS.WS.URIQA_CFG_ITEM_VALUE ('DefaultHost'	, 0	, 'localuriqaserver'	);
  local_host_names	:= WS.WS.URIQA_CFG_ITEM_VALUE ('LocalHostNames'	, 1	, null			);
  local_host_masks	:= WS.WS.URIQA_CFG_ITEM_VALUE ('LocalHostMasks'	, 1	, null			);
  our_fingerprint		:= WS.WS.URIQA_CFG_ITEM_VALUE ('Fingerprint'	, 0	, uuid()		);
  if (local_host_names is null or length (local_host_names) = 0)
    delete from WS.WS.URIQA_HANDLER where UH_ID=1;
  else
    {
      insert soft WS.WS.URIQA_HANDLER
      ( UH_ID	, UH_ORDER	, UH_NAME			, UH_MATCH_COND	, UH_MATCH_ENV		, UH_HANDLER	, UH_HANDLER_ENV	)
      values
      ( 1	, 100		, 'virt:LocalHostNames'		, 'server in'	, vector ()		, 'LOCALDAV'	, null			);
      update WS.WS.URIQA_HANDLER set
        UH_NAME = 'virt:LocalHostNames',
        UH_MATCH_COND = 'server in',
        UH_MATCH_ENV = local_host_names
      where UH_ID = 1 and (
          (UH_NAME <> 'virt:LocalHostNames') or
          (UH_MATCH_COND <> 'server in') or
          serialize (UH_MATCH_ENV) <> serialize (local_host_names) );
    }
  if (local_host_masks is null or length (local_host_masks) = 0)
    delete from WS.WS.URIQA_HANDLER where UH_ID=2;
  else
    {
      insert soft WS.WS.URIQA_HANDLER
      ( UH_ID	, UH_ORDER	, UH_NAME			, UH_MATCH_COND	, UH_MATCH_ENV		, UH_HANDLER	, UH_HANDLER_ENV	)
      values
      ( 2	, 100		, 'virt:LocalHostMasks'		, 'server like in'	, vector ()	, 'LOCALDAV'	, null			);
      update WS.WS.URIQA_HANDLER set
        UH_NAME = 'virt:LocalHostMasks',
        UH_MATCH_COND = 'server like in',
        UH_MATCH_ENV = local_host_masks
      where UH_ID = 2 and (
          (UH_NAME <> 'virt:LocalHostMasks') or
          (UH_MATCH_COND <> 'server like in') or
          serialize (UH_MATCH_ENV) <> serialize (local_host_masks) );
    }
insert soft WS.WS.URIQA_HANDLER
( UH_ID	, UH_ORDER	, UH_NAME		, UH_MATCH_COND	, UH_MATCH_ENV			, UH_HANDLER	, UH_HANDLER_ENV	)
values
( 100	, 999		, 'redir'		, 'schema ='	, 'http'			, 'NATIVE_HTTP'	, null			);
}
;

WS.WS.URIQA_LOAD_FROM_INI ()
;

create function WS.WS.URIQA_FULL_URI (inout path varchar, inout params varchar, inout lines varchar, in parse_params integer, in trim_prefix integer) returns varchar
{
  declare explicit_uri, host, head_uri, res varchar;
  declare pairs any;
  -- dbg_obj_princ ('WS.WS.URIQA_FULL_URI (', path, params, lines, parse_params, trim_prefix, ')');
  explicit_uri := http_request_header (lines, 'URIQA-uri');
  if (isstring (explicit_uri))
    return explicit_uri;
  if (parse_params)
    {
      res := get_keyword ('uri', params);
      if (res is not null)
        goto complete;
    }
--                         2         34       56              789            0
  pairs := regexp_parse ('^([A-Za-z]+)([ \\t]+)([^ \\t\\r\\n]+)(([ \\t]+)HTTP([^ \\t\\r\\n]+))?[ \\t\\r\\n]*\044', lines[0], 0);
  if (pairs is null)
    {
      -- dbg_obj_princ ('WS.WS.URIQA_FULL_URI has failed to parse the first line:', lines[0]);
      res := NULL;
      goto complete;
    }
  head_uri := split_and_decode (subseq (lines[0], pairs[6], pairs[7]), 0, '%+');
  if (trim_prefix and upper (head_uri) like '/URIQA/%')
    head_uri := subseq (head_uri, 6); -- in order to trim leading '/URIQA'
  -- dbg_obj_princ ('WS.WS.URIQA_FULL_URI see User-Agent=', http_request_header (lines, 'User-Agent'));
  host := http_request_header (lines, 'Host');
  if (isstring (host))
    res := WS.WS.EXPAND_URL (concat ('http://', host, '/'), head_uri);
  else
    res := head_uri;

complete:
  -- dbg_obj_princ ('WS.WS.URIQA_FULL_URI returns ', res);
  return res;
}
;

create function WS.WS.URIQA_APPLY_TRIGGERS (in op varchar, inout uri varchar, inout body any, inout params varchar, inout lines varchar) returns any
{
  declare split, err_ret any;
  split := rfc1808_parse_uri (uri);
  -- dbg_obj_princ ('WS.WS.URIQA_APPLY_TRIGGERS (', op, uri, '...) has split the URI as ', split);
  declare is_final integer;
  is_final := 0;
  for (select UH_MATCH_COND, UH_MATCH_ENV, UH_HANDLER, UH_HANDLER_ENV from WS.WS.URIQA_HANDLER) do
    {
      if (UH_MATCH_COND = 'schema =')
        {
          if (split[0] = UH_MATCH_ENV)
            goto match;
          goto no_match;
        }
      if (UH_MATCH_COND = 'server =')
        {
          if (split[1] = UH_MATCH_ENV)
            goto match;
          goto no_match;
        }
      if (UH_MATCH_COND = 'server like')
        {
          if (split[1] like UH_MATCH_ENV)
            goto match;
          goto no_match;
        }
      if (UH_MATCH_COND = 'server in')
        {
          if (position (split[1], UH_MATCH_ENV))
            goto match;
          goto no_match;
        }
      if (UH_MATCH_COND = 'server like in')
        {
          foreach (varchar srv_mask in UH_MATCH_ENV) do
            {
              if (split[1] like srv_mask)
                goto match;
            }
          goto no_match;
        }
      if (UH_MATCH_COND = 'default')
        {
          goto match;
        }
      return vector ('URIQA', 0, '500', sprintf ('Configuration error: unknown UH_MATCH_COND "%s" in WS.WS.URIQA_HANDLER', UH_MATCH_COND));
match:
      err_ret := call ('WS.WS.URIQA_HANDLER_' || UH_HANDLER)(op, uri, split, body, params, lines, UH_HANDLER_ENV, is_final);
      if (is_final)
        return err_ret;
no_match:
      ;
    }
  return vector ('URIQA', 0, '404', sprintf ('URIQA server has no way to access resource "%s"', uri));
}
;

create function WS.WS.URIQA_N3_DIR_LIST (inout split any, in a_uid integer)
{
  declare diritems any;
  declare acc any;
  declare ctr, len integer;
  declare s_path, s_uri varchar;
  s_path := split[2];
  diritems := DAV_DIR_LIST_INT (s_path, 0, '%', null, null, a_uid);
  if (DAV_HIDE_ERROR (diritems) is null)
    return null;
  xte_nodebld_init (acc);
  len := length (diritems);
  s_uri := concat (split[0], '://', split[1], s_path);
  for (ctr := 0; ctr < len; ctr := ctr + 1)
    {
      declare o_uri varchar;
      if ('R' = diritems[ctr][1])
        o_uri := concat (s_uri, diritems[ctr][10]);
      else
        o_uri := concat (s_uri, diritems[ctr][10], '/');
      xte_nodebld_acc (acc, xte_node (xte_head ('N3', 'N3S', s_uri, 'N3P', UNAME'http://www.openlinksw.com/schemas/virtdav#contains', 'N3O', o_uri)));
    }
  if (length (s_path) > 1)
    {
      declare p_path, p_uri varchar;
      declare rslash integer;
      p_path := "LEFT" (s_path, length (s_path) - 1);
      rslash := strrchr (p_path, '/');
      p_path := "LEFT" (s_path, rslash+1);
      p_uri := concat (split[0], '://', split[1], p_path);
      xte_nodebld_acc (acc, xte_node (xte_head ('N3', 'N3S', p_uri, 'N3P', UNAME'http://www.openlinksw.com/schemas/virtdav#contains', 'N3O', s_uri)));
    }
  xte_nodebld_final (acc, xte_head (UNAME' root'));
  return xml_tree_doc (acc);
}
;

create function DB.DBA."DAV_EXTRACT_DYN_RDF_application/xbel+xml" (in id any, inout split any, inout old_prop any, in a_uid integer) returns any
{
  declare ses, tree, label, roots any;
  declare cont_type, res_uri, root_uri, sub_uri varchar;
  declare rc integer;
  declare acc any;
  -- dbg_obj_princ ('DB.DBA."DAV_EXTRACT_DNY_RDF_application/xbel+xml" (', id, split, ', ..., ', a_uid, ')');
  ses := string_output ();
  rc := DAV_RES_CONTENT_INT (id, ses, cont_type, 1, 0);
  if (DAV_HIDE_ERROR (rc) is null)
    return null;
  tree := xtree_doc (ses, 0);
  -- dbg_obj_princ ('DB.DBA."DAV_EXTRACT_DNY_RDF_application/xbel+xml" will parse ', tree);
  res_uri := sprintf ('%s://%s%s', split[0], split[1], split[2]);
  xte_nodebld_init (acc);
  if (length (split[5]) > 0)
    {
      label := split_and_decode (split[5], 0, '%+');
      root_uri := sprintf ('%s#%U', res_uri, label);
      roots := xpath_eval ('/xbel//*[self::folder|self::bookmark][substring (concat (@id, "-", title), 1, 40) = \044label]', tree, 0, vector ('label', label));
      if (roots is not null)
        xte_nodebld_acc (acc, xte_node (xte_head (UNAME'N3', UNAME'N3S', root_uri, UNAME'N3P', 'http://www.openlinksw.com/virtdav#storedIn', UNAME'N3O', res_uri)));
    }
  else
    {
      label := '';
      root_uri := res_uri;
      roots := xpath_eval ('/xbel', tree, 0);
    }
  foreach (any root in roots) do
    {
      declare rdftype, title, root_id, descr, href, parent varchar;
      declare children any;
      rdftype := 'http://www.python.org/topics/xml/xbel/' || xpath_eval ('local-name(.)', root);
      -- dbg_obj_princ ('root = ', root, ', rdftype = ', rdftype);
      xte_nodebld_acc (acc, xte_node (xte_head (UNAME'N3', UNAME'N3S', root_uri, UNAME'N3P', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', UNAME'N3O', rdftype)));
      if (rdftype <> 'http://www.python.org/topics/xml/xbel/xbel')
        {
          title := xpath_eval ('string (title)', root);
          if (title <> '')
            xte_nodebld_acc (acc, xte_node (xte_head (UNAME'N3', UNAME'N3S', root_uri, UNAME'N3P', 'http://www.python.org/topics/xml/xbel/title'), title));
          descr := xpath_eval ('string (description)', root);
          if (descr <> '')
            xte_nodebld_acc (acc, xte_node (xte_head (UNAME'N3', UNAME'N3S', root_uri, UNAME'N3P', 'http://www.python.org/topics/xml/xbel/description'), descr));
          root_id := xpath_eval ('@id', root);
          if (root_id <> '')
            xte_nodebld_acc (acc, xte_node (xte_head (UNAME'N3', UNAME'N3S', root_uri, UNAME'N3P', 'http://www.python.org/topics/xml/xbel/id'), root_id));
          href := xpath_eval ('@href', root);
          if (href <> '')
            xte_nodebld_acc (acc, xte_node (xte_head (UNAME'N3', UNAME'N3S', root_uri, UNAME'N3P', 'http://www.python.org/topics/xml/xbel/id', UNAME'N3O', href)));
          parent := xpath_eval ('substring (concat (../@id, "-", ../title), 1, 40)', root);
          if (parent <> '')
            {
              parent := sprintf ('%s#%U', res_uri, parent);
              xte_nodebld_acc (acc, xte_node (xte_head (UNAME'N3', UNAME'N3S', root_uri, UNAME'N3P', 'http://www.openlinksw.com/virtdav#parentFragment', UNAME'N3O', parent)));
            }
        }
      children := xpath_eval ('folder|bookmark', root, 0);
      foreach (any child in children) do
        {
          declare c_uri varchar;
          declare c_rdftype, c_title, c_id, c_href nvarchar;
          c_uri := xpath_eval ('substring (concat (@id, "-", title), 1, 40)', child);
          if (c_uri <> '-')
            {
              c_uri := sprintf ('%s#%U', res_uri, c_uri);
              xte_nodebld_acc (acc, xte_node (xte_head (UNAME'N3', UNAME'N3S', c_uri, UNAME'N3P', 'http://www.openlinksw.com/virtdav#parentFragment', UNAME'N3O', root_uri)));
              c_rdftype := 'http://www.python.org/topics/xml/xbel/' || xpath_eval ('local-name(.)', child);
              xte_nodebld_acc (acc, xte_node (xte_head (UNAME'N3', UNAME'N3S', c_uri, UNAME'N3P', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', UNAME'N3O', c_rdftype)));
              xte_nodebld_acc (acc, xte_node (xte_head (UNAME'N3', UNAME'N3S', root_uri, UNAME'N3P', c_rdftype, UNAME'N3O', c_uri)));
              c_title := xpath_eval ('string(title)', child);
              if (c_title <> N'')
                xte_nodebld_acc (acc, xte_node (xte_head (UNAME'N3', UNAME'N3S', c_uri, UNAME'N3P', 'http://www.python.org/topics/xml/xbel/title'), c_title));
              c_id := xpath_eval ('@id', child);
              if (c_id <> N'')
                xte_nodebld_acc (acc, xte_node (xte_head (UNAME'N3', UNAME'N3S', c_uri, UNAME'N3P', 'http://www.python.org/topics/xml/xbel/id'), c_id));
              c_href := xpath_eval ('@href', child);
              if (c_href <> N'')
                xte_nodebld_acc (acc, xte_node (xte_head (UNAME'N3', UNAME'N3S', c_uri, UNAME'N3P', 'http://www.python.org/topics/xml/xbel/href', UNAME'N3O', c_href)));
            }
        }
    }
  xte_nodebld_final (acc, xte_head (UNAME' root'));
  acc := xml_tree_doc (acc);
  -- dbg_obj_princ ('DB.DBA."DAV_EXTRACT_DNY_RDF_application/xbel+xml" returns ', acc);
  return acc;

}
;

create function WS.WS.URIQA_HANDLER_LOCALDAV (inout op varchar, inout uri varchar, inout split any, inout body any, inout params varchar, inout lines varchar, inout app_env any, inout is_final integer) returns any
{
  declare id, old_prop, old_descr, rc any;
  declare uid, a_uid, a_gid integer;
  declare st, a_uname, a_pwd, a_perms, res_path varchar;
  -- dbg_obj_princ ('WS.WS.URIQA_HANDLER_LOCALDAV (', op, uri, body, params, lines, app_env, is_final, ')');
  old_descr := null;
  res_path := split[2];
  is_final := 1;
  if (res_path = '')
    {
      return vector ('URIQA', -1, '404', 'Invalid URI; Ill formed or missing path to the resource');
    }
  if ((split[3] <> '') or (split[4] <> ''))
    {
      return vector ('URIQA', -1, '404', 'Invalid URI; Virtuoso DAV does not support URIs that contain parameters');
    }
  if ((split[5] <> '') and ('MGET' <> op))
    return vector ('URIQA', -1, '500', 'Virtuoso DAV does not support MPUT and MDELETE on subject URIs that have fragment');
  if ("RIGHT"(res_path, 1) = '/')
    st := 'C';
  else
    st := 'R';
  id := DAV_SEARCH_ID (res_path, st);
  if (DAV_HIDE_ERROR (id) is null)
    {
      if ((id = -1) and (st = 'R') and (split[5] = ''))
        {
	  declare id_try2 any;
	  id_try2 := DAV_SEARCH_ID (res_path || '/', 'C');
          if (DAV_HIDE_ERROR (id_try2) is not null)
            {
	      id := id_try2;
	      st := 'C';
	      res_path := res_path || '/';
	      split[2] := res_path;
	      uri := uri || '/';
	      goto id_found;
	    }
	}
      if ((id = -1) and ('MGET' = op))
        {
          declare dct any;
          dct := ((sparql define output:valmode "LONG" describe `iri(?:uri)`));
          if (dict_size (dct) > 0)
            {
              old_descr := dct;
              dct := 0;
              goto do_op;
            }
        }
      return vector ('URIQA', id, NULL, DAV_PERROR (id) || sprintf ('; path "%s"', res_path));
    }
id_found:
  a_uid := null;
  a_gid := null;
  uid := DAV_AUTHENTICATE_HTTP (id, st, case (op) when 'MGET' then '1__' else '11_' end, 1, lines, a_uname, a_pwd, a_uid, a_gid, a_perms);
  if (DAV_HIDE_ERROR (uid) is null)
    return vector ('URIQA', id, NULL, NULL);
  old_prop := DAV_PROP_GET_INT (id, st, 'http://local.virt/DAV-RDF', 0);
  if (DAV_HIDE_ERROR (old_prop) is null)
    {
      if (-11 <> old_prop)
        return vector ('URIQA', old_prop, NULL, NULL);
      else
        old_prop := xml_tree_doc (xte_node (xte_head (UNAME' root')));
    }
  else
    {
      declare dyn_n3 any;
      declare container_type varchar;
      old_prop := xml_tree_doc (deserialize (blob_to_string (old_prop)));
      container_type := xpath_eval ('[xmlns:v="virt"] /v:rdf/v:top-res[name(*[1])="http://local.virt/this"]/v:prop[name(*[1])="http://www.openlinksw.com/virtdav#dynRdfExtractor"]/v:value', old_prop);
      if (container_type is not null)
        {
          container_type := cast (container_type as varchar);
          declare exit handler for sqlstate '*'
            {
              -- dbg_obj_princ ('Failed to call DB.DBA.DAV_EXTRACT_DYN_RDF_' || container_type, '(', id, split, ', ...,', a_uid, ' ): ', __SQL_STATE, __SQL_MESSAGE);
              goto dyn_n3_set;
	    };
          dyn_n3 := call ('DB.DBA.DAV_EXTRACT_DYN_RDF_' || container_type)(id, split, old_prop, a_uid);
          XMLAppendChildren (old_prop, dyn_n3);
dyn_n3_set: ;
        }
      else
        {
          -- dbg_obj_princ ('No container in ', old_prop);
          -- dbg_obj_princ (xpath_eval ('[xmlns:v="virt"] /v:rdf/v:top-res/(!http://local.virt/this!)', old_prop));
          ;
        }
    }
do_op:
  if ('MGET' = op)
    {
      declare fmt varchar;
      if (old_descr is null)
        {
          declare dct any;
          dct := ((sparql define output:valmode "LONG" describe `iri(?:uri)`));
          if (dict_size (dct) > 0)
            {
              old_descr := dct;
              dct := 0;
            }
        }
      if (old_descr is not null)
        {
          declare dct_triples, descr_n3 any;
          declare dct_ctr, dct_len integer;
          dct_triples := dict_list_keys (old_descr, 1);
          dct_len := length (dct_triples);
          xte_nodebld_init (descr_n3);
          for (dct_ctr := 0; dct_ctr < dct_len; dct_ctr := dct_ctr + 1)
            {
              declare tr, s, p any;
              tr := dct_triples[dct_ctr];
              s := id_to_iri (tr[0]);
              p := id_to_iri (tr[1]);
              if (isiri_id (tr[2]))
                xte_nodebld_acc (descr_n3, xte_node (xte_head (UNAME'N3', UNAME'N3S', s, UNAME'N3P', p, UNAME'N3O', id_to_iri (tr[2]))));
              else
                xte_nodebld_acc (descr_n3, xte_node (xte_head (UNAME'N3', UNAME'N3S', s, UNAME'N3P', p), DB.DBA.RDF_STRSQLVAL_OF_LONG (tr[2])));
            }
          xte_nodebld_final (descr_n3, xte_head (UNAME' root'));
          if (isentity (old_prop))
	    {
	      descr_n3 := xml_tree_doc (descr_n3);
              XMLAppendChildren (old_prop, descr_n3);
	    }
          else
            old_prop := xml_tree_doc (descr_n3);
        }
      fmt := get_keyword ('format', params, 'application/rdf+xml');
      if ('C' = st)
        XMLAppendChildren (old_prop, WS.WS.URIQA_N3_DIR_LIST (split, a_uid));
      if ((fmt = 'application/rdf+xml') or (fmt = 'text/xml'))
        {
          http_value (xslt ('http://local.virt/davxml2rdfxml', old_prop, vector ('this-real-uri', uri)));
          http_header (http_header_get () || 'Content-Type: ' || fmt || '\r\n');
	}
      else if (fmt = 'text/html')
        {
          declare n3, html any;
          n3 := xslt ('http://local.virt/davxml2n3xml', old_prop, vector ('this-real-uri', uri));
          html := xslt ('http://local.virt/n3xml2uriqahtml', n3, vector ('main-uri', uri));
          http_value (html);
        }
      else
        return vector ('URIQA', -1, '500', 'Invalid GET: Virtuoso DAV support only "application/rdf+xml", "text/xml" and "text/html" values for "format"');
      is_final := 1;
      return vector ('00000', 0, '200', 'OK');
    }
  if ('MPUT' = op)
    {
      declare old_n3, addon_n3 any;
      old_n3 := xslt ('http://local.virt/davxml2n3xml', old_prop);
      -- dbg_obj_princ ('old_n3 is', old_n3);
      addon_n3 := xslt ('http://local.virt/rdfxml2n3xml', xtree_doc (body, 0));
      if (addon_n3 is null)
        return vector ('URIQA', 0, '500', 'Invalid MPUT: The request body contain no RDF triplets');
      if (xquery_eval ('exists (/N3[@N3P="http://www.openlinksw.com/schemas/virtdav#contains"])', addon_n3))
        return vector ('URIQA', 0, '500', 'Invalid MPUT: The request body contain triplets with read-only system predicate http://www.openlinksw.com/schemas/virtdav#contains');
      old_n3 := DAV_RDF_MERGE (old_n3, addon_n3, null, 0);
      rc := DAV_PROP_SET_INT (res_path, 'http://local.virt/DAV-RDF',
        serialize (DAV_RDF_PREPROCESS_RDFXML (old_n3, N'http://local.virt/this', 1)),
        null, null, 0, 1, 1 );
      if (DAV_HIDE_ERROR (rc) is null)
        return vector ('URIQA', '400', DAV_PERROR (rc));
      is_final := 1;
      return vector ('00000', 0, '200', 'OK');
    }
  if ('MDELETE' = op)
    {
      declare old_n3, sub_n3 any;
      old_n3 := xslt ('http://local.virt/davxml2n3xml', old_prop);
      -- dbg_obj_princ ('old_n3 is', old_n3);
      if (not xpath_eval ('exists(/N3)', old_n3))
        goto mdelete_ok;
      if (length (body) > 0)
        {
          sub_n3 := xslt ('http://local.virt/rdfxml2n3xml', xtree_doc (body, 0));
          if (sub_n3 is null)
            {
              return vector ('URIQA', 0, '500', 'Invalid MDELETE: The request body is not empty but contain no RDF triplets');
            }
          else
            old_n3 := DAV_RDF_SUBTRACT (old_n3, sub_n3);
          rc := DAV_PROP_SET_INT (res_path, 'http://local.virt/DAV-RDF',
            serialize (DAV_RDF_PREPROCESS_RDFXML (old_n3, N'http://local.virt/this', 1)),
            null, null, 0, 1, 1 );
          if (DAV_HIDE_ERROR (rc) is null)
            return vector ('URIQA', '400', DAV_PERROR (rc));
        }
      else
        {
          rc := DAV_PROP_REMOVE_INT (res_path, 'http://local.virt/DAV-RDF',
            null, null, 0, 1, 1);
          if (DAV_HIDE_ERROR (rc) is null)
            return vector ('URIQA', '400', DAV_PERROR (rc));
        }
mdelete_ok:
      is_final := 1;
      return vector ('00000', 0, '200', 'OK');
    }
  is_final := 1;
    return vector ('URIQA', 0, '500', sprintf ('Virtuoso DAV does not support URIQA operation "%s"', op));
}
;

create function WS.WS.URIQA_HANDLER_NATIVE_HTTP (inout op varchar, inout uri varchar, inout split any, inout body any, inout params varchar, inout lines varchar, inout app_env any, inout is_final integer) returns any
{
  declare req_uri, req_header, resp_page, resp_header any;
  declare param_ctr, param_count, line_ctr, line_count, our_fingerprint_ctr integer;
  declare our_fingerprint varchar;
  -- dbg_obj_princ ('WS.WS.URIQA_HANDLER_NATIVE_HTTP (', op, uri, body, params, lines, app_env, is_final, ')');
  our_fingerprint := 'Fingerprint' || registry_get ('URIQAFingerprint');
  req_uri := string_output ();
  http (sprintf ('%s://%s/uriqa/?uri=%U&method=%U&', split[0], split[1], uri, op), req_uri);
  param_count := length (params);
  our_fingerprint_ctr := 0;
  for (param_ctr := 1; param_ctr < param_count; param_ctr := param_ctr + 2)
    {
      declare pname, pvalue varchar;
      pname := params[param_ctr-1];
      pvalue := params[param_ctr];
      if (pname = our_fingerprint)
        our_fingerprint_ctr := our_fingerprint_ctr + 1;
      if ((pname <> 'uri') and (pname <> 'method') and (pname <> 'Content'))
        {
          if (isstring (pvalue))
            http (sprintf ('&%U=%U', pname, pvalue), req_uri);
          else
            http (sprintf ('&%U', pname), req_uri);
        }
    }
  if (our_fingerprint_ctr > 1)
    {
      is_final := 1;
      return vector ('URIQA', 0, '500', 'Virtuoso tries to recursively access itself via HTTP to get metadata via URIQA (wrong config?)');
    }
  http (sprintf ('&%U=%U', our_fingerprint, registry_get ('URIQADefaultHost')), req_uri);
  req_uri := string_output_string (req_uri);
  req_header := string_output ();
  line_count := length (lines);
  for (line_ctr := 1; line_ctr < line_count; line_ctr := line_ctr + 1)
    {
      declare line varchar;
      line := trim (lines [line_ctr], concat (chr (13), chr(10)));
      if (line_ctr > 1)
        http (concat (chr (13), chr(10)), req_header);
      http (line, req_header);
    }
  req_header := string_output_string (req_header);
  -- dbg_obj_princ ('Performing http_get (', req_uri, ', ..., "POST", ', req_header, ', ...)');
  if (body is null)
    resp_page := http_get (req_uri, resp_header, 'POST', req_header, '');
  else
    resp_page := http_get (req_uri, resp_header, 'POST', req_header, string_output_string (body));
  -- dbg_obj_princ ('response header: ', resp_header);
  -- dbg_obj_princ ('response body: ', resp_page);
  http (resp_page);
  is_final := 1;
  if (length (resp_header) > 0)
    {
      declare resp_line varchar;
      declare pairs any;
      resp_line := resp_header[0];
      pairs := regexp_parse ('^HTTP[^ \\t\\r\\n]+[ \\t]+([0-9]+)[ \\t]+([^ \\t\\r\\n]+[^\\r\\n]*)[ \\t\\r\\n]*\044', resp_line, 0);
      if (pairs is null)
        return vector ('URIQA', 0, '500', 'The remote URIQA server returned an invalid header');
      return vector ('00000', 0, subseq (resp_line, pairs[2], pairs[3]), subseq (resp_line, pairs[4], pairs[5]));
    }
  return vector ('URIQA', 0, '500', 'The remote URIQA server returned an empty header');
--  return vector ('00000', 0, '200', 'OK');
}
;

create procedure WS.WS.URIQA_STATUS (in err_ret any, in signal_errors integer)
{
  -- dbg_obj_princ ('WS.WS.URIQA_STATUS (', err_ret, signal_errors, ')');
  if (err_ret[2] is null)
    err_ret[2] := '500';
  if (err_ret[3] is null)
    err_ret[3] := coalesce (DAV_PERROR (err_ret[1]), 'OK');
  if (signal_errors)
    {
      if (err_ret[0] <> '00000')
        signal (err_ret[0], sprintf ('%d %s', err_ret[2], err_ret[3]));
      return;
    }
  if (err_ret[0] <> '00000')
    {
      http_request_status (sprintf ('HTTP/1.1 %s Error %s %s', err_ret[2], err_ret[0], split_and_decode (err_ret[3], 0, '\0\0\n')[0]));
      http (concat ('<pre>HTTP/1.1 ', err_ret[2], ' Error ', err_ret[0], ' ', err_ret[3], '</pre>'));
    }
  else if (err_ret[2] like 'HTTP/%')
    http_request_status (err_ret[2]);
  else
    http_request_status (sprintf ('HTTP/1.1 %s %s', err_ret[2], split_and_decode (err_ret[3], 0, '\0\0\n')[0]));
}
;


-- HTTP request handlers

create procedure WS.WS."MPUT" (inout path varchar, inout params varchar, inout lines varchar)
{
  declare b, err_ret any;
  declare s_uri varchar;
  -- dbg_obj_princ ('WS.WS."MPUT" (', path, params, lines, ')');
  b := http_body_read ();
  -- dbg_obj_princ ('body is ', string_output_string (b));
  declare exit handler for sqlstate '*' {
    WS.WS.URIQA_STATUS (vector (__SQL_STATE, 0, '500', __SQL_MESSAGE), 0);
    };
  s_uri := WS.WS.URIQA_FULL_URI (path, params, lines, 0, 0);
  err_ret := WS.WS.URIQA_APPLY_TRIGGERS ('MPUT', s_uri, b, params, lines);
  WS.WS.URIQA_STATUS (err_ret, 0);
}
;

create procedure WS.WS."MGET" (inout path varchar, inout params any, inout lines any)
{
  declare b any;
  declare s_uri, err_ret varchar;
  -- dbg_obj_princ ('WS.WS."MGET" (', path, params, lines, ')');
  b := http_body_read ();
  -- dbg_obj_princ ('body is ', string_output_string (b));
--  declare exit handler for sqlstate '*' {
--    WS.WS.URIQA_STATUS (vector (__SQL_STATE, 0, '500', __SQL_MESSAGE), 0);
--    };
  s_uri := WS.WS.URIQA_FULL_URI (path, params, lines, 0, 0);
-- WS.WS.URIQA_APPLY_TRIGGERS ('MGET', ... ) gets null instead of body because body is ignored for NGET
  b := null;
  err_ret := WS.WS.URIQA_APPLY_TRIGGERS ('MGET', s_uri, b, params, lines);
  WS.WS.URIQA_STATUS (err_ret, 0);
}
;

create procedure WS.WS."MDELETE" (inout path varchar, inout params any, inout lines any)
{
  declare b any;
  declare s_uri, err_ret varchar;
  -- dbg_obj_princ ('WS.WS."MDELETE" (', path, params, lines, ')');
  b := http_body_read ();
  -- dbg_obj_princ ('body is ', string_output_string (b));
  declare exit handler for sqlstate '*' {
    WS.WS.URIQA_STATUS (vector (__SQL_STATE, 0, '500', __SQL_MESSAGE), 0);
    };
  s_uri := WS.WS.URIQA_FULL_URI (path, params, lines, 0, 0);
  err_ret := WS.WS.URIQA_APPLY_TRIGGERS ('MDELETE', s_uri, b, params, lines);
  WS.WS.URIQA_STATUS (err_ret, 0);
}
;

create procedure WS.WS."/!URIQA/" (inout path varchar, inout params any, inout lines any)
{
  declare exit handler for sqlstate '*' {
     -- dbg_obj_princ (__SQL_STATE, __SQL_MESSAGE);
     return ;
   };
  declare b, err_ret any;
  declare s_uri, upper_line varchar;
  if (length (params) < 1)
    params := __http_stream_params ();
  -- dbg_obj_princ ('main_vsp:', path, params, lines);
  b := http_body_read ();
  if (length (lines) > 1)
    upper_line := upper(lines[0]);
  else
    upper_line := '';
  if (
   (upper_line like 'GET /URIQA/ HTTP/%') or
   (upper_line like 'GET /URIQA HTTP/%') or
   (trim (upper_line, ' \r\n') like 'GET /URIQA/') or
   (trim (upper_line, ' \r\n') like 'GET /URIQA') )
    {
      http ('<html><head><title>URIQA quick test</title></head><body>
<form method="GET" action="/uriqa/">
Enter URI of a resource to get metadata: <input name="uri" type="text"><br/>
<input name="format" type="radio" selected=1 value="application/rdf+xml"/> RDF/XML
<input name="format" type="radio" selected=1 value="text/xml"/> XML for HTML browsers
<input name="format" type="radio" value="text/html"/> HTML<br/>
<input name="Go" type="submit" value="Go">
</form>
</body></html>' );
      return;
    }
  -- dbg_obj_princ ('body is ', string_output_string (b));
  declare exit handler for sqlstate '*' {
    WS.WS.URIQA_STATUS (vector (__SQL_STATE, 0, '500', __SQL_MESSAGE), 0);
    };
  s_uri := WS.WS.URIQA_FULL_URI (path, params, lines, 1, 1);
  err_ret := WS.WS.URIQA_APPLY_TRIGGERS (get_keyword ('method', params, 'MGET'), s_uri, b, params, lines);
  WS.WS.URIQA_STATUS (err_ret, 0);
}
;

create procedure WS.WS.URIQA_VHOST_RESET()
{
  registry_set ('/!URIQA/', 'no_vsp_recompile');
  DB.DBA.VHOST_REMOVE (lpath=>'/URIQA/');
  DB.DBA.VHOST_REMOVE (lpath=>'/uriqa/');
  DB.DBA.VHOST_REMOVE (lpath=>'/uriqa');
  DB.DBA.VHOST_REMOVE (lpath=>'/URIQA');
  DB.DBA.VHOST_DEFINE (lpath=>'/URIQA/', ppath=>'/!URIQA/', is_dav=>1, vsp_user=>'dba', opts=>vector('noinherit', 1));
  DB.DBA.VHOST_DEFINE (lpath=>'/uriqa/', ppath=>'/!URIQA/', is_dav=>1, vsp_user=>'dba', opts=>vector('noinherit', 1));
}
;


