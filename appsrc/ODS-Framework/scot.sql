--
--  scot.sql
--
--  $Id$
--
--  Procedures to support the SCOT Ontology RDF data in ODS.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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

db.dba.wa_exec_ddl ('create table inst_tag_stats (
    its_inst_id int,
    its_tag_cnt int default 0,
    its_tag_freq int default 0,
    its_co_cnt int default 0,
    its_co_freq int default 0,
    its_post_cnt int default 0,
    primary key (its_inst_id))');

db.dba.wa_exec_ddl ('create table tag_stat  (
    ts_inst_id int,
    ts_tag varchar,
    ts_afreq int default 0,
    ts_rfreq float default 0,
    primary key (ts_inst_id, ts_tag))');

db.dba.wa_exec_ddl ('create table tag_coocurrence (
    tc_inst_id int,
    tc_id int,
    tc_tag  varchar,
    primary key (tc_inst_id, tc_id, tc_tag))');

db.dba.wa_exec_ddl ('create table tag_coocurrence_stats (
    tcs_inst_id int,
    tcs_id int identity,
    tcs_afreq int default 0,
    tcs_rfreq float default 0,
    tcs_tags_cnt int default 0,
    tcs_tags_stats long varchar,
    primary key (tcs_inst_id, tcs_id))');

db.dba.wa_exec_ddl ('create text index on tag_coocurrence_stats (tcs_tags_stats) with key tcs_id');

create procedure tags_normalize (inout tags any)
{
  declare arr any;
  declare tarr any;
  arr := split_and_decode (tags, 0, '\0\0,');
  tarr := dict_new ();
  foreach (any elm in arr) do
    {
      elm := trim(elm);
      elm := replace (elm, ' ', '_');
      if (length (elm))
	{
	  dict_put (tarr, elm, 0);
	}
    }
  tarr := dict_list_keys (tarr, 1);
  tarr := __vector_sort (tarr);
  tags := tarr;
}
;

create procedure tags_str (in tags any)
{
  declare ret varchar;
  ret := '';
  foreach (any t in tags) do
   ret := ret || t || ' ';
  return rtrim (ret);
}
;

create procedure tags_expr (in tags any)
{
  declare ret varchar;
  ret := '';
  foreach (any t in tags) do
   ret := ret ||'"'|| t || '" AND ';
  ret := substring (ret, 1, length (ret) - 5);
  return ret;
}
;

create procedure scot_tags_insert (in inst_id int, in post_iri any, in tags varchar)
{
  declare tag_cnt, co_cnt int;
  declare tags_str, tags_exp, tc_id varchar;
  declare total_tags, total_co, tag_freq, co_freq int;

  scot_rdf_delete (sioc..get_graph (), inst_id, 1);
  tags_normalize (tags);
  tag_cnt := length (tags);
  if (tag_cnt = 0)
    return;
  tags_str := tags_str (tags);
  tags_exp := tags_expr (tags);
  if (tag_cnt > 1)
    {
      commit work;
      {
        declare exit handler for sqlstate '37000' { rollback work; return; };
        tc_id := (select tcs_id from tag_coocurrence_stats where
          contains (tcs_tags_stats, tags_exp) and tcs_inst_id = inst_id and tcs_tags_cnt = tag_cnt);
      }
      if (tc_id is null)
	{
	  insert into tag_coocurrence_stats (tcs_inst_id, tcs_tags_cnt, tcs_tags_stats, tcs_afreq) values
	      (inst_id, tag_cnt, tags_str, 1);
	}
      else
	{
	  update tag_coocurrence_stats set tcs_afreq = tcs_afreq + 1 where tcs_inst_id = inst_id and tcs_id = tc_id;
	}
    }
  foreach (any tag in tags) do
    {
      update tag_stat set ts_afreq = ts_afreq + 1 where ts_inst_id = inst_id and ts_tag = tag;
      if (row_count () = 0)
        insert into tag_stat (ts_inst_id, ts_tag, ts_afreq) values (inst_id, tag, 1);
      commit work;
      declare continue handler for sqlstate '37000' { rollback work; goto next_tag; };
      {
        for select tcs_id from tag_coocurrence_stats where contains (tcs_tags_stats, '"'||tag||'"') and tcs_inst_id = inst_id do
          {
	    insert soft tag_coocurrence (tc_inst_id, tc_id, tc_tag) values (inst_id, tcs_id, tag);
          }
      }
next_tag: ;
    }

  total_tags := (select count(*) from tag_stat where ts_inst_id = inst_id);
  total_co   := (select count(*) from tag_coocurrence_stats where tcs_inst_id = inst_id);
  tag_freq   := coalesce ((select sum (ts_afreq) from tag_stat where ts_inst_id = inst_id), 0);
  co_freq    := coalesce ((select sum (tcs_afreq) from tag_coocurrence_stats where tcs_inst_id = inst_id), 0);

  update inst_tag_stats set
      its_tag_freq = tag_freq,
      its_tag_cnt = total_tags,
      its_co_cnt = total_co,
      its_co_freq = co_freq,
      its_post_cnt = its_post_cnt + 1
      where its_inst_id = inst_id;
  scot_rdf_update (sioc..get_graph (), inst_id, post_iri, tags);
  return;
}
;

