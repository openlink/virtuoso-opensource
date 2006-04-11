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
create procedure wiki_uninst()
{
  --dbg_obj_princ ('Dropping oWiki');
  for select WAI_INST, WAI_NAME from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'WIKIV' or WAI_TYPE_NAME = 'oWiki' do
    {
	--dbg_obj_princ ('dropping ', WAI_NAME);
        (WAI_INST as wa_wikiv).wa_drop_instance();
	commit work;
    }
}
;

wiki_uninst()
;

drop procedure wiki_uninst
;
create procedure WV.WIKI.SILENT_EXEC (in text varchar)
{
    declare exit handler for sqlstate  '*' {
         rollback work;
         return;
    };
    exec (text);
}
;


DELETE FROM WV.WIKI.CLUSTERS
;

WV.WIKI.DROP_ALL_MEMBERS()
;

DELETE FROM DB.DBA.WA_INSTANCE    WHERE WAI_TYPE_NAME = 'oWiki'
;
DELETE FROM DB.DBA.WA_MEMBER_TYPE WHERE WMT_APP       = 'oWiki'
;

			  
WV.WIKI.SILENT_EXEC ('drop trigger WS.WS."Wiki_ClusterInsert"');
WV.WIKI.SILENT_EXEC ('drop trigger WS.WS."Wiki_ClusterDelete"');
WV.WIKI.SILENT_EXEC ('drop trigger WS.WS."Wiki_ClusterUpdate"');
WV.WIKI.SILENT_EXEC ('drop trigger WS.WS."Wiki_TopicTextInsert"');
WV.WIKI.SILENT_EXEC ('drop trigger WS.WS."Wiki_TopicTextDelete"');
WV.WIKI.SILENT_EXEC ('drop trigger WS.WS."Wiki_TopicTextUpdate"');
WV.WIKI.SILENT_EXEC ('drop trigger WS.WS."Wiki_AttachmentDelete"');	  
WV.WIKI.SILENT_EXEC ('drop trigger WS.WS.WIKI_WA_MEMBERSHIP');	  
WV.WIKI.SILENT_EXEC ('drop trigger WS.WS.WIKI_SYS_USERS');	  
WV.WIKI.SILENT_EXEC ('drop trigger WS.WS.WIKI_WA_INSTANCE');


WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.LockToken');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.LOCKTOKEN');
WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.HitCounter');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.HIT_COUNTER');
WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.AttachmentInfoNew');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.ATTACHMENTINFONEW');
WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.AttachmentInfo');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.ATTACHMENTINFO');
WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.Tmp');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.TMP');
WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.Link');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.LINK');
WV.WIKI.SILENT_EXEC ('drop table "WV"."Wiki"."TopicHistory"');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.TOPICHISTORY');


WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.COMMENT');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.PREDICATE');
WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.SEMANTIC_OBJ');

WV.WIKI.SILENT_EXEC ('drop table "WV"."Wiki"."Topic"');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.TOPIC');
WV.WIKI.SILENT_EXEC ('drop table "WV"."Wiki"."Cluster"');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.CLUSTERS');
WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.AppErrors');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.APPERRORS');
WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.EditTrx');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.EDITTRX');
WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.Membership');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.MEMBERSHIP');
WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.User');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.USERS');
WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.Group');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.GROUPS');
WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.History');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.HISTORY');
WV.WIKI.SILENT_EXEC ('drop type WV.Wiki.TopicInfo');
WV.WIKI.SILENT_EXEC ('drop type WV.WIKI.TOPICINFO');
WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.Category');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.CATEGORY');

WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.UserSettings');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.USERSSETTINGS');
WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.ClusterSettings');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.CLUSTERSSETTINGS');
WV.WIKI.SILENT_EXEC ('drop table WV.Wiki.Lock');
WV.WIKI.SILENT_EXEC ('drop table WV.WIKI.LOCK');

WV.WIKI.SILENT_EXEC ('delete from WA_TYPES where WAT_NAME = \'oWiki\' or WAT_NAME=\'WIKIV\'');

WV.WIKI.SILENT_EXEC ('drop type wa_wikiv');

WV.WIKI.SILENT_EXEC ('DB.DBA.USER_ROLE_DROP (\'WikiAdmin\')');
WV.WIKI.SILENT_EXEC ('DB.DBA.USER_ROLE_DROP (\'WikiUser\')');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki/Main');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki/Doc');
DB.DBA.VHOST_REMOVE(lpath=>'/wikix');
DB.DBA.VHOST_REMOVE(lpath=>'/wiki/wikix');
DB.DBA.VHOST_REMOVE(lpath=>'/wikiview');
DB.DBA.VHOST_REMOVE(lpath=>'/DAV/wikiview');
select EXEC ('drop procedure "'|| p_name ||'"') from sys_procedures where p_name like 'WV.Wiki.%';
select EXEC ('drop procedure "'|| p_name ||'"') from sys_procedures where p_name like 'WV.WIKI.%';

DB.DBA.DAV_DELETE ('/DAV/VAD/wiki/', 0, 'dav', (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid()))
;





