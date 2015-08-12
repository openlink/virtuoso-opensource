/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

import javax.sql.DataSource;
import java.sql.*;
import java.io.PrintWriter;
import java.io.Serializable;
import java.util.Properties;
import java.util.Enumeration;
import javax.naming.*;


public class VirtuosoDataSource implements DataSource, Referenceable, Serializable {

    protected String logFileName = null;
    protected String dataSourceName = "VirtuosoDataSourceName";
    protected String description;
    protected String serverName = "localhost";
    protected String portNumber = "1111";
    protected String databaseName;
    protected String user = "dba";
    protected String password = "dba";

    protected String charSet;
    protected int loginTimeout = 0;
    protected String pwdclear;
    protected int log_enable = -1;

#ifdef SSL
    protected String certificate;
    protected String certificatepass;
    protected String keystorepass;
    protected String keystorepath;
    protected String provider;
#endif
    protected int fbs = 0;
    protected int sendbs = 0;
    protected int recvbs = 0;
    protected boolean roundrobin = false;

#if JDK_VER >= 16
    protected boolean usepstmtpool = false;
    protected int pstmtpoolsize = 0;
#endif


    protected transient java.io.PrintWriter logWriter;


    final static String n_logFileName = "logFileName";
    final static String n_dataSourceName = "dataSourceName";
    final static String n_description = "description";
    final static String n_serverName = "serverName";
    final static String n_portNumber = "portNumber";
    final static String n_databaseName = "databaseName";
    final static String n_user = "user";
    final static String n_password = "password";

    final static String n_charSet = "charSet";
    final static String n_loginTimeout = "loginTimeout";
    final static String n_pwdclear = "pwdclear";
    final static String n_log_enable = "log_enable";

#ifdef SSL
    final static String n_certificate = "certificate";
    final static String n_certificatepass = "certificatepass";
    final static String n_keystorepass = "keystorepass";
    final static String n_keystorepath = "keystorepath";
    final static String n_provider = "provider";
#endif

    final static String n_fbs = "fbs";
    final static String n_sendbs = "sendbs";
    final static String n_recvbs = "recvbs";
    final static String n_roundrobin = "roundrobin";

#if JDK_VER >= 16
    final static String n_usepstmtpool = "usepstmtpool";
    final static String n_pstmtpoolsize = "pstmtpoolsize";
#endif


  public VirtuosoDataSource ()
  {
  }


//==================== interface Referenceable
  protected void  addProperties(Reference ref) {
    if (logFileName != null)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_logFileName, logFileName));
    if (dataSourceName != null)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_dataSourceName, dataSourceName));
    if (description != null)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_description, description));
    if (serverName != null)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_serverName, serverName));
    if (portNumber != null)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_portNumber, portNumber));

    if (databaseName != null)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_databaseName, databaseName));
    if (user != null)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_user, user));
    if (password != null)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_password, password));

    if (loginTimeout != 0)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_loginTimeout, String.valueOf(loginTimeout)));

    if (charSet != null)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_charSet, charSet));

    if (pwdclear != null)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_pwdclear, pwdclear));

    if (log_enable != 1)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_log_enable, String.valueOf(log_enable)));

#ifdef SSL
    if (certificate != null)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_certificate, certificate));

    if (certificatepass != null)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_certificatepass, certificatepass));

    if (keystorepass != null)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_keystorepass, keystorepass));

    if (keystorepath != null)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_keystorepath, keystorepath));

    if (provider != null)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_provider, provider));

#endif

    if (fbs != 0)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_fbs, String.valueOf(fbs)));

    if (sendbs != 0)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_sendbs, String.valueOf(sendbs)));

    if (recvbs != 0)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_recvbs, String.valueOf(recvbs)));

    ref.add(new StringRefAddr(VirtuosoDataSource.n_roundrobin, String.valueOf(roundrobin)));

#if JDK_VER >= 16
    ref.add(new StringRefAddr(VirtuosoDataSource.n_usepstmtpool, String.valueOf(usepstmtpool)));

    if (pstmtpoolsize != 0)
      ref.add(new StringRefAddr(VirtuosoDataSource.n_pstmtpoolsize, String.valueOf(pstmtpoolsize)));
#endif

  }


  // Referenceable members
  public Reference getReference() throws NamingException {
#if JDK_VER < 14
     Reference ref = new Reference(getClass().getName(), "virtuoso.jdbc2.VirtuosoDataSourceFactory", null);
#elif JDK_VER < 16
     Reference ref = new Reference(getClass().getName(), "virtuoso.jdbc3.VirtuosoDataSourceFactory", null);
#else
     Reference ref = new Reference(getClass().getName(), "virtuoso.jdbc4.VirtuosoDataSourceFactory", null);
#endif
     addProperties(ref);
     return ref;
  }