create procedure scot_tags_delete (in inst_id int, in post_iri any, in tags varchar)
{
  declare tag_cnt, co_cnt int;
  declare tags_str, tags_exp, tc_id varchar;
  declare total_tags, total_co, tag_freq, co_freq int;
  declare dummy any;

  scot_rdf_delete (sioc..get_graph (), inst_id);
  tags_normalize (tags);
  tag_cnt := length (tags);
  if (tag_cnt = 0)
    return;
  tags_str := tags_str (tags);
  tags_exp := tags_expr (tags);
  if (tag_cnt > 1)
    {
      commit work;
      {
        declare exit handler for sqlstate '37000' { rollback work; return; };
        tc_id := (select tcs_id from tag_coocurrence_stats where
        contains (tcs_tags_stats, tags_exp) and tcs_inst_id = inst_id and tcs_tags_cnt = tag_cnt);
      }
      if (tc_id is not null)
	{
	  update tag_coocurrence_stats set tcs_afreq = tcs_afreq - 1 where tcs_inst_id = inst_id and tcs_id = tc_id;
	}
    }
  foreach (any tag in tags) do
    {
      update tag_stat set ts_afreq = ts_afreq - 1 where ts_inst_id = inst_id and ts_tag = tag;
    }

  delete from tag_coocurrence where tc_inst_id = inst_id and tc_id
      in (select tcs_id from tag_coocurrence_stats where tcs_inst_id = inst_id and tcs_afreq <= 0);
  delete from tag_coocurrence_stats where tcs_inst_id = inst_id and tcs_afreq <= 0;
  delete from tag_stat where ts_inst_id = inst_id and ts_afreq <= 0;

  total_tags := (select count(*) from tag_stat where ts_inst_id = inst_id);
  total_co   := (select count(*) from tag_coocurrence_stats where tcs_inst_id = inst_id);
  tag_freq   := coalesce ((select sum (ts_afreq) from tag_stat where ts_inst_id = inst_id), 0);
  co_freq    := coalesce ((select sum (tcs_afreq) from tag_coocurrence_stats where tcs_inst_id = inst_id), 0);

  update inst_tag_stats set
      its_tag_freq = tag_freq,
      its_tag_cnt = total_tags,
      its_co_cnt = total_co,
      its_co_freq = co_freq,
      its_post_cnt = its_post_cnt + 1
      where its_inst_id = inst_id;
  dummy := vector ();
  scot_rdf_update (sioc..get_graph (), inst_id, post_iri, dummy);
  return;
}
;

