<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2019 OpenLink Software
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
include "includes/site_extras.php";
include "includes/validate.php";
include "includes/connect.php";

load_global_settings ();
load_user_preferences ();
load_user_layers ();
load_user_categories ();

include "includes/translate.php";

// make sure this is not a read-only calendar
$can_edit = false;

// Public access can only add events, not edit.
if ( $login == "__public__" && $id > 0 ) {
  $id = 0;
}

$external_users = "";
$participants = array ();

if ( ! empty ( $id ) && $id > 0 ) {
  // first see who has access to edit this entry
  if ( $is_admin || $is_assistant ) {
    $can_edit = true;
  } else {
    $can_edit = false;
    if ( $readonly == "N" || $is_admin ) {
      $sql = "SELECT webcal_entry.cal_id FROM webcal_entry, " .
        "webcal_entry_user WHERE webcal_entry.cal_id = " .
        "webcal_entry_user.cal_id AND webcal_entry.cal_id = $id " .
        "AND (webcal_entry.cal_create_by = '$login' " .
        "OR webcal_entry_user.cal_login = '$login')";
      $res = dbi_query ( $sql );
      if ( $res ) {
        $row = dbi_fetch_row ( $res );
        if ( $row && $row[0] > 0 )
          $can_edit = true;
        dbi_free_result ( $res );
      }
    }
  }
  $sql = "SELECT cal_create_by, cal_date, cal_time, cal_mod_date, " .
    "cal_mod_time, cal_duration, cal_priority, cal_type, cal_access, " .
    "cal_name, cal_description FROM webcal_entry WHERE cal_id = " . $id;
  $res = dbi_query ( $sql );
  if ( $res ) {
    $row = dbi_fetch_row ( $res );
    if ( ! empty ( $override ) ) {
      // Leave $cal_date to what was set in URL with date=YYYYMMDD
    } else {
      $cal_date = $row[1];
    }
    $create_by = $row[0];
    $year = (int) ( $cal_date / 10000 );
    $month = ( $cal_date / 100 ) % 100;
    $day = $cal_date % 100;
    $time = $row[2];
    if ( $time >= 0 ) { /* -1 = no time specified */
      $time += $TZ_OFFSET * 10000;
      if ( $time > 240000 ) {
        $time -= 240000;
        $gmt = mktime ( 3, 0, 0, $month, $day, $year );
        $gmt -= $ONE_DAY;
        $month = date ( "m", $gmt );
        $day = date ( "d", $gmt );
        $year = date ( "Y", $gmt );
      } else if ( $time < 0 ) {
        $time += 240000;
        $gmt = mktime ( 3, 0, 0, $month, $day, $year );
        $gmt -= $ONE_DAY;
        $month = date ( "m", $gmt );
        $day = date ( "d", $gmt );
        $year = date ( "Y", $gmt );
      }
    }
    if ( $time >= 0 ) {
      $hour = floor($time / 10000);
      $minute = ( $time / 100 ) % 100;
      $duration = $row[5];
    } else {
      $duration = "";
    }
    $priority = $row[6];
    $type = $row[7];
    $access = $row[8];
    $name = $row[9];
    $description = $row[10];
    // check for repeating event info...
    // but not if we are overriding a single entry of an already repeating
    // event... confusing, eh?
    if ( ! empty ( $override ) ) {
      $rpt_type = "none";
      $rpt_end = 0;
      $rpt_end_date = $cal_date;
      $rpt_freq = 1;
      $rpt_days = "nnnnnnn";
      $rpt_sun = $rpt_mon = $rpt_tue = $rpt_wed =
        $rpt_thu = $rpt_fri = $rpt_sat = false;
    } else {
      $res = dbi_query ( "SELECT cal_id, cal_type, cal_end, " .
        "cal_frequency, cal_days FROM webcal_entry_repeats " .
        "WHERE cal_id = $id" );
      if ( $res ) {
        if ( $row = dbi_fetch_row ( $res ) ) {
          $rpt_type = $row[1];
          if ( $row[2] > 0 )
            $rpt_end = date_to_epoch ( $row[2] );
          else
            $rpt_end = 0;
          $rpt_end_date = $row[2];
          $rpt_freq = $row[3];
          $rpt_days = $row[4];
          $rpt_sun  = ( substr ( $rpt_days, 0, 1 ) == 'y' );
          $rpt_mon  = ( substr ( $rpt_days, 1, 1 ) == 'y' );
          $rpt_tue  = ( substr ( $rpt_days, 2, 1 ) == 'y' );
          $rpt_wed  = ( substr ( $rpt_days, 3, 1 ) == 'y' );
          $rpt_thu  = ( substr ( $rpt_days, 4, 1 ) == 'y' );
          $rpt_fri  = ( substr ( $rpt_days, 5, 1 ) == 'y' );
          $rpt_sat  = ( substr ( $rpt_days, 6, 1 ) == 'y' );
        }
      }
    }
    
  }
  $sql = "SELECT cal_login, cal_category FROM webcal_entry_user WHERE cal_id = $id";
  $res = dbi_query ( $sql );
  if ( $res ) {
    while ( $row = dbi_fetch_row ( $res ) ) {
      if ( ! $is_secretary || $login != $row[0] ) $participants[$row[0]] = 1;
      if ($login == $row[0]) $cat_id = $row[1];
    }
  }
  if ( ! empty ( $allow_external_users ) && $allow_external_users == "Y" ) {
    $external_users = event_get_external_users ( $id );
  }
} else {
  $id = 0; // to avoid warnings below about use of undefined var
  if ( empty ( $hour ) )
    $time = -1;
  else
    $time = $hour * 100;
  if ( $readonly == "N" || $is_admin )
    $can_edit = true;
  if ( ! empty ( $defusers ) ) {
    $tmp_ar = explode ( ",", $defusers );
    for ( $i = 0; $i < count ( $tmp_ar ); $i++ ) {
      $participants[$tmp_ar[$i]] = 1;
    }
  }
}
if ( ! empty ( $year ) && $year )
  $thisyear = $year;
