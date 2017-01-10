<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2017 OpenLink Software
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
load_user_categories ();

include "includes/translate.php";

// Reload preferences into $prefarray[].
// Get system settings first.
$updating_public = false;
$prefarray = array ();
$res = dbi_query ( "SELECT cal_setting, cal_value FROM webcal_config " );
if ( $res ) {
  while ( $row = dbi_fetch_row ( $res ) ) {
    $prefarray[$row[0]] = $row[1];
  }
  dbi_free_result ( $res );
}
if ( $is_admin && ! empty ( $public ) && $public_access == "Y" ) {
  $updating_public = true;
  $res = dbi_query ( "SELECT cal_setting, cal_value FROM webcal_user_pref " .
    "WHERE cal_login = '__public__'" );
} else {
  $res = dbi_query ( "SELECT cal_setting, cal_value FROM webcal_user_pref " .
    "WHERE cal_login = '$login'" );
}
if ( $res ) {
  while ( $row = dbi_fetch_row ( $res ) ) {
    $prefarray[$row[0]] = $row[1];
  }
  dbi_free_result ( $res );
}

?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<SCRIPT LANGUAGE="JavaScript">
// error check the colors
function valid_color ( str ) {
  var ch, j;
  var valid = "0123456789abcdefABCDEF";

  if ( str.length == 0 )
    return true;

  if ( str.charAt ( 0 ) != '#' || str.length != 7 )
    return false;

  for ( j = 1; j < str.length; j++ ) {
   ch = str.charAt ( j );
   if ( valid.indexOf ( ch ) < 0 )
     return false;
  }
  return true;
}

function valid_form ( form ) {
  var err = "";
  <?php if ( $allow_color_customization ) { ?>
  if ( ! valid_color ( form.pref_BGCOLOR.value ) )
    err += "<?php etranslate("Invalid color for document background")?>.\n";
  if ( ! valid_color ( form.pref_H2COLOR.value ) )
    err += "<?php etranslate("Invalid color for document title")?>.\n";
  if ( ! valid_color ( form.pref_CELLBG.value ) )
    err += "<?php etranslate("Invalid color for table cell background")?>.\n";
  if ( ! valid_color ( form.pref_TODAYCELLBG.value ) )
    err += "<?php etranslate("Invalid color for table cell background for today")?>.\n";
  <?php } ?>
  if ( err.length > 0 ) {
    alert ( "Error:\n\n" + err + "\n\n<?php etranslate("Color format should be '#RRGGBB'")?>" );
    return false;
  }
  return true;
}
function selectColor ( color ) {
  url = "colors.php?color=" + color;
  var colorWindow = window.open(url,"ColorSelection","width=390,height=350,resizable=yes,scrollbars=yes");
}
</SCRIPT>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR;?>" CLASS="defaulttext">

<H2><FONT COLOR="<?php echo $H2COLOR;?>">
<?php
if ( $updating_public )
  echo translate($PUBLIC_ACCESS_FULLNAME) . " ";
etranslate("Preferences")
?>
</FONT></H2>

<FORM ACTION="pref_handler.php" METHOD="POST" ONSUBMIT="return valid_form(this);" NAME="prefform">

<?php if ( $updating_public ) { ?>
  <INPUT TYPE="hidden" NAME="public" VALUE="1">
<?php } /*if ( $updating_public )*/ ?>

<H3><?php etranslate("Settings");?></H3>

<?php

if ( $is_admin ) {
  if ( empty ( $public ) ) {
    echo "<blockquote><a href=\"pref.php?public=1\">" .
      translate("Click here") . "</a> " .
      translate("to modify the preferences for the Public Access calendar") .
      "</blockquote>\n";
  }
}
?>