//================== interface Datasource
  protected Properties createConnProperties() {
    Properties prop = new Properties();

    String vhost = serverName;
    if (serverName.indexOf(':') == -1 &&
        serverName.indexOf(',') == -1 && portNumber != "1111")
      vhost += ":" + portNumber;

    prop.setProperty("_vhost", vhost);

    if (databaseName != null) prop.setProperty("database", databaseName);

    if (user != null)      prop.setProperty("user", user);
    if (password != null)  prop.setProperty("password", password);

    if (loginTimeout != 0)  prop.setProperty("timeout", String.valueOf(loginTimeout));

    if (charSet != null)   prop.setProperty("charset", charSet);
    if (pwdclear != null)   prop.setProperty("pwdclear", pwdclear);

    if (log_enable != -1)  prop.setProperty("log_enable", String.valueOf(log_enable));

#ifdef SSL
    if (certificate!=null)      prop.setProperty("certificate", certificate);
    if (certificatepass!=null)  prop.setProperty("certificatepass", certificatepass);
    if (keystorepass!=null)  prop.setProperty("keystorepass", keystorepass);
    if (keystorepath!=null)  prop.setProperty("keystorepath", keystorepath);
    if (provider!=null)  prop.setProperty("provider", provider);
#endif

    if (fbs != 0)  prop.setProperty("fbs", String.valueOf(fbs));
    if (sendbs != 0)  prop.setProperty("sendbs", String.valueOf(sendbs));
    if (recvbs != 0)  prop.setProperty("recvbs", String.valueOf(recvbs));
    if (roundrobin)  prop.setProperty("roundrobin", "1");

#if JDK_VER >= 16
    if (usepstmtpool)  prop.setProperty("usepstmtpool", "1");
    if (pstmtpoolsize != 0)  prop.setProperty("pstmtpoolsize", String.valueOf(pstmtpoolsize));
#endif

    return prop;
  }


  protected String create_url_key(String base_conn_url, Properties info) {
    String key;

    StringBuffer connKeyBuf = new StringBuffer(128);
    connKeyBuf.append(base_conn_url);
    for (Enumeration en = info.propertyNames(); en.hasMoreElements();  )  {
      key = (String)en.nextElement();
      connKeyBuf.append(key);
      connKeyBuf.append('=');
      connKeyBuf.append(info.getProperty(key));
      connKeyBuf.append('/');
    }
    return  connKeyBuf.toString();
  }

  protected String create_url() {
    String url = "jdbc:virtuoso://" + serverName;
     if (serverName.indexOf(':') == -1 &&
         serverName.indexOf(',') == -1 && portNumber != "1111")
       url += ":" + portNumber;
    return url;
  }

  public Connection getConnection() throws SQLException
  {
     return getConnection (null, null);
  }


  public Connection getConnection(String username, String password)
    throws SQLException
  {
    String url = create_url();

    Properties info = createConnProperties();

    if (user != null)
        info.setProperty("user", user);
    if (password != null)
        info.setProperty("password", password);

    return new VirtuosoConnection (url, "localhost", 1111, info);
  }

  public PrintWriter getLogWriter() throws SQLException
  {
    return logWriter;
  }

  public void setLogWriter(PrintWriter out) throws SQLException
  {
    VirtuosoFuture.rpc_log = logWriter = out;
  }

  public void setLoginTimeout(int seconds) throws SQLException
  {
    loginTimeout = seconds;
  }

  public int getLoginTimeout() throws SQLException
  {
    return loginTimeout;
  }

 //////// properties

  /**
   * Get the log FileName.
   * The default value is null
   *
   * @return   log Filename
   *
  **/
  public String getLogFileName() {
    return logFileName;
  }
  /**
   * Set the log Filename. The default value is null
   *
   * @param parm  Filename to be set
   *
  **/
  public void setLogFileName(String parm) {
    logFileName = parm;

    if (logFileName!=null) {
      try {
         setLogWriter(new java.io.PrintWriter(new java.io.FileOutputStream(logFileName), true));
      } catch (Exception e) {}
    }

  }


  /**
   * Get the datasource name for this instance if set.
   * The default value is "VirtuosoDataSourceName"
   *
   * @return   DataSource name
   *
  **/
  public String getDataSourceName() {
    return dataSourceName;
  }
  /**
   * Set the DataSource name. The default value is "VirtuosoDataSourceName"
   *
   * @param parm  DataSource name to be set
   *
  **/
  public void setDataSourceName(String parm) {
    dataSourceName = parm;
  }


  public void setDescription (String description)
  {
    this.description = description;
  }
  public String getDescription ()
  {
    return this.description;
  }

  public void setServerName (String serverName)
  {
    this.serverName = serverName;
  }
  public String getServerName ()
  {
    return serverName;
  }

  /**
   * Get the port number on which oplrqb is listening for requests.
   * The default value is 1111
   *
   * @return   port number
   *
  **/
  public int getPortNumber() {
    return Integer.parseInt(portNumber);
  }
  /**
   * Set the port number where the oplrqb is listening for requests.
   * The default value is 1111 . Will be overwritten with value from URL,
   * if URL is set.
   *
   * @param parm  port number on which oplrqb is listening
   *
  **/
  public void setPortNumber(int parm) {
    portNumber = String.valueOf(parm);
  }


  public void setUser (String user)
  {
    this.user = user;
  }
  public String getUser ()
  {
    return this.user;
  }

  public void setPassword (String passwd)
  {
    this.password = passwd;
  }
  public String getPassword ()
  {
    return this.password;
  }

  public void setDatabaseName (String name)
  {
    this.databaseName = name;
  }
  public String getDatabaseName ()
  {
    return databaseName;
  }

  public void setCharset (String name)
  {
    this.charSet = name;
  }
  public String getCharset ()
  {
    return this.charSet;
  }

  public void setPwdClear (String value)
  {
    this.pwdclear = value;
  }
  public String getPwdClear ()
  {
    return this.pwdclear;
  }


  public void setLog_Enable(int bits) throws SQLException
  {
    if (bits<-1 || bits>3)
      throw new SQLException("The log_enable options must be between -1 and 3");
    log_enable = bits;
  }

  public int getLog_Enable() throws SQLException
  {
    return log_enable;
  }

