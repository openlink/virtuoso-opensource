/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

package virtuoso.jdbc2;

import java.sql.*;
import java.util.*;

/**
 * The Virtuoso DBMS Driver class is an implementation of the Driver interface
 * in the JDBC API. It can be loaded in an application by :
 * <pre>
 *   <code>Class.forName("virtuoso.jdbc2.Driver")</code>
 * </pre>
 * , or statically with the -Djdbc.drivers=virtuoso.jdbc2.Driver on the java
 * interpreter command line, or in the java properties files with an entry like
 * before.
 * <u>Hints :</u> <ul>You can see the version of the current Virtuoso DBMS JDBC driver accessible in
 * the <i>CLASSPATH</i> with the <b>java virtuoso.jdbc2.Driver</b>
 * </ul>
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 * @see java.sql.Driver
 * @see java.sql.DriverManager
 * @see virtuoso.jdbc2.VirtuosoConnection
 */
public class Driver implements java.sql.Driver
{
   // Specifically, it creates a new Driver instance and registers it.
   static
   {
      try
      {
         DriverManager.registerDriver(new Driver());
      }
      catch(Exception e)
      {
         e.printStackTrace();
      }
   }

   // The major and minor version number
   protected static final int major = 3;

   protected static final int minor = 70;

   // Some variables
   private String host = "localhost";
   private String port = "1111";
   private String  user, password, database, charset, pwdclear;
   private Integer timeout, log_enable;
#ifdef SSL
   private String keystore_cert, keystore_pass, keystore_path;
   private String ssl_provider;
#endif
   private Integer fbs, sendbs, recvbs;

   private final String VirtPrefix = "jdbc:virtuoso://";

   /**
    * Constructs a Virtuoso DBMS Driver instance. This function has not to be called
    * directly, this function is called only during the DriverManager registration
    * done with :
    * <pre>
    *   <code>Class.forName("virtuoso.jdbc2.Driver")</code>
    * </pre>
    *
    * @exception java.sql.SQLException an error occurred in registering
    */
   public Driver() throws SQLException
   {
     try
       {
	 String log_file = System.getProperty(
#if JDK_VER < 12
	     "JDBC_LOG"
#elif JDK_VER < 14
	     "JDBC2_LOG"
#elif JDK_VER < 16
	     "JDBC3_LOG"
#else
	     "JDBC4_LOG"
#endif
	     );
	 //log_file="/home/O12/logs/log." + System.currentTimeMillis () + "." + new java.util.Random ().nextInt() + ".log";
	 if (log_file != null)
	   {
	     System.err.println ("RPC logfile=" + log_file);
	     try
	       {
		 VirtuosoFuture.rpc_log = new java.io.PrintStream (
		     new java.io.BufferedOutputStream (
		       new java.io.FileOutputStream (log_file), 4096));
	       }
	     catch (Exception e)
	       {
		 VirtuosoFuture.rpc_log = System.out;
	       }
	     //System.err.println ("rpc_log=" + VirtuosoFuture.rpc_log);
	   }
       }
     catch (Exception e)
       {
         VirtuosoFuture.rpc_log = null;
       }
   }

   // --------------------------- JDBC 1.0 ------------------------------
   /**
    * Attempts to make a database connection to the given URL.
    * The driver returns "null" if the URL given is not a Virtuoso DBMS JDBC
    * URL. A URL under the Virtuoso DBMS JDBC driver should be :
    * <pre>
    *   <code>jdbc:virtuoso://<i>host</i>:<i>port</i></code> , or
    *   <code>jdbc:virtuoso://<i>host</i>:<i>port</i>/UID=<i>username</i>/PWD=<i>userpassword</i></code>
    * </pre>
    * This function is only called through the DriverManager.getConnection function.
    *
    * @param url the URL of the database to which to connect
    * @param info a list of arbitrary string tag/value pairs as
    * connection arguments. Normally at least a "user" and
    * "password" property should be included.
    * @return a <code>Connection</code> object that represents a
    *         connection to the URL
    * @exception virtuoso.jdbc2.VirtuosoException it is the right
    * driver to connect to the given URL, but has trouble connecting to
    * the database.
    * @see java.sql.Connection#connect
    */
   public Connection connect(String url, Properties info) throws VirtuosoException
   {
      try
      {
         // First check the URL
         if(acceptsURL(url))
         {
            Properties props = urlToInfo(url, info);
            return new VirtuosoConnection(url,host,Integer.parseInt(port),props);
         }
      }
      catch(NumberFormatException e)
      {
         throw new VirtuosoException("Wrong port number : " + e.getMessage(),VirtuosoException.BADFORMAT);
      }
      return null;
   }