<TABLE BORDER="0" CELLSPACING="0" CELLPADDING="0"><TR><TD BGCOLOR="#000000"><TABLE BORDER="0" WIDTH="100%" CELLSPACING="1" CELLPADDING="2"><TR><TD WIDTH="100%" BGCOLOR="<?php echo $CELLBG ?>"><TABLE BORDER="0" WIDTH="100%">
<TR><TD VALIGN="top"><B><?php etranslate("Language")?>:</B></TD>
<TD><SELECT NAME="pref_LANGUAGE">
<?php
reset ( $languages );
while ( list ( $key, $val ) = each ( $languages ) ) {
  // Don't allow users to select browser-defined.  We want them to pick
  // a language so that when we send reminders (done without the benefit
  // of a browser-preferred language), we'll know which language to use.
  // DO let them select browser-defined for the public user.
  if ( $key != "Browser-defined" || $updating_public ) {
    echo "<OPTION VALUE=\"" . $val . "\"";
    if ( $val == $LANGUAGE ) echo " SELECTED";
    echo "> " . $key . "\n";
  }
}
?>
</SELECT>
<BR>
<?php etranslate("Your browser default language is"); echo " " . get_browser_language () . "."; ?>
</TD></TR>
<TR><TD VALIGN="top"><B CLASS="tooltip" TITLE="<?php etooltip("tz-help")?>"><?php etranslate("Timezone Offset")?>:</B></TD>
  <TD><SELECT NAME="pref_TZ_OFFSET">
  <?php
  $text_add = translate("Add N hours to");
  $text_sub = translate("Subtract N hours from");
  if ( empty ( $prefarray["TZ_OFFSET"] ) )
    $prefarray["TZ_OFFSET"] = 0;
  for ( $i = -12; $i <= 12; $i++ ) {
    echo "<OPTION VALUE=\"$i\"";
    if ( $prefarray["TZ_OFFSET"] == $i ) echo " SELECTED";
    echo "> ";
    if ( $i < 0 )
      echo str_replace ( "N", -$i, $text_sub );
    else if ( $i == 0 )
      etranslate("same as");
    else
      echo str_replace ( "N", $i, $text_add );
  }
  ?>
  </SELECT><?php etranslate("server time");?></TD></TR>

<TR><TD VALIGN="top"><B CLASS="tooltip" TITLE="<?php etooltip("fonts-help")?>"><?php etranslate("Fonts")?>:</B></TD>
  <TD><INPUT SIZE="40" NAME="pref_FONTS" VALUE="<?php echo htmlspecialchars ( $prefarray["FONTS"] );?>" </TD></TR>

<TR><TD><B><?php etranslate("Preferred view")?>:</B></TD>
<TD>
<SELECT NAME="pref_STARTVIEW">
<OPTION VALUE="day" <?php if ( $prefarray["STARTVIEW"] == "day" ) echo "SELECTED";?> ><?php etranslate("Day")?>
<OPTION VALUE="week" <?php if ( $prefarray["STARTVIEW"] == "week" ) echo "SELECTED";?> ><?php etranslate("Week")?>
<OPTION VALUE="month" <?php if ( $prefarray["STARTVIEW"] == "month" ) echo "SELECTED";?> ><?php etranslate("Month")?>
<OPTION VALUE="year" <?php if ( $prefarray["STARTVIEW"] == "year" ) echo "SELECTED";?> ><?php etranslate("Year")?>
</SELECT></TD></TR>

<TR><TD><B CLASS="tooltip" TITLE="<?php etooltip("display-weekends-help");?>"><?php etranslate("Display weekends in week view")?>:</B></TD>
  <TD><INPUT TYPE="radio" NAME="pref_DISPLAY_WEEKENDS" VALUE="Y" <?php if ( $prefarray["DISPLAY_WEEKENDS"] != "N" ) echo "CHECKED";?>> <?php etranslate("Yes")?> <INPUT TYPE="radio" NAME="pref_DISPLAY_WEEKENDS" VALUE="N" <?php if ( $prefarray["DISPLAY_WEEKENDS"] == "N" ) echo "CHECKED";?>> <?php etranslate("No")?></TD></TR>

