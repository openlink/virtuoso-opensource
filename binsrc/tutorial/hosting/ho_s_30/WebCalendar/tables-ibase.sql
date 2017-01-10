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
--  

 /* Table: WEBCAL_ENTRY, Owner: SYSDBA */

CREATE TABLE "WEBCAL_ENTRY" 
(
   "CAL_ID"	INTEGER NOT NULL,
   "CAL_GROUP_ID"	INTEGER,
   "CAL_DATE"	INTEGER NOT NULL,
   "CAL_EXT_FOR_ID"	INT NULL,
   "CAL_TIME"	INTEGER,
   "CAL_MOD_DATE"	INTEGER,
   "CAL_MOD_TIME"	INTEGER,
   "CAL_DURATION"	INTEGER NOT NULL,
   "CAL_PRIORITY"	INTEGER DEFAULT 2,
   "CAL_TYPE"	CHAR(1) CHARACTER SET WIN1252 DEFAULT 'E',
   "CAL_ACCESS"	CHAR(1) CHARACTER SET WIN1252 DEFAULT 'P',
   "CAL_NAME"	VARCHAR(80) CHARACTER SET WIN1252 NOT NULL,
   "CAL_DESCRIPTION"	VARCHAR(500) CHARACTER SET WIN1252,
   "CAL_CREATE_BY"	VARCHAR(25) CHARACTER SET WIN1252 NOT NULL
);

/* create a default admin user */
INSERT INTO webcal_user ( cal_login, cal_passwd, cal_lastname, cal_firstname, cal_is_admin ) VALUES ( 'admin', 'admin', 'Administrator', 'Default', 'Y' );





/* Table: WEBCAL_ENTRY_REPEATS, Owner: SYSDBA */

CREATE TABLE "WEBCAL_ENTRY_REPEATS" 
(
   "CAL_ID"	INTEGER DEFAULT 0 NOT NULL,
   "CAL_TYPE"	VARCHAR(20) CHARACTER SET WIN1252,
   "CAL_END"	INTEGER,
   "CAL_FREQUENCY"	INTEGER DEFAULT 1,
   "CAL_DAYS"	CHAR(7) CHARACTER SET WIN1252
);

/* Table: WEBCAL_ENTRY_REPEATS_NOT, Owner: SYSDBA */
CREATE TABLE "WEBCAL_ENTRY_REPEATS_NOT" 
   "CAL_ID"	INTEGER DEFAULT 0 NOT NULL,
   "CAL_DATE"	INTEGER NOT NULL
);


/* Table: WEBCAL_ENTRY_USER, Owner: SYSDBA */

CREATE TABLE "WEBCAL_ENTRY_USER" 
(
   "CAL_ID"	INTEGER DEFAULT 0 NOT NULL,
   "CAL_LOGIN"	VARCHAR(25) CHARACTER SET WIN1252 DEFAULT '' NOT NULL,
   "CAL_STATUS"	VARCHAR(1) CHARACTER SET WIN1252 DEFAULT 'A',
   "CAL_CATEGORY"	INTEGER NULL
);


/* Table: WEBCAL_ENTRY_EXT_USER, Owner: SYSDBA */

CREATE TABLE "WEBCAL_ENTRY_EXT_USER" 
(
   "CAL_ID"	INTEGER DEFAULT 0 NOT NULL,
   "CAL_FULLNAME"	VARCHAR(50) CHARACTER SET WIN1252 DEFAULT '' NOT NULL,
   "CAL_EMAIL"	VARCHAR(75) CHARACTER SET WIN1252
);


/* Table: WEBCAL_REMINDER_LOG, Owner: SYSDBA */

CREATE TABLE "WEBCAL_REMINDER_LOG" 
(
   "CAL_ID"	INTEGER DEFAULT 0 NOT NULL,
   "CAL_NAME"	VARCHAR(25) CHARACTER SET WIN1252 NOT NULL,
   "CAL_EVENT_DATE"	INTEGER DEFAULT 0 NOT NULL,
   "CAL_LAST_SENT"	INTEGER DEFAULT 0 NOT NULL
);


/* Table: WEBCAL_SITE_EXTRAS, Owner: SYSDBA */

