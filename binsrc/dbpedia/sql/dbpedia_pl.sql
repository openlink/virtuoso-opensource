--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2024 OpenLink Software
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


create procedure DB.DBA.DBP_GRAPH_PARAM1 (in par varchar, in fmt varchar, in val varchar)
{
  declare tmp any;
  tmp := sprintf ('default-graph-uri=%U', registry_get ('dbp_graph'));
  if (par = 'gr')
    {
      val := trim (val, '/');
      if (length (val) = 0)
	val := '';
      if (val = 'en')
        val := '';
      if (val <> '')
	{
          val := 'http://' || val || '.dbpedia.org';
	  tmp := tmp || sprintf ('&named-graph-uri=%U', val);
	}
    }
  else
    tmp := val;
  return sprintf (fmt, tmp);
}
;


create procedure DB.DBA.DBP_LINK_HDR (in in_path varchar)
{
  declare host, lines, accept, loc, alt, exp, lic any;
  lines := http_request_header ();
--  dbg_obj_print ('in_path: ', in_path);
--  dbg_obj_print ('lines: ', lines);
  loc := ''; alt := ''; exp := '';
  host := http_request_header(lines, 'Host', null, '');
  if (regexp_match ('/data/([a-z_\\-]*/)?(.*)\\.(nt|n3|rdf|ttl|jrdf|jsonld|xml|atom|json|jsod|ntriples)', in_path) is null and in_path like '/data/%')
    {
      declare tmp any;
      accept := http_request_header(lines, 'Accept', null, 'application/rdf+xml');
      accept := regexp_match ('(application/rdf.xml)|(text/rdf.n3)|(text/n3)', accept);
      tmp := split_and_decode (in_path, 0, '\0\0/');
      if (length (tmp) and strstr (http_header_get (), 'Content-Location') is null)
	{
	  tmp := tmp [ length (tmp) - 1 ];
	  if (accept is null)
	    accept := 'application/rdf+xml';
	  if (accept = 'application/rdf+xml')
	    loc := 'Content-Location: ' || tmp || '.xml\r\n';
	  else if (accept = 'text/rdf+n3')
	    loc := 'Content-Location: ' || tmp || '.n3\r\n';
	  else if (accept = 'text/n3')
	    loc := 'Content-Location: ' || tmp || '.n3\r\n';
	}
    }
  if (in_path like '/data/%')
    {
      declare ext any;
      declare p varchar;
      ext := vector (vector ('xml', 'RDF/XML', 'application/rdf+xml'), vector ('n3', 'N3/Turtle', 'text/n3'), vector ('json', 'RDF/JSON', 'application/json'));
      foreach (any ss in ext) do
	{
	  declare s varchar;
	  s := ss[0];
	  if (in_path not like '/data/%.'||s)
	    {
	      p := regexp_replace (in_path, '\\.(nt|n3|rdf|ttl|jrdf|xml|json|atom|jsod|jsonld|ntriples)\x24', '.'||s);
	      alt := alt || sprintf ('<http://%s%s>; rel="alternate"; type="%s"; title="Structured Descriptor Document (%s format)", ', host, p, ss[2], ss[1]);
	    }
	}
      if (in_path not like '/data/%.atom')
	{
	  p := regexp_replace (in_path, '\\.(nt|n3|rdf|ttl|jrdf|xml|json|jsonld|atom)\x24', '.atom');
	  alt := alt || sprintf ('<http://%s%s>; rel="alternate"; type="application/atom+xml"; title="OData (Atom+Feed format)", ', host, p);
	}
      if (in_path not like '/data/%.jsod')
	{
	  p := regexp_replace (in_path, '\\.(nt|n3|rdf|ttl|jrdf|xml|json|jsonld|atom)\x24', '.jsod');
	  alt := alt || sprintf ('<http://%s%s>; rel="alternate"; type="application/odata+json"; title="OData (JSON format)", ', host, p);
	}
      p := regexp_replace (in_path, '\\.(n3|nt|rdf|ttl|jrdf|xml|json|jsonld|atom)\x24', '');
      p := replace (p, '/data/', '/page/');
      alt := alt || sprintf ('<http://%s%s>; rel="alternate"; type="text/html"; title="XHTML+RDFa", ', host, p);
      p := replace (p, '/page/', '/resource/');
      if (in_path not like '/resource/%')
	{
	  alt := alt || sprintf ('<http://%s%s>; rel="http://xmlns.com/foaf/0.1/primaryTopic", ', host, p);
	  alt := alt || sprintf ('<http://%s%s>; rev="describedby", ', host, p);
	}
      else
	{
	  alt := alt || sprintf ('<http://%s%s>; rev="http://xmlns.com/foaf/0.1/primaryTopic", ', host, p);
	  alt := alt || sprintf ('<http://%s%s>; rel="describedby", ', host, p);
	}
      if (registry_get ('dbp_pshb_hub') <> 0)
	alt := alt || sprintf ('<%s>; rel="hub", ', registry_get ('dbp_pshb_hub'));
      exp := sprintf ('Expires: %s\r\n', date_rfc1123 (dateadd ('day', 7, now ())));
    }
  lic := '<http://creativecommons.org/licenses/by-sa/3.0/>; rel="license", ';
  return sprintf ('%s%sLink: %s%s<http://dbpedia.mementodepot.org/timegate/http://%s%s>; rel="timegate"', exp, loc, lic, alt, host, in_path);
}
;