<TR><TD VALIGN="top"><B><?php etranslate("Date format")?>:</B></TD>
  <TD>
  <SELECT NAME="pref_DATE_FORMAT">
  <?php
  // You can add new date formats below if you want.
  // but also add in admin.php.
  $datestyles = array (
    "__month__ __dd__, __yyyy__", translate("December") . " 31, 2000",
    "__dd__ __month__, __yyyy__", "31 " . translate("December") . ", 2000",
    "__dd__-__month__-__yyyy__", "31-" . translate("December") . "-2000",
    "__dd__-__month__-__yy__", "31-" . translate("December") . "-00",
    "__mm__/__dd__/__yyyy__", "12/31/2000",
    "__mm__/__dd__/__yy__", "12/31/00",
    "__mm__-__dd__-__yyyy__", "12-31-2000",
    "__mm__-__dd__-__yy__", "12-31-00",
    "__yyyy__-__mm__-__dd__", "2000-12-31",
    "__yy__-__mm__-__dd__", "00-12-31",
    "__yyyy__/__mm__/__dd__", "2000/12/31",
    "__yy__/__mm__/__dd__", "00/12/31",
    "__dd__/__mm__/__yyyy__", "31/12/2000",
    "__dd__/__mm__/__yy__", "31/12/00",
    "__dd__-__mm__-__yyyy__", "31-12-2000",
    "__dd__-__mm__-__yy__", "31-12-00"
  );
  for ( $i = 0; $i < count ( $datestyles ); $i += 2 ) {
    echo "<OPTION VALUE=\"" . $datestyles[$i] . "\"";
    if ( $prefarray["DATE_FORMAT"] == $datestyles[$i] )
      echo " SELECTED";
    echo "> " . $datestyles[$i + 1] . "\n";
  }
  ?>
</SELECT>
<BR>
  <SELECT NAME="pref_DATE_FORMAT_MY">
  <?php
  // Date format for a month and year (with no day of the month)
  // You can add new date formats below if you want.
  // but also add in admin.php.
  $datestyles = array (
    "__month__ __yyyy__", translate("December") . " 2000",
    "__month__ __yy__", translate("December") . " 00",
    "__month__-__yyyy__", translate("December") . "-2000",
    "__month__-yy", translate("December") . "-00",
    "__mm__/__yyyy__", "12/2000",
    "__mm__/__yy__", "12/00",
    "__mm__-__yyyy__", "12-2000",
    "__mm__-__yy__", "12-00",
    "__yyyy__-__mm__", "2000-12",
    "__yy__-__mm__", "00-12",
    "__yyyy__/__mm__", "2000/12",
    "__yy__/__mm__", "00/12"
  );
  for ( $i = 0; $i < count ( $datestyles ); $i += 2 ) {
    echo "<OPTION VALUE=\"" . $datestyles[$i] . "\"";
    if ( $prefarray["DATE_FORMAT_MY"] == $datestyles[$i] )
      echo " SELECTED";
    echo "> " . $datestyles[$i + 1] . "\n";
  }
  ?>
  </SELECT>
  <BR>
  <SELECT NAME="pref_DATE_FORMAT_MD">
  <?php
  // Date format for a month and day (with no year displayed)
  // You can add new date formats below if you want.
  // but also add in admin.php.
  $datestyles = array (
    "__month__ __dd__", translate("December") . " 31",
    "__month__-__dd__", translate("December") . "-31",
    "__mm__/__dd__", "12/31",
    "__mm__-__dd__", "12-31",
    "__dd__/__mm__", "31/12",
    "__dd__-__mm__", "31-12"
  );
  for ( $i = 0; $i < count ( $datestyles ); $i += 2 ) {
    echo "<OPTION VALUE=\"" . $datestyles[$i] . "\"";
    if ( $prefarray["DATE_FORMAT_MD"] == $datestyles[$i] )
      echo " SELECTED";
    echo "> " . $datestyles[$i + 1] . "\n";
  }
  ?>
  </SELECT>