create procedure scot_rdf_update (in graph_iri varchar, in inst_id int, in post_iri varchar, inout tags any)
{
  declare inst_iri, cloud_iri, tag_iri, co_iri, user_iri, person_iri any;
  declare title, uname varchar;

  declare exit handler for not found
    {
      return;
    };
  if (inst_id > 0)
    {
      select sioc..forum_iri (WAI_TYPE_NAME, WAI_NAME), U_NAME, WAI_NAME
	  into inst_iri, uname, title
	  from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
	  where WAI_ID = inst_id and WAI_NAME = WAM_INST and U_ID = WAM_USER and WAM_MEMBER_TYPE = 1;
    }
  else
    {
      declare gname varchar;
      select forum_iri ('nntpf', NG_NAME), NG_DESC into inst_iri, title from DB.DBA.NEWS_GROUPS where NG_GROUP = -1 * inst_id;
      uname := 'dav';
    }
  user_iri := user_obj_iri (uname);
  person_iri := person_iri (user_iri);
  cloud_iri := inst_iri || '/tagcloud';
  DB.DBA.ODS_QUAD_URI (graph_iri, cloud_iri, dc_iri ('creator'), person_iri);
  DB.DBA.ODS_QUAD_URI (graph_iri, user_iri, scot_iri ('hasSCOT'), cloud_iri);
  for select its_tag_cnt, its_tag_freq, its_co_cnt, its_co_freq, its_post_cnt from inst_tag_stats where its_inst_id = inst_id do
    {
      DB.DBA.ODS_QUAD_URI (graph_iri, cloud_iri, rdf_iri ('type'), scot_iri ('Tagcloud'));
      --DB.DBA.ODS_QUAD_URI (graph_iri, cloud_iri, scot_iri ('tagspace'), '~unknown~');
      DB.DBA.ODS_QUAD_URI_L (graph_iri, cloud_iri, scot_iri ('totalPosts'), its_post_cnt);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, cloud_iri, dc_iri ('title'), title || ' tagcloud');
      DB.DBA.ODS_QUAD_URI_L (graph_iri, cloud_iri, scot_iri ('totalTags'), its_tag_cnt);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, cloud_iri, scot_iri ('totalCooccurrences'), its_co_cnt);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, cloud_iri, scot_iri ('totalTagFrequency'), its_tag_freq);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, cloud_iri, scot_iri ('totalCooccurFrequency'), its_co_freq);
    }
  for select ts_tag, ts_afreq from tag_stat where ts_inst_id = inst_id do
    {
      tag_iri := inst_iri || '/tag/' || ts_tag;
      DB.DBA.ODS_QUAD_URI (graph_iri, tag_iri, rdf_iri ('type'), scot_iri ('Tag'));
      DB.DBA.ODS_QUAD_URI_L (graph_iri, tag_iri, scot_iri ('name'), ts_tag);
      DB.DBA.ODS_QUAD_URI (graph_iri, cloud_iri, scot_iri ('hasTag'), tag_iri);
      DB.DBA.ODS_QUAD_URI_L (graph_iri, tag_iri, scot_iri ('ownAFrequency'), ts_afreq);
      for select tc_id from tag_coocurrence where tc_inst_id = inst_id and tc_tag = ts_tag do
	{
	  co_iri := inst_iri || sprintf ('/Cooccurrence_%d', tc_id);
	  DB.DBA.ODS_QUAD_URI (graph_iri, tag_iri, scot_iri ('cooccurWith'), co_iri);
	}
    }
  for select tcs_id, tcs_afreq from tag_coocurrence_stats where tcs_inst_id = inst_id do
    {
      co_iri := inst_iri || sprintf ('/Cooccurrence_%d', tcs_id);
      DB.DBA.ODS_QUAD_URI (graph_iri, co_iri, rdf_iri ('type'), scot_iri ('Cooccurrence'));
      DB.DBA.ODS_QUAD_URI_L (graph_iri, co_iri, scot_iri ('cooccurAFrequency'), tcs_afreq);
      for select distinct tc_tag as tc_tag from tag_coocurrence where tc_id = tcs_id and tc_inst_id = inst_id do
	{
	  tag_iri := inst_iri || '/tag/' || tc_tag;
	  DB.DBA.ODS_QUAD_URI (graph_iri, co_iri, scot_iri ('cooccurTag'), tag_iri);
	}
    }
  if (length (post_iri))
    {
      declare meaning_iri varchar;
      foreach (any tag in tags) do
	{
	  tag_iri := inst_iri || '/tag/' || tag;
	  DB.DBA.ODS_QUAD_URI_L (graph_iri, tag_iri, skos_iri ('prefLabel'), tag);
	  DB.DBA.ODS_QUAD_URI (graph_iri, tag_iri, skos_iri ('isSubjectOf'), post_iri);
	  DB.DBA.ODS_QUAD_URI (graph_iri, post_iri, sioc_iri ('topic'), tag_iri);
	  -- MOAT
	  DB.DBA.ODS_QUAD_URI (graph_iri, tag_iri, rdf_iri ('type'), moat_iri ('Tag'));
	  DB.DBA.ODS_QUAD_URI_L (graph_iri, tag_iri, moat_iri ('name'), tag);
	  for select m_mid, m_uri from moat.DBA.moat_meanings where m_tag = tag and m_iri = iri_to_id (post_iri) do
	   {
	     meaning_iri := tag_iri || sprintf ('/meaning/%d', m_mid);
	     DB.DBA.ODS_QUAD_URI (graph_iri, tag_iri, moat_iri ('hasMeaning'), meaning_iri);
	     DB.DBA.ODS_QUAD_URI (graph_iri, meaning_iri, rdf_iri ('type'), moat_iri ('Meaning'));
	     DB.DBA.ODS_QUAD_URI (graph_iri, meaning_iri, moat_iri ('meaningURI'), m_uri);
	   }
	}
    }
}
;

