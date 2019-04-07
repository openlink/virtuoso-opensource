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
include "includes/validate.php";
include "includes/connect.php";

load_global_settings ();
load_user_preferences ();
load_user_layers ();

include "includes/translate.php";

$my_event = false;
$can_edit = false;

// First, check to see if this user should be able to delete this event.
if ( $id > 0 ) {
  // first see who has access to edit this entry
  if ( $is_admin || $is_assistant ) {
    $can_edit = true;
  } else if ( $readonly == "Y" ) {
    $can_edit = false;
  } else {
    $can_edit = false;
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

// See who owns the event.  Owner should be able to delete.
$res = dbi_query (
  "SELECT cal_create_by FROM webcal_entry WHERE cal_id = $id" );
if ( $res ) {
  $row = dbi_fetch_row ( $res );
  $owner = $row[0];
  dbi_free_result ( $res );
  if ( $owner == $login || $is_assistant ) {
    $my_event = true;
    $can_edit = true;
  }
}

// Is this a repeating event?
$event_repeats = false;
$res = dbi_query ( "SELECT COUNT(cal_id) FROM webcal_entry_repeats " .
  "WHERE cal_id = $id" );
if ( $res ) {
  $row = dbi_fetch_row ( $res );
  if ( $row[0] > 0 )
    $event_repeats = true;
  dbi_free_result ( $res );
}
$override_repeat = false;
if ( ! empty ( $date ) && $event_repeats && ! empty ( $override ) ) {
  $override_repeat = true;
}

if ( ! $can_edit ) {
  $error = translate ( "You are not authorized" );
}

if ( $id > 0 && empty ( $error ) ) {
  if ( ! empty ( $date ) ) {
    $thisdate = $date;
  } else {
    $res = dbi_query ( "SELECT cal_date FROM webcal_entry WHERE cal_id = $id" );
    if ( $res ) {
      // date format is 19991231
      $row = dbi_fetch_row ( $res );
      $thisdate = $row[0];
    }
  }

  // Only allow delete of webcal_entry & webcal_entry_repeats
  // if owner or admin, not participant.
  if ( $is_admin || $my_event ) {

    // Email participants that the event was deleted
    // First, get list of participants (with status Approved or
    // Waiting on approval).
    $sql = "SELECT cal_login FROM webcal_entry_user WHERE cal_id = $id " .
      "AND cal_status IN ('A','W')";
    $res = dbi_query ( $sql );
    $partlogin = array ();
    if ( $res ) {
      while ( $row = dbi_fetch_row ( $res ) ) {
        if ( $row[0] != $login )
	  $partlogin[] = $row[0];
      }
      dbi_free_result($res);
    }

    // Get event name
    $sql = "SELECT cal_name FROM webcal_entry WHERE cal_id = $id";
    $res = dbi_query($sql);
    if ( $res ) {
      $row = dbi_fetch_row ( $res );
      $name = $row[0];
      dbi_free_result ( $res );
    }
  
  
    // TODO: switch transation language based on user so each user
    // gets message in their selected language.
    for ( $i = 0; $i < count ( $partlogin ); $i++ ) {
      // Log the deletion
      activity_log ( $id, $login, $partlogin[$i], $LOG_DELETE, "" );

      $do_send = get_pref_setting ( $partlogin[$i], "EMAIL_EVENT_DELETED" );
      user_load_variables ( $partlogin[$i], "temp" );
      if ( $partlogin[$i] != $login && $do_send == "Y" &&
        strlen ( $tempemail ) && $send_email != "N" ) {
        $msg = translate("Hello") . ", " . $tempfullname . ".\n\n" .
          translate("An appointment has been canceled for you by") .
          " " . $login_fullname .  ". " .
          translate("The subject was") . " \"" . $name . "\"\n\n";
        if ( strlen ( $login_email ) )
          $extra_hdrs = "From: $login_email\nX-Mailer: " .
            translate($application_name);
        else
          $extra_hdrs = "From: $email_fallback_from\nX-Mailer: " .
            translate($application_name);
        mail ( $tempemail,
          translate($application_name) . " " .
	  translate("Notification") . ": " . $name,
          html_to_8bits ($msg), $extra_hdrs );
      }
    }

    // Instead of deleting from the database... mark it as deleted
    // by setting the status for each participant to "D" (instead
    // of "A"/Accepted, "W"/Waiting-on-approval or "R"/Rejected)
    if ( $override_repeat ) {
      dbi_query ( "INSERT INTO webcal_entry_repeats_not ( cal_id, cal_date ) " .
        "VALUES ( $id, $date )" );
      // Should we log this to the activity log???
    } else {
      // If it's a repeating event, delete any event exceptions
      // that were entered.
      if ( $event_repeats ) {
	$res = dbi_query ( "SELECT cal_id FROM webcal_entry " .
	  "WHERE cal_group_id = $id" );
        if ( $res ) {
	  $ex_events = array ();
          while ( $row = dbi_fetch_row ( $res ) ) {
	    $ex_events[] = $row[0];
	  }
          dbi_free_result ( $res );
          for ( $i = 0; $i < count ( $ex_events ); $i++ ) {
	    $res = dbi_query ( "SELECT cal_login FROM " .
              "webcal_entry_user WHERE cal_id = $ex_events[$i]" );
            if ( $res ) {
              $delusers = array ();
              while ( $row = dbi_fetch_row ( $res ) ) {
                $delusers[] = $row[0];
              }
              dbi_free_result ( $res );
              for ( $j = 0; $j < count ( $delusers ); $j++ ) {
                // Log the deletion
	        activity_log ( $ex_events[$i], $login, $delusers[$j],
                  $LOG_DELETE, "" );
                dbi_query ( "UPDATE webcal_entry_user SET cal_status = 'D' " .
	          "WHERE cal_id = $ex_events[$i] " .
                  "AND cal_login = '$delusers[$j]'" );
              }
            }
          }
	}
      }

      // Now, mark event as deleted for all users.
      dbi_query ( "UPDATE webcal_entry_user SET cal_status = 'D' " .
        "WHERE cal_id = $id" );
    }
  } else {
    // Not the owner of the event and are not the admin.
    // Just delete the event from this user's calendar.
    // We could just set the status to 'D' instead of deleting.
    // (but we would need to make some changes to edit_entry_handler.php
    // to accomodate this).
    dbi_query ( "DELETE FROM webcal_entry_user " .
      "WHERE cal_id = $id AND cal_login = '$login'" );
    activity_log ( $id, $login, $login, $LOG_REJECT, "" );
  }
}

if ( strlen ( get_last_view() ) ) {
  $url = get_last_view();
} else {
  $redir = "";
  if ( $thisdate != "" )
    $redir = "?date=$thisdate";
  if ( $user != "" ) {
    if ( $redir != "" )
      $redir .= "&";
    $redir .= "user=$user";
  }
  $url = "$STARTVIEW.php" . $redir;
}
if ( empty ( $error ) ) {
  if ($is_assistant)
     $url = $url . (strpos($url, "?") === false ? "?" : "&") . "user=$user";
  do_redirect ( $url );
  exit;
}
?>
<HTML>
<HEAD><TITLE><?php etranslate($application_name)?></TITLE>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR; ?>" CLASS="defaulttext">

<H2><FONT COLOR="<?php echo $H2COLOR;?>"><?php etranslate("Error")?></H2></FONT>
<BLOCKQUOTE>
<?php echo $error; ?>
</BLOCKQUOTE>

<?php include "includes/trailer.php"; ?>

</BODY>
</HTML>
