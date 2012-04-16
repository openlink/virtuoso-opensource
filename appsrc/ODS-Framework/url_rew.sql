--
--  url_rev.sql
--
--  $Id$
--
--  URL rewrite rules for ODS
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

-- Support functions for decoding and converting URL rewrite rule parameters
create procedure DB.DBA.ODS_INST_HOME_PAGE (in par varchar, in fmt varchar, in val varchar)
{
  declare ret any;
  if (length (val))
    val := split_and_decode (val)[0];
  ret := (select WAM_HOME_PAGE from WA_MEMBER where WAM_INST = val and WAM_MEMBER_TYPE = 1);
  return ret;
}
;

create procedure DB.DBA.ODS_APPS_PAGE (in par varchar, in fmt varchar, in val varchar)
{
  if (par = 'app')
    return sprintf (fmt, wa_app_to_type (val));
  return sprintf (fmt, val);
}
;

create procedure DB.DBA.ODS_DISC_GRP_ID (in par varchar, in fmt varchar, in val varchar)
{
  declare gid int;
  if (length (val))
    val := split_and_decode (val)[0];
  gid := (select NG_GROUP from DB.DBA.NEWS_GROUPS where NG_NAME = val);
  return sprintf (fmt, gid);
}
;

create procedure DB.DBA.ODS_DISC_ITEM_ID (in par varchar, in fmt varchar, in val varchar)
{
  declare id any;
  if (length (val))
    val := split_and_decode (val)[0];
  id := encode_base64 (val);
  return sprintf (fmt, id);
}
;

create procedure DB.DBA.ODS_ITEM_PAGE (in par varchar, in fmt varchar, in val varchar)
{
  declare ret any;
  if ((par = 'inst') or (par = 'inst2'))
    {
      ret := DB.DBA.ODS_INST_HOME_PAGE (par, fmt, val);
      if (length (ret) and (par = 'inst2'))
        {
          declare pos integer;

          pos := strrchr (ret, '/');
          if (not isnull (pos))
            ret := subseq (ret, 0, pos);
        }
    }
  else -- item
    {
      ret := sprintf ('%s', val);
    }
  return sprintf (fmt, ret);
}
;

create procedure DB.DBA.ODS_ATOM_PAGE (in par varchar, in fmt varchar, in val varchar)
{
  declare ret any;
  if (par = 'inst')
  {
    if (length (val))
      val := split_and_decode (val)[0];
    ret := cast ((select WAI_ID from WA_INSTANCE where WAI_NAME = val) as varchar);
  }
  else if ((par = 'app') and (val = 'subscriptions'))
  {
    ret := 'enews2';
  }
  else
  {
    ret := sprintf ('%s', val);
  }
  return sprintf (fmt, ret);
}
;

create procedure DB.DBA.ODS_WIKI_ITEM_PAGE (in par varchar, in fmt varchar, in val varchar)
{
  declare ret any;
  if (par = 'inst')
  {
    if (length (val))
      val := split_and_decode (val)[0];
    ret := (select WAM_HOME_PAGE from WA_MEMBER where WAM_INST = val and WAM_MEMBER_TYPE = 1);
    if (ret like 'http://%')
    {
      declare i integer;
      ret := replace (ret, 'http://','');
      i := strstr (ret, '/');
      if (not isnull (i))
        ret := subseq (ret, i);
    }
    ret := rtrim (ret, '/') || '/';
  }
  else -- item
    {
      ret := sprintf ('%s', val);
    }
  return sprintf ('%s', ret);
}
;

