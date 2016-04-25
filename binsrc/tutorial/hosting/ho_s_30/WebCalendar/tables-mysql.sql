--  
--  $Id$
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
--  
/*
 * Description:
 *	This file is used to create all tables used by WebCalendar and
 *	initialize some of those tables with the required data.
 *
 *	The comments in the table definitions will be parsed to
 *	generate a document (in HTML) that describes these tables.
 *
 * History:
 *	21-Oct-2002	Added this file header and additional comments
 *			below.
 */

/*
 * Defines a WebCalendar user.
 */
CREATE TABLE webcal_user (
  /* the unique user login */
  cal_login VARCHAR(25) NOT NULL,
  /* the user's password. (not used for http or ldap authentication) */
  cal_passwd VARCHAR(25),
  /* user's last name */
  cal_lastname VARCHAR(25),
  /* user's first name */
  cal_firstname VARCHAR(25),
  /* is the user a WebCalendar administrator ('Y' = yes, 'N' = no) */
  cal_is_admin CHAR(1) DEFAULT 'N',
  /* user's email address */
  cal_email VARCHAR(75) NULL,
  PRIMARY KEY ( cal_login )
);

# create a default admin user
INSERT INTO webcal_user ( cal_login, cal_passwd, cal_lastname, cal_firstname, cal_is_admin ) VALUES ( 'admin', 'admin', 'Administrator', 'Default', 'Y' );


/*
 * Defines a calendar event.  Each event in the system has one entry
 * in this table unless the event starts before midnight and ends
 * after midnight.  In that case a secondary event will be created with
 * cal_ext_for_id set to the cal_id of the original entry.
 * The following tables contain additional information about each
 * event: <UL>
 * <LI> <A HREF="#webcal_entry_user">webcal_entry_user</A> -
 *  lists participants in the event and specifies the status (accepted,
 *  rejected) and category of each participant.
 * <LI> <A HREF="#webcal_entry_repeats">webcal_entry_repeats</A> -
 *  contains information if the event repeats.
 * <LI> <A HREF="#webcal_entry_repeats_not">webcal_entry_repeats_not</A> -
 *  specifies which dates the repeating event does not repeat (because
 *  they were deleted or modified for just that date by the user)
 * <LI> <A HREF="#webcal_entry_log">webcal_entry_log</A> -
 *  provides a history of changes to this event.
 * <LI> <A HREF="#webcal_site_extras">webcal_site_extras</A> -
 *  stores event data as defined in site_extras.php (such as reminders and
 *  other custom event fields).
 * </UL>
 */
CREATE TABLE webcal_entry (
  /* cal_id is unique integer id for event */
  cal_id INT NOT NULL,
  /* cal_group_id: the parent event id if this event is overriding an */
  /* occurrence of a repeating event */
  cal_group_id INT NULL,
  /* used when an event goes past midnight into the */
  /* next day, in which case an additional entry in this table */
  /* will use this field to indicate the original event cal_id */
  cal_ext_for_id INT NULL,
  /* user login of user that created the event */
  cal_create_by VARCHAR(25) NOT NULL,
  /* date of event (in YYYYMMDD format) */
  cal_date INT NOT NULL,
  /* event time (in HHMMSS format) */
  cal_time INT NULL,
  /* date the event was last modified (in YYYYMMDD format) */
  cal_mod_date INT,
  /* time the event was last modified (in HHMMSS format) */
  cal_mod_time INT,
  /* duration of event in minutes */
  cal_duration INT NOT NULL,
  /* event priority: 1=Low, 2=Med, 3=High */
  cal_priority INT DEFAULT 2,
  /* 'E' = Event, 'M' = Repeating event */
  cal_type CHAR(1) DEFAULT 'E',
  /* 'P' = Public, */
  /* 'R' = Confidential (others can see time allocated but not what it is) */
  cal_access CHAR(1) DEFAULT 'P',
  /* brief description of event */
  cal_name VARCHAR(80) NOT NULL,
  /* full description of event */
  cal_description TEXT,
  PRIMARY KEY ( cal_id )
);


/*
 * Defines repeating info about an event.
 * The event is defined in <A HREF="#webcal_entry">webcal_entry</A>.
 */