CREATE TABLE "WEBCAL_SITE_EXTRAS" 
(
   "CAL_ID"	INTEGER DEFAULT 0 NOT NULL,
   "CAL_NAME"	VARCHAR(25) CHARACTER SET WIN1252 NOT NULL,
   "CAL_TYPE"	INTEGER NOT NULL,
   "CAL_DATE"	INTEGER DEFAULT 0,
   "CAL_REMIND"	INTEGER DEFAULT 0,
   "CAL_DATA"	VARCHAR(500) CHARACTER SET WIN1252
);


/* Table: WEBCAL_USER, Owner: SYSDBA */

CREATE TABLE "WEBCAL_USER" 
(
   "CAL_LOGIN"	VARCHAR(25) CHARACTER SET WIN1252 NOT NULL,
   "CAL_PASSWD"	VARCHAR(25) CHARACTER SET WIN1252,
   "CAL_LASTNAME"	VARCHAR(25) CHARACTER SET WIN1252,
   "CAL_FIRSTNAME"	VARCHAR(25) CHARACTER SET WIN1252,
   "CAL_IS_ADMIN"	CHAR(1) CHARACTER SET WIN1252 DEFAULT 'N',
   "CAL_EMAIL"	VARCHAR(75) CHARACTER SET WIN1252
);


/* Table: WEBCAL_USER_LAYERS, Owner: SYSDBA */

CREATE TABLE "WEBCAL_USER_LAYERS" 
(
   "CAL_LAYERID"	INTEGER DEFAULT 0 NOT NULL,
   "CAL_LOGIN"	VARCHAR(25) CHARACTER SET WIN1252 NOT NULL,
   "CAL_LAYERUSER"	VARCHAR(25) CHARACTER SET WIN1252 NOT NULL,
   "CAL_COLOR"	VARCHAR(25) CHARACTER SET WIN1252,
   "CAL_DUPS"	CHAR(1) CHARACTER SET WIN1252 DEFAULT 'N'
);


/* Table: WEBCAL_USER_PREF, Owner: SYSDBA */

CREATE TABLE "WEBCAL_USER_PREF" 
(
   "CAL_LOGIN"	VARCHAR(25) CHARACTER SET WIN1252 NOT NULL,
   "CAL_SETTING"	VARCHAR(25) CHARACTER SET WIN1252 NOT NULL,
   "CAL_VALUE"	VARCHAR(50) CHARACTER SET WIN1252
);

/* Table: WEBCAL_GROUP, Owner: SYSDBA */

CREATE TABLE "WEBCAL_GROUP" 
(
   "CAL_GROUP_ID"	INTEGER DEFAULT 0 NOT NULL,
   "CAL_OWNER"	VARCHAR(25) CHARACTER SET WIN1252 NULL,
   "CAL_NAME"	VARCHAR(50) CHARACTER SET WIN1252 NOT NULL,
   "CAL_LAST_UPDATE"	INTEGER DEFAULT 0 NOT NULL
);

/* Table: WEBCAL_GROUP_USER, Owner: SYSDBA */

CREATE TABLE "WEBCAL_GROUP_USER" 
(
   "CAL_GROUP_ID"	INTEGER DEFAULT 0 NOT NULL,
   "CAL_LOGIN"	VARCHAR(25) CHARACTER SET WIN1252 NOT NULL
);

/* Table: WEBCAL_VIEW, Owner: SYSDBA */

CREATE TABLE "WEBCAL_VIEW" 
(
   "CAL_VIEW_ID"	INTEGER DEFAULT 0 NOT NULL,
   "CAL_OWNER"	VARCHAR(25) CHARACTER SET WIN1252 NOT NULL,
   "CAL_NAME"	VARCHAR(50) CHARACTER SET WIN1252 NOT NULL,
   "CAL_VIEW_TYPE"	VARCHAR(1) CHARACTER SET WIN1252 NOT NULL
);

/* Table: WEBCAL_VIEW_USER, Owner: SYSDBA */

CREATE TABLE "WEBCAL_VIEW_USER" 
(
   "CAL_VIEW_ID"	INTEGER DEFAULT 0 NOT NULL,
   "CAL_LOGIN"	VARCHAR(25) CHARACTER SET WIN1252 NOT NULL
);

/* Table: WEBCAL_CONFIG, Owner: SYSDBA */

CREATE TABLE "WEBCAL_CONFIG" 
(
   "CAL_SETTING"	VARCHAR(50) CHARACTER SET WIN1252 NOT NULL,
   "CAL_VALUE"	VARCHAR(50) CHARACTER SET WIN1252
);