create procedure scot_rdf_delete (in graph_iri varchar, in inst_id int, in only_stats int := 0)
{
  declare inst_iri, iri, meaning_iri any;

  declare exit handler for not found
    {
      return;
    };
  if (inst_id > 0)
    {
      select sioc..forum_iri (WAI_TYPE_NAME, WAI_NAME) into inst_iri from DB.DBA.WA_INSTANCE where WAI_ID = inst_id;
    }
  else
    {
      select forum_iri ('nntpf', NG_NAME) into inst_iri from DB.DBA.NEWS_GROUPS where NG_GROUP = -1 * inst_id;
    }
  iri := inst_iri || '/tagcloud';
  delete_quad_s_or_o (sioc..get_graph (), iri, iri);
  for select ts_tag, ts_afreq from tag_stat where ts_inst_id = inst_id do
    {
      iri := inst_iri || '/tag/' || ts_tag;
      if (only_stats)
	delete_quad_sp (sioc..get_graph (), iri, scot_iri ('ownAFrequency'));
      else
	{
	  delete_quad_s_or_o (sioc..get_graph (), iri, iri);
	  for select m_mid from moat.DBA.moat_meanings where m_tag = ts_tag do
	    {
	      meaning_iri := iri || sprintf ('/meaning/%d', m_mid);
	      delete_quad_s_or_o (sioc..get_graph (), meaning_iri, meaning_iri);
	    }
	}
    }
  for select tcs_id, tcs_afreq from tag_coocurrence_stats where tcs_inst_id = inst_id do
    {
      iri := inst_iri || sprintf ('/Cooccurrence_%d', tcs_id);
      if (only_stats)
	delete_quad_sp (sioc..get_graph (), iri, scot_iri ('cooccurAFrequency'));
      else
	delete_quad_s_or_o (sioc..get_graph (), iri, iri);
    }
}
;

create trigger WA_INST_SCOT_I after insert on DB.DBA.WA_INSTANCE referencing new as N
{
  insert into inst_tag_stats (its_inst_id) values (N.WAI_ID);
}
;

create trigger WA_INST_SCOT_D after delete on DB.DBA.WA_INSTANCE referencing old as O
{
  delete from inst_tag_stats where its_inst_id = O.WAI_ID;
}
;

create trigger tag_stat_d after delete on tag_stat referencing old as O
{
  declare inst_iri, iri any;
  inst_iri := (select sioc..forum_iri (WAI_TYPE_NAME, WAI_NAME) from DB.DBA.WA_INSTANCE where WAI_ID = O.ts_inst_id);
  iri := inst_iri || '/tag/' || O.ts_tag;
  delete_quad_s_or_o (sioc..get_graph (), iri, iri);
}
;

create trigger tag_coocurrence_stats_d after delete on tag_coocurrence_stats referencing old as O
{
  declare inst_iri, iri any;
  inst_iri := (select sioc..forum_iri (WAI_TYPE_NAME, WAI_NAME) from DB.DBA.WA_INSTANCE where WAI_ID = O.tcs_inst_id);
  iri := inst_iri || sprintf ('/Cooccurrence_%d', O.tcs_id);
  delete_quad_s_or_o (sioc..get_graph (), iri, iri);
}
;

