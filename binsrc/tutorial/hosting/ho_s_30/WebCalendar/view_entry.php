<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2015 OpenLink Software
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

include "includes/translate.php";

// make sure this user is allowed to look at this calendar.
$can_view = false;
$is_my_event = false;

if ( $is_admin )
  $can_view = true;

if ( ! $can_view ) {
  // is this user a participant or the creator of the event?
  $sql = "SELECT webcal_entry.cal_id FROM webcal_entry, " .
    "webcal_entry_user WHERE webcal_entry.cal_id = " .
    "webcal_entry_user.cal_id AND webcal_entry.cal_id = $id " .
    "AND (webcal_entry.cal_create_by = '$login' " .
    "OR webcal_entry_user.cal_login = '$login')";
  $res = dbi_query ( $sql );
  if ( $res ) {
    $row = dbi_fetch_row ( $res );
    if ( $row && $row[0] > 0 ) {
      $can_view = true;
      $is_my_event = true;
    }
    dbi_free_result ( $res );
  }
}

if ( ! $can_view ) {
  $check_group = false;
  // if not a participant in the event, must be allowed to look at
  // other user's calendar.
  if ( $login == "__public__" ) {
    if ( $public_access_others == "Y" )
      $check_group = true;
  }
  else {
    if ( $allow_view_other != "Y" )
      $check_group = true;
  }
  // If $check_group is true now, it means this user can look at the
  // event only if they are in the same group as some of the people in
  // the event.
  // This gets kind of tricky.  If there is a participant from a different
  // group, do we still show it?  For now, the answer is no.
  // This could be configurable somehow, but how many lines of text would
  // it need in the admin page to describe this scenario?  Would confuse
  // 99.9% of users.
  // In summary, make sure at least one event participant is in one of
  // this user's groups.
  $my_users = get_my_users ();
  if ( is_array ( $my_users ) ) {
    $sql = "SELECT webcal_entry.cal_id FROM webcal_entry, " .
      "webcal_entry_user WHERE webcal_entry.cal_id = " .
      "webcal_entry_user.cal_id AND webcal_entry.cal_id = $id " .
      "AND webcal_entry_user.cal_login IN ( ";
    for ( $i = 0; $i < count ( $my_users ); $i++ ) {
      if ( $i > 0 )
        $sql .= ", ";
      $sql .= "'" . $my_users[$i]['cal_login'] . "'";
    }
    $sql .= " )";
    $res = dbi_query ( $sql );
    if ( $res ) {
      $row = dbi_fetch_row ( $res );
      if ( $row && $row[0] > 0 )
        $can_view = true;
      dbi_free_result ( $res );
    }
  }
  // If we didn't indicate we need to check groups, then this user
  // can't view this event.
  if ( ! $check_group )
    $can_view = false;
}

if ( ! $can_view ) {
  $error = translate ( "You are not authorized" );
}

// copied from edit_entry_handler (functions.php?)
function add_duration ( $time, $duration ) {
  $hour = (int) ( $time / 10000 );
  $min = ( $time / 100 ) % 100;
  $minutes = $hour * 60 + $min + $duration;
  $h = $minutes / 60;
  $m = $minutes % 60;
  $ret = sprintf ( "%d%02d00", $h, $m );
  //echo "add_duration ( $time, $duration ) = $ret <BR>";
  return $ret;
}

if ( ! empty ( $year ) )
  $thisyear = $year;
if ( ! empty ( $month ) )
  $thismonth = $month;
$pri[1] = translate("Low");
$pri[2] = translate("Medium");
$pri[3] = translate("High");

$unapproved = FALSE;

// Make sure this is not a continuation event.
// If it is, redirect the user to the original event.
$ext_id = -1;
if ( $id > 0 ) {
  $res = dbi_query ( "SELECT cal_ext_for_id FROM webcal_entry " .
    "WHERE cal_id = $id" );
  if ( $res ) {
    if ( $row = dbi_fetch_row ( $res ) ) {
      $ext_id = $row[0];
    }
    dbi_free_result ( $res );
  } else {
    // db error... ignore it, I guess.
  }
}
if ( $ext_id > 0 ) {
  $url = "view_entry.php?id=$ext_id";
  if ( $date != "" )
    $url .= "&date=$date";
  if ( $user != "" )
    $url .= "&user=$user";
  if ( $cat_id != "" )
    $url .= "&cat_id=$cat_id";
  do_redirect ( $url );
}