create procedure DB.DBA.ODS_PHOTO_ITEM_PAGE (in par varchar, in fmt varchar, in val varchar)
{
  declare id int;
  declare col, nam, ret varchar;

  declare exit handler for not found
    {
      signal ('22023', sprintf ('The resource %d doesn''t exists', id));
    };
  id := atoi(ltrim(val, '/'));

  if (par = 'uname' or par='inst')
    {
      ret := sprintf (fmt, val);
    }
  else if (par = 'item' and id is not null and id > 0)
    {
     select RES_NAME,COL_NAME into nam, col from WS.WS.SYS_DAV_RES, WS.WS.SYS_DAV_COL where RES_COL=COL_ID and RES_ID = id;
     ret:= '#/'||col||'/'||nam;
    }
  else if(id>0)
    {
     select RES_FULL_PATH into nam from WS.WS.SYS_DAV_RES where RES_ID = id;
     ret:= nam;
    }
  else
    {
     --dbg_obj_print('val',val);
     ret := sprintf ('%s', val);
    }

  return ret;
}
;

create procedure DB.DBA.ODS_PHOTO_GEMS_PAGE (in par varchar, in fmt varchar, in val varchar)
{

  declare ret any;
  if (par = 'inst')
    {
     if (length (val))
      val := split_and_decode (val)[0];
      ret := (select WAM_HOME_PAGE from WA_MEMBER where WAM_INST = val and WAM_MEMBER_TYPE = 1);
    }
  else -- item
    {
      ret := sprintf ('%s', val);
    }
  return sprintf (fmt, ret);

}
;

create procedure DB.DBA.ODS_DET_REF (in par varchar, in fmt varchar, in val varchar)
{
  declare iri, res any;
--  dbg_obj_print (current_proc_name (), par, val);
  if (par = 'page' or par = 'ext')
    return sprintf (fmt, val);
  else if (par = '*accept*')
    {
      if (val = 'application/rdf+xml')
	return sprintf (fmt, 'rdf');
      else
	return sprintf (fmt, 'n3');
    }

  if (val like 'raw/%')
    val := subseq (val, 4);
  iri := sioc..get_graph () ||'/'|| val;
  -- when an about, sioc or foaf is requested, we just remove. the IRI MUST be preceding path
  if (regexp_match ('http://([^/]*)/dataspace/(.*)/(about|sioc|foaf)\\.(rdf|n3|ttl)', iri) is not null)
    {
      declare pos int;
      pos := strrchr (iri, '/');
      iri := subseq (iri, 0, pos);
    }
  -- if this is a person or organization, we put #this at end if not present
  if (regexp_match ('http://([^/]*)/dataspace/(person|organization|group)/(.*)/online_account/(.*)', iri) is not null and
      iri not like '%#this')
    {
      ;
    }
  else if (regexp_match ('http://([^/]*)/dataspace/(person|organization|group)/(.*)', iri) is not null and
      iri not like '%#this')
    {
      iri := iri || '#this';
    }
  if (regexp_match ('http://([^/]*)/dataspace/([^/]*)/calendar/([^/]*)/(Task|Event)/([^/\\?]*)', iri) is not null and
      iri not like '%#this')
    {
      iri := iri || '#this';
    }
  -- space also have #this
  if ((regexp_match ('http://([^/]*)/dataspace/([^/]*)\x24', iri) is not null
      or regexp_match ('http://([^/]*)/dataspace/([^/]*)/space\x24', iri) is not null)
      and iri not like '%#this')
    {
      iri := iri || '#this';
    }
  -- if this is a person or organization, we put #this at end if not present
  if (regexp_match ('http://([^/]*)/dataspace/([^/]*)/socialnetwork/([^/]*)/(.*)', iri) is not null and
      iri not like '%#this')
    {
      iri := iri || '#this';
    }
  res := sprintf ('iid (%d)', iri_id_num (iri_to_id (iri)));
  return sprintf (fmt, res);
}
;

--
-- ODS IRI rewrite rules
-- IMPORTANT: all rules are processed and last matching will win
--
create procedure DB.DBA.ODS_URLREW_XRDS (in path varchar)
{
  return sprintf ('X-XRDS-Location: http://%{WSHost}s%s/yadis.xrds', path);
}
;


-- Person IRI as HTML
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_person_html', 1,
    '/dataspace/(person/|organization/)([^/#\\?]*)', vector('type', 'uname'), 1,
