#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2013 OpenLink Software
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
require 'dbi'
require 'cgi'
require 'rexml/document'
require 'rexml/xpath'
include REXML

print "Content-Type: text/html\n\n"

# Define function display login data.
def login_form()
  return <<END_OF_STRING
    <div id="lf" class="form">
      #{display_error()}
      <div class="header">
        Please identify yourself
      </div>
      <ul id="lf_tabs" class="tabs">
        <li id="lf_tab_0" title="Digest">Digest</li>
        <li id="lf_tab_1" title="OpenID">OpenID</li>
        <li id="lf_tab_2" title="Facebook" style="display: none;">Facebook</li>
        <li id="lf_tab_3" title="WebID" style="display: none;">WebID</li>
      </ul>
      <div style="min-height: 120px; border: 1px solid #aaa; margin: -13px 5px 5px 5px;">
        <div id="lf_content"></div>
        <div id="lf_page_0" class="tabContent" >
      <table class="form" cellspacing="5">
        <tr>
          <th width="30%">
                <label for="lf_uid">User ID</label>
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
      </table>
      </div>
        <div id="lf_page_1" class="tabContent" style="display: none">
      <table class="form" cellspacing="5">
        <tr>
          <th width="30%">
                <label for="lf_openId">OpenID URL</label>
          </th>
          <td nowrap="nowrap">
                <input type="text" name="lf_openId" value="" id="lf_openId" class="openId" size="40"/>
          </td>
        </tr>
          </table>
        </div>
        <div id="lf_page_2" class="tabContent" style="display: none">
          <table class="form" cellspacing="5">
        <tr>
              <th width="30%">
          </th>
          <td nowrap="nowrap">
                <span id="lf_facebookData" style="min-height: 20px;"></span>
                <br />
                <script src="http://static.ak.connect.facebook.com/js/api_lib/v0.4/FeatureLoader.js.php" type="text/javascript"></script>
                <fb:login-button autologoutlink="true"></fb:login-button>
          </td>
        </tr>
      </table>
        </div>
        <div id="lf_page_3" class="tabContent" style="display: none">
          <table id="lf_table_3" class="form" cellspacing="5">
          </table>
        </div>
      </div>
      <div class="footer">
        <input type="submit" name="lf_login" value="Login" id="lf_login" onclick="javascript: return lfLoginSubmit();" />
      </div>
    </div>
END_OF_STRING
end

# Define function display users data.
def user_form()
  return <<END_OF_STRING
    <div id="uf" class="form">
      <div class="header">
        User profile
      </div>
      <ul id="uf_tabs" class="tabs">
        <li id="uf_tab_0" title="Personal">Personal</li>
        <li id="uf_tab_1" title="Messaging Services">Messaging Services</li>
        <li id="uf_tab_2" title="Home">Home</li>
        <li id="uf_tab_3" title="Business">Business</li>
        <li id="uf_tab_4" title="Data Explorer">Data Explorer</li>
      </ul>
      <div style="min-height: 180px; border: 1px solid #aaa; margin: -13px 5px 5px 5px;">
        <div id="uf_content"></div>
        <div id="uf_page_0" class="tabContent" >
          <table id="uf_table_0" class="form" cellspacing="5">
          </table>
        </div>
        <div id="uf_page_1" class="tabContent" >
          <table id="uf_table_1" class="form" cellspacing="5">
          </table>
        </div>
        <div id="uf_page_2" class="tabContent" >
          <table id="uf_table_2" class="form" cellspacing="5">
          </table>
        </div>
        <div id="uf_page_3" class="tabContent" >
          <table id="uf_table_3" class="form" cellspacing="5">
      </table>
        </div>
        <div id="uf_page_4" class="tabContent" >
          <div id="uf_rdf_content">
            &nbsp;
          </div>
        </div>
        <script type="text/javascript">
          OAT.MSG.attach(OAT, "PAGE_LOADED", function (){selectProfile();});
          OAT.MSG.attach(OAT, "PAGE_LOADED", function (){cRDF.open("<?V xpath_eval ('string (/user/iri)', vXml) ?>");});
        </script>
      </div>
      <div class="footer">
        <input type="submit" name="uf_profile" value="Edit Profile" />
      </div>
    </div>