if ( ! empty ( $month ) && $month )
  $thismonth = $month;
if ( ! empty ( $day ) && $day )
  $thisday = $day;
if ( empty ( $rpt_type ) || ! $rpt_type )
  $rpt_type = "none";

// avoid error for using undefined vars
if ( empty ( $hour ) )
  $hour = -1;
if ( empty ( $duration ) )
  $duration = 0;
if ( $duration == ( 24 * 60 ) ) {
  $hour = $minute = $duration = "";
  $allday = "Y";
} else
  $allday = "N";
if ( empty ( $name ) )
  $name = "";
if ( empty ( $description ) )
  $description = "";
if ( empty ( $priority ) )
  $priority = 0;
if ( empty ( $access ) )
  $access = "";
if ( empty ( $rpt_freq ) )
  $rpt_freq = 0;
if ( empty ( $rpt_end_date ) )
  $rpt_end_date = 0;


if ( ( empty ( $year ) || ! $year ) &&
  ( empty ( $month ) || ! $month ) &&
  ( ! empty ( $date ) && strlen ( $date ) ) ) {
  $thisyear = $year = substr ( $date, 0, 4 );
  $thismonth = $month = substr ( $date, 4, 2 );
  $thisday = $day = substr ( $date, 6, 2 );
  $cal_date = $date;
} else {
  if ( empty ( $cal_date ) )
    $cal_date = date ( "Ymd" );
}
$thisdate = sprintf ( "%04d%02d%02d", $thisyear, $thismonth, $thisday );
if ( empty ( $cal_date ) || ! $cal_date )
  $cal_date = $thisdate;

?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<?php include "includes/js.php"; ?>
<SCRIPT LANGUAGE="JavaScript">
var oldhour = 0, oldminute = 0, olddh = 0, olddm = 0;

