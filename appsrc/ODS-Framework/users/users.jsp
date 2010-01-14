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
<%@ page import="java.util.*" %>
<%@ page import="java.net.HttpURLConnection" %>
<%@ page import="java.net.MalformedURLException" %>
<%@ page import="java.net.ProtocolException" %>
<%@ page import="java.net.URL" %>
<%@ page import="java.net.URLEncoder" %>

<%@ page import="java.security.MessageDigest" %>
<%@ page import="java.security.NoSuchAlgorithmException" %>
<%@ page import="sun.misc.BASE64Encoder" %>

<%@ page import="javax.xml.parsers.*" %>
<%@ page import="javax.xml.xpath.*" %>

<%@ page import="org.xml.sax.InputSource" %>

<%@ page import="org.w3c.dom.*" %>
<html>
  <head>
    <title>Virtuoso Web Applications</title>
    <link rel="stylesheet" type="text/css" href="/ods/users/css/users.css" />
    <link rel="stylesheet" type="text/css" href="/ods/default.css" />
    <link rel="stylesheet" type="text/css" href="/ods/ods-bar.css" />
    <link rel="stylesheet" type="text/css" href="/ods/rdfm.css" />
    <script type="text/javascript" src="/ods/users/js/users.js"></script>
    <script type="text/javascript" src="/ods/common.js"></script>
    <script type="text/javascript" src="/ods/CalendarPopup.js"></script>
    <script type="text/javascript">
      // OAT
      var toolkitPath="/ods/oat";
      var featureList = ["dom", "ajax2", "ws", "json", "tab", "dimmer", "combolist", "crypto", "rdfmini", "dimmer", "grid", "graphsvg", "map", "timeline", "tagcloud", "anchor", "dock"];
    </script>
    <script type="text/javascript" src="/ods/oat/loader.js"></script>
    <script type="text/javascript">
      OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, myInit);
    </script>
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

    String encrypt (String S)
    {
      String hash = new String("");
      try {
        MessageDigest md = MessageDigest.getInstance("SHA-1");
        byte[] textBytes = S.getBytes("UTF-8");
        md.update(textBytes);
        for (byte b : md.digest()) {
          hash += Integer.toHexString(b & 0xff);
        }
      }
      catch (NoSuchAlgorithmException e) {
        e.printStackTrace();
      }
      catch (UnsupportedEncodingException ex) {
        ex.printStackTrace();
      }
      return hash;
    }

    String httpParam (String prefix, String key, String value)
      throws Exception
    {
      String S = "";
      if (value != null)
        S = prefix + key + "=" + URLEncoder.encode(value);
      return S;
    }

    String httpRequest (String httpMethod, String method, String params)
      throws Exception
    {
      HttpURLConnection connection = null;
      DataOutputStream wr = null;
      BufferedReader rd  = null;
      StringBuilder sb = null;
      String line = null;
      URL serverAddress = null;
      Boolean isFirst = true;

      try {
        serverAddress = new URL("http://localhost:8005/ods/api/"+method);

        //Set up the initial connection
        connection = (HttpURLConnection)serverAddress.openConnection();
        connection.setRequestMethod(httpMethod);
        connection.setDoOutput(true);
        connection.setDoInput(true);
        connection.setReadTimeout(10000);
        connection.connect();

        //get the output stream writer and write the output to the server
        wr = new DataOutputStream(connection.getOutputStream());
        if (params != null) {
          wr.writeBytes(params);
        }
        wr.flush ();
        wr.close ();

        //read the result from the server
        rd = new BufferedReader(new InputStreamReader(connection.getInputStream()));
        sb = new StringBuilder();

        while ((line = rd.readLine()) != null) {
          if (!isFirst)
            sb.append('\n');
          sb.append(line);
          isFirst = false;
        }
        rd.close ();
        return sb.toString();
      }
      catch (MalformedURLException e) {
        e.printStackTrace();
      }
      catch (ProtocolException e) {
        e.printStackTrace();
      }
      catch (IOException e) {
        e.printStackTrace();
      }
      finally {
        //close the connection, set all objects to null
        connection.disconnect();
        rd = null;
        sb = null;
        wr = null;
        connection = null;
      }
      throw new Exception ("Bad request!");
    }

    String xpathEvaluate (Document doc, String xpathString)
      throws XPathExpressionException
    {
      return xpath.evaluate(xpathString, doc);
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

    void outSelectOptions (javax.servlet.jsp.JspWriter out, String fieldValue, String listValue)
      throws IOException, SQLException
    {
      outSelectOptions (out, fieldValue, listValue, null);
    }

    void outSelectOptions (javax.servlet.jsp.JspWriter out, String fieldValue, String listValue, String paramValue)
    {
      try
      {
        String params;
        params = httpParam ("", "key", listValue);
        if (paramValue != null)
          params += httpParam ("&", "param", paramValue);
        String retValue = httpRequest ("GET", "lookup.list", params);
        Document doc = createDocument(retValue);

        XPathFactory factory = XPathFactory.newInstance();
        XPath xpath = factory.newXPath();
        XPathExpression expr = xpath.compile("/items/item/text()");

        Object result = expr.evaluate(doc, XPathConstants.NODESET);
        NodeList nodes = (NodeList) result;
        for (int i = 0; i < nodes.getLength(); i++) {
          String F = nodes.item(i).getNodeValue();
          out.print ("<option" + ((fieldValue.equals(F)) ? " selected=\"selected\"": "") + ">" + F + "</option>");
        }
      } catch (Exception e) {
      }
    }
  %>
  <%
    String $_form = request.getParameter("form");
    if ($_form == null)
      $_form = "login";
    String $_sid = request.getParameter("sid");
    String $_realm = "wa";
    String $_error = "";
    String $_retValue;
    Document $_document = null;
    String params = null;

    try
    {
      if ($_form.equals("login"))
      {
        if (request.getParameter("lf_login") != null)
        {
          try
          {
            params = httpParam ( "", "user_name", request.getParameter("lf_uid")) +
                     httpParam ("&", "password_hash", encrypt (request.getParameter("lf_uid")+request.getParameter("lf_password")));
            $_retValue = httpRequest ("GET", "user.authenticate", params);
            if ($_retValue.indexOf("<failed>") == 0)
            {
    		      $_document = createDocument($_retValue);
              throw new Exception(xpathEvaluate($_document, "/failed/message"));
              }
            $_sid = $_retValue;
                $_form = "user";
              }
            catch (Exception e)
            {
              $_error = e.getMessage();
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
          try {
            params = httpParam ( "", "sid"                   , $_sid) +
                     httpParam ("&", "realm"                 , $_realm) +
                     httpParam ("&", "mail"                  , request.getParameter("pf_mail")) +
                     httpParam ("&", "title"                 , request.getParameter("pf_title")) +
                     httpParam ("&", "firstName"             , request.getParameter("pf_firstName")) +
                     httpParam ("&", "lastName"              , request.getParameter("pf_lastName")) +
                     httpParam ("&", "fullName"              , request.getParameter("pf_fullName")) +
                     httpParam ("&", "gender"                , request.getParameter("pf_gender")) +
                     httpParam ("&", "birthday"              , request.getParameter("pf_birthday")) +
                     httpParam ("&", "homepage"              , request.getParameter("pf_homepage")) +
                     httpParam ("&", "icq"                   , request.getParameter("pf_icq")) +
                     httpParam ("&", "skype"                 , request.getParameter("pf_skype")) +
                     httpParam ("&", "yahoo"                 , request.getParameter("pf_yahoo")) +
                     httpParam ("&", "aim"                   , request.getParameter("pf_aim")) +
                     httpParam ("&", "msn"                   , request.getParameter("pf_msn")) +
                     httpParam ("&", "homeDefaultMapLocation", request.getParameter("pf_homeDefaultMapLocation")) +
                     httpParam ("&", "homeCountry"           , request.getParameter("pf_homecountry")) +
                     httpParam ("&", "homeState"             , request.getParameter("pf_homestate")) +
                     httpParam ("&", "homeCity"              , request.getParameter("pf_homecity")) +
                     httpParam ("&", "homeCode"              , request.getParameter("pf_homecode")) +
                     httpParam ("&", "homeAddress1"          , request.getParameter("pf_homeaddress1")) +
                     httpParam ("&", "homeAddress2"          , request.getParameter("pf_homeaddress2")) +
                     httpParam ("&", "homeTimezone"          , request.getParameter("pf_homeTimezone")) +
                     httpParam ("&", "homeLatitude"          , request.getParameter("pf_homelat")) +
                     httpParam ("&", "homeLongitude"         , request.getParameter("pf_homelng")) +
                     httpParam ("&", "homePhone"             , request.getParameter("pf_homePhone")) +
                     httpParam ("&", "homeMobile"            , request.getParameter("pf_homeMobile")) +
                     httpParam ("&", "businessIndustry"      , request.getParameter("pf_businessIndustry")) +
                     httpParam ("&", "businessOrganization"  , request.getParameter("pf_businessOrganization")) +
                     httpParam ("&", "businessHomePage"      , request.getParameter("pf_businessHomePage")) +
                     httpParam ("&", "businessJob"           , request.getParameter("pf_businessJob")) +
                     httpParam ("&", "businessCountry"       , request.getParameter("pf_businesscountry")) +
                     httpParam ("&", "businessState"         , request.getParameter("pf_businessstate")) +
                     httpParam ("&", "businessCity"          , request.getParameter("pf_businesscity")) +
                     httpParam ("&", "businessCode"          , request.getParameter("pf_businesscode")) +
                     httpParam ("&", "businessAddress1"      , request.getParameter("pf_businessaddress1")) +
                     httpParam ("&", "businessAddress2"      , request.getParameter("pf_businessaddress2")) +
                     httpParam ("&", "businessTimezone"      , request.getParameter("pf_businessTimezone")) +
                     httpParam ("&", "businessLatitude"      , request.getParameter("pf_businesslat")) +
                     httpParam ("&", "businessLongitude"     , request.getParameter("pf_businesslng")) +
                     httpParam ("&", "businessPhone"         , request.getParameter("pf_businessPhone")) +
                     httpParam ("&", "businessMobile"        , request.getParameter("pf_businessMobile")) +
                     httpParam ("&", "businessRegNo"         , request.getParameter("pf_businessRegNo")) +
                     httpParam ("&", "businessCareer"        , request.getParameter("pf_businessCareer")) +
                     httpParam ("&", "businessEmployees"     , request.getParameter("pf_businessEmployees")) +
                     httpParam ("&", "businessVendor"        , request.getParameter("pf_businessVendor")) +
                     httpParam ("&", "businessService"       , request.getParameter("pf_businessService")) +
                     httpParam ("&", "businessOther"         , request.getParameter("pf_businessOther")) +
                     httpParam ("&", "businessNetwork"       , request.getParameter("pf_businessNetwork")) +
                     httpParam ("&", "businessResume"        , request.getParameter("pf_businessResume")) +
                     httpParam ("&", "securitySecretQuestion", request.getParameter("pf_securitySecretQuestion")) +
                     httpParam ("&", "securitySecretAnswer"  , request.getParameter("pf_securitySecretAnswer")) +
                     httpParam ("&", "securitySiocLimit"     , request.getParameter("pf_securitySiocLimit"));

            $_retValue = httpRequest ("POST", "user.update.fields", params);
            if ($_retValue.indexOf("<failed>") == 0)
          {
  		        $_document = createDocument($_retValue);
              throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
            $_form = "user";
          }
          catch (Exception e)
          {
            $_error = e.getMessage();
            $_form = "login";
          }
        }
        else if (request.getParameter("pf_cancel") != null)
        {
          $_form = "user";
        }
      }

      if ($_form.equals("user") || $_form.equals("profile"))
      {
        try
        {
          params = httpParam ( "", "sid"   , $_sid) +
                   httpParam ("&", "realm" , $_realm);
          if ($_form.equals("profile"))
            params += httpParam ("&", "short", "0");
          $_retValue = httpRequest ("GET", "user.info", params);
		      $_document = createDocument($_retValue);
          if ("".compareTo(xpathEvaluate($_document, "/failed/message")) != 0)
            throw new Exception (xpathEvaluate($_document, "/failed/message"));
        }
        catch (Exception e)
        {
          $_error = e.getMessage();
          $_form = "login";
        }
      }

      if ($_form.equals("login"))
      {
        $_sid = "";
      }
    }
    catch (Exception e)
    {
      $_error = "Failure to connect to JDBC. " + e.getMessage();
    }
  %>
  <body>
    <div id="cDiv" style="position: absolute; visibility: hidden; background-color: white; z-index: 10;">
    </div>
    <form name="page_form" method="post">
      <input type="hidden" name="sid" id="sid" value="<% out.print($_sid); %>" />
      <input type="hidden" name="realm" id="realm" value="<% out.print($_realm); %>" />
      <input type="hidden" name="form" id="form" value="<% out.print($_form); %>" />
      <div id="ob">
        <div id="ob_left"><a href="/ods/?sid=<% out.print($_sid); %>&amp;realm=<% out.print($_realm); %>">ODS Home</a> > <% outFormTitle (out, $_form); %></div>
        <%
          if ($_form != "login")
          {
        %>
        <div id="ob_right"><a href="#" onclick="javascript: return logoutSubmit();">Logout</a></div>
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
                  User login
                </div>
                <ul id="lf_tabs" class="tabs">
                  <li id="lf_tab_0" title="ODS">ODS</li>
                  <li id="lf_tab_1" title="OpenID">OpenID</li>
                  <li id="lf_tab_2" title="Facebook" style="display: none;">Facebook</li>
                  <li id="lf_tab_3" title="FOAF+SSL" style="display: none;">FOAF+SSL</li>
                </ul>
                <div style="min-height: 120px; border: 1px solid #aaa; margin: -13px 5px 5px 5px;">
                  <div id="lf_content"></div>
                  <div id="lf_page_0" class="tabContent" >
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
              <%
              }
              if ($_form.equals("user"))
              {
              %>
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
                    OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){selectProfile();});
                    OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){cRDF.open("<% out.print(xpathEvaluate($_document, "/user/iri")); %>");});
                  </script>
                </div>
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
                <ul id="tabs" class="tabs">
                  <li id="tab_0" title="Personal">Personal</li>
                  <li id="tab_1" title="Messaging Services">Messaging Services</li>
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
                                String S = xpathEvaluate($_document, "/user/title");
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
                          <input type="text" name="pf_firstName" value="<% out.print(xpathEvaluate($_document, "/user/firstName")); %>" id="pf_firstName" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_lastName">Last Name</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_lastName" value="<% out.print(xpathEvaluate($_document, "/user/lastName")); %>" id="pf_lastName" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_fullName">Full Name</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_fullName" value="<% out.print(xpathEvaluate($_document, "/user/fullName")); %>" id="pf_fullName" size="60" />
                        </td>
                      </tr>
                      <tr>
                        <th width="30%">
                          <label for="pf_mail">E-mail</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_mail" value="<% out.print(xpathEvaluate($_document, "/user/mail")); %>" id="pf_mail" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_gender">Gender</label>
                        </th>
                        <td>
                          <select name="pf_gender" value="" id="pf_gender">
                            <option></option>
                            <%
                              {
                                String[] V = {"Male", "Female"};
                                String[] V1 = {"male", "female"};
                                String S = xpathEvaluate($_document, "/user/gender");
                                for (int N = 0; N < V.length; N++)
                                  out.print("<option value=\"" + V1[N] + "\"" +((V1[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N] + "</option>");
                              }
                            %>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_birthday">Birthday</label>
                        </th>
                        <td>
                          <input name="pf_birthday" id="pf_birthday" value="<% out.print(xpathEvaluate($_document, "/user/birthday")); %>" onclick="cPopup.select ($('pf_birthday'), 'pf_birthday_select', 'yyyy-MM-dd');"/>
                          <a href="#" name="pf_birthday_select" id="pf_birthday_select" onclick="cPopup.select ($('pf_birthday'), 'pf_birthday_select', 'yyyy-MM-dd'); return false;"> </a>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homepage">Personal Webpage</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homepage" value="<% out.print(xpathEvaluate($_document, "/user/homepage")); %>" id="pf_homepage" style="width: 220px;" />
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
                          <input type="text" name="pf_icq" value="<% out.print(xpathEvaluate($_document, "/user/icq")); %>" id="pf_icq" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_skype">Skype</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_skype" value="<% out.print(xpathEvaluate($_document, "/user/skype")); %>" id="pf_skype" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_yahoo">Yahoo</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_yahoo" value="<% out.print(xpathEvaluate($_document, "/user/yahoo")); %>" id="pf_yahoo" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_aim">AIM</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_aim" value="<% out.print(xpathEvaluate($_document, "/user/aim")); %>" id="pf_aim" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_msn">MSN</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_msn" value="<% out.print(xpathEvaluate($_document, "/user/msn")); %>" id="pf_msn" style="width: 220px;" />
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
                            <%
                              outSelectOptions (out, xpathEvaluate($_document, "/user/homeCountry"), "Country");
                            %>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homestate">State/Province</label>
                        </th>
                        <td nowrap="nowrap">
                          <span id="span_pf_homestate">
                            <script type="text/javascript">
                              OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){updateState("pf_homecountry", "pf_homestate", "<% out.print(xpathEvaluate($_document, "/user/homeState")); %>");});
                            </script>
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homecity">City/Town</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homecity" value="<% out.print(xpathEvaluate($_document, "/user/homeCity")); %>" id="pf_homecity" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homecode">Zip/Postal Code</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homecode" value="<% out.print(xpathEvaluate($_document, "/user/homeCode")); %>" id="pf_homecode" style="width: 220px;"/>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeaddress1">Address1</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homeaddress1" value="<% out.print(xpathEvaluate($_document, "/user/homeAddress1")); %>" id="pf_homeaddress1" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeaddress2">Address2</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homeaddress2" value="<% out.print(xpathEvaluate($_document, "/user/homeAddress2")); %>" id="pf_homeaddress2" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeTimezone">Time-Zone</label>
                        </th>
                        <td>
                          <select name="pf_homeTimezone" id="pf_homeTimezone">
                            <%
                              {
                                String S = xpathEvaluate($_document, "/user/homeTimezone");
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
                        <th>
                          <label for="pf_homelat">Latitude</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_homelat" value="<% out.print(xpathEvaluate($_document, "/user/homeLatitude")); %>" id="pf_homelat" />
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
                          <input type="text" name="pf_homelng" value="<% out.print(xpathEvaluate($_document, "/user/homeLongitude")); %>" id="pf_homelng" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homePhone">Phone</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homePhone" value="<% out.print(xpathEvaluate($_document, "/user/homePhone")); %>" id="pf_homePhone" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeMobile">Mobile</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homeMobile" value="<% out.print(xpathEvaluate($_document, "/user/homeMobile")); %>" id="pf_homeMobile" />
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
                          <select name="pf_businessIndustry" id="pf_businessIndustry" style="width: 220px;">
                            <option></option>
                            <%
                              outSelectOptions (out, xpathEvaluate($_document, "/user/businessIndustry"), "Industry");
                            %>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessOrganization">Organization</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businessOrganization" value="<% out.print(xpathEvaluate($_document, "/user/businessOrganization")); %>" id="pf_businessOrganization" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessHomePage">Organization Home Page</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businessHomePage" value="<% out.print(xpathEvaluate($_document, "/user/businessHomePage")); %>" id="pf_businessNetwork" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessJob">Job Title</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businessJob" value="<% out.print(xpathEvaluate($_document, "/user/businessJob")); %>" id="pf_businessJob" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th width="30%">
                          <label for="pf_businesscountry">Country</label>
                        </th>
                        <td nowrap="nowrap">
                          <select name="pf_businesscountry" id="pf_businesscountry" onchange="javascript: return updateState('pf_businesscountry', 'pf_businessState');" style="width: 220px;">
                            <option></option>
                            <%
                              outSelectOptions (out, xpathEvaluate($_document, "/user/businessCountry"), "Country");
                            %>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessstate">State/Province</label>
                        </th>
                        <td nowrap="nowrap">
                          <span id="span_pf_businessstate">
                            <script type="text/javascript">
                              OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){updateState("pf_businesscountry", "pf_businessstate", "<% out.print(xpathEvaluate($_document, "/user/businessState")); %>");});
                            </script>
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businesscity">City/Town</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businesscity" value="<% out.print(xpathEvaluate($_document, "/user/businessCity")); %>" id="pf_businesscity" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businesscode">Zip/Postal Code</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businesscode" value="<% out.print(xpathEvaluate($_document, "/user/businessCode")); %>" id="pf_businesscode" style="width: 220px;"/>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessaddress1">Address1</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businessaddress1" value="<% out.print(xpathEvaluate($_document, "/user/businessAddress1")); %>" id="pf_businessaddress1" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessaddress2">Address2</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businessaddress2" value="<% out.print(xpathEvaluate($_document, "/user/businessAddress2")); %>" id="pf_businessaddress2" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessTimezone">Time-Zone</label>
                        </th>
                        <td>
                          <select name="pf_businessTimezone" id="pf_businessTimezone">
                            <%
                              {
                                String S = xpathEvaluate($_document, "/user/businessTimezone");
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
                        <th>
                          <label for="pf_businesslat">Latitude</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_businesslat" value="<% out.print(xpathEvaluate($_document, "/user/businessLatitude")); %>" id="pf_businesslat" />
                          <label>
                          <input type="checkbox" name="pf_businessDefaultMapLocation" id="pf_businessDefaultMapLocation" onclick="javascript: setDefaultMapLocation('business', 'business');" />
                            Default Map Location
                          </label>
                        <td>
                      <tr>
                      <tr>
                        <th>
                          <label for="pf_businesslng">Longitude</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businesslng" value="<% out.print(xpathEvaluate($_document, "/user/businessLongitude")); %>" id="pf_businesslng" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessPhone">Phone</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessPhone" value="<% out.print(xpathEvaluate($_document, "/user/businessPhone")); %>" id="pf_businessPhone" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessMobile">Mobile</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessMobile" value="<% out.print(xpathEvaluate($_document, "/user/businessMobile")); %>" id="pf_businessMobile" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessRegNo">VAT Reg number (EU only) or Tax ID</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessRegNo" value="<% out.print(xpathEvaluate($_document, "/user/businessRegNo")); %>" id="pf_businessRegNo" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessCareer">Career / Organization Status</label>
                        </th>
                        <td>
                          <select name="pf_businessCareer" id="pf_businessCareer" style="width: 220px;">
                            <option />
                            <%
                              {
                                String[] V = {"Job seeker-Permanent", "Job seeker-Temporary", "Job seeker-Temp/perm", "Employed-Unavailable", "Employer", "Agency", "Resourcing supplier"};
                                String S = xpathEvaluate($_document, "/user/businessCareer");
                                for (int N = 0; N < V.length; N++)
                                  out.print("<option" + ((V[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N] + "</option>");
                              }
                            %>
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
                            <%
                              {
                                String[] V = {"1-100", "101-250", "251-500", "501-1000", ">1000"};
                                String S = xpathEvaluate($_document, "/user/businessEmployees");
                                for (int N = 0; N < V.length; N++)
                                  out.print("<option" + ((V[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N] + "</option>");
                              }
                            %>
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
                            <%
                              {
                                String[] V = {"Not a Vendor", "Vendor", "VAR", "Consultancy"};
                                String S = xpathEvaluate($_document, "/user/businessVendor");
                                for (int N = 0; N < V.length; N++)
                                  out.print("<option" + ((V[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N] + "</option>");
                              }
                            %>
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
                            <%
                              {
                                String[] V = {"Enterprise Data Integration", "Business Process Management", "Other"};
                                String S = xpathEvaluate($_document, "/user/businessService");
                                for (int N = 0; N < V.length; N++)
                                  out.print("<option" + ((V[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N] + "</option>");
                              }
                            %>
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessOther">Other Technology service</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessOther" value="<% out.print(xpathEvaluate($_document, "/user/businessOther")); %>" id="pf_businessOther" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessNetwork">Importance of OpenLink Network for you</label>
                        </th>
                        <td>
                          <input type="text" name="pf_businessNetwork" value="<% out.print(xpathEvaluate($_document, "/user/businessNetwork")); %>" id="pf_businessNetwork" style="width: 220px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessResume">Resume</label>
                        </th>
                        <td>
                          <textarea name="pf_businessResume" id="pf_businessResume" style="width: 220px;"><% out.print(xpathEvaluate($_document, "/user/businessResume")); %></textarea>
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
                          <input type="text" name="pf_securitySecretQuestion" value="<% out.print(xpathEvaluate($_document, "/user/securitySecretQuestion")); %>" id="pf_securitySecretQuestion" style="width: 220px;" />
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
                          <input type="text" name="pf_securitySecretAnswer" value="<% out.print(xpathEvaluate($_document, "/user/securitySecretAnswer")); %>" id="pf_securitySecretAnswer" style="width: 220px;" />
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
                          <input type="text" name="pf_securitySiocLimit" value="<% out.print(xpathEvaluate($_document, "/user/securitySiocLimit")); %>" id="pf_securitySiocLimit" />
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
          Copyright &copy; 1999-2010 OpenLink Software
        </div>
      </div>
     </div>
  </body>
</html>