?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR; ?>" CLASS="defaulttext">

<?php

if ( $id < 1 ) {
  echo translate("Invalid entry id") . ".";
  exit;
}

// Try to determine the event status.
$event_status = "";

if ( $login != $user ) {
  // If viewing another user's calendar, check the status of the
  // event on their calendar (to see if it's deleted).
  $sql = "SELECT cal_status FROM webcal_entry_user " .
    "WHERE cal_login = '$user' AND cal_id = $id";
  $res = dbi_query ( $sql );
  if ( $res ) {
    if ( $row = dbi_fetch_row ( $res ) )
      $event_status = $row[0];
    dbi_free_result ( $res );
  }
} else {
  $sql = "SELECT cal_id, cal_status FROM webcal_entry_user " .
    "WHERE cal_login = '$login' AND cal_id = $id";
  $res = dbi_query ( $sql );
  if ( $res ) {
    $row = dbi_fetch_row ( $res );
    $event_status = $row[1];
    dbi_free_result ( $res );
  }
}

// At this point, if we don't have the event status, then either
// this user is not viewing an event from his own calendar and not
// viewing an event from someone else's calendar.
// They probably got here from the search results page (or possibly
// by hand typing in the URL.)
// Check to make sure that it hasn't been deleted from everyone's
// calendar.
if ( empty ( $event_status ) ) {
  $sql = "SELECT cal_status FROM webcal_entry_user " .
    "WHERE cal_status != 'D' ORDER BY cal_status";
  $res = dbi_query ( $sql );
  if ( $res ) {
    if ( $row = dbi_fetch_row ( $res ) )
      $event_status = $row[0];
    dbi_free_result ( $res );
  }
}

// If we have no event status yet, it must have been deleted.
if ( ( empty ( $event_status ) && ! $is_admin ) || ! $can_view ) {
  echo "<H2><FONT COLOR=\"$H2COLOR\">" . translate("Error") .
    "</FONT></H2>" . translate("You are not authorized") . ".\n";
  include "includes/trailer.php";
  echo "</BODY></HTML>\n";
  exit;
}


// Load event info now.
$sql = "SELECT cal_create_by, cal_date, cal_time, cal_mod_date, " .
  "cal_mod_time, cal_duration, cal_priority, cal_type, cal_access, " .
  "cal_name, cal_description FROM webcal_entry WHERE cal_id = " . $id;
$res = dbi_query ( $sql );
if ( ! $res ) {
  echo translate("Invalid entry id") . ": $id";
  exit;
}
$row = dbi_fetch_row ( $res );
$create_by = $row[0];
$event_time = $row[2];
$name = $row[9];
$description = $row[10];
// $subject is used for mailto URLs
$subject = translate($application_name) . ": " . $name;
// Remove the '"' character since it causes some mailers to barf
$subject = str_replace ( "\"", "", $subject );
$subject = htmlentities ( $subject );

$event_repeats = false;
// build info string for repeating events and end date
$sql = "SELECT cal_type, cal_end, cal_frequency, cal_days " .
  "FROM webcal_entry_repeats WHERE cal_id = $id";
