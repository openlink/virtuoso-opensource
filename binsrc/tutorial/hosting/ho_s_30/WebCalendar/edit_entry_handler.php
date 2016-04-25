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
include "includes/site_extras.php";
include "includes/validate.php";
include "includes/connect.php";

load_global_settings ();
load_user_preferences ();
load_user_categories ();

include "includes/translate.php";

$error = "";

$do_override = false;
$old_id = -1;
if ( ! empty ( $override ) && ! empty ( $override_date ) ) {
  // override date specified.  user is going to create an exception
  // to a repeating event.
  $do_override = true;
  $old_id = $id;
}

// Modify the time to be server time rather than user time.
if ( ! empty ( $hour ) ) {
  $hour -= $TZ_OFFSET;
  if ( $hour < 0 ) {
    $hour += 24;
    // adjust date
    $date = mktime ( 3, 0, 0, $month, $day, $year );
    $date -= $ONE_DAY;
    $month = date ( "m", $date );
    $day = date ( "d", $date );
    $year = date ( "Y", $date );
  }
  if ( $hour > 24 ) {
    $hour -= 24;
    // adjust date
    $date = mktime ( 3, 0, 0, $month, $day, $year );
    $date += $ONE_DAY;
    $month = date ( "m", $date );
    $day = date ( "d", $date );
    $year = date ( "Y", $date );
  }
}

// Return the time in HHMMSS format of input time + duration
// $time - format "235900"
// $duration - number of minutes
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


// Make sure this user is really allowed to edit this event.
// Otherwise, someone could hand type in the URL to edit someone else's
// event.
// Can edit if:
//   - new event
//   - user is admin
//   - user created event
//   - user is participant
$can_edit = false;
if ( empty ( $id ) ) {
  // New event...
  $can_edit = true;
} else if ( $is_admin || $is_assistant ) {
  $can_edit = true;
} else {
  // event owner?
  $sql = "SELECT cal_create_by FROM webcal_entry WHERE cal_id = '$id'";
  $res = dbi_query($sql);
  if ($res) {
    $row = dbi_fetch_row ( $res );
    if ( $row[0] == $login )
      $can_edit = true;
    dbi_free_result ( $res );
  } else
    $error = translate("Database error") . ": " . dbi_error ();
}
if ( empty ( $error ) && ! $can_edit ) {
  // is user a participant of that event ?
  $sql = "SELECT cal_id FROM webcal_entry_user WHERE cal_id = '$id' " .
    "AND cal_login = '$login' AND cal_status IN ('W','A')";
  $res = dbi_query ( $sql );
  if ($res) {
    $row = dbi_fetch_row ( $res );
    if ( ! empty( $row[0] ) )
      $can_edit = true; // is participant
    dbi_free_result ( $res );
  } else
    $error = translate("Database error") . ": " . dbi_error ();
}

if ( ! $can_edit && empty ( $error ) )
  $error = translate ( "You are not authorized" );

// If display of participants is disabled, set the participant list
// to the event creator.  This also works for single-user mode.
// Basically, if no participants were selected (because there
// was no selection list available in the form or because the user
// refused to select any participant from the list), then we will
// assume the only participant is the current user.
if ( ! strlen ( $participants[0] ) )
  $participants[0] = $login;

// If "all day event" was selected, then we set the event time
// to be 12AM with a duration of 24 hours.
// We don't actually store the "all day event" flag per se.  This method
// makes conflict checking much simpler.  We just need to make sure
// that we don't screw up the day view (which normally starts the
// view with the first timed event).
// Note that if someone actually wants to create an event that starts
// at midnight and lasts exactly 24 hours, it will be treated in the
// same manner.
if ( $allday == "Y" ) {
  $duration_h = 24;
  $duration_m = 0;
  $hour = 0;
  $minute = 0;
}

$duration = ( $duration_h * 60 ) + $duration_m;
if ( strlen ( $hour ) > 0 ) {
  if ( $TIME_FORMAT == '12' ) {
    $ampmt = $ampm;
    //This way, a user can pick am and still
    //enter a 24 hour clock time.
    if ($hour > 12 && $ampm == 'am') {
      $ampmt = 'pm';
    }
    $hour %= 12;
    if ( $ampmt == 'pm' )
      $hour += 12;
  }
}

