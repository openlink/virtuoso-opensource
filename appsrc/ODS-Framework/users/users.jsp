<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2013 OpenLink Software
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
  <%!
    XPathFactory factory = XPathFactory.newInstance();
    XPath xpath = factory.newXPath();
    Document $_acl = null;
    String[] $_ACL = {"public", "1", "acl", "2", "private", "3"};

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

    String getParameterDefault(List items, HttpServletRequest req, String param, String defaultValue)
      throws IOException, FileUploadException
    {
      String value = getParameter(items, req, param);
      if (value == null)
        value = defaultValue;

      return value;
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

    String $_retValue;
    Document $_document = null;
    String params = null;

    Boolean $_validate = false;
    String $_error = "";
    String $_userName = getParameter(items, request, "userName");
    String $_sid = getParameter(items, request, "sid");
    String $_realm = "wa";
    // System.out.println($_sid);
    if ($_sid != null) {
      params = httpParam( "", "sid", $_sid) +
               httpParam("&", "realm", $_realm);
      if ($_userName != null)
        params += httpParam( "&", "name", $_userName);

      $_retValue = httpRequest ("POST", "user.validate", params);
      if ($_retValue.indexOf("<result>") == 0)
      {
        $_validate = true;
      }
    }

    String $_form = null;
    String $_oidForm = getParameter(items, request, "oid-form");
    if ($_oidForm == null) {
      $_form = getParameter(items, request, "form");
    if ($_form == null) {
      if ($_userName != null) {
        $_form = "user";
      } else {
        $_form = "login";
      }
    }
    } else {
      if ($_oidForm.equals("lf"))
        $_form = "login";
      if ($_oidForm.equals("rf"))
        $_form = "register";
    }

    int $_formTab = 0;
    if (getParameter(items, request, "formTab") != null)
      $_formTab = Integer.parseInt(getParameter(items, request, "formTab"));
    int $_formTab2 = 0;
    if (getParameter(items, request, "formTab2") != null)
      $_formTab2 = Integer.parseInt(getParameter(items, request, "formTab2"));
    String $_formMode = "";
    if (getParameter(items, request, "formMode") != null)
      $_formMode = getParameter(items, request, "formMode");
  String $_host;
  String $_hostLinks = "";
  String $_userLinks = "";

    try
    {
      if ($_form.equals("login"))
      {
        if (getParameter(items, request, "lf_register") != null)
          $_form = "register";
        }

      if ($_form.equals("profile"))
      {
        if (getParameter(items, request, "pf_update051") != null)
        {
          params = httpParam( "", "sid", $_sid) +
                   httpParam("&", "realm", $_realm) +
                   httpParam("&", "id", getParameter(items, request, "pf051_id")) +
                   httpParam("&", "flag", getParameter(items, request, "pf051_flag")) +
                   httpParam("&", "name", getParameter(items, request, "pf051_name")) +
                   httpParam("&", "comment", getParameter(items, request, "pf051_comment")) +
                   httpParam("&", "properties", getParameter(items, request, "items"));
          $_retValue = httpRequest ("POST", "user.owns."+$_formMode, params);
          if ($_retValue.indexOf("<failed>") == 0)
          {
		        $_document = createDocument($_retValue);
            throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
          $_formMode = "";
        }
        else if (getParameter(items, request, "pf_update052") != null)
        {
          params = httpParam( "", "sid", $_sid) +
                   httpParam("&", "realm", $_realm) +
                   httpParam("&", "id", getParameter(items, request, "pf052_id")) +
                   httpParam("&", "flag", getParameter(items, request, "pf052_flag")) +
                   httpParam("&", "label", getParameter(items, request, "pf052_label")) +
                   httpParam("&", "uri", getParameter(items, request, "pf052_uri")) +
                   httpParam("&", "properties", getParameter(items, request, "items"));
          $_retValue = httpRequest ("POST", "user.favorites."+$_formMode, params);
          if ($_retValue.indexOf("<failed>") == 0)
          {
		        $_document = createDocument($_retValue);
            throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
          $_formMode = "";
        }
        else if (getParameter(items, request, "pf_update053") != null)
        {
          params = httpParam( "", "sid", $_sid) +
                   httpParam("&", "realm", $_realm) +
                   httpParam("&", "id", getParameter(items, request, "pf053_id")) +
                   httpParam("&", "property", getParameter(items, request, "pf053_property")) +
                   httpParam("&", "url", getParameter(items, request, "pf053_url")) +
                   httpParam("&", "description", getParameter(items, request, "pf053_description"));
          $_retValue = httpRequest ("POST", "user.mades."+$_formMode, params);
          if ($_retValue.indexOf("<failed>") == 0)
          {
		        $_document = createDocument($_retValue);
            throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
          $_formMode = "";
        }
        else if (getParameter(items, request, "pf_update054") != null)
        {
          params = httpParam( "", "sid", $_sid) +
                   httpParam("&", "realm", $_realm) +
                   httpParam("&", "id", getParameter(items, request, "pf054_id")) +
                   httpParam("&", "flag", getParameter(items, request, "pf054_flag")) +
                   httpParam("&", "name", getParameter(items, request, "pf054_name")) +
                   httpParam("&", "comment", getParameter(items, request, "pf054_comment")) +
                   httpParam("&", "properties", getParameter(items, request, "items"));
          $_retValue = httpRequest ("POST", "user.offers."+$_formMode, params);
          if ($_retValue.indexOf("<failed>") == 0)
          {
		        $_document = createDocument($_retValue);
            throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
          $_formMode = "";
        }
        else if (getParameter(items, request, "pf_update055") != null)
        {
          params = httpParam( "", "sid", $_sid) +
                   httpParam("&", "realm", $_realm) +
                   httpParam("&", "id", getParameter(items, request, "pf055_id")) +
                   httpParam("&", "flag", getParameter(items, request, "pf055_flag")) +
                   httpParam("&", "name", getParameter(items, request, "pf055_name")) +
                   httpParam("&", "comment", getParameter(items, request, "pf055_comment")) +
                   httpParam("&", "properties", getParameter(items, request, "items"));
          $_retValue = httpRequest ("POST", "user.seeks."+$_formMode, params);
          if ($_retValue.indexOf("<failed>") == 0)
          {
		        $_document = createDocument($_retValue);
            throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
          $_formMode = "";
        }
        else if (getParameter(items, request, "pf_update056") != null)
        {
          params = httpParam( "", "sid", $_sid) +
                   httpParam("&", "realm", $_realm) +
                   httpParam("&", "id", getParameter(items, request, "pf056_id")) +
                   httpParam("&", "flag", getParameter(items, request, "pf056_flag")) +
                   httpParam("&", "uri", getParameter(items, request, "pf056_uri")) +
                   httpParam("&", "type", getParameter(items, request, "pf056_type")) +
                   httpParam("&", "name", getParameter(items, request, "pf056_name")) +
                   httpParam("&", "comment", getParameter(items, request, "pf056_comment")) +
                   httpParam("&", "properties", getParameter(items, request, "items"));
          $_retValue = httpRequest ("POST", "user.likes."+$_formMode, params);
          if ($_retValue.indexOf("<failed>") == 0)
          {
		        $_document = createDocument($_retValue);
            throw new Exception(xpathEvaluate($_document, "/failed/message"));
          }
          $_formMode = "";
        }
        else if (getParameter(items, request, "pf_update057") != null)
        {
          List items2 = new ArrayList();
          if ($_formMode.equals("import"))
          {
            Enumeration keys = request.getParameterNames();
    		    while (keys.hasMoreElements())
    		    {
    		      String key = (String)keys.nextElement();
              if (key.indexOf("k_fld_1_") == 0)
              {
                String suffix = key.replace("k_fld_1_", "");
                items2.add(new String[]{"",
                                        getParameter(items, request, "k_fld_1_"+suffix),
                                        getParameter(items, request, "k_fld_2_"+suffix),
                                        getParameter(items, request, "k_fld_3_"+suffix)
                                       }
                          );
              }
            }
            $_formMode = "new";
          } else {
            items2.add(new String[]{getParameter(items, request, "pf057_id"),
                                    getParameter(items, request, "pf057_flag"),
                                    getParameter(items, request, "pf057_uri"),
                                    getParameter(items, request, "pf057_label")
                                   }
                      );
          }
          for (int N = 0; N < items2.size(); N++)
          {
            String[] item = (String[])items2.get(N);
            params = httpParam( "", "sid", $_sid) +
                     httpParam("&", "realm", $_realm) +
                     httpParam("&", "id", item[0]) +
                     httpParam("&", "flag", item[1]) +
                     httpParam("&", "uri", item[2]) +
                     httpParam("&", "label", item[3]);
            $_retValue = httpRequest ("POST", "user.knows."+$_formMode, params);
            if ($_retValue.indexOf("<failed>") == 0)
            {
  		        $_document = createDocument($_retValue);
              throw new Exception($_formMode + xpathEvaluate($_document, "/failed/message"));
            }
          }
          $_formMode = "";
        }
        else if (getParameter(items, request, "pf_update26") != null)
        {
        String tmp = "";
        if ("1".equals(getParameterDefault(items, request, "pf26_importFile", "0")))
        {
          tmp = getParameter(items, request, "pf26_file");
        }
        else
        {
          tmp = getParameter(items, request, "pf26_certificate");
        }
          params = httpParam( "", "sid", $_sid) +
                   httpParam("&", "realm", $_realm) +
                   httpParam("&", "id", getParameter(items, request, "pf26_id")) +
                 httpParam("&", "certificate", tmp) +
                 httpParam("&", "enableLogin", getParameterDefault(items, request, "pf26_enableLogin", "0"));
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
            if ((($_formTab == 0) && ($_formTab2 == 3)) || (($_formTab == 1) && ($_formTab2 == 2)))
            {
              String accountType = "P";
              prefix = "x4";
              if (($_formTab == 1) && ($_formTab2 == 2))
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
                         httpParam("&", "url", getParameter(items, request, prefix+"_fld_2_"+suffix)) +
                         httpParam("&", "uri", getParameter(items, request, prefix+"_fld_3_"+suffix));
                  $_retValue = httpRequest ("POST", "user.onlineAccounts.new", params);
                  if ($_retValue.indexOf("<failed>") == 0)
                  {
        		        $_document = createDocument($_retValue);
                    throw new Exception(xpathEvaluate($_document, "/failed/message"));
                  }
                }
      		    }
            }
            else if (($_formTab == 0) && ($_formTab2 == 5))
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
            else if (($_formTab == 2) && ($_formTab2 == 0))
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
                if ($_formTab2 == 0)
                {
                  // Import
                  if ("1".equals(getParameter(items, request, "cb_item_i_photo")))
                    params += httpParam ("&", "photo", getParameter(items, request, "i_photo"));
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
                if ("1".equals(getParameter(items, request, "cb_item_i_homeCountry")))
                  params += httpParam ("&", "homeCountry", getParameter(items, request, "i_homeCountry"));
                if ("1".equals(getParameter(items, request, "cb_item_i_homeState")))
                  params += httpParam ("&", "homeState", getParameter(items, request, "i_homeState"));
                if ("1".equals(getParameter(items, request, "cb_item_i_homeCity")))
                  params += httpParam ("&", "homeCity", getParameter(items, request, "i_homeCity"));
                if ("1".equals(getParameter(items, request, "cb_item_i_homeCode")))
                  params += httpParam ("&", "homeCode", getParameter(items, request, "i_homeCode"));
                if ("1".equals(getParameter(items, request, "cb_item_i_homeAddress1")))
                  params += httpParam ("&", "homeAddress1", getParameter(items, request, "i_homeAddress1"));
                if ("1".equals(getParameter(items, request, "cb_item_i_homeAddress2")))
                  params += httpParam ("&", "homeAddress2", getParameter(items, request, "i_homeAddress2"));
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
                  if ("1".equals(getParameter(items, request, "cb_item_i_topicInterests")))
                    params += httpParam ("&", "topicInterests", getParameter(items, request, "i_topicInterests"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_interests")))
                    params += httpParam ("&", "interests", getParameter(items, request, "i_interests"));
                  if ("1".equals(getParameter(items, request, "cb_item_i_onlineAccounts")))
                    params += httpParam ("&", "onlineAccounts", getParameter(items, request, "i_onlineAccounts"));
                }
                else if ($_formTab2 == 1)
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
                       httpParam ("&", "spbEnable"             , getParameterDefault(items, request, "pf_spbEnable", "0")) +
                       httpParam ("&", "inSearch"              , getParameterDefault(items, request, "pf_inSearch", "0")) +
                       httpParam ("&", "showActive"            , getParameterDefault(items, request, "pf_showActive", "0")) +
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
                        if (item.getFieldName().indexOf("x1_fld_1_") == 0) {
                          suffix = item.getFieldName().replace("x1_fld_1_", "");
                          tmp += item.getString() + ";" + getParameter(items, request, "x1_fld_2_"+suffix) + "\n";
                        }
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
                  params += httpParam ("&", "topicInterests", tmp);
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
                  params += httpParam ("&", "interests", tmp);
                }
                if ($_formTab2 == 2)
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
                if ($_formTab2 == 4)
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
                if ($_formTab2 == 0)
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
                if ($_formTab2 == 1)
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
                if ($_formTab2 == 3)
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
                if ($_formTab2 == 1)
                  params +=
                       httpParam ("&", "securitySecretQuestion", getParameter(items, request, "pf_securitySecretQuestion")) +
                       httpParam ("&", "securitySecretAnswer", getParameter(items, request, "pf_securitySecretAnswer"));

                if ($_formTab2 == 2)
                  params +=
                       httpParam ("&", "securityOpenID", getParameter(items, request, "pf_securityOpenID"));

              if ($_formTab2 == 3)
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
              $_formTab2 += 1;
              if (
                  (($_formTab == 1) && ($_formTab2 > 3)) ||
                  (($_formTab == 2) && ($_formTab2 > 5))
                 )
              {
                $_formTab += 1;
                $_formTab2 = 0;
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
          $_formTab2 = 0;
        }
      }

      if ($_form.equals("user") || $_form.equals("profile"))
      {
        try
        {
          params = httpParam ( "", "sid"   , $_sid) +
                   httpParam ("&", "realm" , $_realm);
          if ($_form.equals("user") && $_userName != null)
            params += httpParam ("&", "name", $_userName);
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

    $_host = (new URL(request.getScheme(), request.getServerName(), request.getServerPort(), "")).toString();
    $_hostLinks =
      "    <link rel=\"openid.server\" title=\"OpenID Server\" href=\"[HOST]/openid\" />\n" +
      "    <link rel=\"openid2.provider\" title=\"OpenID v2 Server\" href=\"[HOST]/openid\" />";
    $_hostLinks = $_hostLinks.replace ("[HOST]", $_host);

    if ($_userName != null) {
      $_userLinks =
        "    <link rel=\"meta\" type=\"application/rdf+xml\" title=\"SIOC\" href=\"[HOST]/dataspace/[USER]/sioc.rdf\" />\n" +
        "    <link rel=\"meta\" type=\"application/rdf+xml\" title=\"FOAF\" href=\"[HOST]/dataspace/person/[USER]/foaf.rdf\" />\n" +
        "    <link rel=\"meta\" type=\"text/rdf+n3\" title=\"FOAF\" href=\"[HOST]/dataspace/person/[USER]/foaf.n3\" />\n" +
        "    <link rel=\"meta\" type=\"application/json\" title=\"FOAF\" href=\"[HOST]/dataspace/person/[USER]/foaf.json\" />\n" +
        "    <link rel=\"http://xmlns.com/foaf/0.1/primaryTopic\"  title=\"About\" href=\"[HOST]/dataspace/person/[USER]#this\" />\n" +
        "    <link rel=\"schema.dc\" href=\"http://purl.org/dc/elements/1.1/\" />\n" +
        "    <meta name=\"dc.language\" content=\"en\" scheme=\"rfc1766\" />\n" +
        "    <meta name=\"dc.creator\" content=\"[USER]\" />\n" +
        "    <meta name=\"dc.description\" content=\"ODS HTML [USER]'s page\" />\n" +
        "    <meta name=\"dc.title\" content=\"ODS HTML [USER]'s page\" />\n" +
        "    <link rev=\"describedby\" title=\"About\" href=\"[HOST]/dataspace/person/[USER]#this\" />\n" +
        "    <link rel=\"schema.geo\" href=\"http://www.w3.org/2003/01/geo/wgs84_pos#\" />\n" +
        "    <meta http-equiv=\"X-XRDS-Location\" content=\"[HOST]/dataspace/[USER]/yadis.xrds\" />\n" +
        "    <meta http-equiv=\"X-YADIS-Location\" content=\"[HOST]/dataspace/[USER]/yadis.xrds\" />\n" +
        "    <link rel=\"meta\" type=\"application/xml+apml\" title=\"APML 0.6\" href=\"[HOST]/dataspace/[USER]/apml.xml\" />\n" +
        "    <link rel=\"alternate\" type=\"application/atom+xml\" title=\"OpenSocial Friends\" href=\"[HOST]/feeds/people/[USER]/friends\" />";
      $_userLinks = $_userLinks.replace ("[HOST]", $_host);
      $_userLinks = $_userLinks.replace ("[USER]", $_userName);
    }
    }
    catch (Exception e)
    {
      $_error = "Failure: " + e.getMessage();
    }
  %>
<html>
  <head>
    <meta charset="utf-8" />
    <title>ODS user's pages</title>
<% out.print($_hostLinks); %>
<% out.print($_userLinks); %>
    <link rel="stylesheet" type="text/css" href="/ods/users/css/users.css" />
    <link rel="stylesheet" type="text/css" href="/ods/default.css" />
    <link rel="stylesheet" type="text/css" href="/ods/typeahead.css" />
    <link rel="stylesheet" type="text/css" href="/ods/ods-bar.css" />
    <link rel="stylesheet" type="text/css" href="/ods/rdfm.css" />
    <script type="text/javascript" src="/ods/users/js/users.js"></script>
    <script type="text/javascript" src="/ods/common.js"></script>
    <script type="text/javascript" src="/ods/facebook.js"></script>
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
  <body>
    <div id="fb-root"></div>
    <form name="page_form" id="page_form" method="post" enctype="<% out.print(($_form.equals("profile") && ((($_formTab == 0) && ($_formTab2 == 1)) || (($_formTab == 2) && ($_formTab2 == 5))))? "multipart/form-data": "application/x-www-form-urlencoded"); %>">
      <input type="hidden" name="mode" id="mode" value="jsp" />
      <input type="hidden" name="sid" id="sid" value="<% out.print($_sid); %>" />
      <input type="hidden" name="realm" id="realm" value="<% out.print($_realm); %>" />
      <input type="hidden" name="form" id="form" value="<% out.print($_form); %>" />
      <input type="hidden" name="formTab" id="formTab" value="<% out.print($_formTab); %>" />
      <input type="hidden" name="formTab2" id="formTab2" value="<% out.print($_formTab2); %>" />
      <input type="hidden" name="formMode" id="formMode" value="<% out.print($_formMode); %>" />
      <input type="hidden" name="items" id="items" value="" />
      <input type="hidden" name="securityNo" id="securityNo" value="" />
      <div id="ob">
        <div id="ob_left">
        <%
          if (($_validate) && ($_form.equals("profile") || $_form.equals("user")))
          {
        %>
          <b>User: </b><% out.print(xpathEvaluate($_document, "/user/fullName")); %>, <b>Profile: </b><a href="#" onclick="javascript: return profileSubmit();">Edit</a> / <a href="#" onclick="javascript: return loginUrl();">View</a>
        <%
          }
        %>
        </div>
        <div id="ob_right">
        <%
          if (($_form != "login") && ($_form != "register"))
          {
            if ($_validate)
            {
        %>
          <a href="#" onclick="javascript: return logoutSubmit();">Logout</a>
        <%
            } else {
        %>
          <a href="#" onclick="javascript: return logoutSubmit();">Login</a>
        <%
            }
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
                  Please identify yourself
                </div>
                <ul id="lf_tabs" class="tabs">
                  <li id="lf_tab_0" title="Digest" style="display: none;">Digest</li>
                  <li id="lf_tab_3" title="WebID" style="display: none;">WebID</li>
                  <li id="lf_tab_1" title="OpenID" style="display: none;">OpenID</li>
                  <li id="lf_tab_2" title="Facebook" style="display: none;">Facebook</li>
                  <li id="lf_tab_4" title="Twitter" style="display: none;">Twitter</li>
                  <li id="lf_tab_5" title="LinkedIn" style="display: none;">LinkedIn</li>
                  <li id="lf_tab_6" style="display: none;"></li>
                </ul>
                <div style="min-height: 120px; border: 1px solid #aaa; margin: -13px 5px 5px 5px;">
                  <div id="lf_content"></div>
                  <div id="lf_page_0" class="tabContent" style="display: none;">
                <table class="form" cellspacing="5">
                  <tr>
                        <th width="20%">
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
                  <div id="lf_page_1" class="tabContent" style="display: none;">
                    <table class="form" cellspacing="5">
                  <tr>
                        <th width="20%">
                          <label for="lf_openId">OpenID URL</label>
                    </th>
                        <td>
                          <input type="text" name="lf_openId" value="" id="lf_openId" style="width: 300px;" />
                        </td>
                  </tr>
                    </table>
                  </div>
                  <div id="lf_page_2" class="tabContent" style="display: none;">
                    <table class="form" cellspacing="5">
                  <tr>
                        <th width="20%">
                    </th>
                        <td>
                          <span id="lf_facebookData" style="min-height: 20px;"></span>
                          <br />
                          <fb:login-button autologoutlink="true" xmlns:fb="http://www.facebook.com/2008/fbml"></fb:login-button>
                    </td>
                  </tr>
                </table>
                  </div>
                  <div id="lf_page_3" class="tabContent" style="display: none;">
                    <table id="lf_table_3" class="form" cellspacing="5">
                      <tr id="lf_table_3_throbber">
                        <th width="20%">
                        </th>
                        <td>
                          <img alt="Import WebID Data" src="/ods/images/oat/Ajax_throbber.gif" />
                        </td>
                      </tr>
                    </table>
                  </div>
                  <div id="lf_page_4" class="tabContent" style="display: none;">
                    <table id="lf_table_4" class="form" cellspacing="5">
                      <tr>
                        <th width="20%">
                        </th>
                        <td>
                          <span id="lf_twitter" style="min-height: 20px;"></span>
                          <br />
                          <img id="lf_twitterButton" src="/ods/images/sign-in-with-twitter-d.png" border="0"/>
                        </td>
                      </tr>
                    </table>
                  </div>
                  <div id="lf_page_5" class="tabContent" style="display: none;">
                    <table id="lf_table_5" class="form" cellspacing="5">
                      <tr>
                        <th width="20%">
                        </th>
                        <td>
                          <span id="lf_linkedin" style="min-height: 20px;"></span>
                          <br />
                          <img id="lf_linkedinButton" src="/ods/images/linkedin-large.png" border="0"/>
                        </td>
                      </tr>
                    </table>
                  </div>
                  <div id="lf_page_6" class="tabContent" style="display: none;">
                    <table id="lf_table_6" class="form" cellspacing="5" width="100%">
                      <tr>
                        <td style="text-align: center;">
                          <b>The login is not allowed!</b>
                        </td>
                      </tr>
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
                  User Registration
                </div>
                <ul id="rf_tabs" class="tabs">
                  <li id="rf_tab_0" title="Digest" style="display: none;">Digest</li>
                  <li id="rf_tab_3" title="WebID" style="display: none;">WebID</li>
                  <li id="rf_tab_1" title="OpenID" style="display: none;">OpenID</li>
                  <li id="rf_tab_2" title="Facebook" style="display: none;">Facebook</li>
                  <li id="rf_tab_4" title="Twitter" style="display: none;">Twitter</li>
                  <li id="rf_tab_5" title="LinkedIn" style="display: none;">LinkedIn</li>
                  <li id="rf_tab_6" style="display: none;"></li>
                </ul>
                <div style="min-height: 135px; border: 1px solid #aaa; margin: -13px 5px 5px 5px;">
                  <div id="rf_content"></div>
                  <div id="rf_page_0" class="tabContent" style="display: none;">
                    <table id="rf_table_0" class="form" cellspacing="5">
                      <tr>
                        <th width="20%">
                          <label for="rf_uid_0">Login Name<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
                        </th>
                        <td>
                          <input type="text" name="rf_uid_0" value="" id="rf_uid_0" style="width: 150px;" />
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <label for="rf_email_0">E-mail<div style="font-weight: normal; display:inline; color:red;"> *</div></label>
                        </th>
                        <td>
                          <input type="text" name="rf_email_0" value="" id="rf_email_0" style="width: 300px;" />
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
                  <div id="rf_page_1" class="tabContent" style="display: none;">
                    <table id="rf_table_1" class="form" cellspacing="5">
                      <tr>
                        <th width="20%">
                          <label for="rf_openId">OpenID</label>
                        </th>
                        <td>
                          <input type="text" name="rf_openId" value="" id="rf_openId" size="40"/>
                        </td>
                      </tr>
                    </table>
                  </div>
                  <div id="rf_page_2" class="tabContent" style="display: none;">
                    <table id="rf_table_2" class="form" cellspacing="5">
                      <tr>
                        <th width="20%">
                        </th>
                        <td>
                          <span id="rf_facebookData" style="min-height: 20px;"></span>
                          <br />
                          <fb:login-button autologoutlink="true" xmlns:fb="http://www.facebook.com/2008/fbml"></fb:login-button>
                        </td>
                      </tr>
                    </table>
                  </div>
                  <div id="rf_page_3" class="tabContent" style="display: none;">
                    <table id="rf_table_3" class="form" cellspacing="5">
                      <tr id="rf_table_3_throbber">
                        <th width="20%">
                        </th>
                        <td>
                          <img alt="Import WebID Data" src="/ods/images/oat/Ajax_throbber.gif" />
                        </td>
                      </tr>
                    </table>
                  </div>
                  <div id="rf_page_4" class="tabContent" style="display: none;">
                    <table id="rf_table_4" class="form" cellspacing="5">
                      <tr>
                        <th width="20%">
                        </th>
                        <td>
                          <span id="rf_twitter" style="min-height: 20px;"></span>
                          <br />
                          <img id="rf_twitterButton" src="/ods/images/sign-in-with-twitter-d.png" border="0"/></a>
                        </td>
                      </tr>
                    </table>
                  </div>
                  <div id="rf_page_5" class="tabContent" style="display: none;">
                    <table id="rf_table_5" class="form" cellspacing="5">
                      <tr>
                        <th width="20%">
                        </th>
                        <td>
                          <span id="rf_linkedin" style="min-height: 20px;"></span>
                          <br />
                          <img id="rf_linkedinButton" src="/ods/images/linkedin-large.png" border="0"/>
                        </td>
                      </tr>
                    </table>
                  </div>
                  <div id="rf_page_6" class="tabContent" style="display: none;">
                    <table id="rf_table_6" class="form" cellspacing="5" width="100%">
                      <tr>
                        <td style="text-align: center;">
                          <b>The registration is not allowed!</b>
                        </td>
                      </tr>
                    </table>
                  </div>
                </div>
                <div>
                  <table class="form" cellspacing="5">
                    <tr>
                      <th width="20%">
                      </th>
                      <td>
                        <input type="checkbox" name="rf_is_agreed" value="1" id="rf_is_agreed"/><label for="rf_is_agreed">I agree to the <a href="/ods/terms.html" target="_blank">Terms of Service</a>.</label>
                      </td>
                    </tr>
                  </table>
                </div>
                <div class="footer" id="rf_login_5">
                  <input type="button" id="rf_check" name="rf_check" value="Check Availabilty" onclick="javascript: return rfCheckAvalability();" />
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
                  <script type="text/javascript">
                  <%
                    out.print(String.format("OAT.MSG.attach(OAT, 'PAGE_LOADED', function (){selectProfile('%s');});", $_userName));
                  %>
                  </script>
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
                  <%
                  if ($_formTab == 0)
                  {
                  %>
                  <div id="pf_page_0" class="tabContent" style="display:none;">
                    <ul id="pf_tabs_0" class="tabs">
                      <div id="pf_tabs_0_row_0" style="margin-top: 4px;">
                      <li id="pf_tab_0_0">Profile Import</li>
                      <li id="pf_tab_0_1">Main</li>
                      <li id="pf_tab_0_2">Address</li>
                      <li id="pf_tab_0_3">Online Accounts</li>
                      <li id="pf_tab_0_4">Messaging Services</li>
                      <li id="pf_tab_0_5">Biographical Events</li>
                      </div>
                      <div id="pf_tabs_0_row_1" style="margin-top: 4px;">
                      <li id="pf_tab_0_6">Owns</li>
                      <li id="pf_tab_0_7">Favorite Things</li>
                      <li id="pf_tab_0_8">Creator Of</li>
                      <li id="pf_tab_0_9">My Offers</li>
                      <li id="pf_tab_0_10">Offers I Seek</li>
                      <li id="pf_tab_0_11">Likes & DisLikes</li>
                      <li id="pf_tab_0_12">Social Network</li>
                      </div>
                    </ul>
                    <div style="min-height: 180px; min-width: 650px; border-top: 1px solid #aaa; margin: -13px 5px 5px 5px;">
                      <%
                      if ($_formTab2 == 0)
                      {
                      %>
                      <div id="pf_page_0_0" class="tabContent" style="display:none;">
                    <table class="form" cellspacing="5">
                      <tr>
                        <th>
                              <label for="pf_foaf">Profile Document URL</label>
                            </th>
                            <td>
                              <input type="text" name="pf_foaf" value="" id="pf_foaf" style="width: 400px;" />
                              <input type="button" value="Import" onclick="javascript: pfGetFOAFData($v('pf_foaf')); return false;" class="button" />
                              <img id="pf_import_image" alt="Import FOAF Data" src="/ods/images/oat/Ajax_throbber.gif" style="display: none;" />
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
                      <%
                      }
                      if ($_formTab2 == 1)
                      {
                      %>
                      <div id="pf_page_0_1" class="tabContent" style="display:none;">
                        <table class="form" cellspacing="5">
                          <tr>
                            <th>Account deactivation</th>
                            <td>
                              <input type="button" value="Deactivate" onclick="return userDisable('pf_loginName');" />
                            </td>
                          </tr>
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
                                    String[] V = {"Mr", "Mrs", "Dr", "Ms", "Sir"};
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
                                          <th width="10%">
                                            Access
                                          </th>
                                          <th width="65px">
                                            Action
                                          </th>
                                        </tr>
                                      </thead>
                                      <tr id="x1_tr_no" style="display: none;"><td colspan="2"><b>No Personal URIs</b></td></tr>
                                      <script type="text/javascript">
                                        OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowRows("x1", '<% out.print(xpathEvaluate($_document, "/user/webIDs").replace("\n", "\\n")); %>', ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _webid_ _canEmpty_'}, fld_2: {mode: 4, value: val2}});});});
                                      </script>
                                    </table>
                                  </td>
                                  <td valign="top" nowrap="nowrap">
                                    <span class="button pointer" onclick="TBL.createRow('x1', null, {fld_1: {className: '_validate_ _webid_ _canEmpty_'}, fld_2: {mode: 4}});"><img class="button" src="/ods/images/icons/add_16.png" border="0" alt="Add Row" title="Add Row" /> Add</span>
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
                                        OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowRows("x2", '<% out.print(xpathEvaluate($_document, "/user/topicInterests").replace("\n", "\\n")); %>', ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _url_ _canEmpty_'}, fld_2: {value: val2}});});});
                                      </script>
                                    </table>
                                  </td>
                                  <td valign="top" nowrap="nowrap">
                                    <span class="button pointer" onclick="TBL.createRow('x2', null, {fld_1: {className: '_validate_ _url_ _canEmpty_'}, fld_2: {}});"><img class="button" src="/ods/images/icons/add_16.png" border="0" alt="Add Row" title="Add Row" /> Add</span>
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
                                        OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowRows("x3", '<% out.print(xpathEvaluate($_document, "/user/interests").replace("\n", "\\n")); %>', ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _url_ _canEmpty_'}, fld_2: {value: val2}});});});
                                      </script>
                                    </table>
                                  </td>
                                  <td valign="top" nowrap="nowrap">
                                    <span class="button pointer" onclick="TBL.createRow('x3', null, {fld_1: {className: '_validate_ _url_ _canEmpty_'}, fld_2: {}});"><img class="button" src="/ods/images/icons/add_16.png" border="0" alt="Add Row" title="Add Row" /> Add</span>
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
                            <td>&nbsp;</td>
                            <td>
                              <label>
                                <%
                                  out.print("<input type=\"checkbox\" id=\"pf_spbEnable\" name=\"pf_spbEnable\" value=\"1\" " + ("1".equals(xpathEvaluate($_document, "/user/spbEnable")) ? ("checked=\"checked\"") : ("")) + ">");
                                %>
                                <b>Enable Semantic Pingback for ACLs</b>
                              </label>
                            </td>
                          </tr>
                          <tr>
                            <td>&nbsp;</td>
                            <td>
                             <label>
                                <%
                                  out.print("<input type=\"checkbox\" id=\"pf_inSearch\" name=\"pf_inSearch\" value=\"1\" " + ("1".equals(xpathEvaluate($_document, "/user/inSearch")) ? ("checked=\"checked\"") : ("")) + ">");
                                %>
                               <b>Include my profile in search results</b>
                             </label>
                            </td>
                          </tr>
                          <tr>
                            <td>&nbsp;</td>
                            <td>
                             <label>
                                <%
                                  out.print("<input type=\"checkbox\" id=\"pf_showActive\" name=\"pf_showActive\" value=\"1\" " + ("1".equals(xpathEvaluate($_document, "/user/showActive")) ? ("checked=\"checked\"") : ("")) + ">");
                                %>
                               <b>Include in User active information</b>
                             </label>
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
                                <option value="2">acl</option>
                                <option value="3">private</option>
                              </select>
                            </td>
                          </tr>
                    </table>
                  </div>
                      <%
                      }
                      if ($_formTab2 == 2)
                      {
                      %>
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
                                Use as default map location
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
                                <option value="2">acl</option>
                                <option value="3">private</option>
                              </select>
                        </td>
                      </tr>
                    </table>
                  </div>
                      <%
                      }
                      if ($_formTab2 == 3)
                      {
                      %>
                      <div id="pf_page_0_3" class="tabContent" style="display:none;">
                        <input type="hidden" name="c_nick" value="<% out.print(xpathEvaluate($_document, "/user/nickName")); %>" id="c_nick" />
                    <table class="form" cellspacing="5">
                      <tr>
                            <td width="800px">
                              <table id="x4_tbl" class="listing">
                                <thead>
                                  <tr class="listing_header_row">
                                    <th>
                                      Select from Service List ot Type New One
                        </th>
                                    <th>
                                      Member Home Page URI
                                    </th>
                                    <th>
                                      Account URI
                                    </th>
                                    <th width="65px">
                                      Action
                                    </th>
                                  </tr>
                                </thead>
                                <tr id="x4_tr_no" style="display: none;"><td colspan="3"><b>No Services</b></td></tr>
                                <script type="text/javascript">
                                  OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowOnlineAccounts("x4", "P", function(prefix, val0, val1, val2, val3){TBL.createRow(prefix, null, {id: val0, fld_1: {mode: 10, value: val1}, fld_2: {value: val2, className: '_validate_ _uri_ _canEmpty_'}, fld_3: {value: val3}});});});
                                </script>
                              </table>
                            </td>
                            <td valign="top" nowrap="1">
                              <span class="button pointer" onclick="TBL.createRow('x4', null, {fld_1: {mode: 10}, fld_2: {className: '_validate_ _uri_ _canEmpty_'}, fld_3: {}});"><img class="button" src="/ods/images/icons/add_16.png" border="0" alt="Add Row" title="Add Row" /> Add</span>
                        </td>
                      </tr>
                        </table>
                      </div>
                      <%
                      }
                      if ($_formTab2 == 4)
                      {
                      %>
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
                                <option value="2">acl</option>
                                <option value="3">private</option>
                              </select>
                            </td>
                          </tr>
                          <script type="text/javascript">
                            OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowRows("x6", '<% out.print(xpathEvaluate($_document, "/user/messaging").replace("\n", "\\n")); %>', ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1}, fld_2: {value: val2, cssText: 'width: 220px;'}});});});
                          </script>
                        </table>
                      </div>
                      <%
                      }
                      if ($_formTab2 == 5)
                      {
                      %>
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
                          }
                      if ($_formTab2 == 6)
                          {
                          %>
                      <div id="pf_page_0_6" class="tabContent" style="display:none;">
                            <h3>Owns</h3>
                            <%
                              if ($_formMode == "")
                              {
                            %>
                            <div id="pf051_list">
                              <div style="padding: 0 0 0.5em 0;">
                                <span onclick="javascript: $('formMode').value = 'new'; $('page_form').submit();" class="button pointer"><img class="button" border="0" title="Add Offer" alt="Add Offer" src="/ods/images/icons/add_16.png"> Add</span>
                              </div>
                          	  <table id="pf051_tbl" class="listing">
                          	    <thead>
                          	      <tr class="listing_header_row">
                            		    <th width="50%">Name</th>
                            		    <th width="50%">Description</th>
                            		    <th width="1%" nowrap="nowrap">Action</th>
                          	      </tr>
                                </thead>
                          	    <tbody id="pf051_tbody">
                                  <script type="text/javascript">
                                    OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowOwns();});
                                  </script>
                          	    </tbody>
                              </table>
                            </div>
                            <%
                              }
                              else
                      {
                                out.print("<input type=\"hidden\" id=\"pf051_id\" name=\"pf051_id\" value=\"" + ((getParameter(items, request, "pf051_id") != null) ? getParameter(items, request, "pf051_id"): "0") + "\" />");
                            %>
                            <div id="pf051_form">
                              <table class="form" cellspacing="5">
                      				  <tr>
                                  <th width="25%">
                      		          Access
                      		        </th>
                      		        <td>
                                    <select name="pf051_flag" id="pf051_flag">
                                      <option value="1">public</option>
                                      <option value="2">acl</option>
                                      <option value="3">private</option>
                                    </select>
                                  </td>
                                </tr>
                                <tr>
                                  <th>
                                    Name (*)
                                  </th>
                                  <td>
                                    <input type="text" name="pf051_name" id="pf051_name" value="" class="_validate_" style="width: 400px;">
                                  </td>
                                </tr>
                                <tr>
                                  <th>
                                    Comment
                                  </th>
                                  <td>
                                    <textarea name="pf051_comment" id="pf051_comment" class="_validate_ _canEmpty_" style="width: 400px;"></textarea>
                                  </td>
                                </tr>
                      				  <tr>
                      				    <th valign="top">
                      		          Products
                      		        </th>
                      		        <td width="800px">
                                    <table id="ow_tbl" class="listing">
                                      <tbody id="ow_tbody">
                                        <tr id="ow_throbber">
                                          <td>
                                            <img src="/ods/images/oat/Ajax_throbber.gif" />
                                          </td>
                                        </tr>
                                      </tbody>
                                    </table>
                                    <input type="hidden" id="ow_no" name="ow_no" value="1" />
                                  </td>
                                </tr>
                              </table>
                              <script type="text/javascript">
                                OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowOwn();});
                              </script>
                              <div class="footer">
                                <input type="submit" name="pf_cancel2" value="Cancel" onclick="needToConfirm = false;"/>
                                <input type="submit" name="pf_update051" value="Save" onclick="myBeforeSubmit(); return validateInputs(this, 'pf051');"/>
                              </div>
                            </div>
                            <%
                              }
                            %>
                          </div>
                          <%
                          }
                      if ($_formTab2 == 7)
                        {
                      %>
                      <div id="pf_page_0_7" class="tabContent" style="display:none;">
                        <h3>Favorites</h3>
                        <%
                          if ($_formMode == "")
                          {
                        %>
                            <div id="pf052_list">
                          <div style="padding: 0 0 0.5em 0;">
                            <span onclick="javascript: $('formMode').value = 'new'; $('page_form').submit();" class="button pointer"><img class="button" border="0" title="Add 'Favorite'" alt="Add 'Favorite'" src="/ods/images/icons/add_16.png"> Add</span>
                          </div>
                          	  <table id="pf052_tbl" class="listing">
                                <thead>
                                  <tr class="listing_header_row">
                            		    <th width="50%">Label</th>
                            		    <th width="50%">URI</th>
                        		    <th width="1%" nowrap="nowrap">Action</th>
                                  </tr>
                                </thead>
                          	    <tbody id="pf052_tbody">
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
                                out.print("<input type=\"hidden\" id=\"pf052_id\" name=\"pf052_id\" value=\"" + ((getParameter(items, request, "pf052_id") != null) ? getParameter(items, request, "pf052_id"): "0") + "\" />");
                        %>
                            <div id="pf052_form">
                          <table class="form" cellspacing="5">
                            <tr>
                              <th width="25%">
                      		          Access
                      		        </th>
                      		        <td>
                                    <select name="pf052_flag" id="pf052_flag">
                                      <option value="1">public</option>
                                      <option value="2">acl</option>
                                      <option value="3">private</option>
                                    </select>
                                  </td>
                                </tr>
                                <tr>
                                  <th>
                                Label (*)
                              </th>
                              <td>
                                    <input type="text" name="pf052_label" id="pf052_label" value="" class="_validate_" style="width: 400px;">
                            </td>
                            </tr>
                            <tr>
                              <th>
                                External URI
                              </th>
                              <td>
                                    <input type="text" name="pf052_uri" id="pf052_uri" value="" class="_validate_ _url_ _canEmpty_" style="width: 400px;">
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
                                <input type="submit" name="pf_update052" value="Save" onclick="myBeforeSubmit(); return validateInputs(this, 'pf052');"/>
                          </div>
                      </div>
                      <%
                          }
                        %>
                      </div>
                      <%
                        }
                      if ($_formTab2 == 8)
                        {
                      %>
                      <div id="pf_page_0_8" class="tabContent" style="display:none;">
                        <h3>Creator Of</h3>
                        <%
                          if ($_formMode == "")
                          {
                        %>
                            <div id="pf053_list">
                          <div style="padding: 0 0 0.5em 0;">
                            <span onclick="javascript: $('formMode').value = 'new'; $('page_form').submit();" class="button pointer"><img class="button" border="0" title="Add Creator Of" alt="Add Creator Of" src="/ods/images/icons/add_16.png"> Add</span>
                          </div>
                          	  <table id="pf053_tbl" class="listing">
                      	    <thead>
                      	      <tr class="listing_header_row">
                        		    <th>Property</th>
                        		    <th>Description</th>
                        		    <th width="1%" nowrap="nowrap">Action</th>
                      	      </tr>
                            </thead>
                          	    <tbody id="pf053_tbody">
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
                                out.print("<input type=\"hidden\" id=\"pf053_id\" name=\"pf053_id\" value=\"" + ((getParameter(items, request, "pf053_id") != null) ? getParameter(items, request, "pf053_id"): "0") + "\" />");
                        %>
                            <div id="pf053_form">
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
                                        fld.input.name = 'pf053_property';
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
                                    <input type="text" name="pf053_url" id="pf053_url" value="" class="_validate_ _url_ _canEmpty_" style="width: 400px;">
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Description (*)
                              </th>
                              <td>
                                    <textarea name="pf053_description" id="pf053_description" style="width: 400px;"></textarea>
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
                                <input type="submit" name="pf_update053" value="Save" onclick="needToConfirm = false; return validateInputs(this, 'pf053');"/>
                          </div>
                        </div>
                        <%
                          }
                        %>
                      </div>
                      <%
                        }
                      if ($_formTab2 == 9)
                        {
                      %>
                      <div id="pf_page_0_9" class="tabContent" style="display:none;">
                        <h3>My Offers</h3>
                        <%
                          if ($_formMode == "")
                          {
                        %>
                            <div id="pf054_list">
                          <div style="padding: 0 0 0.5em 0;">
                            <span onclick="javascript: $('formMode').value = 'new'; $('page_form').submit();" class="button pointer"><img class="button" border="0" title="Add Offer" alt="Add Offer" src="/ods/images/icons/add_16.png"> Add</span>
                          </div>
                          	  <table id="pf054_tbl" class="listing">
                      	    <thead>
                      	      <tr class="listing_header_row">
                            		    <th width="50%">Name</th>
                            		    <th width="50%">Description</th>
                        		    <th width="1%" nowrap="nowrap">Action</th>
                      	      </tr>
                            </thead>
                          	    <tbody id="pf054_tbody">
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
                                out.print("<input type=\"hidden\" id=\"pf054_id\" name=\"pf054_id\" value=\"" + ((getParameter(items, request, "pf054_id") != null) ? getParameter(items, request, "pf054_id"): "0") + "\" />");
                        %>
                            <div id="pf054_form">
                          <table class="form" cellspacing="5">
                            <tr>
                              <th width="25%">
                      		          Access
                      		        </th>
                      		        <td>
                                    <select name="pf054_flag" id="pf054_flag">
                                      <option value="1">public</option>
                                      <option value="2">acl</option>
                                      <option value="3">private</option>
                                    </select>
                                  </td>
                                </tr>
                                <tr>
                                  <th>
                                    Name (*)
                              </th>
                              <td>
                                    <input type="text" name="pf054_name" id="pf054_name" value="" class="_validate_" style="width: 400px;">
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Comment
                              </th>
                              <td>
                                    <textarea name="pf054_comment" id="pf054_comment" class="_validate_ _canEmpty_" style="width: 400px;"></textarea>
                              </td>
                            </tr>
                  				  <tr>
                  				    <th valign="top">
                  		          Products
                  		        </th>
                  		        <td width="800px">
                                    <table class="ctl_grp">
                                      <tr>
                                        <td width="800px">
                                <table id="ol_tbl" class="listing">
                                            <thead>
                                              <tr class="listing_header_row">
                                                <th>
                                                  <div style="width: 16px;"><![CDATA[&nbsp;]]></div>
                                                </th>
                                                <th width="100%">
                                                  Ontology
                                                </th>
                                                <th width="80px">
                                                  Action
                                                </th>
                                    </tr>
                                            </thead>
                                            <tbody id="ol_tbody" class="colorize">
                                              <tr id="ol_tr_no"><td colspan="3"><b>No Attached Ontologies</b></td></tr>
                                  </tbody>
                                </table>
                                        </td>
                                        <td valign="top" nowrap="nowrap">
                                          <span class="button pointer" onclick="TBL.createRow('ol', null, {fld_1: {mode: 40, cssText: 'display: none;'}, fld_2: {mode: 41, labelValue: 'Ontology: ', cssText: 'width: 95%;'}, btn_1: {mode: 40}, btn_2: {mode: 41, title: 'Attach'}});"><img class="button" src="/ods/images/icons/add_16.png" border="0" alt="Add Ontology" title="Add Ontology" /> Add</span>
                                        </td>
                                      </tr>
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
                                <input type="submit" name="pf_update054" value="Save" onclick="myBeforeSubmit(); return validateInputs(this, 'pf054');"/>
                          </div>
                        </div>
                        <%
                          }
                        %>
                      </div>
                      <%
                        }
                      if ($_formTab2 == 10)
                        {
                      %>
                      <div id="pf_page_0_10" class="tabContent" style="display:none;">
                        <h3>Offers I Seek</h3>
                        <%
                          if ($_formMode == "")
                          {
                        %>
                            <div id="pf055_list">
                          <div style="padding: 0 0 0.5em 0;">
                            <span onclick="javascript: $('formMode').value = 'new'; $('page_form').submit();" class="button pointer"><img class="button" border="0" title="Add Seek" alt="Add Seek" src="/ods/images/icons/add_16.png"> Add</span>
                          </div>
                          	  <table id="pf055_tbl" class="listing">
                      	    <thead>
                      	      <tr class="listing_header_row">
                            		    <th width="50%">Name</th>
                            		    <th width="50%">Description</th>
                        		    <th width="1%" nowrap="nowrap">Action</th>
                      	      </tr>
                            </thead>
                          	    <tbody id="pf055_tbody">
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
                                out.print("<input type=\"hidden\" id=\"pf055_id\" name=\"pf055_id\" value=\"" + ((getParameter(items, request, "pf055_id") != null) ? getParameter(items, request, "pf055_id"): "0") + "\" />");
                        %>
                            <div id="pf055_form">
                          <table class="form" cellspacing="5">
                            <tr>
                              <th width="25%">
                      		          Access
                      		        </th>
                      		        <td>
                                    <select name="pf055_flag" id="pf055_flag">
                                      <option value="1">public</option>
                                      <option value="2">acl</option>
                                      <option value="3">private</option>
                                    </select>
                                  </td>
                                </tr>
                                <tr>
                                  <th>
                                    Name (*)
                              </th>
                              <td>
                                    <input type="text" name="pf055_name" id="pf055_name" value="" class="_validate_" style="width: 400px;">
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Comment
                              </th>
                              <td>
                                    <textarea name="pf055_comment" id="pf055_comment" class="_validate_ _canEmpty_" style="width: 400px;"></textarea>
                              </td>
                            </tr>
                  				  <tr>
                  				    <th valign="top">
                  		          Products
                  		        </th>
                  		        <td width="800px">
                                    <table class="ctl_grp">
                                      <tr>
                                        <td width="800px">
                                <table id="wl_tbl" class="listing">
                                            <thead>
                                              <tr class="listing_header_row">
                                                <th>
                                                  <div style="width: 16px;"><![CDATA[&nbsp;]]></div>
                                                </th>
                                                <th width="100%">
                                                  Ontology
                                                </th>
                                                <th width="80px">
                                                  Action
                                                </th>
                                    </tr>
                                            </thead>
                                            <tbody id="wl_tbody" class="colorize">
                                              <tr id="wl_tr_no"><td colspan="3"><b>No Attached Ontologies</b></td></tr>
                                  </tbody>
                                </table>
                                        </td>
                                        <td valign="top" nowrap="nowrap">
                                          <span class="button pointer" onclick="TBL.createRow('wl', null, {fld_1: {mode: 40, cssText: 'display: none;'}, fld_2: {mode: 41, labelValue: 'Ontology: ', cssText: 'width: 95%;'}, btn_1: {mode: 40}, btn_2: {mode: 41, title: 'Attach'}});"><img class="button" src="/ods/images/icons/add_16.png" border="0" alt="Add Ontology" title="Add Ontology" /> Add</span>
                                        </td>
                                      </tr>
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
                                <input type="submit" name="pf_update055" value="Save" onclick="myBeforeSubmit(); return validateInputs(this, 'pf055');"/>
                          </div>
                        </div>
                        <%
                          }
                        %>
                      </div>
                      <%
                        }
                      if ($_formTab2 == 11)
                        {
                      %>
                      <div id="pf_page_0_11" class="tabContent" style="display:none;">
                        <h3>Likes &amp; DisLikes</h3>
                        <%
                          if ($_formMode == "")
                          {
                        %>
                            <div id="pf056_list">
                          <div style="padding: 0 0 0.5em 0;">
                            <span onclick="javascript: $('formMode').value = 'new'; $('page_form').submit();" class="button pointer"><img class="button" border="0" title="Add Like" alt="Add Like" src="/ods/images/icons/add_16.png"> Add</span>
                          </div>
                          	  <table id="pf056_tbl" class="listing">
                      	    <thead>
                      	      <tr class="listing_header_row">
                            		    <th width="10%">Type</th>
                            		    <th width="45%">URI</th>
                            		    <th width="45%">Name</th>
                        		    <th width="1%" nowrap="nowrap">Action</th>
                      	      </tr>
                            </thead>
                          	    <tbody id="pf056_tbody">
                              <script type="text/javascript">
                                OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowLikes();});
                              </script>
                      	    </tbody>
                          </table>
                        </div>
                        <%
                          }
                          else
                          {
                                out.print("<input type=\"hidden\" id=\"pf056_id\" name=\"pf056_id\" value=\"" + ((getParameter(items, request, "pf056_id") != null) ? getParameter(items, request, "pf056_id"): "0") + "\" />");
                        %>
                            <div id="pf056_form">
                          <table class="form" cellspacing="5">
                            <tr>
                              <th width="25%">
                      		          Access
                      		        </th>
                      		        <td>
                                    <select name="pf056_flag" id="pf056_flag">
                                      <option value="1">public</option>
                                      <option value="2">acl</option>
                                      <option value="3">private</option>
                                    </select>
                                  </td>
                                </tr>
                                <tr>
                                  <th>
                                Type
                              </th>
                              <td>
                                    <select name="pf056_type" id="pf056_type">
                                  <option value="L">Like</option>
                                  <option value="DL">DisLike</option>
                                </select>
                              </td>
                            </tr>
                            <tr>
                              <th>
                                    URI (*)
                              </th>
                              <td>
                                    <input type="text" name="pf056_uri" id="pf056_uri" value="" class="_validate_ _uri_" style="width: 400px;">
                              </td>
                            </tr>
                            <tr>
                              <th>
                                    Name (*)
                              </th>
                              <td>
                                    <input type="text" name="pf056_name" id="pf056_name" value="" class="_validate_" style="width: 400px;">
                              </td>
                            </tr>
                            <tr>
                              <th>
                                Comment
                              </th>
                              <td>
                                    <textarea name="pf056_comment" id="pf056_comment" class="_validate_ _canEmpty_" style="width: 400px;"></textarea>
                              </td>
                            </tr>
                  				  <tr>
                  				    <th valign="top">
                  		          Properties
                  		        </th>
                  		        <td width="800px">
                                    <table class="ctl_grp">
                                      <tr>
                                        <td width="800px">
                                <table id="ld_tbl" class="listing">
                                            <thead>
                                              <tr class="listing_header_row">
                                                <th>
                                                  <div style="width: 16px;"><![CDATA[&nbsp;]]></div>
                                                </th>
                                                <th width="100%">
                                                  Ontology
                                                </th>
                                                <th width="80px">
                                                  Action
                                                </th>
                                    </tr>
                                            </thead>
                                            <tbody id="ld_tbody" class="colorize">
                                              <tr id="ld_tr_no"><td colspan="3"><b>No Attached Ontologies</b></td></tr>
                                  </tbody>
                                </table>
                                        </td>
                                        <td valign="top" nowrap="nowrap">
                                          <span class="button pointer" onclick="TBL.createRow('ld', null, {fld_1: {mode: 40, cssText: 'display: none;'}, fld_2: {mode: 41, labelValue: 'Ontology: ', cssText: 'width: 95%;'}, btn_1: {mode: 40}, btn_2: {mode: 41, title: 'Attach'}});"><img class="button" src="/ods/images/icons/add_16.png" border="0" alt="Add Ontology" title="Add Ontology" /> Add</span>
                                        </td>
                                      </tr>
                                    </table>
                                <input type="hidden" id="ld_no" name="ld_no" value="1" />
                              </td>
                            </tr>
                          </table>
                          <script type="text/javascript">
                            OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowLike();});
                          </script>
                          <div class="footer">
                            <input type="submit" name="pf_cancel2" value="Cancel" onclick="needToConfirm = false;"/>
                                <input type="submit" name="pf_update056" value="Save" onclick="myBeforeSubmit(); return validateInputs(this, 'pf056');"/>
                              </div>
                            </div>
                            <%
                              }
                            %>
                          </div>
                          <%
                          }
                      if ($_formTab2 == 12)
                          {
                          %>
                      <div id="pf_page_0_12" class="tabContent" style="display:none;">
                            <h3>Knows</h3>
                            <%
                              if ($_formMode.equals(""))
                              {
                            %>
                            <div id="pf057_list">
                              <div style="padding: 0 0 0.5em 0;">
                                <span onclick="javascript: $('formMode').value = 'new'; $('page_form').submit();" class="button pointer"><img class="button" border="0" title="Add Knows" alt="Add Knows" src="/ods/images/icons/add_16.png"> Add</span>
                                <span onclick="javascript: $('formMode').value = 'import'; $('page_form').submit();" class="button pointer"><img class="button" border="0" title="Import Knows" alt="Import Knows" src="/ods/images/icons/add_16.png"> Import</span>
                              </div>
                          	  <table id="pf057_tbl" class="listing">
                          	    <thead>
                          	      <tr class="listing_header_row">
                            		    <th width="50%">Label</th>
                            		    <th width="50%">URI</th>
                            		    <th width="1%" nowrap="nowrap">Action</th>
                          	      </tr>
                                </thead>
                          	    <tbody id="pf057_tbody">
                                  <script type="text/javascript">
                                    OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowKnows();});
                                  </script>
                          	    </tbody>
                              </table>
                        </div>
                        <%
                          }
                              else if ($_formMode.equals("import"))
                              {
                        %>
                            <div id="pf057_import">
                              <table>
                      				  <tr>
                      				    <th width="100px">
                      		          Source
                      		        </th>
                                  <td>
                                    <input type="text" class="_validate_ _uri_" size="100" value="" id="k_import" name="k_import">
                                    <input type="button" class="button" onclick="javascript: knowsData(); return false;" value="Retrieve">
                                    <img style="display: none;" src="/ods/images/oat/Ajax_throbber.gif" alt="Import knows URIs" id="k_import_image">
                                  </td>
                                </tr>
                                <tr>
                                  <th>
                                  </th><td>
                                    <table class="listing" id="k_tbl">
                                      <thead>
                                        <tr class="listing_header_row">
                                          <th>
                                            Access
                                          </th>
                                          <th width="50%">
                                            URI
                                          </th>
                                          <th width="50%">
                                            Label
                                          </th>
                                          <th width="65px">
                                            Action
                                          </th>
                                        </tr>
                                      </thead>
                                      <tbody>
                                        <tr id="k_tr_no">
                                           <td colspan="3">
                                             <b>No retrieved items</b>
                                           </td>
                                        </tr>
                                      </tbody>
                                    </table>
                                  </td>
                                </tr>
                              </table>
                              <div class="footer">
                                <input type="submit" name="pf_cancel2" value="Cancel" onclick="needToConfirm = false;"/>
                                <input type="submit" name="pf_update057" value="Import" onclick="myBeforeSubmit(); return true;"/>
                              </div>
                      </div>
                      <%
                        }
                        else
                        {
                                out.print("<input type=\"hidden\" id=\"pf057_id\" name=\"pf057_id\" value=\"" + ((getParameter(items, request, "pf057_id") != null) ? getParameter(items, request, "pf057_id"): "0") + "\" />");
                            %>
                            <div id="pf057_form">
                              <table class="form" cellspacing="5">
                      				  <tr>
                                  <th width="25%">
                      		          Access
                      		        </th>
                      		        <td>
                                    <select name="pf057_flag" id="pf057_flag">
                                      <option value="1">public</option>
                                      <option value="2">acl</option>
                                      <option value="3">private</option>
                                    </select>
                                  </td>
                                </tr>
                                <tr>
                                  <th>
                                    URI (*)
                                  </th>
                                  <td>
                                    <input type="text" name="pf057_uri" id="pf057_uri" value="" class="_validate_ _uri_" style="width: 400px;">
                                  </td>
                                </tr>
                                <tr>
                                  <th>
                                    Label (*)
                                  </th>
                                  <td>
                                    <input type="text" name="pf057_label" id="pf057_label" value="" class="_validate_" style="width: 400px;">
                                  </td>
                                </tr>
                              </table>
                              <script type="text/javascript">
                                OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowKnow();});
                              </script>
                              <div class="footer">
                                <input type="submit" name="pf_cancel2" value="Cancel" onclick="needToConfirm = false;"/>
                                <input type="submit" name="pf_update057" value="Save" onclick="myBeforeSubmit(); return validateInputs(this, 'pf057');"/>
                              </div>
                            </div>
                            <%
                              }
                            %>
                          </div>
                          <%
                          }
                      if ($_formTab2 < 5)
                      {
                      %>
                      <div class="footer">
                        <input type="submit" name="pf_cancel" value="Cancel" onclick="needToConfirm = false;"/>
                        <input type="submit" name="pf_update" value="Save" onclick="myBeforeSubmit(); return myValidateInputs(this);"/>
                        <input type="submit" name="pf_next" value="Save & Next" onclick="myBeforeSubmit(); return myValidateInputs(this);"/>
                      </div>
                      <%
                        }
                      %>
                    </div>
                  </div>
                  <%
                  }
                  if ($_formTab == 1)
                  {
                  %>
                  <div id="pf_page_1" class="tabContent" style="display:none;">
                    <ul id="pf_tabs_1" class="tabs">
                      <li id="pf_tab_1_0" title="Main">Main</li>
                      <li id="pf_tab_1_1" title="Address">Address</li>
                      <li id="pf_tab_1_2" title="Online Accounts">Online Accounts</li>
                      <li id="pf_tab_1_3" title="Messaging Services">Messaging Services</li>
                    </ul>
                    <div style="min-height: 180px; min-width: 650px; border-top: 1px solid #aaa; margin: -13px 5px 5px 5px;">
                      <%
                      if ($_formTab2 == 0)
                      {
                      %>
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
                                <option value="2">acl</option>
                                <option value="3">private</option>
                              </select>
                        </td>
                      </tr>
                        </table>
                      </div>
                      <%
                      }
                      if ($_formTab2 == 1)
                      {
                      %>
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
                                Use as default map location
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
                                <option value="2">acl</option>
                                <option value="3">private</option>
                              </select>
                            </td>
                          </tr>
                        </table>
                      </div>
                      <%
                      }
                      if ($_formTab2 == 2)
                      {
                      %>
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
                      <%
                      }
                      if ($_formTab2 == 3)
                      {
                      %>
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
                                <option value="2">acl</option>
                                <option value="3">private</option>
                              </select>
                            </td>
                          </tr>
                          <script type="text/javascript">
                            OAT.MSG.attach(OAT, "PAGE_LOADED", function (){pfShowRows("y2", '<% out.print(xpathEvaluate($_document, "/user/businessMessaging").replace("\n", "\\n")); %>', ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1}, fld_2: {value: val2, cssText: 'width: 220px;'}});});});
                          </script>
                    </table>
                  </div>
                      <%
                      }
                      %>
                      <div class="footer">
                        <input type="submit" name="pf_cancel" value="Cancel" onclick="needToConfirm = false;"/>
                        <input type="submit" name="pf_update" value="Save" onclick="myBeforeSubmit(); return myValidateInputs(this);"/>
                        <input type="submit" name="pf_next" value="Save & Next" onclick="myBeforeSubmit(); return myValidateInputs(this);"/>
                      </div>
                    </div>
                  </div>
                  <%
                  }
                  if ($_formTab == 2)
                  {
                  %>
                  <div id="pf_page_2" class="tabContent" style="display:none;">
                    <ul id="pf_tabs_2" class="tabs">
                      <li id="pf_tab_2_0" title="Password">Password</li>
                      <li id="pf_tab_2_1" title="Password Recovery">Password Recovery</li>
                      <li id="pf_tab_2_2" title="OpenID">OpenID</li>
                      <li id="pf_tab_2_3" title="Limits">Limits</li>
                      <li id="pf_tab_2_4" title="Certificate Generator" style="display:none;">Certificate Generator</li>
                      <li id="pf_tab_2_5" title="X.509 Certificates">X.509 Certificates</li>
                    </ul>
                    <div style="min-height: 180px; min-width: 650px; border-top: 1px solid #aaa; margin: -13px 5px 5px 5px;">
                      <%
                      if ($_formTab2 == 0)
                      {
                      %>
                      <div id="pf_page_2_0" class="tabContent" style="display:none;">
                        <h2>Change login password</h2>
                        <p class="fm_expln">For your security, please use a password not found in a dictionary, consisting of both letters, and numbers or non-alphanumeric characters.</p>
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
                      <%
                      }
                      if ($_formTab2 == 1)
                      {
                      %>
                      <div id="pf_page_2_1" class="tabContent" style="display:none;">
                        <h2>Password recovery questions</h2>
                        <p class="fm_expln">Manage password recovery procedure. Set verification question / answer.</p>
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
                      <%
                      }
                      if ($_formTab2 == 2)
                      {
                      %>
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
                      <%
                      }
                      if ($_formTab2 == 3)
                      {
                      %>
                      <div id="pf_page_2_3" class="tabContent" style="display:none;">
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
                      }
                      if ($_formTab2 == 4)
                      {
                      %>
                      <div id="pf_page_2_4" class="tabContent" style="display:none;">
            	          <iframe id="cert" src="/ods/cert.vsp?sid=<% out.print($_sid); %>" width="650" height="270" frameborder="0" scrolling="no">
            	            <p>Your browser does not support iframes.</p>
            	          </iframe>
                      </div>
                      <%
                      }
                      if ($_formTab2 == 5)
                      {
                      %>
                      <div id="pf_page_2_5" class="tabContent" style="display:none;">
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
                              <th width="15%"></th>
                              <td>
                                <label>
                                  <input type="checkbox" name="pf26_importFile" id="pf26_importFile" value="1" onclick="destinationChange(this, {checked: {show: ['pf26_form_3'], hide: ['pf26_form_4']}, unchecked: {hide: ['pf26_form_3'], show: ['pf26_form_4']}});" />
                                  <b>Import from local file</b>
                                </label>
                              </td>
                            </tr>
                            <tr id="pf26_form_3" style="display: none;">
                              <th width="15%">
                                <label for="pf26_file">File to import</label>
                              </th>
                              <td align="left">
                                <input type="file" name="pf26_file" id="pf26_file" />
                              </td>
                            </tr>
                            <tr id="pf26_form_4">
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
                      if ($_formTab2 < 4)
                        {
                      %>
                    <div class="footer">
                      <input type="submit" name="pf_cancel" value="Cancel" onclick="needToConfirm = false;"/>
                        <input type="submit" name="pf_update" value="Save" onclick="myBeforeSubmit(); return myValidateInputs(this);"/>
                        <input type="submit" name="pf_next" value="Save & Next" onclick="myBeforeSubmit(); return myValidateInputs(this);"/>
                      </div>
                      <%
                        }
                      %>
                  </div>
                </div>
                  <%
                  }
                  %>
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
        <a href="http://www.openlinksw.com/virtuoso"><img border="0" alt="Powered by OpenLink Virtuoso Universal Server" src="/ods/images/virt_power_no_border.png" border="0" /></a>
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