create trigger inst_tag_stats_d after delete on inst_tag_stats referencing old as O
{
  declare inst_iri, cloud_iri any;
  delete from tag_stat where ts_inst_id = O.its_inst_id;
  delete from tag_coocurrence where tc_inst_id = O.its_inst_id;
  delete from tag_coocurrence_stats where tcs_inst_id = O.its_inst_id;
  inst_iri := (select sioc..forum_iri (WAI_TYPE_NAME, WAI_NAME) from DB.DBA.WA_INSTANCE where WAI_ID = O.its_inst_id);
  cloud_iri := inst_iri || '/tagcloud';
  delete_quad_s_or_o (sioc..get_graph (), cloud_iri, cloud_iri);
}
;

create procedure scot_tags_init (in f int := 0)
{
  delete from inst_tag_stats;
  insert into inst_tag_stats (its_inst_id) select WAI_ID from DB.DBA.WA_INSTANCE;
  for select WAI_ID, WAI_TYPE_NAME from DB.DBA.WA_INSTANCE where f > 0 do
    {
      declare p_name varchar;
      p_name := sprintf ('sioc.DBA.ods_%s_scot_init', DB.DBA.wa_type_to_app (WAI_TYPE_NAME));
      if (__proc_exists (p_name))
	call (p_name) (WAI_ID);
    }
  for select NG_GROUP from DB.DBA.NEWS_GROUPS do
    {
      insert into inst_tag_stats (its_inst_id) values (-1 * NG_GROUP);
    }
  return;
}
;

create trigger SYS_DAV_TAG_SIOC_I after insert on WS.WS.SYS_DAV_TAG referencing new as N
{
  declare tags, iri, post_iri any;
  declare dir, path, owner_name varchar;
  declare pos, owner, res_id int;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  declare exit handler for not found {
    return;
  };

  res_id := N.DT_RES_ID;
  tags := N.DT_TAGS;
  if (not isstring (tags) or length (tags) = 0)
    return;

  select RES_FULL_PATH, RES_OWNER, U_NAME into path, owner, owner_name from WS.WS.SYS_DAV_RES, DB.DBA.SYS_USERS
      where RES_ID = N.DT_RES_ID and RES_OWNER = U_ID;
  -- Gallery
  if (__proc_exists ('sioc.DBA.ods_photo_sioc_tags'))
    ods_photo_sioc_tags (path, res_id, owner, owner_name, tags, 'I');
  -- Briefcase
  if (__proc_exists ('sioc.DBA.ods_briefcase_sioc_tags') and N.DT_U_ID = http_nobody_uid ())
    ods_briefcase_sioc_tags (path, res_id, owner, owner_name, tags, 'I');
  if (__proc_exists ('sioc.DBA.ods_wiki_sioc_tags') and N.DT_U_ID = http_nobody_uid ())
    ods_wiki_sioc_tags (path, res_id, owner, owner_name, tags, 'I');
}
;

create trigger SYS_DAV_TAG_SIOC_U after update on WS.WS.SYS_DAV_TAG referencing old as O, new as N
{
  declare tags, iri, post_iri, otags any;
  declare dir, path, owner_name varchar;
  declare pos, owner, res_id int;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  declare exit handler for not found {
    return;
  };

  res_id := N.DT_RES_ID;
  tags := N.DT_TAGS;
  otags := O.DT_TAGS;
  if (not isstring (tags) or length (tags) = 0)
    return;

  select RES_FULL_PATH, RES_OWNER, U_NAME into path, owner, owner_name from WS.WS.SYS_DAV_RES, DB.DBA.SYS_USERS
      where RES_ID = N.DT_RES_ID and RES_OWNER = U_ID;
  -- Gallery
  if (__proc_exists ('sioc.DBA.ods_photo_sioc_tags'))
    {
      ods_photo_sioc_tags (path, res_id, owner, owner_name, otags, 'D');
      ods_photo_sioc_tags (path, res_id, owner, owner_name, tags, 'I');
    }
  -- Briefcase
  if (__proc_exists ('sioc.DBA.ods_briefcase_sioc_tags') and N.DT_U_ID = http_nobody_uid ())
    {
      ods_briefcase_sioc_tags (path, res_id, owner, owner_name, otags, 'D');
      ods_briefcase_sioc_tags (path, res_id, owner, owner_name, tags, 'I');
    }
  if (__proc_exists ('sioc.DBA.ods_wiki_sioc_tags') and N.DT_U_ID = http_nobody_uid ())
    {
      ods_wiki_sioc_tags (path, res_id, owner, owner_name, tags, 'D');
      ods_wiki_sioc_tags (path, res_id, owner, owner_name, tags, 'I');
    }
}
;