--    '/ods/uhome.vspx?page=1&ufname=%U&utype=%U', vector('uname', 'type'),
    '/ods/index.vsp?uname=%U&utype=%U', vector( 'uname','type'), --this line is related to the new UI. without it will not work correct. Old UI will keep working as expected.
    NULL,
    NULL,
    2,
    NULL,
    '^{sql:DB.DBA.ODS_URLREW_XRDS}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_person_yadis', 1,
    '/dataspace/(person/|organization/)?([^/#\\?]*)', vector('type', 'uname'), 1,
    '/ods/yadis.vsp?uname=%U&type=%U', vector('uname', 'type'),
    NULL,
    'application/xrds.xml',
    2,
    NULL);

-- Application instances page as HTML
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_apps_html', 1,
    '/dataspace/((?!person)(?!organization)(?!all)(?!doc)[^/]*)/([^\\./\\?]*)/?', vector('uname', 'app'), 2,
    '/ods/app_my_inst.vspx?app=%s&ufname=%s&l=1', vector('app', 'uname'),
    'DB.DBA.ODS_APPS_PAGE',
    NULL,
    2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_all_apps_html', 1,
    '/dataspace/all/([^\\./\\?]*)/?', vector('app'), 2,
    '/ods/app_inst.vspx?app=%s', vector('app'),
    'DB.DBA.ODS_APPS_PAGE',
    NULL,
    2);

-- Yadis file
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_yadis', 1,
    '/dataspace/(person/|organization/)?([^/]*)/yadis.xrds', vector('type', 'uname'), 1,
    '/ods/yadis.vsp?uname=%U&type=%U', vector('uname', 'type'),
    NULL,
    NULL,
    1);

-- APML file
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_apml', 1,
    '/dataspace/([^/]*)/apml.xml', vector('uname'), 1,
    '/ods/apml.vsp?uname=%U', vector('uname'),
    NULL,
    NULL,
    1);

-- START Feeds
-- A feed page
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_feed_html', 1,
    '/dataspace/feed/([^/\\?]*)', vector('fid'), 1,
    '/subscriptions/news.vspx?feed=%U', vector('fid'),
    NULL,
    NULL,
    1);

-- Feed item page
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_feed_item_html', 1,
    '/dataspace/feed/([^/]*)/([^/\\?]*)', vector('fid', 'link'), 1,
    '/subscriptions/news.vspx?feed=%s&link=%s', vector('fid', 'link'),
    NULL,
    NULL,
    1);


DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_feed_item_html2', 1,
    '/dataspace/feed/([^/]*)/([^/\\?]*)\\?instance=([^&]*)', vector('fid', 'link', 'instance'), 1,
    '/enews2/%U/news.vspx?feed=%s&link=%s', vector('instance', 'fid', 'link'),
    NULL,
    NULL,
    1);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_feed_item_html3', 1,
    '/dataspace/([^/]*)/subscriptions/([^/]*)/news.vspx', vector('uname', 'inst'), 1,
    '/enews2/%U/news.vspx', vector('inst'),
    'DB.DBA.ODS_ATOM_PAGE',
    NULL,
    1);

-- END Feeds

-- A rule returning home page for a given instance.
-- NB: all instances have a <home url> except discussion
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_inst_html_post', 1,
    '/dataspace/([^/]*)/(weblog|ecrm|wiki|addressbook|socialnetwork|bookmark|briefcase|eCRM|calendar|community|subscriptions|photos|polls|mail|IM)/([^/\\?]+)',
    vector('ufname', 'app', 'inst'), 3,
    '%s', vector('inst'),
    'DB.DBA.ODS_INST_HOME_PAGE',
    NULL,
    2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_inst_html', 1,
    '/dataspace/doc/([^/]*)/(weblog|ecrm|wiki|addressbook|socialnetwork|bookmark|briefcase|eCRM|calendar|community|subscriptions|photos|polls|mail|IM)/([^/\\?]+)\x24',
    vector('ufname', 'app', 'inst'), 3,
    '%s', vector('inst'),
    'DB.DBA.ODS_INST_HOME_PAGE',
    NULL,
    1);