</TD></TR>

<TR><TD><B><?php etranslate("Time format")?>:</B></TD>
  <TD><INPUT TYPE="radio" NAME="pref_TIME_FORMAT" VALUE="12" <?php if ( $prefarray["TIME_FORMAT"] == "12" ) echo "CHECKED";?>> <?php etranslate("12 hour")?> <INPUT TYPE="radio" NAME="pref_TIME_FORMAT" VALUE="24" <?php if ( $prefarray["TIME_FORMAT"] != "12" ) echo "CHECKED";?>> <?php etranslate("24 hour")?></TD></TR>

<TR><TD><B><?php etranslate("Time interval")?>:</B></TD>
  <TD><SELECT NAME="pref_TIME_SLOTS">
  <OPTION VALUE="24" <?php if ( $prefarray["TIME_SLOTS"] == "24" ) echo "SELECTED"?>>1 <?php etranslate("hour")?>
  <OPTION VALUE="48" <?php if ( $prefarray["TIME_SLOTS"] == "48" ) echo "SELECTED"?>>30 <?php etranslate("minutes")?>
  <OPTION VALUE="72" <?php if ( $prefarray["TIME_SLOTS"] == "72" ) echo "SELECTED"?>>20 <?php etranslate("minutes")?>
  <OPTION VALUE="144" <?php if ( $prefarray["TIME_SLOTS"] == "144" ) echo "SELECTED"?>>10 <?php etranslate("minutes")?>
  </SELECT></TD></TR>

<TR><TD><B CLASS="tooltip" TITLE="<?php etooltip("auto-refresh-help");?>"><?php etranslate("Auto-refresh calendars")?>:</B></TD>
  <TD><INPUT TYPE="radio" NAME="pref_auto_refresh" VALUE="Y" <?php if ( $prefarray["auto_refresh"] == "Y" ) echo "CHECKED";?>> <?php etranslate("Yes")?> <INPUT TYPE="radio" NAME="pref_auto_refresh" VALUE="N" <?php if ( $prefarray["auto_refresh"] != "Y" ) echo "CHECKED";?>> <?php etranslate("No")?></TD></TR>

<TR><TD>&nbsp;&nbsp;&nbsp;&nbsp;<B CLASS="tooltip" TITLE="<?php etooltip("auto-refresh-time-help");?>"><?php etranslate("Auto-refresh time")?>:</B></TD>
  <TD><INPUT NAME="pref_auto_refresh_time" SIZE="4" VALUE="<?php if ( empty ( $prefarray["auto_refresh_time"] ) ) echo "0"; else echo $prefarray["auto_refresh_time"]; ?>"> <?php etranslate("minutes")?></TD></TR>


<TR><TD><B><?php etranslate("Display unapproved")?>:</B></TD>
  <TD><INPUT TYPE="radio" NAME="pref_DISPLAY_UNAPPROVED" VALUE="Y" <?php if ( $prefarray["DISPLAY_UNAPPROVED"] != "N" ) echo "CHECKED";?>> <?php etranslate("Yes")?> <INPUT TYPE="radio" NAME="pref_DISPLAY_UNAPPROVED" VALUE="N" <?php if ( $prefarray["DISPLAY_UNAPPROVED"] == "N" ) echo "CHECKED";?>> <?php etranslate("No")?></TD></TR>
<TR><TD><B><?php etranslate("Display week number")?>:</B></TD>
  <TD><INPUT TYPE="radio" NAME="pref_DISPLAY_WEEKNUMBER" VALUE="Y" <?php if ( $DISPLAY_WEEKNUMBER != "N" ) echo "CHECKED";?>> <?php etranslate("Yes")?> <INPUT TYPE="radio" NAME="pref_DISPLAY_WEEKNUMBER" VALUE="N" <?php if ( $prefarray["DISPLAY_WEEKNUMBER"] == "N" ) echo "CHECKED";?>> <?php etranslate("No")?></TD></TR>
