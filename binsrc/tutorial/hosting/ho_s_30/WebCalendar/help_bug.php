<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2012 OpenLink Software
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

<H2><FONT COLOR="<?php echo $H2COLOR;?>"><?php etranslate("Report Bug")?></FONT></H2>

<!--
No need to translate the text below since I want all bugs
reported in English. 
Americans only speak English, of course ;-)
-->
Please include all the information below when reporting a bug.
<?php if ( $LANGUAGE != "English-US" ) { ?>
Also.... when reporting a bug, please use <B>English</B>
rather than <?php echo $LANGUAGE?>.
<?php } ?>

<FORM ACTION="http://sourceforge.net/tracker/" TARGET="_new">
<INPUT TYPE="hidden" NAME="func" VALUE="add">
<INPUT TYPE="hidden" NAME="group_id" VALUE="3870">
<INPUT TYPE="hidden" NAME="atid" VALUE="103870">
<INPUT TYPE="submit" VALUE="<?php etranslate("Report Bug")?>">
</FORM>
<P>

<H3><FONT COLOR="<?php echo $H2COLOR;?>"><?php etranslate("System Settings")?></FONT></H3>
<?php

if ( empty ( $SERVER_SOFTWARE ) )
  $SERVER_SOFTWARE = $_SERVER["SERVER_SOFTWARE"];
if ( empty ( $HTTP_USER_AGENT ) )
  $HTTP_USER_AGENT = $_SERVER["HTTP_USER_AGENT"];
if ( empty ( $HTTP_USER_AGENT ) )
  $HTTP_USER_AGENT = $_SERVER["HTTP_USER_AGENT"];

echo "<PRE>";
printf ( "%-25s: %s\n", "PROGRAM_NAME", $PROGRAM_NAME );
printf ( "%-25s: %s\n", "SERVER_SOFTWARE", $SERVER_SOFTWARE );
printf ( "%-25s: %s\n", "Web Browser", $HTTP_USER_AGENT );
printf ( "%-25s: %s\n", "db_type", $db_type );
printf ( "%-25s: %s\n", "readonly", $readonly );
printf ( "%-25s: %s\n", "single_user", $single_user );
printf ( "%-25s: %s\n", "single_user_login", $single_user_login );
printf ( "%-25s: %s\n", "use_http_auth", $use_http_auth ? "true" : "false" );
printf ( "%-25s: %s\n", "user_inc", $user_inc );

$res = dbi_query ( "SELECT cal_setting, cal_value FROM webcal_config" );
if ( $res ) {
  while ( $row = dbi_fetch_row ( $res ) ) {
    printf ( "%-25s: %s\n", $row[0], $row[1] );
  }
  dbi_free_result ( $res );
}

echo "</PRE>\n";

?>

<?php include "includes/help_trailer.php"; ?>

</BODY>
</HTML>