// handle external participants
$ext_names = array ();
$ext_emails = array ();
$matches = array ();
$ext_count = 0;
if ( $single_user == "N" &&
  ! empty ( $allow_external_users ) && $allow_external_users == "Y" ) {
  $lines = explode ( "\n", $externalparticipants );
  if ( ! is_array ( $lines ) )
    $lines = array ( $externalparticipants );
  if ( is_array ( $lines ) ) {
    for ( $i = 0; $i < count ( $lines ); $i++ ) {
      $ext_words = explode ( " ", $lines[$i] );
      if ( ! is_array ( $ext_words ) )
        $ext_words = array ( $lines[$i] );
      if ( is_array ( $ext_words ) ) {
        $ext_names[$ext_count] = "";
        $ext_emails[$ext_count] = "";
        for ( $j = 0; $j < count ( $ext_words ); $j++ ) {
          // use regexp matching to pull email address out
          if ( preg_match ( "/<?\\S+@\\S+\\.\\S+>?/", $ext_words[$j],
            $matches ) ) {
            $ext_emails[$ext_count] = $matches[0];
            $ext_emails[$ext_count] = preg_replace ( "/[<>]/", "",
              $ext_emails[$ext_count] );
          } else {
            if ( strlen ( $ext_names[$ext_count] ) )
              $ext_names[$ext_count] .= " ";
            $ext_names[$ext_count] .= $ext_words[$j];
          }
        }
        $ext_count++;
      }
    }
  }
}

// first check for any schedule conflicts
if ( empty ( $allow_conflict_override ) || $allow_conflict_override != "Y" ) {
  $confirm_conflicts = ""; // security precaution
}
if ( $allow_conflicts != "Y" && empty ( $confirm_conflicts ) &&
  strlen ( $hour ) > 0 ) {
  $date = mktime ( 3, 0, 0, $month, $day, $year );
  $str_cal_date = date ( "Ymd", $date );
  if ( strlen ( $hour ) > 0 )
    $str_cal_time = sprintf ( "%02d%02d00", $hour, $minute );
  if ( ! empty ( $rpt_end_use ) )
    $endt = mktime ( 3, 0, 0, $rpt_month, $rpt_day,$rpt_year );
  else
    $endt = 'NULL';

  if ($rpt_type == 'weekly') {
    $dayst = ( $rpt_sun ? 'y' : 'n' )
      . ( $rpt_mon ? 'y' : 'n' )
      . ( $rpt_tue ? 'y' : 'n' )
      . ( $rpt_wed ? 'y' : 'n' )
      . ( $rpt_thu ? 'y' : 'n' )
      . ( $rpt_fri ? 'y' : 'n' )
      . ( $rpt_sat ? 'y' : 'n' );
  } else {
    $dayst = "nnnnnnn";
  }

  // Load exception days... but not for a new event (which can't have
  // exception dates yet)
  $ex_days = array ();
  if ( ! empty ( $id ) ) {
    $res = dbi_query ( "SELECT cal_date FROM webcal_entry_repeats_not " .
      "WHERE cal_id = $id" );
    if ( $res ) {
      while ( $row = dbi_fetch_row ( $res ) ) {
        $ex_days[] = $row[0];
      }
      dbi_free_result ( $res );
    } else
      $error = translate("Database error") . ": " . dbi_error ();
  }
  
  $dates = get_all_dates ( $date, $rpt_type, $endt, $dayst,
    $ex_days, $rpt_freq );

  //echo $id . "<BR>";
  $conflicts = check_for_conflicts ( $dates, $duration, $hour, $minute,
    $participants, $login, empty ( $id ) ? 0 : $id );

}
if ( empty ( $error ) && ! empty ( $conflicts ) ) {
  $error = translate("The following conflicts with the suggested time") .
    ":<UL>$conflicts</UL>";
}