// do a little form verifying
function validate_and_submit () {
  if ( document.forms[0].name.value == "" ) {
    document.forms[0].name.select ();
    document.forms[0].name.focus ();
    alert ( "<?php etranslate("You have not entered a Brief Description")?>." );
    return false;
  }
  // Leading zeros seem to confuse parseInt()
  if ( document.forms[0].hour.value.charAt ( 0 ) == '0' )
    document.forms[0].hour.value = document.forms[0].hour.value.substring ( 1, 2 );
  h = parseInt ( document.forms[0].hour.value );
  m = parseInt ( document.forms[0].minute.value );
<?php if ($GLOBALS["TIME_FORMAT"] == "12") { ?>
  if ( document.forms[0].ampm[1].checked ) {
    // pm
    if ( h < 12 )
      h += 12;
  } else {
    // am
    if ( h == 12 )
      h = 0;
  }
<?php } ?>
  if ( h >= 24 || m > 59 ) {
    alert ( "<?php etranslate ("You have not entered a valid time of day")?>." );
    document.forms[0].hour.select ();
    document.forms[0].hour.focus ();
    return false;
  }
  // Ask for confirmation for time of day if it is before the user's
  // preference for work hours.
  <?php if ($GLOBALS["TIME_FORMAT"] == "24") {
          echo "if ( h < $WORK_DAY_START_HOUR  ) {";
        }  else {
          echo "if ( h < $WORK_DAY_START_HOUR && document.forms[0].ampm[0].checked ) {";
        }
  ?>
    if ( ! confirm ( "<?php etranslate ("The time you have entered begins before your preferred work hours.  Is this correct?")?> "))
      return false;
  }
  // is there really a change?
  changed = false;
  form=document.forms[0];
  for ( i = 0; i < form.elements.length; i++ ) {
    field = form.elements[i];
    switch ( field.type ) {
      case "radio":
      case "checkbox":
        if ( field.checked != field.defaultChecked )
          changed = true;
        break;
      case "text":
//      case "textarea":
        if ( field.value != field.defaultValue )
          changed = true;
        break;
      case "select-one":
//      case "select-multiple":
        for( j = 0; j < field.length; j++ ) {
          if ( field.options[j].selected != field.options[j].defaultSelected )
            changed = true;
        }
        break;
    }
  }
  if ( changed ) {
    form.entry_changed.value = "yes";
  }

  // would be nice to also check date to not allow Feb 31, etc...
  document.forms[0].submit ();
  return true;
}


function selectDate ( day, month, year, current ) {
  url = "datesel.php?form=editentryform&day=" + day +
    "&month=" + month + "&year=" + year;
  if ( current > 0 )
    url += '&date=' + current;
  window.open( url, "DateSelection",
    "width=300,height=200,resizable=yes,scrollbars=yes" );
}


<?php if ( $groups_enabled == "Y" ) { ?>
function selectUsers () {
  // find id of user selection object
  var listid = 0;
  for ( i = 0; i < document.forms[0].elements.length; i++ ) {
    if ( document.forms[0].elements[i].name == "participants[]" )
      listid = i;
  }
  url = "usersel.php?form=editentryform&listid=" + listid + "&users=";
  // add currently selected users
  for ( i = 0, j = 0; i < document.forms[0].elements[listid].length; i++ ) {
    if ( document.forms[0].elements[listid].options[i].selected ) {
      if ( j != 0 )
	url += ",";
      j++;
      url += document.forms[0].elements[listid].options[i].value;
    }
  }
  //alert ( "URL: " + url );
  // open window
  window.open ( url, "UserSelection",
    "width=500,height=500,resizable=yes,scrollbars=yes" );
}
<?php } ?>


// This function is called wheneve someone clicks on the "All day event"
// checkbox.  When the enabled all day, it clears all the time of day
// and duration fields.  If they change their mind and turn it off, we
// put the original values back for them.
// This isn't necessary, but it helps show what the meaning of "all-day" is.
function timetype_handler () {
  var i = document.forms[0].timetype.selectedIndex;
  var val = document.forms[0].timetype.options[i].text;
  //alert ( "val " + i + "  = " + val );
  // i == 1 when set to timed event
  if ( i != 1 ) {
    //alert("clear");
    // switching to allday event... save values
    if ( document.forms[0].hour.value != "" ) {
      oldhour = document.forms[0].hour.value;
      oldminute = document.forms[0].minute.value;
      olddh = document.forms[0].duration_h.value;
      olddm = document.forms[0].duration_m.value;
    }
    document.forms[0].hour.value = "";
    document.forms[0].minute.value = "";
    document.forms[0].duration_h.value = "";
    document.forms[0].duration_m.value = "";
    //hide ( "timeentry" );
  } else {
    //alert("set");
    document.forms[0].hour.value = oldhour;
    document.forms[0].minute.value = oldminute;
    document.forms[0].duration_h.value = olddh;
    document.forms[0].duration_m.value = olddm;
    //unhide ( "timeentry" );
  }
}

</SCRIPT>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR; ?>" CLASS="defaulttext" xonload="timetype_handler()">

<H2><FONT COLOR="<?php echo $H2COLOR;?>"><?php if ( $id ) echo translate("Edit Entry"); else echo translate("Add Entry"); ?></FONT></H2>