<TR><TD><B><?php etranslate("Week starts on")?>:</B></TD>
  <TD><INPUT TYPE="radio" NAME="pref_WEEK_START" VALUE="0" <?php if ( $prefarray["WEEK_START"] != "1" ) echo "CHECKED";?>> <?php etranslate("Sunday")?> <INPUT TYPE="radio" NAME="pref_WEEK_START" VALUE="1" <?php if ( $prefarray["WEEK_START"] == "1" ) echo "CHECKED";?>> <?php etranslate("Monday")?></TD></TR>
<TR><TD><B><?php etranslate("Work hours")?>:</B></TD>
  <TD>
  <?php etranslate("From")?> <SELECT NAME="pref_WORK_DAY_START_HOUR">
  <?php
  if ( empty ( $prefarray["WORK_DAY_START_HOUR"] ) ) {
    $prefarray["WORK_DAY_START_HOUR"] = $WORK_DAY_START_HOUR;
    $prefarray["WORK_DAY_END_HOUR"] = $WORK_DAY_END_HOUR;
  }
  for ( $i = 0; $i < 24; $i++ ) {
    echo "<OPTION VALUE=\"$i\" " .
      ( $i == $prefarray["WORK_DAY_START_HOUR"] ? "SELECTED " : "" ) .
      "> " . display_time ( $i * 10000, 1 );
  }
  ?>
  </SELECT> <?php etranslate("to")?>
  <SELECT NAME="pref_WORK_DAY_END_HOUR">
  <?php
  for ( $i = 0; $i < 24; $i++ ) {
    echo "<OPTION VALUE=\"$i\" " .
      ( $i == $prefarray["WORK_DAY_END_HOUR"] ? "SELECTED " : "" ) .
      "> " . display_time ( $i * 10000, 1 );
  }
  ?>
  </SELECT>
  </TD></TR>

<?php if ( ! empty ( $categories ) ) { ?>
<TR><TD><B><?php etranslate("Default Category")?>:</B></TD>
  <TD><SELECT NAME="pref_CATEGORY_VIEW">
  <?php
  echo "<OPTION VALUE=\"\"";
  if ( $prefarray["CATEGORY_VIEW"] == '' ) echo " SELECTED";
  echo ">".translate('All')."</OPTION>\n";
  if ( ! empty ( $categories ) ) {
    foreach( $categories as $K => $V ){
      echo "<option value=\"$K\"";
      if ( $prefarray["CATEGORY_VIEW"] == $K ) echo " SELECTED";
      echo ">$V\n";
    }
  }
  ?>

  </SELECT>
  </TD></TR>
<?php } ?>

</TABLE></TD></TR></TABLE></TD></TR></TABLE>