$res = dbi_query ($sql);
if ( $res ) {
  if ( $tmprow = dbi_fetch_row ( $res ) ) {
    $event_repeats = true;
    $cal_type = $tmprow[0];
    $cal_end = $tmprow[1];
    $cal_frequency = $tmprow[2];
    $cal_days = $tmprow[3];

    if ( $cal_end ) {
      $rep_str .= "&nbsp; - &nbsp;";
      $rep_str .= date_to_str ( $cal_end );
    }
    $rep_str .= "&nbsp; (" . translate("every") . " ";

    if ( $cal_frequency > 1 ) {
      switch ( $cal_frequency ) {
        case 1: $rep_str .= translate("1st"); break;
        case 2: $rep_str .= translate("2nd"); break;
        case 3: $rep_str .= translate("3rd"); break;
        case 4: $rep_str .= translate("4th"); break;
        case 5: $rep_str .= translate("5th"); break;
        default: $rep_str .= $cal_frequency; break;
      }
    }
    switch ($cal_type) {
      case "daily": $rep_str .= translate("Day"); break;
      case "weekly": $rep_str .= translate("Week");
        for ($i=0; $i<=7; $i++) {
          if (substr($cal_days, $i, 1) == "y") {
            $rep_str .= ", " . weekday_short_name($i);
          }
        }
        break;
      case "monthlyByDay":
        $rep_str .= translate("Month") . "/" . translate("by day"); break;
      case "monthlyByDate":
        $rep_str .= translate("Month") . "/" . translate("by date"); break;
      case "yearly":
        $rep_str .= translate("Year"); break;
    }
    $rep_str .= ")";
  } else
    $rep_str = "";
  dbi_free_result ( $res );
}
/* calculate end time */
if ( $event_time > 0 && $row[5] > 0 )
  $end_str = "-" . display_time ( add_duration ( $row[2], $row[5] ) );
else
  $end_str = "";

// get the email adress of the creator of the entry
user_load_variables ( $create_by, "createby_" );
$email_addr = $createby_email;

// If confidential and not this user's event, then
// They cannot seem name or description.
//if ( $row[8] == "R" && ! $is_my_event && ! $is_admin ) {
if ( $row[8] == "R" && ! $is_my_event ) {
  $is_private = true;
  $name = "[" . translate("Confidential") . "]";
  $description = "[" . translate("Confidential") . "]";
} else {
  $is_private = false;
}

if ( $event_repeats && ! empty ( $date ) )
  $event_date = $date;
else
  $event_date = $row[1];

// TODO: don't let someone view another user's private entry
// by hand editing the URL.

// Get category Info
if ( $categories_enabled == "Y" ) {
  $sql = "SELECT cat_name FROM webcal_categories, webcal_entry_user " .
    "WHERE webcal_entry_user.cal_login = '$login' AND webcal_entry_user.cal_id = $id " .
    "AND webcal_entry_user.cal_category = webcal_categories.cat_id";
  $res2 = dbi_query ( $sql );
  if ( $res2 ) {
    $row2 = dbi_fetch_row ( $res2 );
    $category = $row2[0];
    dbi_free_result ( $res2 );
  }
}

?>
<H2><FONT COLOR="<?php echo $H2COLOR;?>"><?php echo htmlspecialchars ( $name ); ?></FONT></H2>

<TABLE BORDER=0>
<TR><TD VALIGN="top"><B><?php etranslate("Description")?>:</B></TD>
  <TD><?php echo nl2br ( activate_urls ( htmlspecialchars ( $description ) ) ); ?></TD></TR>

<?php if ( $event_status != 'A' && ! empty ( $event_status ) ) { ?>
  <TR><TD VALIGN="top"><B><?php etranslate("Status")?>:</B></TD>
  <TD><?php
     if ( $event_status == 'W' )
       etranslate("Waiting for approval");
     if ( $event_status == 'D' )
       etranslate("Deleted");
     else if ( $event_status == 'R' )
       etranslate("Rejected");
      ?></TD></TR>
<?php } ?>

<TR><TD VALIGN="top"><B><?php etranslate("Date")?>:</B></TD>
  <TD><?php
  if ( $event_repeats ) {
    echo date_to_str ( $event_date, "", true, false, $event_time );
  } else {
    echo date_to_str ( $row[1], "", true, false, $event_time );
  }
  ?></TD></TR>
