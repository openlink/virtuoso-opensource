--
--  sioc.sql
--
--  $Id$
--
--  Procedures to support the SIOC & FOAF Ontologies RDF data in ODS using RDF-VIEWS.
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

use sioc;

create procedure get_cname ()
{
  return DB.DBA.wa_cname ();
};

create procedure get_base_path ()
{
  return '/dataspace';
};

create procedure get_graph ()
{
  return sprintf ('http://%s%s', get_cname (), get_base_path ());
};

create procedure get_ods_link ()
{
  return sprintf ('http://%s/ods', get_cname ());
};

-- IRIs of the ontologies used for ODS RDF data

create procedure foaf_iri (in s varchar)
{
  return concat ('http://xmlns.com/foaf/0.1/', s);
};

create procedure sioc_iri (in s varchar)
{
  return concat ('http://rdfs.org/sioc/ns#', s);
};

create procedure rdf_iri (in s varchar)
{
  return concat ('http://www.w3.org/1999/02/22-rdf-syntax-ns#', s);
};

create procedure rdfs_iri (in s varchar)
{
  return concat ('http://www.w3.org/2000/01/rdf-schema#', s);
};

create procedure geo_iri (in s varchar)
{
  return concat ('http://www.w3.org/2003/01/geo/wgs84_pos#', s);
};

create procedure atom_iri (in s varchar)
{
  return concat ('http://atomowl.org/ontologies/atomrdf#', s);
};

create procedure dc_iri (in s varchar)
{
  return concat ('http://purl.org/dc/elements/1.1/', s);
};

create procedure dcterms_iri (in s varchar)
{
  return concat ('http://purl.org/dc/terms/', s);
};

create procedure skos_iri (in s varchar)
{
  return concat ('http://www.w3.org/2004/02/skos/core#', s);
};

create procedure make_href (in u varchar)
{
  return WS.WS.EXPAND_URL (sprintf ('http://%s/', get_cname ()), u);
};

-- ODS object to IRI functions

create procedure user_obj_iri (in _u_name varchar)
{
  return sprintf ('http://%s%s/%U', get_cname(), get_base_path (), _u_name);
};

create procedure user_site_iri (in _u_name varchar)
{
  return user_obj_iri (_u_name) || '#site';
};

create procedure user_iri (in _u_id int)
{
  declare _u_name varchar;
  declare exit handler for not found { return null; };
  select u_name into _u_name from DB.DBA.SYS_USERS where U_ID = _u_id and U_IS_ROLE = 0 and U_ACCOUNT_DISABLED = 0;
  return user_obj_iri (_u_name);
};

create procedure user_group_iri (in _g_id int)
{
  declare _u_name varchar;
  declare exit handler for not found { return null; };
  select u_name into _u_name from DB.DBA.SYS_USERS where U_ID = _g_id and U_IS_ROLE = 1;
  return user_obj_iri (_u_name);
};

create procedure role_iri (in _wai_id int, in _wam_member_id int)
{
  declare _role, inst, _member, tp, m_type any;
  declare exit handler for not found { return null; };


  select WAI_NAME, U_NAME, WAI_TYPE_NAME, WAM_MEMBER_TYPE into inst, _member, tp, m_type
      from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME and WAI_ID = _wai_id
      and WAM_USER = _wam_member_id and U_ID = WAM_USER;

  _role := (select WMT_NAME from DB.DBA.WA_MEMBER_TYPE where WMT_APP = tp and WMT_ID = m_type);

  if (_role is null and m_type = 1)
    _role := 'owner';

  tp := DB.DBA.wa_type_to_app (tp);
  return sprintf ('http://%s%s/%U/%U/%U#%U', get_cname(), get_base_path (), _member, tp, inst, _role);
};


