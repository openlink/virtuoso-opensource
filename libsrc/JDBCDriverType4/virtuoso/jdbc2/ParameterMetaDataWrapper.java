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

import java.sql.ParameterMetaData;
import java.sql.SQLException;
import java.sql.ParameterMetaData;
import java.sql.Types;

public class ParameterMetaDataWrapper implements ParameterMetaData {

  private ParameterMetaData wmd;
  private ConnectionWrapper wconn;

  protected ParameterMetaDataWrapper(ParameterMetaData _prmd,
  	ConnectionWrapper _wconn)
  {
    wmd = _prmd;
    wconn = _wconn;
  }


  private void exceptionOccurred(SQLException sqlEx) {
    if (wconn != null)
      wconn.exceptionOccurred(sqlEx);
  }


  public synchronized void finalize () throws Throwable {
    close();
  }

  protected void close() throws SQLException {
    if (wmd == null)
      return;
    wmd = null;
    wconn = null;
  }

  public int getParameterCount() throws java.sql.SQLException {
    try {
      return wmd.getParameterCount();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


  public int isNullable(int param) throws java.sql.SQLException {
    try {
      return wmd.isNullable(param);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


  public boolean isSigned(int param) throws java.sql.SQLException {
    try {
      return wmd.isSigned(param);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


  public int getPrecision(int param) throws java.sql.SQLException {
    try {
      return wmd.getPrecision(param);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


  public int getScale(int param) throws java.sql.SQLException {
    try {
      return wmd.getScale(param);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


  public int getParameterType(int param) throws java.sql.SQLException {
    try {
      return wmd.getParameterType(param);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


  public String getParameterTypeName(int param) throws java.sql.SQLException {
    try {
      return wmd.getParameterTypeName(param);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


  public String getParameterClassName(int param) throws java.sql.SQLException {
    try {
      return wmd.getParameterClassName(param);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


  public int getParameterMode(int param) throws java.sql.SQLException {
    try {
      return wmd.getParameterMode(param);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

#if JDK_VER >= 16
  public <T> T unwrap(java.lang.Class<T> iface) throws java.sql.SQLException
  {
    try {
      return wmd.unwrap(iface);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isWrapperFor(java.lang.Class<?> iface) throws java.sql.SQLException
  {
    try {
      return wmd.isWrapperFor(iface);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }
#endif

}