if ( empty ( $error ) ) {
  $newevent = true;
  // now add the entries
  if ( empty ( $id ) || $do_override ) {
    $res = dbi_query ( "SELECT MAX(cal_id) FROM webcal_entry" );
    if ( $res ) {
      $row = dbi_fetch_row ( $res );
      $id = $row[0] + 1;
      dbi_free_result ( $res );
    } else {
      $id = 1;
    }
  } else {
    $newevent = false;
    // save old status values of participants
    $sql = "SELECT cal_login, cal_status, cal_category FROM webcal_entry_user " .
      "WHERE cal_id = $id ";
    $res = dbi_query ( $sql );
    if ( $res ) {
      for ( $i = 0; $tmprow = dbi_fetch_row ( $res ); $i++ ) {
        $old_status[$tmprow[0]] = $tmprow[1]; 
        $old_category[$tmprow[0]] = $tmprow[2];
      }
      dbi_free_result ( $res );
    } else
      $error = translate("Database error") . ": " . dbi_error ();
    if ( empty ( $error ) ) {
      dbi_query ( "DELETE FROM webcal_entry WHERE cal_id = $id" );
      dbi_query ( "DELETE FROM webcal_entry_user WHERE cal_id = $id" );
      dbi_query ( "DELETE FROM webcal_entry_ext_user WHERE cal_id = $id" );
      dbi_query ( "DELETE FROM webcal_entry_repeats WHERE cal_id = $id" );
      dbi_query ( "DELETE FROM webcal_site_extras WHERE cal_id = $id" );
    }
    $newevent = false;
  }

  if ( $do_override ) {
    $sql = "INSERT INTO webcal_entry_repeats_not ( cal_id, cal_date ) " .
      "VALUES ( $old_id, $override_date )";
    if ( ! dbi_query ( $sql ) ) {
      $error = translate("Database error") . ": " . dbi_error ();
    }
  }

  $sql = "INSERT INTO webcal_entry ( cal_id, " .
    ( $old_id > 0 ? " cal_group_id, " : "" ) .
    "cal_create_by, cal_date, " .
    "cal_time, cal_mod_date, cal_mod_time, cal_duration, cal_priority, " .
    "cal_access, cal_type, cal_name, cal_description ) " .
    "VALUES ( $id, " .
    ( $old_id > 0 ? " $old_id, " : "" ) .
    "'$login', ";

  $date = mktime ( 3, 0, 0, $month, $day, $year );
  $sql .= date ( "Ymd", $date ) . ", ";
  if ( strlen ( $hour ) > 0 ) {
    $sql .= sprintf ( "%02d%02d00, ", $hour, $minute );
  } else
    $sql .= "-1, ";
  $sql .= date ( "Ymd" ) . ", " . date ( "Gis" ) . ", ";
  $sql .= sprintf ( "%d, ", $duration );
  $sql .= sprintf ( "%d, ", $priority );
  $sql .= "'$access', ";
  if ( $rpt_type != 'none' )
    $sql .= "'M', ";
  else
    $sql .= "'E', ";

  if ( strlen ( $name ) == 0 )
    $name = translate("Unnamed Event");
  $sql .= "'" . $name .  "', ";
  if ( strlen ( $description ) == 0 )
    $description = $name;
  $sql .= "'" . $description . "' )";
  
  if ( empty ( $error ) ) {
    if ( ! dbi_query ( $sql ) )
      $error = translate("Database error") . ": " . dbi_error ();
  }

  // log add/update
  activity_log ( $id, $login, $login,
    $newevent ? $LOG_CREATE : $LOG_UPDATE, "" );
  
  if ( $single_user == "Y" ) {
    $participants[0] = $single_user_login;
  }

  // check if participants have been removed and send out emails
  if ( ! $newevent && count ( $old_status ) > 0 ) {  // nur bei Update!!!
    while ( list ( $old_participant, $dummy ) = each ( $old_status ) ) {
      $found_flag = false;
      for ( $i = 0; $i < count ( $participants ); $i++ ) {
        if ( $participants[$i] == $old_participant ) {
          $found_flag = true;
          break;
        }
      }
      if ( !$found_flag ) {
        // only send mail if their email address is filled in
        $do_send = get_pref_setting ( $old_participants, "EMAIL_EVENT_DELETED" );
        user_load_variables ( $old_participant, "temp" );
        if ( $old_participant != $login && strlen ( $tempemail ) &&
          $do_send == "Y" && $send_email != "N" ) {
          $fmtdate = sprintf ( "%04d%02d%02d", $year, $month, $day );
          $msg = translate("Hello") . ", " . $tempfullname . ".\n\n" .
            translate("An appointment has been canceled for you by") .
            " " . $login_fullname .  ". " .
            translate("The subject was") . " \"" . $name . "\"\n\n" .
            translate("The description is") . " \"" . $description . "\"\n" .
            translate("Date") . ": " . date_to_str ( $fmtdate ) . "\n" .
            ( ( empty ( $hour ) && empty ( $minute ) ) ? "" :
            translate("Time") . ": " .
              display_time ( ( $hour * 10000 ) + ( $minute * 100 ) ) ) .
            "\n\n\n";
          // add URL to event, if we can figure it out
          if ( ! empty ( $server_url ) ) {
            $url = $server_url .  "view_entry.php?id=" .  $id;
            $msg .= $url . "\n\n";
          }
	  # translate("Title")
          if ( strlen ( $login_email ) )
            $extra_hdrs = "From: $login_email\nX-Mailer: " . translate($application_name);
          else
            $extra_hdrs = "From: $email_fallback_from\nX-Mailer: " . translate($application_name);
          mail ( $tempemail,
            translate($application_name) . " " . translate("Notification") . ": " . $name,
            html_to_8bit ($msg), $extra_hdrs );
          activity_log ( $id, $login, $old_participant, $LOG_NOTIFICATION,
	    "User removed from participants list" );
        }
      }
    }
  }

  // now add participants and send out notifications
  for ( $i = 0; $i < count ( $participants ); $i++ ) {
    $my_cat_id = "";
    // if public access, require approval unless
    // $public_access_add_needs_approval is set to "N"
    if ( $login == "__public__" ) {
      if ( ! empty ( $public_access_add_needs_approval ) &&
        $public_access_add_needs_approval == "N" ) {
        $status = "A"; // no approval needed
      } else {
        $status = "W"; // approval required
      }
      $my_cat_id = $cat_id;
    } else if ( ! $newevent ) {
      // keep the old status if no email will be sent
      $send_user_mail = ( $old_status[$participants[$i]] == '' ||
        $entry_changed ) ?  true : false;
      $tmp_status = ( $old_status[$participants[$i]] && ! $send_user_mail ) ?
        $old_status[$participants[$i]] : "W";
      $status = ( $participants[$i] != $login && $require_approvals == "Y" ) ?
        $tmp_status : "A";
      $tmp_cat = ( ! empty ( $old_category[$participants[$i]]) ) ?
        $old_category[$participants[$i]] : 'NULL';
      $my_cat_id = ( $participants[$i] != $login ) ? $tmp_cat : $cat_id;
    } else {
      $send_user_mail = true;
      $status = ( $participants[$i] != $login && $require_approvals == "Y" ) ?
        "W" : "A";
      if ( $participants[$i] == $login ) {
        $my_cat_id = $cat_id;
      } else {
        // if it's a global cat, then set it for other users as well.
        if ( ! empty ( $categories[$cat_id] ) &&
          empty ( $category_owners[$cat_id] ) ) {
          // found categ. and owner set to NULL; it is global
          $my_cat_id = $cat_id;
        } else {
          // not global category
          $my_cat_id = 'NULL';
        }
      }
    }
    if ( empty ( $my_cat_id ) ) $my_cat_id = 'NULL';
    $sql = "INSERT INTO webcal_entry_user " .
      "( cal_id, cal_login, cal_status, cal_category ) VALUES ( $id, '" .
      $participants[$i] . "', '$status', $my_cat_id )";
    if ( ! dbi_query ( $sql ) ) {
      $error = translate("Database error") . ": " . dbi_error ();
      break;
    } else {
      $from = $user_email;
      if ( empty ( $from ) && ! empty ( $email_fallback_from ) )
        $from = $email_fallback_from;
      // only send mail if their email address is filled in
      $do_send = get_pref_setting ( $participants[$i],
         $newevent ? "EMAIL_EVENT_ADDED" : "EMAIL_EVENT_UPDATED" );
      user_load_variables ( $participants[$i], "temp" );
      if ( $participants[$i] != $login && strlen ( $tempemail ) &&
        $do_send == "Y" && $send_user_mail && $send_email != "N" ) {
        $fmtdate = sprintf ( "%04d%02d%02d", $year, $month, $day );
        $msg = translate("Hello") . ", " . $tempfullname . ".\n\n";
        if ( $newevent || $old_status[$participants[$i]] == '' )
          $msg .= translate("A new appointment has been made for you by");
        else
          $msg .= translate("An appointment has been updated by");
        $msg .= " " . $login_fullname .  ". " .
          translate("The subject is") . " \"" . $name . "\"\n\n" .
          translate("The description is") . " \"" . $description . "\"\n" .
          translate("Date") . ": " . date_to_str ( $fmtdate ) . "\n" .
          translate("Time") . ": " .
          display_time ( ( $hour * 10000 ) + ( $minute * 100 ) ) . "\n\n\n";
          translate("Please look on") . " " . translate($application_name) . " " .
          ( $require_approvals == "Y" ?
          translate("to accept or reject this appointment") :
          translate("to view this appointment") ) . ".";
        // add URL to event, if we can figure it out
        if ( ! empty ( $server_url ) ) {
          $url = $server_url .  "view_entry.php?id=" .  $id;
          $msg .= "\n\n" . $url;
        }
        if ( strlen ( $from ) )
          $extra_hdrs = "From: $from\nX-Mailer: " . translate($application_name);
        else
          $extra_hdrs = "X-Mailer: " . translate($application_name);
        mail ( $tempemail,
          translate($application_name) . " " . translate("Notification") . ": " . $name,
          html_to_8bits ($msg), $extra_hdrs );
        activity_log ( $id, $login, $participants[$i], $LOG_NOTIFICATION, "" );
      }
    }
  }

  // add external participants
  // send notification if enabled.
  if ( is_array ( $ext_names ) && is_array ( $ext_emails ) ) {
    for ( $i = 0; $i < count ( $ext_names ); $i++ ) {
      if ( strlen ( $ext_names[$i] ) ) {
        $sql = "INSERT INTO webcal_entry_ext_user " .
          "( cal_id, cal_fullname, cal_email ) VALUES ( " .
          "$id, '$ext_names[$i]', ";
        if ( strlen ( $ext_emails[$i] ) )
          $sql .= "'$ext_emails[$i]' )";
        else
          $sql .= "NULL )";
        if ( ! dbi_query ( $sql ) ) {
          $error = translate("Database error") . ": " . dbi_error ();
        }
        // send mail notification if enabled
        // TODO: move this code into a function...
        if ( $external_notifications == "Y" && $send_email != "N" &&
          strlen ( $ext_emails[$i] ) > 0 ) {
          $fmtdate = sprintf ( "%04d%02d%02d", $year, $month, $day );
          $msg = translate("Hello") . ", " . $ext_names[$i] . ".\n\n";
          if ( $newevent )
            $msg .= translate("A new appointment has been made for you by");
          else
            $msg .= translate("An appointment has been updated by");
          $msg .= " " . $login_fullname .  ". " .
            translate("The subject is") . " \"" . $name . "\"\n\n" .
            translate("The description is") . " \"" . $description . "\"\n" .
            translate("Date") . ": " . date_to_str ( $fmtdate ) . "\n" .
            translate("Time") . ": " .
            display_time ( ( $hour * 10000 ) + ( $minute * 100 ) ) . "\n\n\n";
            translate("Please look on") . " " . translate($application_name) .
            ".";
          // add URL to event, if we can figure it out
          if ( ! empty ( $server_url ) ) {
            $url = $server_url .  "view_entry.php?id=" .  $id;
            $msg .= "\n\n" . $url;
          }
          if ( strlen ( $from ) )
            $extra_hdrs = "From: $from\nX-Mailer: " . translate($application_name);
          else
            $extra_hdrs = "X-Mailer: " . translate($application_name);
          mail ( $ext_emails[$i],
            translate($application_name) . " " .
            translate("Notification") . ": " . $name,
            html_to_8bits ($msg), $extra_hdrs );
        
        }
      }
    }
  }

  // add site extras
  for ( $i = 0; $i < count ( $site_extras ) && empty ( $error ); $i++ ) {
    $sql = "";
    $extra_name = $site_extras[$i][0];
    $extra_type = $site_extras[$i][2];
    $extra_arg1 = $site_extras[$i][3];
    $extra_arg2 = $site_extras[$i][4];
    $value = $$extra_name;
    //echo "Looking for $extra_name... value = " . $value . " ... type = " .
    // $extra_type . "<BR>\n";
    if ( strlen ( $$extra_name ) || $extra_type == $EXTRA_DATE ) {
      if ( $extra_type == $EXTRA_URL || $extra_type == $EXTRA_EMAIL ||
        $extra_type == $EXTRA_TEXT || $extra_type == $EXTRA_USER ||
        $extra_type == $EXTRA_MULTILINETEXT ||
        $extra_type == $EXTRA_SELECTLIST  ) {
        $sql = "INSERT INTO webcal_site_extras " .
          "( cal_id, cal_name, cal_type, cal_data ) VALUES ( " .
          "$id, '$extra_name', $extra_type, '$value' )";
      } else if ( $extra_type == $EXTRA_REMINDER ) {
        $remind = ( $value == "1" ? 1 : 0 );
        if ( ( $extra_arg2 & $EXTRA_REMINDER_WITH_DATE ) > 0 ) {
          $yname = $extra_name . "year";
          $mname = $extra_name . "month";
          $dname = $extra_name . "day";
          $edate = sprintf ( "%04d%02d%02d", $$yname, $$mname, $$dname );
          $sql = "INSERT INTO webcal_site_extras " .
            "( cal_id, cal_name, cal_type, cal_remind, cal_date ) VALUES ( " .
            "$id, '$extra_name', $extra_type, $remind, $edate )";
        } else if ( ( $extra_arg2 & $EXTRA_REMINDER_WITH_OFFSET ) > 0 ) {
          $dname = $extra_name . "_days";
          $hname = $extra_name . "_hours";
          $mname = $extra_name . "_minutes";
          $minutes = ( $$dname * 24 * 60 ) + ( $$hname * 60 ) + $$mname;
          $sql = "INSERT INTO webcal_site_extras " .
            "( cal_id, cal_name, cal_type, cal_remind, cal_data ) VALUES ( " .
            "$id, '$extra_name', $extra_type, $remind, '" . $minutes . "' )";
        } else {
          $sql = "INSERT INTO webcal_site_extras " .
          "( cal_id, cal_name, cal_type, cal_remind ) VALUES ( " .
          "$id, '$extra_name', $extra_type, $remind )";
        }
      } else if ( $extra_type == $EXTRA_DATE )  {
        $yname = $extra_name . "year";
        $mname = $extra_name . "month";
        $dname = $extra_name . "day";
        $edate = sprintf ( "%04d%02d%02d", $$yname, $$mname, $$dname );
        $sql = "INSERT INTO webcal_site_extras " .
          "( cal_id, cal_name, cal_type, cal_date ) VALUES ( " .
          "$id, '$extra_name', $extra_type, $edate )";
      }
    }
    if ( strlen ( $sql ) && empty ( $error ) ) {
      //echo "SQL: $sql<BR>\n";
      if ( ! dbi_query ( $sql ) )
        $error = translate("Database error") . ": " . dbi_error ();
    }
  }

  // clearly, we want to delete the old repeats, before inserting new...
  if ( empty ( $error ) ) {
    if ( ! dbi_query ( "DELETE FROM webcal_entry_repeats WHERE cal_id = $id") )
      $error = translate("Database error") . ": " . dbi_error ();
    // add repeating info
    if ( strlen ( $rpt_type ) && $rpt_type != 'none' ) {
      $freq = ( $rpt_freq ? $rpt_freq : 1 );
      if ( $rpt_end_use )
        $end = sprintf ( "%04d%02d%02d", $rpt_year, $rpt_month, $rpt_day );
      else
        $end = 'NULL';
      if ($rpt_type == 'weekly') {
        $days = ( $rpt_sun ? 'y' : 'n' )
          . ( $rpt_mon ? 'y' : 'n' )
          . ( $rpt_tue ? 'y' : 'n' )
          . ( $rpt_wed ? 'y' : 'n' )
          . ( $rpt_thu ? 'y' : 'n' )
          . ( $rpt_fri ? 'y' : 'n' )
          . ( $rpt_sat ? 'y' : 'n' );
      } else {
        $days = "nnnnnnn";
      }
  
      $sql = "INSERT INTO webcal_entry_repeats ( cal_id, " .
        "cal_type, cal_end, cal_days, cal_frequency ) VALUES " .
        "( $id, '$rpt_type', $end, '$days', $freq )";
      dbi_query ( $sql );
      $msg .= "<B>SQL:</B> $sql<P>";
    }
  }
}