create procedure role_iri_by_name (in _wai_name varchar, in _wam_member_id int)
{
  declare _role, inst, _member, tp, m_type any;
  declare exit handler for not found { return null; };

  select WAM_INST, U_NAME, WAM_APP_TYPE, WAM_MEMBER_TYPE into inst, _member, tp, m_type
      from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER where WAM_INST = _wai_name
      and WAM_USER = _wam_member_id and U_ID = WAM_USER;

  _role := (select WMT_NAME from DB.DBA.WA_MEMBER_TYPE where WMT_APP = tp and WMT_ID = m_type);

  if (_role is null and m_type = 1)
    _role := 'owner';

  tp := DB.DBA.wa_type_to_app (tp);
  return sprintf ('http://%s%s/%U/%U/%U#%U', get_cname(), get_base_path (), _member, tp, inst, _role);
};


create procedure forum_iri (in inst_type varchar, in wai_name varchar)
{
  declare _member, tp varchar;
  tp := DB.DBA.wa_type_to_app (inst_type);
  declare exit handler for not found { return null; };
  if (inst_type = 'nntpf')
    return sprintf ('http://%s%s/%U/%U', get_cname(), get_base_path (), tp, wai_name);

  select U_NAME into _member from DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS where WAM_INST = wai_name and WAM_USER = U_ID and WAM_MEMBER_TYPE = 1;
  return sprintf ('http://%s%s/%U/%U/%U', get_cname(), get_base_path (), _member, tp, wai_name);
};

create procedure post_iri (in u_name varchar, in inst_type varchar, in wai_name varchar, in post_id varchar)
{
  declare tp varchar;
  tp := DB.DBA.wa_type_to_app (inst_type);
  return sprintf ('http://%s%s/%U/%U/%U/%s', get_cname(), get_base_path (), u_name, tp, wai_name, post_id);
};

create procedure forum_iri_n (in inst_type varchar, in wai_name varchar, in n_wai_name varchar)
{
  declare _member, tp varchar;
  tp := DB.DBA.wa_type_to_app (inst_type);
  declare exit handler for not found { return null; };
  select U_NAME into _member from DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS where WAM_INST = wai_name and WAM_USER = U_ID and WAM_MEMBER_TYPE = 1;
  return sprintf ('http://%s%s/%U/%U/%U', get_cname(), get_base_path (), _member, tp, n_wai_name);
};

create procedure user_iri_ent (in sne int)
{
  declare _u_name varchar;
  declare exit handler for not found { return null; };
  select sne_name into _u_name from DB.DBA.sn_entity where sne_id = sne;
  return sprintf ('http://%s%s/%U', get_cname(), get_base_path (), _u_name);
};

create procedure  blog_iri (in wai_name varchar)
{
  return forum_iri ('WEBLOG2', wai_name);
};

create procedure wiki_iri (in wai_name varchar)
{
  return forum_iri ('oWiki', wai_name);
};

create procedure feeds_iri (in wai_name varchar)
{
  return forum_iri ('eNews2', wai_name);
};

create procedure briefcase_iri (in wai_name varchar)
{
  return forum_iri ('oDrive', wai_name);
};

create procedure xd_iri (in wai_name varchar)
{
  return forum_iri ('Community', wai_name);
};

create procedure bmk_iri (in wai_name varchar)
{
  return forum_iri ('Bookmark', wai_name);
};

create procedure mail_iri (in wai_name varchar)
{
  return forum_iri ('oMail', wai_name);
};

create procedure photo_iri (in wai_name varchar)
{
  return forum_iri ('oGallery', wai_name);
};

create procedure nntp_iri (in grp varchar)
{
  return forum_iri ('nntpf', grp);
};

create procedure ods_sioc_clean_all ()
{
  declare graph_iri varchar;
  graph_iri := get_graph ();
  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
};


create procedure person_iri (in iri varchar)
{
  return iri || '#person';
};

create procedure wa_user_pub_info (in flags varchar, in fld int)
{
  declare r any;
  if (length (flags) <= fld)
    return 0;
  r := atoi (chr (flags[fld]));
  if (r = 1)
    return 1;
  return 0;
};

create procedure sioc_date (in d any)
{
  declare str any;
  str := DB.DBA.date_iso8601 (dt_set_tz (d, 0));
  return substring (str, 1, 19) || 'Z';
};