CREATE TABLE webcal_entry_repeats (
  /* event id */
  cal_id INT DEFAULT 0 NOT NULL,
  /* type of repeating:<UL> */
  /* <LI>  daily - repeats daily */
  /* <LI>  monthlyByDate - repeats on same day of the month */
  /* <LI>  monthlyByDay - repeats on specified day (2nd Monday, for example) */
  /* <LI>  weekly - repeats every week */
  /* <LI>  yearly - repeats on same date every year */
  cal_type VARCHAR(20),
  /* end date for repeating event (in YYYYMMDD format) */
  cal_end INT,
  /* frequency of repeat: 1 = every, 2 = every other, 3 = every 3rd, etc. */
  cal_frequency INT DEFAULT 1,
  /* which days of the week does it repeat on (only applies when cal_type = 'weekly' */
  cal_days CHAR(7),
  PRIMARY KEY (cal_id)
);


/*
 * This table specifies which dates in a repeating
 * event have either been deleted or replaced with
 * a replacement event for that day.  When replaced, the cal_group_id
 * (I know... not the best name, but it wasn't being used) column will
 * be set to the original event.  That way the user can delete the original
 * event and (at the same time) delete any exception events.
 */
CREATE TABLE webcal_entry_repeats_not (
  /* event id of repeating event */
  cal_id INT NOT NULL,
  /* cal_date: date event should not repeat (in YYYYMMDD format) */
  cal_date INT NOT NULL,
  PRIMARY KEY ( cal_id, cal_date )
);


/*
 * This table associates one or more users with an event by the event id.
 * The event can be found in
 * <A HREF="#webcal_entry">webcal_entry</A>.
 */
CREATE TABLE webcal_entry_user (
  /* event id */
  cal_id INT DEFAULT 0 NOT NULL,
  /* participant in the event */
  cal_login VARCHAR(25) NOT NULL,
  /* status of event for this user: <UL> */
  /* <LI>   A=Accepted */
  /* <LI>   R=Rejected */
  /* <LI>   W=Waiting    </UL>*/
  cal_status CHAR(1) DEFAULT 'A',
  /* category of the event for this user */
  cal_category INT DEFAULT NULL,
  PRIMARY KEY ( cal_id, cal_login )
);


/*
 * This table associates one or more external users (people who do not
 * have a WebCalendar login) with an event by the event id.
 * An event must still have at least one WebCalendar user associated
 * with it.  This table is not used unless external users is enabled
 * in system settings.
 * The event can be found in
 * <A HREF="#webcal_entry">webcal_entry</A>.
 */
CREATE TABLE webcal_entry_ext_user (
  /* event id */
  cal_id INT DEFAULT 0 NOT NULL,
  /* external user fill name */
  cal_fullname VARCHAR(50) NOT NULL,
  /* external user email (for sending a reminder) */
  cal_email VARCHAR(75) NULL,
  PRIMARY KEY ( cal_id, cal_fullname )
);



/*
 * Specify preferences for a user.
 * Most preferences are set via pref.php.
 * Values in this table are loaded after system settings
 * found in <A HREF="#webcal_config">webcal_config</A>.
 */
CREATE TABLE webcal_user_pref (
  /* user login */
  cal_login VARCHAR(25) NOT NULL,
  /* setting name */
  cal_setting VARCHAR(25) NOT NULL,
  /* setting value */
  cal_value VARCHAR(50) NULL,
  PRIMARY KEY ( cal_login, cal_setting )
);


/*
 * Define layers for a user.
 */
CREATE TABLE webcal_user_layers (
  /* unique layer id */
  cal_layerid INT DEFAULT 0 NOT NULL,
  /* login of owner of this layer */
  cal_login VARCHAR(25) NOT NULL,
  /* login name of user that this layer represents */
  cal_layeruser VARCHAR(25) NOT NULL,
  /* color to display this layer in */
  cal_color VARCHAR(25) NULL,
  /* show duplicates ('N' or 'Y') */
  cal_dups CHAR(1) DEFAULT 'N',
  PRIMARY KEY ( cal_login, cal_layeruser )
);

/*
 * This table holds data for site extra fields
 * (customized in site_extra.php).
 */
CREATE TABLE webcal_site_extras (
  /* event id */
  cal_id INT DEFAULT 0 NOT NULL,
  /* the brief name of this type (first field in $site_extra array) */
  cal_name VARCHAR(25) NOT NULL,
  /* $EXTRA_URL, $EXTRA_DATE, etc. */
  cal_type INT NOT NULL,
  /* only used for $EXTRA_DATE type fields (in YYYYMMDD format) */
  cal_date INT DEFAULT 0,
  /* how many minutes before event should a reminder be sent */
  cal_remind INT DEFAULT 0,
  /* used to store text data */
  cal_data TEXT,
  PRIMARY KEY ( cal_id, cal_name, cal_type )
);

/*
 * This table keeps a history of when reminders get sent.
 */
