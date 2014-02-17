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

<H2><FONT COLOR="<?php echo $H2COLOR;?>"><?php etranslate("Help")?>: <?php etranslate("Layers")?></FONT></H2>

<TABLE BORDER=0>

<TR><TD COLSPAN=2><?php etranslate("Layers are useful for displaying other users' events in your own calendar.  You can specifiy the user and the color the events will be displayed in.")?></TD></TR>
<TR><TD COLSPAN=2> &nbsp; </TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Add/Edit/Delete")?>:</B></TD>
  <TD><?php etranslate("Clicking the Edit Layers link in the admin section at the bottom of the page will allow you to add/edit/delete layers.")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Source")?>:</B></TD>
  <TD><?php etranslate("Specifies the user that you would like to see displayed in your calendar.")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Colors")?>:</B></TD>
  <TD><?php etranslate("The text color of the new layer that will be displayed in your calendar.")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Duplicates")?>:</B></TD>
  <TD><?php etranslate("If checked, events that are duplicates of your events will be shown.")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Disabling")?>:</B></TD>
  <TD><?php etranslate("Press the Disable Layers link in the admin section at the bottom of the page to turn off layers.")?></TD></TR>
<TR><TD VALIGN="top"><B><?php etranslate("Enabling")?>:</B></TD>
  <TD><?php etranslate("Press the Enable Layers link in the admin section at the bottom of the page to turn on layers.")?></TD></TR>
      </TD></TR>

</TABLE>
<P>

<?php if ( $allow_color_customization ) { ?>
<H3><?php etranslate("Colors")?></H3>
<?php etranslate("colors-help")?>
<P>
<?php } // if $allow_color_customization ?>

<?php include "includes/help_trailer.php"; ?>

</BODY>
</HTML>