<?php if ( ! $updating_public ) { ?>
<H3><?php etranslate("Email")?></H3>

<TABLE BORDER="0" CELLSPACING="0" CELLPADDING="0"><TR><TD BGCOLOR="#000000"><TABLE BORDER="0" WIDTH="100%" CELLSPACING="1" CELLPADDING="2"><TR><TD WIDTH="100%" BGCOLOR="<?php echo $CELLBG ?>"><TABLE BORDER="0" WIDTH="100%">

<TR><TD VALIGN="top"><B><?php etranslate("Event reminders")?>:</B></TD>
  <TD><INPUT TYPE="radio" NAME="pref_EMAIL_REMINDER" VALUE="Y" <?php if ( $prefarray["EMAIL_REMINDER"] != "N" ) echo "CHECKED";?>> <?php etranslate("Yes")?> <INPUT TYPE="radio" NAME="pref_EMAIL_REMINDER" VALUE="N" <?php if ( $prefarray["EMAIL_REMINDER"] == "N" ) echo "CHECKED";?>> <?php etranslate("No")?></TD></TR>

<TR><TD VALIGN="top"><B><?php etranslate("Events added to my calendar")?>:</B></TD>
  <TD><INPUT TYPE="radio" NAME="pref_EMAIL_EVENT_ADDED" VALUE="Y" <?php if ( $prefarray["EMAIL_EVENT_ADDED"] != "N" ) echo "CHECKED";?>> <?php etranslate("Yes")?> <INPUT TYPE="radio" NAME="pref_EMAIL_EVENT_ADDED" VALUE="N" <?php if ( $prefarray["EMAIL_EVENT_ADDED"] == "N" ) echo "CHECKED";?>> <?php etranslate("No")?></TD></TR>

<TR><TD VALIGN="top"><B><?php etranslate("Events updated on my calendar")?>:</B></TD>
  <TD><INPUT TYPE="radio" NAME="pref_EMAIL_EVENT_UPDATED" VALUE="Y" <?php if ( $prefarray["EMAIL_EVENT_UPDATED"] != "N" ) echo "CHECKED";?>> <?php etranslate("Yes")?> <INPUT TYPE="radio" NAME="pref_EMAIL_EVENT_UPDATED" VALUE="N" <?php if ( $prefarray["EMAIL_EVENT_UPDATED"] == "N" ) echo "CHECKED";?>> <?php etranslate("No")?></TD></TR>

<TR><TD VALIGN="top"><B><?php etranslate("Events removed from my calendar")?>:</B></TD>
  <TD><INPUT TYPE="radio" NAME="pref_EMAIL_EVENT_DELETED" VALUE="Y" <?php if ( $prefarray["EMAIL_EVENT_DELETED"] != "N" ) echo "CHECKED";?>> <?php etranslate("Yes")?> <INPUT TYPE="radio" NAME="pref_EMAIL_EVENT_DELETED" VALUE="N" <?php if ( $prefarray["EMAIL_EVENT_DELETED"] == "N" ) echo "CHECKED";?>> <?php etranslate("No")?></TD></TR>

<TR><TD VALIGN="top"><B><?php etranslate("Event rejected by participant")?>:</B></TD>
  <TD><INPUT TYPE="radio" NAME="pref_EMAIL_EVENT_REJECTED" VALUE="Y" <?php if ( $prefarray["EMAIL_EVENT_REJECTED"] != "N" ) echo "CHECKED";?>> <?php etranslate("Yes")?> <INPUT TYPE="radio" NAME="pref_EMAIL_EVENT_REJECTED" VALUE="N" <?php if ( $prefarray["EMAIL_EVENT_REJECTED"] == "N" ) echo "CHECKED";?>> <?php etranslate("No")?></TD></TR>

</TABLE></TD></TR></TABLE></TD></TR></TABLE>

<?php } /* if ( ! $updating_public ) */ ?>

