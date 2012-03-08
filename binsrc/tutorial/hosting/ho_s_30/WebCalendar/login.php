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
include "includes/connect.php";

load_global_settings ();

if ( ! empty ( $last_login ) )
  $login = "";

if ( $remember_last_login == "Y" && empty ( $login ) ) {
  $last_login = $login = $webcalendar_login;
}

load_user_preferences ();

include "includes/translate.php";

// see if a return path was set
if ( ! empty ( $return_path ) ) {
  $url = $return_path;
} else {
  $url = "index.php";
}

// calculate path for cookie
if ( empty ( $PHP_SELF ) )
  $PHP_SELF = $_SERVER["PHP_SELF"];
$cookie_path = str_replace ( "login.php", "", $PHP_SELF );
//echo "Cookie path: $cookie_path\n";

if ( $single_user == "Y" ) {
  // No login for single-user mode
  do_redirect ( "index.php" );
} else if ( $use_http_auth ) {
  // There is no login page when using HTTP authorization
  do_redirect ( "index.php" );
} else {
  if ( ! empty ( $login ) && ! empty ( $password ) ) {
    $login = trim ( $login );
    if ( user_valid_login ( $login, $password ) ) {
      user_load_variables ( $login, "" );
      // set login to expire in 365 days
      srand((double) microtime() * 1000000);
      $salt = chr( rand(ord('A'), ord('z'))) . chr( rand(ord('A'), ord('z')));
      $encoded_login = encode_string ( $login . "|" . crypt($password, $salt) );

      if ( $remember == "yes" )
        SetCookie ( "webcalendar_session", $encoded_login,
          time() + ( 24 * 3600 * 365 ), $cookie_path );
      else
        SetCookie ( "webcalendar_session", $encoded_login, 0, $cookie_path );
      // The cookie "webcalendar_login" is provided as a convenience to
      // other apps that may wish to find out what the last calendar
      // login was, so they can use week_ssi.php as a server-side include.
      // As such, it's not a security risk to have it un-encoded since it
      // is not used to allow logins within this app.  It is used to
      // load user preferences on the login page (before anyone has
      // logged in) if $remember_last_login is set to "Y" (in admin.php).
      if ( $remember == "yes" )
        SetCookie ( "webcalendar_login", $login,
          time() + ( 24 * 3600 * 365 ), $cookie_path );
      else
        SetCookie ( "webcalendar_login", $login, 0, $cookie_path );
      do_redirect ( $url );
    }
  }
  // delete current user
  SetCookie ( "webcalendar_session", "", 0, $cookie_path );
  // In older versions the cookie path had no trailing slash and NS 4.78
  // thinks "path/" and "path" are different, so the line above does not
  // delete the "old" cookie. This prohibits the login. So we delete the
  // cookie with the trailing slash removed
  if (substr($cookie_path, -1) == '/')
    SetCookie ( "webcalendar_session", "", 0, substr($cookie_path, 0, -1)  );
}

?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<SCRIPT LANGUAGE="JavaScript">
// error check login/password
function valid_form ( form ) {
  if ( form.login.value.length == 0 || form.password.value.length == 0 ) {
    alert ( "<?php etranslate("You must enter a login and password")?>." );
    return false;
  }
  return true;
}
function myOnLoad() {
  <?php if ( $plugins_enabled ) { ?>
  if (self != top)  {
    window.open("login.php","_top","");
    return;
  }
  <?php } ?>
  document.forms[0].login.focus();
  <?php
    if ( ! empty ( $login ) ) echo "document.forms[0].login.select();"
  ?>
  }
}
</SCRIPT>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR;?>"
ONLOAD="myOnLoad();" CLASS="defaulttext">

<H2><FONT COLOR="<?php echo $H2COLOR?>"><?php etranslate($application_name)?></FONT></H2>

<?php
if ( ! empty ( $error ) ) {
  print "<FONT COLOR=\"#FF0000\"><B>" . translate("Error") .
    ":</B> $error</FONT><P>\n";
}
?>
<FORM NAME="login_form" ACTION="login.php" METHOD="POST" ONSUBMIT="return valid_form(this)">

<?php
if ( ! empty ( $return_path ) )
  echo "<INPUT TYPE=\"hidden\" NAME=\"return_path\" VALUE=\"" .
    htmlentities ( $return_path ) . "\">\n";
?>

<TABLE BORDER=0>
<TR><TD><B><?php etranslate("Username")?>:</B></TD>
  <TD><INPUT NAME="login" SIZE=10 VALUE="<?php if ( isset ( $last_login ) ) echo $last_login; else echo "admin";?>" TABINDEX="1"></TD></TR>
<TR><TD><B><?php etranslate("Password")?>:</B></TD>
  <TD><INPUT NAME="password" TYPE="password" SIZE=10 value="admin" TABINDEX="2"></TD></TR>
<TR><TD COLSPAN=2><INPUT TYPE="checkbox" NAME="remember" VALUE="yes" <?php if ( ! empty ( $remember ) && $remember == "yes" ) echo "CHECKED"; ?>> <?php etranslate("Save login via cookies so I don't have to login next time")?></TD></TR>
<TR><TD COLSPAN=2><INPUT TYPE="submit" VALUE="<?php etranslate("Login")?>" TABINDEX="3"></TD></TR>
</TABLE>

</FORM>

<P>
<?php if ( $public_access == "Y" ) { ?>
  <A CLASS="navlinks" HREF="week.php"><?php etranslate("Access public calendar")?></A><P>
<?php } ?>

<?php
if ( $demo_mode == "Y" ) {
  // This is used on the sourceforge demo page
  echo "Demo login: user = \"demo\", password = \"demo\" <P>";
}
?>
<BR><BR><BR>
<FONT SIZE="-1">
<?php etranslate("cookies-note")?>
<P>
<HR><P>
<A HREF="<?php echo $PROGRAM_URL ?>" CLASS="aboutinfo"><?php echo $PROGRAM_NAME?></A>
</FONT>
</BODY>
</HTML>
