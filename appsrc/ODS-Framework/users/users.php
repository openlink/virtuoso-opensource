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
    <link rel="stylesheet" type="text/css" href="/ods/users/css/users.css" />
    <script type="text/javascript" src="/ods/users/js/oid_login.js"></script>
    <script type="text/javascript" src="/ods/users/js/users.js"></script>
    <script type="text/javascript" src="/ods/common.js"></script>
    <script type="text/javascript" src="/ods/CalendarPopup.js"></script>
    <script type="text/javascript">
      // OAT
      var toolkitPath="/ods/oat";
      var featureList = ["dom", "ajax2", "ws", "tab", "json", "dimmer", "combolist"];
    </script>
    <script type="text/javascript" src="/ods/oat/loader.js"></script>
    <script type="text/javascript">
      // publics
      var cPopup;
      function myInit()
      {
        // CalendarPopup
        if ($("cDiv"))
        {
          cPopup = new CalendarPopup("cDiv");
          cPopup.isShowYearNavigation = true;
        }

        OAT.Preferences.imagePath = "/ods/images/oat/";
        OAT.Preferences.stylePath = "/ods/oat/styles/";
        OAT.Preferences.showAjax = false;

        if ($('pf'))
        {
          var tab = new OAT.Tab ("content");
          tab.add ("tab_0", "page_0");
          tab.add ("tab_1", "page_1");
          tab.add ("tab_2", "page_2");
          tab.add ("tab_3", "page_3");
          tab.add ("tab_4", "page_4");
          tab.go (0);
        }
      }
      OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, myInit);
    </script>
  </head>
  <?php
    function selectList ($list, $param)
    {
      $V = Array ();
      $url = sprintf ("%s/lookup.list?key=%s&param=%s", apiURL(), urlencode ($list), urlencode ($param));
      $result = file_get_contents ($url);
      $xml = new SimpleXMLElement ($result);
      $items = $xml->xpath("/items/item");
      $N = 1;
      foreach ($items as $S)
      {
        if ($S <> "0")
          $V[$N] = $S;
        $N++;
      }
      return $V;
    }

    function outFormTitle ($form)
    {
      if ($form == "login")
        print "Login";
      if ($form == "user")
        print "View Profile";
      if ($form == "profile")
        print "Edit Profile";
    }

    function apiURL()
    {
      $pageURL = $_SERVER['HTTPS'] == 'on' ? 'https://' : 'http://';
      $pageURL .= $_SERVER['SERVER_PORT'] != '80' ? $_SERVER["SERVER_NAME"].":".$_SERVER["SERVER_PORT"] : $_SERVER['SERVER_NAME'];
      return $pageURL.'/ods/api';
    }

    $_error = "";
    $_form = "login";
    if (isset ($_POST['form']))
      $_form = $_POST['form'];
    $_sid = $_POST['sid'];
    $_realm = "wa";

      if ($_form == "login")
      {
        if (isset ($_POST['lf_login']) && ($_POST['lf_login'] <> ""))
        {
        $_url = sprintf ("%s/user.authenticate?user_name=%s&password_hash=%s", apiURL(), $_POST['lf_uid'], sha1($_POST['lf_uid'].$_POST['lf_password']));
        $_result = file_get_contents($_url);
        if (substr_count($_result, "<failed>") <> 0)
        {
          $_xml = simplexml_load_string($_result);
          $_error = $_xml->failed->message;;
        } else {
          $_sid = $_result;
            $_form = "user";
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
        $_url = apiURL().                   "/user.update.fields".
                "?sid=".                    $_sid.
                "&realm=".                  $_realm.
                "&mail=".                   urlencode ($_POST['pf_mail']).
                "&title=".                  urlencode ($_POST['pf_title']).
                "&firstName=".              urlencode ($_POST['pf_firstName']).
                "&lastName=".               urlencode ($_POST['pf_lastName']).
                "&fullName=".               urlencode ($_POST['pf_fullName']).
                "&gender=".                 urlencode ($_POST['pf_gender']).
                "&birthday=".               urlencode ($_POST['pf_birthday']).
                "&icq=".                    urlencode ($_POST['pf_icq']).
                "&skype=".                  urlencode ($_POST['pf_skype']).
                "&yahoo=".                  urlencode ($_POST['pf_yahoo']).
                "&aim=".                    urlencode ($_POST['pf_aim']).
                "&msn=".                    urlencode ($_POST['pf_msn']).
                "&homeDefaultMapLocation=". urlencode ($_POST['pf_homeDefaultMapLocation']).
                "&homeCountry=".            urlencode ($_POST['pf_homecountry']).
                "&homeState=".              urlencode ($_POST['pf_homestate']).
                "&homeCity=".               urlencode ($_POST['pf_homecity']).
                "&homeCode=".               urlencode ($_POST['pf_homecode']).
                "&homeAddress1=".           urlencode ($_POST['pf_homeaddress1']).
                "&homeAddress2=".           urlencode ($_POST['pf_homeaddress2']).
                "&homeTimezone=".           urlencode ($_POST['pf_homeTimezone']).
                "&homeLatitude=".           urlencode ($_POST['pf_homelat']).
                "&homeLongitude=".          urlencode ($_POST['pf_homelng']).
                "&homePhone=".              urlencode ($_POST['pf_homePhone']).
                "&homeMobile=".             urlencode ($_POST['pf_homeMobile']).
                "&businessIndustry=".       urlencode ($_POST['pf_businessIndustry']).
                "&businessOrganization=".   urlencode ($_POST['pf_businessOrganization']).
                "&businessHomePage=".       urlencode ($_POST['pf_businessHomePage']).
                "&businessJob=".            urlencode ($_POST['pf_businessJob']).
                "&businessCountry=".        urlencode ($_POST['pf_businesscountry']).
                "&businessState=".          urlencode ($_POST['pf_businessstate']).
                "&businessCity=".           urlencode ($_POST['pf_businesscity']).
                "&businessCode=".           urlencode ($_POST['pf_businesscode']).
                "&businessAddress1=".       urlencode ($_POST['pf_businessaddress1']).
                "&businessAddress2=".       urlencode ($_POST['pf_businessaddress2']).
                "&businessTimezone=".       urlencode ($_POST['pf_businessTimezone']).
                "&businessLatitude=".       urlencode ($_POST['pf_businesslat']).
                "&businessLongitude=".      urlencode ($_POST['pf_businesslng']).
                "&businessPhone=".          urlencode ($_POST['pf_businessPhone']).
                "&businessMobile=".         urlencode ($_POST['pf_businessMobile']).
                "&businessRegNo=".          urlencode ($_POST['pf_businessRegNo']).
                "&businessCareer=".         urlencode ($_POST['pf_businessCareer']).
                "&businessEmployees=".      urlencode ($_POST['pf_businessEmployees']).
                "&businessVendor=".         urlencode ($_POST['pf_businessVendor']).
                "&businessService=".        urlencode ($_POST['pf_businessService']).
                "&businessOther=".          urlencode ($_POST['pf_businessOther']).
                "&businessNetwork=".        urlencode ($_POST['pf_businessNetwork']).
                "&businessResume=".         urlencode ($_POST['pf_businessResume']).
                "&securitySecretQuestion=". urlencode ($_POST['pf_securitySecretQuestion']).
                "&securitySecretAnswer=".   urlencode ($_POST['pf_securitySecretAnswer']).
                "&securitySiocLimit=".      urlencode ($_POST['pf_securitySiocLimit']);
        $_result = file_get_contents($_url);
        if (substr_count($_result, "<failed>") <> 0)
          {
          $_xml = simplexml_load_string($_result);
          $_error = $_xml->failed->message;;
            $_form = "login";
        } else {
          $_form = "user";
          }
      }
      else if (isset ($_POST['pf_cancel']) && ($_POST['pf_cancel'] <> ""))
          {
            $_form = "user";
          }
        }

    if (($_form == "user") || ($_form == "profile"))
        {
      $_url = sprintf ("%s/user.info?sid=%s&realm=%s", apiURL(), $_sid, $_realm);
      if ($_form == "profile")
        $_url = $_url."&short=1";
      $_result = file_get_contents($_url);
      $_xml = simplexml_load_string($_result);
      if ($_xml->failed->message)
          {
        $_error = $_xml->failed->message;
            $_form = "login";
          }
      else if ($_form == "profile")
        {
        $_industries = selectList ('Industry', '');
        $_countries = selectList ('Country', '');
        }
      }

      if ($_form == "login")
      {
        $_sid = "";
        $_realm = "";
      }
  ?>
  <body>
    <div id="cDiv" style="position: absolute; visibility: hidden; background-color: white; z-index: 10;">
    </div>
    <form name="page_form" method="post" action="users.php">
      <input type="hidden" name="sid" id="sid" value="<?php print($_sid); ?>" />
      <input type="hidden" name="realm" id="realm" value="<?php print($_realm); ?>" />
      <input type="hidden" name="form" id="form" value="<?php print($_form); ?>" />
      <div id="ob">
        <div id="ob_left"><a href="/ods/?sid=<?php print($_sid); ?>&amp;realm=<?php print($_realm); ?>">ODS Home</a> > <?php outFormTitle($_form); ?></div>
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
                      <input type="text" name="lf_openID" value="" id="lf_openID" class="openID" style="width: 220px;"/>
                    </td>
                  </tr>
                </table>
                <div class="footer">
                  <input type="submit" name="lf_login" value="Login" id="lf_login" onclick="javascript: return lfLoginSubmit2();" />
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
                      <span id="uf_name"><?php print($_xml->name); ?></span>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      E-mail
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_mail"><?php print($_xml->mail); ?></span>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      Title
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_title"><?php print($_xml->title); ?></span>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      First Name
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_firstName"><?php print($_xml->firstName); ?></span>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      Last Name
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_lastName"><?php print($_xml->lastName); ?></span>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      Full Name
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_fullName"><?php print($_xml->fullName); ?></span>
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
                                print sprintf("<option %s>%s</option>", ((strcmp($X[$N], $_xml->title) == 0) ? "selected=\"selected\"" : ""), $X[$N]);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_firstName">First Name</label>
                        </th>
                        <td>
                          <input type="text" name="pf_firstName" value="<?php print($_xml->firstName); ?>" id="pf_firstName" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_lastName">Last Name</label>
                        </th>
                        <td>
                          <input type="text" name="pf_lastName" value="<?php print($_xml->lastName); ?>" id="pf_lastName" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_fullName">Full Name</label>
                        </th>
                        <td>
                          <input type="text" name="pf_fullName" value="<?php print($_xml->fullName); ?>" id="pf_fullName" size="60" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_mail">E-mail</label>
                        </th>
                        <td>
                          <input type="text" name="pf_mail" value="<?php print($_xml->mail); ?>" id="pf_mail" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_gender">Gender</label>
                        </th>
                        <td>
                          <select name="pf_gender" value="" id="pf_gender">
                            <option></option>
                            <?php
                              $X = array ("Male", "Female");
                              for ($N = 0; $N < count ($X); $N += 1)
                                print sprintf("<option value=\"%s\" %s>%s</option>", strtolower($X[$N]), ((strcmp(strtolower($X[$N]), $_xml->gender) == 0) ? "selected=\"selected\"": ""), $X[$N]);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_birthday">Birthday</label>
                        </th>
                        <td>
                          <input name="pf_birthday" id="pf_birthday" value="<?php print($_xml->birthday); ?>" onclick="cPopup.select ($('pf_birthday'), 'pf_birthday_select', 'yyyy-MM-dd');"/>
                          <a href="#" name="pf_birthday_select" id="pf_birthday_select" onclick="cPopup.select ($('pf_birthday'), 'pf_birthday_select', 'yyyy-MM-dd'); return false;"> </a>
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
                          <input type="text" name="pf_icq" value="<?php print($_xml->icq); ?>" id="pf_icq" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_skype">Skype</label>
                        </th>
                        <td>
                          <input type="text" name="pf_skype" value="<?php print($_xml->skype); ?>" id="pf_skype" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_yahoo">Yahoo</label>
                        </th>
                        <td>
                          <input type="text" name="pf_yahoo" value="<?php print($_xml->yahoo); ?>" id="pf_yahoo" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_aim">AIM</label>
                        </th>
                        <td>
                          <input type="text" name="pf_aim" value="<?php print($_xml->aim); ?>" id="pf_aim" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_msn">MSN</label>
                        </th>
                        <td>
                          <input type="text" name="pf_msn" value="<?php print($_xml->msn); ?>" id="pf_msn" style="width: 220px;" />
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div id="page_2" style="display:none;">
                    <table class="form" cellspacing="5">
                      <tr>
                        <th width="30%">
                          <label for="pf_homecountry">Country</label>
                        </th>
                        <td nowrap="nowrap">
                          <select name="pf_homecountry" id="pf_homecountry" onchange="javascript: return updateState('pf_homecountry', 'pf_homestate');" style="width: 220px;">
                            <option></option>
                            <?php
                              for ($N = 1; $N <= count ($_countries); $N += 1)
                                print sprintf("<option %s>%s</option>", ((strcmp($_countries[$N], $_xml->homeCountry) == 0) ? "selected=\"selected\"" : ""), $_countries[$N]);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homestate">State/Province</label>
                        </th>
                        <td>
                          <span id="span_pf_homestate">
                            <script type="text/javascript">
                              OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){updateState("pf_homecountry", "pf_homestate", "<?php print($_xml->homeState); ?>");});
                            </script>
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homecity">City/Town</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homecity" value="<?php print($_xml->homeCity); ?>" id="pf_homecity" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homecode">Zip/Postal Code</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homecode" value="<?php print($_xml->homeCode); ?>" id="pf_homecode" style="width: 220px;"/>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeaddress1">Address1</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homeaddress1" value="<?php print($_xml->homeAddress1); ?>" id="pf_homeaddress1" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeaddress2">Address2</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homeaddress2" value="<?php print($_xml->homeAddress2); ?>" id="pf_homeaddress2" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeTimezone">Time-Zone</label>
                        </th>
                        <td>
                          <select name="pf_homeTimezone" id="pf_homeTimezone">
                            <?php
                              for ($N = -12; $N <= 12; $N += 1)
                                print sprintf("<option value=\"%d\" %s>GMT %d:00</option>", $N, (($N == $_xml->homeTimezone) ? "selected=\"selected\"" : ""), $N);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homelat">Latitude</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homelat" value="<?php print($_xml->homeLatitude); ?>" id="pf_homelat" />
                          <label>
                          <input type="checkbox" name="pf_homeDefaultMapLocation" id="pf_homeDefaultMapLocation" onclick="javascript: setDefaultMapLocation('home', 'business');" />
                            Default Map Location
                          </label>
                        <td>
                      <tr>
                      <tr>
                        <th>
                          <label for="pf_homelng">Longitude</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homelng" value="<?php print($_xml->homeLongitude); ?>" id="pf_homelng" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homePhone">Phone</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homePhone" value="<?php print($_xml->homePhone); ?>" id="pf_homePhone" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeMobile">Mobile</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homeMobile" value="<?php print($_xml->homeMobile); ?>" id="pf_homeMobile" />
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
                                print sprintf("<option %s>%s</option>", ((strcmp($_industries[$N], $_xml->businessIndustry) == 0) ? "selected=\"selected\"" : ""), $_industries[$N]);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessOrganization">Organization</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessOrganization" value="<?php print($_xml->businessOrganization); ?>" id="pf_businessOrganization" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessHomePage">Organization Home Page</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businessHomePage" value="<?php print($_xml->businessHomePage); ?>" id="pf_businessNetwork" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessJob">Job Title</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessJob" value="<?php print($_xml->businessJob); ?>" id="pf_businessJob" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businesscountry">Country</label>
                        </th>
                        <td>
                          <select name="pf_businesscountry" id="pf_businesscountry" onchange="javascript: return updateState('pf_businesscountry', 'pf_businessstate');" style="width: 220px;">
                            <option></option>
                            <?php
                              for ($N = 1; $N <= count ($_countries); $N += 1)
                                print sprintf("<option %s>%s</option>", ((strcmp($_countries[$N], $_xml->businessCountry) == 0) ? "selected=\"selected\"" : ""), $_countries[$N]);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessstate">State/Province</label>
                        </th>
                        <td>
                          <span id="span_pf_businessstate">
                            <script type="text/javascript">
                              OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){updateState("pf_businesscountry", "pf_businessstate", "<?php print($_xml->businessState); ?>");});
                            </script>
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businesscity">City/Town</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businesscity" value="<?php print($_xml->businessCity); ?>" id="pf_businesscity" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businesscode">Zip/Postal Code</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businesscode" value="<?php print($_xml->businessCode); ?>" id="pf_businesscode" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessaddress1">Address1</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessaddress1" value="<?php print($_xml->businessAddress1); ?>" id="pf_businessaddress1" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessaddress2">Address2</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessaddress2" value="<?php print($_xml->businessAddress2); ?>" id="pf_businessaddress2" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessTimezone">Time-Zone</label>
                        </th>
                        <td>
                          <select name="pf_businessTimezone" id="pf_businessTimezone" style="width: 220px;">
                            <?php
                              for ($N = -12; $N <= 12; $N += 1)
                                print sprintf("<option value=\"%d\" %s>GMT %d:00</option>", $N, (($N == $_xml->businessTimezone) ? "selected=\"selected\"": ""), $N);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businesslat">Latitude</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businesslat" value="<?php print($_xml->businessLatitude); ?>" id="pf_businesslat" />
                          <label>
                          <input type="checkbox" name="pf_businessDefaultMapLocation" id="pf_businessDefaultMapLocation" onclick="javascript: setDefaultMapLocation('business', 'home');" />
                            Default Map Location
                          </label>
                        <td>
                      <tr>
                      <tr>
                        <th>
                          <label for="pf_businesslng">Longitude</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businesslng" value="<?php print($_xml->businessLongitude); ?>" id="pf_businesslng" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessPhone">Phone</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessPhone" value="<?php print($_xml->businessPhone); ?>" id="pf_businessPhone" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessMobile">Mobile</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessMobile" value="<?php print($_xml->businessMobile); ?>" id="pf_businessMobile" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessRegNo">VAT Reg number (EU only) or Tax ID</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessRegNo" value="<?php print($_xml->businessRegNo); ?>" id="pf_businessRegNo" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessCareer">Career / Organization Status</label>
                        </th>
                        <td>
                          <select name="pf_businessCareer" id="pf_businessCareer" style="width: 220px;">
                            <option />
                            <?php
                              $X = array ("Job seeker-Permanent", "Job seeker-Temporary", "Job seeker-Temp/perm", "Employed-Unavailable", "Employer", "Agency", "Resourcing supplier");
                              for ($N = 0; $N < count ($X); $N += 1)
                                print sprintf("<option %s>%s</option>", ((strcmp($X[$N], $_xml->businessCareer) == 0) ? "selected=\"selected\"" : ""), $X[$N]);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessEmployees">No. of Employees</label>
                        </th>
                        <td>
                          <select name="pf_businessEmployees" id="pf_businessEmployees" style="width: 220px;">
                            <option />
                            <?php
                              $X = array ("1-100", "101-250", "251-500", "501-1000", ">1000");
                              for ($N = 0; $N < count ($X); $N += 1)
                                print sprintf("<option %s>%s</option>", ((strcmp($X[$N], $_xml->businessEmployees) == 0) ? "selected=\"selected\"" : ""), $X[$N]);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessVendor">Are you a technology vendor</label>
                        </th>
                        <td>
                          <select name="pf_businessVendor" id="pf_businessVendor" style="width: 220px;">
                            <option />
                            <?php
                              $X = array ("Not a Vendor", "Vendor", "VAR", "Consultancy");
                              for ($N = 0; $N < count ($X); $N += 1)
                                print sprintf("<option %s>%s</option>", ((strcmp($X[$N], $_xml->businessVendor) == 0) ? "selected=\"selected\"" : ""), $X[$N]);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessService">If so, what technology and/or service do you provide?</label>
                        </th>
                        <td>
                          <select name="pf_businessService" id="pf_businessService" style="width: 220px;">
                            <option />
                            <?php
                              $X = array ("Enterprise Data Integration", "Business Process Management", "Other");
                              for ($N = 0; $N < count ($X); $N += 1)
                                print sprintf("<option %s>%s</option>", ((strcmp($X[$N], $_xml->businessService) == 0) ? "selected=\"selected\"" : ""), $X[$N]);
                            ?>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessOther">Other Technology service</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessOther" value="<?php print($_xml->businessOther); ?>" id="pf_businessOther" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessNetwork">Importance of OpenLink Network for you</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessNetwork" value="<?php print($_xml->businessNetwork); ?>" id="pf_businessNetwork" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessResume">Resume</label>
                        </th>
                        <td>
                          <textarea name="pf_businessResume" id="pf_businessResume" style="width: 220px;"><?php print($_xml->businessResume); ?></textarea>
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
                        <th>
                          <label for="pf_newPassword">New Password</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="password" name="pf_newPassword" value="" id="pf_newPassword" />
                        </td>
                      </tr>
                      <tr>
                        <th>
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
                        <th>
                          <label for="pf_securitySecretQuestion">Secret Question</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_securitySecretQuestion" value="<?php print($_xml->securitySecretQuestion); ?>" id="pf_securitySecretQuestion" style="width: 220px;" />
                          <select name="pf_secretQuestion_select" value="" id="pf_secretQuestion_select" onchange="setSecretQuestion ();" style="width: 220px;">
                            <option value="">~pick predefined~</option>
                            <option value="First Car">First Car</option>
                            <option value="Mothers Maiden Name">Mothers Maiden Name</option>
                            <option value="Favorite Pet">Favorite Pet</option>
                            <option value="Favorite Sports Team">Favorite Sports Team</option>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_securitySecretAnswer">Secret Answer</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_securitySecretAnswer" value="<?php print($_xml->securitySecretAnswer); ?>" id="pf_securitySecretAnswer" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th style="text-align: left; background-color: #F6F6F6;" colspan="2">
                          Applications restrictions
                        </th>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_securitySiocLimit">SIOC Query Result Limit  </label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_securitySiocLimit" value="<?php print($_xml->securitySiocLimit); ?>" id="pf_securitySiocLimit" />
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
          Copyright &copy; 1998-2010 OpenLink Software
        </div>
      </div>
     </div>
  </body>
</html>