/* default system settings */
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


/* Table: WEBCAL_ENTRY_LOG, Owner: SYSDBA */

CREATE TABLE "WEBCAL_ENTRY_LOG" 
(
   "CAL_LOG_ID"	INTEGER DEFAULT 0 NOT NULL,
   "CAL_ENTRY_ID"	INTEGER DEFAULT 0 NOT NULL,
   "CAL_LOGIN"	VARCHAR(25) CHARACTER SET WIN1252 NOT NULL,
   "CAL_USER_CAL"	VARCHAR(25) CHARACTER SET WIN1252 NULL,
   "CAL_TYPE"	VARCHAR(1) CHARACTER SET WIN1252 NOT NULL,
   "CAL_DATE"	INTEGER NULL,
   "CAL_TIME"	INTEGER NULL,
   "CAL_TEXT"	VARCHAR(500) CHARACTER SET WIN1252 NULL
);


/* Table: WEBCAL_CATEGORIES, Owner: SYSDBA */

CREATE TABLE "WEBCAL_CATEGORIES" 
(
   "CAT_ID"	INTEGER DEFAULT 0 NOT NULL,
   "CAT_OWNER"	VARCHAR(25) CHARACTER SET WIN1252 NULL,
   "CAT_NAME"	VARCHAR(80) CHARACTER SET WIN1252 NOT NULL
);


/*  Index definitions for all user tables */

CREATE INDEX "IWEBCAL_ENTRYNEWINDEX" ON "WEBCAL_ENTRY"("CAL_ID");
CREATE INDEX "IWEBCAL_ENTRY_REPEATSNEWINDEX" ON "WEBCAL_ENTRY_REPEATS"("CAL_ID");
CREATE INDEX "IWEBCAL_ENTRY_REPEATS_NOTNEWINDEX" ON "WEBCAL_ENTRY_REPEATS_NOT"("CAL_ID", "CAL_DATE");
CREATE INDEX "IWEBCAL_ENTRY_USERNEWINDEX" ON "WEBCAL_ENTRY_USER"("CAL_ID", "CAL_LOGIN");
CREATE INDEX "IWEBCAL_ENTRY_EXTUSERNEWINDEX" ON "WEBCAL_ENTRY_EXT_USER"("CAL_ID", "CAL_FULLNAME");
CREATE INDEX "IWEBCAL_REMINDER_LOGNEWINDEX" ON "WEBCAL_REMINDER_LOG"("CAL_ID", "CAL_NAME", "CAL_EVENT_DATE");
CREATE INDEX "IWEBCAL_SITE_EXTRASNEWINDEX" ON "WEBCAL_SITE_EXTRAS"("CAL_ID", "CAL_NAME", "CAL_TYPE");
CREATE INDEX "IWEBCAL_USERNEWINDEX" ON "WEBCAL_USER"("CAL_LOGIN");
CREATE INDEX "IWEBCAL_USER_LAYERSNEWINDEX" ON "WEBCAL_USER_LAYERS"("CAL_LOGIN", "CAL_LAYERUSER");
CREATE INDEX "IWEBCAL_USER_PREFNEWINDEX" ON "WEBCAL_USER_PREF"("CAL_LOGIN", "CAL_SETTING");
CREATE INDEX "IWEBCAL_GROUPNEWINDEX" ON "WEBCAL_GROUP"("CAL_GROUP_ID");
CREATE INDEX "IWEBCAL_GROUPUSERNEWINDEX" ON "WEBCAL_GROUP_USER"("CAL_GROUP_ID", "CAL_LOGIN");
CREATE INDEX "IWEBCAL_VIEWNEWINDEX" ON "WEBCAL_VIEW"("CAL_VIEW_ID");
CREATE INDEX "IWEBCAL_VIEWUSERNEWINDEX" ON "WEBCAL_VIEW_USER"("CAL_VIEW_ID", "CAL_LOGIN");
CREATE INDEX "IWEBCAL_CONFIGNEWINDEX" ON "WEBCAL_CONFIG"("CAL_SETTING");
CREATE INDEX "IWEBCAL_ENTRYLOGINDEX" ON "WEBCAL_CONFIG"("CAL_LOG_ID");
CREATE INDEX "IWEBCAL_CATEGORIESINDEX" ON "WEBCAL_CATEGORIES"("CAT_ID");