END_OF_STRING
end

# Define function display profile data.
def profile_form()
  return <<END_OF_STRING
    <div id="pf" class="form" style="width: 800px;">
      #{display_error()}
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
                </select>
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_firstName">First Name</label>
              </th>
              <td>
                <input type="text" name="pf_firstName" value="#{$_user['pf_firstName']}" id="pf_firstName" size="40" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_lastName">Last Name</label>
              </th>
              <td>
                <input type="text" name="pf_lastName" value="#{$_user['pf_lastName']}" id="pf_lastName" size="40" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_fullName">Full Name</label>
              </th>
              <td>
                <input type="text" name="pf_fullName" value="#{$_user['pf_fullName']}" id="pf_fullName" size="60" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_mail">E-mail</label>
              </th>
              <td>
                <input type="text" name="pf_mail" value="#{$_user['pf_mail']}" id="pf_mail" size="40" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_gender">Gender</label>
              </th>
              <td>
                <select name="pf_gender" value="" id="pf_gender">
                  <option></option>
                </select>
              </td>
            </tr>
            <tr>
              <th>
                <label for="pf_birthday">Birthday</label>
              </th>
              <td>
                <input name="pf_birthday" id="pf_birthday" value="#{$_user['pf_birthday']}" onclick="datePopup('pf_birthday');"/>
              </td>
            </tr>
            <tr>
              <th>
                <label for="pf_homepage">Personal Webpage</label>
              </th>
              <td>
                <input type="text" name="pf_homepage" value="#{$_user['pf_homepage']}" id="pf_homepage" style="width: 220px;" />
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
                <input type="text" name="pf_icq" value="#{$_user['pf_icq']}" id="pf_icq" size="40" />
              </td>
            </tr>
            <tr>
              <th>
                <label for="pf_skype">Skype</label>
              </th>
              <td>
                <input type="text" name="pf_skype" value="#{$_user['pf_skype']}" id="pf_skype" size="40" />
              </td>
            </tr>
            <tr>
              <th>
                <label for="pf_yahoo">Yahoo</label>
              </th>
              <td>
                <input type="text" name="pf_yahoo" value="#{$_user['pf_yahoo']}" id="pf_yahoo" size="40" />
              </td>
            </tr>
            <tr>
              <th>
                <label for="pf_aim">AIM</label>
              </th>
              <td>
                <input type="text" name="pf_aim" value="#{$_user['pf_aim']}" id="pf_aim" size="40" />
              </td>
            </tr>
            <tr>
              <th>
                <label for="pf_msn">MSN</label>
              </th>
              <td>
                <input type="text" name="pf_msn" value="#{$_user['pf_msn']}" id="pf_msn" size="40" />
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
                </select>
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_homeCity">City/Town</label>
              </th>
              <td>
                <input type="text" name="pf_homeCity" value="#{$_user['pf_homeCity']}" id="pf_homeCity" size="40" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_homeCode">Zip/Postal Code</label>
              </th>
              <td>
                <input type="text" name="pf_homeCode" value="#{$_user['pf_homeCode']}" id="pf_homeCode" />
              </td>
            </tr>
            <tr>
              <th>
                <label for="pf_homeAddress1">Address1</label>
              </th>
              <td nowrap="nowrap">
                <input type="text" name="pf_homeAddress1" value="#{$_user['pf_homeAddress1']}" id="pf_homeAddress1" size="40" />
              </td>
            </tr>
            <tr>
              <th>
                <label for="pf_homeAddress2">Address2</label>
              </th>
              <td nowrap="nowrap">
                <input type="text" name="pf_homeAddress2" value="#{$_user['pf_homeAddress2']}" id="pf_homeAddress2" size="40" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_homeTimeZone">Time-Zone</label>
              </th>
              <td>
                <select name="pf_homeTimeZone" id="pf_homeTimeZone">
                </select>
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_homeLatitude">Latitude</label>
              </th>
              <td nowrap="nowrap">
                <input type="text" name="pf_homeLatitude" value="#{$_user['pf_homeLatitude']}" id="pf_homeLatitude" />
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
                <input type="text" name="pf_homeLongitude" value="#{$_user['pf_homeLongitude']}" id="pf_homeLongitude" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_homePhone">Phone</label>
              </th>
              <td>
                <input type="text" name="pf_homePhone" value="#{$_user['pf_homePhone']}" id="pf_homePhone" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_homeMobile">Mobile</label>
              </th>
              <td>
                <input type="text" name="pf_homeMobile" value="#{$_user['pf_homeMobile']}" id="pf_homeMobile" />
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
                </select>
              </td>
            </tr>
            <tr>
              <th>
                <label for="pf_businessOrganization">Organization</label>
              </th>
              <td>
                <input type="text" name="pf_businessOrganization" value="#{$_user['pf_businessOrganization']}" id="pf_businessOrganization" size="40" />
              </td>
            </tr>
            <tr>
              <th>
                <label for="pf_businessHomePage">Organization Home Page</label>
              </th>
              <td nowrap="nowrap">
                <input type="text" name="pf_businessHomePage" value="#{$_user['pf_businessHomePage']}" id="pf_businessNetwork" size="40" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_businessJob">Job Title</label>
              </th>
              <td>
                <input type="text" name="pf_businessJob" value="#{$_user['pf_businessJob']}" id="pf_businessJob" size="40" />
              </td>
            </tr>
            <tr>
              <th>
                <label for="pf_businessCountry">Country</label>
              </th>
              <td>
                <select name="pf_businessCountry" id="pf_businessCountry" onchange="javascript: return updateState('pf_businessCountry', 'pf_businessState');">
                  <option></option>
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
                </select>
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_businessCity">City/Town</label>
              </th>
              <td>
                <input type="text" name="pf_businessCity" value="#{$_user['pf_businessCity']}" id="pf_businessCity" size="40" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_businessCode">Zip/Postal Code</label>
              </th>
              <td>
                <input type="text" name="pf_businessCode" value="#{$_user['pf_businessCode']}" id="pf_businessCode" />
              </td>
            </tr>
            <tr>
              <th>
                <label for="pf_businessAddress1">Address1</label>
              </th>
              <td>
                <input type="text" name="pf_businessAddress1" value="#{$_user['pf_businessAddress1']}" id="pf_businessAddress1" size="40" />
              </td>
            </tr>
            <tr>
              <th>
                <label for="pf_businessAddress2">Address2</label>
              </th>
              <td>
                <input type="text" name="pf_businessAddress2" value="#{$_user['pf_businessAddress2']}" id="pf_businessAddress2" size="40" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_businessTimeZone">Time-Zone</label>
              </th>
              <td>
                <select name="pf_businessTimeZone" id="pf_businessTimeZone">
                </select>
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_businessLatitude">Latitude</label>
              </th>
              <td>
                <input type="text" name="pf_businessLatitude" value="#{$_user['pf_businessLatitude']}" id="pf_businessLatitude" />
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
                <input type="text" name="pf_businessLongitude" value="#{$_user['pf_businessLongitude']}" id="pf_businessLongitude" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_businessPhone">Phone</label>
              </th>
              <td>
                <input type="text" name="pf_businessPhone" value="#{$_user['pf_businessPhone']}" id="pf_businessPhone" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_businessMobile">Mobile</label>
              </th>
              <td>
                <input type="text" name="pf_businessMobile" value="#{$_user['pf_businessMobile']}" id="pf_businessMobile" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_businessRegNo">VAT Reg number (EU only) or Tax ID</label>
              </th>
              <td>
                <input type="text" name="pf_businessRegNo" value="#{$_user['pf_businessRegNo']}" id="pf_businessRegNo" size="40" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_businessCareer">Career / Organization Status</label>
              </th>
              <td>
                <select name="pf_businessCareer" id="pf_businessCareer">
                  <option />
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
                </select>
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_businessOther">Other Technology service</label>
              </th>
              <td>
                <input type="text" name="pf_businessOther" value="#{$_user['pf_businessOther']}" id="pf_businessOther" size="40" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_businessNetwork">Importance of OpenLink Network for you</label>
              </th>
              <td>
                <input type="text" name="pf_businessNetwork" value="#{$_user['pf_businessNetwork']}" id="pf_businessNetwork" size="40" />
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_businessResume">Resume</label>
              </th>
              <td>
                <textarea name="pf_businessResume" id="pf_businessResume" cols="50">#{$_user['pf_businessResume']}</textarea>
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
                <input type="text" name="pf_securitySecretQuestion" value="#{$_user['pf_securitySecretQuestion']}" id="pf_securitySecretQuestion" size="40" />
                <select name="pf_secretQuestion_select" value="" id="pf_secretQuestion_select" onchange="setSecretQuestion ();">
                  <option value="">~pick predefined~</option>
                  <option value="First Car">First Car</option>
                  <option value="Mothers Maiden Name">Mothers Maiden Name</option>
                  <option value="Favorite Pet">Favorite Pet</option>
                  <option value="Favorite Sports Team">Favorite Sports Team</option>
                </select>
                #{$_user['pf_securitySecretQuestion']}
              </td>
            </tr>
            <tr>
              <th nowrap="nowrap">
                <label for="pf_securitySecretAnswer">Secret Answer</label>
              </th>
              <td nowrap="nowrap">
                <input type="text" name="pf_securitySecretAnswer" value="#{$_user['pf_securitySecretAnswer']}" id="pf_securitySecretAnswer" size="40" />
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
                <input type="text" name="pf_securitySiocLimit" value="#{$_user['pf_securitySiocLimit']}" id="pf_securitySiocLimit" />
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
END_OF_STRING
end