#print $msg; exit;

// If we were editing this event, then go back to the last view (week, day,
// month).  If this is a new event, then go to the preferred view for
// the date range that this event was added to.
if ( empty ( $error ) ) {
  $last_view = get_last_view ();
  if ( strlen ( $last_view ) && ! $newevent ) {
    $url = $last_view;
  } else {
    $url = sprintf ( "%s.php?date=%04d%02d%02d",
      $STARTVIEW, $year, $month, $day );
  }
  if ($is_assistant)
     $url = $url . (strpos($url, "?") === false ? "?" : "&") . "user=$user";
  do_redirect ( $url );
}

?>
<HTML>
<HEAD><TITLE><?php etranslate($application_name)?></TITLE>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR; ?>" CLASS="defaulttext">

<?php if ( strlen ( $conflicts ) ) { ?>
<H2><FONT COLOR="<?php echo $H2COLOR;?>"><?php etranslate("Scheduling Conflict")?></H2></FONT>

<?php etranslate("Your suggested time of")?> <B>
<?php
  if ( $allday == "Y" )
    etranslate("All day event");
  else {
    $time = sprintf ( "%d%02d00", $hour, $minute );
    echo display_time ( $time );
    if ( $duration > 0 )
      echo "-" . display_time ( add_duration ( $time, $duration ) );
  }
?>
</B> <?php etranslate("conflicts with the following existing calendar entries")?>:
<UL>
<?php echo $conflicts; ?>
</UL>

<?php
// user can confirm conflicts
  echo "<form name=\"confirm\" method=\"post\">\n";
  while (list($xkey, $xval)=each($HTTP_POST_VARS)) {
    if (is_array($xval)) {
      $xkey.="[]";
      while (list($ykey, $yval)=each($xval)) {
        echo "<input type=\"hidden\" name=\"$xkey\" value=\"$yval\">\n";
      }
    } else {
      echo "<input type=\"hidden\" name=\"$xkey\" value=\"$xval\">\n";
    }
  }
?>
<table>
 <tr>
<?php
  // Allow them to override a conflict if server settings allow it
  if ( ! empty ( $allow_conflict_override ) &&
    $allow_conflict_override == "Y" ) {
    echo "<td><input type=\"submit\" name=\"confirm_conflicts\" " .
      "value=\"&nbsp;" . translate("Save") . "&nbsp;\"></td>\n";
  }
?>
   <td><input type="button" value="<?php etranslate("Cancel")?>" onClick="history.back()"><td>
 </tr>
</table>
</form>

<?php } else { ?>
<H2><FONT COLOR="<?php echo $H2COLOR;?>"><?php etranslate("Error")?></H2></FONT>
<BLOCKQUOTE>
<?php echo $error; ?>
</BLOCKQUOTE>

<?php } ?>


<?php include "includes/trailer.php"; ?>

</BODY>
</HTML>