<?php if ( $event_repeats ) { ?>
<TR><TD VALIGN="top"><B><?php etranslate("Repeat Type")?>:</B></TD>
  <TD><?php echo date_to_str ( $row[1], "", true, false, $event_time ) . $rep_str; ?></TD></TR>
<?php } ?>
<?php
// save date so the trailer links are for the same time period
$list = split ( "-", $row[1] );
$thisyear = (int) ( $row[1] / 10000 );
$thismonth = ( $row[1] / 100 ) % 100;
$thisday = $row[1] % 100;
?>
<?php if ( $event_time >= 0 ) { ?>
<TR><TD VALIGN="top"><B><?php etranslate("Time")?>:</B></TD>
  <TD><?php
    if ( $row[5] == ( 24 * 60 ) )
      etranslate("All day event");
    else
      echo display_time ( $row[2] ) . $end_str;
  ?></TD></TR>
<?php } ?>
<?php if ( $row[5] > 0 && $row[5] != ( 24 * 60 ) ) { ?>
<TR><TD VALIGN="top"><B><?php etranslate("Duration")?>:</B></TD>
  <TD><?php echo $row[5]; ?> <?php etranslate("minutes")?></TD></TR>
<?php } ?>
<?php if ( $disable_priority_field != "Y" ) { ?>
<TR><TD VALIGN="top"><B><?php etranslate("Priority")?>:</B></TD>
  <TD><?php echo $pri[$row[6]]; ?></TD></TR>
<?php } ?>
<?php if ( $disable_access_field != "Y" ) { ?>
<TR><TD VALIGN="top"><B><?php etranslate("Access")?>:</B></TD>
  <TD><?php echo ( $row[8] == "P" ) ? translate("Public") : translate("Confidential"); ?></TD></TR>
<?php } ?>
<?php if ( $categories_enabled == "Y" && ! empty ( $category ) ) { ?>
<TR><TD VALIGN="top"><B><?php etranslate("Category")?>:</B></TD>
  <TD><?php echo $category; ?></TD></TR>
<?php } ?>
<?php
if ( $single_user == "N" ) {
  echo "<TR><TD VALIGN=\"top\"><B>" . translate("Created by") . ":</B></TD>\n";
  if ( $is_private )
    echo "<TD>[" . translate("Confidential") . "]</TD></TR>\n";
  else {
    if ( strlen ( $email_addr ) )
      echo "<TD><A HREF=\"mailto:$email_addr?subject=$subject\">" .
        ( $row[0] == "__public__" ? "Public Access" : $row[0] ) .
	"</A></TD></TR>\n";
    else
      echo "<TD>" .
        ( $row[0] == "__public__" ? "Public Access" : $row[0] ) .
	"</TD></TR>\n";
  }
}
?>
<TR><TD VALIGN="top"><B><?php etranslate("Updated")?>:</B></TD>
  <TD><?php
    echo date_to_str ( $row[3] );
    echo " ";
    echo display_time ( $row[4] );
   ?></TD></TR>
<?php
// load any site-specific fields and display them
$extras = get_site_extra_fields ( $id );
for ( $i = 0; $i < count ( $site_extras ); $i++ ) {
  $extra_name = $site_extras[$i][0];
  $extra_type = $site_extras[$i][2];
  $extra_arg1 = $site_extras[$i][3];
  $extra_arg2 = $site_extras[$i][4];
  if ( $extras[$extra_name]['cal_name'] != "" ) {
    echo "<TR><TD VALIGN=\"top\"><B>" .
      translate ( $site_extras[$i][1] ) .
      ":</B></TD><TD>";
    if ( $extra_type == $EXTRA_URL ) {
      if ( strlen ( $extras[$extra_name]['cal_data'] ) )
        echo "<A HREF=\"" . $extras[$extra_name]['cal_data'] . "\">" .
          $extras[$extra_name]['cal_data'] . "</A>";
    } else if ( $extra_type == $EXTRA_EMAIL ) {
      if ( strlen ( $extras[$extra_name]['cal_data'] ) )
        echo "<A HREF=\"mailto:" . $extras[$extra_name]['cal_data'] .
          "?subject=$subject\">" .
          $extras[$extra_name]['cal_data'] . "</A>";
    } else if ( $extra_type == $EXTRA_DATE ) {
      if ( $extras[$extra_name]['cal_date'] > 0 )
        echo date_to_str ( $extras[$extra_name]['cal_date'] );
    } else if ( $extra_type == $EXTRA_TEXT ||
      $extra_type == $EXTRA_MULTILINETEXT ) {
      echo nl2br ( $extras[$extra_name]['cal_data'] );
    } else if ( $extra_type == $EXTRA_USER ) {
      echo $extras[$extra_name]['cal_data'];
    } else if ( $extra_type == $EXTRA_REMINDER ) {
      if ( $extras[$extra_name]['cal_remind'] <= 0 )
        etranslate ( "No" );
      else {
        etranslate ( "Yes" );
        if ( ( $extra_arg2 & $EXTRA_REMINDER_WITH_DATE ) > 0 ) {
          echo "&nbsp;&nbsp;-&nbsp;&nbsp;";
          echo date_to_str ( $extras[$extra_name]['cal_date'] );
        } else if ( ( $extra_arg2 & $EXTRA_REMINDER_WITH_OFFSET ) > 0 ) {
          echo "&nbsp;&nbsp;-&nbsp;&nbsp;";
          $minutes = $extras[$extra_name]['cal_data'];
          $d = (int) ( $minutes / ( 24 * 60 ) );
          $minutes -= ( $d * 24 * 60 );
          $h = (int) ( $minutes / 60 );
          $minutes -= ( $h * 60 );
          if ( $d > 0 )
            echo $d . " " . translate("days") . " ";
          if ( $h > 0 )
            echo $h . " " . translate("hours") . " ";
          if ( $minutes > 0 )
            echo $minutes . " " . translate("minutes");
          echo " " . translate("before event" );
        }
      }
    } else if ( $extra_type == $EXTRA_SELECTLIST ) {
      echo $extras[$extra_name]['cal_data'];
    }
    echo "</TD></TR>\n";
  }
}
?>