-- Discussion home

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_discussion_home_html', 1,
    '/dataspace/discussion', vector(), 1,
    '/nntpf/', vector(),
    NULL,
    NULL,
    2);

-- Discussion apps pages
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_discussion_page', 1,
    '/dataspace/discussion/([^/\\.\?]*)(.vspx|.vsp|.css|.js)',
    vector('page', 'ext'), 2,
    '/nntpf/%s%s', vector('page', 'ext'),
    'DB.DBA.ODS_ITEM_PAGE',
    NULL,
    1);

-- Discussion group page
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_discussion_html', 1,
    '/dataspace/discussion/([^/\\?]*)', vector('grp'), 1,
    '/nntpf/nntpf_nthread_view.vspx?group=%d', vector('grp'),
    'DB.DBA.ODS_DISC_GRP_ID',
    NULL,
    2);

-- A rule returning home page for a given item within instance all of these having a form of <home>?id=<item id>
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_apps_page', 1,
    '/dataspace/([^/]*)/(addressbook|bookmark|briefcase|calendar|subscriptions|polls|mail)/([^/]*)/([^/\\.\?]*)(.vspx|.vsp)',
    vector('uname', 'app', 'inst2', 'page', 'ext'), 4,
    '%s/%s%s', vector('inst2', 'page', 'ext'),
    'DB.DBA.ODS_ITEM_PAGE',
    NULL,
    2);

-- A rule returning home page for a given item within instance all of these having a form of <home>?id=<item id>
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_item_html', 1,
    '/dataspace/doc/([^/]*)/(weblog|addressbook|ecrm|socialnetwork|bookmark|briefcase|community|subscriptions|polls|mail|eCRM|IM)/([^/]*)/((?!gems)(?!tag)[^/\\?]*)',
    vector('uname', 'app', 'inst', 'item'), 3,
    '%s?id=%s', vector('inst', 'item'),
    'DB.DBA.ODS_ITEM_PAGE',
    NULL,
    2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_item_briefcase_html', 1,
    '/dataspace/doc/([^/]*)/(briefcase)/([^/]*)/folder/([^/\\?]*)',
    vector('uname', 'app', 'inst', 'item'), 3,
    '%s?id=%s&what=c', vector('inst', 'item'),
    'DB.DBA.ODS_ITEM_PAGE',
    NULL,
    2);

-- Wiki item is special case
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_wiki_item_html', 1,
    '/dataspace/doc/([^/]*)/wiki/([^/]*)/([^\\?]*)',
    vector('uname', 'inst', 'item'), 3,
    '%s%s', vector('inst', 'item'),
    'DB.DBA.ODS_WIKI_ITEM_PAGE',
    NULL,
    2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_wiki_item_html_post', 1,
    '/dataspace/([^/]*)/wiki/([^/]*)/([^\\?]*)',
    vector('uname', 'inst', 'item'), 3,
    '%s%s', vector('inst', 'item'),
    'DB.DBA.ODS_WIKI_ITEM_PAGE',
    NULL,
    2);

-- Wiki item is special case
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_ecrm_item_html1', 1,
    '/dataspace/doc/([^/]*)/ecrm/([^/]*)/([^\\?]*)',
    vector('uname', 'inst', 'item'), 3,
    '%s%s', vector('inst', 'item'),
    'DB.DBA.ODS_WIKI_ITEM_PAGE',
    NULL,
    2);

-- Wiki item is special case
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_ecrm_item_html2', 1,
    '/dataspace/doc/([^/]*)/eCRM/([^/]*)/([^\\?]*)',
    vector('uname', 'inst', 'item'), 3,
    '%s%s', vector('inst', 'item'),
    'DB.DBA.ODS_WIKI_ITEM_PAGE',
    NULL,
    2);


-- Wiki atop-pub is special case
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_wiki_atom_html', 1,
    '/dataspace/doc/([^/]*)/wiki/([^/]*)/atom-pub([^\\?]*)',
    vector('uname', 'inst', 'action'), 3,
    '/wiki/Atom/%s%s', vector('inst', 'action'),
    'DB.DBA.ODS_ATOM_PAGE',
    NULL,
    2);