CREATE TABLE webcal_reminder_log (
  /* event id */
  cal_id INT DEFAULT 0 NOT NULL,
  /* extra type (see site_extras.php) */
  cal_name VARCHAR(25) NOT NULL,
  /* the event date we are sending reminder for (in YYYYMMDD format) */
  cal_event_date INT NOT NULL DEFAULT 0,
  /* the date/time we last sent a reminder (in UNIX time format) */
  cal_last_sent INT NOT NULL DEFAULT 0,
  PRIMARY KEY ( cal_id, cal_name, cal_event_date )
);

/*
 * Define a group.  Group members can be found in
 * <A HREF="#webcal_group_user">webcal_group_user</A>.
 */
CREATE TABLE webcal_group (
  /* unique group id */
  cal_group_id INT NOT NULL,
  /* user login of user that created this group */
  cal_owner VARCHAR(25) NULL,
  /* name of the group */
  cal_name VARCHAR(50) NOT NULL,
  /* date last updated (in YYYYMMDD format) */
  cal_last_update INT NOT NULL,
  PRIMARY KEY ( cal_group_id )
);

/*
 * Specify users in a group.  The group is defined in
 * <A HREF="#webcal_group">webcal_group</A>.
 */
CREATE TABLE webcal_group_user (
  /* group id */
  cal_group_id INT NOT NULL,
  /* user login */
  cal_login VARCHAR(25) NOT NULL,
  PRIMARY KEY ( cal_group_id, cal_login )
);

/*
 * A "view" allows a user to put the calendars of multiple users all on
 * one page.  A "view" is valid only for the owner (cal_owner) of the
 * view.  Users for the view are in
 * <A HREF="#webcal_view_user">webcal_view_user</A>.
 */
CREATE TABLE webcal_view (
  /* unique view id */
  cal_view_id INT NOT NULL,
  /* login name of owner of this view */
  cal_owner VARCHAR(25) NOT NULL,
  /* name of view */
  cal_name VARCHAR(50) NOT NULL,
  /* "W" for week view, "D" for day view, "M" for month view */
  cal_view_type CHAR(1),
  PRIMARY KEY ( cal_view_id )
);

/*
 * Specify users in a view. See <A HREF="#webcal_view">webcal_view</A>.
 */
CREATE TABLE webcal_view_user (
  /* view id */
  cal_view_id INT NOT NULL,
  /* a user in the view */
  cal_login VARCHAR(25) NOT NULL,
  PRIMARY KEY ( cal_view_id, cal_login )
);


/*
 * System settings (set by the admin interface in admin.php)
 */
CREATE TABLE webcal_config (
  /* setting name */
  cal_setting VARCHAR(50) NOT NULL,
  /* setting value */
  cal_value VARCHAR(50) NULL,
  PRIMARY KEY ( cal_setting )
);

# default settings
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


/*
 * Activity log for an event.
 */
CREATE TABLE webcal_entry_log (
  /* unique id of this log entry */
  cal_log_id INT NOT NULL,
  /* event id */
  cal_entry_id INT NOT NULL,
  /* user who performed this action */
  cal_login VARCHAR(25) NOT NULL,
  /* user who's calendar was affected */
  cal_user_cal VARCHAR(25) NULL,
  /* log types:  <UL> */
  /* <LI>    C: Created  */
  /* <LI>    A: Approved/Confirmed by user  */
  /* <LI>    R: Rejected by user  */
  /* <LI>    U: Updated by user  */
  /* <LI>    M: Mail Notification sent  */
  /* <LI>    E: Reminder sent     </UL>*/
  cal_type CHAR(1) NOT NULL,
  /* date in YYYYMMDD format */
  cal_date INT NOT NULL,
  /* time in HHMMSS format */
  cal_time INT NULL,
  /* optional text */
  cal_text TEXT,
  PRIMARY KEY ( cal_log_id )
);

/*
 * Defines user categories.
 * Categories can be specific to a user or global.  When a cateogry is global,
 * the cat_owner field will be NULL.  (Only an admin user can created
 * a global category.)
 */
CREATE TABLE webcal_categories (
  /* unique category id */
  cat_id INT NOT NULL,
  /* user login of category owner. */
  /* If this is NULL, then it is a global category */
  cat_owner VARCHAR(25) NULL,
  /* category name */
  cat_name VARCHAR(80) NOT NULL,
  PRIMARY KEY ( cat_id )
);

/*
 * Define assitant/boss relationship.
 */
CREATE TABLE webcal_asst (
  /* user login of boss */
  cal_boss VARCHAR(25) NOT NULL,
  /* user login of assistant */
  cal_assistant VARCHAR(25) NOT NULL,
  PRIMARY KEY ( cal_boss, cal_assistant )
);