#ifdef SSL
  public void setCertificate (String value)
  {
    this.certificate = value;
  }
  public String getCertificate ()
  {
    return this.certificate;
  }

  public void setCertificatepass (String value)
  {
    this.certificatepass = value;
  }
  public String getCertificatepass ()
  {
    return this.certificatepass;
  }

  public void setKeystorepass (String value)
  {
    this.keystorepass = value;
  }
  public String getKeystorepass ()
  {
    return this.keystorepass;
  }

  public void setKeystorepath (String value)
  {
    this.keystorepath = value;
  }
  public String getKeystorepath ()
  {
    return this.keystorepath;
  }

  public void setProvider (String value)
  {
    this.provider = value;
  }
  public String getProvider ()
  {
    return this.provider;
  }
#endif

  public void setFbs (int value)
  {
    this.fbs = value;
  }
  public int getFbs ()
  {
    return this.fbs;
  }

  public void setSendbs (int value)
  {
    this.sendbs = value;
  }
  public int getSendbs ()
  {
    return this.sendbs;
  }

  public void setRecvbs (int value)
  {
    this.recvbs = value;
  }
  public int getRecvbs ()
  {
    return this.recvbs;
  }

  public void setRoundrobin (boolean value)
  {
    this.roundrobin = value;
  }
  public boolean getRoundrobin ()
  {
    return this.roundrobin;
  }

#if JDK_VER >= 16
  public void setUsepstmtpool (boolean value)
  {
    this.usepstmtpool = value;
  }
  public boolean getUsepstmtpool ()
  {
    return this.usepstmtpool;
  }

  public void setPstmtpoolsize (int value)
  {
    this.pstmtpoolsize = value;
  }
  public int getPstmtpoolsize ()
  {
    return this.pstmtpoolsize;
  }


    /**
     * Returns an object that implements the given interface to allow access to
     * non-standard methods, or standard methods not exposed by the proxy.
     *
     * If the receiver implements the interface then the result is the receiver
     * or a proxy for the receiver. If the receiver is a wrapper
     * and the wrapped object implements the interface then the result is the
     * wrapped object or a proxy for the wrapped object. Otherwise return the
     * the result of calling <code>unwrap</code> recursively on the wrapped object
     * or a proxy for that result. If the receiver is not a
     * wrapper and does not implement the interface, then an <code>SQLException</code> is thrown.
     *
     * @param iface A Class defining an interface that the result must implement.
     * @return an object that implements the interface. May be a proxy for the actual implementing object.
     * @throws java.sql.SQLException If no object found that implements the interface
     * @since 1.6
     */
  public <T> T unwrap(java.lang.Class<T> iface) throws java.sql.SQLException
  {
    try {
      // This works for classes that aren't actually wrapping anything
      return iface.cast(this);
    } catch (ClassCastException cce) {
      throw new VirtuosoException("Unable to unwrap to "+iface.toString(), VirtuosoException.OK);
    }
  }

    /**
     * Returns true if this either implements the interface argument or is directly or indirectly a wrapper
     * for an object that does. Returns false otherwise. If this implements the interface then return true,
     * else if this is a wrapper then return the result of recursively calling <code>isWrapperFor</code> on the wrapped
     * object. If this does not implement the interface and is not a wrapper, return false.
     * This method should be implemented as a low-cost operation compared to <code>unwrap</code> so that
     * callers can use this method to avoid expensive <code>unwrap</code> calls that may fail. If this method
     * returns true then calling <code>unwrap</code> with the same argument should succeed.
     *
     * @param iface a Class defining an interface.
     * @return true if this implements the interface or directly or indirectly wraps an object that does.
     * @throws java.sql.SQLException  if an error occurs while determining whether this is a wrapper
     * for an object with the given interface.
     * @since 1.6
     */
  public boolean isWrapperFor(java.lang.Class<?> iface) throws java.sql.SQLException
  {
    // This works for classes that aren't actually wrapping anything
    return iface.isInstance(this);
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
#endif


}
