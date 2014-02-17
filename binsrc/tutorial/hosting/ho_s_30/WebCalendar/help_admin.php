<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2014 OpenLink Software
#  
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#  
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#  
#  
?>
<?php
include "includes/config.php";
include "includes/php-dbi.php";
include "includes/functions.php";
include "includes/$user_inc";
include "includes/validate.php";
include "includes/connect.php";

load_global_settings ();
load_user_preferences ();
load_user_layers ();

include "includes/translate.php";

?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR; ?>" CLASS="defaulttext">

<H2><FONT COLOR="<?php echo $H2COLOR;?>"><?php etranslate("Help")?>: <?php etranslate("System Settings")?></FONT></H2>

<H3><?php etranslate("Settings")?></H3>
<TABLE BORDER=0>

<TR><TD VALIGN="top"><B><?php etranslate("Language")?>:</B></TD>
  <TD><?php etranslate("language-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Fonts")?>:</B></TD>
  <TD><?php etranslate("fonts-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Preferred view")?>:</B></TD>
  <TD><?php etranslate("preferred-view-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Date format")?>:</B></TD>
  <TD><?php etranslate("date-format-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Time format")?>:</B></TD>
  <TD><?php etranslate("time-format-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Time interval")?>:</B></TD>
  <TD><?php etranslate("time-interval-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Require event approvals")?>:</B></TD>
  <TD><?php etranslate("require-approvals-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Display unapproved")?>:</B></TD>
  <TD><?php etranslate("display-unapproved-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Display week number")?>:</B></TD>
  <TD><?php etranslate("display-week-number-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Week starts on")?>:</B></TD>
  <TD><?php etranslate("display-week-starts-on")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Work hours")?>:</B></TD>
  <TD><?php etranslate("work-hours-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Disable Priority field")?>:</B></TD>
  <TD><?php etranslate("disable-priority-field-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Disable Access field")?>:</B></TD>
  <TD><?php etranslate("disable-access-field-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Disable Participants field")?>:</B></TD>
  <TD><?php etranslate("disable-participants-field-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Disable Repeating field")?>:</B></TD>
  <TD><?php etranslate("disable-repeating-field-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Allow public access")?>:</B></TD>
  <TD><?php etranslate("allow-public-access-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Public access can view other users")?>:</B></TD>
  <TD><?php etranslate("public-access-view-others-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Allow viewing other user's calendars")?>:</B></TD>
  <TD><?php etranslate("allow-view-other-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Allow external users")?>:</B></TD>
  <TD><?php etranslate("allow-external-users-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("External users can receive email notifications")?>:</B></TD>
  <TD><?php etranslate("external-can-receive-notification-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("External users can receive email reminders")?>:</B></TD>
  <TD><?php etranslate("external-can-receive-reminder-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Remember last login")?>:</B></TD>
  <TD><?php etranslate("remember-last-login-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Check for event conflicts")?>:</B></TD>
  <TD><?php etranslate("conflict-check-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Conflict checking months")?>:</B></TD>
  <TD><?php etranslate("conflict-months-help")?></TD></TR>

      </TD></TR>

</TABLE>
<P>

<H3><?php etranslate("Groups")?></H3>
<TABLE BORDER=0>
<TR><TD VALIGN="top"><B><?php etranslate("Groups enabled")?>:</B></TD>
  <TD><?php etranslate("groups-enabled-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("User sees only his groups")?>:</B></TD>
  <TD><?php etranslate("user-sees-his-group-help")?></TD></TR>
</TABLE>


<H3><?php etranslate("Email")?></H3>

<TABLE BORDER=0>
<TR><TD VALIGN="top"><B><?php etranslate("Email enabled")?>:</B></TD>
  <TD><?php etranslate("email-enabled-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Default sender address")?>:</B></TD>
  <TD><?php etranslate("email-default-sender")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Event reminders")?>:</B></TD>
  <TD><?php etranslate("email-event-reminders-help")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Events added to my calendar")?>:</B></TD>
  <TD><?php etranslate("email-event-added")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Events updated on my calendar")?>:</B></TD>
  <TD><?php etranslate("email-event-updated")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Events removed from my calendar")?>:</B></TD>
  <TD><?php etranslate("email-event-deleted")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Event rejected by participant")?>:</B></TD>
  <TD><?php etranslate("email-event-rejected")?></TD></TR>
</TABLE>

<H3><?php etranslate("Colors")?></H3>
<?php etranslate("colors-help")?>
<P>

<?php include "includes/help_trailer.php"; ?>

</BODY>
</HTML>