<?php // participants
// Only ask for participants if we are multi-user.
$allmails = array ();
$show_participants = ( $disable_participants_field != "Y" );
if ( $is_admin )
  $show_participants = true;
if ( $public_access == "Y" && $login == "__public__" &&
  $public_access_others != "Y" )
  $show_participants = false;
if ( $single_user == "N" && $show_participants ) {
?>
<TR><TD VALIGN="top"><B><?php etranslate("Participants")?>:</B></TD>
  <TD><?php
  if ( $is_private ) {
    echo "[" . translate("Confidential") . "]";
  } else {
    $sql = "SELECT cal_login, cal_status FROM webcal_entry_user " .
      "WHERE cal_id = $id";
    //echo "$sql<P>\n";
    $res = dbi_query ( $sql );
    $first = 1;
    $num_app = $num_wait = $num_rej = 0;
    if ( $res ) {
      while ( $row = dbi_fetch_row ( $res ) ) {
        $pname = $row[0];
        if ( $login == $row[0] && $row[1] == 'W' )
          $unapproved = TRUE;
        if ( $row[1] == 'A' )
          $approved[$num_app++] = $pname;
        else if ( $row[1] == 'W' )
          $waiting[$num_wait++] = $pname;
        else if ( $row[1] == 'R' )
          $rejected[$num_rej++] = $pname;
      }
      dbi_free_result ( $res );
    } else {
      echo translate ("Database error") . ": " . dbi_error() . "<BR>";
    }
  }
  for ( $i = 0; $i < $num_app; $i++ ) {
    user_load_variables ( $approved[$i], "temp" );
    if ( strlen ( $tempemail ) ) {
      echo "<A HREF=\"mailto:" . $tempemail . "?subject=$subject\">" . $tempfullname . "</A><BR>\n";
      $allmails[] = $tempemail;
    } else {
      echo $tempfullname . "<BR>\n";
    }
  }
  // show external users here...
  if ( ! empty ( $allow_external_users ) && $allow_external_users == "Y" ) {
    $external_users = event_get_external_users ( $id, 1 );
    $ext_users = explode ( "\n", $external_users );
    if ( is_array ( $ext_users ) ) {
      for ( $i = 0; $i < count( $ext_users ); $i++ ) {
        if ( ! empty ( $ext_users[$i] ) )
          echo $ext_users[$i] . " (" . translate("External User") . ")<BR>\n";
      }
    }
  }
  for ( $i = 0; $i < $num_wait; $i++ ) {
    user_load_variables ( $waiting[$i], "temp" );
    if ( strlen ( $tempemail ) ) {
      echo "<BR><A HREF=\"mailto:" . $tempemail . "?subject=$subject\">" . $tempfullname . "</a> (?)\n";
      $allmails[] = $tempemail;
    } else {
      echo "<BR>" . $tempfullname . " (?)\n";
    }
  }
  for ( $i = 0; $i < $num_rej; $i++ ) {
    user_load_variables ( $rejected[$i], "temp" );
    if ( strlen ( $tempemail ) ) {
      echo "<BR><STRIKE><A HREF=\"mailto:" . $tempemail .
        "?subject=$subject\">" . $tempfullname .
        "</a></STRIKE> (" . translate("Rejected") . ")\n";
    } else {
      echo "<BR><STRIKE>$tempfullname</STRIKE> (" . translate("Rejected") . ")\n";
    }
  }


?></TD></TR>
<?php
} // end participants
?>