# Define function display form data.
def display_form()
  if ($_formName == 'login')
    return login_form()
  elsif ($_formName == 'register')
    return register_form()
  elsif ($_formName == 'user')
    return user_form()
  elsif ($_formName == 'profile')
    return profile_form()
  end
end

# Define function display form title.
def outFormTitle()
  if ($_formName == 'login')
    return "Login"
  elsif ($_formName == 'register')
    return "Register"
  elsif ($_formName == 'user')
    return "View Profile"
  elsif ($_formName == 'profile')
    return "Edit Profile"
  end
end

# Define function display form title.
def display_logout()
  if (($_formName != "login") && ($_formName != "register"))
    return '<div id="ob_right"><a href="#" onclick="javascript: return logoutSubmit2();">Logout</a></div>'
  end
end

# Define function display form title.
def display_error()
  if ($_error != "")
    return "<div class=\"error\">#{$_error}</div>"
  end
end

# Define function display form title.
def xpathResult(xml, path)
  node = REXML::XPath.first(xml, path)
  if (node != nil)
    print ' '
    if (node.instance_of? REXML::Element)
      return node.text
    end
  end
end

# Define main function.
def main()
  odbc = DBI.connect('DBI:ODBC:LocalVirtuosoDemo', 'dba', 'dba')

  $_form = CGI.new
  $_sid = ''
  $_realm = ''
  $_error = ''
  $_formName = 'login'
  if ($_form.has_key?('sid'))
    $_sid = $_form['sid']
  end
  if ($_form.has_key?('realm'))
    $_realm = $_form['realm']
  end
  if ($_form.has_key?('form'))
    $_formName = $_form['form']
  end
  $_user = Hash.new()

  if ($_formName == "login")
    if ($_form.has_key?('lf_login'))
      sth = odbc.prepare("select ODS_USER_LOGIN(?, ?)")
      sth.execute($_form['lf_uid'], $_form['lf_password'])

      while row=sth.fetch do
        xmlResult = REXML::Document.new(row[0])
        if (xpathResult(xmlResult.root, '//error/code') != 'OK')
          $_error = xpathResult(xmlResult.root, '//error/message')
        else
          $_sid = xpathResult(xmlResult.root, '//session/sid')
          $_realm = xpathResult(xmlResult.root, '//session/realm')
          $_formName = "user"
        end
      end

      # Close the statement handle when done
      sth.finish
    end
    if ($_form.has_key?('lf_register'))
      $_formName = "register"
    end
  end
  if ($_formName == 'user')
    if ($_form.has_key?('uf_profile'))
      $_formName = 'profile';
    end
  end
  if ($_formName == 'profile')
    if ($_form.has_key?('pf_update'))
      sth = odbc.prepare("select ODS_USER_UPDATE(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)")
      sth.execute($_sid,                                \
                  $_realm,                              \
                  $_form['pf_mail'],                    \
                  $_form['pf_title'],                   \
                  $_form['pf_firstName'],               \
                  $_form['pf_lastName'],                \
                  $_form['pf_fullName'],                \
                  $_form['pf_gender'],                  \
                  $_form['pf_birthdayDay'],             \
                  $_form['pf_birthdayMonth'],           \
                  $_form['pf_birthdayYear'],            \
                  $_form['pf_icq'],                     \
                  $_form['pf_skype'],                   \
                  $_form['pf_yahoo'],                   \
                  $_form['pf_aim'],                     \
                  $_form['pf_msn'],                     \
                  $_form['pf_homeDefaultMapLocation'],  \
                  $_form['pf_homeCountry'],             \
                  $_form['pf_homeState'],               \
                  $_form['pf_homeCity'],                \
                  $_form['pf_homeCode'],                \
                  $_form['pf_homeAddress1'],            \
                  $_form['pf_homeAddress2'],            \
                  $_form['pf_homeTimeZone'],            \
                  $_form['pf_homeLatitude'],            \
                  $_form['pf_homeLongitude'],           \
                  $_form['pf_homePhone'],               \
                  $_form['pf_homeMobile'],              \
                  $_form['pf_businessIndustry'],        \
                  $_form['pf_businessOrganization'],    \
                  $_form['pf_businessHomePage'],        \
                  $_form['pf_businessJob'],             \
                  $_form['pf_businessCountry'],         \
                  $_form['pf_businessState'],           \
                  $_form['pf_businessCity'],            \
                  $_form['pf_businessCode'],            \
                  $_form['pf_businessAddress1'],        \
                  $_form['pf_businessAddress2'],        \
                  $_form['pf_businessTimeZone'],        \
                  $_form['pf_businessLatitude'],        \
                  $_form['pf_businessLongitude'],       \
                  $_form['pf_businessPhone'],           \
                  $_form['pf_businessMobile'],          \
                  $_form['pf_businessRegNo'],           \
                  $_form['pf_businessCareer'],          \
                  $_form['pf_businessEmployees'],       \
                  $_form['pf_businessVendor'],          \
                  $_form['pf_businessService'],         \
                  $_form['pf_businessOther'],           \
                  $_form['pf_businessNetwork'],         \
                  $_form['pf_businessResume'],          \
                  $_form['pf_securitySecretQuestion'],  \
                  $_form['pf_securitySecretAnswer'],    \
                  $_form['pf_securitySiocLimit']);

      while row=sth.fetch do
        xmlResult = REXML::Document.new(row[0])
        if (xpathResult(xmlResult.root, '//error/code') != 'OK')
          $_error = xpathResult(xmlResult.root, '//error/message')
          $_formName = "login";
        else
          $_formName = "user";
        end
      end

      # Close the statement handle when done
      sth.finish
    end
    if ($_form.has_key?('pf_cancel'))
      $_formName = "user";
    end
    if ($_formName == 'profile')
      sth = odbc.prepare("select ODS_USER_SELECT(?, ?, ?)")
      sth.execute($_sid, $_realm, 0);

      while row=sth.fetch do
        xmlResult = REXML::Document.new(row[0])
        # xmlResult << XMLDecl.new
        # xmlResult.write(STDOUT, 0)
        if (xpathResult(xmlResult.root, '//error/code') != 'OK')
          $_error = xpathResult(xmlResult.root, '//error/message')
          $_formName = "login";
        else
          $_user['pf_name']                   = xpathResult(xmlResult.root, '//user/name')
          $_user['pf_mail']                   = xpathResult(xmlResult.root, '//user/mail')
          $_user['pf_title']                  = xpathResult(xmlResult.root, '//user/title')
          $_user['pf_firstName']              = xpathResult(xmlResult.root, '//user/firstName')
          $_user['pf_lastName']               = xpathResult(xmlResult.root, '//user/lastName')
          $_user['pf_fullName']               = xpathResult(xmlResult.root, '//user/fullName')
          $_user['pf_gender']                 = xpathResult(xmlResult.root, '//user/gender')
          $_user['pf_birthday']               = xpathResult(xmlResult.root, '//user/birthday')
          $_user['pf_homepage']               = xpathResult(xmlResult.root, '//user/homepage')
          $_user['pf_icq']                    = xpathResult(xmlResult.root, '//user/icq')
          $_user['pf_skype']                  = xpathResult(xmlResult.root, '//user/skype')
          $_user['pf_yahoo']                  = xpathResult(xmlResult.root, '//user/yahoo')
          $_user['pf_aim']                    = xpathResult(xmlResult.root, '//user/aim')
          $_user['pf_msn']                    = xpathResult(xmlResult.root, '//user/msn')
          $_user['pf_homeDefaultMapLocation'] = xpathResult(xmlResult.root, '//user/defaultMapLocation')
          $_user['pf_homeCountry']            = xpathResult(xmlResult.root, '//user/homeCountry')
          $_user['pf_homeState']              = xpathResult(xmlResult.root, '//user/homeState')
          $_user['pf_homeCity']               = xpathResult(xmlResult.root, '//user/homeCity')
          $_user['pf_homeCode']               = xpathResult(xmlResult.root, '//user/homeCode')
          $_user['pf_homeAddress1']           = xpathResult(xmlResult.root, '//user/homeAddress1')
          $_user['pf_homeAddress2']           = xpathResult(xmlResult.root, '//user/homeAddress2')
          $_user['pf_homeTimeZone']           = xpathResult(xmlResult.root, '//user/homeTimeZone')
          $_user['pf_homeLatitude']           = xpathResult(xmlResult.root, '//user/homeLatitude')
          $_user['pf_homeLongitude']          = xpathResult(xmlResult.root, '//user/homeLongitude')
          $_user['pf_homePhone']              = xpathResult(xmlResult.root, '//user/homePhone')
          $_user['pf_homeMobile']             = xpathResult(xmlResult.root, '//user/homeMobile')
          $_user['pf_businessIndustry']       = xpathResult(xmlResult.root, '//user/businessIndustry')
          $_user['pf_businessOrganization']   = xpathResult(xmlResult.root, '//user/businessOrganization')
          $_user['pf_businessHomePage']       = xpathResult(xmlResult.root, '//user/businessHomePage')
          $_user['pf_businessJob']            = xpathResult(xmlResult.root, '//user/businessJob')
          $_user['pf_businessCountry']        = xpathResult(xmlResult.root, '//user/businessCountry')
          $_user['pf_businessState']          = xpathResult(xmlResult.root, '//user/businessState')
          $_user['pf_businessCity']           = xpathResult(xmlResult.root, '//user/businessCity')
          $_user['pf_businessCode']           = xpathResult(xmlResult.root, '//user/businessCode')
          $_user['pf_businessAddress1']       = xpathResult(xmlResult.root, '//user/businessAddress1')
          $_user['pf_businessAddress2']       = xpathResult(xmlResult.root, '//user/businessAddress2')
          $_user['pf_businessTimeZone']       = xpathResult(xmlResult.root, '//user/businessTimeZone')
          $_user['pf_businessLatitude']       = xpathResult(xmlResult.root, '//user/businessLatitude')
          $_user['pf_businessLongitude']      = xpathResult(xmlResult.root, '//user/businessLongitude')
          $_user['pf_businessPhone']          = xpathResult(xmlResult.root, '//user/businessPhone')
          $_user['pf_businessMobile']         = xpathResult(xmlResult.root, '//user/businessMobile')
          $_user['pf_businessRegNo']          = xpathResult(xmlResult.root, '//user/businessRegNo')
          $_user['pf_businessCareer']         = xpathResult(xmlResult.root, '//user/businessCareer')
          $_user['pf_businessEmployees']      = xpathResult(xmlResult.root, '//user/businessEmployees')
          $_user['pf_businessVendor']         = xpathResult(xmlResult.root, '//user/businessVendor')
          $_user['pf_businessService']        = xpathResult(xmlResult.root, '//user/businessService')
          $_user['pf_businessOther']          = xpathResult(xmlResult.root, '//user/businessOther')
          $_user['pf_businessNetwork']        = xpathResult(xmlResult.root, '//user/businessNetwork')
          $_user['pf_businessResume']         = xpathResult(xmlResult.root, '//user/businessResume')
          $_user['pf_securitySecretQuestion'] = xpathResult(xmlResult.root, '//user/securitySecretQuestion')
          $_user['pf_securitySecretAnswer']   = xpathResult(xmlResult.root, '//user/securitySecretAnswer')
          $_user['pf_securitySiocLimit']      = xpathResult(xmlResult.root, '//user/securitySiocLimit')
        end
      end

      # Close the statement handle when done
      sth.finish
    end
  end
  if ($_formName == "user")
    sth = odbc.prepare("select ODS_USER_SELECT(?, ?)")
    sth.execute($_sid, $_realm);

    while row=sth.fetch do
      xmlResult = REXML::Document.new(row[0])
      if (xpathResult(xmlResult.root, '//error/code') != 'OK')
        $_error = xpathResult(xmlResult.root, '//error/message')
        $_formName = "login";
      else
        $_user['uf_name'] = xpathResult(xmlResult.root, '//user/name')
        $_user['uf_mail'] = xpathResult(xmlResult.root, '//user/mail')
        $_user['uf_title'] = xpathResult(xmlResult.root, '//user/title')
        $_user['uf_firstName'] = xpathResult(xmlResult.root, '//user/firstName')
        $_user['uf_lastName'] = xpathResult(xmlResult.root, '//user/lastName')
        $_user['uf_fullName'] = xpathResult(xmlResult.root, '//user/fullName')
      end
    end

    # Close the statement handle when done
    sth.finish
  end
  if ($_formName == "login")
    $_sid = "";
    $_realm = "";
  end

  puts <<END_OF_STRING
