--
--  $Id$
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

drop procedure WA_GET_EMAIL_TEMPLATE;
drop procedure WA_SET_EMAIL_TEMPLATE;
drop procedure wa_exec_no_error_log;
drop procedure wa_exec_no_error;
drop procedure wa_add_col;
drop procedure wa_member_upgrade;
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


DROP TYPE WEB_APP;
DROP TABLE WA_MEMBER;
DROP TABLE WA_INSTANCE;
DROP TABLE WA_TYPES;
DROP TABLE WA_MEMBER_MODEL;
DROP TABLE WA_MEMBER_TYPE;
DROP TABLE WA_SETTINGS;
DROP TABLE WA_USERS;
DROP TABLE WA_BLOCKED_IP;
DROP TABLE WA_COUNTRY;
DROP TABLE WA_INDUSTRY;
DROP TABLE WA_USER_SETTINGS;
DROP TABLE WA_USER_INFO;
DROP TABLE WA_USER_TEXT;
DROP TRIGGER SYS_USERS_ON_DELETE_WA_FK;
vhost_remove (lpath=>'/wa');
vhost_remove (lpath=>'/ods');