create trigger SYS_DAV_TAG_SIOC_D after delete on WS.WS.SYS_DAV_TAG referencing old as O
{
  declare tags, iri, post_iri any;
  declare dir, path, owner_name varchar;
  declare pos, owner, res_id int;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };

  declare exit handler for not found {
    return;
  };

  res_id := O.DT_RES_ID;
  tags := O.DT_TAGS;
  if (not isstring (tags) or length (tags) = 0)
    return;

  select RES_FULL_PATH, RES_OWNER, U_NAME into path, owner, owner_name from WS.WS.SYS_DAV_RES, DB.DBA.SYS_USERS
      where RES_ID = O.DT_RES_ID and RES_OWNER = U_ID;
  -- Gallery
  if (__proc_exists ('sioc.DBA.ods_photo_sioc_tags'))
    ods_photo_sioc_tags (path, res_id, owner, owner_name, tags, 'D');
  -- Briefcase
  if (__proc_exists ('sioc.DBA.ods_briefcase_sioc_tags') and O.DT_U_ID = http_nobody_uid ())
    ods_briefcase_sioc_tags (path, res_id, owner, owner_name, tags, 'D');
  if (__proc_exists ('sioc.DBA.ods_wiki_sioc_tags') and O.DT_U_ID = http_nobody_uid ())
    ods_wiki_sioc_tags (path, res_id, owner, owner_name, tags, 'D');
}
;



ods_sioc_init ();

use DB;

create procedure ODS.DBA.apml (in uname int)
{
  declare ses, dt, srv, uid any;
  set isolation='uncommitted';
  srv := WA_CNAME ();
  ses := string_output ();
  dt := DB.DBA.date_iso8601 (dt_set_tz (curdatetime (), 0));
  uid := -1;
  http ('<APML xmlns="http://www.apml.org/apml-0.6" version="0.6" >\n', ses);
  http ('<Head>\n', ses);
  for select U_ID, U_E_MAIL, U_FULL_NAME from DB.DBA.SYS_USERS where U_NAME = uname do
    {
      uid := U_ID;
      http (sprintf ('<Title>%V</Title>\n', U_FULL_NAME), ses);
      http (sprintf ('<UserEmail>%V</UserEmail>\n', U_E_MAIL), ses);
    }
  http (sprintf ('<DateCreated>%s</DateCreated>\n', dt), ses);
  http ('</Head>\n', ses);
  http ('<Body>\n', ses);
  for select WAM_INST, WAI_ID from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE
    where WAM_INST = WAI_NAME and WAM_USER = uid and WAM_MEMBER_TYPE = 1 do
    {
      http (sprintf ('<Profile name="%V">\n', WAM_INST), ses);
      http ('<ImplicitData>\n', ses);
      http ('<Concepts>\n', ses);
      for select ts_tag, (ts_afreq*100/its_tag_cnt)/100.00 as freq from sioc..tag_stat, sioc..inst_tag_stats
	where its_inst_id = ts_inst_id and ts_inst_id = WAI_ID do
	  {
	    http (sprintf ('<Concept key="%V" value="%f" from="%s" updated="%s" />\n',
		  ts_tag, freq, srv, dt), ses);
	  }
      http ('</Concepts>\n', ses);
      http ('</ImplicitData>\n', ses);
      http ('</Profile>\n', ses);
    }
  http ('</Body>\n', ses);
  http ('</APML>', ses);
  return string_output_string (ses);
}
;
