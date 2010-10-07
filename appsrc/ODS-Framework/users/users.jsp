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
<%@ page import="javax.servlet.jsp.JspWriter" %>

<%@ page import="org.xml.sax.InputSource" %>

<%@ page import="org.w3c.dom.*" %>

<%@ page import="org.apache.commons.fileupload.*" %>
<%@ page import="org.apache.commons.fileupload.disk.*" %>
<%@ page import="org.apache.commons.fileupload.servlet.*" %>
<html>
  <head>
    <title>Virtuoso Web Applications</title>
    <link rel="stylesheet" type="text/css" href="/ods/users/css/users.css" />
    <link rel="stylesheet" type="text/css" href="/ods/default.css" />
    <link rel="stylesheet" type="text/css" href="/ods/nav_framework.css" />
    <link rel="stylesheet" type="text/css" href="/ods/typeahead.css" />
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
      var featureList = ["ajax", "json", "tab", "combolist", "calendar", "rdfmini", "grid", "graphsvg", "tagcloud", "map", "timeline", "anchor"];
    </script>
    <script type="text/javascript" src="/ods/oat/loader.js"></script>
  </head>
  <%!
    XPathFactory factory = XPathFactory.newInstance();
    XPath xpath = factory.newXPath();
    Document $_acl = null;
    String[] $_ACL = {"public", "1", "friends", "2", "private", "3"};

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

    void outACLOptions (javax.servlet.jsp.JspWriter out, String xpathString)
      throws IOException, XPathExpressionException
    {
      String S = xpathEvaluate($_acl, xpathString);
      for (int N = 0; N < $_ACL.length; N += 2)
        out.print("<option value=\"" + $_ACL[N+1] + "\" " + (($_ACL[N+1].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + $_ACL[N] + "</option>");
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

    String getParameter(List items, HttpServletRequest req, String param)
      throws IOException, FileUploadException
    {
      if (ServletFileUpload.isMultipartContent(req)) {
        // Process the uploaded items
        Iterator iterator = items.iterator();
        while (iterator.hasNext()) {
          FileItem item = (FileItem) iterator.next();

          if (param.equals(item.getFieldName()))
            if (item.isFormField()) {
              return item.getString();
            } else {
              return convertStreamToString(item.getInputStream());
            }
        }
      } else {
        return req.getParameter(param);
      }
      return null;
    }

    public String convertStreamToString(InputStream in)
      throws IOException
    {
      StringBuffer out = new StringBuffer();
      byte[] b = new byte[4096];

      for (int n; (n = in.read(b)) != -1;)
        out.append(new String(b, 0, n));

      return out.toString();
    }
  %>
  <%
    List /* FileItem */ items = null;
    if (ServletFileUpload.isMultipartContent(request)) {
      // Create a factory for disk-based file items
      FileItemFactory factory = new DiskFileItemFactory();

      // Create a new file upload handler
      ServletFileUpload upload = new ServletFileUpload(factory);

      // Parse the request
      items = upload.parseRequest(request);
    }
    String $_form = null;
    String $_oidForm = getParameter(items, request, "oid-form");
    if ($_oidForm == null) {
      $_form = getParameter(items, request, "form");
    } else {
      if ($_oidForm.equals("lf"))
        $_form = "login";
      if ($_oidForm.equals("rf"))
        $_form = "register";
    }
    if ($_form == null)
      $_form = "login";
    int $_formTab = 0;
    if (getParameter(items, request, "formTab") != null)
      $_formTab = Integer.parseInt(getParameter(items, request, "formTab"));
    int $_formSubtab = 0;
    if (getParameter(items, request, "formSubtab") != null)
      $_formSubtab = Integer.parseInt(getParameter(items, request, "formSubtab"));
    String $_formMode = "";
    if (getParameter(items, request, "formMode") != null)
      $_formMode = getParameter(items, request, "formMode");
    String $_sid = getParameter(items, request, "sid");
    String $_realm = "wa";
    String $_error = "";
    String $_retValue;
    Document $_document = null;
    String params = null;

    try
    {
      if ($_form.equals("login"))
      {
        if (getParameter(items, request, "lf_register") != null)
          $_form = "register";
        }

      if ($_form.equals("profile"))
      {
        if (getParameter(items, request, "pf_update06") != null)
        {
          params = httpParam( "", "sid", $_sid) +
                   httpParam("&", "realm", $_realm) +
                   httpParam("&", "id", getParameter(items, request, "pf06_id")) +
                   httpParam("&", "label", getParameter(items, request, "pf06_label")) +
                   httpParam("&", "uri", getParameter(items, request, "pf06_uri")) +
                   httpParam("&", "properties", getParameter(items, request, "items"));
          $_retValue = httpRequest ("POST", "user.favorites."+$_formMode, params);
          if ($_retValue.indexOf("<failed>") == 0)
          {
		        $_document = createDocument($_retValue);
            throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
          $_formMode = "";
        }
        else if (getParameter(items, request, "pf_update07") != null)
        {
          params = httpParam( "", "sid", $_sid) +
                   httpParam("&", "realm", $_realm) +
                   httpParam("&", "id", getParameter(items, request, "pf07_id")) +
                   httpParam("&", "property", getParameter(items, request, "pf07_property")) +
                   httpParam("&", "url", getParameter(items, request, "pf07_url")) +
                   httpParam("&", "description", getParameter(items, request, "pf07_description"));
          $_retValue = httpRequest ("POST", "user.mades."+$_formMode, params);
          if ($_retValue.indexOf("<failed>") == 0)
          {
		        $_document = createDocument($_retValue);
            throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
          $_formMode = "";
        }
        else if (getParameter(items, request, "pf_update08") != null)
        {
          params = httpParam( "", "sid", $_sid) +
                   httpParam("&", "realm", $_realm) +
                   httpParam("&", "id", getParameter(items, request, "pf08_id")) +
                   httpParam("&", "name", getParameter(items, request, "pf08_name")) +
                   httpParam("&", "comment", getParameter(items, request, "pf08_comment")) +
                   httpParam("&", "properties", getParameter(items, request, "items"));
          $_retValue = httpRequest ("POST", "user.offers."+$_formMode, params);
          if ($_retValue.indexOf("<failed>") == 0)
          {
		        $_document = createDocument($_retValue);
            throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
          $_formMode = "";
        }
        else if (getParameter(items, request, "pf_update09") != null)
        {
          params = httpParam( "", "sid", $_sid) +
                   httpParam("&", "realm", $_realm) +
                   httpParam("&", "id", getParameter(items, request, "pf09_id")) +
                   httpParam("&", "name", getParameter(items, request, "pf09_name")) +
                   httpParam("&", "comment", getParameter(items, request, "pf09_comment")) +
                   httpParam("&", "properties", getParameter(items, request, "items"));
          $_retValue = httpRequest ("POST", "user.seeks."+$_formMode, params);
          if ($_retValue.indexOf("<failed>") == 0)
          {
		        $_document = createDocument($_retValue);
            throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
          $_formMode = "";
        }
        else if (getParameter(items, request, "pf_update26") != null)
        {
          params = httpParam( "", "sid", $_sid) +
                   httpParam("&", "realm", $_realm) +
                   httpParam("&", "id", getParameter(items, request, "pf26_id")) +
                   httpParam("&", "certificate", getParameter(items, request, "pf26_certificate")) +
                   httpParam("&", "enableLogin", getParameter(items, request, "pf26_enableLogin"));
          $_retValue = httpRequest ("POST", "user.certificates."+$_formMode, params);
          if ($_retValue.indexOf("<failed>") == 0)
          {
		        $_document = createDocument($_retValue);
            throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
          $_formMode = "";
        }
        else if (getParameter(items, request, "pf_cancel2") != null)
        {
          $_formMode = "";
        }
        else if ((getParameter(items, request, "pf_update") != null) || (getParameter(items, request, "pf_next") != null) || (getParameter(items, request, "pf_clear") != null))
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
                           httpParam("&", "name", getParameter(items, request, key)) +
                           httpParam("&", "url", getParameter(items, request, prefix+"_fld_2_"+suffix));
                  $_retValue = httpRequest ("POST", "user.onlineAccounts.new", params);
                  if ($_retValue.indexOf("<failed>") == 0)
                  {
        		        $_document = createDocument($_retValue);
                    throw new Exception(xpathEvaluate($_document, "/failed/message"));
                  }
                }
      		    }
            }
            else if (($_formTab == 0) && ($_formSubtab == 5))
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
                           httpParam("&", "event", getParameter(items, request, key)) +
                           httpParam("&", "date", getParameter(items, request, prefix+"_fld_2_"+suffix)) +
                           httpParam("&", "place", getParameter(items, request, prefix+"_fld_3_"+suffix));
                  $_retValue = httpRequest ("POST", "user.bioEvents.new", params);
                  if ($_retValue.indexOf("<failed>") == 0)
                  {
        		        $_document = createDocument($_retValue);
                    throw new Exception(xpathEvaluate($_document, "/failed/message"));
                  }
                }
      		    }
            }
            else if (($_formTab == 2) && ($_formSubtab == 0))
            {
              params = httpParam( "", "sid", $_sid) +
                       httpParam("&", "realm", $_realm) +
                       httpParam("&", "new_password", getParameter(items, request, "pf_newPassword"));
              if (getParameter(items, request, "pf_oldPassword") == null)
              {
                params+= httpParam("&", "old_password", "x");
              } else {
                params+= httpParam("&", "old_password", getParameter(items, request, "pf_oldPassword"));
              }
              $_retValue = httpRequest ("POST", "user.password_change", params);
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
                  if ("1".equals(getParameter(items, request, "cb_item_i_name")))
                    params += httpParam ("&", "nickName", getParameter(items, request, "i_nickName"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_title")))
                    params += httpParam ("&", "title=", getParameter(items, request, "i_title"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_firstName")))
                    params += httpParam ("&", "firstName", getParameter(items, request, "i_firstName"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_lastName")))
                    params += httpParam ("&", "lastName", getParameter(items, request, "i_lastName"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_fullName")))
                    params += httpParam ("&", "fullName", getParameter(items, request, "i_fullName"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_gender")))
                    params += httpParam ("&", "gender", getParameter(items, request, "i_gender"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_mail")))
                    params += httpParam ("&", "mail", getParameter(items, request, "i_mail"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_birthday")))
                    params += httpParam ("&", "birthday", getParameter(items, request, "i_birthday"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_homepage")))
                    params += httpParam ("&", "homepage", getParameter(items, request, "i_homepage"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_icq")))
                    params += httpParam ("&", "icq", getParameter(items, request, "i_icq"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_aim")))
                    params += httpParam ("&", "aim", getParameter(items, request, "i_aim"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_yahoo")))
                    params += httpParam ("&", "yahoo", getParameter(items, request, "i_yahoo"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_msn")))
                    params += httpParam ("&", "msn", getParameter(items, request, "i_msn"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_skype")))
                    params += httpParam ("&", "skype", getParameter(items, request, "i_skype"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_homelat")))
                    params += httpParam ("&", "homeLatitude", getParameter(items, request, "i_homelat"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_homelng")))
                    params += httpParam ("&", "homeLongitude", getParameter(items, request, "i_homelng"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_homePhone")))
                    params += httpParam ("&", "homePhone", getParameter(items, request, "i_homePhone"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_businessOrganization")))
                    params += httpParam ("&", "businessOrganization", getParameter(items, request, "i_businessOrganization"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_businessHomePage")))
                    params += httpParam ("&", "businessHomePage", getParameter(items, request, "i_businessHomePage"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_summary")))
                    params += httpParam ("&", "summary", getParameter(items, request, "i_summary"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_tags")))
                    params += httpParam ("&", "tags", getParameter(items, request, "i_tags"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_sameAs")))
                    params += httpParam ("&", "webIDs", getParameter(items, request, "i_sameAs"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_interests")))
                    params += httpParam ("&", "interests", getParameter(items, request, "i_interests"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_topicInterests")))
                    params += httpParam ("&", "topicInterests", getParameter(items, request, "i_topicInterests"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_onlineAccounts")))
                    params += httpParam ("&", "onlineAccounts", getParameter(items, request, "i_onlineAccounts"));
                }
                else if ($_formSubtab == 1)
                {
                  params +=
                       httpParam ("&", "nickName"              , getParameter(items, request, "pf_nickName")) +
                       httpParam ("&", "mail"                  , getParameter(items, request, "pf_mail")) +
                       httpParam ("&", "title"                 , getParameter(items, request, "pf_title")) +
                       httpParam ("&", "firstName"             , getParameter(items, request, "pf_firstName")) +
                       httpParam ("&", "lastName"              , getParameter(items, request, "pf_lastName")) +
                       httpParam ("&", "fullName"              , getParameter(items, request, "pf_fullName")) +
                       httpParam ("&", "gender"                , getParameter(items, request, "pf_gender")) +
                       httpParam ("&", "birthday"              , getParameter(items, request, "pf_birthday")) +
                       httpParam ("&", "homepage"              , getParameter(items, request, "pf_homepage")) +
                       httpParam ("&", "mailSignature"         , getParameter(items, request, "pf_mailSignature")) +
                       httpParam ("&", "summary"               , getParameter(items, request, "pf_summary")) +
                       httpParam ("&", "appSetting"            , getParameter(items, request, "pf_appSetting")) +
                       httpParam ("&", "photo"                 , getParameter(items, request, "pf_photo")) +
                       httpParam ("&", "photoContent"          , getParameter(items, request, "pf_photoContent")) +
                       httpParam ("&", "audio"                 , getParameter(items, request, "pf_audio")) +
                       httpParam ("&", "audioContent"          , getParameter(items, request, "pf_audioContent"));

                  tmp = "";
                  if (ServletFileUpload.isMultipartContent(request)) {
                    Iterator iterator = items.iterator();
                    while (iterator.hasNext()) {
                      FileItem item = (FileItem) iterator.next();
                      if (item.isFormField()) {
                        if (item.getFieldName().indexOf("x1_fld_1_") == 0)
                          tmp += item.getString() + "\n";
                      }
                    }
                  } else {
                  keys = request.getParameterNames();
          		    while (keys.hasMoreElements() )
          		    {
          		      String key = (String)keys.nextElement();
                    if (key.indexOf("x1_fld_1_") == 0)
                      tmp += getParameter(items, request, key) + "\n";
          		    }
            		  }
                  params += httpParam ("&", "webIDs", tmp);
                  tmp = "";
                  if (ServletFileUpload.isMultipartContent(request)) {
                    Iterator iterator = items.iterator();
                    while (iterator.hasNext()) {
                      FileItem item = (FileItem) iterator.next();
                      if (item.isFormField()) {
                        if (item.getFieldName().indexOf("x2_fld_1_") == 0) {
                          suffix = item.getFieldName().replace("x2_fld_1_", "");
                          tmp += item.getString() + ";" + getParameter(items, request, "x2_fld_2_"+suffix) + "\n";
                        }
                      }
                    }
                  } else {
                    keys = request.getParameterNames();
          		    while (keys.hasMoreElements() )
          		    {
          		      String key = (String)keys.nextElement();
                    if (key.indexOf("x2_fld_1_") == 0)
                    {
                      suffix = key.replace("x2_fld_1_", "");
                      tmp += getParameter(items, request, key) + ";" + getParameter(items, request, "x2_fld_2_"+suffix) + "\n";
                    }
          		    }
            		  }
                  params += httpParam ("&", "interests", tmp);
                  tmp = "";
                  if (ServletFileUpload.isMultipartContent(request)) {
                    Iterator iterator = items.iterator();
                    while (iterator.hasNext()) {
                      FileItem item = (FileItem) iterator.next();
                      if (item.isFormField()) {
                        if (item.getFieldName().indexOf("x3_fld_1_") == 0) {
                          suffix = item.getFieldName().replace("x3_fld_1_", "");
                          tmp += item.getString() + ";" + getParameter(items, request, "x3_fld_2_"+suffix) + "\n";
                        }
                      }
                    }
                  } else {
                    keys = request.getParameterNames();
          		    while (keys.hasMoreElements() )
          		    {
          		      String key = (String)keys.nextElement();
                    if (key.indexOf("x3_fld_1_") == 0)
                    {
                      suffix = key.replace("x3_fld_1_", "");
                      tmp += getParameter(items, request, key) + ";" + getParameter(items, request, "x3_fld_2_"+suffix) + "\n";
                    }
          		    }
            		  }
                  params += httpParam ("&", "topicInterests", tmp);
                }
                if ($_formSubtab == 2)
                {
                  params +=
                       httpParam ("&", "homeDefaultMapLocation", getParameter(items, request, "pf_homeDefaultMapLocation")) +
                       httpParam ("&", "homeCountry"           , getParameter(items, request, "pf_homecountry")) +
                       httpParam ("&", "homeState"             , getParameter(items, request, "pf_homestate")) +
                       httpParam ("&", "homeCity"              , getParameter(items, request, "pf_homecity")) +
                       httpParam ("&", "homeCode"              , getParameter(items, request, "pf_homecode")) +
                       httpParam ("&", "homeAddress1"          , getParameter(items, request, "pf_homeaddress1")) +
                       httpParam ("&", "homeAddress2"          , getParameter(items, request, "pf_homeaddress2")) +
                       httpParam ("&", "homeTimezone"          , getParameter(items, request, "pf_homeTimezone")) +
                       httpParam ("&", "homeLatitude"          , getParameter(items, request, "pf_homelat")) +
                       httpParam ("&", "homeLongitude"         , getParameter(items, request, "pf_homelng")) +
                       httpParam ("&", "homePhone"             , getParameter(items, request, "pf_homePhone")) +
                       httpParam ("&", "homePhoneExt"          , getParameter(items, request, "pf_homePhoneExt")) +
                       httpParam ("&", "homeMobile"            , getParameter(items, request, "pf_homeMobile"));
                }
                if ($_formSubtab == 4)
                {
                  params +=
                       httpParam ("&", "icq"                   , getParameter(items, request, "pf_icq")) +
                       httpParam ("&", "skype"                 , getParameter(items, request, "pf_skype")) +
                       httpParam ("&", "yahoo"                 , getParameter(items, request, "pf_yahoo")) +
                       httpParam ("&", "aim"                   , getParameter(items, request, "pf_aim")) +
                       httpParam ("&", "msn"                   , getParameter(items, request, "pf_msn"));
                  keys = request.getParameterNames();
                  tmp = "";
          		    while (keys.hasMoreElements() )
          		    {
          		      String key = (String)keys.nextElement();
                    if (key.indexOf("x6_fld_1_") == 0)
                    {
                      suffix = key.replace("x6_fld_1_", "");
                      tmp += getParameter(items, request, key) + ";" + getParameter(items, request, "x6_fld_2_"+suffix) + "\n";
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
                       httpParam ("&", "businessIndustry"      , getParameter(items, request, "pf_businessIndustry")) +
                       httpParam ("&", "businessOrganization"  , getParameter(items, request, "pf_businessOrganization")) +
                       httpParam ("&", "businessHomePage"      , getParameter(items, request, "pf_businessHomePage")) +
                       httpParam ("&", "businessJob"           , getParameter(items, request, "pf_businessJob")) +
                       httpParam ("&", "businessRegNo"         , getParameter(items, request, "pf_businessRegNo")) +
                       httpParam ("&", "businessCareer"        , getParameter(items, request, "pf_businessCareer")) +
                       httpParam ("&", "businessEmployees"     , getParameter(items, request, "pf_businessEmployees")) +
                       httpParam ("&", "businessVendor"        , getParameter(items, request, "pf_businessVendor")) +
                       httpParam ("&", "businessService"       , getParameter(items, request, "pf_businessService")) +
                       httpParam ("&", "businessOther"         , getParameter(items, request, "pf_businessOther")) +
                       httpParam ("&", "businessNetwork"       , getParameter(items, request, "pf_businessNetwork")) +
                       httpParam ("&", "businessResume"        , getParameter(items, request, "pf_businessResume"));
                }
                if ($_formSubtab == 1)
                {
                  params +=
                       httpParam ("&", "businessCountry"       , getParameter(items, request, "pf_businesscountry")) +
                       httpParam ("&", "businessState"         , getParameter(items, request, "pf_businessstate")) +
                       httpParam ("&", "businessCity"          , getParameter(items, request, "pf_businesscity")) +
                       httpParam ("&", "businessCode"          , getParameter(items, request, "pf_businesscode")) +
                       httpParam ("&", "businessAddress1"      , getParameter(items, request, "pf_businessaddress1")) +
                       httpParam ("&", "businessAddress2"      , getParameter(items, request, "pf_businessaddress2")) +
                       httpParam ("&", "businessTimezone"      , getParameter(items, request, "pf_businessTimezone")) +
                       httpParam ("&", "businessLatitude"      , getParameter(items, request, "pf_businesslat")) +
                       httpParam ("&", "businessLongitude"     , getParameter(items, request, "pf_businesslng")) +
                       httpParam ("&", "businessPhone"         , getParameter(items, request, "pf_businessPhone")) +
                       httpParam ("&", "businessPhoneExt"      , getParameter(items, request, "pf_businessPhoneExt")) +
                       httpParam ("&", "businessMobile"        , getParameter(items, request, "pf_businessMobile"));
                }
                if ($_formSubtab == 3)
                {
                  params +=
                       httpParam ("&", "businessIcq"          , getParameter(items, request, "pf_businessIcq")) +
                       httpParam ("&", "businessSkype"        , getParameter(items, request, "pf_businessSkype")) +
                       httpParam ("&", "businessYahoo"        , getParameter(items, request, "pf_businessYahoo")) +
                       httpParam ("&", "businessAim"          , getParameter(items, request, "pf_businessAim")) +
                       httpParam ("&", "businessMsn"          , getParameter(items, request, "pf_businessMsn"));
                  keys = request.getParameterNames();
                  tmp = "";
          		    while (keys.hasMoreElements() )
          		    {
          		      String key = (String)keys.nextElement();
                    if (key.indexOf("y2_fld_1_") == 0)
                    {
                      suffix = key.replace("y2_fld_1_", "");
                      tmp += getParameter(items, request, key) + ";" + getParameter(items, request, "y2_fld_2_"+suffix) + "\n";
                    }
          		    }
                  params += httpParam ("&", "businessMessaging", tmp);
                }
              }
              if ($_formTab == 2)
              {
                if ($_formSubtab == 1)
                  params +=
                       httpParam ("&", "securitySecretQuestion", getParameter(items, request, "pf_securitySecretQuestion")) +
                       httpParam ("&", "securitySecretAnswer", getParameter(items, request, "pf_securitySecretAnswer"));

                if ($_formSubtab == 2)
                  params +=
                       httpParam ("&", "securityOpenID", getParameter(items, request, "pf_securityOpenID"));

                if ($_formSubtab == 3)
                {
                  if (getParameter(items, request, "pf_clear") != null)
                  {
                    params +=
                         httpParam ("&", "securityFacebookID", "");
                  } else {
                  params +=
                       httpParam ("&", "securityFacebookID", getParameter(items, request, "pf_securityFacebookID"));
                  }
                }

                if ($_formSubtab == 4)
                  params +=
                       httpParam ("&", "securitySiocLimit", getParameter(items, request, "pf_securitySiocLimit"));
              }
            $_retValue = httpRequest ("POST", "user.update.fields", params);
            if ($_retValue.indexOf("<failed>") == 0)
          {
  		        $_document = createDocument($_retValue);
              throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }

              tmp = "";
              if (ServletFileUpload.isMultipartContent(request)) {
                Iterator iterator = items.iterator();
                while (iterator.hasNext()) {
                  FileItem item = (FileItem) iterator.next();
                  if (item.isFormField()) {
                    if (item.getFieldName().indexOf("pf_acl_") == 0)
                      tmp += item.getFieldName().replace("pf_acl_", "") + "=" + item.getString() + "&";
                  }
                }
              } else {
                keys = request.getParameterNames();
        		    while (keys.hasMoreElements() )
        		    {
        		      String key = (String)keys.nextElement();
                  if (key.indexOf("pf_acl_") == 0) {
                    tmp += key.replace("pf_acl_", "") + "=" + getParameter(items, request, key) + "&";
                  }
        		    }
              }
              params = httpParam ( "", "sid", $_sid) +
                       httpParam ("&", "realm", $_realm) +
                       httpParam ("&", "acls", tmp);
              $_retValue = httpRequest ("POST", "user.acl.update", params);
              if ($_retValue.indexOf("<failed>") == 0)
              {
    		        $_document = createDocument($_retValue);
                throw new Exception(xpathEvaluate($_document, "/failed/message"));
              }
            }
            if (getParameter(items, request, "pf_next") != null)
            {
              $_formSubtab += 1;
              if (
                  (($_formTab == 1) && ($_formSubtab > 3)) ||
                  (($_formTab == 2) && ($_formSubtab > 5))
                 )
              {
                $_formTab += 1;
                $_formSubtab = 0;
              }
              if ($_formTab == 3)
                $_formTab = 0;
            }
          }
          catch (Exception e)
          {
            $_error = e.getMessage();
            $_form = "login";
          }
        }
        else if (getParameter(items, request, "pf_cancel") != null)
        {
          $_form = "user";
        }
      }

      if ($_form.equals("user"))
      {
        if (getParameter(items, request, "uf_profile") != null)
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
          $_retValue = httpRequest ("POST", "user.info", params);
		      $_document = createDocument($_retValue);
          if ("".compareTo(xpathEvaluate($_document, "/failed/message")) != 0)
            throw new Exception (xpathEvaluate($_document, "/failed/message"));
        }
        catch (Exception e)
        {
          $_error = e.getMessage();
          $_form = "login";
        }
        if ($_form.equals("profile"))
        {
          try
          {
            params = httpParam ( "", "sid"   , $_sid) +
                     httpParam ("&", "realm" , $_realm);
            $_retValue = httpRequest ("POST", "user.acl.info", params);
  		      $_acl = createDocument($_retValue);
            if ("".compareTo(xpathEvaluate($_acl, "/failed/message")) != 0)
              throw new Exception (xpathEvaluate($_acl, "/failed/message"));
          }
          catch (Exception e)
          {
            $_error = e.getMessage();
            $_form = "login";
          }
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
    <form name="page_form" id="page_form" method="post" enctype="<% out.print(($_form.equals("profile") && ($_formTab == 0) && ($_formSubtab == 1))? "multipart/form-data": "application/x-www-form-urlencoded"); %>" action="users.jsp">
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
        <div id="ob_left">
        <%
          if ($_form.equals("profile") || $_form.equals("user"))
          {
        %>
          <b>User: </b><% out.print(xpathEvaluate($_document, "/user/fullName")); %>, <b>Profile: </b><a href="#" onclick="javascript: return profileSubmit();">Edit</a> / <a href="#" onclick="javascript: return userSubmit();">View</a>
        <%
          }
        %>
        </div>
        <div id="ob_right">
        <%
          if (($_form != "login") && ($_form != "register"))
          {
        %>
          <a href="#" onclick="javascript: return logoutSubmit();">Logout</a>
        <%
          }
        %>
      </div>
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
                  Identify Yourself
                </div>
                <ul id="lf_tabs" class="tabs">
                  <li id="lf_tab_0" title="Digest">Digest</li>
                  <li id="lf_tab_1" title="OpenID" style="display: none;">OpenID</li>
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
                        <td>
                          <input type="text" name="lf_uid" value="" id="lf_uid" style="width: 150px;" />
                    </td>
                  </tr>
                  <tr>
                    <th>
                      <label for="lf_password">Password</label>
                    </th>
                        <td>
                          <input type="password" name="lf_password" value="" id="lf_password" style="width: 150px;" />
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
                        <td>
                          <input type="text" name="lf_openId" value="" id="lf_openId" style="width: 300px;" />
                        </td>
                  </tr>
                    </table>
                  </div>
                  <div id="lf_page_2" class="tabContent" style="display: none">
                    <table class="form" cellspacing="5">
                  <tr>
                        <th width="30%">
                    </th>
                        <td>
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
                  <input type="submit" name="lf_register" value="Sign Up" id="lf_register" />
                </div>
              </div>
              <%
              }
              if ($_form.equals("register"))
              {
              %>
              <div id="rf" class="form">
                <div class="header">
                  User register
                </div>
                <ul id="rf_tabs" class="tabs">
                  <li id="rf_tab_0" title="Digest">Digest</li>
                  <li id="rf_tab_1" title="OpenID" style="display: none;">OpenID</li>
                  <li id="rf_tab_2" title="Facebook" style="display: none;">Facebook</li>
                  <li id="rf_tab_3" title="WebID" style="display: none;">WebID</li>
                </ul>
                <div style="min-height: 135px; border: 1px solid #aaa; margin: -13px 5px 5px 5px;">
                  <div id="rf_content"></div>
                  <div id="rf_page_0" class="tabContent" >
                    <table id="rf_table_0" class="form" cellspacing="5">
                      <tr>
                        <th width="30%">
                          <label for="rf_uid">Login Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
                        </th>
                        <td>
                          <input type="text" name="rf_uid" value="" id="rf_uid" style="width: 150px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="rf_email">E-mail<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
                        </th>
                        <td>
                          <input type="text" name="rf_email" value="" id="rf_email" size="40"/>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="rf_password">Password<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
                        </th>
                        <td>
                          <input type="password" name="rf_password" value="" id="rf_password" style="width: 150px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="rf_password2">Password (verify)<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
                        </th>
                        <td>
                          <input type="password" name="rf_password2" value="" id="rf_password2" style="width: 150px;" />
                        </td>
                      </tr>
                    </table>
                  </div>
                  <div id="rf_page_1" class="tabContent" style="display: none">
                    <table id="rf_table_1" class="form" cellspacing="5">
                      <tr>
                        <th width="30%">
                          <label for="rf_openId">OpenID</label>
                        </th>
                        <td>
                          <input type="text" name="rf_openId" value="" id="rf_openId" size="40"/>
                        </td>
                      </tr>
                    </table>
                  </div>
                  <div id="rf_page_2" class="tabContent" style="display: none">
                    <table id="rf_table_2" class="form" cellspacing="5">
                      <tr>
                        <th width="30%">
                        </th>
                        <td>
                          <span id="rf_facebookData" style="min-height: 20px;"></span>
                          <br />
                          <script src="http://static.ak.connect.facebook.com/js/api_lib/v0.4/FeatureLoader.js.php" type="text/javascript"></script>
                          <fb:login-button autologoutlink="true"></fb:login-button>
                        </td>
                      </tr>
                    </table>
                  </div>
                  <div id="rf_page_3" class="tabContent" style="display: none">
                    <table id="rf_table_3" class="form" cellspacing="5">
                    </table>
                  </div>
                </div>
                <div>
                  <table class="form" cellspacing="5">
                    <tr>
                      <th width="30%">
                      </th>
                      <td>
                        <input type="checkbox" name="rf_is_agreed" value="1" id="rf_is_agreed"/><label for="rf_is_agreed">I agree to the <a href="/ods/terms.html" target="_blank">Terms of Service</a>.</label>
                      </td>
                    </tr>
                  </table>
                </div>
                <div class="footer" id="rf_login_5">
                  <input type="button" id="rf_signup" name="rf_signup" value="Sign Up" onclick="javascript: return rfSignupSubmit();" />
                </div>
              </div>
              <%
              }
              if ($_form.equals("user"))
              {
              %>
              <div id="uf" class="form" style="width: 100%;">
                <div class="header">
                  User profile
                </div>

                <div id="uf_div_new" style="clear: both;">
                </div>
                <div id="uf_div" style="clear: both; display: none;">
              	  <div id="u_profile_l">
              	    <div id="user_info_w" class="widget user_info_w">
              	      <div class="w_title" id="userProfilePhotoName">
              	        <h3></h3>
              	      </div>
              	      <div class="w_content">
                        <div class="user_img_ctr">
                          <a href="javascript:void(0)">
                       		  <img alt="Profile image" id="userProfilePhotoImg" rel="foaf:depiction" class="prof_photo" src="/ods/images/profile.png"/>
                          </a>
                        </div> <!-- user_img_ctr -->
                        <div class="gems_ctr">
                          <div class="prof_user_gems" id="profileUserGems">
                            <div class="gem">
                              <a href="javascript:void(0)" id="uf_foaf_gem" target="_blank"><img src="/ods/images/icons/foaf.png" alt="FOAF"/></a>
                            </div>
                            <div class="gem">
                              <a href="javascript:void(0)" id="uf_sioc_gem" target="_blank"><img src="/ods/images/icons/sioc_button.png" alt="SIOC"/></a>
                            </div>
                            <div class="gem">
                              <a href="javascript:void(0)" id="uf_vcard_gem" target="_blank"><img src="/ods/images/icons/vcard.png" alt="VCARD"/></a>
                            </div>
                          </div> <!-- prof_user_gems -->
                        </div> <!-- gems_ctr -->
                      </div> <!-- w_content -->
          	        </div> <!-- .widget -->

            	      <div id="ds_w" class="widget ds_w">
            	        <div class="w_title">
                        <h3>Data Space</h3>
          		          <div class="w_title_bar_btns">
                    		  <img src="/ods/images/skin/default/menu_dd_handle_close.png" alt="Minimize" class="w_toggle" onclick="widgetToggle(this);"/>
                    		</div> <!-- w_title_bar_btns -->
          	          </div> <!-- w_title -->
            	        <div class="w_content">
                        <ul class="ds_list" id="ds_list">
                        </ul> <!-- ds_list -->
                        <div class="cmd_ctr">&nbsp;</div>
                      </div> <!-- w_content -->
                    </div> <!-- .widget -->

              	    <div id="connections_w" class="widget connections_w">
              	      <div class="w_title">
                        <h3 id="connPTitleTxt">Connections</h3>
                        <div class="w_title_bar_btns">
                          <img src="/ods/images/skin/default/menu_dd_handle_close.png" alt="Minimize" class="w_toggle" onclick="widgetToggle(this);"/>
                        </div> <!-- w_title_bar_btns -->
              	      </div> <!-- w_title -->
            	        <div class="w_content" id="connP1" style="height: 200px;">
                      </div> <!-- w_content -->
            	      </div> <!-- .widget -->

                    <div id="groups_w" class="widget groups_w" style="display: none;">
            	        <div class="w_title">
            	          <h3 id="discussionsTitleTxt">Discussion Groups ()</h3>
            	        </div>
            	        <div class="w_content" id="discussionsCtr">
                      </div> <!-- w_content -->
            	      </div> <!-- .widget -->
          	      </div>

              	  <div id="u_profile_r" style="width: 100%;">
                    <div class="widget w_contact" about="#THIS" instanceof="foaf:Person">
                      <div class="w_title">
                        <h3>Contact Information</h3>
                        <div class="w_title_bar_btns">
                    		  <img src="/ods/images/skin/default/menu_dd_handle_close.png" alt="Minimize" class="w_toggle" onclick="widgetToggle(this);"/>
                    		</div>
                      </div>
                      <div class="w_content">
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
                          <div id="uf_page_1" class="tabContent" style="display: none">
                    <table id="uf_table_1" class="form" cellspacing="5">
                    </table>
                  </div>
                          <div id="uf_page_2" class="tabContent" style="display: none">
                    <table id="uf_table_2" class="form" cellspacing="5">
                    </table>
                  </div>
                          <div id="uf_page_3" class="tabContent" style="display: none">
                    <table id="uf_table_3" class="form" cellspacing="5">
                </table>
                  </div>
                          <div id="uf_page_4" class="tabContent" style="display: none">
                    <div id="uf_rdf_content">
                      &nbsp;
                    </div>
                  </div>
                  <script type="text/javascript">
                    OAT.MSG.attach(OAT, "PAGE_LOADED", function (){selectProfile();});
                    OAT.MSG.attach(OAT, "PAGE_LOADED", function (){cRDF.open("<% out.print(xpathEvaluate($_document, "/user/iri")); %>");});
                  </script>
                </div>
                      </div>
                    </div>

                    <div id="notify" class="notify_w widget">
                      <div class="w_title">
                        <h3>Activities</h3>
                        <div class="w_title_bar_btns">
                      	  <img src="/ods/images/skin/default/menu_dd_handle_close.png" alt="Minimize" class="w_toggle" onclick="widgetToggle(this);"/>
                      	</div> <!-- w_title_bar_btns -->
                      </div>
                      <div class="w_content" id="notify_content">
                      </div>
                    </div>
                  </div>
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
                      <li id="pf_tab_0_0" title="Import">Profile Import</li>
                      <li id="pf_tab_0_1" title="Main">Main</li>
                      <li id="pf_tab_0_2" title="Address">Address</li>
                      <li id="pf_tab_0_3" title="Online Accounts">Online Accounts</li>
                      <li id="pf_tab_0_4" title="Messaging Services">Messaging Services</li>
                      <li id="pf_tab_0_5" title="Biographical Events">Biographical Events</li>
                      <li id="pf_tab_0_6" title="Favorite Things">Favorite Things</li>
                      <li id="pf_tab_0_7" title="Creator Of">Creator Of</li>
                      <li id="pf_tab_0_8" title="My Offers">My Offers</li>
                      <li id="pf_tab_0_9" title="Offers I Seek">Offers I Seek</li>
                    </ul>
                    <div style="min-height: 180px; min-width: 650px; border-top: 1px solid #aaa; margin: -13px 5px 5px 5px;">
                      <div id="pf_page_0_0" class="tabContent" style="display:none;">
                    <table class="form" cellspacing="5">
                      <tr>
                        <th>
                              <label for="pf_foaf">Profile Document URL</label>
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
                            <td>
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
                              <select name="pf_acl_title" id="pf_acl_title">
                                <%
                                  outACLOptions (out, "/acl/title");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_firstName">First Name</label>
                        </th>
                            <td>
                          <input type="text" name="pf_firstName" value="<% out.print(xpathEvaluate($_document, "/user/firstName")); %>" id="pf_firstName" style="width: 220px;" />
                              <select name="pf_acl_firstName" id="pf_acl_firstName">
                                <%
                                  outACLOptions (out, "/acl/firstName");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_lastName">Last Name</label>
                        </th>
                            <td>
                          <input type="text" name="pf_lastName" value="<% out.print(xpathEvaluate($_document, "/user/lastName")); %>" id="pf_lastName" style="width: 220px;" />
                              <select name="pf_acl_lastName" id="pf_acl_lastName">
                                <%
                                  outACLOptions (out, "/acl/lastName");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_fullName">Full Name</label>
                        </th>
                            <td>
                          <input type="text" name="pf_fullName" value="<% out.print(xpathEvaluate($_document, "/user/fullName")); %>" id="pf_fullName" size="60" />
                              <select name="pf_acl_fullName" id="pf_acl_fullName">
                                <%
                                  outACLOptions (out, "/acl/fullName");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th width="30%">
                          <label for="pf_mail">E-mail</label>
                        </th>
                            <td>
                          <input type="text" name="pf_mail" value="<% out.print(xpathEvaluate($_document, "/user/mail")); %>" id="pf_mail" style="width: 220px;" />
                              <select name="pf_acl_mail" id="pf_acl_mail">
                                <%
                                  outACLOptions (out, "/acl/mail");
                                %>
                              </select>
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
                              <select name="pf_acl_gender" id="pf_acl_gender">
                                <%
                                  outACLOptions (out, "/acl/gender");
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
                              <select name="pf_acl_birthday" id="pf_acl_birthday">
                                <%
                                  outACLOptions (out, "/acl/birthday");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homepage">Personal Webpage</label>
                        </th>
                        <td>
                          <input type="text" name="pf_homepage" value="<% out.print(xpathEvaluate($_document, "/user/homepage")); %>" id="pf_homepage" style="width: 220px;" />
                              <select name="pf_acl_homepage" id="pf_acl_homepage">
                                <%
                                  outACLOptions (out, "/acl/homepage");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                            <th>
                              <label for="pf_foaf">Other Personal URIs (Web IDs)</label>
                        </th>
                            <td>
                              <table>
                                <tr>
                                  <td width="600px" style="padding: 0px;">
                                    <table id="x1_tbl" class="listing">
                                      <thead>
                                        <tr class="listing_header_row">
                                          <th>
                                            URI
                                          </th>
                                          <th width="65px">
                                            Action
                                          </th>
                                        </tr>
                                      </thead>
                                      <tr id="x1_tr_no" style="display: none;"><td colspan="2"><b>No Personal URIs</b></td></tr>
                                      <script type="text/javascript">
                                        OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowRows("x1", '<% out.print(xpathEvaluate($_document, "/user/webIDs").replace("\n", "\\n")); %>', ["\n"], function(prefix, val1){TBL.createRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _webid_ _canEmpty_'}});});});
                                      </script>
                                    </table>
                                  </td>
                                  <td valign="top" nowrap="nowrap">
                                    <span class="button pointer" onclick="TBL.createRow('x1', null, {fld_1: {className: '_validate_ _webid_ _canEmpty_'}});"><img class="button" src="/ods/images/icons/add_16.png" border="0" alt="Add Row" title="Add Row" /> Add</span>
                                    <select name="pf_acl_webIDs" id="pf_acl_webIDs">
                                      <%
                                        {
                                          String S = xpathEvaluate($_acl, "/acl/webIDs");
                                          for (int N = 0; N < $_ACL.length; N += 2)
                                            out.print("<option value=\"" + $_ACL[N+1] + "\" " + (($_ACL[N+1].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + $_ACL[N] + "</option>");
                                        }
                                      %>
                                    </select>
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
                              <select name="pf_acl_summary" id="pf_acl_summary">
                                <%
                                  outACLOptions (out, "/acl/summary");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                              <label for="pf_foaf">Web page URL indicating a topic of interest</label>
                        </th>
                            <td>
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
                                          <th width="65px">
                                            Action
                                          </th>
                                        </tr>
                                      </thead>
                                      <tr id="x2_tr_no" style="display: none;"><td colspan="3"><b>No Topic of Interests</b></td></tr>
                                      <script type="text/javascript">
                                        OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowRows("x2", '<% out.print(xpathEvaluate($_document, "/user/interests").replace("\n", "\\n")); %>', ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _url_ _canEmpty_'}, fld_2: {value: val2}});});});
                                      </script>
                                    </table>
                                  </td>
                                  <td valign="top" nowrap="nowrap">
                                    <span class="button pointer" onclick="TBL.createRow('x2', null, {fld_1: {className: '_validate_ _url_ _canEmpty_'}, fld_2: {}});"><img class="button" src="/ods/images/icons/add_16.png" border="0" alt="Add Row" title="Add Row" /> Add</span>
                                    <select name="pf_acl_interests" id="pf_acl_interests">
                                      <%
                                        {
                                          String S = xpathEvaluate($_acl, "/acl/interests");
                                          for (int N = 0; N < $_ACL.length; N += 2)
                                            out.print("<option value=\"" + $_ACL[N+1] + "\" " + (($_ACL[N+1].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + $_ACL[N] + "</option>");
                                        }
                                      %>
                                    </select>
                                  </td>
                                </tr>
                              </table>
                        </td>
                      </tr>
                      <tr>
                        <th>
                              <label for="pf_foaf">Resource URI indicating thing of interest</label>
                        </th>
                            <td>
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
                                          <th width="65px">
                                            Action
                                          </th>
                                        </tr>
                                      </thead>
                                      <tr id="x3_tr_no" style="display: none;"><td colspan="3"><b>No Thing of Interests</b></td></tr>
                                      <script type="text/javascript">
                                        OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowRows("x3", '<% out.print(xpathEvaluate($_document, "/user/topicInterests").replace("\n", "\\n")); %>', ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _url_ _canEmpty_'}, fld_2: {value: val2}});});});
                                      </script>
                                    </table>
                                  </td>
                                  <td valign="top" nowrap="nowrap">
                                    <span class="button pointer" onclick="TBL.createRow('x3', null, {fld_1: {className: '_validate_ _url_ _canEmpty_'}, fld_2: {}});"><img class="button" src="/ods/images/icons/add_16.png" border="0" alt="Add Row" title="Add Row" /> Add</span>
                                    <select name="pf_acl_topicInterests" id="pf_acl_topicInterests">
                                      <%
                                        {
                                          String S = xpathEvaluate($_acl, "/acl/topicInterests");
                                          for (int N = 0; N < $_ACL.length; N += 2)
                                            out.print("<option value=\"" + $_ACL[N+1] + "\" " + (($_ACL[N+1].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + $_ACL[N] + "</option>");
                                        }
                                      %>
                                    </select>
                                  </td>
                                </tr>
                              </table>
                        </td>
                      </tr>
                          <tr>
                            <th>
                              <label for="pf_photoContent">Upload Photo</label>
                            </th>
                            <td nowrap="1" class="listing_col">
                              <input type="file" name="pf_photoContent" id="pf_photoContent"onblur="javascript: getFileName(this.form, this, this.form.pf_photo);">
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_photo">Photo</label>
                            </th>
                            <td nowrap="1" class="listing_col">
                              <input type="text" name="pf_photo" id="pf_photo" value="<% out.print(xpathEvaluate($_document, "/user/photo")); %>" style="width: 400px;" >
                              <select name="pf_acl_photo" id="pf_acl_photo">
                                <%
                                  outACLOptions (out, "/acl/photo");
                                %>
                              </select>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_audioContent">Upload Audio</label>
                            </th>
                            <td nowrap="1" class="listing_col">
                              <input type="file" name="pf_audioContent" id="pf_audioContent"onblur="javascript: getFileName(this.form, this, this.form.pf_audio);">
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_audio">Audio</label>
                            </th>
                            <td nowrap="1" class="listing_col">
                              <input type="text" name="pf_audio" id="pf_audio"value="<% out.print(xpathEvaluate($_document, "/user/audio")); %>" style="width: 400px;" >
                              <select name="pf_acl_audio" id="pf_acl_audio">
                                <%
                                  outACLOptions (out, "/acl/audio");
                                %>
                              </select>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_appSetting">Show &lt;a&gt;++ links</label>
                            </th>
                            <td>
                              <select name="pf_appSetting" id="pf_appSetting">
                                <%
                                  {
                                    String[] V = {"0", "disabled", "1", "click", "2", "hover"};
                                    String S = xpathEvaluate($_document, "/user/appSetting");
                                    for (int N = 0; N < V.length; N += 2)
                                      out.print("<option value=\"" + V[N] + "\" " + ((V[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N+1] + "</option>");
                                  }
                                %>
                              </select>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_set_0_1">Set access for all fields as </label>
                            </th>
                            <td>
                              <select name="pf_set_0_1" id="pf_set_0_1" value="0" class="dummy" onchange="javascript: pfSetACLSelects (this)">
                                <option value="0">*no change*</option>
                                <option value="1">public</option>
                                <option value="2">friends</option>
                                <option value="3">private</option>
                              </select>
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
                            <td>
                          <select name="pf_homecountry" id="pf_homecountry" onchange="javascript: return updateState('pf_homecountry', 'pf_homestate');" style="width: 220px;">
                            <option></option>
                            <%
                              outSelectOptions (out, xpathEvaluate($_document, "/user/homeCountry"), "Country");
                            %>
                          </select>
                              <select name="pf_acl_homeCountry" id="pf_acl_homeCountry">
                                <%
                                  outACLOptions (out, "/acl/homeCountry");
                                %>
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
                                  OAT.MSG.attach(OAT, "PAGE_LOADED", function (){updateState("pf_homecountry", "pf_homestate", "<% out.print(xpathEvaluate($_document, "/user/homeState")); %>");});
                            </script>
                          </span>
                              <select name="pf_acl_homeState" id="pf_acl_homeState">
                                <%
                                  outACLOptions (out, "/acl/homeState");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homecity">City/Town</label>
                        </th>
                            <td>
                              <input type="text" name="pf_homecity" value="<% out.print(xpathEvaluate($_document, "/user/homeCity")); %>" id="pf_homecity" style="width: 216px;" />
                              <select name="pf_acl_homeCity" id="pf_acl_homeCity">
                                <%
                                  outACLOptions (out, "/acl/homeCity");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homecode">Zip/Postal Code</label>
                        </th>
                            <td>
                              <input type="text" name="pf_homecode" value="<% out.print(xpathEvaluate($_document, "/user/homeCode")); %>" id="pf_homecode" style="width: 216px;"/>
                              <select name="pf_acl_homeCode" id="pf_acl_homeCode">
                                <%
                                  outACLOptions (out, "/acl/homeCode");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeaddress1">Address1</label>
                        </th>
                            <td>
                              <input type="text" name="pf_homeaddress1" value="<% out.print(xpathEvaluate($_document, "/user/homeAddress1")); %>" id="pf_homeaddress1" style="width: 216px;" />
                              <select name="pf_acl_homeAddress1" id="pf_acl_homeAddress1">
                                <%
                                  outACLOptions (out, "/acl/homeAddress1");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeaddress2">Address2</label>
                        </th>
                            <td>
                              <input type="text" name="pf_homeaddress2" value="<% out.print(xpathEvaluate($_document, "/user/homeAddress2")); %>" id="pf_homeaddress2" style="width: 216px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeTimezone">Time-Zone</label>
                        </th>
                        <td>
                              <select name="pf_homeTimezone" id="pf_homeTimezone" style="width: 114px;" >
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
                              <select name="pf_acl_homeTimezone" id="pf_acl_homeTimezone">
                                <%
                                  outACLOptions (out, "/acl/homeTimezone");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homelat">Latitude</label>
                        </th>
                            <td>
                              <input type="text" name="pf_homelat" value="<% out.print(xpathEvaluate($_document, "/user/homeLatitude")); %>" id="pf_homelat" style="width: 110px;" />
                              <select name="pf_acl_homeLatitude" id="pf_acl_homeLatitude">
                                <%
                                  outACLOptions (out, "/acl/homeLatitude");
                                %>
                              </select>
                        <td>
                      <tr>
                      <tr>
                        <th>
                          <label for="pf_homelng">Longitude</label>
                        </th>
                        <td>
                              <input type="text" name="pf_homelng" value="<% out.print(xpathEvaluate($_document, "/user/homeLongitude")); %>" id="pf_homelng" style="width: 110px;" />
                              <label>
                                <input type="checkbox" name="pf_homeDefaultMapLocation" id="pf_homeDefaultMapLocation" onclick="javascript: setDefaultMapLocation('home', 'business');" />
                                Default Map Location
                              </label>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homePhone">Phone</label>
                        </th>
                        <td>
                              <input type="text" name="pf_homePhone" value="<% out.print(xpathEvaluate($_document, "/user/homePhone")); %>" id="pf_homePhone" style="width: 110px;" />
                              <b>Ext.</b>
                              <input type="text" name="pf_homePhoneExt" value="<% out.print(xpathEvaluate($_document, "/user/homePhoneExt")); %>" id="pf_homePhoneExt" style="width: 40px;" />
                              <select name="pf_acl_homePhone" id="pf_acl_homePhone">
                                <%
                                  outACLOptions (out, "/acl/homePhone");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_homeMobile">Mobile</label>
                        </th>
                        <td>
                              <input type="text" name="pf_homeMobile" value="<% out.print(xpathEvaluate($_document, "/user/homeMobile")); %>" id="pf_homeMobile" style="width: 110px;" />
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_set_0_2">Set access for all fields as </label>
                            </th>
                            <td>
                              <select name="pf_set_0_2" id="pf_set_0_2" value="0" class="dummy" onchange="javascript: pfSetACLSelects (this)">
                                <option value="0">*no change*</option>
                                <option value="1">public</option>
                                <option value="2">friends</option>
                                <option value="3">private</option>
                              </select>
                        </td>
                      </tr>
                    </table>
                  </div>

                      <div id="pf_page_0_3" class="tabContent" style="display:none;">
                        <input type="hidden" name="c_nick" value="<% out.print(xpathEvaluate($_document, "/user/nickName")); %>" id="c_nick" />
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
                                      Member Home Page URI
                                    </th>
                                    <th width="65px">
                                      Action
                                    </th>
                                  </tr>
                                </thead>
                                <tr id="x4_tr_no" style="display: none;"><td colspan="3"><b>No Services</b></td></tr>
                                <script type="text/javascript">
                                  OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowOnlineAccounts("x4", "P", function(prefix, val0, val1, val2){TBL.createRow(prefix, null, {id: val0, fld_1: {mode: 10, value: val1}, fld_2: {value: val2, className: '_validate_ _uri_ _canEmpty_'}});});});
                                </script>
                              </table>
                            </td>
                            <td valign="top" nowrap="1">
                              <span class="button pointer" onclick="TBL.createRow('x4', null, {fld_1: {mode: 10}, fld_2: {className: '_validate_ _uri_ _canEmpty_'}});"><img class="button" src="/ods/images/icons/add_16.png" border="0" alt="Add Row" title="Add Row" /> Add</span>
                        </td>
                      </tr>
                        </table>
                      </div>

                      <div id="pf_page_0_4" class="tabContent" style="display:none;">
                        <table id="x6_tbl" class="form" cellspacing="5">
                      <tr>
                            <th width="30%">
                              <label for="pf_icq">ICQ</label>
                        </th>
                            <td colspan="2">
                              <input type="text" name="pf_icq" value="<% out.print(xpathEvaluate($_document, "/user/icq")); %>" id="pf_icq" style="width: 220px;" />
                              <select name="pf_acl_icq" id="pf_acl_icq">
                                <%
                                  outACLOptions (out, "/acl/icq");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                              <label for="pf_skype">Skype</label>
                        </th>
                            <td colspan="2">
                              <input type="text" name="pf_skype" value="<% out.print(xpathEvaluate($_document, "/user/skype")); %>" id="pf_skype" style="width: 220px;" />
                              <select name="pf_acl_skype" id="pf_acl_skype">
                                <%
                                  outACLOptions (out, "/acl/skype");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                            <th>
                              <label for="pf_yahoo">Yahoo</label>
                        </th>
                            <td colspan="2">
                              <input type="text" name="pf_yahoo" value="<% out.print(xpathEvaluate($_document, "/user/yahoo")); %>" id="pf_yahoo" style="width: 220px;" />
                              <select name="pf_acl_yahoo" id="pf_acl_yahoo">
                                <%
                                  outACLOptions (out, "/acl/yahoo");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                              <label for="pf_aim">AIM</label>
                        </th>
                            <td colspan="2">
                              <input type="text" name="pf_aim" value="<% out.print(xpathEvaluate($_document, "/user/aim")); %>" id="pf_aim" style="width: 220px;" />
                              <select name="pf_acl_aim" id="pf_acl_aim">
                                <%
                                  outACLOptions (out, "/acl/aim");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                              <label for="pf_msn">MSN</label>
                        </th>
                            <td colspan="2">
                              <input type="text" name="pf_msn" value="<% out.print(xpathEvaluate($_document, "/user/msn")); %>" id="pf_msn" style="width: 220px;" />
                              <select name="pf_acl_msn" id="pf_acl_msn">
                                <%
                                  outACLOptions (out, "/acl/msn");
                                %>
                              </select>
                        </td>
                          </tr>
                          <tr>
                            <th>Add other services</th>
                            <td>
                              <span class="button pointer" onclick="TBL.createRow('x6', null, {fld_1: {}, fld_2: {cssText: 'width: 220px;'}});"><img class="button" src="/ods/images/icons/add_16.png" border="0" alt="Add Row" title="Add Row" /> Add</span>
                            </td>
                            <td width="40%">
                        </td>
                      </tr>
                          <tr>
                            <th>
                              <label for="pf_set_0_4">Set access for all fields as </label>
                            </th>
                            <td colspan="2">
                              <select name="pf_set_0_4" id="pf_set_0_4" value="0" class="dummy" onchange="javascript: pfSetACLSelects (this)">
                                <option value="0">*no change*</option>
                                <option value="1">public</option>
                                <option value="2">friends</option>
                                <option value="3">private</option>
                              </select>
                            </td>
                          </tr>
                          <script type="text/javascript">
                            OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowRows("x6", '<% out.print(xpathEvaluate($_document, "/user/messaging").replace("\n", "\\n")); %>', ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1}, fld_2: {value: val2, cssText: 'width: 220px;'}});});});
                          </script>
                        </table>
                      </div>

                      <div id="pf_page_0_5" class="tabContent" style="display:none;">
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
                                    <th width="65px">
                                      Action
                                    </th>
                                  </tr>
                                </thead>
                                <tr id="x5_tr_no" style="display: none;"><td colspan="4"><b>No Biographical Events</b></td></tr>
                                <script type="text/javascript">
                                  OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowBioEvents("x5", function(prefix, val0, val1, val2, val3){TBL.createRow(prefix, null, {id: val0, fld_1: {mode: 11, value: val1}, fld_2: {value: val2}, fld_3: {value: val3}});});});
                                </script>
                              </table>
                            </td>
                            <td valign="top" nowrap="1">
                              <span class="button pointer" onclick="TBL.createRow('x5', null, {fld_1: {mode: 11}, fld_2: {}, fld_3: {}});"><img class="button" src="/ods/images/icons/add_16.png" border="0" alt="Add Row" title="Add Row" /> Add</span>
                            </td>
                          </tr>
                        </table>
                      </div>

                      <%
                      if ($_formTab == 0)
                      {
                        if ($_formSubtab == 6)
                        {
                      %>
                      <div id="pf_page_0_6" class="tabContent" style="display:none;">
                        <h3>Favorites</h3>
                        <%
                          if ($_formMode == "")
                          {
                        %>
                        <div id="pf06_list">
                          <div style="padding: 0 0 0.5em 0;">
                            <span onclick="javascript: $('formMode').value = 'new'; $('page_form').submit();" class="button pointer"><img class="button" border="0" title="Add 'Favorite'" alt="Add 'Favorite'" src="/ods/images/icons/add_16.png"> Add</span>
                          </div>
                      	  <table id="pf06_tbl" class="listing">
                                <thead>
                                  <tr class="listing_header_row">
                        		    <th>Label</th>
                        		    <th>URI</th>
                        		    <th width="1%" nowrap="nowrap">Action</th>
                                  </tr>
                                </thead>
                      	    <tbody id="pf06_tbody">
                                  <script type="text/javascript">
                                    OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowFavorites();});
                                  </script>
                                </tbody>
                              </table>
                        </div>
                        <%
                          }
                          else
                          {
                            out.print("<input type=\"hidden\" id=\"pf06_id\" name=\"pf06_id\" value=\"" + ((getParameter(items, request, "pf06_id") != null) ? getParameter(items, request, "pf06_id"): "0") + "\" />");
                        %>
                        <div id="pf06_form">
                          <table class="form" cellspacing="5">
                            <tr>
                              <th width="25%">
                                Label (*)
                              </th>
                              <td>
                                <input type="text" name="pf06_label" id="pf06_label" value="" class="_validate_" style="width: 400px;">
                            </td>
                            </tr>
                            <tr>
                              <th>
                                External URI
                              </th>
                              <td>
                                <input type="text" name="pf06_uri" id="pf06_uri" value="" class="_validate_ _url_ _canEmpty_" style="width: 400px;">
                              </td>
                            </tr>
                            <tr>
                              <th valign="top">
                                Item Properties
                              </th>
                  		        <td width="800px">
                                <table id="r_tbl" class="listing">
                                  <tbody id="r_tbody">
                                  </tbody>
                                </table>
                        </td>
                      </tr>
                        </table>
                          <script type="text/javascript">
                            OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowFavorite();});
                          </script>
                          <div class="footer">
                            <input type="submit" name="pf_cancel2" value="Cancel" onclick="needToConfirm = false; "/>
                            <input type="submit" name="pf_update06" value="Save" onclick="myBeforeSubmit(); return validateInputs(this, 'pf06');"/>
                          </div>
                      </div>
                      <%
                          }
                        %>
                      </div>
                      <%
                        }
                        else if ($_formSubtab == 7)
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
                                OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowMades();});
                              </script>
                      	    </tbody>
                          </table>
                        </div>
                        <%
                          }
                          else
                          {
                              out.print("<input type=\"hidden\" id=\"pf07_id\" name=\"pf07_id\" value=\"" + ((getParameter(items, request, "pf07_id") != null) ? getParameter(items, request, "pf07_id"): "0") + "\" />");
                        %>
                        <div id="pf07_form">
                          <table class="form" cellspacing="5">
                            <tr>
                              <th width="25%">
                                Property (*)
                              </th>
                              <td id="if_opt">
                                <script type="text/javascript">
                                  function p_init ()
                                  {
                                    var fld = new OAT.Combolist([]);
                                    fld.input.name = 'pf07_property';
                                    fld.input.id = fld.input.name;
                                    fld.input.style.width = "400px";
                                    $("if_opt").appendChild(fld.div);
                                    fld.addOption("foaf:made");
                                    fld.addOption("dc:creator");
                                    fld.addOption("sioc:owner");
                                  }
                                  OAT.MSG.attach(OAT, "PAGE_LOADED", p_init)
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
                                Description (*)
                              </th>
                              <td>
                                <textarea name="pf07_description" id="pf07_description" style="width: 400px;"></textarea>
                              </td>
                            </tr>
                            <tr>
                              <td />
                              <td>
  		                          <b>Note: The fields designated with '*' will be fetched from the source document if empty</b>
                              </td>
                            </tr>
                          </table>
                          <script type="text/javascript">
                            OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowMade();});
                          </script>
                          <div class="footer">
                            <input type="submit" name="pf_cancel2" value="Cancel" onclick="needToConfirm = false; "/>
                            <input type="submit" name="pf_update07" value="Save" onclick="needToConfirm = false; return validateInputs(this, 'pf07');"/>
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
                                OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowOffers();});
                              </script>
                      	    </tbody>
                          </table>
                        </div>
                        <%
                          }
                          else
                          {
                            out.print("<input type=\"hidden\" id=\"pf08_id\" name=\"pf08_id\" value=\"" + ((getParameter(items, request, "pf08_id") != null) ? getParameter(items, request, "pf08_id"): "0") + "\" />");
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
                            OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowOffer();});
                          </script>
                          <div class="footer">
                            <input type="submit" name="pf_cancel2" value="Cancel" onclick="needToConfirm = false;"/>
                            <input type="submit" name="pf_update08" value="Save" onclick="myBeforeSubmit(); return validateInputs(this, 'pf08');"/>
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
                                OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowSeeks();});
                              </script>
                      	    </tbody>
                          </table>
                        </div>
                        <%
                          }
                          else
                          {
                            out.print("<input type=\"hidden\" id=\"pf09_id\" name=\"pf09_id\" value=\"" + ((getParameter(items, request, "pf09_id") != null) ? getParameter(items, request, "pf09_id"): "0") + "\" />");
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
                            OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowSeek();});
                          </script>
                          <div class="footer">
                            <input type="submit" name="pf_cancel2" value="Cancel" onclick="needToConfirm = false;"/>
                            <input type="submit" name="pf_update09" value="Save" onclick="myBeforeSubmit(); return validateInputs(this, 'pf09');"/>
                          </div>
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
                        <input type="submit" name="pf_update" value="Save" onclick="myBeforeSubmit(); return myValidateInputs(this);"/>
                        <input type="submit" name="pf_next" value="Save & Next" onclick="myBeforeSubmit(); return myValidateInputs(this);"/>
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
                    <div style="min-height: 180px; min-width: 650px; border-top: 1px solid #aaa; margin: -13px 5px 5px 5px;">
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
                              <select name="pf_acl_businessIndustry" id="pf_acl_businessIndustry">
                                <%
                                  outACLOptions (out, "/acl/businessIndustry");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                              <label for="pf_businessOrganization">Organization</label>
                        </th>
                        <td nowrap="nowrap">
                              <input type="text" name="pf_businessOrganization" value="<% out.print(xpathEvaluate($_document, "/user/businessOrganization")); %>" id="pf_businessOrganization" style="width: 216px;" />
                              <select name="pf_acl_businessOrganization" id="pf_acl_businessOrganization">
                                <%
                                  outACLOptions (out, "/acl/businessOrganization");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                              <label for="pf_businessHomePage">Organization Home Page</label>
                        </th>
                            <td nowrap="nowrap">
                              <input type="text" name="pf_businessHomePage" value="<% out.print(xpathEvaluate($_document, "/user/businessHomePage")); %>" id="pf_businessNetwork" style="width: 216px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                              <label for="pf_businessJob">Job Title</label>
                        </th>
                            <td nowrap="nowrap">
                              <input type="text" name="pf_businessJob" value="<% out.print(xpathEvaluate($_document, "/user/businessJob")); %>" id="pf_businessJob" style="width: 216px;" />
                              <select name="pf_acl_businessJob" id="pf_acl_businessJob">
                                <%
                                  outACLOptions (out, "/acl/businessJob");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessRegNo">VAT Reg number (EU only) or Tax ID</label>
                        </th>
                        <td>
                              <input type="text" name="pf_businessRegNo" value="<% out.print(xpathEvaluate($_document, "/user/businessRegNo")); %>" id="pf_businessRegNo" style="width: 216px;" />
                              <select name="pf_acl_businessRegNo" id="pf_acl_businessRegNo">
                                <%
                                  outACLOptions (out, "/acl/businessRegNo");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessCareer">Career / Organization Status</label>
                        </th>
                        <td>
                          <select name="pf_businessCareer" id="pf_businessCareer" style="width: 220px;">
                                <option></option>
                            <%
                              {
                                String[] V = {"Job seeker-Permanent", "Job seeker-Temporary", "Job seeker-Temp/perm", "Employed-Unavailable", "Employer", "Agency", "Resourcing supplier"};
                                String S = xpathEvaluate($_document, "/user/businessCareer");
                                for (int N = 0; N < V.length; N++)
                                  out.print("<option" + ((V[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N] + "</option>");
                              }
                            %>
                          </select>
                              <select name="pf_acl_businessCareer" id="pf_acl_businessCareer">
                                <%
                                  outACLOptions (out, "/acl/businessCareer");
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
                                <option></option>
                            <%
                              {
                                String[] V = {"1-100", "101-250", "251-500", "501-1000", ">1000"};
                                String S = xpathEvaluate($_document, "/user/businessEmployees");
                                for (int N = 0; N < V.length; N++)
                                  out.print("<option" + ((V[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N] + "</option>");
                              }
                            %>
                          </select>
                              <select name="pf_acl_businessEmployees" id="pf_acl_businessEmployees">
                                <%
                                  outACLOptions (out, "/acl/businessEmployees");
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
                                <option></option>
                            <%
                              {
                                String[] V = {"Not a Vendor", "Vendor", "VAR", "Consultancy"};
                                String S = xpathEvaluate($_document, "/user/businessVendor");
                                for (int N = 0; N < V.length; N++)
                                  out.print("<option" + ((V[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N] + "</option>");
                              }
                            %>
                          </select>
                              <select name="pf_acl_businessVendor" id="pf_acl_businessVendor">
                                <%
                                  outACLOptions (out, "/acl/businessVendor");
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
                                <option></option>
                            <%
                              {
                                String[] V = {"Enterprise Data Integration", "Business Process Management", "Other"};
                                String S = xpathEvaluate($_document, "/user/businessService");
                                for (int N = 0; N < V.length; N++)
                                  out.print("<option" + ((V[N].equals(S)) ? (" selected=\"selected\""): ("")) + ">" + V[N] + "</option>");
                              }
                            %>
                          </select>
                              <select name="pf_acl_businessService" id="pf_acl_businessService">
                                <%
                                  outACLOptions (out, "/acl/businessService");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessOther">Other Technology service</label>
                        </th>
                        <td>
                              <input type="text" name="pf_businessOther" value="<% out.print(xpathEvaluate($_document, "/user/businessOther")); %>" id="pf_businessOther" style="width: 216px;" />
                              <select name="pf_acl_businessOther" id="pf_acl_businessOther">
                                <%
                                  outACLOptions (out, "/acl/businessOther");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessNetwork">Importance of OpenLink Network for you</label>
                        </th>
                        <td>
                              <input type="text" name="pf_businessNetwork" value="<% out.print(xpathEvaluate($_document, "/user/businessNetwork")); %>" id="pf_businessNetwork" style="width: 216px;" />
                              <select name="pf_acl_businessNetwork" id="pf_acl_businessNetwork">
                                <%
                                  outACLOptions (out, "/acl/businessNetwork");
                                %>
                              </select>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_businessResume">Resume</label>
                        </th>
                        <td>
                          <textarea name="pf_businessResume" id="pf_businessResume" style="width: 400px;"><% out.print(xpathEvaluate($_document, "/user/businessResume")); %></textarea>
                              <select name="pf_acl_businessResume" id="pf_acl_businessResume">
                                <%
                                  outACLOptions (out, "/acl/businessResume");
                                %>
                              </select>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_set_1_0">Set access for all fields as </label>
                            </th>
                            <td>
                              <select name="pf_set_1_0" id="pf_set_1_0" value="0" class="dummy" onchange="javascript: pfSetACLSelects (this)">
                                <option value="0">*no change*</option>
                                <option value="1">public</option>
                                <option value="2">friends</option>
                                <option value="3">private</option>
                              </select>
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
                              <select name="pf_acl_businessCountry" id="pf_acl_businessCountry">
                                <%
                                  outACLOptions (out, "/acl/businessCountry");
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
                                  OAT.MSG.attach(OAT, "PAGE_LOADED", function (){updateState("pf_businesscountry", "pf_businessstate", "<% out.print(xpathEvaluate($_document, "/user/businessState")); %>");});
                                </script>
                              </span>
                              <select name="pf_acl_businessState" id="pf_acl_businessState">
                                <%
                                  outACLOptions (out, "/acl/businessState");
                                %>
                              </select>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businesscity">City/Town</label>
                            </th>
                            <td nowrap="nowrap">
                              <input type="text" name="pf_businesscity" value="<% out.print(xpathEvaluate($_document, "/user/businessCity")); %>" id="pf_businesscity" style="width: 216px;" />
                              <select name="pf_acl_businessCity" id="pf_acl_businessCity">
                                <%
                                  outACLOptions (out, "/acl/businessCity");
                                %>
                              </select>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businesscode">Zip/Postal Code</label>
                            </th>
                            <td nowrap="nowrap">
                              <input type="text" name="pf_businesscode" value="<% out.print(xpathEvaluate($_document, "/user/businessCode")); %>" id="pf_businesscode" style="width: 216px;"/>
                              <select name="pf_acl_businessCode" id="pf_acl_businessCode">
                                <%
                                  outACLOptions (out, "/acl/businessCode");
                                %>
                              </select>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businessaddress1">Address1</label>
                            </th>
                            <td nowrap="nowrap">
                              <input type="text" name="pf_businessaddress1" value="<% out.print(xpathEvaluate($_document, "/user/businessAddress1")); %>" id="pf_businessaddress1" style="width: 216px;" />
                              <select name="pf_acl_businessAddress1" id="pf_acl_businessAddress1">
                                <%
                                  outACLOptions (out, "/acl/businessAddress1");
                                %>
                              </select>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businessaddress2">Address2</label>
                            </th>
                            <td nowrap="nowrap">
                              <input type="text" name="pf_businessaddress2" value="<% out.print(xpathEvaluate($_document, "/user/businessAddress2")); %>" id="pf_businessaddress2" style="width: 216px;" />
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businessTimezone">Time-Zone</label>
                            </th>
                            <td>
                              <select name="pf_businessTimezone" id="pf_businessTimezone" style="width: 114px;">
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
                              <select name="pf_acl_businessTimezone" id="pf_acl_businessTimezone">
                                <%
                                  outACLOptions (out, "/acl/businessTimezone");
                                %>
                              </select>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businesslat">Latitude</label>
                            </th>
                            <td nowrap="nowrap">
                              <input type="text" name="pf_businesslat" value="<% out.print(xpathEvaluate($_document, "/user/businessLatitude")); %>" id="pf_businesslat" style="width: 110px;" />
                              <select name="pf_acl_businessLatitude" id="pf_acl_businessLatitude">
                                <%
                                  outACLOptions (out, "/acl/businessLatitude");
                                %>
                              </select>
                            <td>
                          <tr>
                          <tr>
                            <th>
                              <label for="pf_businesslng">Longitude</label>
                            </th>
                            <td>
                              <input type="text" name="pf_businesslng" value="<% out.print(xpathEvaluate($_document, "/user/businessLongitude")); %>" id="pf_businesslng" style="width: 110px;" />
                              <label>
                                <input type="checkbox" name="pf_businessDefaultMapLocation" id="pf_businessDefaultMapLocation" onclick="javascript: setDefaultMapLocation('business', 'business');" />
                                Default Map Location
                              </label>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businessPhone">Phone</label>
                            </th>
                            <td>
                              <input type="text" name="pf_businessPhone" value="<% out.print(xpathEvaluate($_document, "/user/businessPhone")); %>" id="pf_businessPhone" style="width: 110px;" />
                              <b>Ext.</b>
                              <input type="text" name="pf_businessPhoneExt" value="<% out.print(xpathEvaluate($_document, "/user/businessPhoneExt")); %>" id="pf_businessPhoneExt" style="width: 40px;" />
                              <select name="pf_acl_businessPhone" id="pf_acl_businessPhone">
                                <%
                                  outACLOptions (out, "/acl/businessPhone");
                                %>
                              </select>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businessMobile">Mobile</label>
                            </th>
                            <td>
                              <input type="text" name="pf_businessMobile" value="<% out.print(xpathEvaluate($_document, "/user/businessMobile")); %>" id="pf_businessMobile" style="width: 110px;" />
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_set_1_1">Set access for all fields as </label>
                            </th>
                            <td>
                              <select name="pf_set_1_1" id="pf_set_1_1" value="0" class="dummy" onchange="javascript: pfSetACLSelects (this)">
                                <option value="0">*no change*</option>
                                <option value="1">public</option>
                                <option value="2">friends</option>
                                <option value="3">private</option>
                              </select>
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
                                      Member Home Page URI
                                    </th>
                                    <th width="65px">
                                      Action
                                    </th>
                                  </tr>
                                </thead>
                                <tr id="y1_tr_no" style="display: none;"><td colspan="3"><b>No Services</b></td></tr>
                                <script type="text/javascript">
                                  OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowOnlineAccounts("y1", "B", function(prefix, val0, val1, val2){TBL.createRow(prefix, null, {id: val0, fld_1: {mode: 10, value: val1}, fld_2: {value: val2, className: '_validate_ _uri_ _canEmpty_'}});});});
                                </script>
                              </table>
                            </td>
                            <td valign="top" nowrap="1">
                              <span class="button pointer" onclick="TBL.createRow('y1', null, {fld_1: {mode: 10}, fld_2: {className: '_validate_ _uri_ _canEmpty_'}});"><img class="button" src="/ods/images/icons/add_16.png" border="0" alt="Add Row" title="Add Row" /> Add</span>
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
                              <select name="pf_acl_businessIcq" id="pf_acl_businessIcq">
                                <%
                                  outACLOptions (out, "/acl/businessIcq");
                                %>
                              </select>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businessSkype">Skype</label>
                            </th>
                            <td colspan="2">
                              <input type="text" name="pf_businessSkype" value="<% out.print(xpathEvaluate($_document, "/user/businessSkype")); %>" id="pf_businessSkype" style="width: 220px;" />
                              <select name="pf_acl_businessSkype" id="pf_acl_businessSkype">
                                <%
                                  outACLOptions (out, "/acl/businessSkype");
                                %>
                              </select>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businessYahoo">Yahoo</label>
                            </th>
                            <td colspan="2">
                              <input type="text" name="pf_businessYahoo" value="<% out.print(xpathEvaluate($_document, "/user/businessYahoo")); %>" id="pf_businessYahoo" style="width: 220px;" />
                              <select name="pf_acl_businessYahoo" id="pf_acl_businessYahoo">
                                <%
                                  outACLOptions (out, "/acl/businessYahoo");
                                %>
                              </select>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businessAim">AIM</label>
                            </th>
                            <td colspan="2">
                              <input type="text" name="pf_businessAim" value="<% out.print(xpathEvaluate($_document, "/user/businessAim")); %>" id="pf_businessAim" style="width: 220px;" />
                              <select name="pf_acl_businessAim" id="pf_acl_businessAim">
                                <%
                                  outACLOptions (out, "/acl/businessAim");
                                %>
                              </select>
                            </td>
                          </tr>
                          <tr>
                            <th>
                              <label for="pf_businessMsn">MSN</label>
                            </th>
                            <td colspan="2">
                              <input type="text" name="pf_businessMsn" value="<% out.print(xpathEvaluate($_document, "/user/businessMsn")); %>" id="pf_businessMsn" style="width: 220px;" />
                              <select name="pf_acl_businessMsn" id="pf_acl_businessMsn">
                                <%
                                  outACLOptions (out, "/acl/businessMsn");
                                %>
                              </select>
                            </td>
                          </tr>
                          <tr>
                            <th>Add other services</th>
                            <td>
                              <span class="button pointer" onclick="TBL.createRow('y2', null, {fld_1: {}, fld_2: {cssText: 'width: 220px;'}});"><img class="button" src="/ods/images/icons/add_16.png" border="0" alt="Add Row" title="Add Row" /> Add</span>
                            </td>
                            <td width="40%">
                        </td>
                      </tr>
                          <tr>
                            <th>
                              <label for="pf_set_1_3">Set access for all fields as </label>
                            </th>
                            <td colspan="2">
                              <select name="pf_set_1_3" id="pf_set_1_3" value="0" class="dummy" onchange="javascript: pfSetACLSelects (this)">
                                <option value="0">*no change*</option>
                                <option value="1">public</option>
                                <option value="2">friends</option>
                                <option value="3">private</option>
                              </select>
                            </td>
                          </tr>
                          <script type="text/javascript">
                            OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowRows("y2", '<% out.print(xpathEvaluate($_document, "/user/businessMessaging").replace("\n", "\\n")); %>', ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1}, fld_2: {value: val2, cssText: 'width: 220px;'}});});});
                          </script>
                    </table>
                  </div>

                      <div class="footer">
                        <input type="submit" name="pf_cancel" value="Cancel" onclick="needToConfirm = false;"/>
                        <input type="submit" name="pf_update" value="Save" onclick="myBeforeSubmit(); return myValidateInputs(this);"/>
                        <input type="submit" name="pf_next" value="Save & Next" onclick="myBeforeSubmit(); return myValidateInputs(this);"/>
                      </div>
                    </div>
                  </div>

                  <div id="pf_page_2" class="tabContent" style="display:none;">
                    <ul id="pf_tabs_2" class="tabs">
                      <li id="pf_tab_2_0" title="Password Settings">Password Settings</li>
                      <li id="pf_tab_2_1" title="Password Recovery">Password Recovery</li>
                      <li id="pf_tab_2_2" title="OpenID">OpenID</li>
                      <li id="pf_tab_2_3" title="Facebook" style="display:none;">Facebook</li>
                      <li id="pf_tab_2_4" title="Limits">Limits</li>
                      <li id="pf_tab_2_5" title="Certificate Generator" style="display:none;">Certificate Generator</li>
                      <li id="pf_tab_2_6" title="X.509 Certificates">X.509 Certificates</li>
                    </ul>
                    <div style="min-height: 180px; min-width: 650px; border-top: 1px solid #aaa; margin: -13px 5px 5px 5px;">
                      <div id="pf_page_2_0" class="tabContent" style="display:none;">
                    <table class="form" cellspacing="5">
                      <tr>
                        <td align="center" colspan="2">
                          <span id="pf_change_txt"></span>
                        </td>
                      </tr>
                          <%
                          if (xpathEvaluate($_document, "/user/noPassword").equals("0"))
                          {
                          %>
                      <tr>
                        <th width="30%">
                          <label for="pf_oldPassword">Old Password</label>
                        </th>
                        <td>
                          <input type="password" name="pf_oldPassword" value="" id="pf_oldPassword" />
                        </td>
                      </tr>
                          <%
                          }
                          %>
                      <tr>
                            <th width="30%">
                          <label for="pf_newPassword">New Password</label>
                        </th>
                        <td>
                          <input type="password" name="pf_newPassword" value="" id="pf_newPassword" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_password">Repeat Password</label>
                        </th>
                        <td>
                          <input type="password" name="pf_newPassword2" value="" id="pf_newPassword2" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                        </th>
                      </tr>
                        </table>
                      </div>
                      <div id="pf_page_2_1" class="tabContent" style="display:none;">
                        <table class="form" cellspacing="5">
                      <tr>
                        <th>
                          <label for="pf_securitySecretQuestion">Secret Question</label>
                        </th>
                        <td id="td_securitySecretQuestion">
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
                            OAT.MSG.attach(OAT, "PAGE_LOADED", categoryCombo);
                          </script>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="pf_securitySecretAnswer">Secret Answer</label>
                        </th>
                        <td>
                          <input type="text" name="pf_securitySecretAnswer" value="<% out.print(xpathEvaluate($_document, "/user/securitySecretAnswer")); %>" id="pf_securitySecretAnswer" style="width: 220px;" />
                        </td>
                      </tr>
                        </table>
                      </div>
                      <div id="pf_page_2_2" class="tabContent" style="display:none;">
                        <table class="form" cellspacing="5">
                      <tr>
                        <th>
                              <label for="pf_openID">OpenID URL</label>
                        </th>
                        <td>
                              <input type="text" name="pf_openID" value="<% out.print(xpathEvaluate($_document, "/user/securityOpenID")); %>" id="pf_openID" style="width: 220px;" />
                        </td>
                      </tr>
                        </table>
                      </div>
                      <div id="pf_page_2_3" class="tabContent" style="display:none;">
                        <table class="form" cellspacing="5">
                      <tr>
                            <th>
                              Saved Facebook ID
                        </th>
                            <td>
                              <%
                                if ((xpathEvaluate($_document, "/user/securityFacebookID") != null) && (xpathEvaluate($_document, "/user/securityFacebookID") != ""))
                                {
                                  out.print(xpathEvaluate($_document, "/user/securityFacebookName"));
                                } else {
                                  out.print("not yet");
                                }
                              %>
                            </td>
                      </tr>
                      <tr>
                        <th>
                        </th>
                        <td>
                              <span id="pf_facebookData" style="min-height: 20px;"></span>
                              <br />
                              <script src="http://static.ak.connect.facebook.com/js/api_lib/v0.4/FeatureLoader.js.php" type="text/javascript"></script>
                              <fb:login-button autologoutlink="true"></fb:login-button>
                        </td>
                      </tr>
                        </table>
                      </div>
                      <div id="pf_page_2_4" class="tabContent" style="display:none;">
                        <table class="form" cellspacing="5">
                      <tr>
                            <th>
                              <label for="pf_securitySiocLimit">SIOC Query Result Limit</label>
                        </th>
                            <td>
                              <input type="text" name="pf_securitySiocLimit" value="<% out.print(xpathEvaluate($_document, "/user/securitySiocLimit")); %>" id="pf_securitySiocLimit" />
                            </td>
                      </tr>
                        </table>
                      </div>
                      <%
                      if (($_formTab == 2) && ($_formSubtab == 5))
                      {
                      %>
                      <div id="pf_page_2_5" class="tabContent" style="display:none;">
            	          <iframe id="cert" src="/ods/cert.vsp?sid=<% out.print($_sid); %>" width="650" height="270" frameborder="0" scrolling="no">
            	            <p>Your browser does not support iframes.</p>
            	          </iframe>
                      </div>
                      <%
                      }
                      else if (($_formTab == 2) && ($_formSubtab == 6))
                      {
                      %>
                      <div id="pf_page_2_6" class="tabContent" style="display:none;">
                        <h3>X.509 Certificates</h3>
              	      <%
                          if ($_formMode == "")
                          {
                        %>
                        <div id="pf26_list">
                          <div style="padding: 0 0 0.5em 0;">
                            <span onclick="javascript: $('formMode').value = 'new'; $('page_form').submit();" class="button pointer"><img class="button" border="0" title="Add 'Fovorite'" alt="Add 'Fovorite'" src="/ods/images/icons/add_16.png"> Add</span>
                          </div>
                      	  <table id="pf26_tbl" class="listing">
                      	    <thead>
                      	      <tr class="listing_header_row">
                        		    <th>Subject</th>
                          		  <th>Created</th>
                          		  <th>Fingerprint</th>
                          		  <th>Login enabled</th>
                        		    <th width="1%" nowrap="nowrap">Action</th>
                      	      </tr>
                            </thead>
                      	    <tbody id="pf26_tbody">
                              <script type="text/javascript">
                                OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowCertificates();});
                              </script>
                      	    </tbody>
                          </table>
                        </div>
                        <%
                          }
                          else
                          {
                            out.print("<input type=\"hidden\" id=\"pf26_id\" name=\"pf26_id\" value=\"" + ((getParameter(items, request, "pf26_id") != null) ? getParameter(items, request, "pf26_id"): "0") + "\" />");
                        %>
                        <div id="pf26_form">
                          <table class="form" cellspacing="5">
                            <%
                            if ($_formMode.equals("edit"))
              	        {
              	      %>
                      <tr>
                        <th>
                	    	  Subject
                        </th>
                        <td>
                          		  <span id="pf26_subject"></span>
                    		</td>
                      </tr>
                      <tr>
                        <th>
                	    	  Agent ID
                        </th>
                        <td>
                          		  <span id="pf26_agentID"></span>
                          		</td>
                            </tr>
                            <tr>
                              <th>
                      	    	  Fingerprint
                              </th>
                              <td>
                          		  <span id="pf26_fingerPrint"></span>
                    		</td>
                      </tr>
            	        <%
            	          }
            	        %>
                      <tr>
                        <th valign="top">
                                <label for="pf26_certificate">Certificate</label>
                        </th>
                        <td>
                                <textarea name="pf26_certificate" id="pf26_certificate" rows="20" style="width: 560px;"></textarea>
                        </td>
                      </tr>
                      <tr>
                        <th></th>
                        <td>
                          <label>
                                  <input type="checkbox" name="pf26_enableLogin" id="pf26_enableLogin" value="1"/>
                            Enable Automatic WebID Login
                          </label>
                        </td>
                      </tr>
                    </table>
                          <script type="text/javascript">
                            OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowCertificate();});
                          </script>
                          <div class="footer">
                            <input type="submit" name="pf_cancel2" value="Cancel" onclick="needToConfirm = false;"/>
                            <input type="submit" name="pf_update26" value="Save" onclick="needToConfirm = false; return validateInputs(this, 'pf26');"/>
                          </div>
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
                        <%
                          if (($_formTab == 2) && ($_formSubtab == 3) && (xpathEvaluate($_document, "/user/securityFacebookID") != null))
                          {
                        %>
                        <input type="submit" name="pf_clear" value="Clear" onclick="myBeforeSubmit(); return myValidateInputs(this);"/>
                        <%
                          }
                        %>
                        <input type="submit" name="pf_update" value="Save" onclick="myBeforeSubmit(); return myValidateInputs(this);"/>
                        <input type="submit" name="pf_next" value="Save & Next" onclick="myBeforeSubmit(); return myValidateInputs(this);"/>
                      </div>
                      <%
                        }
                      %>
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