<html>
  <head>
    <title>Virtuoso Web Applications</title>
    <link rel="stylesheet" type="text/css" href="/ods/users/css/users.css" />
    <link rel="stylesheet" type="text/css" href="/ods/default.css" />
    <link rel="stylesheet" type="text/css" href="/ods/ods-bar.css" />
    <link rel="stylesheet" type="text/css" href="/ods/rdfm.css" />
    <script type="text/javascript" src="/ods/users/js/users.js"></script>
    <script type="text/javascript" src="/ods/common.js"></script>
    <script type="text/javascript" src="/ods/typeahead.js"></script>
    <script type="text/javascript" src="/ods/tbl.js"></script>
    <script type="text/javascript" src="/ods/validate.js"></script>
    <script type="text/javascript">
      // OAT
      var toolkitPath="/ods/oat";
      var featureList = ["ajax", "json", "tab", "combolist", "calendar", "crypto", "rdfmini", "grid", "graphsvg", "tagcloud", "map", "timeline", "anchor"];
    </script>
    <script type="text/javascript" src="/ods/oat/loader.js"></script>
    <script type="text/javascript">
      OAT.MSG.attach(OAT, "PAGE_LOADED", myInit);
      window.onload = function(){OAT.MSG.send(OAT, 'PAGE_LOADED');};
    </script>
  </head>
  <body>
    <form name="page_form" method="post">
      <input type="hidden" name="sid" id="sid" value="#{$_sid}" />
      <input type="hidden" name="realm" id="realm" value="#{$_realm}" />
      <input type="hidden" name="form" id="form" value="#{$_formName}" />
      <div id="ob">
        <div id="ob_left"><a href="/ods/?sid=#{$_sid}&realm=#{$_realm}">ODS Home</a> > #{outFormTitle()}</div>
        #{display_logout()}
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
              #{display_form()}
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
          Copyright &copy; 1999-2013 OpenLink Software
        </div>
      </div>
     </div>
  </body>
</html>
END_OF_STRING
end

# Call main function.
main()
