<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2007 OpenLink Software
 -
 -  This project is free software; you can redistribute it and/or modify it
 -  under the terms of the GNU General Public License as published by the
 -  Free Software Foundation; only version 2 of the License, dated June 1991.
 -
 -  This program is distributed in the hope that it will be useful, but
 -  WITHOUT ANY WARRANTY; without even the implied warranty of
 -  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 -  General Public License for more details.
 -
 -  You should have received a copy of the GNU General Public License along
 -  with this program; if not, write to the Free Software Foundation, Inc.,
 -  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 -
 -
-->
<html>
  <head>
    <title>Virtuoso Web Applications</title>
    <link rel="stylesheet" type="text/css" href="/ods/default.css" />
    <link rel="stylesheet" type="text/css" href="/ods/ods-bar.css" />
    <link rel="stylesheet" type="text/css" href="css/users.css" />
    <script type="text/javascript" src="js/oid_login.js"></script>
    <script type="text/javascript" src="js/users.js"></script>
    <script type="text/javascript">
      var toolkitPath="/ods/oat";
      var featureList = ["dom", "ajax2", "ws", "tab", "dimmer"];
    </script>
    <script type="text/javascript" src="/ods/oat/loader.js"></script>
  </head>
  <?php
    function selectList ($handle, $sql)
    {
      $_V = Array ();
      $_result = odbc_exec ($handle, $sql);
      $N = 1;
      while (odbc_fetch_row ($_result)) {
        $_S = odbc_result($_result, 1);
        if ($_S <> "0")
          $_V[$N] = $_S;
        $N++;
      }
      return $_V;
    }

    function outFormTitle ($form)
    {
      if ($form == "login")
        print "Login";
      if ($form == "register")
        print "Register";
      if ($form == "user")
        print "View Profile";
      if ($form == "profile")
        print "Edit Profile";
    }

    $_error = "";
    $_form = "login";
    if (isset ($_POST['form']))
      $_form = $_POST['form'];
    $_sid = $_POST['sid'];
    $_realm = $_POST['realm'];

    include 'users_dsn.php';
    $handle = odbc_connect ($_dsn, $_user, $_pass);
    if (!$handle)
    {
      $_error = "Failure to connect to DSN [$_dsn]:";
      odbc_errormsg();
    }
    else
    {
      if ($_form == "login")
      {
        if (isset ($_POST['lf_login']) && ($_POST['lf_login'] <> ""))
        {
          $_result = odbc_exec ($handle, sprintf ("select ODS_USER_LOGIN('%s', '%s')", $_POST['lf_uid'], $_POST['lf_password']));
          $_xml = new SimpleXMLElement(odbc_result ($_result, 1));
          if ($_xml->error->code <> 'OK')
          {
            $_error = $_xml->error->message;
          }
          else
          {
            $_sid = $_xml->session->sid;
            $_realm = $_xml->session->realm;
            $_form = "user";
          }
        }
        if (isset ($_POST['lf_register']) && ($_POST['lf_register'] <> ""))
          $_form = "register";
      }
      if ($_form == "register")
      {
        if (isset ($_POST['rf_signup']) && ($_POST['rf_signup'] <> ""))
        {
          if (strlen ($_POST['rf_uid']) == 0)
          {
            $_error = "Bad username. Please correct!";
          }
          else if (strlen ($_POST['rf_mail']) == 0)
          {
            $_error = "Bad mail. Please correct!";
          }
          else if (strlen ($_POST['rf_password']) == 0)
          {
            $_error = "Bad password. Please correct!";
          }
          else if ($_POST['rf_password'] <> $_POST['rf_password2'])
          {
            $_error = "Bad password. Please retype!";
          }
          else if (!isset ($_POST['rf_is_agreed']))
          {
            $_error = "You have not agreed to the Terms of Service!";
          }
          else
          {
            $_result = odbc_exec ($handle, sprintf ("select ODS_USER_REGISTER('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')",
                                                    $_POST['rf_uid'],
                                                    $_POST['rf_password'],
                                                    $_POST['rf_mail'],
                                                    $_POST['rf_identity'],
                                                    $_POST['rf_fullname'],
                                                    $_POST['rf_birthday'],
                                                    $_POST['rf_gender'],
                                                    $_POST['rf_postcode'],
                                                    $_POST['rf_country'],
                                                    $_POST['rf_tz'])
                                 );
            $_xml = new SimpleXMLElement(odbc_result ($_result, 1));
            if ($_xml->error->code <> 'OK')
            {
              $_error = $_xml->error->message;
            }
            else
            {
              $_sid = $_xml->session->sid;
              $_realm = $_xml->session->realm;
              $_form = "user";
            }
          }
        }
      }
      if ($_form == "user")
      {
        if (isset ($_POST['uf_profile']) && ($_POST['uf_profile'] <> ""))
          $_form = "profile";
      }
      if ($_form == "profile")
      {
        if (isset ($_POST['pf_update']) && ($_POST['pf_update'] <> ""))
        {
          $_S = "select ODS_USER_UPDATE('%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s')";
          $_result = odbc_exec ($handle, sprintf ($_S, $_sid,
                                                       $_realm,
                                                       $_POST['pf_mail'],
                                                       $_POST['pf_title'],
                                                       $_POST['pf_firstName'],
                                                       $_POST['pf_lastName'],
                                                       $_POST['pf_fullName'],
                                                       $_POST['pf_gender'],
                                                       $_POST['pf_birthdayDay'],
                                                       $_POST['pf_birthdayMonth'],
                                                       $_POST['pf_birthdayYear'],
                                                       $_POST['pf_icq'],
                                                       $_POST['pf_skype'],
                                                       $_POST['pf_yahoo'],
                                                       $_POST['pf_aim'],
                                                       $_POST['pf_msn'],
                                                       $_POST['pf_homeDefaultMapLocation'],
                                                       $_POST['pf_homeCountry'],
                                                       $_POST['pf_homeState'],
                                                       $_POST['pf_homeCity'],
                                                       $_POST['pf_homeCode'],
                                                       $_POST['pf_homeAddress1'],
                                                       $_POST['pf_homeAddress2'],
                                                       $_POST['pf_homeTimeZone'],
                                                       $_POST['pf_homeLatitude'],
                                                       $_POST['pf_homeLongitude'],
                                                       $_POST['pf_homePhone'],
                                                       $_POST['pf_homeMobile'],
                                                       $_POST['pf_businessIndustry'],
                                                       $_POST['pf_businessOrganization'],
                                                       $_POST['pf_businessHomePage'],
                                                       $_POST['pf_businessJob'],
                                                       $_POST['pf_businessCountry'],
                                                       $_POST['pf_businessState'],
                                                       $_POST['pf_businessCity'],
                                                       $_POST['pf_businessCode'],
                                                       $_POST['pf_businessAddress1'],
                                                       $_POST['pf_businessAddress2'],
                                                       $_POST['pf_businessTimeZone'],
                                                       $_POST['pf_businessLatitude'],
                                                       $_POST['pf_businessLongitude'],
                                                       $_POST['pf_businessPhone'],
                                                       $_POST['pf_businessMobile'],
                                                       $_POST['pf_businessRegNo'],
                                                       $_POST['pf_businessCareer'],
                                                       $_POST['pf_businessEmployees'],
                                                       $_POST['pf_businessVendor'],
                                                       $_POST['pf_businessService'],
                                                       $_POST['pf_businessOther'],
                                                       $_POST['pf_businessNetwork'],
                                                       $_POST['pf_businessResume'],
                                                       $_POST['pf_securitySecretQuestion'],
                                                       $_POST['pf_securitySecretAnswer'],
                                                       $_POST['pf_securitySiocLimit']));

          $_xml = new SimpleXMLElement(odbc_result ($_result, 1));
          if ($_xml->error->code <> 'OK')
          {
            $_error = $_xml->error->message;
            $_form = "login";
          }
          else
          {
            $_form = "user";
          }
        }
        if (isset ($_POST['pf_cancel']) && ($_POST['pf_cancel'] <> ""))
          $_form = "user";
        if ($_form == "profile")
        {
          $_result = odbc_exec ($handle, sprintf ("select ODS_USER_SELECT('%s', '%s', 0)", $_sid, $_realm));
          $_xml = new SimpleXMLElement(odbc_result ($_result, 1));
          if ($_xml->error->code <> 'OK')
          {
            $_error = $_xml->error->message;
            $_form = "login";
          }
          else
          {
            $_industries = selectList ($handle, "select WI_NAME from DB.DBA.WA_INDUSTRY order by WI_NAME");
            $_countries = selectList ($handle, "select WC_NAME from DB.DBA.WA_COUNTRY order by WC_NAME");
            $_homeStates = selectList ($handle, sprintf ("select WP_PROVINCE from DB.DBA.WA_PROVINCE where WP_COUNTRY = '%s' and WP_COUNTRY <> '' order by WP_PROVINCE", $_xml->user->homeCountry));
            $_businessStates = selectList ($handle, sprintf ("select WP_PROVINCE from DB.DBA.WA_PROVINCE where WP_COUNTRY = '%s' and WP_COUNTRY <> '' order by WP_PROVINCE", $_xml->user->businessCountry));
          }
        }
      }
      if ($_form == "user")
      {
        $_result = odbc_exec ($handle, sprintf ("select ODS_USER_SELECT('%s', '%s')", $_sid, $_realm));
        $_xml = new SimpleXMLElement(odbc_result ($_result, 1));
        if ($_xml->error->code <> 'OK')
        {
          $_error = $_xml->error->message;
          $_form = "login";
        }
      }
      if ($_form == "login")
      {
        $_sid = "";
        $_realm = "";
      }
      odbc_close($handle);
    }
  ?>
  <body>
    <form name="page_form" method="post" action="users.php">
      <input type="hidden" name="sid" id="sid" value="<?php print($_sid); ?>" />
      <input type="hidden" name="realm" id="realm" value="<?php print($_realm); ?>" />
      <input type="hidden" name="form" id="form" value="<?php print($_form); ?>" />
      <div id="ob">
        <div id="ob_left"><a href="/ods/?sid=<?php print($_sid); ?>&realm=<?php print($_realm); ?>">ODS Home</a> > <?php outFormTitle($_form); ?></div>
        <?php
          if ($_form <> 'login')
          {
        ?>
        <div id="ob_right"><a href="#" onclick="javascript: return logoutSubmit2();">Logout</a></div>
        <?php
          }
        ?>
      </div>
      <div id="MD">
        <table cellspacing="0">
          <tr>
            <td>
              <img style="margin: 60px;" src="/ods/images/odslogo_200.png" /><br />
              <div id="ob_links" style="display: none; margin-left: 60px;">
                <a id="ob_links_foaf" href="#">
                  <img border="0" alt="FOAF" src="/ods/images/foaf.gif"/>
                </a>
              </div>
            </td>
            <td>
              <?php
              if ($_form == 'login')
              {
              ?>
              <div id="lf" class="form">
                <?php
                  if ($_error <> '')
                  {
                    print "<div class=\"error\">".$_error."</div>";
                  }
                ?>
                <div class="header">
                  Enter your Member ID and Password
                </div>
                <table class="form" cellspacing="5">
                  <tr>
                    <th width="30%">
                      <label for="lf_uid">Member ID</label>
                    </th>
                    <td nowrap="nowrap">
                      <input type="text" name="lf_uid" value="" id="lf_uid" />
                    </td>
                  </tr>
                  <tr>
                    <th>
                      <label for="lf_password">Password</label>
                    </th>
                    <td nowrap="nowrap">
                      <input type="password" name="lf_password" value="" id="lf_password" />
                    </td>
                  </tr>
                  <tr>
                    <th>
                      or
                    </th>
                    <td nowrap="nowrap" />
                  </tr>
                  <tr>
                    <th>
                      <label for="lf_openID">Login with OpenID</label>
                    </th>
                    <td nowrap="nowrap">
                      <input type="text" name="lf_openID" value="" id="lf_openID" class="openID" size="40"/>
                    </td>
                  </tr>
                </table>
                <div class="footer">
                  <input type="submit" name="lf_login" value="Login" id="lf_login" onclick="javascript: return lfLoginSubmit2();" />
                  <input type="submit" name="lf_register" value="Sign Up" id="lf_register" />
                </div>
              </div>

              <?php
              }
              if ($_form == 'register')
              {
              ?>

              <div id="rf" class="form">
                <?php
                  if ($_error <> '')
                  {
                    print "<div class=\"error\">".$_error."</div>";
                  }
                ?>
                <div class="header">
                  Enter register data
                </div>
                <table class="form" cellspacing="5">
                  <tr>
                    <th width="30%">
                      <label for="rf_openID">Register with OpenID</label>
                    </th>
                    <td nowrap="nowrap">
                      <input type="text" name="rf_openID" value="<?php print($_POST['rf_openID']); ?>" id="rf_openID" class="openID" size="40"/>
                      <input type="button" name="rf_authenticate" value="Authenticate" id="rf_authenticate" onclick="javascript: return rfAuthenticateSubmit();"/>
                    </td>
                  </tr>
                  <tr>
                    <th />
                    <td nowrap="nowrap">
                      <input type="checkbox" name="rf_useOpenID" id="rf_useOpenID" onclick="javascript: rfAlternateLogin(this);" value="1" />
                      <label for="rf_useOpenID">Do not create password, I want to use my OpenID URL to login</label>
                    </td>
                  </tr>
                  <tr id="rf_login_1">
                    <th>
                      <label for="rf_uid">Login Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
                    </th>
                    <td nowrap="nowrap">
                      <input type="text" name="rf_uid" value="<?php print($_POST['rf_uid']); ?>" id="rf_uid" />
                    </td>
                  </tr>
                  <tr id="rf_login_2">
                    <th>
                      <label for="rf_mail">E-mail<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
                    </th>
                    <td nowrap="nowrap">
                      <input type="text" name="rf_mail" value="<?php print($_POST['rf_mail']); ?>" id="rf_mail" size="40"/>
                    </td>
                  </tr>
                  <tr id="rf_login_3">
                    <th>
                      <label for="rf_pwd">Password<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
                    </th>
                    <td nowrap="nowrap">
                      <input type="password" name="rf_password" value="" id="rf_password" />
                    </td>
                  </tr>
                  <tr id="rf_login_4">
                    <th>
                      <label for="rf_pwd2">Password (verify)<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
                    </th>
                    <td nowrap="nowrap">
                      <input type="password" name="rf_password2" value="" id="rf_password2" />
                    </td>
                  </tr>
                  <tr>
                    <td nowrap="nowrap" colspan="2">
                      <input type="checkbox" name="rf_is_agreed" value="1" id="rf_is_agreed"/><label for="rf_is_agreed">I agree to the <a href="/ods/terms.html" target="_blank">Terms of Service</a>.</label>
                    </td>
                  </tr>
                </table>
                <div class="footer" id="rf_login_5">
                  <input type="submit" name="rf_signup" value="Sign Up" />
                </div>
              </div>

              <?php
              }
              if ($_form == 'user')
              {
              ?>

              <div id="uf" class="form">
                <div class="header">
                  User profile
                </div>
                <table class="form" cellspacing="5">
                  <tr>
                    <th width="30%">
                      Login Name
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_name"><?php print($_xml->user->name); ?></span>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      E-mail
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_mail"><?php print($_xml->user->mail); ?></span>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      Title
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_title"><?php print($_xml->user->title); ?></span>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      First Name
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_firstName"><?php print($_xml->user->firstName); ?></span>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      Last Name
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_lastName"><?php print($_xml->user->lastName); ?></span>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      Full Name
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_fullName"><?php print($_xml->user->fullName); ?></span>
                    </td>
                  </tr>
                </table>
                <div class="footer">
                  <input type="submit" name="uf_profile" value="Edit Profile" />
                </div>
              </div>

              <?php
              }
              if ($_form == 'profile')
              {
              ?>

              <div id="pf" class="form" style="width: 800px;">
                <?php
                  if ($_error <> '')
                  {
                    print "<div class=\"error\">".$_error."</div>";
                  }
                ?>
                <div class="header">
                  Update user profile
                </div>
                <ul id="tabs">
                  <li id="tab_0" title="Personal">Personal</li>
                  <li id="tab_1" title="Contact">Contact</li>
                  <li id="tab_2" title="Home">Home</li>
                  <li id="tab_3" title="Business">Business</li>
                  <li id="tab_4" title="Security">Security</li>
                </ul>
                <div style="min-height: 180px; border: 1px solid #aaa; margin: -13px 5px 5px 5px;">
                  <div id="content"></div>

                  <div id="page_0">
                    <table class="form" cellspacing="5">
                      <tr>
                        <th width="30%" nowrap="nowrap">
                          <label for="pf_title">Title</label>
                        </th>
                        <td>
                          <select name="pf_title" id="pf_title">
                            <option></option>s
                            <?php
                              $X = array ("Mr", "Mrs", "Dr", "Ms");
                              for ($N = 0; $N < count ($X); $N += 1)
                                print sprintf("<option %s>%s</option>", (($X[$N] == $_xml->user->title) ? "selected=\"selected\"": ""), $X[$N]);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_firstName">First Name</label>
                        </th>
                        <td>
                          <input type="text" name="pf_firstName" value="<?php print($_xml->user->firstName); ?>" id="pf_firstName" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_lastName">Last Name</label>
                        </th>
                        <td>
                          <input type="text" name="pf_lastName" value="<?php print($_xml->user->lastName); ?>" id="pf_lastName" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_fullName">Full Name</label>
                        </th>
                        <td>
                          <input type="text" name="pf_fullName" value="<?php print($_xml->user->fullName); ?>" id="pf_fullName" size="60" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_mail">E-mail</label>
                        </th>
                        <td>
                          <input type="text" name="pf_mail" value="<?php print($_xml->user->mail); ?>" id="pf_mail" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_gender">Gender</label>
                        </th>
                        <td>
                          <select name="pf_gender" value="" id="pf_gender">
                            <option></option>
                            <?php
                              $X = array ("Male", "Female");
                              for ($N = 0; $N < count ($X); $N += 1)
                                print sprintf("<option value=\"%s\" %s>%s</option>", strtolower($X[$N]), ((strtolower($X[$N]) == $_xml->user->gender) ? "selected=\"selected\"": ""), $X[$N]);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_birthday">Birthday</label>
                        </th>
                        <td>
                          <select name="pf_birthdayDay" id="pf_birthdayDay">
                            <option></option>
                            <?php
                              for ($N = 1; $N <= 31; $N += 1)
                                print sprintf("<option value=\"%d\" %s>%d</option>", $N, (($N == $_xml->user->birthdayDay) ? "selected=\"selected\"": ""), $N);
                            ?>
                          </select>
        		              -
                          <select name="pf_birthdayMonth" id="pf_birthdayMonth">
                            <option></option>
                            <?php
                              $X = array ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
                              for ($N = 1; $N <= 12; $N += 1)
                                print sprintf("<option value=\"%d\" %s>%s</option>", $N, (($N == $_xml->user->birthdayMonth) ? "selected=\"selected\"": ""), $X[$N-1]);
                            ?>
                          </select>
                          -
                          <select name="pf_birthdayYear" id="pf_birthdayYear">
                            <option></option>
                            <?php
                              for ($N = 1950; $N <= 2003; $N += 1)
                                print sprintf("<option value=\"%d\" %s>%d</option>", $N, (($N == $_xml->user->birthdayYear) ? "selected=\"selected\"": ""), $N);
                            ?>
                          </select>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div id="page_1" style="display:none;">
                    <table class="form" cellspacing="5">
                      <tr>
                        <th width="30%">
                          <label for="pf_icq">ICQ</label>
                        </th>
                        <td>
                          <input type="text" name="pf_icq" value="<?php print($_xml->user->icq); ?>" id="pf_icq" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_skype">Skype</label>
                        </th>
                        <td>
                          <input type="text" name="pf_skype" value="<?php print($_xml->user->skype); ?>" id="pf_skype" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_yahoo">Yahoo</label>
                        </th>
                        <td>
                          <input type="text" name="pf_yahoo" value="<?php print($_xml->user->yahoo); ?>" id="pf_yahoo" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_aim">AIM</label>
                        </th>
                        <td>
                          <input type="text" name="pf_aim" value="<?php print($_xml->user->aim); ?>" id="pf_aim" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_msn">MSN</label>
                        </th>
                        <td>
                          <input type="text" name="pf_msn" value="<?php print($_xml->user->msn); ?>" id="pf_msn" size="40" />
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div id="page_2" style="display:none;">
                    <table class="form" cellspacing="5">
                      <tr>
                        <th width="30%">
                          <label for="pf_homeCountry">Country</label>
                        </th>
                        <td nowrap="nowrap">
                          <select name="pf_homeCountry" id="pf_homeCountry" onchange="javascript: return updateState('pf_homeCountry', 'pf_homeState');">
                            <option></option>
                            <?php
                              for ($N = 1; $N <= count ($_countries); $N += 1)
                              {
                                $_S = "";
                                if ($_countries[$N] == $_xml->user->homeCountry)
                                  $_S = "selected=\"selected\"";
                                print sprintf("<option %s>%s</option>", $_S, $_countries[$N]);
                              }
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_homeState">State/Province</label>
                        </th>
                        <td>
                          <select name="pf_homeState" id="pf_homeState">
                            <option></option>
                            <?php
                              for ($N = 1; $N <= count ($_homeStates); $N += 1)
                              {
                                if ($_homeStates[$N] <> '') {
                                  $_S = "";
                                  if ($_homeStates[$N] == $_xml->user->homeState)
                                    $_S = "selected=\"selected\"";
                                  print sprintf("<option %s>%s</option>", $_S, $_homeStates[$N]);
                                }
                              }
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_homeCity">City/Town</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homeCity" value="<?php print($_xml->user->homeCity); ?>" id="pf_homeCity" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_homeCode">Zip/Postal Code</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homeCode" value="<?php print($_xml->user->homeCode); ?>" id="pf_homeCode" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeAddress1">Address1</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homeAddress1" value="<?php print($_xml->user->homeAddress1); ?>" id="pf_homeAddress1" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeAddress2">Address2</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homeAddress2" value="<?php print($_xml->user->homeAddress2); ?>" id="pf_homeAddress2" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_homeTimeZone">Time-Zone</label>
                        </th>
                        <td>
                          <select name="pf_homeTimeZone" id="pf_homeTimeZone">
                            <?php
                              for ($N = -12; $N <= 12; $N += 1)
                                print sprintf("<option value=\"%d\" %s>GMT %d:00</option>", $N, (($N == $_xml->user->homeTimeZone) ? "selected=\"selected\"": ""), $N);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_homeLatitude">Latitude</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homeLatitude" value="<?php print($_xml->user->homeLatitude); ?>" id="pf_homeLatitude" />
                          <input type="button" name="pf_setHomeLocation" value="Set From Address" onclick="javascript: pfGetLocation('home');" />
                          <input type="checkbox" name="pf_homeDefaultMapLocation" id="pf_homeDefaultMapLocation" onclick="javascript: setDefaultMapLocation('home', 'business');" />
                          <label for="pf_homeDefaultMapLocation">Default Map Location</label>
                        <td>
                      <tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_homeLongitude">Longitude</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homeLongitude" value="<?php print($_xml->user->homeLongitude); ?>" id="pf_homeLongitude" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_homePhone">Phone</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homePhone" value="<?php print($_xml->user->homePhone); ?>" id="pf_homePhone" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_homeMobile">Mobile</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homeMobile" value="<?php print($_xml->user->homeMobile); ?>" id="pf_homeMobile" />
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div id="page_3" style="display:none;">
                    <table class="form" cellspacing="5">
                      <tr>
                        <th width="30%">
                          <label for="pf_businessIndustry">Industry</label>
                        </th>
                        <td>
                          <select name="pf_businessIndustry" id="pf_businessIndustry">
                            <option></option>
                            <?php
                              for ($N = 1; $N <= count ($_industries); $N += 1)
                              {
                                if ($_industries[$N] <> '') {
                                  $_S = "";
                                  if ($_industries[$N] == $_xml->user->businessIndustry)
                                    $_S = "selected=\"selected\"";
                                  print sprintf("<option %s>%s</option>", $_S, $_industries[$N]);
                                }
                              }
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessOrganization">Organization</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessOrganization" value="<?php print($_xml->user->businessOrganization); ?>" id="pf_businessOrganization" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessHomePage">Organization Home Page</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businessHomePage" value="<?php print($_xml->user->businessHomePage); ?>" id="pf_businessNetwork" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessJob">Job Title</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessJob" value="<?php print($_xml->user->businessJob); ?>" id="pf_businessJob" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessCountry">Country</label>
                        </th>
                        <td>
                          <select name="pf_businessCountry" id="pf_businessCountry" onchange="javascript: return updateState('pf_businessCountry', 'pf_businessState');">
                            <option></option>
                            <?php
                              for ($N = 1; $N <= count ($_countries); $N += 1)
                              {
                                $_S = "";
                                if ($_countries[$N] == $_xml->user->businessCountry)
                                  $_S = "selected=\"selected\"";
                                print sprintf("<option %s>%s</option>", $_S, $_countries[$N]);
                              }
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessState">State/Province</label>
                        </th>
                        <td>
                          <select name="pf_businessState" id="pf_businessState">
                            <option></option>
                            <?php
                              for ($N = 1; $N <= count ($_businessStates); $N += 1)
                              {
                                if ($_businessStates[$N] <> '')
                                {
                                  $_S = "";
                                  if ($_businessStates[$N] == $_xml->user->businessState)
                                    $_S = "selected=\"selected\"";
                                  print sprintf("<option %s>%s</option>", $_S, $_businessStates[$N]);
                                }
                              }
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessCity">City/Town</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessCity" value="<?php print($_xml->user->businessCity); ?>" id="pf_businessCity" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessCode">Zip/Postal Code</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessCode" value="<?php print($_xml->user->businessCode); ?>" id="pf_businessCode" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessAddress1">Address1</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessAddress1" value="<?php print($_xml->user->businessAddress1); ?>" id="pf_businessAddress1" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessAddress2">Address2</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessAddress2" value="<?php print($_xml->user->businessAddress2); ?>" id="pf_businessAddress2" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessTimeZone">Time-Zone</label>
                        </th>
                        <td>
                          <select name="pf_businessTimeZone" id="pf_businessTimeZone">
                            <?php
                              for ($N = -12; $N <= 12; $N += 1)
                                print sprintf("<option value=\"%d\" %s>GMT %d:00</option>", $N, (($N == $_xml->user->businessTimeZone) ? "selected=\"selected\"": ""), $N);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessLatitude">Latitude</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessLatitude" value="<?php print($_xml->user->businessLatitude); ?>" id="pf_businessLatitude" />
                          <input type="button" name="pf_setBusinessLocation" value="Set From Address" onclick="javascript: pfGetLocation('business');" />
                          <input type="checkbox" name="pf_businessDefaultMapLocation" id="pf_businessDefaultMapLocation" onclick="javascript: setDefaultMapLocation('business', 'home');" />
                          <label for="pf_businessDefaultMapLocation">Default Map Location</label>
                        <td>
                      <tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessLongitude">Longitude</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessLongitude" value="<?php print($_xml->user->businessLongitude); ?>" id="pf_businessLongitude" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessPhone">Phone</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessPhone" value="<?php print($_xml->user->businessPhone); ?>" id="pf_businessPhone" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessMobile">Mobile</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessMobile" value="<?php print($_xml->user->businessMobile); ?>" id="pf_businessMobile" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessRegNo">VAT Reg number (EU only) or Tax ID</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessRegNo" value="<?php print($_xml->user->businessRegNo); ?>" id="pf_businessRegNo" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessCareer">Career / Organization Status</label>
                        </th>
                        <td>
                          <select name="pf_businessCareer" id="pf_businessCareer">
                            <option />
                            <?php
                              $X = array ("Job seeker-Permanent", "Job seeker-Temporary", "Job seeker-Temp/perm", "Employed-Unavailable", "Employer", "Agency", "Resourcing supplier");
                              for ($N = 0; $N < count ($X); $N += 1)
                                print sprintf("<option %s>%s</option>", (($X[$N] == $_xml->user->businessCareer) ? "selected=\"selected\"": ""), $X[$N]);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessEmployees">No. of Employees</label>
                        </th>
                        <td>
                          <select name="pf_businessEmployees" id="pf_businessEmployees">
                            <option />
                            <?php
                              $X = array ("1-100", "101-250", "251-500", "501-1000", ">1000");
                              for ($N = 0; $N < count ($X); $N += 1)
                                print sprintf("<option %s>%s</option>", (($X[$N] == $_xml->user->businessEmployees) ? "selected=\"selected\"": ""), $X[$N]);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessVendor">Are you a technology vendor</label>
                        </th>
                        <td>
                          <select name="pf_businessVendor" id="pf_businessVendor">
                            <option />
                            <?php
                              $X = array ("Not a Vendor", "Vendor", "VAR", "Consultancy");
                              for ($N = 0; $N < count ($X); $N += 1)
                                print sprintf("<option %s>%s</option>", (($X[$N] == $_xml->user->businessVendor) ? "selected=\"selected\"": ""), $X[$N]);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessService">If so, what technology and/or service do you provide?</label>
                        </th>
                        <td>
                          <select name="pf_businessService" id="pf_businessService">
                            <option />
                            <?php
                              $X = array ("Enterprise Data Integration", "Business Process Management", "Other");
                              for ($N = 0; $N < count ($X); $N += 1)
                                print sprintf("<option %s>%s</option>", (($X[$N] == $_xml->user->businessService) ? "selected=\"selected\"": ""), $X[$N]);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessOther">Other Technology service</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessOther" value="<?php print($_xml->user->businessOther); ?>" id="pf_businessOther" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessNetwork">Importance of OpenLink Network for you</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessNetwork" value="<?php print($_xml->user->businessNetwork); ?>" id="pf_businessNetwork" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessResume">Resume</label>
                        </th>
                        <td>
                          <textarea name="pf_businessResume" id="pf_businessResume" cols="50"><?php print($_xml->user->businessResume); ?></textarea>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div id="page_4" style="display:none;">
                    <table class="form" cellspacing="5">
                      <tr>
                        <td align="center" colspan="2">
                          <span id="pf_change_txt"></span>
                        </td>
                      </tr>
                      <tr>
                        <th style="text-align: left; background-color: #F6F6F6;" colspan="2">
                          Password Settings
                        </th>
                      </tr>
                      <tr>
                        <th width="30%" nowrap="nowrap">
                          <label for="pf_oldPassword">Old Password</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="password" name="pf_oldPassword" value="" id="pf_oldPassword" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_newPassword">New Password</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="password" name="pf_newPassword" value="" id="pf_newPassword" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_password">Repeat Password</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="password" name="pf_newPassword2" value="" id="pf_newPassword2" />
                          <input type="button" name="pf_change" value="Change" onclick="javascript: return pfChangeSubmit();" />
                        </td>
                      </tr>
                      <tr>
                        <th style="text-align: left; background-color: #F6F6F6;" colspan="2">
                          Password Recovery
                        </th>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_securitySecretQuestion">Secret Question</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_securitySecretQuestion" value="<?php print($_xml->user->securitySecretQuestion); ?>" id="pf_securitySecretQuestion" size="40" />
                          <select name="pf_secretQuestion_select" value="" id="pf_secretQuestion_select" onchange="setSecretQuestion ();">
                            <option value="">~pick predefined~</option>
                            <option value="First Car">First Car</option>
                            <option value="Mothers Maiden Name">Mothers Maiden Name</option>
                            <option value="Favorite Pet">Favorite Pet</option>
                            <option value="Favorite Sports Team">Favorite Sports Team</option>
                          </select>
                          <?php print($_xml->user->securitySecretQuestion); ?>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_securitySecretAnswer">Secret Answer</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_securitySecretAnswer" value="<?php print($_xml->user->securitySecretAnswer); ?>" id="pf_securitySecretAnswer" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th style="text-align: left; background-color: #F6F6F6;" colspan="2">
                          Applications restrictions
                        </th>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_securitySiocLimit">SIOC Query Result Limit  </label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_securitySiocLimit" value="<?php print($_xml->user->securitySiocLimit); ?>" id="pf_securitySiocLimit" />
                        </td>
                      </tr>
                    </table>
                  </div>

                </div>
                <div class="footer">
                  <input type="submit" name="pf_update" value="Update" />
                  <input type="submit" name="pf_cancel" value="Cancel" />
                </div>
              </div>
              <?php
              }
              ?>
            </td>
          </tr>
        </table>
      </div>
    </form>
    <div id="FT">
      <div id="FT_L">
        <a href="http://www.openlinksw.com/virtuoso"><img alt="Powered by OpenLink Virtuoso Universal Server" src="/ods/images/virt_power_no_border.png" border="0" /></a>
      </div>
      <div id="FT_R">
        <a href="/ods/faq.html">FAQ</a> | <a href="/ods/privacy.html">Privacy</a> | <a href="/ods/rabuse.vspx">Report Abuse</a>
        <div>
          Copyright &copy; 1999-2009 OpenLink Software
        </div>
      </div>
     </div>
  </body>
</html>
