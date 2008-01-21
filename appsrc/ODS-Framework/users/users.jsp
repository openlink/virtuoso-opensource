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

<%@ page import="java.sql.*" %>
<%@ page import="java.io.*" %>

<%@ page import="javax.xml.parsers.DocumentBuilderFactory" %>
<%@ page import="javax.xml.parsers.DocumentBuilder" %>
<%@ page import="javax.xml.xpath.XPathFactory" %>
<%@ page import="javax.xml.xpath.XPath" %>
<%@ page import="javax.xml.xpath.XPathExpressionException" %>

<%@ page import="org.xml.sax.InputSource" %>

<%@ page import="org.w3c.dom.Document" %>
<html>
  <head>
    <title>Virtuoso Web Applications</title>
    <link rel="stylesheet" type="text/css" href="/ods/default.css" />
    <link rel="stylesheet" type="text/css" href="/ods/ods-bar.css" />
    <link rel="stylesheet" type="text/css" href="/ods/users/css/users.css" />
    <script type="text/javascript" src="/ods/users/js/oid_login.js"></script>
    <script type="text/javascript" src="/ods/users/js/users.js"></script>
    <script type="text/javascript">
      var toolkitPath="/ods/oat";
      var featureList = ["dom", "ajax2", "ws", "tab", "dimmer"];
    </script>
    <script type="text/javascript" src="/ods/oat/loader.js"></script>
  </head>
  <%!
    XPathFactory factory = XPathFactory.newInstance();
    XPath xpath = factory.newXPath();

    Document createDocument (String S)
    {
      try
      {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        if (factory == null)
	        throw new RuntimeException("Unable to create XML document factory");
        DocumentBuilder builder = factory.newDocumentBuilder();
        if (builder == null)
	        throw new RuntimeException("Unable to create XML document factory");
        StringReader stringReader = new StringReader(S);
        InputSource is = new InputSource(stringReader);
	      return builder.parse(is);
      }
      catch (Exception e)
      {
        throw new RuntimeException("Error creating XML document factory : " + e.getMessage());
      }
    }

    String xpathEvaluate (Document doc, String xpathString)
      throws XPathExpressionException
    {
      return xpath.evaluate(xpathString, doc);
    }

    void outPrint (javax.servlet.jsp.JspWriter out, String S)
      throws IOException
    {
      if (S == null)
        return;
      out.print(S);
    }

    void outFormTitle (javax.servlet.jsp.JspWriter out, String formName)
      throws IOException
    {
      if (formName.equals("login"))
        out.print("Login");
      if (formName.equals("register"))
        out.print("Register");
      if (formName.equals("user"))
        out.print("View Profile");
      if (formName.equals("profile"))
        out.print("Edit Profile");
    }

    void outSelectOptions (javax.servlet.jsp.JspWriter out, Connection conn, String sql, String fieldValue, String paramValue)
      throws IOException, SQLException
    {
      PreparedStatement ps = null;
      ResultSet rs = null;

      try
      {
        ps = conn.prepareStatement(sql);
        if (paramValue != null)
          ps.setObject(1, paramValue);
        rs = ps.executeQuery();
        while (rs.next())
        {
          String F = rs.getString("NAME");
          out.print ("<option" + ((fieldValue.equals(F)) ? " selected=\"selected\"": "") + ">" + F + "</option>");
        }
      }
      finally
      {
        if (rs != null)
        {
          try
          {
            rs.close();
          } catch (SQLException e) {
          }
        }
        if (ps != null)
        {
          try {
            ps.close();
          } catch (SQLException e) {
          }
        }
      }
    }
  %>
  <%@ include file="users_dsn.jsp" %>
  <%
    String $_form = "login";
    if (request.getParameter("form") != null)
      $_form = request.getParameter("form");
    String $_sid = request.getParameter("sid");
    String $_realm = request.getParameter("realm");
    String $_error = "";
    String $_retValue;
    Document $_document = null;

    Connection conn = null;
    CallableStatement cs = null;

    try
    {
	    Class.forName("virtuoso.jdbc3.Driver");
      conn = DriverManager.getConnection($_dsn, $_user, $_pass);
      if ($_form.equals("login"))
      {
        if (request.getParameter("lf_login") != null)
        {
          try
          {
            cs = conn.prepareCall("{? = call ODS_USER_LOGIN(?, ?)}");
            cs.registerOutParameter(1, Types.VARCHAR);
            cs.setString(2, request.getParameter("lf_uid"));
            cs.setString(3, request.getParameter("lf_password"));

            // Execute and retrieve the returned value
            cs.execute();
            $_retValue = cs.getString(1);
  		      $_document = createDocument($_retValue);
            if ("OK".compareTo(xpathEvaluate($_document, "//error/code")) != 0)
            {
              $_error = xpathEvaluate($_document, "//error/message");
            }
            else
            {
              $_sid = xpathEvaluate($_document, "/root/session/sid");
              $_realm = xpathEvaluate($_document, "/root/session/realm");
              $_form = "user";
            }
          }
          catch (Exception e)
          {
            $_error = e.getMessage();
          }
        }
        if (request.getParameter("lf_register") != null)
          $_form = "register";
      }
      if ($_form.equals("register"))
      {
        if (request.getParameter("rf_signup") != null)
        {
          if (request.getParameter("rf_uid").length() == 0)
          {
            $_error = "Bad username. Please correct!";
          }
          else if (request.getParameter("rf_mail").length() == 0)
          {
            $_error = "Bad mail. Please correct!";
          }
          else if (request.getParameter("rf_password").length() == 0)
          {
            $_error = "Bad password. Please correct!";
          }
          else if (request.getParameter("rf_password").compareTo(request.getParameter("rf_password2")) != 0)
          {
            $_error = "Bad password. Please retype!";
          }
          else if (request.getParameter("rf_is_agreed") == null)
          {
            $_error = "You have not agreed to the Terms of Service!";
          }
          else
          {
            try
            {
              cs = conn.prepareCall("{? = call ODS_USER_REGISTER(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)}");
              cs.registerOutParameter(1, Types.VARCHAR);
              cs.setString( 2, request.getParameter("rf_uid"));
              cs.setString( 3, request.getParameter("rf_password"));
              cs.setString( 4, request.getParameter("rf_mail"));
              cs.setString( 5, request.getParameter("rf_identity"));
              cs.setString( 6, request.getParameter("rf_fullname"));
              cs.setString( 7, request.getParameter("rf_birthday"));
              cs.setString( 8, request.getParameter("rf_gender"));
              cs.setString( 9, request.getParameter("rf_postcode"));
              cs.setString(10, request.getParameter("rf_country"));
              cs.setString(11, request.getParameter("rf_tz"));

              // Execute and retrieve the returned value
              cs.execute();
              $_retValue = cs.getString(1);
    		      $_document = createDocument($_retValue);
              if ("OK".compareTo(xpathEvaluate($_document, "//error/code")) != 0)
              {
                $_error = xpathEvaluate($_document, "//error/message");
              }
              else
              {
                $_sid = xpathEvaluate($_document, "/root/session/sid");
                $_realm = xpathEvaluate($_document, "/root/session/realm");
                $_form = "user";
              }
            }
            catch (Exception e)
            {
              $_error = e.getMessage();
            }
          }
        }
      }
      if ($_form.equals("user"))
      {
        if (request.getParameter("uf_profile") != null)
          $_form = "profile";
      }
      if ($_form.equals("profile"))
      {
        if (request.getParameter("pf_update") != null)
        {
          cs = conn.prepareCall("{? = call ODS_USER_UPDATE(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)}");
          cs.registerOutParameter(1, Types.VARCHAR);
          cs.setString( 2, $_sid);
          cs.setString( 3, $_realm);
          cs.setString( 4, request.getParameter("pf_mail"));
          cs.setString( 5, request.getParameter("pf_title"));
          cs.setString( 6, request.getParameter("pf_firstName"));
          cs.setString( 7, request.getParameter("pf_lastName"));
          cs.setString( 8, request.getParameter("pf_fullName"));
          cs.setString( 9, request.getParameter("pf_gender"));
          cs.setString(10, request.getParameter("pf_birthdayDay"));
          cs.setString(11, request.getParameter("pf_birthdayMonth"));
          cs.setString(12, request.getParameter("pf_birthdayYear"));
          cs.setString(13, request.getParameter("pf_icq"));
          cs.setString(14, request.getParameter("pf_skype"));
          cs.setString(15, request.getParameter("pf_yahoo"));
          cs.setString(16, request.getParameter("pf_aim"));
          cs.setString(17, request.getParameter("pf_msn"));
          cs.setString(18, request.getParameter("pf_homeDefaultMapLocation"));
          cs.setString(19, request.getParameter("pf_homeCountry"));
          cs.setString(20, request.getParameter("pf_homeState"));
          cs.setString(21, request.getParameter("pf_homeCity"));
          cs.setString(22, request.getParameter("pf_homeCode"));
          cs.setString(23, request.getParameter("pf_homeAddress1"));
          cs.setString(24, request.getParameter("pf_homeAddress2"));
          cs.setString(25, request.getParameter("pf_homeTimeZone"));
          cs.setString(26, request.getParameter("pf_homeLatitude"));
          cs.setString(27, request.getParameter("pf_homeLongitude"));
          cs.setString(28, request.getParameter("pf_homePhone"));
          cs.setString(29, request.getParameter("pf_homeMobile"));
          cs.setString(30, request.getParameter("pf_businessIndustry"));
          cs.setString(31, request.getParameter("pf_businessOrganization"));
          cs.setString(32, request.getParameter("pf_businessHomePage"));
          cs.setString(33, request.getParameter("pf_businessJob"));
          cs.setString(34, request.getParameter("pf_businessCountry"));
          cs.setString(35, request.getParameter("pf_businessState"));
          cs.setString(36, request.getParameter("pf_businessCity"));
          cs.setString(37, request.getParameter("pf_businessCode"));
          cs.setString(38, request.getParameter("pf_businessAddress1"));
          cs.setString(39, request.getParameter("pf_businessAddress2"));
          cs.setString(40, request.getParameter("pf_businessTimeZone"));
          cs.setString(41, request.getParameter("pf_businessLatitude"));
          cs.setString(42, request.getParameter("pf_businessLongitude"));
          cs.setString(43, request.getParameter("pf_businessPhone"));
          cs.setString(44, request.getParameter("pf_businessMobile"));
          cs.setString(45, request.getParameter("pf_businessRegNo"));
          cs.setString(46, request.getParameter("pf_businessCareer"));
          cs.setString(47, request.getParameter("pf_businessEmployees"));
          cs.setString(48, request.getParameter("pf_businessVendor"));
          cs.setString(49, request.getParameter("pf_businessService"));
          cs.setString(50, request.getParameter("pf_businessOther"));
          cs.setString(51, request.getParameter("pf_businessNetwork"));
          cs.setString(52, request.getParameter("pf_businessResume"));
          cs.setString(53, request.getParameter("pf_securitySecretQuestion"));
          cs.setString(54, request.getParameter("pf_securitySecretAnswer"));
          cs.setString(55, request.getParameter("pf_securitySiocLimit"));

          // Execute and retrieve the returned value
          cs.execute();
          $_retValue = cs.getString(1);
		      $_document = createDocument($_retValue);
          if ("OK".compareTo(xpathEvaluate($_document, "//error/code")) != 0)
          {
            $_error = xpathEvaluate($_document, "//error/message");
            $_form = "login";
          }
          else
          {
            $_form = "user";
          }
        }
        if (request.getParameter("pf_cancel") != null)
          $_form = "user";
        if ($_form.equals("profile"))
        {
          cs = conn.prepareCall("{? = call ODS_USER_SELECT(?, ?, ?)}");
          cs.registerOutParameter(1, Types.VARCHAR);
          cs.setString(2, $_sid);
          cs.setString(3, $_realm);
          cs.setInt(4, 0);

          // Execute and retrieve the returned value
          cs.execute();
          $_retValue = cs.getString(1);
		      $_document = createDocument($_retValue);
          if ("OK".compareTo(xpathEvaluate($_document, "//error/code")) != 0)
          {
            $_error = xpathEvaluate($_document, "//error/message");
            $_form = "login";
          }
        }
      }
      if ($_form.equals("user"))
      {
        try
        {
          cs = conn.prepareCall("{? = call ODS_USER_SELECT(?, ?)}");
          cs.registerOutParameter(1, Types.VARCHAR);
          cs.setString(2, $_sid);
          cs.setString(3, $_realm);

          // Execute and retrieve the returned value
          cs.execute();
          $_retValue = cs.getString(1);
		      $_document = createDocument($_retValue);
          if ("OK".compareTo(xpathEvaluate($_document, "//error/code")) != 0)
          {
            $_error = xpathEvaluate($_document, "//error/message");
            $_form = "login";
          }
        }
        catch (Exception e)
        {
          $_error = e.getMessage();
        }
      }
      if ($_form.equals("login"))
      {
        $_sid = "";
        $_realm = "";
      }
    }
    catch (Exception e)
    {
      $_error = "Failure to connect to JDBC. " + e.getMessage();
    }
  %>
  <body>
    <form name="page_form" method="post">
      <input type="hidden" name="sid" id="sid" value="<% out.print($_sid); %>" />
      <input type="hidden" name="realm" id="realm" value="<% out.print($_realm); %>" />
      <input type="hidden" name="form" id="form" value="<% out.print($_form); %>" />
      <div id="ob">
        <div id="ob_left"><a href="/ods/?sid=<% out.print($_sid); %>&realm=<% out.print($_realm); %>">ODS Home</a> > <% outFormTitle (out, $_form); %></div>
        <%
          if ($_form != "login")
          {
        %>
        <div id="ob_right"><a href="#" onclick="javascript: return logoutSubmit2();">Logout</a></div>
        <%
          }
        %>
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
              <%
              if ($_form.equals("login"))
              {
              %>
              <div id="lf" class="form">
                <%
                  if ($_error != "")
                  {
                    out.print("<div class=\"error\">" + $_error + "</div>");
                  }
                %>
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
              <%
              }
              if ($_form.equals("register"))
              {
              %>
              <div id="rf" class="form">
                <%
                  if ($_error != "")
                  {
                    out.print("<div class=\"error\">" + $_error + "</div>");
                  }
                %>
                <div class="header">
                  Enter register data
                </div>
                <table class="form" cellspacing="5">
                  <tr>
                    <th width="30%">
                      <label for="rf_openID">Register with OpenID</label>
                    </th>
                    <td nowrap="nowrap">
                      <input type="text" name="rf_openID" value="<% outPrint(out, request.getParameter("rf_openID")); %>" id="rf_openID" class="openID" size="40"/>
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
                      <input type="text" name="rf_uid" value="<% outPrint(out, request.getParameter("rf_uid")); %>" id="rf_uid" />
                    </td>
                  </tr>
                  <tr id="rf_login_2">
                    <th>
                      <label for="rf_mail">E-mail<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
                    </th>
                    <td nowrap="nowrap">
                      <input type="text" name="rf_mail" value="<% outPrint(out, request.getParameter("rf_mail")); %>" id="rf_mail" size="40"/>
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
              <%
              }
              if ($_form.equals("user"))
              {
              %>
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
                      <span id="uf_name"><% out.print(xpathEvaluate($_document, "/root/user/name")); %></span>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      E-mail
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_mail"><% out.print(xpathEvaluate($_document, "/root/user/mail")); %></span>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      Title
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_title"><% out.print(xpathEvaluate($_document, "/root/user/title")); %></span>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      First Name
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_firstName"><% out.print(xpathEvaluate($_document, "/root/user/firstName")); %></span>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      Last Name
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_lastName"><% out.print(xpathEvaluate($_document, "/root/user/lastName")); %></span>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      Full Name
                    </th>
                    <td nowrap="nowrap">
                      <span id="uf_fullName"><% out.print(xpathEvaluate($_document, "/root/user/fullName")); %></span>
                    </td>
                  </tr>
                </table>
                <div class="footer">
                  <input type="submit" name="uf_profile" value="Edit Profile" />
                </div>
              </div>
              <%
              }
              if ($_form.equals("profile"))
              {
              %>
              <div id="pf" class="form" style="width: 800px;">
                <%
                  if ($_error != "")
                  {
                    out.print("<div class=\"error\">" + $_error + "</div>");
                  }
                %>
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
                        <th>
                          <label for="pf_title">Title</label>
                        </th>
                        <td nowrap="nowrap">
                          <select name="pf_title" id="pf_title">
                            <option></option>
                            <%
                              {
                                String[] V = {"Mr", "Mrs", "Dr", "Ms"};
                                String S = xpathEvaluate($_document, "/root/user/title");
                                for (int N = 0; N < V.length; N++)
                                  out.print("<option" + ((V[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N] + "</option>");
                              }
                            %>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_firstName">First Name</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_firstName" value="<% out.print(xpathEvaluate($_document, "/root/user/firstName")); %>" id="pf_firstName" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_lastName">Last Name</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_lastName" value="<% out.print(xpathEvaluate($_document, "/root/user/lastName")); %>" id="pf_lastName" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_fullName">Full Name</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_fullName" value="<% out.print(xpathEvaluate($_document, "/root/user/fullName")); %>" id="pf_fullName" size="60" />
                        </td>
                      </tr>
                      <tr>
                        <th width="30%">
                          <label for="pf_mail">E-mail</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_mail" value="<% out.print(xpathEvaluate($_document, "/root/user/mail")); %>" id="pf_mail" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_gender">Gender</label>
                        </th>
                        <td>
                          <select name="pf_gender" value="" id="pf_gender">
                            <option></option>
                            <%
                              {
                                String[] V = {"Male", "Female"};
                                String[] V1 = {"male", "female"};
                                String S = xpathEvaluate($_document, "/root/user/gender");
                                for (int N = 0; N < V.length; N++)
                                  out.print("<option value=\"" + V1[N] + "\"" +((V1[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N] + "</option>");
                              }
                            %>
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
                            <%
                              {
                                String S = xpathEvaluate($_document, "/root/user/birthdayDay");
                                String NS;
                                for (int N = 1; N <= 31; N++) {
                                  NS = Integer.toString(N);
                                  out.print("<option value=\"" + NS + "\"" +((NS.equals(S)) ? (" selected=\"selected\""): ("")) + ">" + NS + "</option>");
                                }
                              }
                            %>
                          </select>
        		              -
                          <select name="pf_birthdayMonth" id="pf_birthdayMonth">
                            <option></option>
                            <%
                              {
                                String[] V = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"};
                                String S = xpathEvaluate($_document, "/root/user/birthdayMonth");
                                String NS;
                                for (int N = 1; N <= V.length; N++) {
                                  NS = Integer.toString(N);
                                  out.print("<option value=\"" + NS + "\"" +((NS.equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N-1] + "</option>");
                                }
                              }
                            %>
                          </select>
                          -
                          <select name="pf_birthdayYear" id="pf_birthdayYear">
                            <option></option>
                            <%
                              {
                                String S = xpathEvaluate($_document, "/root/user/birthdayYear");
                                String NS;
                                for (int N = 1950; N <= 2003; N++) {
                                  NS = Integer.toString(N);
                                  out.print("<option value=\"" + NS + "\"" +((NS.equals(S)) ? (" selected=\"selected\""): ("")) + ">" + NS + "</option>");
                                }
                              }
                            %>
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
                        <td nowrap="nowrap">
                          <input type="text" name="pf_icq" value="<% out.print(xpathEvaluate($_document, "/root/user/icq")); %>" id="pf_icq" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_skype">Skype</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_skype" value="<% out.print(xpathEvaluate($_document, "/root/user/skype")); %>" id="pf_skype" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_yahoo">Yahoo</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_yahoo" value="<% out.print(xpathEvaluate($_document, "/root/user/yahoo")); %>" id="pf_yahoo" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_aim">AIM</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_aim" value="<% out.print(xpathEvaluate($_document, "/root/user/aim")); %>" id="pf_aim" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_msn">MSN</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_msn" value="<% out.print(xpathEvaluate($_document, "/root/user/msn")); %>" id="pf_msn" size="40" />
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
                            <%
                              outSelectOptions (out, conn, "select WC_NAME NAME from DB.DBA.WA_COUNTRY order by WC_NAME", xpathEvaluate($_document, "/root/user/homeCountry"), null);
                            %>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeState">State/Province</label>
                        </th>
                        <td nowrap="nowrap">
                          <select name="pf_homeState" id="pf_homeState">
                            <option></option>
                            <%
                              outSelectOptions (out, conn, "select WP_PROVINCE NAME from DB.DBA.WA_PROVINCE where WP_COUNTRY = ? and WP_COUNTRY <> '' order by WP_PROVINCE", xpathEvaluate($_document, "/root/user/homeState"), xpathEvaluate($_document, "/root/user/homeCountry"));
                            %>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeCity">City/Town</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homeCity" value="<% out.print(xpathEvaluate($_document, "/root/user/homeCity")); %>" id="pf_homeCity" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeCode">Zip/Postal Code</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homeCode" value="<% out.print(xpathEvaluate($_document, "/root/user/homeCode")); %>" id="pf_homeCode" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeAddress1">Address1</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homeAddress1" value="<% out.print(xpathEvaluate($_document, "/root/user/homeAddress1")); %>" id="pf_homeAddress1" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeAddress2">Address2</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homeAddress2" value="<% out.print(xpathEvaluate($_document, "/root/user/homeAddress2")); %>" id="pf_homeAddress2" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_homeTimeZone">Time-Zone</label>
                        </th>
                        <td>
                          <select name="pf_homeTimeZone" id="pf_homeTimeZone">
                            <%
                              {
                                String S = xpathEvaluate($_document, "/root/user/birthdayDay");
                                String NS;
                                for (int N = -12; N <= 12; N++) {
                                  NS = Integer.toString(N);
                                  out.print("<option value=\"" + NS + "\"" +((NS.equals(S)) ? (" selected=\"selected\""): ("")) + ">GMT " + NS + ":00</option>");
                                }
                              }
                            %>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_homeLatitude">Latitude</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homeLatitude" value="<% out.print(xpathEvaluate($_document, "/root/user/homeLatitude")); %>" id="pf_homeLatitude" />
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
                          <input type="text" name="pf_homeLongitude" value="<% out.print(xpathEvaluate($_document, "/root/user/homeLongitude")); %>" id="pf_homeLongitude" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_homePhone">Phone</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homePhone" value="<% out.print(xpathEvaluate($_document, "/root/user/homePhone")); %>" id="pf_homePhone" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_homeMobile">Mobile</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homeMobile" value="<% out.print(xpathEvaluate($_document, "/root/user/homeMobile")); %>" id="pf_homeMobile" />
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
                        <td nowrap="nowrap">
                          <select name="pf_businessIndustry" id="pf_businessIndustry">
                            <option></option>
                            <%
                              outSelectOptions (out, conn, "select WI_NAME NAME from DB.DBA.WA_INDUSTRY order by WI_NAME", xpathEvaluate($_document, "/root/user/businessIndustry"), null);
                            %>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessOrganization">Organization</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businessOrganization" value="<% out.print(xpathEvaluate($_document, "/root/user/businessOrganization")); %>" id="pf_businessOrganization" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessHomePage">Organization Home Page</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businessHomePage" value="<% out.print(xpathEvaluate($_document, "/root/user/businessHomePage")); %>" id="pf_businessNetwork" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessJob">Job Title</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businessJob" value="<% out.print(xpathEvaluate($_document, "/root/user/businessJob")); %>" id="pf_businessJob" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th width="30%">
                          <label for="pf_businessCountry">Country</label>
                        </th>
                        <td nowrap="nowrap">
                          <select name="pf_businessCountry" id="pf_businessCountry" onchange="javascript: return updateState('pf_businessCountry', 'pf_businessState');">
                            <option></option>
                            <%
                              outSelectOptions (out, conn, "select WC_NAME NAME from DB.DBA.WA_COUNTRY order by WC_NAME", xpathEvaluate($_document, "/root/user/businessCountry"), null);
                            %>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessState">State/Province</label>
                        </th>
                        <td nowrap="nowrap">
                          <select name="pf_businessState" id="pf_businessState">
                            <option></option>
                            <%
                              outSelectOptions (out, conn, "select WP_PROVINCE NAME from DB.DBA.WA_PROVINCE where WP_COUNTRY = ? and WP_COUNTRY <> '' order by WP_PROVINCE", xpathEvaluate($_document, "/root/user/businessState"), xpathEvaluate($_document, "/root/user/businessCountry"));
                            %>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessCity">City/Town</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businessCity" value="<% out.print(xpathEvaluate($_document, "/root/user/businessCity")); %>" id="pf_businessCity" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessCode">Zip/Postal Code</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businessCode" value="<% out.print(xpathEvaluate($_document, "/root/user/businessCode")); %>" id="pf_businessCode" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessAddress1">Address1</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businessAddress1" value="<% out.print(xpathEvaluate($_document, "/root/user/businessAddress1")); %>" id="pf_businessAddress1" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessAddress2">Address2</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businessAddress2" value="<% out.print(xpathEvaluate($_document, "/root/user/businessAddress2")); %>" id="pf_businessAddress2" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessTimeZone">Time-Zone</label>
                        </th>
                        <td>
                          <select name="pf_businessTimeZone" id="pf_businessTimeZone">
                            <%
                              {
                                String S = xpathEvaluate($_document, "/root/user/birthdayDay");
                                String NS;
                                for (int N = -12; N <= 12; N++) {
                                  NS = Integer.toString(N);
                                  out.print("<option value=\"" + NS + "\"" +((NS.equals(S)) ? (" selected=\"selected\""): ("")) + ">GMT " + NS + ":00</option>");
                                }
                              }
                            %>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessLatitude">Latitude</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businessLatitude" value="<% out.print(xpathEvaluate($_document, "/root/user/businessLatitude")); %>" id="pf_businessLatitude" />
                          <input type="button" name="pf_setHomeLocation" value="Set From Address" onclick="javascript: pfGetLocation('business');" />
                          <input type="checkbox" name="pf_businessDefaultMapLocation" id="pf_businessDefaultMapLocation" onclick="javascript: setDefaultMapLocation('business', 'business');" />
                          <label for="pf_businessDefaultMapLocation">Default Map Location</label>
                        <td>
                      <tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessLongitude">Longitude</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessLongitude" value="<% out.print(xpathEvaluate($_document, "/root/user/businessLongitude")); %>" id="pf_businessLongitude" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessPhone">Phone</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessPhone" value="<% out.print(xpathEvaluate($_document, "/root/user/businessPhone")); %>" id="pf_businessPhone" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessMobile">Mobile</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessMobile" value="<% out.print(xpathEvaluate($_document, "/root/user/businessMobile")); %>" id="pf_businessMobile" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessRegNo">VAT Reg number (EU only) or Tax ID</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessRegNo" value="<% out.print(xpathEvaluate($_document, "/root/user/businessRegNo")); %>" id="pf_businessRegNo" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessCareer">Career / Organization Status</label>
                        </th>
                        <td>
                          <select name="pf_businessCareer" id="pf_businessCareer">
                            <option />
                            <%
                              {
                                String[] V = {"Job seeker-Permanent", "Job seeker-Temporary", "Job seeker-Temp/perm", "Employed-Unavailable", "Employer", "Agency", "Resourcing supplier"};
                                String S = xpathEvaluate($_document, "/root/user/businessCareer");
                                for (int N = 0; N < V.length; N++)
                                  out.print("<option" + ((V[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N] + "</option>");
                              }
                            %>
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
                            <%
                              {
                                String[] V = {"1-100", "101-250", "251-500", "501-1000", ">1000"};
                                String S = xpathEvaluate($_document, "/root/user/businessEmployees");
                                for (int N = 0; N < V.length; N++)
                                  out.print("<option" + ((V[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N] + "</option>");
                              }
                            %>
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
                            <%
                              {
                                String[] V = {"Not a Vendor", "Vendor", "VAR", "Consultancy"};
                                String S = xpathEvaluate($_document, "/root/user/businessVendor");
                                for (int N = 0; N < V.length; N++)
                                  out.print("<option" + ((V[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N] + "</option>");
                              }
                            %>
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
                            <%
                              {
                                String[] V = {"Enterprise Data Integration", "Business Process Management", "Other"};
                                String S = xpathEvaluate($_document, "/root/user/businessService");
                                for (int N = 0; N < V.length; N++)
                                  out.print("<option" + ((V[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N] + "</option>");
                              }
                            %>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessOther">Other Technology service</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessOther" value="<% out.print(xpathEvaluate($_document, "/root/user/businessOther")); %>" id="pf_businessOther" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessNetwork">Importance of OpenLink Network for you</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessNetwork" value="<% out.print(xpathEvaluate($_document, "/root/user/businessNetwork")); %>" id="pf_businessNetwork" size="40" />
                        </td>
                      </tr>
                      <tr>
                        <th nowrap="nowrap">
                          <label for="pf_businessResume">Resume</label>
                        </th>
                        <td>
                          <textarea name="pf_businessResume" id="pf_businessResume" cols="50"><% out.print(xpathEvaluate($_document, "/root/user/businessResume")); %></textarea>
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
                          <input type="text" name="pf_securitySecretQuestion" value="<% out.print(xpathEvaluate($_document, "/root/user/securitySecretQuestion")); %>" id="pf_securitySecretQuestion" size="40" />
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
                          <input type="text" name="pf_securitySecretAnswer" value="<% out.print(xpathEvaluate($_document, "/root/user/securitySecretAnswer")); %>" id="pf_securitySecretAnswer" size="40" />
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
                          <input type="text" name="pf_securitySiocLimit" value="<% out.print(xpathEvaluate($_document, "/root/user/securitySiocLimit")); %>" id="pf_securitySiocLimit" />
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
              <%
              }
              %>
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
          Copyright &copy; 1999-2008 OpenLink Software
        </div>
      </div>
     </div>
  </body>
</html>
