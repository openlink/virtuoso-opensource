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

<%@ page import="org.apache.log4j.*" %>
<html>
  <head>
    <title>Virtuoso Web Applications</title>
    <link rel="stylesheet" type="text/css" href="/ods/users/css/users.css" />
    <link rel="stylesheet" type="text/css" href="/ods/default.css" />
    <link rel="stylesheet" type="text/css" href="/ods/typeahead.css" />
    <link rel="stylesheet" type="text/css" href="/ods/ods-bar.css" />
    <link rel="stylesheet" type="text/css" href="/ods/rdfm.css" />
    <script type="text/javascript" src="/ods/users/js/users.js"></script>
    <script type="text/javascript" src="/ods/common.js"></script>
    <script type="text/javascript" src="/ods/typeahead.js"></script>
    <script type="text/javascript">
      // OAT
      var toolkitPath="/ods/oat";
      var featureList = ["dom", "ajax2", "ws", "json", "tab", "dimmer", "combolist", "calendar", "crypto", "rdfmini", "dimmer", "grid", "graphsvg", "tagcloud", "anchor", "dock", "map", "timeline"];
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
    int $_formTab = 0;
    if (request.getParameter("formTab") != null)
      $_formTab = Integer.parseInt(request.getParameter("formTab"));
    int $_formSubtab = 0;
    if (request.getParameter("formSubtab") != null)
      $_formSubtab = Integer.parseInt(request.getParameter("formSubtab"));
    String $_formMode = "";
    if (request.getParameter("formMode") != null)
      $_formMode = request.getParameter("formMode");
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
		        $_document = createDocument($_retValue);
            $_sid = xpathEvaluate($_document, "/sid");
                $_form = "user";
              }
            catch (Exception e)
            {
              $_error = e.getMessage();
            }
          }
        }

      if ($_form.equals("profile"))
      {
        if (request.getParameter("pf_update07") != null)
        {
          params = httpParam( "", "sid", $_sid) +
                   httpParam("&", "realm", $_realm) +
                   httpParam("&", "id", request.getParameter("pf07_id")) +
                   httpParam("&", "property", request.getParameter("pf07_property")) +
                   httpParam("&", "url", request.getParameter("pf07_url")) +
                   httpParam("&", "description", request.getParameter("pf07_description"));
          $_retValue = httpRequest ("POST", "user.mades."+$_formMode, params);
          if ($_retValue.indexOf("<failed>") == 0)
          {
		        $_document = createDocument($_retValue);
            throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
          $_formMode = "";
        }
        else if (request.getParameter("pf_update08") != null)
        {
          params = httpParam( "", "sid", $_sid) +
                   httpParam("&", "realm", $_realm) +
                   httpParam("&", "id", request.getParameter("pf08_id")) +
                   httpParam("&", "name", request.getParameter("pf08_name")) +
                   httpParam("&", "comment", request.getParameter("pf08_comment")) +
                   httpParam("&", "properties", request.getParameter("items"));
          $_retValue = httpRequest ("POST", "user.offers."+$_formMode, params);
          if ($_retValue.indexOf("<failed>") == 0)
          {
		        $_document = createDocument($_retValue);
            throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
          $_formMode = "";
        }
        else if (request.getParameter("pf_update09") != null)
        {
          params = httpParam( "", "sid", $_sid) +
                   httpParam("&", "realm", $_realm) +
                   httpParam("&", "id", request.getParameter("pf09_id")) +
                   httpParam("&", "name", request.getParameter("pf09_name")) +
                   httpParam("&", "comment", request.getParameter("pf09_comment")) +
                   httpParam("&", "properties", request.getParameter("items"));
          $_retValue = httpRequest ("POST", "user.seeks."+$_formMode, params);
          if ($_retValue.indexOf("<failed>") == 0)
          {
		        $_document = createDocument($_retValue);
            throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
          $_formMode = "";
        }
        else if (request.getParameter("pf_cancel2") != null)
        {
          $_formMode = "";
        }
        else if ((request.getParameter("pf_update") != null) || (request.getParameter("pf_next") != null))
        {
          $_formMode = "";
          String tmp = "";
          String prefix = "";
          String suffix = "";
          Enumeration keys;
          try {
            if ((($_formTab == 0) && ($_formSubtab == 3)) || (($_formTab == 1) && ($_formSubtab == 2)))
            {
              String accountType = "P";
              prefix = "x4";
              if (($_formTab == 1) && ($_formSubtab == 2))
              {
                accountType = "B";
                prefix = "y1";
      }
              params = httpParam("", "sid", $_sid) + httpParam ("&", "realm", $_realm) + httpParam ("&", "type", accountType);
              $_retValue = httpRequest ("POST", "user.onlineAccounts.delete", params);
              if ($_retValue.indexOf("<failed>") == 0)
              {
    		        $_document = createDocument($_retValue);
                throw new Exception(xpathEvaluate($_document, "/failed/message"));
              }
              keys = request.getParameterNames();
      		    while (keys.hasMoreElements() )
      {
      		      String key = (String)keys.nextElement();
                if (key.indexOf(prefix+"_fld_1_") == 0)
        {
                  suffix = key.replace(prefix+"_fld_1_", "");
                  params = httpParam( "", "sid", $_sid) +
                           httpParam("&", "realm", $_realm) +
                           httpParam("&", "type", accountType) +
                           httpParam("&", "name", request.getParameter(key)) +
                           httpParam("&", "url", request.getParameter(prefix+"_fld_2_"+suffix));
                  $_retValue = httpRequest ("POST", "user.onlineAccounts.new", params);
                  if ($_retValue.indexOf("<failed>") == 0)
                  {
        		        $_document = createDocument($_retValue);
                    throw new Exception(xpathEvaluate($_document, "/failed/message"));
                  }
                }
      		    }
            }
            else if (($_formTab == 0) && ($_formSubtab == 4))
            {
              prefix = "x5";
              params = httpParam( "", "sid", $_sid) + httpParam ("&", "realm", $_realm);
              $_retValue = httpRequest ("POST", "user.bioEvents.delete", params);
              if ($_retValue.indexOf("<failed>") == 0)
              {
    		        $_document = createDocument($_retValue);
                throw new Exception(xpathEvaluate($_document, "/failed/message"));
              }
              keys = request.getParameterNames();
      		    while (keys.hasMoreElements() )
      		    {
      		      String key = (String)keys.nextElement();
                if (key.indexOf(prefix+"_fld_1_") == 0)
                {
                  suffix = key.replace(prefix+"_fld_1_", "");
            params = httpParam ( "", "sid"                   , $_sid) +
                     httpParam ("&", "realm"                 , $_realm) +
                           httpParam("&", "event", request.getParameter(key)) +
                           httpParam("&", "date", request.getParameter(prefix+"_fld_2_"+suffix)) +
                           httpParam("&", "place", request.getParameter(prefix+"_fld_3_"+suffix));
                  $_retValue = httpRequest ("POST", "user.bioEvents.new", params);
                  if ($_retValue.indexOf("<failed>") == 0)
                  {
        		        $_document = createDocument($_retValue);
                    throw new Exception(xpathEvaluate($_document, "/failed/message"));
                  }
                }
      		    }
            }
            else if (($_formTab == 0) && ($_formSubtab == 6))
            {
              params = httpParam( "", "sid", $_sid) + httpParam ("&", "realm", $_realm);
              $_retValue = httpRequest ("POST", "user.favorites.delete", params);
              if ($_retValue.indexOf("<failed>") == 0)
              {
    		        $_document = createDocument($_retValue);
                throw new Exception(xpathEvaluate($_document, "/failed/message"));
              }
              params = httpParam( "", "sid", $_sid) + httpParam ("&", "realm", $_realm) + httpParam("&", "favorites", request.getParameter("favorites"));
              $_retValue = httpRequest ("POST", "user.favorites.new", params);
              if ($_retValue.indexOf("<failed>") == 0)
              {
    		        $_document = createDocument($_retValue);
                throw new Exception(xpathEvaluate($_document, "/failed/message"));
              }
            }
            else
            {
              params = httpParam ( "", "sid", $_sid) + httpParam ("&", "realm", $_realm);
              if ($_formTab == 0)
              {
                if ($_formSubtab == 0)
                {
                  // Import
                  if ("1".equals(request.getParameter("cb_item_i_name")))
                    params += httpParam ("&", "nickName", request.getParameter("i_nickName"));
                  if ("1".equals(request.getParameter("cb_item_i_title")))
                    params += httpParam ("&", "title=", request.getParameter("i_title"));
                  if ("1".equals(request.getParameter("cb_item_i_firstName")))
                    params += httpParam ("&", "firstName", request.getParameter("i_firstName"));
                  if ("1".equals(request.getParameter("cb_item_i_lastName")))
                    params += httpParam ("&", "lastName", request.getParameter("i_lastName"));
                  if ("1".equals(request.getParameter("cb_item_i_fullName")))
                    params += httpParam ("&", "fullName", request.getParameter("i_fullName"));
                  if ("1".equals(request.getParameter("cb_item_i_gender")))
                    params += httpParam ("&", "gender", request.getParameter("i_gender"));
                  if ("1".equals(request.getParameter("cb_item_i_mail")))
                    params += httpParam ("&", "mail", request.getParameter("i_mail"));
                  if ("1".equals(request.getParameter("cb_item_i_birthday")))
                    params += httpParam ("&", "birthday", request.getParameter("i_birthday"));
                  if ("1".equals(request.getParameter("cb_item_i_homepage")))
                    params += httpParam ("&", "homepage", request.getParameter("i_homepage"));
                  if ("1".equals(request.getParameter("cb_item_i_icq")))
                    params += httpParam ("&", "icq", request.getParameter("i_icq"));
                  if ("1".equals(request.getParameter("cb_item_i_aim")))
                    params += httpParam ("&", "aim", request.getParameter("i_aim"));
                  if ("1".equals(request.getParameter("cb_item_i_yahoo")))
                    params += httpParam ("&", "yahoo", request.getParameter("i_yahoo"));
                  if ("1".equals(request.getParameter("cb_item_i_msn")))
                    params += httpParam ("&", "msn", request.getParameter("i_msn"));
                  if ("1".equals(request.getParameter("cb_item_i_skype")))
                    params += httpParam ("&", "skype", request.getParameter("i_skype"));
                  if ("1".equals(request.getParameter("cb_item_i_homelat")))
                    params += httpParam ("&", "homeLatitude", request.getParameter("i_homelat"));
                  if ("1".equals(request.getParameter("cb_item_i_homelng")))
                    params += httpParam ("&", "homeLongitude", request.getParameter("i_homelng"));
                  if ("1".equals(request.getParameter("cb_item_i_homelng")))
                    params += httpParam ("&", "homePhone", request.getParameter("i_homePhone"));
                  if ("1".equals(request.getParameter("cb_item_i_businessOrganization")))
                    params += httpParam ("&", "businessOrganization", request.getParameter("i_businessOrganization"));
                  if ("1".equals(request.getParameter("cb_item_i_businessHomePage")))
                    params += httpParam ("&", "businessHomePage", request.getParameter("i_businessHomePage"));
                  if ("1".equals(request.getParameter("cb_item_i_sumary")))
                    params += httpParam ("&", "sumary", request.getParameter("i_sumary"));
                  if ("1".equals(request.getParameter("cb_item_i_tags")))
                    params += httpParam ("&", "tags", request.getParameter("i_tags"));
                  if ("1".equals(request.getParameter("cb_item_i_interests")))
                    params += httpParam ("&", "interests", request.getParameter("i_interests"));
                  if ("1".equals(request.getParameter("cb_item_i_topicInterests")))
                    params += httpParam ("&", "topicInterests", request.getParameter("i_topicInterests"));
                }
                else if ($_formSubtab == 1)
                {
                  params +=
                       httpParam ("&", "nickName"              , request.getParameter("pf_nickName")) +
                     httpParam ("&", "mail"                  , request.getParameter("pf_mail")) +
                     httpParam ("&", "title"                 , request.getParameter("pf_title")) +
                     httpParam ("&", "firstName"             , request.getParameter("pf_firstName")) +
                     httpParam ("&", "lastName"              , request.getParameter("pf_lastName")) +
                     httpParam ("&", "fullName"              , request.getParameter("pf_fullName")) +
                     httpParam ("&", "gender"                , request.getParameter("pf_gender")) +
                     httpParam ("&", "birthday"              , request.getParameter("pf_birthday")) +
                     httpParam ("&", "homepage"              , request.getParameter("pf_homepage")) +
                       httpParam ("&", "mailSignature"         , request.getParameter("pf_mailSignature")) +
                       httpParam ("&", "sumary"                , request.getParameter("pf_sumary"));

                  tmp = "";
                  keys = request.getParameterNames();
          		    while (keys.hasMoreElements() )
          		    {
          		      String key = (String)keys.nextElement();
                    if (key.indexOf("x1_fld_1_") == 0)
                      tmp += request.getParameter(key) + "\n";
          		    }
                  params += httpParam ("&", "webIDs", tmp);
                  keys = request.getParameterNames();
                  tmp = "";
          		    while (keys.hasMoreElements() )
          		    {
          		      String key = (String)keys.nextElement();
                    if (key.indexOf("x2_fld_1_") == 0)
                    {
                      suffix = key.replace("x2_fld_1_", "");
                      tmp += request.getParameter(key) + ";" + request.getParameter("x2_fld_2_"+suffix) + "\n";
                    }
          		    }
                  params += httpParam ("&", "interests", tmp);
                  keys = request.getParameterNames();
                  tmp = "";
          		    while (keys.hasMoreElements() )
          		    {
          		      String key = (String)keys.nextElement();
                    if (key.indexOf("x3_fld_1_") == 0)
                    {
                      suffix = key.replace("x3_fld_1_", "");
                      tmp += request.getParameter(key) + ";" + request.getParameter("x3_fld_2_"+suffix) + "\n";
                    }
          		    }
                  params += httpParam ("&", "topicInterests", tmp);
                }
                if ($_formSubtab == 2)
                {
                  params +=
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
                       httpParam ("&", "homeMobile"            , request.getParameter("pf_homeMobile"));
                }
                if ($_formSubtab == 5)
                {
                  params +=
                       httpParam ("&", "icq"                   , request.getParameter("pf_icq")) +
                       httpParam ("&", "skype"                 , request.getParameter("pf_skype")) +
                       httpParam ("&", "yahoo"                 , request.getParameter("pf_yahoo")) +
                       httpParam ("&", "aim"                   , request.getParameter("pf_aim")) +
                       httpParam ("&", "msn"                   , request.getParameter("pf_msn"));
                  keys = request.getParameterNames();
                  tmp = "";
          		    while (keys.hasMoreElements() )
          		    {
          		      String key = (String)keys.nextElement();
                    if (key.indexOf("x6_fld_1_") == 0)
                    {
                      suffix = key.replace("x6_fld_1_", "");
                      tmp += request.getParameter(key) + ";" + request.getParameter("x6_fld_2_"+suffix) + "\n";
                    }
          		    }
                  params += httpParam ("&", "messaging", tmp);
                }
              }
              if ($_formTab == 1)
              {
                if ($_formSubtab == 0)
                {
                  params +=
                     httpParam ("&", "businessIndustry"      , request.getParameter("pf_businessIndustry")) +
                     httpParam ("&", "businessOrganization"  , request.getParameter("pf_businessOrganization")) +
                     httpParam ("&", "businessHomePage"      , request.getParameter("pf_businessHomePage")) +
                     httpParam ("&", "businessJob"           , request.getParameter("pf_businessJob")) +
                       httpParam ("&", "businessRegNo"         , request.getParameter("pf_businessRegNo")) +
                       httpParam ("&", "businessCareer"        , request.getParameter("pf_businessCareer")) +
                       httpParam ("&", "businessEmployees"     , request.getParameter("pf_businessEmployees")) +
                       httpParam ("&", "businessVendor"        , request.getParameter("pf_businessVendor")) +
                       httpParam ("&", "businessService"       , request.getParameter("pf_businessService")) +
                       httpParam ("&", "businessOther"         , request.getParameter("pf_businessOther")) +
                       httpParam ("&", "businessNetwork"       , request.getParameter("pf_businessNetwork")) +
                       httpParam ("&", "businessResume"        , request.getParameter("pf_businessResume"));
                }
                if ($_formSubtab == 1)
                {
                  params +=
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
                       httpParam ("&", "businessMobile"        , request.getParameter("pf_businessMobile"));
                }
                if ($_formSubtab == 3)
                {
                  params +=
                       httpParam ("&", "businessIcq"          , request.getParameter("pf_businessIcq")) +
                       httpParam ("&", "businessSkype"        , request.getParameter("pf_businessSkype")) +
                       httpParam ("&", "businessYahoo"        , request.getParameter("pf_businessYahoo")) +
                       httpParam ("&", "businessAim"          , request.getParameter("pf_businessAim")) +
                       httpParam ("&", "businessMsn"          , request.getParameter("pf_businessMsn"));
                  keys = request.getParameterNames();
                  tmp = "";
          		    while (keys.hasMoreElements() )
          		    {
          		      String key = (String)keys.nextElement();
                    if (key.indexOf("y2_fld_1_") == 0)
                    {
                      suffix = key.replace("y2_fld_1_", "");
                      tmp += request.getParameter(key) + ";" + request.getParameter("y2_fld_2_"+suffix) + "\n";
                    }
          		    }
                  params += httpParam ("&", "businessMessaging", tmp);
                }
              }
              if ($_formTab == 2)
              {
                String securityNo = request.getParameter("securityNo");
                if (securityNo == null)
                  securityNo = "";

                if (securityNo == "1")
                  params +=
                       httpParam ("&", "securityOpenID"     , request.getParameter("pf_securityOpenID"));

                if (securityNo == "2")
                  params +=
                     httpParam ("&", "securitySecretQuestion", request.getParameter("pf_securitySecretQuestion")) +
                       httpParam ("&", "securitySecretAnswer"  , request.getParameter("pf_securitySecretAnswer"));

                if (securityNo == "3")
                  params +=
                       httpParam ("&", "securitySiocLimit"     , request.getParameter("pf_securitySiocLimit"));
              }
            $_retValue = httpRequest ("POST", "user.update.fields", params);
            if ($_retValue.indexOf("<failed>") == 0)
          {
  		        $_document = createDocument($_retValue);
              throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
            }
            if (request.getParameter("pf_next") != null)
            {
              $_formSubtab += 1;
              if (
                  (($_formTab == 1) && ($_formSubtab > 3)) ||
                  ($_formTab > 1)
                 )
              {
                $_formTab += 1;
                $_formSubtab = 0;
              }
            }
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

      if ($_form.equals("user"))
      {
        if (request.getParameter("uf_profile") != null)
        {
          $_form = "profile";
          $_formTab = 0;
          $_formSubtab = 0;
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
      $_error = "Failure: " + e.getMessage();
    }
  %>
  <body>
    <form name="page_form" id="page_form" method="post" action="users.jsp">
      <input type="hidden" name="mode" id="mode" value="jsp" />
      <input type="hidden" name="sid" id="sid" value="<% out.print($_sid); %>" />
      <input type="hidden" name="realm" id="realm" value="<% out.print($_realm); %>" />
      <input type="hidden" name="form" id="form" value="<% out.print($_form); %>" />
      <input type="hidden" name="formTab" id="formTab" value="<% out.print($_formTab); %>" />
      <input type="hidden" name="formSubtab" id="formSubtab" value="<% out.print($_formSubtab); %>" />
      <input type="hidden" name="formMode" id="formMode" value="<% out.print($_formMode); %>" />
      <input type="hidden" name="items" id="items" value="" />
      <input type="hidden" name="securityNo" id="securityNo" value="" />
      <div id="ob">
        <div id="ob_left"><% outFormTitle (out, $_form); %></div>
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
            <td valign="top">
              <img class="logo" src="/ods/images/odslogo_200.png" /><br />
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
              <div id="pf" class="form" style="width: 100%;">
                <%
                  if ($_error != "")
                  {
                    out.print("<div class=\"error\">" + $_error + "</div>");
                  }
                %>
                <div class="header">
                  Update user profile
                </div>
                <ul id="pf_tabs" class="tabs">
                  <li id="pf_tab_0" title="Personal">Personal</li>
                  <li id="pf_tab_1" title="Business">Business</li>
                  <li id="pf_tab_2" title="Security">Security</li>
                </ul>
                <div style="min-height: 180px; border-top: 1px solid #aaa; margin: -13px 5px 5px 5px;">
                  <div id="pf_page_0" class="tabContent" style="display:none;">
                    <ul id="pf_tabs_0" class="tabs">
                      <li id="pf_tab_0_0" title="Import">Import</li>
                      <li id="pf_tab_0_1" title="Main">Main</li>
                      <li id="pf_tab_0_2" title="Address">Address</li>
                      <li id="pf_tab_0_3" title="Online Accounts">Online Accounts</li>
                      <li id="pf_tab_0_4" title="Biographical Events">Biographical Events</li>
                      <li id="pf_tab_0_5" title="Messaging Services">Messaging Services</li>
                      <li id="pf_tab_0_6" title="Favorite Things">Favorite Things</li>
                      <li id="pf_tab_0_7" title="Creator Of">Creator Of</li>
                      <li id="pf_tab_0_8" title="My Offers">My Offers</li>
                      <li id="pf_tab_0_9" title="Offers I Seek">Offers I Seek</li>
                    </ul>
                    <div style="min-height: 180px; border-top: 1px solid #aaa; margin: -13px 5px 5px 5px;">
                      <div id="pf_page_0_0" class="tabContent" style="display:none;">
                    <table class="form" cellspacing="5">
                      <tr>
                        <th>
                              <label for="pf_foaf">Personal URI (Web ID)</label>
                            </th>
                            <td>
                              <input type="text" name="pf_foaf" value="" id="pf_foaf" style="width: 400px;" />
                              <input type="button" value="Import" onclick="javascript: pfGetFOAFData($v('pf_foaf')); return false;" class="button" />
                              <img id="pf_import_image" alt="Import FOAF Data" src="/ods/images/oat/Ajax_throbber.gif" style="display: none" />
                            </td>
                          </tr>
                        </table>
                        <table id="i_tbl" class="listing" style="display: none;">
                          <thead>
                            <tr class="listing_header_row">
                              <th width="1%"><input type="checkbox" name="cb_all" value="Select All" onclick="selectAllCheckboxes(this, 'cb_item')" /></th>
                              <th>Field</th>
                              <th>Value</th>
                            </tr>
                          </thead>
                          <tbody id="i_tbody">
                          </tbody>
                        </table>
                      </div>
                      <div id="pf_page_0_1" class="tabContent" style="display:none;">
                        <table class="form" cellspacing="5">
                          <tr>
                            <th>
                              <label for="pf_loginName">Login Name</label>
                            </th>
                            <td>
                              <% out.print(xpathEvaluate($_document, "/user/name")); %>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_nickName">Nick Name</label>
                            </th>
                            <td>
                              <input type="text" name="pf_nickName" value="<% out.print(xpathEvaluate($_document, "/user/nickName")); %>" id="pf_nickName" style="width: 220px;" />
                            </td>
                          </tr>
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
                          <input name="pf_birthday" id="pf_birthday" value="<% out.print(xpathEvaluate($_document, "/user/birthday")); %>" onclick="datePopup('pf_birthday');"/>
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
                      <tr>
                            <th>
                              <label for="pf_foaf">Other Personal URIs (Web IDs)</label>
                        </th>
                        <td nowrap="nowrap">
                              <table>
                                <tr>
                                  <td width="600px" style="padding: 0px;">
                                    <table id="x1_tbl" class="listing">
                                      <thead>
                                        <tr class="listing_header_row">
                                          <th>
                                            URI
                                          </th>
                                          <th width="80px">
                                            Action
                                          </th>
                                        </tr>
                                      </thead>
                                      <tr id="x1_tr_no" style="display: none;"><td colspan="2"><b>No Personal URIs</b></td></tr>
                                      <script type="text/javascript">
                                        OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){pfShowRows("x1", '<% out.print(xpathEvaluate($_document, "/user/webIDs").replace("\n", "\\n")); %>', ["\n"], function(prefix, val1){updateRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _url_ _canEmpty_', onBlur: function(){validateField(this);}}});});});
                                      </script>
                                    </table>
                                  </td>
                                  <td valign="top" nowrap="nowrap">
                                    <input type="button" value="Add" onclick="javascript: updateRow('x1', null, {fld_1: {className: '_validate_ _url_ _canEmpty_', onBlur: function(){validateField(this);}}});" />
                                  </td>
                                </tr>
                              </table>
                        </td>
                      </tr>
                      <tr>
                        <th>
                              <label for="pf_mailSignature">Mail Signature</label>
                        </th>
                            <td>
                              <textarea name="pf_mailSignature" id="pf_mailSignature" style="width: 400px;"><% out.print(xpathEvaluate($_document, "/user/mailSignature")); %></textarea>
                        </td>
                      </tr>
                      <tr>
                        <th>
                              <label for="pf_summary">Summary</label>
                        </th>
                            <td>
                              <textarea name="pf_summary" id="pf_summary" style="width: 400px;"><% out.print(xpathEvaluate($_document, "/user/summary")); %></textarea>
                        </td>
                      </tr>
                      <tr>
                        <th>
                              <label for="pf_foaf">Web page URL indicating a topic of interest</label>
                        </th>
                        <td nowrap="nowrap">
                              <table>
                                <tr>
                                  <td width="600px" style="padding: 0px;">
                                    <table id="x2_tbl" class="listing">
                                      <thead>
                                        <tr class="listing_header_row">
                                          <th>
                                            URL
                                          </th>
                                          <th>
                                            Label
                                          </th>
                                          <th width="80px">
                                            Action
                                          </th>
                                        </tr>
                                      </thead>
                                      <tr id="x2_tr_no" style="display: none;"><td colspan="3"><b>No Topic of Interests</b></td></tr>
                                      <script type="text/javascript">
                                        OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){pfShowRows("x2", '<% out.print(xpathEvaluate($_document, "/user/interests").replace("\n", "\\n")); %>', ["\n", ";"], function(prefix, val1, val2){updateRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _url_ _canEmpty_', onBlur: function(){validateField(this);}}, fld_2: {value: val2}});});});
                                      </script>
                                    </table>
                                  </td>
                                  <td valign="top" nowrap="nowrap">
                                    <input type="button" value="Add" onclick="javascript: updateRow('x2', null, {fld_1: {className: '_validate_ _url_ _canEmpty_', onBlur: function(){validateField(this);}}, fld_2: {}});" />
                                  </td>
                                </tr>
                              </table>
                        </td>
                      </tr>
                      <tr>
                        <th>
                              <label for="pf_foaf">Resource URI indicating thing of interest</label>
                        </th>
                        <td nowrap="nowrap">
                              <table>
                                <tr>
                                  <td width="600px" style="padding: 0px;">
                                    <table id="x3_tbl" class="listing">
                                      <thead>
                                        <tr class="listing_header_row">
                                          <th>
                                            URL
                                          </th>
                                          <th>
                                            Label
                                          </th>
                                          <th width="80px">
                                            Action
                                          </th>
                                        </tr>
                                      </thead>
                                      <tr id="x3_tr_no" style="display: none;"><td colspan="3"><b>No Thing of Interests</b></td></tr>
                                      <script type="text/javascript">
                                        OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){pfShowRows("x3", '<% out.print(xpathEvaluate($_document, "/user/topicInterests").replace("\n", "\\n")); %>', ["\n", ";"], function(prefix, val1, val2){updateRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _url_ _canEmpty_', onBlur: function(){validateField(this);}}, fld_2: {value: val2}});});});
                                      </script>
                                    </table>
                                  </td>
                                  <td valign="top" nowrap="nowrap">
                                    <input type="button" value="Add" onclick="javascript: updateRow('x3', null, {fld_1: {className: '_validate_ _url_ _canEmpty_', onBlur: function(){validateField(this);}}, fld_2: {}});" />
                                  </td>
                                </tr>
                              </table>
                        </td>
                      </tr>
                    </table>
                  </div>

                      <div id="pf_page_0_2" class="tabContent" style="display:none;">
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

                      <div id="pf_page_0_3" class="tabContent" style="display:none;">
                    <table class="form" cellspacing="5">
                      <tr>
                            <td width="600px">
                              <table id="x4_tbl" class="listing">
                                <thead>
                                  <tr class="listing_header_row">
                                    <th>
                                      Select from Service List ot Type New One
                        </th>
                                    <th>
                                      Member Home Page URL
                                    </th>
                                    <th width="80px">
                                      Action
                                    </th>
                                  </tr>
                                </thead>
                                <tr id="x4_tr_no" style="display: none;"><td colspan="3"><b>No Services</b></td></tr>
                                <script type="text/javascript">
                                  OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){pfShowOnlineAccounts("x4", "P", function(prefix, val0, val1, val2){updateRow(prefix, null, {fld_0: {value: val0}, fld_1: {mode: 1, value: val1, className: '_validate_ _url_ _canEmpty_', onBlur: function(){validateField(this);}}, fld_2: {value: val2}});});});
                                </script>
                              </table>
                            </td>
                            <td valign="top" nowrap="1">
                              <input type="button" value="Add" onclick="javascript: updateRow('x4', null, {fld_1: {mode: 1}, fld_2: {className: '_validate_ _url_ _canEmpty_', onBlur: function(){validateField(this);}}});" />
                        </td>
                      </tr>
                        </table>
                      </div>

                      <div id="pf_page_0_4" class="tabContent" style="display:none;">
                        <table class="form" cellspacing="5">
                      <tr>
                            <td width="600px">
                              <table id="x5_tbl" class="listing">
                                <thead>
                                  <tr class="listing_header_row">
                                    <th width="15%">
                                      Event
                                    </th>
                                    <th width="15%">
                                      Date
                                    </th>
                        <th>
                                      Place
                        </th>
                                    <th width="80px">
                                      Action
                                    </th>
                                  </tr>
                                </thead>
                                <tr id="x5_tr_no" style="display: none;"><td colspan="4"><b>No Biographical Events</b></td></tr>
                                <script type="text/javascript">
                                  OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){pfShowBioEvents("x5", function(prefix, val0, val1, val2, val3){updateRow(prefix, null, {fld_0: {value: val0}, fld_1: {mode: 4, value: val1}, fld_2: {value: val2}, fld_3: {value: val3}});});});
                                </script>
                              </table>
                            </td>
                            <td valign="top" nowrap="1">
                              <input type="button" value="Add" onclick="javascript: updateRow('x5', null, {fld_1: {mode: 4}, fld_2: {}, fld_3: {}});" />
                        </td>
                      </tr>
                        </table>
                      </div>

                      <div id="pf_page_0_5" class="tabContent" style="display:none;">
                        <table id="x6_tbl" class="form" cellspacing="5">
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
                            <td width="40%">
                        </td>
                      </tr>
                          <script type="text/javascript">
                            OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){pfShowRows("x6", '<% out.print(xpathEvaluate($_document, "/user/messaging").replace("\n", "\\n")); %>', ["\n", ";"], function(prefix, val1, val2){updateRow(prefix, null, {fld_1: {value: val1}, fld_2: {value: val2, cssText: 'width: 220px;'}});});});
                          </script>
                        </table>
                        <input type="button" value="Add" onclick="javascript: updateRow('x6', null, {fld_1: {}, fld_2: {cssText: 'width: 220px;'}});" />
                      </div>

                      <div id="pf_page_0_6" class="tabContent" style="display:none;">
                        <table class="form" cellspacing="5">
                      <tr>
                            <td width="600px">
                              <table id="r_tbl" class="listing">
                                <thead>
                                  <tr class="listing_header_row">
                        <th>
                                      <div style="width: 16px;"><![CDATA[&nbsp;]]></div>
                        </th>
                                    <th width="100%">
                                      Favorite Type
                        </th>
                                    <th width="80px">
                                      Action
                                    </th>
                                  </tr>
                                </thead>
                                <tbody id="r_tbody">
                                  <tr id="r_tr_no"><td></td><td colspan="2"><b><i>No Favorite Types</i></b></td></tr>
                                  <script type="text/javascript">
                                    OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){pfShowFavorites();});
                                  </script>
                                </tbody>
                              </table>
                            </td>
                            <td valign="top" nowrap="nowrap">
                              <input type="button" value="Add" onclick="javascript: updateRow('r', null, {fld_1: {mode: 12, cssText: 'display: none;'}, fld_2: {mode: 5, labelValue: 'New Type: ', cssText: 'width: 95%;'}, btn_1: {mode: 5, cssText: 'margin-left: 2px; margin-right: 2px;'}, btn_2: {mode: 6, cssText: 'margin-left: 2px; margin-right: 2px;'}});" />
                        </td>
                      </tr>
                        </table>
                      </div>
                      <%
                      if ($_formTab == 0)
                      {
                        if ($_formSubtab == 7)
                        {
                      %>
                      <div id="pf_page_0_7" class="tabContent" style="display:none;">
                        <h3>Creator Of</h3>
                        <%
                          if ($_formMode == "")
                          {
                        %>
                        <div id="pf07_list">
                          <div style="padding: 0 0 0.5em 0;">
                            <span onclick="javascript: $('formMode').value = 'new'; $('page_form').submit();" class="button pointer"><img class="button" border="0" title="Add Creator Of" alt="Add Creator Of" src="/ods/images/icons/add_16.png"> Add</span>
                          </div>
                      	  <table id="pf07_tbl" class="listing">
                      	    <thead>
                      	      <tr class="listing_header_row">
                        		    <th>Property</th>
                        		    <th>Description</th>
                        		    <th width="1%" nowrap="nowrap">Action</th>
                      	      </tr>
                            </thead>
                      	    <tbody id="pf07_tbody">
                              <script type="text/javascript">
                                OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){pfShowMades();});
                              </script>
                      	    </tbody>
                          </table>
                        </div>
                        <%
                          }
                          else
                          {
                            if ($_formMode.equals("edit"))
                              out.print("<input type=\"hidden\" id=\"pf07_id\" name=\"pf07_id\" value=\"" + ((request.getParameter("pf07_id") != null) ? request.getParameter("pf07_id"): "0") + "\" />");
                        %>
                        <div id="pf07_form">
                          <table class="form" cellspacing="5">
                            <tr>
                              <th width="25%">
                                Property
                              </th>
                              <td id="if_opt">
                                <script type="text/javascript">
                                  function p_init ()
                                  {
                                    var fld = new OAT.Combolist([]);
                                    fld.input.name = 'pf07_property';
                                    fld.input.id = fld.input.name;
                                    fld.input.className = '_validate_';
                                    fld.input.style.width = "400px";
                                    $("if_opt").appendChild(fld.div);
                                    fld.addOption("foaf:made");
                                    fld.addOption("dc:creator");
                                    fld.addOption("sioc:owner");
                                  }
                                  OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){OAT.Loader.loadFeatures(["combolist"], p_init);});
                                </script>
                              </td>
                            </tr>
                            <tr>
                              <th>
                                URI
                              </th>
                              <td>
                                <input type="text" name="pf07_url" id="pf07_url" value="" class="_validate_ _url_ _canEmpty_" style="width: 400px;">
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Description
                              </th>
                              <td>
                                <textarea name="pf07_description" id="pf07_description" class="_validate_" style="width: 400px;"></textarea>
                              </td>
                            </tr>
                          </table>
                          <script type="text/javascript">
                            OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){pfShowMade();});
                          </script>
                          <div class="footer">
                            <input type="submit" name="pf_cancel2" value="Cancel" onclick="needToConfirm = false; "/>
                            <input type="submit" name="pf_update07" value="Save" onclick="needToConfirm = false; return validateInputs(this);"/>
                          </div>
                        </div>
                        <%
                          }
                        %>
                      </div>
                      <%
                        }
                        else if ($_formSubtab == 8)
                        {
                      %>
                      <div id="pf_page_0_8" class="tabContent" style="display:none;">
                        <h3>My Offers</h3>
                        <%
                          if ($_formMode == "")
                          {
                        %>
                        <div id="pf08_list">
                          <div style="padding: 0 0 0.5em 0;">
                            <span onclick="javascript: $('formMode').value = 'new'; $('page_form').submit();" class="button pointer"><img class="button" border="0" title="Add Offer" alt="Add Offer" src="/ods/images/icons/add_16.png"> Add</span>
                          </div>
                      	  <table id="pf08_tbl" class="listing">
                      	    <thead>
                      	      <tr class="listing_header_row">
                        		    <th>Name</th>
                        		    <th>Description</th>
                        		    <th width="1%" nowrap="nowrap">Action</th>
                      	      </tr>
                            </thead>
                      	    <tbody id="pf08_tbody">
                              <script type="text/javascript">
                                OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){pfShowOffers();});
                              </script>
                      	    </tbody>
                          </table>
                        </div>
                        <%
                          }
                          else
                          {
                            out.print("<input type=\"hidden\" id=\"pf08_id\" name=\"pf08_id\" value=\"" + ((request.getParameter("pf08_id") != null) ? request.getParameter("pf08_id"): "0") + "\" />");
                        %>
                        <div id="pf08_form">
                          <table class="form" cellspacing="5">
                            <tr>
                              <th width="25%">
                                Name
                              </th>
                              <td>
                                <input type="text" name="pf08_name" id="pf08_name" value="" class="_validate_" style="width: 400px;">
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Comment
                              </th>
                              <td>
                                <textarea name="pf08_comment" id="pf08_comment" class="_validate_ _canEmpty_" style="width: 400px;"></textarea>
                              </td>
                            </tr>
                  				  <tr>
                  				    <th valign="top">
                  		          Products
                  		        </th>
                  		        <td width="800px">
                                <table id="ol_tbl" class="listing">
                                  <tbody id="ol_tbody">
                                  </tbody>
                                </table>
                                <input type="hidden" id="ol_no" name="ol_no" value="1" />
                              </td>
                            </tr>
                          </table>
                          <script type="text/javascript">
                            OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){pfShowOffer();});
                          </script>
                          <div class="footer">
                            <input type="submit" name="pf_cancel2" value="Cancel" onclick="needToConfirm = false;"/>
                            <input type="submit" name="pf_update08" value="Save" onclick="myBeforeSubmit(); return validateInputs(this);"/>
                          </div>
                        </div>
                        <%
                          }
                        %>
                      </div>
                      <%
                        }
                        else if ($_formSubtab == 9)
                        {
                      %>
                      <div id="pf_page_0_9" class="tabContent" style="display:none;">
                        <h3>Offers I Seek</h3>
                        <%
                          if ($_formMode == "")
                          {
                        %>
                        <div id="pf09_list">
                          <div style="padding: 0 0 0.5em 0;">
                            <span onclick="javascript: $('formMode').value = 'new'; $('page_form').submit();" class="button pointer"><img class="button" border="0" title="Add Seek" alt="Add Seek" src="/ods/images/icons/add_16.png"> Add</span>
                          </div>
                      	  <table id="pf09_tbl" class="listing">
                      	    <thead>
                      	      <tr class="listing_header_row">
                        		    <th>Name</th>
                        		    <th>Description</th>
                        		    <th width="1%" nowrap="nowrap">Action</th>
                      	      </tr>
                            </thead>
                      	    <tbody id="pf09_tbody">
                              <script type="text/javascript">
                                OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){pfShowSeeks();});
                              </script>
                      	    </tbody>
                          </table>
                        </div>
                        <%
                          }
                          else
                          {
                            out.print("<input type=\"hidden\" id=\"pf09_id\" name=\"pf09_id\" value=\"" + ((request.getParameter("pf09_id") != null) ? request.getParameter("pf09_id"): "0") + "\" />");
                        %>
                        <div id="pf09_form">
                          <table class="form" cellspacing="5">
                            <tr>
                              <th width="25%">
                                Name
                              </th>
                              <td>
                                <input type="text" name="pf09_name" id="pf09_name" value="" class="_validate_" style="width: 400px;">
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Comment
                              </th>
                              <td>
                                <textarea name="pf09_comment" id="pf09_comment" class="_validate_ _canEmpty_" style="width: 400px;"></textarea>
                              </td>
                            </tr>
                  				  <tr>
                  				    <th valign="top">
                  		          Products
                  		        </th>
                  		        <td width="800px">
                                <table id="wl_tbl" class="listing">
                                  <tbody id="wl_tbody">
                                  </tbody>
                                </table>
                                <input type="hidden" id="wl_no" name="wl_no" value="1" />
                              </td>
                            </tr>
                          </table>
                          <script type="text/javascript">
                            OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){pfShowSeek();});
                          </script>
                          <div class="footer">
                            <input type="submit" name="pf_cancel2" value="Cancel" onclick="needToConfirm = false;"/>
                            <input type="submit" name="pf_update09" value="Save" onclick="myBeforeSubmit(); return validateInputs(this);"/>
                          </div>
                        </div>
                        <?vsp
                          }
                        ?>
                      </div>
                        <%
                          }
                        %>
                      </div>
                      <%
                        }
                        else
                        {
                      %>
                      <div class="footer">
                        <input type="submit" name="pf_cancel" value="Cancel" onclick="needToConfirm = false;"/>
                        <input type="submit" name="pf_update" value="Save" onclick="myBeforeSubmit ();"/>
                        <input type="submit" name="pf_next" value="Save & Next" onclick="myBeforeSubmit ();"/>
                      </div>
                      <%
                        }
                      }
                      %>
                    </div>
                  </div>

                  <div id="pf_page_1" class="tabContent" style="display:none;">
                    <ul id="pf_tabs_1" class="tabs">
                      <li id="pf_tab_1_0" title="Main">Main</li>
                      <li id="pf_tab_1_1" title="Address">Address</li>
                      <li id="pf_tab_1_2" title="Online Accounts">Online Accounts</li>
                      <li id="pf_tab_1_3" title="Messaging Services">Messaging Services</li>
                    </ul>
                    <div style="min-height: 180px; border-top: 1px solid #aaa; margin: -13px 5px 5px 5px;">
                      <div id="pf_page_1_0" class="tabContent" style="display:none;">
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
                          <textarea name="pf_businessResume" id="pf_businessResume" style="width: 400px;"><% out.print(xpathEvaluate($_document, "/user/businessResume")); %></textarea>
                        </td>
                      </tr>
                        </table>
                      </div>

                      <div id="pf_page_1_1" class="tabContent" style="display:none;">
                        <table class="form" cellspacing="5">
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
                        </table>
                      </div>
                      <div id="pf_page_1_2" class="tabContent" style="display:none;">
                        <table class="form" cellspacing="5">
                          <tr>
                            <td width="600px">
                              <table id="y1_tbl" class="listing">
                                <thead>
                                  <tr class="listing_header_row">
                                    <th>
                                      Select from Service List ot Type New One
                                    </th>
                                    <th>
                                      Member Home Page URL
                                    </th>
                                    <th width="80px">
                                      Action
                                    </th>
                                  </tr>
                                </thead>
                                <tr id="y1_tr_no" style="display: none;"><td colspan="3"><b>No Services</b></td></tr>
                                <script type="text/javascript">
                                  OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){pfShowOnlineAccounts("y1", "B", function(prefix, val0, val1, val2){updateRow(prefix, null, {fld_0: {value: val0}, fld_1: {mode: 1, value: val1, className: '_validate_ _url_ _canEmpty_', onBlur: function(){validateField(this);}}, fld_2: {value: val2}});});});
                                </script>
                              </table>
                            </td>
                            <td valign="top" nowrap="1">
                              <input type="button" value="Add" onclick="javascript: updateRow('y1', null, {fld_1: {mode: 1}, fld_2: {className: '_validate_ _url_ _canEmpty_', onBlur: function(){validateField(this);}}});" />
                            </td>
                          </tr>
                        </table>
                      </div>

                      <div id="pf_page_1_3" class="tabContent" style="display:none;">
                        <table id="y2_tbl" class="form" cellspacing="5">
                          <tr>
                            <th width="30%">
                              <label for="pf_businessIcq">ICQ</label>
                            </th>
                            <td colspan="2">
                              <input type="text" name="pf_businessIcq" value="<% out.print(xpathEvaluate($_document, "/user/businessIcq")); %>" id="pf_icq" style="width: 220px;" />
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businessSkype">Skype</label>
                            </th>
                            <td colspan="2">
                              <input type="text" name="pf_businessSkype" value="<% out.print(xpathEvaluate($_document, "/user/businessSkype")); %>" id="pf_businessSkype" style="width: 220px;" />
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businessYahoo">Yahoo</label>
                            </th>
                            <td colspan="2">
                              <input type="text" name="pf_businessYahoo" value="<% out.print(xpathEvaluate($_document, "/user/businessYahoo")); %>" id="pf_businessYahoo" style="width: 220px;" />
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businessAim">AIM</label>
                            </th>
                            <td colspan="2">
                              <input type="text" name="pf_businessAim" value="<% out.print(xpathEvaluate($_document, "/user/businessAim")); %>" id="pf_businessAim" style="width: 220px;" />
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businessMsn">MSN</label>
                            </th>
                            <td>
                              <input type="text" name="pf_businessMsn" value="<% out.print(xpathEvaluate($_document, "/user/businessMsn")); %>" id="pf_businessMsn" style="width: 220px;" />
                            </td>
                            <td width="40%">
                        </td>
                      </tr>
                          <script type="text/javascript">
                            OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function (){pfShowRows("y2", '<% out.print(xpathEvaluate($_document, "/user/businessMessaging").replace("\n", "\\n")); %>', ["\n", ";"], function(prefix, val1, val2){updateRow(prefix, null, {fld_1: {value: val1}, fld_2: {value: val2, cssText: 'width: 220px;'}});});});
                          </script>
                    </table>
                        <input type="button" value="Add" onclick="javascript: updateRow('y2', null, {fld_1: {}, fld_2: {cssText: 'width: 220px;'}});" />
                  </div>

                      <div class="footer">
                        <input type="submit" name="pf_cancel" value="Cancel" onclick="needToConfirm = false;"/>
                        <input type="submit" name="pf_update" value="Save" onclick="myBeforeSubmit ();"/>
                        <input type="submit" name="pf_next" value="Save & Next" onclick="myBeforeSubmit ();"/>
                      </div>
                    </div>
                  </div>

                  <div id="pf_page_2" class="tabContent" style="display:none;">
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
                        </td>
                      </tr>
                      <tr>
                        <th>
                        </th>
                        <td nowrap="nowrap">
                          <input type="button" name="pf_change" value="Change" onclick="javascript: return pfChangeSubmit();" />
                        </td>
                      </tr>
                      <tr>
                        <th style="text-align: left; background-color: #F6F6F6;" colspan="2">
                          OpenID
                        </th>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_securityOpenID">OpenID URL</label>
                        </th>
                        <td nowrap="nowrap">
                          <input type="text" name="pf_securityOpenID" value="<% out.print(xpathEvaluate($_document, "/user/securityOpenID")); %>" id="pf_securityOpenID" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                        </th>
                        <td nowrap="nowrap">
                          <input type="submit" name="pf_update" value="Change" onclick="$('securityNo').value = '1'; needToConfirm = false;" />
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
                        <td id="td_securitySecretQuestion" nowrap="nowrap">
                          <script type="text/javascript">
                            function categoryCombo ()
                            {
                              var cc = new OAT.Combolist([], "<% out.print(xpathEvaluate($_document, "/user/securitySecretQuestion")); %>");
                              cc.input.name = "pf_securitySecretQuestion";
                              cc.input.id = "pf_securitySecretQuestion";
                              cc.input.style.cssText = "width: 220px;";
                              $("td_securitySecretQuestion").appendChild(cc.div);
                              cc.addOption("");
                              cc.addOption("First Car");
                              cc.addOption("Mothers Maiden Name");
                              cc.addOption("Favorite Pet");
                              cc.addOption("Favorite Sports Team");
                            }
                            OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, categoryCombo);
                          </script>
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
                        <th>
                        </th>
                        <td nowrap="nowrap">
                          <input type="submit" name="pf_update" value="Change" onclick="$('securityNo').value = '2'; needToConfirm = false;" />
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
                      <tr>
                        <th>
                        </th>
                        <td nowrap="nowrap">
                          <input type="submit" name="pf_update" value="Change" onclick="$('securityNo').value = '3'; needToConfirm = false;" />
                        </td>
                      </tr>
                    </table>
                    <div class="footer">
                      <input type="submit" name="pf_cancel" value="Cancel" onclick="needToConfirm = false;"/>
                  </div>
                </div>
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