   /**
    * Returns true if the driver thinks that it can open a connection
    * to the given URL.  Typically drivers will return true if they
    * understand the subprotocol specified in the URL and false if
    * they don't.
    *
    * @param url the URL of the database
    * @return true if this driver can connect to the given URL
    * @exception virtuoso.jdbc.VirtuosoException An internal error occurred.
    * @see java.sql.Connection#acceptsURL
    */
   public boolean acceptsURL(String url) throws VirtuosoException
   {
     if (url.startsWith (VirtPrefix))
       return true;
     return false;
   }


   protected Properties urlToInfo(String url, Properties _info)
   {
    host = "localhost";
    port = "1111";
    fbs = new Integer(VirtuosoTypes.DEFAULTPREFETCH);
    sendbs = new Integer(32768);
    recvbs = new Integer(32768);

    Properties props = new Properties();

    for (Enumeration en = _info.propertyNames(); en.hasMoreElements();  )  {
      String key = (String)en.nextElement();
      String property = (String)_info.getProperty(key);
      props.setProperty(key.toLowerCase(), property);
    }

    char inQuote = '\0';
    String attr = null; // name
    StringBuffer buff = new StringBuffer();

    String part = url.substring(VirtPrefix.length());
    boolean isFirst = true;

    for (int i = 0; i < part.length(); i++) {
      char c = part.charAt(i);

      switch (c) {
        case '\'':
        case '"':
          if (inQuote == c)
            inQuote = '\0';
          else if (inQuote == '\0')
            inQuote = c;
          break;
        case '/':
	  if (inQuote == '\0') {
            String val = buff.toString().trim();
            if (attr == null) { //  "jdbc:virtuoso://local:5000/MyParam/UID=sa/"
              attr = val;
              val  = "";
            }
	    if (attr != null && attr.length() > 0) {
	      //  The first part is the host:port stuff
              if (isFirst) {
                isFirst = false;
		props.setProperty("_vhost", attr);
              } else {
	        props.setProperty(attr.toLowerCase(), val);
              }
	    }
	    attr = null;
	    buff.setLength(0);
	  } else {
	    buff.append(c);
	  }
	  break;
        case '=':
	  if (inQuote == '\0') {
	    attr = buff.toString().trim();
	    buff.setLength(0);
	  } else {
	    buff.append(c);
	  }
	  break;
        default:
	  buff.append(c);
	  break;
      }
    }

    String val = buff.toString().trim();
    if (attr == null) {
      attr = val;
      val  = "";
    }
    if (attr != null && attr.length() > 0) {
      if (isFirst)
        props.put("_vhost", attr);
      else
        props.put(attr.toLowerCase(), val);
    }

    char fsep = System.getProperty("file.separator").charAt(0);

    val = props.getProperty("kpath");
    if (val != null) {
      if (fsep != '\\') {
        val = val.replace('\\', fsep);
        props.put("kpath", val);
      }
    }
    val = props.getProperty("cert");
    if (val != null) {
      if (fsep != '\\') {
        val = val.replace('\\', fsep);
        props.put("cert", val);
      }
    }
    val = props.getProperty("ts");
    if (val != null) {
      if (fsep != '\\') {
        val = val.replace('\\', fsep);
        props.put("ts", val);
      }
    }

    val = props.getProperty("ssl");
    if (val != null) {
      if (props.getProperty("cert")==null)
        props.setProperty("cert", "");
    }

    val = props.getProperty("pwdtype");
    if (val != null)
      props.setProperty("pwdclear", val);

    val = props.getProperty("uid");
    if (val != null)
      props.setProperty("user", val);

    val = props.getProperty("pwd");
    if (val != null)
      props.setProperty("password", val);


    val = props.getProperty("cert");
    if (val != null)
      props.setProperty("certificate", val);

    val = props.getProperty("ts");
    if (val != null)
      props.setProperty("certificate", val);

    val = props.getProperty("tspass");
    if (val != null)
      props.setProperty("certificatepass", val);


    val = props.getProperty("kpath");
    if (val != null)
      props.setProperty("keystorepath", val);

    val = props.getProperty("pass");
    if (val != null)
      props.setProperty("keystorepass", val);

    val = props.getProperty("kpass");
    if (val != null)
      props.setProperty("keystorepass", val);

    return props;
   }


