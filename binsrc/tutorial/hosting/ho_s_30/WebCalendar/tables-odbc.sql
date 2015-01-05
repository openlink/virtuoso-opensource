--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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
USER_CREATE('WebCal', '991f5070ad647438986fd5d19c83123e', 
	vector('LOGIN_QUALIFIER', 'WebCal',
	'FULL_NAME', 'PHP WebCalendar Demo user'));

use WebCal;

CREATE TABLE webcal_user (
  cal_login VARCHAR(25) NOT NULL,
  cal_passwd VARCHAR(25),
  cal_lastname VARCHAR(25),
  cal_firstname VARCHAR(25),
  cal_is_admin CHAR(1) DEFAULT 'N',
  cal_email VARCHAR(75),
  PRIMARY KEY ( cal_login )
);

INSERT INTO webcal_user ( cal_login, cal_passwd, cal_lastname, cal_firstname, cal_is_admin ) VALUES ( 'admin', 'admin', 'Administrator', 'Default', 'Y' );


CREATE TABLE webcal_entry (
  cal_id INTEGER NOT NULL,
  cal_group_id INTEGER,
  cal_ext_for_id INTEGER NULL,
  cal_create_by VARCHAR(25) NOT NULL,
  cal_date INTEGER NOT NULL,
  cal_time INTEGER,
  cal_mod_date INTEGER,
  cal_mod_time INTEGER,
  cal_duration INTEGER NOT NULL,
  cal_priority INTEGER DEFAULT 2,
  cal_type CHAR(1) DEFAULT 'E',
  cal_access CHAR(1) DEFAULT 'P',
  cal_name VARCHAR(80) NOT NULL,
  cal_description varchar(4096),
  PRIMARY KEY ( cal_id )
);


CREATE TABLE webcal_entry_repeats (
   cal_id INTEGER DEFAULT '0' NOT NULL,
   cal_type VARCHAR(20),
   cal_end INTEGER,
   cal_frequency INTEGER DEFAULT '1',
   cal_days CHAR(7),
   PRIMARY KEY (cal_id)
);


CREATE TABLE webcal_entry_repeats_not (
  cal_id INTEGER NOT NULL,
  cal_date INTEGER NOT NULL,
  PRIMARY KEY ( cal_id, cal_date )
);


CREATE TABLE webcal_entry_user (
  cal_id int DEFAULT '0' NOT NULL,
  cal_login varchar(25) DEFAULT '' NOT NULL, 
  cal_status char(1) DEFAULT 'A' NOT NULL,
  cal_category INTEGER DEFAULT NULL,
  PRIMARY KEY ( cal_id,cal_login )
);


CREATE TABLE webcal_entry_ext_user (
  cal_id INTEGER DEFAULT 0 NOT NULL,
  cal_fullname VARCHAR(50) NOT NULL,
  cal_email VARCHAR(75) NULL,
  PRIMARY KEY ( cal_id, cal_fullname )
);


CREATE TABLE webcal_user_pref (
  cal_login varchar(25) NOT NULL,
  cal_setting varchar(25) NOT NULL,
  cal_value varchar(50),
  PRIMARY KEY ( cal_login, cal_setting )
);



CREATE TABLE webcal_user_layers (
  cal_layerid INTEGER DEFAULT '0' NOT NULL,
  cal_login varchar(25) NOT NULL,
  cal_layeruser varchar(25) NOT NULL,
  cal_color varchar(25),
  cal_dups CHAR(1) DEFAULT 'N',
  PRIMARY KEY ( cal_login, cal_layeruser )
);



CREATE TABLE webcal_site_extras (
  cal_id INTEGER DEFAULT '0' NOT NULL,
  cal_name VARCHAR(25) NOT NULL,
  cal_type INTEGER NOT NULL,
  cal_date INTEGER DEFAULT '0',
  cal_remind INTEGER DEFAULT '0',
  cal_data varchar(4096),
  PRIMARY KEY ( cal_id, cal_name, cal_type )
);


