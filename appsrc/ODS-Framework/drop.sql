--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

vhost_remove (lpath=>'/wa');
vhost_remove (lpath=>'/ods');
vhost_remove (lpath=>'/ods/users');
vhost_remove (lpath=>'/javascript/users');
vhost_remove (lpath=>'/php/users');
vhost_remove (lpath=>'/jsp/users');
vhost_remove (lpath=>'/ruby/users');
vhost_remove (lpath=>'/vsp/users');
vhost_remove (lpath=>'/ods/webid');

drop procedure WA_GET_EMAIL_TEMPLATE;
drop procedure WA_SET_EMAIL_TEMPLATE;
drop procedure wa_exec_no_error_log;
drop procedure wa_add_col;
drop procedure WA_INSTANCE_WAI_DESCRIPTION_INDEX_HOOK;
drop procedure WA_INSTANCE_WAI_DESCRIPTION_UNINDEX_HOOK;
drop procedure web_user_password_check;
drop procedure inst_child_node;
drop procedure inst_root_node ;
drop procedure inst_node;
drop procedure WA_GET_HOST;
drop procedure WA_MAIL_TEMPLATES;
drop procedure WA_RETRIEVE_MESSAGE;
drop procedure WA_STATUS_NAME;
drop procedure WA_USER_SET_OPTION;
drop procedure WA_USER_GET_OPTION;
drop procedure WA_USER_TAG_WAUTG_TAGS_INDEX_HOOK;
drop procedure WA_USER_TAG_WAUTG_TAGS_UNINDEX_HOOK;
drop procedure WA_USER_SET_INFO;
drop procedure WA_USER_EDIT;
drop procedure WA_USER_VISIBILITY;
drop procedure WA_REPLACE_ARR;
drop procedure WA_STR_PARAM;
drop procedure WA_USER_INFO_CHECK;
drop procedure WA_GET_FTID;
drop procedure WA_USER_TAG_SET;
drop procedure WA_USER_TAG_GET;
drop procedure WA_USER_TAGS_GET;
drop procedure WA_TAG_PREPARE;
drop procedure WA_VALIDATE_TAGS;
drop procedure WA_VALIDATE_TAG;
drop procedure WA_VALIDATE_FTEXT;
drop procedure WA_USER_IS_TAGGED;
drop procedure WA_GET_USER_INFO;
drop procedure WA_DATE_GET;
drop procedure WA_USER_IS_FRIEND;
drop procedure WA_OPTION_IS_PUBLIC;
drop procedure WA_USER_TEXT_SET;
drop procedure WA_USER_OL_ACCOUNTS_SET_UP;

registry_remove ('__wa_member_upgrade');
registry_remove ('__wa_member_doinstcount');
registry_remove ('__WA_USER_INFO_CERT_UPGRADE');
registry_remove ('__WA_USER_INFO_NICK_UPGRADE');
registry_remove ('__WA_USER_OL_ACCOUNTS_SET_UP');
registry_remove ('__WA_USER_OL_ACCOUNTS_SET_UP2');
registry_remove ('__wa_offerlist_upgrade');
registry_remove ('__wa_wishlist_upgrade');
registry_remove ('__wa_favorites_upgrade');
registry_remove ('__WA_USER_SEARCH_SET_UP');
registry_remove ('__WA_USER_INFO_CHECK');
registry_remove ('__wa_wa_member_upgrade');
registry_remove ('wa_hosts_updated');
registry_remove ('wa_reg_updated');
registry_remove ('__WA_UPGRADE_USER_SVC');

create procedure db.dba._drop_ods_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'ODS.%.%') do
        db.dba.wa_exec_no_error(sprintf('drop procedure %s', P_NAME));
  }
;
-- dropping procedures for ODS
db.dba._drop_ods_procedures();
db.dba.wa_exec_no_error('db.dba._drop_ods_procedures');

db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_abs_date');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_add_rel_tag');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_add_tag_to_count');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_app_menu_fill_names');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_app_to_type');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_check_package');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_clear_stats');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_collect_all_rel_tags');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_collect_all_tags');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_collect_odrive_tags');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_content_annotate');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_ensure_page_class');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_ensure_widgets');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_exec_ddl');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_execute_search');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_expand_url');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_favorites_upgrade');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_get_app_dataspace');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_get_col_allres_count');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_get_custom_app_options');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_get_image_sizes');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_get_keywords');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_get_last_tf_id');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_get_last_tfd_id');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_get_new_url');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_get_package_name');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_get_type_from_name');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_get_user_sharedres_count');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_get_users');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_get_xslt_url');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_home_exec');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_identity_dstype');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_inst_type_icon');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_inst_url');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_keywords_sift');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_make_temp_sp');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_make_thumbnail');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_make_url_from_vd');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_member_doinstcount');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_offerlist_upgrade');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_redefine_vhosts');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_reg_register');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_set_type');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_set_url');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_set_url_t');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_str2words');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_tag_frecuency');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_tag_frecuency_int');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_tags2search');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_tags2vector');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_template_body_render');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_template_header_render');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_trim');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_type_to_app');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_type_to_appg');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_user_have_mailbox');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_user_is_dba');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_users_rdf_data_det_upgrade');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_utf8_to_wide');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_vad_check');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_wa_member_upgrade');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_wide_to_utf8');
db.dba.wa_exec_no_error ('drop procedure DB.DBA.wa_wishlist_upgrade');
DROP TYPE WEB_APP;

