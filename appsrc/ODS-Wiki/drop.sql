--  
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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

create procedure wiki_uninst()
{
  whenever sqlstate '*' goto fin;

  for select WAI_INST, WAI_NAME from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'WIKIV' or WAI_TYPE_NAME = 'oWiki' do
    {
        (WAI_INST as wa_wikiv).wa_drop_instance();
	commit work;
    }
fin:
  ;
}
;
create procedure WV.Wiki.drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where (P_NAME like 'WV.Wiki.%') or (P_NAME like 'WV.DBA.%')) do {
    if (P_NAME not in ('WV.Wiki.SILENT_EXEC', 'WV.Wiki.drop_procedures'))
      WV.Wiki.SILENT_EXEC(sprintf('drop procedure %s', P_NAME));
  }
}
;

-- remove XSLT extensions
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:AuthorIRI', 'WV.WIKI.AUTHORIRI');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:AuthorName', 'WV.WIKI.AUTHORNAME');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:ClusterIRI', 'WV.WIKI.CLUSTERIRI');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:ClusterParam', 'WV.WIKI.CLUSTERPARAM');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:WikiAplusLink', 'WV.Wiki.WIKI_APLUSLINK');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:DIUCategoryLink', 'WV.WIKI.DIUCATEGORYLINK');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:DiffPrint', 'WV.WIKI.DIFFPRINT');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:ExpandMacro', 'WV.WIKI.EXPANDMACRO');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:GetEnv', 'WV.WIKI.GETENV');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:GetMainTopicName', 'WV.WIKI.GETMAINTOPIC_NAME');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:NormalizeWikiWordLink', 'WV.WIKI.NORMALIZEWIKIWORDLINK');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:QueryWikiWordLink', 'WV.WIKI.QUERYWIKIWORDLINK');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:ReadOnlyWikiIRI', 'WV.WIKI.READONLYWIKIIRI');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:ReadOnlyWikiWordHREF', 'WV.WIKI.READONLYWIKIWORDHREF');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:ReadOnlyWikiWordHREF2', 'WV.WIKI.READONLYWIKIWORDHREF2');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:ReadOnlyWikiWordLink', 'WV.WIKI.READONLYWIKIWORDLINK');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:ResourceHREF', 'WV.WIKI.RESOURCEHREF');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:ResourceHREF2', 'WV.WIKI.RESOURCEHREF2');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:ResourcePath', 'WV.WIKI.RESOURCEPATH');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:WikiClusterURI', 'WV.WIKI.wiki_cluster_uri');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:TextFormattingRules', 'WV.WIKI.TEXTFORMATTINGRULES');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:UserByEmail', 'WV.WIKI.USER_BY_EMAIL');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:atom_pub_uri', 'WV.WIKI.ATOM_PUB_URI');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:collect_pairs', 'WV.WIKI.COLLECT_PAIRS');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:rdfLinksHead', 'WV.WIKI.RDF_LINKS_HEAD');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:email_obfuscate', 'WV.WIKI.EMAIL_OBFUSCATE');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:expandWikiText', 'WV.WIKI.EXPAND_WIKI_TEXT');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:funcall0', 'WV.WIKI.FUNCALL0');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:funcall1', 'WV.WIKI.FUNCALL1');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:funcall2', 'WV.WIKI.FUNCALL2');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:funcall3', 'WV.WIKI.FUNCALL3');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:funcall4', 'WV.WIKI.FUNCALL4');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:nnbsps', 'WV.WIKI.NNBSPS');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:pair', 'WV.WIKI.PAIR');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:params', 'WV.WIKI.PARAMS');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:registry_get', 'WV.WIKI.REGISTRY_GET');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:sioc_uri', 'WV.WIKI.SIOC_URI');
xpf_extension_remove ('http://www.openlinksw.com/Virtuoso/WikiV/:trim', 'WV.WIKI.TRIM');

wiki_uninst();
drop procedure wiki_uninst;

DELETE FROM WV.WIKI.CLUSTERS;
WV.WIKI.DROP_ALL_MEMBERS();
DELETE FROM DB.DBA.WA_INSTANCE    WHERE WAI_TYPE_NAME = 'oWiki';
DELETE FROM DB.DBA.WA_MEMBER_TYPE WHERE WMT_APP       = 'oWiki';

WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_AttachmentDelete');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_ClusterDelete');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_ClusterDeleteContent');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_ClusterInsert');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_ClusterUpdate');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_Tagging');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_TaggingUpdate');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_TopicDelete');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_TopicTextAttachment');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_TopicTextAttachment_D');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_TopicTextDelete');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_TopicTextInsert');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_TopicTextInsertMeta');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_TopicTextInsertPerms');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_TopicTextUpdate');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_TopicTextUpdatePerms');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_TopicTextSparql_AI');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_TopicTextSparql_AU');
WV.WIKI.SILENT_EXEC('drop trigger DB.DBA.Wiki_TopicTextSparql_AI');
WV.WIKI.SILENT_EXEC('drop trigger DB.DBA.Wiki_TopicTextSparql_AU');

WV.WIKI.SILENT_EXEC('drop trigger WS.WS.WIKI_SYS_DAV_PROP_AI');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.WIKI_SYS_DAV_PROP_BU');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.WIKI_SYS_DAV_PROP_BD');

WV.WIKI.SILENT_EXEC('drop trigger WS.WS.WIKI_SYS_DAV_RES_AI');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.WIKI_SYS_DAV_RES_AU');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.WIKI_SYS_DAV_RES_BD');

WV.WIKI.SILENT_EXEC('drop trigger DB.DBA.SYS_USERS_WIKI_USERS_U');