-- Photo item is special case
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_photo_item_html', 1,
    '/dataspace/doc/([^/]*)/photos/([^/]*)/([^/\\?]*)',
    vector('uname', 'inst', 'item'), 3,
    '/photos/%s/%s', vector('uname','item'),
    'DB.DBA.ODS_PHOTO_ITEM_PAGE',
    NULL,
    2);
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_photo_gems_html', 1,
    '/dataspace/([^/]*)/photos/([^/]*)/(([^/\\?]*)\\.(xml|rdf|ttl))', -- .xml .rdf .ttl --(?!\.xml)|(?!\.rdf)|(?!\.ttl)
    vector('uname', 'inst', 'item'), 3,
    '%s%s', vector('inst','item'),
    'DB.DBA.ODS_PHOTO_GEMS_PAGE',
    NULL,
    2);

-- Calendar item is special case
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_cal_item_html', 1,
    '/dataspace/doc/([^/]*)/calendar/([^/]*)/(Task|Event)/([^/\\?]*)',
    vector('uname', 'inst', 'item_type', 'item'), 4,
    '%s?id=%s', vector('inst', 'item'),
    'DB.DBA.ODS_ITEM_PAGE',
    NULL,
    2);

-- Calendar atop-pub is special case
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_cal_atom_html', 1,
    '/dataspace/([^/]*)/calendar/([^/]*)/atom-pub([^\\?]*)',
    vector('uname', 'inst', 'action'), 3,
    '/calendar/atom-pub/%s%s', vector('inst', 'action'),
    'DB.DBA.ODS_ATOM_PAGE',
    NULL,
    1);

-- Calendar atop-pub is special case
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_apps_gems_html', 1,
    '/dataspace/([^/]*)/(addressbook|bookmark|calendar|subscriptions|polls)/([^/]*)/gems/([^\\?]*)',
    vector('uname', 'app', 'inst', 'gem'), 4,
    '/%s/%s/gems.vsp?type=%s', vector('app', 'inst', 'gem'),
    'DB.DBA.ODS_ATOM_PAGE',
    NULL,
    1);

-- Applications tags special case
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_apps_tags_html', 1,
    '/dataspace/([^/]*)/(addressbook|bookmark|calendar|subscriptions|polls)/([^/]*)/tag/([^\\?]*)',
    vector('uname', 'app', 'inst', 'tag'), 4,
    '%s?tag=%s', vector('inst', 'tag'),
    'DB.DBA.ODS_ITEM_PAGE',
    NULL,
    2);

-- A discussion item page
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_discussion_item_html', 1,
    '/dataspace/discussion/([^/]*)/((?!sioc)(?!about)[^/\\?]*)',
    vector('grp', 'post'), 1,
    '/nntpf/nntpf_disp_article.vspx?id=%U', vector('post'),
    'DB.DBA.ODS_DISC_ITEM_ID',
    NULL,
    2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_blog_tag', 1,
    '/dataspace/([^/]*)/weblog/([^/]*)/tag/([^/\\?]*)',
    vector('uname', 'inst', 'tag'), 3,
    '%s?tag=%U', vector('inst', 'tag'),
    'DB.DBA.ODS_ITEM_PAGE',
    NULL,
    2);

-- /ods
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_main', 1,
    '/dataspace/?\x24', vector(), 0,
    '/ods/', vector(),
    null,
    null,
    2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_space_html', 1,
    '/dataspace/([^/]*)/space/?', vector('uname'), 1,
    '/ods/myhome.vspx', vector(),
    NULL,
    NULL,
    2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_ecrm_rdf', 1,
    '/dataspace/([^/]*)/eCRM/(.*)',
    vector('uname', 'path'),
    1,
    '/ecrm/%U',
    vector('path'),
    'DB.DBA.ECRM_DET_REF2',
    'application/rdf.xml',
    2,
    303);