CREATE TABLE webcal_reminder_log (
  cal_id INTEGER DEFAULT '0' NOT NULL,
  cal_name VARCHAR(25) NOT NULL,
  cal_event_date INTEGER NOT NULL DEFAULT 0,
  cal_last_sent INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY ( cal_id, cal_name, cal_event_date )
);

CREATE TABLE webcal_group (
  cal_group_id INTEGER NOT NULL,
  cal_owner VARCHAR(25) NULL,
  cal_name VARCHAR(50) NOT NULL,
  cal_last_update INTEGER NOT NULL,
  PRIMARY KEY ( cal_group_id )
);

CREATE TABLE webcal_group_user (
  cal_group_id INTEGER NOT NULL,
  cal_login VARCHAR(25) NOT NULL,
  PRIMARY KEY ( cal_group_id, cal_login )
);

CREATE TABLE webcal_view (
  cal_view_id INTEGER NOT NULL,
  cal_owner VARCHAR(25) NOT NULL,
  cal_name VARCHAR(50) NOT NULL,
  cal_view_type CHAR(1),
  PRIMARY KEY ( cal_view_id )
);

CREATE TABLE webcal_view_user (
  cal_view_id INTEGER NOT NULL,
  cal_login VARCHAR(25) NOT NULL,
  PRIMARY KEY ( cal_view_id, cal_login )
);

CREATE TABLE webcal_config (
  cal_setting VARCHAR(50) NOT NULL,
  cal_value VARCHAR(50) NULL,
  PRIMARY KEY ( cal_setting )
);


INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'LANGUAGE', 'Browser-defined' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'demo_mode', 'N' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'require_approvals', 'Y' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'groups_enabled', 'N' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'user_sees_only_his_groups', 'N' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'categories_enabled', 'N' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'allow_conflicts', 'N' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'conflict_repeat_months', '6' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'disable_priority_field', 'N' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'disable_access_field', 'N' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'disable_participants_field', 'N' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'disable_repeating_field', 'N' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'allow_view_other', 'Y' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'email_fallback_from', 'youremailhere' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'remember_last_login', 'Y' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'allow_color_customization', 'Y' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'BGCOLOR', '#C0C0C0' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'H2COLOR', '#000000' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'CELLBG', '#C0C0C0' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'WEEKENDBG', '#D0D0D0' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'TABLEBG', '#000000' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'THBG', '#FFFFFF' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'THFG', '#000000' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'POPUP_FG', '#000000' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'POPUP_BG', '#FFFFFF' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'TODAYCELLBG', '#E0E0E0' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'STARTVIEW', 'week' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'WEEK_START', '0' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'TIME_FORMAT', '12' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'DISPLAY_UNAPPROVED', 'Y' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'DISPLAY_WEEKNUMBER', 'Y' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'WORK_DAY_START_HOUR', '8' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'WORK_DAY_END_HOUR', '17' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'send_email', 'N' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'EMAIL_REMINDER', 'Y' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'EMAIL_EVENT_ADDED', 'Y' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'EMAIL_EVENT_UPDATED', 'Y' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'EMAIL_EVENT_DELETED', 'Y' );
INSERT INTO webcal_config ( cal_setting, cal_value )
  VALUES ( 'EMAIL_EVENT_REJECTED', 'Y' );


CREATE TABLE webcal_entry_log (
  cal_log_id INTEGER NOT NULL,
  cal_entry_id INTEGER NOT NULL,
  cal_login VARCHAR(25) NOT NULL,
  cal_user_cal VARCHAR(25) NULL,
  cal_type CHAR(1) NOT NULL,
  cal_date INTEGER NOT NULL,
  cal_time INTEGER NULL,
  cal_text varchar(4096),
  PRIMARY KEY ( cal_log_id )
);


CREATE TABLE webcal_categories (
  cat_id INTEGER NOT NULL,
  cat_owner VARCHAR(25),
  cat_name VARCHAR(80) NOT NULL,
  PRIMARY KEY ( cat_id )
);

CREATE TABLE webcal_asst (
  cal_boss VARCHAR(25) NOT NULL,
  cal_assistant VARCHAR(25) NOT NULL,
  PRIMARY KEY ( cal_boss, cal_assistant )
);