create procedure nntp_post_iri (in grp varchar, in msgid varchar)
{
  return sprintf ('http://%s%s/discussion/%U/%U', get_cname(), get_base_path (), grp, msgid);
};


create procedure dav_res_iri (in path varchar)
{
  return sprintf ('http://%s%s', get_cname(), path);
};

create procedure rdf_head (inout ses any)
{
  http ('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">', ses);
};

create procedure rdf_tail (inout ses any)
{
  http ('</rdf:RDF>', ses);
};

create procedure sioc_compose_xml (in u_name varchar, in wai_name varchar, in inst_type varchar, in postid varchar := null,
				   in p int := null)
{
  declare state, tp, qry, msg, maxrows, metas, rset, graph, iri, offs any;
  declare ses any;

  set isolation='uncommitted';

  -- dbg_obj_print (u_name,wai_name,inst_type,postid);
  graph := get_graph ();
  ses := string_output ();


  if (inst_type = 'users')
    inst_type := null;

  if (u_name is null)
    {
      -- http://cname/dataspace/about.rdf
      qry := sprintf (
      		'sparql  ' ||
		' define input:storage "http://www.openlinksw.com/schemas/virtrdf#ODS" ' ||
		'prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> '||
		'prefix foaf: <http://xmlns.com/foaf/0.1/> '||
		'prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> '||
		'prefix dc: <http://purl.org/dc/elements/1.1/> '||
		'prefix dct: <http://purl.org/dc/terms/> '||
		'construct { '||
		  '<%s#users> rdf:type foaf:Group . '||
		  '<%s#users> foaf:member ?s . '||
		  '?s rdf:type foaf:Agent . '||
		  '?s foaf:nick ?nick . '||
		  '?s foaf:name ?name . '||
		  '?s rdfs:seeAlso ?sa . ' ||
		  '?sa dc:format "application/rdf+xml" '||
		  '} from <%s> '||
		  'where { ?s rdf:type foaf:Person . '||
		  '?s foaf:nick ?nick . '||
		  '?s rdfs:seeAlso ?sa . '||
		  'optional { ?s foaf:name ?name } . '||
		  '}', graph, graph, graph, graph, graph);
    }
  else if (wai_name is null and inst_type is null and postid is null)
    {
      -- http://cname/dataspace/uname/sioc.rdf
      iri := user_obj_iri (u_name);
      qry := sprintf ('sparql ' ||
      ' define input:storage "http://www.openlinksw.com/schemas/virtrdf#ODS" ' ||
         ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' ||
         ' prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> '||
         ' prefix foaf: <http://xmlns.com/foaf/0.1/> \n' ||
   	 ' prefix sioc: <http://rdfs.org/sioc/ns#> \n' ||
         ' prefix dc: <http://purl.org/dc/elements/1.1/> '||
         ' prefix dct: <http://purl.org/dc/terms/> '||
         ' prefix atom: <http://atomowl.org/ontologies/atomrdf#> \n' ||
         ' CONSTRUCT {

	 ?user sioc:id ?u_id .
	 ?user sioc:name ?u_name .
	 ?user sioc:email ?u_email .
	 ?user sioc:email_sha1 ?u_sha1 .
	 ?user sioc:account_of ?person .
	 ?person foaf:holdsAccount ?user .
	 ?person rdfs:seeAlso ?p_see_also .

	 ?forum sioc:has_member ?user .
	 ?forum sioc:type ?f_type .
	 ?forum rdfs:seeAlso ?f_see_also .
	 ?forum sioc:id ?f_id .
	 ?forum sioc:has_host ?f_host .
	 ?f_host sioc:host_of ?forum .
	 ?role sioc:has_scope ?forum .
	 ?user sioc:has_function ?role .
	 ?f_host sioc:link ?h_link .

	 } \n' ||
         ' FROM <%s> WHERE {

	 ?user 	sioc:id "%s" ;
	       	sioc:id ?u_id ;
	   	sioc:email ?u_email ;
	   	sioc:email_sha1 ?u_sha1 ;
		sioc:account_of ?person .
         ?person rdfs:seeAlso ?p_see_also .
         optional { ?user sioc:name ?u_name } .

	 optional { ?user sioc:has_function ?role .
	   	?role sioc:has_scope ?forum .
	  	?forum sioc:has_member ?user ;
		    sioc:type ?f_type ;
		    rdfs:seeAlso ?f_see_also ;
		    sioc:id ?f_id ;
		    sioc:has_host ?f_host .
	        ?f_host  sioc:link ?h_link .
	 } .


	 } ',
	 graph, u_name);
    }
  else if (wai_name is null and postid is null)
    {
      -- http://cname/dataspace/uname/app/sioc.rdf
      signal ('22023', 'No instance name is given.');
    }
  else if (postid is null)
    {
      -- http://cname/dataspace/uname/app/instance/sioc.rdf
      declare triples, num any;
      declare lim any;

      lim := coalesce (DB.DBA.USER_GET_OPTION (u_name, 'SIOC_POSTS_QUERY_LIMIT'), 10);
      offs := coalesce (p, 0) * lim;
      tp := DB.DBA.wa_type_to_app (inst_type);

      if (inst_type = 'discussion')
	iri := forum_iri ('nntpf', wai_name);
      else
        iri := forum_iri (inst_type, wai_name);

      set_user_id ('dba');

      rdf_head (ses);
      qry := sprintf ('sparql
          define input:storage "http://www.openlinksw.com/schemas/virtrdf#ODS"
   	  prefix sioc: <http://rdfs.org/sioc/ns#>
	  prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	  prefix dc: <http://purl.org/dc/elements/1.1/>
          construct
	        {
		  ?host sioc:host_of ?forum .
		  ?host sioc:link ?link .
		  ?host dc:title ?title .
		  ?host rdf:type sioc:Site .
	        } where
            	{
		  graph <%s>
		  {
		    ?host sioc:host_of ?forum . ?forum sioc:id "%s" .
		    ?host sioc:link ?link . optional { ?host dc:title ?title } .
		  }
		}', graph, wai_name
	    );
      rset := null;
      maxrows := 0;
      state := '00000';
      dbg_printf ('HOST:\n%s', qry);
      exec (qry, state, msg, vector(), maxrows, metas, rset);
--      dbg_obj_print (msg);
      if (state = '00000')
	{
	  triples := rset[0][0];
          rset := dict_list_keys (triples, 1);
          DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (rset, 0, ses);
	}
      else
	signal (state, msg);

      qry := sprintf ('sparql
          define input:storage "http://www.openlinksw.com/schemas/virtrdf#ODS"
   	  prefix sioc: <http://rdfs.org/sioc/ns#>
	  prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	  prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
	  prefix dc: <http://purl.org/dc/elements/1.1/>
          construct {
			?forum sioc:id ?id .
			?forum sioc:type sioc:Forum .
			?forum sioc:link ?link .
			?forum sioc:description ?descr .
			?forum sioc:has_member ?member .
			?member rdfs:seeAlso ?see_also .
			?forum sioc:has_host ?host .
			?forum sioc:type ?type
		    } where
            	{
		  graph <%s>
		  {
		    ?forum sioc:id "%s" .
		    ?forum sioc:id ?id .
		    ?forum sioc:link ?link .
		    ?forum sioc:description ?descr .
		    ?forum sioc:has_member ?member .
		    ?member rdfs:seeAlso ?see_also .
		    ?forum sioc:has_host ?host .
		    ?forum sioc:type ?type
		  }
		}', graph, wai_name
	    );
      rset := null;
      maxrows := 0;
      state := '00000';
      dbg_printf ('FORUM:\n%s', qry);
      exec (qry, state, msg, vector(), maxrows, metas, rset);
--      dbg_obj_print (msg);
      if (state = '00000')
	{
	  triples := rset[0][0];
          rset := dict_list_keys (triples, 1);
          DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (rset, 0, ses);
	}
      else
	signal (state, msg);

      if (tp = 'feeds' or tp = 'community')
	{
	  qry := sprintf ('sparql
              define input:storage "http://www.openlinksw.com/schemas/virtrdf#ODS"
	      prefix sioc: <http://rdfs.org/sioc/ns#>
	      prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	      prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
	      prefix dc: <http://purl.org/dc/elements/1.1/>
              prefix dct: <http://purl.org/dc/terms/>
	      construct
	       {
		    ?forum sioc:has_parent <%s> .
		    <%s> sioc:parent_of ?forum .
		    ?forum sioc:container_of ?post .
		    ?post  sioc:has_container ?forum .
		    ?post rdf:type sioc:Post .
		    ?post rdfs:seeAlso ?post_see_also
	       }
	      where
		    {
		      graph <%s>
		      {
			<%s> sioc:parent_of ?forum .
			?post sioc:has_container ?forum .
			?post rdfs:seeAlso ?post_see_also .
			?post dct:created ?created .
			#optional { ?post sioc:reply_of ?reply_of }
			#filter bif:isnull (?reply_of)
		      }
		    }
		    order by desc (?created) limit %d offset %d
		', iri, iri, graph, iri, lim, offs);
	}
      else
	{
	  qry := sprintf ('sparql
              define input:storage "http://www.openlinksw.com/schemas/virtrdf#ODS"
	      prefix sioc: <http://rdfs.org/sioc/ns#>
	      prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	      prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
	      prefix dc: <http://purl.org/dc/elements/1.1/>
              prefix dct: <http://purl.org/dc/terms/>
	      prefix foaf: <http://xmlns.com/foaf/0.1/>
	      construct
	       {
		    <%s> sioc:container_of ?post .
		    ?post  sioc:has_container <%s> .
		    ?post rdf:type sioc:Post .
		    ?post rdfs:seeAlso ?post_see_also
	       }
	      where
		    {
		      graph <%s>
		      {
			<%s> sioc:container_of ?post .
			?post rdfs:seeAlso ?post_see_also .
		        optional { ?post dct:created ?created } .
			optional { ?post sioc:has_creator ?creator } .
			optional { ?post sioc:reply_of ?reply_of } .
			#filter bif:isnull (?reply_of)
		      }
		    }
		    order by desc (?created) limit %d offset %d
		', iri, iri, graph, iri, lim, offs);
	}
      rset := null;
      maxrows := 0;
      state := '00000';
      msg := '';
      dbg_printf ('POSTS:\n%s', qry);
      exec (qry, state, msg, vector(), maxrows, metas, rset);
--      dbg_obj_print (msg);
      if (state = '00000')
	{
	  triples := rset[0][0];
	  rset := dict_list_keys (triples, 1);
	  DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (rset, 0, ses);
	  -- seeAlso for the rest of posts
	  if (length (rset))
	    {
	      http (sprintf ('<rdf:Description rdf:about="%s">', iri), ses);
	      http (sprintf
	      	('<rdfs:seeAlso xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" rdf:resource="%s/sioc.rdf?p=%d" />',
		    iri, coalesce (p, 0) + 1), ses);
	      http ('</rdf:Description>', ses);
	    }
        }
      else
	{
	  signal (state, msg);
	}
      rdf_tail (ses);
      goto ret;
    }
  else -- the post
    {
      declare has_par int;
      has_par := 0;
      -- http://cname/dataspace/uname/app/instance/post/sioc.rdf
--      dbg_obj_print (u_name, inst_type, wai_name, postid);

      if (inst_type = 'feed' or inst_type = 'community')
	has_par := 1;

      if (inst_type = 'feed')
        iri := feed_item_iri (atoi(wai_name), atoi(postid));
      else if (inst_type = 'discussion')
	iri := nntp_post_iri (wai_name, postid);
      else
        iri := post_iri (u_name, inst_type, wai_name, postid);
--      dbg_obj_print (iri, md5(iri));
      qry := sprintf ('sparql
          define input:storage "http://www.openlinksw.com/schemas/virtrdf#ODS"
          prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' ||
	 ' prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ' ||
   	 ' prefix sioc: <http://rdfs.org/sioc/ns#> \n' ||
         ' prefix dc: <http://purl.org/dc/elements/1.1/> '||
         ' prefix dct: <http://purl.org/dc/terms/> '||
	 ' prefix foaf: <http://xmlns.com/foaf/0.1/> '||
	 ' prefix skos: <http://www.w3.org/2004/02/skos/core#> '||
         ' construct {
	            ?post rdf:type sioc:Post .
	   	    ?post sioc:has_container ?forum .
		    ?forum sioc:container_of ?post .  ?forum rdfs:seeAlso ?see_also .
	   	    #comment ?forum sioc:has_parent ?pforum . ?pforum rdfs:seeAlso ?psee_also .
	   	    #comment ?pforum sioc:parent_of ?forum .
		    ?post dc:title ?title .
		    ?post sioc:link ?link .
		    ?post sioc:links_to ?links_to .
		    ?post dct:modified ?modified .
		    ?post dct:created ?created .
		    ?post sioc:has_creator ?creator .
		    ?post sioc:has_reply ?reply .
		    ?reply sioc:reply_of ?post .
		    ?reply rdfs:seeAlso ?reply_see_also .
		    ?post sioc:reply_of ?reply_of .
		    ?reply_of sioc:has_reply ?post .
		    ?reply_of rdfs:seeAlso ?reply_of_see_also .
		    ?post sioc:content ?content .
		    ?post sioc:attachment ?att .
		    ?post foaf:maker ?maker .
		    ?maker rdfs:seeAlso ?maker_see_also .
		    ?post sioc:topic ?skos_topic .
	   	    ?skos_topic rdf:type skos:Concept .
	   	    ?skos_topic skos:prefLabel ?skos_label .
		    ?skos_topic skos:isSubjectOf ?post .
		    ?creator rdfs:seeAlso ?cr_see_also .
		    ?maker rdf:type foaf:Person .
	 }
           from <%s> where {
	   #?post sioc:id "%s" .
	   ?post sioc:has_container ?forum .
	   optional { ?forum rdfs:seeAlso ?see_also . } .
	   #comment optional { ?forum sioc:has_parent ?pforum . ?pforum rdfs:seeAlso ?psee_also . } .
	   optional { ?post dct:modified ?modified } .
	   optional { ?post dct:created ?created } .
	   optional { ?post sioc:links_to ?links_to } .
	   optional { ?post sioc:link ?link } .
	   optional { ?post sioc:has_creator ?creator . ?creator rdfs:seeAlso ?cr_see_also  . } .
	   optional { ?post sioc:has_reply ?reply .
	     	      ?reply rdfs:seeAlso ?reply_see_also
	   	    } .
	   optional { ?post sioc:reply_of ?reply_of .
	     	      ?reply_of rdfs:seeAlso ?reply_of_see_also
	   	    } .
	   optional { ?post sioc:attachment ?att } .
	   optional { ?post dc:title ?title } .
	   optional { ?post sioc:topic ?skos_topic . ?skos_topic skos:prefLabel ?skos_label } .
	   optional { ?post sioc:content ?content } .
	   optional { ?post foaf:maker ?maker . optional { ?maker rdfs:seeAlso ?maker_see_also } .
		    optional { ?maker foaf:name ?foaf_name .  } . optional { ?maker foaf:mbox ?foaf_mbox } } .
	  } ',
	 graph, md5(iri));

	 if (has_par)
	   qry := replace (qry, '#comment', '');

	 qry := replace (qry, '?post', '<'||iri||'>');
    }

  maxrows := 0;
  state := '00000';
  dbg_printf ('%s', qry);
  set_user_id ('dba');
  exec (qry, state, msg, vector(), maxrows, metas, rset);
--  dbg_obj_print (msg);
  if (state = '00000')
    DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, '', 1);
  else
    signal (state, msg);

ret:
  return ses;
};


use DB;