<?php if ( $allow_color_customization ) { ?>

<H3><?php etranslate("Colors")?></H3>

<TABLE BORDER="0" WIDTH="100%"><TR><TD VALIGN="top" ALIGN="left">

<TABLE BORDER="0" CELLSPACING="0" CELLPADDING="0"><TR><TD BGCOLOR="#000000"><TABLE BORDER="0" WIDTH="100%" CELLSPACING="1" CELLPADDING="2"><TR><TD WIDTH="100%" BGCOLOR="<?php echo $CELLBG ?>"><TABLE BORDER="0" WIDTH="100%">


<TR><TD><B><?php etranslate("Document background")?>:</B></TD>
  <TD><INPUT NAME="pref_BGCOLOR" SIZE="8" MAXLENGTH="7" VALUE="<?php echo $prefarray["BGCOLOR"]; ?>"> <INPUT TYPE="button" ONCLICK="selectColor('pref_BGCOLOR')" VALUE="<?php etranslate("Select")?>..."></TD></TR>
<TR><TD><B><?php etranslate("Document title")?>:</B></TD>
  <TD><INPUT NAME="pref_H2COLOR" SIZE="8" MAXLENGTH="7" VALUE="<?php echo $prefarray["H2COLOR"]; ?>"> <INPUT TYPE="button" ONCLICK="selectColor('pref_H2COLOR')" VALUE="<?php etranslate("Select")?>..."></TD></TR>
<TR><TD><B><?php etranslate("Table cell background")?>:</B></TD>
  <TD><INPUT NAME="pref_CELLBG" SIZE="8" MAXLENGTH="7" VALUE="<?php echo $prefarray["CELLBG"]; ?>"> <INPUT TYPE="button" ONCLICK="selectColor('pref_CELLBG')" VALUE="<?php etranslate("Select")?>..."></TD></TR>
<TR><TD><B><?php etranslate("Table cell background for current day")?>:</B></TD>
  <TD><INPUT NAME="pref_TODAYCELLBG" SIZE="8" MAXLENGTH="7" VALUE="<?php echo $prefarray["TODAYCELLBG"]; ?>"> <INPUT TYPE="button" ONCLICK="selectColor('pref_TODAYCELLBG')" VALUE="<?php etranslate("Select")?>..."></TD></TR>
<TR><TD><B><?php etranslate("Table cell background for weekends")?>:</B></TD>
  <TD><INPUT NAME="pref_WEEKENDBG" SIZE="8" MAXLENGTH="7" VALUE="<?php echo $prefarray["WEEKENDBG"]; ?>"> <INPUT TYPE="button" ONCLICK="selectColor('pref_WEEKENDBG')" VALUE="<?php etranslate("Select")?>..."></TD></TR>

</TABLE></TD></TR></TABLE></TD></TR></TABLE>

</TD><TD VALIGN="top" ALIGN="middle" BGCOLOR="<?php echo $prefarray["BGCOLOR"]?>">
<BR>

<!-- BEGIN EXAMPLE MONTH -->
<TABLE BORDER="0" WIDTH="100%"><TR>
<TD ALIGN="middle"><FONT SIZE="+0" COLOR="<?php echo $H2COLOR?>"><B><?php echo translate("December") . " 2000";?></FONT></TD></TR>
</TABLE>

<TABLE BORDER="0" WIDTH="90%" CELLSPACING="0" CELLPADDING="0">
<TR><TD BGCOLOR="<?php echo $TABLEBG?>">
<TABLE BORDER="0" WIDTH="100%" CELLSPACING="1" CELLPADDING="2">

<TR>
<?php if ( $prefarray["WEEK_START"] == 0 ) { ?>
<TH WIDTH="14%" CLASS="tableheader" BGCOLOR="<?php echo $prefarray["THBG"]?>"><FONT COLOR="<?php echo $prefarray["THFG"]?>"><?php etranslate("Sun")?></FONT></TH>
<?php } ?>
<TH WIDTH="14%" CLASS="tableheader" BGCOLOR="<?php echo $prefarray["THBG"]?>"><FONT COLOR="<?php echo $prefarray["THFG"]?>"><?php etranslate("Mon")?></FONT></TH>
<TH WIDTH="14%" CLASS="tableheader" BGCOLOR="<?php echo $prefarray["THBG"]?>"><FONT COLOR="<?php echo $prefarray["THFG"]?>"><?php etranslate("Tue")?></FONT></TH>
<TH WIDTH="14%" CLASS="tableheader" BGCOLOR="<?php echo $prefarray["THBG"]?>"><FONT COLOR="<?php echo $prefarray["THFG"]?>"><?php etranslate("Wed")?></FONT></TH>
<TH WIDTH="14%" CLASS="tableheader" BGCOLOR="<?php echo $prefarray["THBG"]?>"><FONT COLOR="<?php echo $prefarray["THFG"]?>"><?php etranslate("Thu")?></FONT></TH>
<TH WIDTH="14%" CLASS="tableheader" BGCOLOR="<?php echo $prefarray["THBG"]?>"><FONT COLOR="<?php echo $prefarray["THFG"]?>"><?php etranslate("Fri")?></FONT></TH>
<TH WIDTH="14%" CLASS="tableheader" BGCOLOR="<?php echo $prefarray["THBG"]?>"><FONT COLOR="<?php echo $prefarray["THFG"]?>"><?php etranslate("Sat")?></FONT></TH>
<?php if ( $prefarray["WEEK_START"] == 1 ) { ?>
<TH WIDTH="14%" CLASS="tableheader" BGCOLOR="<?php echo $prefarray["THBG"]?>"><FONT COLOR="<?php echo $prefarray["THFG"]?>"><?php etranslate("Sun")?></FONT></TH>
<?php } ?>
</TR>
<?php

$today = mktime ( 3, 0, 0, 12, 13, 2000 );
if ( $prefarray["WEEK_START"] == 1 )
  $wkstart = get_monday_before ( 2000, 12, 1 );
else
  $wkstart = get_sunday_before ( 2000, 12, 1 );
// generate values for first day and last day of month
$monthstart = mktime ( 3, 0, 0, 12, 1, 2000 );
$monthend = mktime ( 3, 0, 0, 13, 0, 2000 );

for ( $i = $wkstart; date ( "Ymd", $i ) <= date ( "Ymd", $monthend );
  $i += ( 24 * 3600 * 7 ) ) {
  print "<TR>\n";
  for ( $j = 0; $j < 7; $j++ ) {
    $date = $i + ( $j * 24 * 3600 );
    if ( date ( "Ymd", $date ) >= date ( "Ymd", $monthstart ) &&
      date ( "Ymd", $date ) <= date ( "Ymd", $monthend ) ) {
      $thiswday = date ( "w", $date );
      $is_weekend = ( $thiswday == 0 || $thiswday == 6 );
      if ( empty ( $prefarray["WEEKENDBG"] ) ) $is_weekend = false;
      $class = $is_weekend ? "tablecellweekenddemo" : "tablecelldemo";
      $color = $is_weekend ? $prefarray["WEEKENDBG"] : $prefarray["CELLBG"];
      if ( empty ( $color ) )
        $color = "#C0C0C0";
      print "<TD VALIGN=\"top\" HEIGHT=\"30\" ID=\"$class\" ";
      if ( date ( "Ymd", $date ) == date ( "Ymd", $today ) )
        echo "BGCOLOR=\"$prefarray[TODAYCELLBG]\">";
      else
        echo "BGCOLOR=\"$color\">";
      echo "&nbsp;";
      print "</TD>\n";
    } else {
      print "<TD VALIGN=\"top\" HEIGHT=\"30\" ID=\"tablecelldemo\" BGCOLOR=\"$prefarray[CELLBG]\">&nbsp;</TD>\n";
    }
  }
  print "</TR>\n";
}

?>


</TABLE></TD></TR></TABLE>

<!-- END EXAMPLE MONTH -->
<BR><BR>

</TD></TR></TABLE>

</TD></TR></TABLE>

<?php } // if $allow_color_customization ?>

<BR><BR>
<TABLE BORDER=0><TR><TD>
<INPUT TYPE="submit" VALUE="<?php etranslate("Save Preferences")?>">
<SCRIPT LANGUAGE="JavaScript">
  document.writeln ( '<INPUT TYPE="button" VALUE="<?php etranslate("Help")?>..." ONCLICK="window.open ( \'help_pref.php\', \'cal_help\', \'dependent,menubar,scrollbars,height=400,width=400,innerHeight=420,outerWidth=420\');">' );
</SCRIPT>
</TD></TR></TABLE>


</FORM>

<?php include "includes/trailer.php"; ?>
</BODY>
</HTML>