-- A rule returning home page for a given discussion within instance all of these having a form of <home>/conversation.vspx?id=<item id>
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_item_discussion_html', 1,
    '/dataspace/([^/]*)/(addressbook|bookmark|subscriptions|polls)/([^/]*)/([0-9]*)/([0-9]*)',
    vector('uname', 'app', 'inst', 'item', 'discussion'), 5,
    '/dataspace/%s/%s/%s/conversation.vspx?id=%s', vector('uname', 'app', 'inst', 'item'),
    NULL,
    NULL,
    2,
    303);

-- A rule returning home page for a given discussion within instance all of these having a form of <home>/conversation.vspx?id=<item id>
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_cal_item_discussion_html', 1,
    '/dataspace/([^/]*)/calendar/([^/]*)/(Task|Event)/([0-9]*)/([0-9]*)',
    vector('uname', 'inst', 'item_type', 'item', 'discussion'), 5,
    '/dataspace/%s/calendar/%s/conversation.vspx?id=%s', vector('uname', 'inst', 'item'),
    NULL,
    NULL,
    2,
    303);

-- A rule returning home page for a given annotation within instance all of these having a form of <home>/annotea.vspx?id=<item id>
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_item_annotation_html', 1,
    '/dataspace/([^/]*)/(addressbook|bookmark|subscriptions|polls)/([^/]*)/([0-9]*)/annotation/([0-9]*)',
    vector('uname', 'app', 'inst', 'item', 'annotation'), 5,
    '/dataspace/%s/%s/%s/annotea.vspx?oid=%s&id=%s', vector('uname', 'app', 'inst', 'item', 'annotation'),
    NULL,
    NULL,
    2,
    303);

-- A rule returning home page for a given discussion within instance all of these having a form of <home>/conversation.vspx?id=<item id>
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_cal_item_annotation_html', 1,
    '/dataspace/([^/]*)/calendar/([^/]*)/(Task|Event)/([0-9]*)/annotation/([0-9]*)',
    vector('uname', 'inst', 'item_type', 'item', 'annotation'), 5,
    '/dataspace/%s/calendar/%s/annotea.vspx?oid=%s&id=%s', vector('uname', 'inst', 'item', 'annotation'),
    NULL,
    NULL,
    2,
    303);

--DB.DBA.VHOST_REMOVE (lpath=>'/ods/data/rdf');
--DB.DBA.VHOST_DEFINE (lpath=>'/ods/data/rdf', ppath=>'/DAV/VAD/wa/RDFData/All/', is_dav=>1, vsp_user=>'dba',
--    opts=>vector ('url_rewrite', 'ods_rule_tcn_list'));

create procedure DB.DBA.ODS_RDF_URI_LOC (in id int, in variant varchar)
{
  declare tmp, arr, r_id, iri any;
  tmp := split_and_decode (variant);
  tmp := tmp[0];
  arr := sprintf_inverse (tmp, '%s (%d).%s', 1);
  r_id := iri_id_from_num (arr [1]);
  iri := id_to_iri (r_id);
  --dbg_obj_print (iri);
  if (iri like 'http://%/dataspace/person/%')
    return 'about.'||arr[2];
  return 'sioc.'||arr[2];
}
;