<?php
if ( $can_edit ) {
?>
<FORM ACTION="edit_entry_handler.php" METHOD="POST" NAME="editentryform">

<?php
if ( ! empty ( $id ) ) echo "<INPUT TYPE=\"hidden\" NAME=\"id\" VALUE=\"$id\">\n";
// we need an additional hidden input field
echo "<INPUT TYPE=\"hidden\" NAME=\"entry_changed\" VALUE=\"\">\n";

// are we overriding an entry from a repeating event...
if ( $override ) {
  echo "<INPUT TYPE=\"hidden\" NAME=\"override\" VALUE=\"1\">\n";
  echo "<INPUT TYPE=\"hidden\" NAME=\"override_date\" VALUE=\"$cal_date\">\n";
}
// if assistant, need to remember boss = user
if ( $is_assistant )
   echo "<INPUT TYPE=\"hidden\" NAME=\"user\" VALUE=\"$user\">\n";

?>

<TABLE BORDER=0>

<TR><TD><B CLASS="tooltip" TITLE="<?php etooltip("brief-description-help")?>"><?php etranslate("Brief Description")?>:</B></TD>
  <TD><INPUT NAME="name" SIZE=25 VALUE="<?php echo htmlspecialchars ( $name ); ?>"></TD></TR>

<TR><TD VALIGN="top"><B CLASS="tooltip" TITLE="<?php etooltip("full-description-help")?>"><?php etranslate("Full Description")?>:</B></TD>
  <TD><TEXTAREA NAME="description" ROWS=5 COLS=40 WRAP="virtual"><?php echo htmlspecialchars ( $description ); ?></TEXTAREA></TD></TR>

<TR><TD><B CLASS="tooltip" TITLE="<?php etooltip("date-help")?>"><?php etranslate("Date")?>:</B></TD>
  <TD>
  <?php
  print_date_selection ( "", $cal_date )
  ?>
</TD></TR>

<TR><TD><B CLASS="tooltip" TITLE="<?php etooltip("time-help")?>"><?php etranslate("Time")?>:</B></TD>
<?php

$h12 = $hour;
$amsel = "CHECKED"; $pmsel = "";
if ( $TIME_FORMAT == "12" ) {
  if ( $h12 < 12 ) {
    $amsel = "CHECKED"; $pmsel = "";
  } else {
    $amsel = ""; $pmsel = "CHECKED";
  }
  $h12 %= 12;
  if ( $h12 == 0 ) $h12 = 12;
}
if ( $time < 0 )
  $h12 = "";
?>
  <TD>
<SPAN ID="timeentry">
<INPUT NAME="hour" SIZE=2 VALUE="<?php if ( $allday != "Y" ) echo $h12;?>" MAXLENGTH=2>:<INPUT NAME="minute" SIZE=2 VALUE="<?php if ( $time >= 0 && $allday != "Y" ) printf ( "%02d", $minute );?>" MAXLENGTH=2>
<?php
if ( $TIME_FORMAT == "12" ) {
  echo "<INPUT TYPE=radio NAME=ampm VALUE=\"am\" $amsel>" .
    translate("am") . "\n";
  echo "<INPUT TYPE=radio NAME=ampm VALUE=\"pm\" $pmsel>" .
    translate("pm") . "\n";
}
?>
</SPAN>
&nbsp;&nbsp;&nbsp;&nbsp;
<SELECT NAME="timetype" ONCHANGE="timetype_handler()">
<OPTION VALUE="U" <?php if ( $allday != "Y" && $hour == -1 ) echo SELECTED?>>
  <?php etranslate("Untimed event"); ?>
<OPTION VALUE="T" <?php if ( $allday != "Y" && $hour >= 0 ) echo SELECTED?>>
  <?php etranslate("Timed event"); ?>
<OPTION VALUE="A" <?php if ( $allday == "Y" ) echo SELECTED?>>
  <?php etranslate("All day event"); ?>
</SELECT>
</TD></TR>

<?php
  $dur_h = (int)( $duration / 60 );
  $dur_m = $duration - ( $dur_h * 60 );
?>
<TR><TD><B CLASS="tooltip" TITLE="<?php etooltip("duration-help")?>"><?php etranslate("Duration")?>:</B></TD>
  <TD><INPUT NAME="duration_h" SIZE="2" MAXLENGTH="2" VALUE="<?php if ( $allday != "Y" ) printf ( "%d", $dur_h );?>">:<INPUT NAME="duration_m" SIZE="2" MAXLENGTH="2" VALUE="<?php if ( $allday != "Y" ) printf ( "%02d", $dur_m );?>"> (<?php echo translate("hours") . ":" . translate("minutes")?>)</TD></TR>

<?php if ( $disable_priority_field != "Y" ) { ?>
<TR><TD><B CLASS="tooltip" TITLE="<?php etooltip("priority-help")?>"><?php etranslate("Priority")?>:</B></TD>
  <TD><SELECT NAME="priority">
    <OPTION VALUE="1"<?php if ( $priority == 1 ) echo " SELECTED";?>><?php etranslate("Low")?>
    <OPTION VALUE="2"<?php if ( $priority == 2 || $priority == 0 ) echo " SELECTED";?>><?php etranslate("Medium")?>
    <OPTION VALUE="3"<?php if ( $priority == 3 ) echo " SELECTED";?>><?php etranslate("High")?>
  </SELECT></TD></TR>
<?php } ?>

<?php if ( $disable_access_field != "Y" ) { ?>
<TR><TD><B CLASS="tooltip" TITLE="<?php etooltip("access-help")?>"><?php etranslate("Access")?>:</B></TD>
  <TD><SELECT NAME="access">
    <OPTION VALUE="P"<?php if ( $access == "P" || ! strlen ( $access ) ) echo " SELECTED";?>><?php etranslate("Public")?>
    <OPTION VALUE="R"<?php if ( $access == "R" ) echo " SELECTED";?>><?php etranslate("Confidential")?>
  </SELECT></TD></TR>
<?php } ?>

<?php if ( ! empty ( $categories ) ) { ?>
<TR><TD><B CLASS="tooltip" TITLE="<?php etooltip("category-help")?>"><?php etranslate("Category")?>:</B></TD>
  <TD><SELECT NAME="cat_id">
  <OPTION VALUE=""> None
<?php
  foreach( $categories as $K => $V ){
    echo "<OPTION VALUE=\"$K\"";
    if ( $cat_id == $K ) echo " SELECTED";
    echo ">$V";
  }
?>
  </SELECT></TD></TR>
<?php } ?>

<?php
// site-specific extra fields (see site_extras.php)
// load any site-specific fields and display them
if ( $id > 0 )
  $extras = get_site_extra_fields ( $id );
for ( $i = 0; $i < count ( $site_extras ); $i++ ) {
  $extra_name = $site_extras[$i][0];
  $extra_descr = $site_extras[$i][1];
  $extra_type = $site_extras[$i][2];
  $extra_arg1 = $site_extras[$i][3];
  $extra_arg2 = $site_extras[$i][4];
  //echo "<TR><TD>Extra " . $extra_name . " - " . $site_extras[$i][2] . 
  //  " - " . $extras[$extra_name]['cal_name'] .
  //  "arg1: $extra_arg1, arg2: $extra_arg2 </TD></TR>\n";
  if ( $extra_type == $EXTRA_MULTILINETEXT )
    echo "<TR><TD VALIGN=\"top\"><BR>";
  else
    echo "<TR><TD>";
  echo "<B>" .  translate ( $extra_descr ) .  ":</B></TD><TD>";
  if ( $extra_type == $EXTRA_URL ) {
    echo '<INPUT SIZE="50" NAME="' . $extra_name .
      '" VALUE="' .
      ( empty ( $extras[$extra_name]['cal_data'] ) ?
      "" : htmlspecialchars ( $extras[$extra_name]['cal_data'] ) ) .
      '">';
  } else if ( $extra_type == $EXTRA_EMAIL ) {
    echo '<INPUT SIZE="30" NAME="' . $extra_name .
      '" VALUE="' .
      ( empty ( $extras[$extra_name]['cal_data'] ) ?
      "" : htmlspecialchars ( $extras[$extra_name]['cal_data'] ) ) .
      '">';
  } else if ( $extra_type == $EXTRA_DATE ) {
    if ( ! empty ( $extras[$extra_name]['cal_date'] ) )
      print_date_selection ( $extra_name, $extras[$extra_name]['cal_date'] );
    else
      print_date_selection ( $extra_name, $cal_date );
  } else if ( $extra_type == $EXTRA_TEXT ) {
    $size = ( $extra_arg1 > 0 ? $extra_arg1 : 50 );
    echo '<INPUT SIZE="' . $size . '" NAME="' . $extra_name .
      '" VALUE="' .
      ( empty ( $extras[$extra_name]['cal_data'] ) ?
      "" : htmlspecialchars ( $extras[$extra_name]['cal_data'] ) ) .
      '">';
  } else if ( $extra_type == $EXTRA_MULTILINETEXT ) {
    $cols = ( $extra_arg1 > 0 ? $extra_arg1 : 50 );
    $rows = ( $extra_arg2 > 0 ? $extra_arg2 : 5 );
    echo '<TEXTAREA ROWS="' . $rows . '" COLS="' . $cols .
      '" NAME="' . $extra_name .  '">' .
      ( empty ( $extras[$extra_name]['cal_data'] ) ?
      "" : htmlspecialchars ( $extras[$extra_name]['cal_data'] ) ) .
      '</TEXTAREA>';
  } else if ( $extra_type == $EXTRA_USER ) {
    // show list of calendar users...
    echo "<SELECT NAME=\"" . $extra_name . "\">";
    echo "<OPTION VALUE=\"\"> None";
    $userlist = get_my_users ();
    for ( $i = 0; $i < count ( $userlist ); $i++ ) {
      echo "<OPTION VALUE=\"" . $userlist[$i]['cal_login'] . "\"";
        if ( ! empty ( $extras[$extra_name]['cal_data'] ) &&
          $userlist[$i]['cal_login'] == $extras[$extra_name]['cal_data'] )
          echo " SELECTED";
        echo "> " . $userlist[$i]['cal_fullname'];
    }
    echo "</SELECT>";
  } else if ( $extra_type == $EXTRA_REMINDER ) {
    $rem_status = 0; // don't send
    echo "<INPUT TYPE=\"radio\" NAME=\"" . $extra_name . "\" VALUE=\"1\"";
    if ( empty ( $id ) ) {
      // adding event... check default
      if ( ( $extra_arg2 & $EXTRA_REMINDER_DEFAULT_YES ) > 0 )
        $rem_status = 1;
    } else {
      // editing event... check status
      if ( ! empty ( $extras[$extra_name]['cal_remind'] ) )
        $rem_status = 1;
    }
    if ( $rem_status )
      echo " CHECKED";
    echo "> ";
    etranslate ( "Yes" );
    echo "&nbsp;<INPUT TYPE=\"radio\" NAME=\"" . $extra_name . "\" VALUE=\"0\"";
    if ( ! $rem_status )
      echo " CHECKED";
    echo "> ";
    etranslate ( "No" );
    echo "&nbsp;&nbsp;";
    if ( ( $extra_arg2 & $EXTRA_REMINDER_WITH_DATE ) > 0 ) {
      if ( ! empty ( $extras[$extra_name]['cal_date'] ) &&
        $extras[$extra_name]['cal_date'] > 0 )
        print_date_selection ( $extra_name, $extras[$extra_name]['cal_date'] );
      else
        print_date_selection ( $extra_name, $cal_date );
    } else if ( ( $extra_arg2 & $EXTRA_REMINDER_WITH_OFFSET ) > 0 ) {
      if ( isset ( $extras[$extra_name]['cal_data'] ) )
        $minutes = $extras[$extra_name]['cal_data'];
      else
        $minutes = $extra_arg1;
      // will be specified in total minutes
      $d = (int) ( $minutes / ( 24 * 60 ) );
      $minutes -= ( $d * 24 * 60 );
      $h = (int) ( $minutes / 60 );
      $minutes -= ( $h * 60 );
      echo "<INPUT SIZE=\"2\" NAME=\"" . $extra_name .
        "_days\" VALUE=\"$d\"> " .  translate("days") . "&nbsp;&nbsp;";
      echo "<INPUT SIZE=\"2\" NAME=\"" . $extra_name .
        "_hours\" VALUE=\"$h\"> " .  translate("hours") . "&nbsp;&nbsp;";
      echo "<INPUT SIZE=\"2\" NAME=\"" . $extra_name .
        "_minutes\" VALUE=\"$minutes\"> " .  translate("minutes") .
        "&nbsp;&nbsp;";
      etranslate("before event");
    }
  } else if ( $extra_type == $EXTRA_SELECTLIST ) {
    // show custom select list.
    echo "<SELECT NAME=\"" . $extra_name . "\">";
    if ( is_array ( $extra_arg1 ) ) {
      for ( $i = 0; $i < count ( $extra_arg1 ); $i++ ) {
        echo "<OPTION";
        if ( ! empty ( $extras[$extra_name]['cal_data'] ) &&
          $extra_arg1[$i] == $extras[$extra_name]['cal_data'] )
          echo " SELECTED";
        echo ">" . $extra_arg1[$i] . "</OPTION>\n";
      }
    }
    echo "</SELECT>";
  }
  echo "</TD></TR>\n";
}
// end site-specific extra fields
?>

<?php
// Only ask for participants if we are multi-user.
$show_participants = ( $disable_participants_field != "Y" );
if ( $is_admin )
  $show_participants = true;
if ( $login == "__public__" && $public_access_others != "Y" )
  $show_participants = false;

if ( $single_user == "N" && $show_participants ) {
  $userlist = get_my_users ();
  $num_users = 0;
  $size = 0;
  $users = "";
  for ( $i = 0; $i < count ( $userlist ); $i++ ) {
    $l = $userlist[$i]['cal_login'];
    $size++;
    $users .= "<OPTION VALUE=\"" . $l . "\"";
    if ( $id > 0 ) {
      if ( ! empty ( $participants[$l] ) )
        $users .= " SELECTED";
    } else {
      if ( ! empty ( $defusers ) ) {
        // default selection of participants was in the URL
        if ( ! empty ( $participants[$l] ) )
          $users .= " SELECTED";
      } else {
        if ( ( $l == $login && ! $is_assistant ) || ( ! empty ( $user ) && $l == $user ) )
          $users .= " SELECTED";
      }
    }
    $users .= "> " . $userlist[$i]['cal_fullname'];
  }

  if ( $size > 50 )
    $size = 15;
  else if ( $size > 5 )
    $size = 5;
  print "<TR><TD VALIGN=\"top\"><B CLASS=\"tooltip\" TITLE=\"" .
    tooltip("participants-help") . "\">" .
    translate("Participants") . ":</B></TD>";
  print "<TD><SELECT NAME=\"participants[]\" SIZE=$size MULTIPLE>$users\n";
  print "</SELECT>";
  if ( $groups_enabled == "Y" ) {
    echo "<INPUT TYPE=\"button\" ONCLICK=\"selectUsers()\" VALUE=\"" .
      translate("Select") . "...\">";
  }
  print "</TD></TR>\n";

  // external users
  if ( ! empty ( $allow_external_users ) && $allow_external_users == "Y" ) {
    print "<TR><TD VALIGN=\"top\"><B CLASS=\"tooltip\" TITLE=\"" .
      tooltip("external-participants-help") . "\">" .
      translate("External Participants") . ":</B></TD>";
    print "<TD><TEXTAREA NAME=\"externalparticipants\" ROWS=\"5\" COLS=\"40\">";
    print $external_users . "</TEXTAREA></TD></TR>\n";
    print "</TD></TR>\n";
  }
}
?>

<?php if ( $disable_repeating_field != "Y" ) { ?>
<TR><TD VALIGN="top"><B CLASS="tooltip" TITLE="<?php etooltip("repeat-type-help")?>"><?php etranslate("Repeat Type")?>:</B></TD>
<TD VALIGN="top"><?php
echo "<INPUT TYPE=\"radio\" NAME=\"rpt_type\" VALUE=\"none\" " .
  ( strcmp ( $rpt_type, 'none' ) == 0 ? "CHECKED" : "" ) . "> " .
  translate("None");
echo "<INPUT TYPE=\"radio\" NAME=\"rpt_type\" VALUE=\"daily\" " .
  ( strcmp ( $rpt_type, 'daily' ) == 0 ? "CHECKED" : "" ) . "> " .
  translate("Daily");
echo "<INPUT TYPE=\"radio\" NAME=\"rpt_type\" VALUE=\"weekly\" " .
  ( strcmp ( $rpt_type, 'weekly' ) == 0 ? "CHECKED" : "" ) . "> " .
  translate("Weekly");
echo "<INPUT TYPE=\"radio\" NAME=\"rpt_type\" VALUE=\"monthlyByDay\" " .
  ( strcmp ( $rpt_type, 'monthlyByDay' ) == 0 ? "CHECKED" : "" ) . "> " .
  translate("Monthly") . " (" . translate("by day") . ")";
echo "<INPUT TYPE=\"radio\" NAME=\"rpt_type\" VALUE=\"monthlyByDate\" " .
  ( strcmp ( $rpt_type, 'monthlyByDate' ) == 0 ? "CHECKED" : "" ) . "> " .
  translate("Monthly") . " (" . translate("by date") . ")";
echo "<INPUT TYPE=\"radio\" NAME=\"rpt_type\" VALUE=\"yearly\" " .
  ( strcmp ( $rpt_type, 'yearly' ) == 0 ? "CHECKED" : "" ) . "> " .
  translate("Yearly");
?>
</TD></TR>
<TR><TD><B CLASS="tooltip" TITLE="<?php etooltip("repeat-end-date-help")?>"><?php etranslate("Repeat End Date")?>:</B></TD>
<TD><INPUT TYPE="checkbox" NAME="rpt_end_use" VALUE="y" <?php
  echo ( ! empty ( $rpt_end ) ? "CHECKED" : "" ); ?>> <?php etranslate("Use end date")?>
&nbsp;&nbsp;&nbsp;
<SPAN CLASS="end_day_selection">
  <?php
    print_date_selection ( "rpt_", $rpt_end_date ? $rpt_end_date : $cal_date )
  ?>
</TD></TR>
<TR><TD><B CLASS="tooltip" TITLE="<?php etooltip("repeat-day-help")?>"><?php etranslate("Repeat Day")?>: </b>(<?php etranslate("for weekly")?>)</td>
  <td><?php
  echo "<INPUT TYPE=\"checkbox\" NAME=\"rpt_sun\" VALUE=\"y\" "
     . (!empty($rpt_sun)?"CHECKED":"") . "> " . translate("Sunday");
  echo "<INPUT TYPE=\"checkbox\" NAME=\"rpt_mon\" VALUE=\"y\" "
     . (!empty($rpt_mon)?"CHECKED":"") . "> " . translate("Monday");
  echo "<INPUT TYPE=\"checkbox\" NAME=\"rpt_tue\" VALUE=y "
     . (!empty($rpt_tue)?"CHECKED":"") . "> " . translate("Tuesday");
  echo "<INPUT TYPE=\"checkbox\" NAME=\"rpt_wed\" VALUE=\"y\" "
     . (!empty($rpt_wed)?"CHECKED":"") . "> " . translate("Wednesday");
  echo "<INPUT TYPE=\"checkbox\" NAME=\"rpt_thu\" VALUE=\"y\" "
     . (!empty($rpt_thu)?"CHECKED":"") . "> " . translate("Thursday");
  echo "<INPUT TYPE=\"checkbox\" NAME=\"rpt_fri\" VALUE=\"y\" "
     . (!empty($rpt_fri)?"CHECKED":"") . "> " . translate("Friday");
  echo "<INPUT TYPE=\"checkbox\" NAME=\"rpt_sat\" VALUE=\"y\" "
     . (!empty($rpt_sat)?"CHECKED":"") . "> " . translate("Saturday");
  ?></TD></TR>

<TR><TD><B CLASS="tooltip" TITLE="<?php etooltip("repeat-frequency-help")?>"><?php etranslate("Frequency")?>:</B></TD>
<TD>
  <INPUT NAME="rpt_freq" SIZE="4" MAXLENGTH="4" VALUE="<?php echo $rpt_freq; ?>">
 </TD>
</TR>
<?php } ?>

</TABLE>

<TABLE BORDER=0><TR><TD>
<SCRIPT LANGUAGE="JavaScript">
  document.writeln ( '<INPUT TYPE="button" VALUE="<?php etranslate("Save")?>" ONCLICK="validate_and_submit()">' );
  document.writeln ( '<INPUT TYPE="button" VALUE="<?php etranslate("Help")?>..." ONCLICK="window.open ( \'help_edit_entry.php<?php if ( ! isset ( $id ) ) echo "?add=1"; ?>\', \'cal_help\', \'dependent,menubar,scrollbars,height=400,width=400,innerHeight=420,outerWidth=420\');">' );
</SCRIPT>

<NOSCRIPT>
<INPUT TYPE="submit" VALUE="<?php etranslate("Save")?>">
</NOSCRIPT>

</TD></TR></TABLE>

<INPUT TYPE="hidden" NAME="participant_list" VALUE="">

</FORM>

<?php if ( $id > 0 && ( $login == $create_by || $single_user == "Y" || $is_admin ) ) { ?>
<A HREF="del_entry.php?id=<?php echo $id;?>" onClick="return confirm('<?php etranslate("Are you sure you want to delete this entry?")?>');"><?php etranslate("Delete entry")?></A><BR>
<?php } ?>
<?php
} else {
  echo translate("You are not authorized to edit this entry") . ".";
}
?>

<?php include "includes/trailer.php"; ?>
</BODY>
</HTML>