   /**
    * Gets information about the possible properties for this driver.
    * <p>The getPropertyInfo method is intended to allow a generic GUI tool to
    * discover what properties it should prompt a human for in order to get
    * enough information to connect to a database.  Note that depending on
    * the values the human has supplied so far, additional values may become
    * necessary, so it may be necessary to iterate though several calls
    * to getPropertyInfo.
    *
    * @param url the URL of the database to which to connect
    * @param info a proposed list of tag/value pairs that will be sent on
    *          connect open
    * @return an array of DriverPropertyInfo objects describing possible
    *          properties.  This array may be an empty array if no properties
    *          are required.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    * @see java.sql.Connection#getPropertyInfo
    */
   public DriverPropertyInfo[] getPropertyInfo(String url, Properties info) throws VirtuosoException
   {
      Vector pinfo = new Vector();
      DriverPropertyInfo pr;
      // First check the URL
      if(acceptsURL(url))
      {
         if(info.get("user") == null)
         {
            pr = new DriverPropertyInfo("user",null);
            pr.required = true;
            pinfo.add(pr);
         }
         if(info.get("password") == null)
         {
            pr = new DriverPropertyInfo("password",null);
            pr.required = true;
            pinfo.add(pr);
         }
         if(info.get("database") == null)
         {
            pr = new DriverPropertyInfo("database",null);
            pr.required = false;
            pinfo.add(pr);
         }
#ifdef SSL
         if(info.get("certificate") == null)
         {
            pr = new DriverPropertyInfo("certificate",null);
            pr.required = false;
            pinfo.add(pr);
         }
         if(info.get("keystorepass") == null)
         {
            pr = new DriverPropertyInfo("keystorepass",null);
            pr.required = false;
            pinfo.add(pr);
         }
         if(info.get("keystorepath") == null)
         {
            pr = new DriverPropertyInfo("keystorepath",null);
            pr.required = false;
            pinfo.add(pr);
         }
         if(info.get("provider") == null)
         {
            pr = new DriverPropertyInfo("provider",null);
            pr.required = false;
            pinfo.add(pr);
         }
#endif
         DriverPropertyInfo drv_info[] = new DriverPropertyInfo[pinfo.size()];
         pinfo.copyInto(drv_info);
         return drv_info;
      }

      pr = new DriverPropertyInfo("url",url);
      pr.required = true;
      pinfo.add(pr);
      if(info.get("user") == null)
      {
         pr = new DriverPropertyInfo("user",null);
         pr.required = true;
         pinfo.add(pr);
      }
      if(info.get("password") == null)
      {
         pr = new DriverPropertyInfo("password",null);
         pr.required = true;
         pinfo.add(pr);
      }
      if(info.get("database") == null)
      {
         pr = new DriverPropertyInfo("database",null);
         pr.required = false;
         pinfo.add(pr);
      }
      if(info.get("fbs") == null)
      {
         pr = new DriverPropertyInfo("fbs",null);
         pr.required = false;
         pinfo.add(pr);
      }
      if(info.get("sendbs") == null)
      {
         pr = new DriverPropertyInfo("sendbs",null);
         pr.required = false;
         pinfo.add(pr);
      }
      if(info.get("recvbs") == null)
      {
         pr = new DriverPropertyInfo("recvbs",null);
         pr.required = false;
         pinfo.add(pr);
      }
      if(info.get("roundrobin") == null)
      {
         pr = new DriverPropertyInfo("roundrobin",null);
         pr.required = false;
         pinfo.add(pr);
      }
#ifdef SSL
      if(info.get("certificate") == null)
      {
         pr = new DriverPropertyInfo("certificate",null);
         pr.required = false;
         pinfo.add(pr);
      }
      if(info.get("keystorepass") == null)
      {
         pr = new DriverPropertyInfo("keystorepass",null);
         pr.required = false;
         pinfo.add(pr);
      }
      if(info.get("keystorepath") == null)
      {
         pr = new DriverPropertyInfo("keystorepath",null);
         pr.required = false;
         pinfo.add(pr);
      }
      if(info.get("provider") == null)
      {
         pr = new DriverPropertyInfo("provider",null);
         pr.required = false;
         pinfo.add(pr);
      }
#endif

#if JDK_VER >= 16
      if(info.get("usepstmtpool") == null)
      {
         pr = new DriverPropertyInfo("usepstmtpool",null);
         pr.required = false;
         pinfo.add(pr);
      }
      if(info.get("pstmtpoolsize") == null)
      {
         pr = new DriverPropertyInfo("pstmtpoolsize",null);
         pr.required = false;
         pinfo.add(pr);
      }
#endif
      DriverPropertyInfo drv_info[] = new DriverPropertyInfo[pinfo.size()];
      pinfo.copyInto(drv_info);
      return drv_info;
   }

