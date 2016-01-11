<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2016 OpenLink Software
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

<H2><FONT COLOR="<?php echo $H2COLOR;?>"><?php etranslate("Help")?>: <?php etranslate("Adding/Editing Calendar Entries")?></FONT></H2>

<TABLE BORDER=0>
<TR>
<TD VALIGN="top"><B><?php etranslate("Brief Description")?>:</B></TD>
  <TD><?php etranslate("brief-description-help")?></TD></TR>
<TD VALIGN="top"><B><?php etranslate("Full Description")?>:</B></TD>
  <TD><?php etranslate("full-description-help")?></TD></TR>
<TD VALIGN="top"><B><?php etranslate("Date")?>:</B></TD>
  <TD><?php etranslate("date-help")?></TD></TR>
<TD VALIGN="top"><B><?php etranslate("Time")?>:</B></TD>
  <TD><?php etranslate("time-help")?></TD></TR>
<TD VALIGN="top"><B><?php etranslate("Duration")?>:</B></TD>
  <TD><?php etranslate("duration-help")?></TD></TR>

<?php if ( $disable_priority_field != "Y" ) { ?>
<TD VALIGN="top"><B><?php etranslate("Priority")?>:</B></TD>
  <TD><?php etranslate("priority-help")?></TD></TR>
<?php } ?>

<?php if ( $disable_access_field != "Y" ) { ?>
<TD VALIGN="top"><B><?php etranslate("Access")?>:</B></TD>
  <TD><?php etranslate("access-help")?></TD></TR>
<?php } ?>

<?php
$show_participants = ( $disable_participants_field != "Y" );
if ( $is_admin )
  $show_participants = true;
if ( $single_user == "N" && $show_participants ) { ?>
<TD VALIGN="top"><B><?php etranslate("Participants")?>:</B></TD>
  <TD><?php etranslate("participants-help")?></TD></TR>
<?php } ?>


<?php if ( $disable_repeating_field != "Y" ) { ?>
<TD VALIGN="top"><B><?php etranslate("Repeat Type")?>:</B></TD>
  <TD><?php etranslate("repeat-type-help")?></TD></TR>
<TD VALIGN="top"><B><?php etranslate("Repeat End Date")?>:</B></TD>
  <TD><?php etranslate("repeat-end-date-help")?></TD></TR>
<TD VALIGN="top"><B><?php etranslate("Repeat Day")?>:</B></TD>
  <TD><?php etranslate("repeat-day-help")?></TD></TR>
<TD VALIGN="top"><B><?php etranslate("Frequency")?>:</B></TD>
  <TD><?php etranslate("repeat-frequency-help")?></TD></TR>
<?php } ?>

</TABLE>

<?php include "includes/help_trailer.php"; ?>

</BODY>
</HTML>