DROP TABLE ODS.DBA.APP_PING_LOG;
DROP TABLE ODS.DBA.APP_PING_REG;
DROP TABLE ODS.DBA.SVC_HOST;

DROP TABLE DB.DBA.WA_ACTIVITIES_USERSET;
DROP TABLE DB.DBA.WA_ACTIVITIES;
DROP TABLE DB.DBA.WA_BLOCKED_IP;
DROP TABLE DB.DBA.WA_COUNTRY;
DROP TABLE DB.DBA.WA_DOMAINS;
DROP TABLE DB.DBA.WA_INDUSTRY;
DROP TABLE DB.DBA.WA_MEMBER;
DROP TABLE DB.DBA.WA_VIRTUAL_HOSTS;
DROP TABLE DB.DBA.WA_SETTINGS_FEEDS;
DROP TABLE DB.DBA.WA_INSTANCE;
DROP TABLE DB.DBA.WA_MEMBER_INSTCOUNT;
DROP TABLE DB.DBA.WA_MEMBER_MODEL;
DROP TABLE DB.DBA.WA_MEMBER_TYPE;
DROP TABLE DB.DBA.WA_INVITATIONS;
DROP TABLE DB.DBA.WA_MAP_DISPLAY;
DROP TABLE DB.DBA.WA_MAP_HOSTS;
DROP TABLE DB.DBA.WA_MESSAGES;
DROP TABLE DB.DBA.WA_PROVINCE;
DROP TABLE DB.DBA.WA_RELATED_APPS;
DROP TABLE DB.DBA.WA_SETTINGS;
DROP TABLE DB.DBA.WA_TAG_REL;
DROP TABLE DB.DBA.WA_TAG_REL_INX;
DROP TABLE DB.DBA.WA_TYPES;
DROP TABLE DB.DBA.WA_USERS;
DROP TABLE DB.DBA.WA_USER_BIOEVENTS;
DROP TABLE DB.DBA.WA_USER_FAVORITES;
DROP TABLE DB.DBA.WA_USER_INFO;
DROP TABLE DB.DBA.WA_USER_OFFERLIST;
DROP TABLE DB.DBA.WA_USER_OL_ACCOUNTS;
DROP TABLE DB.DBA.WA_USER_PROJECTS;
DROP TABLE DB.DBA.WA_USER_RELATED_RES;
DROP TABLE DB.DBA.WA_USER_SETTINGS;
DROP TABLE DB.DBA.WA_USER_SVC;
DROP TABLE DB.DBA.WA_USER_TAG;
DROP TABLE DB.DBA.WA_USER_TEXT;
DROP TABLE DB.DBA.WA_USER_WISHLIST;

DROP VIEW DB.DBA.WA_SYS_USERS;

-- social network related
DROP TABLE DB.DBA.sn_invitation;
DROP TABLE DB.DBA.sn_related;
DROP TABLE DB.DBA.sn_member;
DROP TABLE DB.DBA.sn_alias;
DROP TABLE DB.DBA.sn_group;
DROP TABLE DB.DBA.sn_person;
DROP TABLE DB.DBA.sn_entity;
DROP TABLE DB.DBA.sn_source;

registry_remove ('__wa_sn_user_ent_set_done');
registry_remove ('__wa_sn_user_ent_set_done2');
db.dba.wa_exec_no_error ('drop procedure wa_sn_user_ent_set');

-- tag related
DROP TABLE DB.DBA.tag_content;
DROP TABLE DB.DBA.tag_rules;
DROP TABLE DB.DBA.tag_user;
DROP TABLE DB.DBA.tag_rule_set;

DROP TRIGGER DB.DBA.SYS_USERS_ON_DELETE_WA_FK;
DROP TRIGGER DB.DBA.HTTP_PATH_D_WA;
DROP TRIGGER DB.DBA.HTTP_PATH_U_WA;

drop procedure wa_exec_no_error;