</TABLE>

<P>
<?php

if ( empty ( $event_status ) ) {
  // this only happens when an admin views a deleted event that he is
  // not a participant for.  Set to $event_status to "D" just to get
  // rid of all the edit/delete links below.
  $event_status = "D";
}

if ( $unapproved ) {
  echo "<A HREF=\"approve_entry.php?id=$id\" onClick=\"return confirm('" .
    translate("Approve this entry?") .
    "');\">" . translate("Approve/Confirm entry") . "</A><BR>\n";
  echo "<A HREF=\"reject_entry.php?id=$id\" onClick=\"return confirm('" .
    translate("Reject this entry?") .
    "');\">" . translate("Reject entry") . "</A><BR>\n";
}

if ( ! empty ( $user ) && $login != $user )
  $u_url = "&user=$user";
else
  $u_url = "";

$can_edit = ( $is_admin || ( $is_assistant && ! $is_private ) ||
  ( $readonly != "Y" && ( $login == $create_by || $single_user == "Y" ) ) );
if ( $public_access == "Y" && $login == "__public__" )
  $can_edit = false;

$rdate = "";
if ( $event_repeats )
  $rdate = "&date=$event_date";

// If approved, but event category not set (and user does not have permission
// to edit where they could also set the category), then allow them to
// set it through set_cat.php.
if ( empty ( $user ) && $categories_enabled == "Y" &&
  $readonly != "Y" && $is_my_event && $login != "__public__" &&
  $event_status != "D" && ! $can_edit )  {
  echo "<A CLASS=\"navlinks\" HREF=\"set_entry_cat.php?id=$id$rdate\">" .
    translate("Set category") . "</A><BR>\n";
}


if ( $can_edit && $event_status != "D" ) {
  if ( $event_repeats ) {
    echo "<A CLASS=\"navlinks\" HREF=\"edit_entry.php?id=$id\">" .
      translate("Edit repeating entry for all dates") . "</A><BR>\n";
    echo "<A CLASS=\"navlinks\" HREF=\"edit_entry.php?id=$id$rdate&override=1\">" .
      translate("Edit entry for this date") . "</A><BR>\n";
    echo "<A CLASS=\"navlinks\" HREF=\"del_entry.php?id=$id$u_url&override=1\" onClick=\"return confirm('" .
      translate("Are you sure you want to delete this entry?") .
      "\\n\\n" . translate("This will delete this entry for all users.") .
      "');\">" . translate("Delete repeating event for all dates") . "</A><BR>\n";
    echo "<A CLASS=\"navlinks\" HREF=\"del_entry.php?id=$id$u_url$rdate&override=1\" onClick=\"return confirm('" .
      translate("Are you sure you want to delete this entry?") .
      "\\n\\n" . translate("This will delete this entry for all users.") .
      "');\">" . translate("Delete entry only for this date") . "</A><BR>\n";
  } else {
    echo "<A CLASS=\"navlinks\" HREF=\"edit_entry.php?id=$id$u_url\">" .
      translate("Edit entry") . "</A><BR>\n";
    echo "<A CLASS=\"navlinks\" HREF=\"del_entry.php?id=$id$u_url$rdate\" onClick=\"return confirm('" .
      translate("Are you sure you want to delete this entry?") .
      "\\n\\n" . translate("This will delete this entry for all users.") .
      "');\">" . translate("Delete entry") . "</A><BR>\n";
  }
} elseif ( $readonly != "Y" && $is_my_event && $login != "__public__" &&
  $event_status != "D" )  {
  echo "<A CLASS=\"navlinks\" HREF=\"del_entry.php?id=$id$u_url$rdate\" onClick=\"return confirm('" .
    translate("Are you sure you want to delete this entry?") .
    "\\n\\n" . translate("This will delete the entry from your calendar.") .
    "');\">" . translate("Delete entry") . "</A><BR>\n";
}
if ( $readonly != "Y" && ! $is_my_event && ! $is_private && 
  $event_status != "D" && $login != "__public__" )  {
  echo "<A CLASS=\"navlinks\" HREF=\"add_entry.php?id=$id\" onClick=\"return confirm('" .
    translate("Do you want to add this entry to your calendar?") .
    "\\n\\n" . translate("This will add the entry to your calendar.") .
    "');\">" . translate("Add to My Calendar") . "</A><BR>\n";
}

