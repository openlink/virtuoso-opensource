--
--  $Id$
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

use DB
;

create procedure DB.DBA.RDFData_log_message (in x varchar)
{
  if (0)
  log_message (cast (x as varchar));
}
;

create function DB.DBA."RDFData_DAV_AUTHENTICATE" (in id any, in what char(1), in req varchar, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer)
{
  RDFData_log_message (current_proc_name ());
  --log_message (sprintf ('RDFData_DAV_AUTHENTICATE req=%s uname=%s uid=%d', req, auth_uname, auth_uid));
  -- dbg_obj_princ ('RDFData_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, ')');
  if (not ('110' like req))
  {
    return -13;
  }
  if ('100' like req and auth_uid >= 0)
    return auth_uid;

  if ((auth_uid <> id[3]) and (auth_uid <> http_dav_uid()))
  {
    -- dbg_obj_princ ('a_uid is ', auth_uid, ', id[3] is ', id[3], ' mismatch');
    return -13;
  }
  if (auth_uid >= 0)
    return auth_uid;
  return -12;
}
;

create function DB.DBA."RDFData_DAV_AUTHENTICATE_HTTP" (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
{
  RDFData_log_message (current_proc_name ());
--  dbg_obj_print (current_proc_name (), id, what, _perms);
  declare rc integer;
  declare puid, pgid integer;
  declare u_password, pperms varchar;
  declare allow_anon integer;
  if (length (req) <> 3)
    return -15;

  whenever not found goto nf_col_or_res;
  puid := http_dav_uid();
  pgid := coalesce (
    ( select G_ID from WS.WS.SYS_DAV_GROUP
      where G_NAME = 'RDFData_' || coalesce ((select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID=id[1] and COL_DET='RDFData'), '')
      ), puid+1);
  pperms := '110100100NN';
  if ((what <> 'R') and (what <> 'C'))
    return -14;
  allow_anon := WS.WS.PERM_COMP (substring (cast (pperms as varchar), 7, 3), req);
  if (a_uid is null)
    {
      if ((not allow_anon) or ('' <> WS.WS.FINDPARAM (a_lines, 'Authorization:')))
      rc := WS.WS.GET_DAV_AUTH (a_lines, allow_anon, can_write_http, a_uname, u_password, a_uid, a_gid, _perms);
      if (rc < 0)
        return rc;
    }
  if (isinteger (a_uid))
    {
      if (a_uid < 0)
	return a_uid;
     if (a_uid = 1) -- Anonymous FTP
	{
          a_uid := http_nobody_uid ();
          a_gid := http_nogroup_gid ();
	}
    }
  if (DAV_CHECK_PERM (pperms, req, a_uid, a_gid, pgid, puid))
    return a_uid;
  return -13;

nf_col_or_res:
  return -1;
}
;


create function DB.DBA."RDFData_DAV_GET_PARENT" (in id any, in st char(1), in path varchar) returns any
{
  RDFData_log_message (current_proc_name ());
  return -20;
}
;

create function DB.DBA."RDFData_DAV_COL_CREATE" (in detcol_id any, in path_parts any, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  RDFData_log_message (current_proc_name ());
  return -20;
}
;

create function DB.DBA."RDFData_DAV_COL_MOUNT" (in detcol_id any, in path_parts any, in full_mount_path varchar, in mount_det varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  RDFData_log_message (current_proc_name ());
  return -20;
}
;

create function DB.DBA."RDFData_DAV_COL_MOUNT_HERE" (in parent_id any, in full_mount_path varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  RDFData_log_message (current_proc_name ());
  return -20;
}
;


create function DB.DBA."RDFData_DAV_DELETE" (in detcol_id any, in path_parts any, in what char(1), in silent integer, in auth_uid integer) returns integer
{
  RDFData_log_message (current_proc_name ());
  return -20;
}
;

create function DB.DBA."RDFData_DAV_RES_UPLOAD" (in detcol_id any, in path_parts any, inout content any, in type varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('RDFData_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', type, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


create function DB.DBA."RDFData_DAV_PROP_REMOVE" (in id any, in what char(0), in propname varchar, in silent integer, in auth_uid integer) returns integer
{
  RDFData_log_message (current_proc_name ());
  return -20;
}
;

create function DB.DBA."RDFData_DAV_PROP_SET" (in id any, in what char(0), in propname varchar, in propvalue any, in overwrite integer, in auth_uid integer) returns any
{
  RDFData_log_message (current_proc_name ());
  if (propname[0] = 58)
    {
      return -16;
    }
  return -20;
}
;

create function DB.DBA."RDFData_DAV_PROP_GET" (in id any, in what char(0), in propname varchar, in auth_uid integer)
{
  RDFData_log_message (current_proc_name ());
  return -11;
}
;


create function DB.DBA."RDFData_DAV_PROP_LIST" (in id any, in what char(0), in propmask varchar, in auth_uid integer)
{
  RDFData_log_message (current_proc_name ());
  return vector ();
}
;

create function DB.DBA."RDFData_ACCESS_PARAMS" (in detcol_id any, out access varchar, out gid integer, out uid integer)
{
  declare access_tmp varchar;
  whenever not found goto ret;
  access := '000100100N';
  gid := http_nogroup_gid ();
  uid := http_nobody_uid ();
  if (isinteger (detcol_id))
  {
    select COL_PERMS, COL_GROUP, COL_OWNER into access_tmp, gid, uid from WS.WS.SYS_DAV_COL where COL_ID = detcol_id;
  }
  access[0] := access_tmp[0];
  access[1] := access_tmp[1];
ret:
  ;
}
;

create procedure DB.DBA.RDFData_cast_dt_silent (in d any)
{
  if (__tag (d) = 211)
    return d;
  else
    {
      declare exit handler for sqlstate '*'
	{
	  return now ();
	};
      return cast (d as datetime);
    }
}
;

create function DB.DBA."RDFData_DAV_DIR_SINGLE" (in id any, in what char(0), in path any, in auth_uid integer) returns any
{
  RDFData_log_message (current_proc_name ());
  -- dbg_obj_princ ('RDFData_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
  declare path_parts any;
  declare access, ownergid, owner_uid, mime any;
  declare len int;

  DB.DBA."RDFData_ACCESS_PARAMS" (id[1], access, ownergid, owner_uid);

  if (isstring (path))
    path_parts := split_and_decode (path, 0, '\0\0/');
  else
    path_parts := path;
  len := length (path_parts);
  if (what = 'C')
    return vector (DAV_CONCAT_PATH (path, ''), 'C', 0, now (), id, access, ownergid, owner_uid, now (), 'dav/unix-directory', path_parts [len - 2]);
  mime := 'application/rdf+xml';
  if (is_http_ctx ())
    {
      declare lpath varchar;
      lpath := http_path ();
      if (lpath like '%.ttl')
        mime := 'text/turtle';
      else if (lpath like '%.n3')
        mime := 'text/rdf+n3';
    }
  return vector (DAV_CONCAT_PATH (path, ''), 'R', 0, now (), id, access, ownergid, owner_uid, now (), mime, path_parts [len - 1]);
}
;


create function DB.DBA."RDFData_DAV_DIR_LIST" (in detcol_id any, in path_parts any, in detcol_path varchar, in name_mask varchar, in recursive integer, in auth_uid integer) returns any
{
  RDFData_log_message (current_proc_name ());
  declare top_davpath varchar;
  declare res any;
  declare top_id, descnames any;
  declare what char (1);
  declare access, filt_lg varchar;
  declare ownergid, owner_uid, dn_ctr, dn_count integer;
  declare gr, u_name any;

  vectorbld_init (res);

  DB.DBA."RDFData_ACCESS_PARAMS" (detcol_id, access, ownergid, owner_uid);

  -- dbg_obj_princ ('RDFData_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid, ')');

  if ((0 = length (path_parts)) or ('' = path_parts[length (path_parts) - 1]))
    what := 'C';
  else
    what := 'R';
  if ('C' = what and 1 = length(path_parts))
    top_id := vector (UNAME'RDFData', detcol_id, null, owner_uid, null, null); -- may be a fake id because top_id[4] may be NULL
  else
    top_id := DB.DBA."RDFData_DAV_SEARCH_ID" (detcol_id, path_parts, what);
  if (DAV_HIDE_ERROR (top_id) is null)
    {
      return vector();
    }
  top_davpath := DAV_CONCAT_PATH (detcol_path, path_parts);
  if ('R' = what)
    {
      return vector (DB.DBA."RDFData_DAV_DIR_SINGLE" (top_id, what, top_davpath, auth_uid));
    }
  gr := DAV_PROP_GET_INT (detcol_id, 'C', 'virt:rdfdata_graph', 0);
  filt_lg := DAV_PROP_GET_INT (detcol_id, 'C', 'virt:rdfdata_lang', 0);
  if (not isstring (gr) or length (gr) = 0)
    {
      u_name := (select p.COL_NAME from WS.WS.SYS_DAV_COL p, WS.WS.SYS_DAV_COL c
      where c.COL_ID = detcol_id and p.COL_ID = c.COL_PARENT);
      gr := sioc..user_doc_iri (u_name);
    }
  if (not isstring (filt_lg))
    filt_lg := '';
  if (is_http_ctx () and filt_lg = '*http*')
    {
      filt_lg := http_request_header (http_request_header (), 'Accept-Language', null, '');
    }
--  dbg_obj_print (detcol_id, gr);
  if (top_id[2] is null)
    {
--	vectorbld_acc (res,
--	    	vector (
--		   DAV_CONCAT_PATH (top_davpath, 'All') || '/',
--		   'C',
--		   0,
--		   now (),
--                   vector (UNAME'RDFData', detcol_id, -1),
--                   access,
--		   ownergid,
--		   owner_uid,
--		   now (),
--		   'dav/unix-directory',
--		   'All')
--		 );
      FOR SELECT CLS FROM (
		    sparql
		    select distinct ?CLS
		    where {
		      graph `iri(?:gr)`
		      {
		      	?x a ?CLS .
		      } } ) sub do
      {
	declare tmp, tit, pref any;
	declare p1, p2, p3, pos int;
	p1 := coalesce (strrchr (cls, '#'), -1);
	p2 := coalesce (strrchr (cls, '/'), -1);
	p3 := coalesce (strrchr (cls, ':'), -1);
	pos := __max (p1, p2, p3);
	if (pos > 0)
	  {
	    tit := subseq (CLS, pos + 1);
            tmp := subseq (CLS, 0, pos + 1);
	    pref := RDFData_std_pref (tmp);
	    if (pref is not null)
	      tit := pref || ':' || tit;
	    else
              tit := CLS;
	  }
	else
	  tit := CLS;
        tit := replace (tit, '/', '^2f');
        tit := replace (tit, '#', '^23');
	--tit := sprintf ('%U', tit);
	vectorbld_acc (res,
	    	vector (
		   DAV_CONCAT_PATH (top_davpath, tit) || '/',
		   'C',
		   0,
		   now (),
                   vector (UNAME'RDFData', detcol_id, iri_to_id (CLS)),
                   access,
		   ownergid,
		   owner_uid,
		   now (),
		   'dav/unix-directory',
		   tit)
		 );
      }
    }
  else if (top_id[2] is not null and length (top_id) = 4)
    {
      declare cs any;
      declare qr, rset, mdta, h, dict, is_all any;
      declare inc, limit int;

      limit := 1000;
      inc := 0;
      is_all := 0;
      cs := top_id[2];
      cs := id_to_iri (cs);
      if (cs = 'All')
	{
	  is_all := 1;
	  cs := '?cls';
	  return vector ();
	}
      else
        cs := sprintf ('<%S>', cs);
      --dbg_obj_print (top_id[2]);

      qr := sprintf ('sparql
          define output:valmode "LONG"
	  prefix dc: <http://purl.org/dc/elements/1.1/>
	  prefix dct: <http://purl.org/dc/terms/>
	  prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
	  prefix skos: <http://www.w3.org/2004/02/skos/core#>
	  SELECT ?X ?L ?T ?PL ?CR ?MOD
	  where
	  {
	    graph <%S>
	    {
	      ?X a %s
	      optional { ?X rdfs:label ?L } .
	      optional { ?X dc:title ?T } .
	      optional { ?X skos:prefLabel ?PL } .
	      optional { ?X dct:created ?CR } .
	      optional { ?X dct:modified ?MOD } .
	    }
	  }', gr, cs);

	dict := dict_new ();
	exec (qr, null, null, vector (), 0, null, null, h);
        while (0 = exec_next (h, null, null, rset))
	{
	  declare tit, lg any;
	  declare X,L,T,PL,CR,MOD any;
	  --dbg_obj_print (rset);
	  X := rset[0];
	  L := rset[1];
	  T := rset[2];
	  PL := rset[3];
	  CR := rset[4];
	  MOD := rset[5];

	  cr := coalesce (cr, now ());
	  mod := coalesce (mod, now ());
	  cr := RDFData_cast_dt_silent (cr);
	  mod := RDFData_cast_dt_silent (mod);
	  --dbg_obj_print (cr, mod);
	  tit := coalesce (L, T, PL);

	  lg := '';
	  if (is_all)
	    tit := 'iid';
	  else if (tit is null)
	    tit := '~unnamed~';
	  else
	    {
	      lg := DB.DBA.RDF_LANGUAGE_OF_LONG (tit, '');
              tit := DB.DBA.RDF_SQLVAL_OF_LONG (tit);
	    }
	  --dbg_obj_print (filt_lg, lg, strstr (filt_lg, lg));
	  if (filt_lg <> '' and lg <> '' and strstr (filt_lg, lg) is null)
	    goto next_row;
	  if (dict_get (dict, X) = 1)
	    goto next_row;
	  tit := sprintf ('%s (%i).rdf', tit, iri_id_num (iri_to_id (X)));
	  --tit := replace (sprintf ('%U', x), '/', '%252F');
	  --dbg_obj_print (tit, lg);
	  vectorbld_acc (res,
	    	vector (
		   DAV_CONCAT_PATH (top_davpath, tit),
		   'R',
		   0,
		   mod,
                   vector (UNAME'RDFData', detcol_id, cs, iri_to_id (X)),
                   access,
		   ownergid,
		   owner_uid,
		   cr,
		   'application/rdf+xml',
		   tit)
		 );
	  dict_put (dict, X, 1);
	  inc := inc + 1;
	  if (inc > limit)
	    goto end_loop;
	  next_row:;
	}
	end_loop:;
	exec_close (h);
    }
finalize_res:
  vectorbld_final (res);
  return res;
}
;


create function RDFData_std_pref (in iri varchar, in rev int := 0)
{
  declare v any;
  v := vector (
  'http://xmlns.com/foaf/0.1/', 'foaf',
  'http://rdfs.org/sioc/ns#', 'sioc',
  'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'rdf',
  'http://www.w3.org/2000/01/rdf-schema#', 'rdfs',
  'http://www.w3.org/2003/01/geo/wgs84_pos#', 'geo',
  'http://atomowl.org/ontologies/atomrdf#', 'aowl',
  'http://purl.org/dc/elements/1.1/', 'dc',
  'http://purl.org/dc/terms/', 'dct',
  'http://www.w3.org/2004/02/skos/core#', 'skos',
  'http://rdfs.org/sioc/types#', 'sioct',
  'http://sw.deri.org/2005/04/wikipedia/wikiont.owl#', 'wiki',
  'http://www.w3.org/2002/01/bookmark#', 'bm',
  'http://www.w3.org/2003/12/exif/ns/', 'exif',
  'http://www.w3.org/2000/10/annotation-ns#', 'ann',
  'http://purl.org/vocab/bio/0.1/', 'bio',
  'http://www.w3.org/2001/vcard-rdf/3.0#', 'vcard',
  'http://www.w3.org/2002/12/cal#', 'vcal',
  'http://www.w3.org/2002/07/owl#', 'owl',
  'http://web.resource.org/cc/', 'cc',
  'http://dbpedia.org/class/yago/', 'dbp'

  );
  if (rev)
    {
      declare nv, l any;
      nv := make_array (length (v), 'any');
      for (declare i, j int, j := 0, i := length (v) - 1; i >= 0; i := i - 2, j := j + 2)
        {
	   nv[j] := v[i];
	   nv[j+1] := v[i-1];
	}
      return get_keyword (iri, nv, null);
    }
  else
   return get_keyword (iri, v, null);
}
;

create function DB.DBA."RDFData_DAV_DIR_FILTER" (in detcol_id any, in path_parts any, in detcol_path varchar, inout compilation any, in recursive integer, in auth_uid integer) returns any
{
  RDFData_log_message (current_proc_name ());
  -- dbg_obj_princ ('RDFData_DAV_DIR_FILTER (', detcol_id, path_parts, detcol_path, compilation, recursive, auth_uid, ')');
  return vector();
}
;

create function DB.DBA."RDFData_DAV_SEARCH_ID" (in detcol_id any, in path_parts any, in what char(1)) returns any
{
  RDFData_log_message (current_proc_name ());
  -- dbg_obj_princ ('RDFData_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  declare orig_id, ctr, len integer;
  declare r_id, cl_id, cl any;
  declare access, ownergid, owner_uid any;
  DB.DBA."RDFData_ACCESS_PARAMS" (detcol_id, access, ownergid, owner_uid);

  if (path_parts[0] = '' or path_parts[0] is null)
    return -1;
  if (path_parts[0] <> '')
    {
      declare x, pos, pref, url any;
      cl := path_parts[0];
      pos := strchr (cl, ':');
      pref := subseq (cl, 0, pos);
      url := RDFData_std_pref (pref, 1);
      if (url is null)
        {
	  cl := replace (cl, '^2f', '/');
	  cl := replace (cl, '^23', '#');
          cl_id := iri_to_id (cl);
	  --dbg_obj_print ('cl:',cl);
	}
      else
        {
	  cl := subseq (cl, pos + 1);
	  cl := url || cl;
	  cl_id := iri_to_id (cl);
        }
    }
  if (length (path_parts) = 2 and what = 'C')
    {
      return vector (UNAME'RDFData', detcol_id, cl_id, owner_uid);
    }
  else if (length (path_parts) = 2 and path_parts[1] <> '' and what = 'R')
    {
      declare t, arr any;
      t := path_parts[1];
      arr := sprintf_inverse (t, '%s (%d).%s', 1);
      if (3 > length (arr))
        return -1;
      r_id := iri_id_from_num (arr [1]);
--      dbg_obj_print (arr, r_id);
      return vector (UNAME'RDFData', detcol_id, cl_id, owner_uid, r_id);
    }
  return -20;
}
;

create function DB.DBA."RDFData_DAV_SEARCH_PATH" (in id any, in what char(1)) returns any
{
  declare col_path varchar;
  declare ret any;
  RDFData_log_message (current_proc_name ());
  -- dbg_obj_princ ('RDFData_DAV_SEARCH_PATH (', id, what, ')');
  col_path := WS.WS.COL_PATH (id[1]);
  if (what = 'C')
    ret := sprintf ('%s%s/', col_path, id_to_iri (id[2]));
  else
    ret := sprintf ('%s%s/iid (%d).rdf', col_path, id_to_iri (id[2]), iri_id_num (id[4]));
--  dbg_obj_print (ret);
  return ret;
}
;

create function DB.DBA."RDFData_DAV_RES_UPLOAD_COPY" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite_flags integer,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer,
  in auth_uname varchar := null,
  in auth_pwd varchar := null,
  in extern integer := 1,
  in check_locks any := 1) returns any
{
  RDFData_log_message (current_proc_name ());
  return -20;
}
;

create function DB.DBA."RDFData_DAV_RES_UPLOAD_MOVE" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite_flags integer,
  in auth_uid integer,
  in auth_uname varchar := null,
  in auth_pwd varchar := null,
  in extern integer := 1,
  in check_locks any := 1) returns any
{
  RDFData_log_message (current_proc_name ());
  return -20;
}
;

create function DB.DBA."RDFData_DAV_RES_CONTENT" (in id any, inout content any, out type varchar, in content_mode integer) returns integer
{
  RDFData_log_message (current_proc_name ());
  declare iri, url, qr, _from any;
  declare path, params, lines, ses, gr any;
  -- dbg_obj_princ ('RDFData_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
  if (id [4] is null)
    return -20;
  type := 'application/rdf+xml';
  if (is_http_ctx ())
    {
      declare lpath varchar;
      lpath := http_path ();
      if (lpath like '%.rdf')
	type := 'application/rdf+xml';
      else if (lpath like '%.nt')
	type := 'text/n3';
      else if (lpath like '%.txt')
	type := 'text/plain';
      else if (lpath like '%.json')
	type := 'application/json';
      else
        type := 'text/turtle';
    }
  iri := id_to_iri (id [4]);
--  dbg_obj_print (iri);
  _from := '';
  gr := DAV_PROP_GET_INT (id[1], 'C', 'virt:rdfdata_graph', 0);
  if (__proc_exists ('sioc.DBA.get_graph') is not null and gr = sioc.DBA.get_graph ())
    {
      declare pg any;
      declare tmp, uname any;
      declare pos int;
      pg := http_param ('page');
      if (not isstring (pg))
	pg := '0';
      pg := atoi (pg);

      -- take data from ODS graph
      if (regexp_match ('https?://([^/]*)/dataspace/(person|organization)/(.*)', iri) is not null and iri not like '%/online_account/%')
        {
	  tmp := sprintf_inverse (iri, 'http%s://%s/dataspace/%s/%s', 0);
	  tmp := tmp[3];
	  pos := coalesce (strchr (tmp, '#'), strchr (tmp, '/'));
	  if (pos is not null)
	    uname := subseq (tmp, 0, pos);
          else
	    uname := tmp;
          ses := sioc..compose_foaf (uname, type, pg);
	  goto ret_place2;
	}
      else if (__proc_exists ('sioc.DBA.ods_obj_describe') is not null)
	{
	  ses := sioc..ods_obj_describe (iri, type, pg);
	  goto ret_place2;
	}
      else if (regexp_match ('https?://([^/]*)/dataspace/([^/]*)(#this|/sioc.rdf|/sioc.n3)?\x24', iri) is not null
	  and __proc_exists ('sioc.DBA.ods_sioc_obj_describe') is not null)
	{
	  tmp := sprintf_inverse (iri, 'http%s://%s/dataspace/%s', 0);
	  tmp := tmp[2];
	  pos := coalesce (strchr (tmp, '#'), strchr (tmp, '/'));
	  if (pos is not null)
	    uname := subseq (tmp, 0, pos);
          else
	    uname := tmp;
          ses := sioc..ods_sioc_obj_describe (uname, type, pg);
	  goto ret_place2;
	}
      if (__proc_exists ('sioc.DBA.ods_sioc_container_obj_describe') is not null)
	{
	  ses := sioc..ods_sioc_container_obj_describe (iri, type, pg);
	  goto ret_place2;
	}
      else
	{
	  DB.DBA.OdsIriDescribe (iri, type);
	  goto ret_place;
	}
    }
  if (isstring (gr) and length (gr))
    _from := sprintf (' FROM <%s>', gr);

  qr := sprintf ('describe <%s> %s', iri, _from);
  path := vector ();
  --dbg_obj_print (qr);
  params := vector ('query', qr, 'format', 'application/rdf+xml');
  lines := vector ();
  WS.WS."/!sparql/" (path, params, lines);
ret_place:
  ses := http_get_string_output (1);
ret_place2:
  --dbg_obj_print (string_output_string (ses));
  http_rewrite ();
  if (content_mode = 1)
   http (ses, content);
  else
   content := string_output_string (ses);
  return 0;
}
;

create function DB.DBA."RDFData_DAV_SYMLINK" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in uid integer, in gid integer, in auth_uid integer) returns any
{
  RDFData_log_message (current_proc_name ());
  return -20;
}
;

create function DB.DBA."RDFData_DAV_DEREFERENCE_LIST" (in detcol_id any, inout report_array any) returns any
{
  RDFData_log_message (current_proc_name ());
  return -20;
}
;

create function DB.DBA."RDFData_DAV_RESOLVE_PATH" (in detcol_id any, inout reference_item any, inout old_base varchar, inout new_base varchar) returns any
{
  return -20;
}
;

create function DB.DBA."RDFData_DAV_LOCK" (in path any, in id any, in type char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid integer) returns any
{
  RDFData_log_message (current_proc_name ());
  return -20;
}
;


create function DB.DBA."RDFData_DAV_UNLOCK" (in id any, in type char(1), in token varchar, in auth_uid integer)
{
  RDFData_log_message (current_proc_name ());
  return -27;
}
;

create function DB.DBA."RDFData_DAV_IS_LOCKED" (inout id any, inout type char(1), in owned_tokens varchar) returns integer
{
  RDFData_log_message (current_proc_name ());
  return 0;
}
;


create function DB.DBA."RDFData_DAV_LIST_LOCKS" (in id any, in type char(1), in recursive integer) returns any
{
  RDFData_log_message (current_proc_name ());
  return vector ();
}
;

create procedure DB.DBA."RDFData_MAKE_DET_COL" (in path varchar, in gr varchar := null, in lg varchar := null)
{
  declare colid int;
  colid := DAV_MAKE_DIR (path, http_dav_uid (), null, '110100100N');
  if (colid < 0)
    signal ('42000', 'Unable to create RDFData DET collection');
  update WS.WS.SYS_DAV_COL set COL_DET='RDFData' where COL_ID = colid;
  if (gr is not null)
    DAV_PROP_SET_INT (path, 'virt:rdfdata_graph', gr, null, null, 0, 0, 1, http_dav_uid ());
  if (lg is not null)
    DAV_PROP_SET_INT (path, 'virt:rdfdata_lang', lg, null, null, 0, 0, 1, http_dav_uid ());
}
;