create procedure DB.DBA.DBP_DATA_IRI1 (in par varchar, in fmt varchar, in val varchar)
{
  if (par = 'par_2' and length (val))
    {
      declare arr any;
      arr := split_and_decode (val);
      if (length (arr) > 1 and arr[1] <> 'en' and length (arr[1]))
	return sprintf (fmt, arr[1] || '/');
      val := '';
    }
  return sprintf (fmt, val);
}
;


create procedure DB.DBA.DBP_TCN_LOC (in id any, in var any)
{
  return var;
}
;



create procedure ensure_demo_user ()
{
    if (exists (select 1 from SYS_USERS where U_NAME = 'demo'))
	return;
	exec ('create user "demo"');
	DB.DBA.user_set_qualifier ('demo', 'Demo');
};

ensure_demo_user ();

drop procedure ensure_demo_user;


create procedure create_demo_home ()
{
  declare pwd any;
  pwd := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = 'dav');
  DAV_COL_CREATE ('/DAV/home/', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', pwd);
  DAV_COL_CREATE ('/DAV/home/demo/', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', pwd);
  DAV_COL_CREATE ('/DAV/home/demo/dbpedia/', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', pwd);
};

create_demo_home ();
drop procedure create_demo_home;


create procedure upload_isparql ()
{
  declare base varchar;
  declare pwd any;
  pwd := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = 'dav');
  base := registry_get('_dbpedia_path_');
  if (base like '/DAV/%')
    {
      for select RES_FULL_PATH from WS..SYS_DAV_RES where RES_FULL_PATH like base||'%.isparql' do
	{
	  DAV_COPY (RES_FULL_PATH, '/DAV/home/demo/dbpedia/', 0, '111101101NN', 'dav', 'administrators', 'dav', pwd);
	}
    }
  else
    {
      declare arr any;
      arr := sys_dirlist (base);
      foreach (varchar f in arr) do
	{
	  if (f like '%.isparql')
	    DAV_RES_UPLOAD ('/DAV/home/demo/dbpedia/'||f, file_to_string (base||f), '', '110100100R', http_dav_uid(), http_dav_gid(), 'dav', pwd);
	}
    }
  -- the current trigger of isparql have bug
  update WS..SYS_DAV_RES set RES_PERMS = '110100100NN' where RES_FULL_PATH like '/DAV/home/demo/dbpedia/%';
}
;

upload_isparql ();
drop procedure upload_isparql;