delete from DB.DBA.HTTP_VARIANT_MAP where VM_RULELIST = 'ods_rule_list1';
DB.DBA.HTTP_VARIANT_ADD ('ods_rule_list1', 'sioc\x24', 'sioc.json',   'application/json',    1.0, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('ods_rule_list1', 'sioc\x24', 'sioc.txt',    'text/plain',          1.0, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('ods_rule_list1', 'sioc\x24', 'sioc.turtle', 'text/turtle',         1.0, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('ods_rule_list1', 'sioc\x24', 'sioc.ttl',    'text/rdf+ttl',        1.0, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('ods_rule_list1', 'sioc\x24', 'sioc.n3',     'text/rdf+n3',         1.0, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('ods_rule_list1', 'sioc\x24', 'sioc.nt',     'text/n3',             1.0, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('ods_rule_list1', 'sioc\x24', 'sioc.rdf',    'application/rdf+xml', 1.0, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('ods_rule_list1', 'sioc\x24', 'sioc.jmd',    'application/microdata+json', 1.0, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('ods_rule_list1', 'sioc\x24', 'sioc.jld',    'application/ld+json', 1.0, location_hook=>null);

create procedure DB.DBA.ODS_URLREW_HDR (in in_path varchar)
{
  declare host, lines, exts any;
  declare links, tmp, path, mail, uname varchar;

  lines := http_request_header ();
  host := http_request_header (lines, 'Host', null, '');
  links := '';
  mail := null;
  uname := null;
--  dbg_obj_print_vars (in_path);
  exts := 
  vector (
      	vector ('rdf',  'RDF/XML', 'application/rdf+xml'), 
      	vector ('nt',   'N3/Turtle', 'text/n3'), 
      	vector ('n3',   'N3/Turtle', 'text/rdf+n3'), 
	vector ('json', 'RDF/JSON', 'application/json'),
	vector ('txt', 	'N-Triples', 'text/plain'),
	vector ('turtle','N3/Turtle', 'text/turtle'),
	vector ('ttl', 	'N3/Turtle', 'text/rdf+ttl'),
	vector ('jmd', 	'Microdata+JSON', 'application/microdata+json'),
	vector ('jld', 	'JSON-LD', 'application/ld+json')
	);
  path := regexp_replace (in_path, '/(about|foaf|sioc)\\.([a-z0-9]+)\x24', '', 1, null);	
  if (regexp_match ('/dataspace/(person|organization)/([^/]+)\x24', path) is not null)
    {
      declare a any;
      a := sprintf_inverse (path, '/dataspace/%s/%s', 1);
      if (length (a) = 2)
	{
	mail := (select U_E_MAIL from DB.DBA.SYS_USERS where U_NAME = a[1]);
	  uname := a[1];
	}
      tmp := path || '#this';
    }
  else
    {
      tmp := path;
    }
  links := sprintf ('X-RDF-Graph: http://%{WSHost}s/dataspace\r\nX-SPARQL-Endpoint: http://%{WSHost}s/sparql-auth/\r\nLink: ');
  links := links || sprintf ('<http://%s%s>; rel="http://xmlns.com/foaf/0.1/primaryTopic",', host, tmp);
  links := links || sprintf ('\r\n <http://%s%s>; rev="describedby",', host, tmp);
  if (uname is not null)
    links := links || sprintf ('\r\n <http://%s/activities/feeds/activities/user/%U>; rel="http://schemas.google.com/g/2010#updates-from"; type="application/atom+xml",', host, uname);
  tmp := regexp_replace (in_path, '\\.([a-z0-9]+)\x24', '', 1, null);	
  if (tmp = in_path)
    {
      if (regexp_match ('/dataspace/(person|organization)/([^/]+)', path) is not null)
	tmp := tmp || '/about';
      else
        tmp := tmp || '/sioc';	
    }
  foreach (any ss in exts) do
    {
      if (in_path not like '%.'||ss[0])
	{
	  links := links || sprintf ('\r\n <http://%s%s.%s>; rel="alternate";\r\n type="%s"; title="Structured Descriptor Document (%s format)",', 
	  host, tmp, ss[0], ss[2], ss[1]);
	}
    }
  if (mail is not null)
    links := links || sprintf ('\r\n <http://%s/ods/describe?uri=%U>; rel="webfinger",', host, 'acct:' || mail);
  links := rtrim (links, ',');
  return links;
}
;

-- RDF data rules - these returns 303
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_html', 1,
    '/dataspace/((?!(doc|person|organization|raw)/)[^\\?]*)\x24', vector('path'), 1,
    '/dataspace/doc/%s', vector('path'),
    null, --'DB.DBA.ODS_DET_REF',
    '(text/html)|(\\*/\\*)',
    2,
    303,
    null --'^{sql:DB.DBA.ODS_URLREW_HDR}^'
    );

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_rdf', 1,
    '/dataspace/([^\\?]*)', vector('path'), 1,
    '/dataspace/raw/%s/sioc', vector('path'),
    null, --'DB.DBA.ODS_DET_REF',
    '(application/rdf.xml)|(text/rdf.n3)|(text/rdf.turtle)|(text/rdf.ttl)|([a-z]+/turtle)|(application/x-turtle)|(text/n3)|(application/json)|(application/microdata+json)|(application/ld+json)',
    2,
    303,
    null --'^{sql:DB.DBA.ODS_URLREW_HDR}^'
    );

-- XXX: RDF data rule
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_rdf_next', 1,
    '/dataspace/(.*)/page/([0-9]*)', vector('path', 'page'), 1,
    '/ods/data/rdf/%U.%U?page=%U', vector('path', '*accept*', 'page'),
    'DB.DBA.ODS_DET_REF',
    '(application/rdf.xml)|(text/rdf.n3)|(text/rdf.turtle)|(text/rdf.ttl)|([a-z]+/turtle)|(application/x-turtle)|(text/n3)|(application/json)|(application/microdata+json)|(application/ld+json)',
    2,
    303,
    null --'^{sql:DB.DBA.ODS_URLREW_HDR}^'
    );

-- Rule for about, sioc, foaf etc. RDF resources
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_rdf_res', 1,
    '/dataspace/raw/(.*)/(about|foaf|sioc)\\.([^\\?]*)', vector('path', 'dummy', 'ext'), 1,
    '/ods/data/rdf/%U.%U', vector('path', 'ext'),
    'DB.DBA.ODS_DET_REF',
    NULL,
    2,
    null,
    '^{sql:DB.DBA.ODS_URLREW_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_rdf_res_2', 1,
    '/dataspace/(.*)/(about|foaf|sioc)\\.([^\\?]*)', vector('path', 'dummy', 'ext'), 1,
    '/ods/data/rdf/%U.%U', vector('path', 'ext'),
    'DB.DBA.ODS_DET_REF',
    NULL,
    2,
    null,
    '^{sql:DB.DBA.ODS_URLREW_HDR}^');

-- Rule for moat
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_moat_res', 1,
    '/dataspace/tag/([^/]*)\x24', vector('tag'), 1,
    '/ods/moat.vsp?tag=%U', vector('tag'),
    null,
    NULL,
    2,
    null);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_error', 1,
    '/dataspace/(.*)/error.vspx?(.*)', vector(), 0,
    '/ods/error.vspx', vector(),
    null,
    null,
    2);

-- All rules are processed in the order below.
-- Every rule will be tried and last matching rule will win
DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_rule_list1', 1,
   	vector(
	  'ods_person_html',
	  'ods_person_yadis',
	  'ods_apps_html',
	  'ods_all_apps_html',
	  'ods_yadis',
	  'ods_apml',
	  'ods_feed_item_html2',
	  'ods_feed_item_html3',
	  'ods_feed_item_html',
	  'ods_feed_html',
	  'ods_inst_html_post',
	  'ods_inst_html',
	  'ods_discussion_page',
	  'ods_discussion_home_html',
	  'ods_discussion_html',
	  'ods_item_html',
    'ods_item_briefcase_html',
    'ods_item_discussion_html',
    'ods_item_annotation_html',
	  'ods_wiki_item_html',
	  'ods_wiki_item_html_post',
	  'ods_wiki_atom_html',
	  'ods_ecrm_item_html1',
	  'ods_ecrm_item_html2',
	  'ods_photo_item_html',
	  'ods_photo_gems_html',
	  'ods_cal_item_html',
    'ods_cal_item_discussion_html',
    'ods_cal_item_annotation_html',
	  'ods_cal_atom_html',
	  'ods_apps_gems_html',
	  'ods_apps_tags_html',
	  'ods_discussion_item_html',
	  'ods_blog_tag',
	  'ods_main',
	  'ods_space_html',
	  'ods_html',
	  'ods_apps_page',
	  'ods_rdf',
	  --'ods_rdf_next',
	  'ods_rdf_res',
	  'ods_rdf_res_2',
	  'ods_moat_res',
	  'ods_ecrm_rdf',
	  'ods_error'
	  ));