WV.WIKI.SILENT_EXEC('drop trigger DB.DBA.WIKI_WA_MEMBERSHIP');
WV.WIKI.SILENT_EXEC('drop trigger DB.DBA.WIKI_WA_MEMBERSHIP_OPEN');
WV.WIKI.SILENT_EXEC('drop trigger DB.DBA.WIKI_WA_MEMBERSHIP_CLOSE');
WV.WIKI.SILENT_EXEC('drop trigger DB.DBA.WIKI_WA_INSTANCE');
WV.WIKI.SILENT_EXEC('drop trigger DB.DBA.WIKI_WA_INSTANCE_U');
WV.WIKI.SILENT_EXEC('drop trigger DB.DBA.WIKI_WA_INSTANCE_D');

WV.WIKI.SILENT_EXEC('drop table WV.DBA.ERRORS');
WV.WIKI.SILENT_EXEC('drop table WV.DBA.HIST');
WV.WIKI.SILENT_EXEC('drop table WV.DBA.UPSTREAM_LOG');
WV.WIKI.SILENT_EXEC('drop table WV.DBA.UPSTREAM_ENTRY');
WV.WIKI.SILENT_EXEC('drop table WV.DBA.UPSTREAM');
WV.WIKI.SILENT_EXEC('drop type WV.WIKI.TOPICINFO');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.DOCBOOK_IDS');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.DOMAIN_PATTERN_1');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.EDIT_TEMP_STORAGE');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.COMMENT');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.SEMANTIC_OBJ');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.PREDICATE');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.LOCKTOKEN');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.COMMITCOUNTER');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.HITCOUNTER');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.ATTACHMENTINFONEW');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.CLUSTERSETTINGS');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.USERSETTINGS');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.CATEGORY');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.LOCK');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.HISTORY');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.DASHBOARD');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.TMP');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.LINK');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.TOPIC');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.CLUSTERS');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.APPERRORS');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.MEMBERSHIP');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.USERS');
WV.WIKI.SILENT_EXEC('drop table WV.WIKI.GROUPS');

WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_TopicTextSparql_AI');
WV.WIKI.SILENT_EXEC('drop trigger WS.WS.Wiki_TopicTextSparql_AU');

WV.WIKI.SILENT_EXEC ('delete from WA_TYPES where WAT_NAME = \'oWiki\' or WAT_NAME=\'WIKIV\'');
WV.WIKI.SILENT_EXEC ('drop type wa_wikiv');

WV.WIKI.SILENT_EXEC('drop view DB.DBA.ODS_WIKI_POSTS');

WV.WIKI.SILENT_EXEC ('DB.DBA.USER_ROLE_DROP (\'WikiAdmin\')');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_ROLE_DROP (\'WikiUser\')');
WV.WIKI.SILENT_EXEC('drop procedure DB.DBA.WA_SEARCH_DAV_OR_WIKI_GET_EXCERPT_HTM');
WV.WIKI.SILENT_EXEC('drop procedure DB.DBA.WA_SEARCH_WIKI_GET_EXCERPT_HTML');

DB.DBA.VHOST_REMOVE(lpath=>'/wiki');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki/Main');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki/Doc');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki/resources');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki/Atom');
DB.DBA.VHOST_REMOVE(lpath=>'/wikix');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki/wikix');
DB.DBA.VHOST_REMOVE(lpath=>'/wikiview');
DB.DBA.VHOST_REMOVE(lpath=>'/DAV/wikiview');

-- Registry
registry_remove('wiki default uri');
registry_remove('wiki_services_update');

-- NNTP
DROP procedure DB.DBA.oWiki_NEWS_MSG_I;
DROP procedure DB.DBA.oWiki_NEWS_MSG_U;
DROP procedure DB.DBA.oWiki_NEWS_MSG_D;
DB.DBA.NNTP_NEWS_MSG_DEL ('oWiki');

-- dropping procedures for Wiki
WV.Wiki.drop_procedures ();
WV.Wiki.SILENT_EXEC('DROP procedure WV.Wiki.drop_procedures');

WV.WIKI.SILENT_EXEC('drop procedure WV.DBA.CLUSTER_URL');
WV.WIKI.SILENT_EXEC('drop procedure WV.DBA.COLLECTION_LIST');
WV.WIKI.SILENT_EXEC('drop procedure WV.DBA.TOPIC_LIST');
WV.WIKI.SILENT_EXEC('drop procedure WV.DBA.TOPIC_URL');
WV.WIKI.SILENT_EXEC('drop procedure WV.DBA.ADD_ERROR');
WV.WIKI.SILENT_EXEC('drop procedure WV.DBA.ODS_LINK');
WV.WIKI.SILENT_EXEC('drop procedure WV.DBA.RESOURCE_PATH');
WV.WIKI.SILENT_EXEC('drop procedure WV.DBA.SEND_NOTIFICATION');
WV.WIKI.SILENT_EXEC('drop procedure WV.DBA.WIKI_LINK');
WV.WIKI.SILENT_EXEC('drop procedure WV.DBA.WIPE_OLD_ERRORS');
WV.WIKI.SILENT_EXEC('drop procedure DB.DBA.WA_NEW_WIKI_IN');
WV.WIKI.SILENT_EXEC('drop procedure DB.DBA.WA_NEW_WIKI_RM');
WV.WIKI.SILENT_EXEC('drop procedure DB.DBA.WA_SEARCH_DAV_OR_WIKI_GET_EXCERPT_HTML');
WV.WIKI.SILENT_EXEC('drop procedure DB.DBA.wiki_exec_no_error');

drop procedure WV.WIKI.SILENT_EXEC;