if ( count ( $allmails ) > 0 ) {
  echo "<A CLASS=\"navlinks\" HREF=\"mailto:" . implode ( ", ", $allmails ) .
    "?subject=$subject\">" .
    translate("Email all participants") . "</A><BR>\n";
}

$show_log = false;

if ( $is_admin ) {
  if ( empty ( $log ) ) {
    echo "<A CLASS=\"navlinks\" HREF=\"view_entry.php?id=$id&log=1\">" .
      translate("Show activity log") . "</A><BR>\n";
  } else {
    echo "<A CLASS=\"navlinks\" HREF=\"view_entry.php?id=$id\">" .
      translate("Hide activity log") . "</A><BR>\n";
    $show_log = true;
  }
}


if ( $show_log ) {
  echo "<H3>" . translate("Activity Log") . "</H3>\n";
  echo "<TABLE BORDER=\"0\" WIDTH=\"100%\">\n";
  echo "<TR>";
  echo "<TH ALIGN=\"left\" BGCOLOR=\"$THBG\"><FONT COLOR=\"$THFG\">" .
    translate("User") . "</FONT></TH>";
  echo "<TH ALIGN=\"left\" BGCOLOR=\"$THBG\"><FONT COLOR=\"$THFG\">" .
    translate("Calendar") . "</FONT></TH>";
  echo "<TH ALIGN=\"left\" BGCOLOR=\"$THBG\"><FONT COLOR=\"$THFG\">" .
    translate("Date") . "/" . translate("Time") . "</FONT></TH>";
  echo "<TH ALIGN=\"left\" BGCOLOR=\"$THBG\"><FONT COLOR=\"$THFG\">" .
    translate("Action") . "</FONT></TH></TR>\n";
  $res = dbi_query ( "SELECT cal_login, cal_user_cal, cal_type, " .
    "cal_date, cal_time " .
    "FROM webcal_entry_log WHERE cal_entry_id = $id " .
    "ORDER BY cal_log_id DESC" );
  if ( $res ) {
    $font = "<FONT SIZE=\"-1\">";
    while ( $row = dbi_fetch_row ( $res ) ) {
      echo "<TR>";
      echo "<TD VALIGN=\"top\" BGCOLOR=\"$CELLBG\">" . $font . $row[0] .
        "</FONT></TD>";
      echo "<TD VALIGN=\"top\" BGCOLOR=\"$CELLBG\">" . $font . $row[1] .
        "</FONT></TD>";
      echo "<TD VALIGN=\"top\" BGCOLOR=\"$CELLBG\">" . $font .
	date_to_str ( $row[3] ) . " " .
        display_time ( $row[4] ) . "</FONT></TD>";
      echo "<TD BGCOLOR=\"$CELLBG\">" . $font;
      if ( $row[2] == $LOG_CREATE )
        etranslate("Event created");
      else if ( $row[2] == $LOG_APPROVE )
        etranslate("Event approved");
      else if ( $row[2] == $LOG_REJECT )
        etranslate("Event rejected");
      else if ( $row[2] == $LOG_UPDATE )
        etranslate("Event updated");
      else if ( $row[2] == $LOG_DELETE )
        etranslate("Event deleted");
      else if ( $row[2] == $LOG_NOTIFICATION )
        etranslate("Notification sent");
      else if ( $row[2] == $LOG_REMINDER )
        etranslate("Reminder sent");
      echo "</FONT></TD></TR>\n";
    }
    dbi_free_result ( $res );
  }
  echo "</TABLE>\n";
}

?>

<?php include "includes/trailer.php"; ?>
</BODY>
</HTML>
