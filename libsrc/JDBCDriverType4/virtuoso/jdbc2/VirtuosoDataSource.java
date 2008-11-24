/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
 *  
*/
package virtuoso.jdbc2;

import javax.sql.DataSource;
import java.io.Serializable;
import java.sql.Connection;
import java.sql.SQLException;
import javax.naming.Reference;
import javax.naming.NamingException;
import javax.naming.Referenceable;


public class VirtuosoDataSource implements DataSource, Referenceable, Serializable {

  protected String description;
  protected String serverName;
  protected int port;
  protected String user;
  protected String password;
  protected String databaseName;
  protected String charset;
  protected String pwdclear;
  protected Integer loginTimeout;
  protected java.io.PrintWriter logWriter;

  public VirtuosoDataSource ()
  {
    description = null;
    serverName = "localhost";
    port = 1111;
    user = "dba";
    password = "dba";
    databaseName = null;
    charset = null;
    pwdclear = null;
    loginTimeout = null;
    logWriter = null;
  }

  public Connection getConnection() throws SQLException
  {
     return getConnection (this.user, this.password);
  }

  public Connection getConnection(String username, String password)
    throws SQLException
  {
     java.util.Properties props = new java.util.Properties();
     props.put ("user", username);
     props.put ("password", password);
     if (databaseName != null)
       props.put ("database", this.databaseName);
     if (charset != null)
       props.put ("charset", this.charset);
     if (pwdclear != null)
       props.put ("pwdclear", this.pwdclear);
     if (this.loginTimeout != null)
       props.put ("timeout", this.loginTimeout);

     return new VirtuosoConnection (
       "jdbc:virtuoso://" + serverName + ":" + port,
       serverName, port, props);
  }

  public java.io.PrintWriter getLogWriter() throws SQLException
  {
    return this.logWriter;
  }

  public void setLogWriter(java.io.PrintWriter out) throws SQLException
  {
    this.logWriter = out;
  }

  public void setLoginTimeout(int seconds) throws SQLException
  {
    this.loginTimeout = new Integer (seconds);
  }

  public int getLoginTimeout() throws SQLException
  {
    return this.loginTimeout != null ? this.loginTimeout.intValue() : 0;
  }

 //////// properties

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

  public void setPortNumber (int port)
  {
    this.port = port;
  }
  public int getPortNumber ()
  {
    return this.port;
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
    this.charset = name;
  }
  public String getCharset ()
  {
    return this.charset;
  }

  public void setPwdClear (String value)
  {
    this.pwdclear = value;
  }
  public String getPwdClear ()
  {
    return this.pwdclear;
  }


  // Referenceable members
  public Reference getReference()
                       throws NamingException
    {
      return new Reference (this.getClass().getName());
    }

#if JDK_VER >= 16
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
      throw new VirtuosoException ("Unable to unwrap to "+iface.toString(), "22023", VirtuosoException.BADPARAM);
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
#endif

}