   /**
    * Gets the driver's major version number.
    *
    * @return this driver's major version number
    */
   public int getMajorVersion()
   {
      return major;
   }

   /**
    * Gets the driver's minor version number.
    *
    * @return this driver's minor version number
    */
   public int getMinorVersion()
   {
      return minor;
   }

   /**
    * Reports whether this driver is a genuine JDBC COMPLIANT driver.
    *
    * @return true if the JDBC Driver is compliant, false otherwise ... but
    * our Virtuoso DBMS JDBC driver is compliant, so true is always returned.
    */
   public boolean jdbcCompliant()
   {
      return true;
   }

   public static void main(String args[])
   {
#ifdef SSL
      System.out.println("OpenLink Virtuoso(TM) Driver with SSL support for JDBC(TM) Version " + VIRT_JDBC_VER + " [Build " + major + "." + minor + "]");
#else
      System.out.println("OpenLink Virtuoso(TM) Driver for JDBC(TM) Version " + VIRT_JDBC_VER + " [Build " + major + "." + minor + "]");
#endif
   }

#if JDK_VER >= 17
    //------------------------- JDBC 4.1 -----------------------------------

    /**
     * Return the parent Logger of all the Loggers used by this driver. This
     * should be the Logger farthest from the root Logger that is
     * still an ancestor of all of the Loggers used by this driver. Configuring
     * this Logger will affect all of the log messages generated by the driver.
     * In the worst case, this may be the root Logger.
     *
     * @return the parent Logger for this driver
     * @throws SQLFeatureNotSupportedException if the driver does not use <code>java.util.logging<code>.
     * @since 1.7
     */
   public java.util.logging.Logger getParentLogger() throws SQLFeatureNotSupportedException
   {
     throw new VirtuosoFNSException ("getParentLogger()  not supported", VirtuosoException.NOTIMPLEMENTED);
   }
#endif
}
