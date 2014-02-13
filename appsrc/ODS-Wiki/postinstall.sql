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

update DB.DBA.SYS_USERS set U_HOME = '/DAV/home/dav/' where U_ID = http_dav_uid() and U_HOME is null;
WV.WIKI.CREATEGROUP('WikiAdmin', 'WikiAdmin', 'A group of WikiV managers', 0);
WV.WIKI.CREATEGROUP('WikiUser', 'WikiUser', 'A group of all WikiV users', 0);
WV.WIKI.CREATEUSER('Wiki', 'WikiEngineAdmin', 'WikiAdmin', 'Main administrator of WikiV', 0);
WV.WIKI.CREATEUSER('WikiGuest', 'WikiAnonymousUser', 'WikiUser', 'Anonymous user of WikiV', 0);
WV.WIKI.CREATEUSER('dav', 'DAVWikiAdmin', 'WikiAdmin', 'DAV administrator of WikiV', 0);
WV.WIKI.CREATEINSTANCE('Main', http_dav_uid(), WV.Wiki.WikiAdminGId(), 0);
WV.WIKI.CREATEINSTANCE('Doc', http_dav_uid(), WV.Wiki.WikiAdminGId(), 0);

wiki_exec_no_error ('DB.DBA.USER_GRANT_ROLE (\'WikiGuest\', \'MainReaders\')');
wiki_exec_no_error ('DB.DBA.USER_GRANT_ROLE (\'WikiGuest\', \'DocReaders\')');
wiki_exec_no_error ('WV.WIKI.ADD_USER (\'dav\', \'Main\')');
wiki_exec_no_error ('WV.WIKI.ADD_USER (\'dav\', \'Doc\')');

WV.WIKI.SET_AUTOVERSION();
WV.WIKI.STALE_ALL_XSLTS();
WV.WIKI.CREATE_ALL_USERS_PAGES();
WV.WIKI.SET_WIKI_MAIN();
WV.WIKI.SANITY_CHECK();
WV.WIKI.CREATEINSTANCE('Main', http_dav_uid(), WV.Wiki.WikiAdminGId(), 0);
WV.WIKI.CREATEINSTANCE('Doc', http_dav_uid(), WV.Wiki.WikiAdminGId(), 0);
SIOC..fill_comments();
WV.WIKI.PUT_NEW_FILES('Main');
WV.WIKI.PUT_NEW_FILES('Doc',1);
WV.WIKI.PUT_NEW_FILES('Main',1,'WikiUsers');
WV.WIKI.PUT_NEW_FILES('Main',1,'WMacros');

WV.WIKI.PUT_NEW_FILES('Main',1,'TemplateUser');
update WV.WIKI.DOMAIN_PATTERN_1 set DP_PATTERN = replace (DP_PATTERN, '%', 'main')  where DP_PATTERN like '%%%';

create procedure WV.WIKI.temp ()
{
  declare _topic_id integer;
  declare _content, _type any;

  _topic_id := (select TopicId from WV.Wiki.CLUSTERS a, WV.Wiki.TOPIC b where a.ClusterId = b.ClusterId and a.ClusterName = 'Main' and b.LocalName = 'WMacros');
  if (not isnull (_topic_id))
  {
  DB.DBA.DAV_RES_CONTENT_INT (DAV_SEARCH_ID ('/DAV/VAD/wiki/Main/Attachments/WikiMacroSources.sql', 'R'), _content, _type, 0, 0);
  WV.WIKI.ATTACH2 (http_dav_uid(), 'WikiMacroSources.sql', _type, _topic_id, _content, '');
}
}
;

WV.WIKI.temp ();

create procedure WV.WIKI.temp ()
{
  if (registry_get ('wiki_services_update') = '1')
    return;

  SIOC..fill_ods_wiki_services();
  registry_set ('wiki_services_update', '1');
}
;
WV.WIKI.temp ();

create procedure WV.WIKI.temp ()
{
  if (registry_get ('wiki_acl_update') = '1')
    return;

  for (select ClusterId as _ClusterId, ClusterName as _ClusterName, ColId as _ColId from WV.WIKI.CLUSTERS) do
  {
    for (select TopicId as _TopicId, ResId as _ResId from WV.WIKI.TOPIC where ClusterId = _ClusterId) do
    {
      WV.WIKI.UPDATEGRANTS_FOR_RES_OR_COL (_ClusterName, _ResId, 'R', 0);
    }
    WV.WIKI.UPDATEGRANTS_FOR_RES_OR_COL (_ClusterName, _ColId, 'C', 0);
  }
  registry_set ('wiki_acl_update', '1');
}
;
WV.WIKI.temp ();

drop procedure WV.WIKI.temp;
