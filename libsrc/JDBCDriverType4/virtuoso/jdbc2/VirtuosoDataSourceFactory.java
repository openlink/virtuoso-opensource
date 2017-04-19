/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

import javax.naming.spi.ObjectFactory;
import javax.naming.Name;
import javax.naming.Context;
import javax.naming.Reference;
import javax.naming.StringRefAddr;
import java.util.Hashtable;
import javax.sql.*;

public class VirtuosoDataSourceFactory implements ObjectFactory {

  public VirtuosoDataSourceFactory() {
  }

  public Object getObjectInstance(Object obj, Name name, Context nameCtx, Hashtable environment)
    throws Exception
  {
    Reference ref = (Reference)obj;
    DataSource ds;
    String className = ref.getClassName();
#if JDK_VER < 14
    if (className.equals("virtuoso.jdbc2.VirtuosoDataSource"))
      ds = new VirtuosoDataSource();
    else if (className.equals("virtuoso.jdbc2.VirtuosoConnectionPoolDataSource"))
      ds = new VirtuosoConnectionPoolDataSource();
    else if (className.equals("virtuoso.jdbc2.VirtuosoXADataSource"))
      ds = new VirtuosoXADataSource();
    else
      return null;
#elif JDK_VER < 16
    if (className.equals("virtuoso.jdbc3.VirtuosoDataSource"))
      ds = new VirtuosoDataSource();
    else if (className.equals("virtuoso.jdbc3.VirtuosoConnectionPoolDataSource"))
      ds = new VirtuosoConnectionPoolDataSource();
    else if (className.equals("virtuoso.jdbc3.VirtuosoXADataSource"))
      ds = new VirtuosoXADataSource();
    else
      return null;
#else
    if (className.equals("virtuoso.jdbc4.VirtuosoDataSource"))
      ds = new VirtuosoDataSource();
    else if (className.equals("virtuoso.jdbc4.VirtuosoConnectionPoolDataSource"))
      ds = new VirtuosoConnectionPoolDataSource();
    else if (className.equals("virtuoso.jdbc4.VirtuosoXADataSource"))
      ds = new VirtuosoXADataSource();
    else
      return null;
#endif

    if (ds != null) {
      StringRefAddr refS;

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_logFileName)) != null)
          ((VirtuosoDataSource) ds).setLogFileName((String)refS.getContent());

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_dataSourceName)) != null)
          ((VirtuosoDataSource) ds).setDataSourceName((String)refS.getContent());

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_description)) != null)
          ((VirtuosoDataSource) ds).setDescription((String)refS.getContent());

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_serverName)) != null)
          ((VirtuosoDataSource) ds).setServerName((String)refS.getContent());

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_portNumber)) != null)
          ((VirtuosoDataSource) ds).setPortNumber(Integer.parseInt((String)refS.getContent()));

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_databaseName)) != null)
          ((VirtuosoDataSource) ds).setDatabaseName((String)refS.getContent());

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_user)) != null)
          ((VirtuosoDataSource) ds).setUser((String)refS.getContent());

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_password)) != null)
          ((VirtuosoDataSource) ds).setPassword((String)refS.getContent());

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_loginTimeout)) != null)
          ((VirtuosoDataSource) ds).setLoginTimeout(Integer.parseInt((String)refS.getContent()));

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_charset)) != null)
          ((VirtuosoDataSource) ds).setCharset((String)refS.getContent());
      else if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_charSet)) != null)
          ((VirtuosoDataSource) ds).setCharset((String)refS.getContent());

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_pwdclear)) != null)
          ((VirtuosoDataSource) ds).setPwdClear((String)refS.getContent());

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_log_enable)) != null)
          ((VirtuosoDataSource) ds).setLog_Enable(Integer.parseInt((String)refS.getContent()));

#ifdef SSL
      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_certificate)) != null)
          ((VirtuosoDataSource) ds).setCertificate((String)refS.getContent());

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_keystorepass)) != null)
          ((VirtuosoDataSource) ds).setKeystorepass((String)refS.getContent());

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_keystorepath)) != null)
          ((VirtuosoDataSource) ds).setKeystorepath((String)refS.getContent());

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_provider)) != null)
          ((VirtuosoDataSource) ds).setProvider((String)refS.getContent());

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_truststorepass)) != null)
          ((VirtuosoDataSource) ds).setTruststorepass((String)refS.getContent());

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_truststorepath)) != null)
          ((VirtuosoDataSource) ds).setTruststorepath((String)refS.getContent());

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_ssl)) != null)
          ((VirtuosoDataSource) ds).setSsl(Boolean.getBoolean((String)refS.getContent()));
#endif

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_fbs)) != null)
          ((VirtuosoDataSource) ds).setFbs(Integer.parseInt((String)refS.getContent()));

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_sendbs)) != null)
          ((VirtuosoDataSource) ds).setSendbs(Integer.parseInt((String)refS.getContent()));

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_recvbs)) != null)
          ((VirtuosoDataSource) ds).setRecvbs(Integer.parseInt((String)refS.getContent()));

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_roundrobin)) != null)
          ((VirtuosoDataSource) ds).setRoundrobin(Boolean.getBoolean((String)refS.getContent()));

#if JDK_VER >= 16
      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_usepstmtpool)) != null)
          ((VirtuosoDataSource) ds).setUsepstmtpool(Boolean.getBoolean((String)refS.getContent()));

      if ((refS = (StringRefAddr)ref.get(VirtuosoDataSource.n_pstmtpoolsize)) != null)
          ((VirtuosoDataSource) ds).setPstmtpoolsize(Integer.parseInt((String)refS.getContent()));
#endif

      if (ds instanceof virtuoso.jdbc2.VirtuosoConnectionPoolDataSource) {

        if ((refS = (StringRefAddr)ref.get(VirtuosoConnectionPoolDataSource.n_maxStatements)) != null)
            ((VirtuosoConnectionPoolDataSource) ds).setMaxStatements(Integer.parseInt((String)refS.getContent()));

        if ((refS = (StringRefAddr)ref.get(VirtuosoConnectionPoolDataSource.n_initialPoolSize)) != null)
            ((VirtuosoConnectionPoolDataSource) ds).setInitialPoolSize(Integer.parseInt((String)refS.getContent()));

        if ((refS = (StringRefAddr)ref.get(VirtuosoConnectionPoolDataSource.n_minPoolSize)) != null)
            ((VirtuosoConnectionPoolDataSource) ds).setMinPoolSize(Integer.parseInt((String)refS.getContent()));

        if ((refS = (StringRefAddr)ref.get(VirtuosoConnectionPoolDataSource.n_maxPoolSize)) != null)
            ((VirtuosoConnectionPoolDataSource) ds).setMaxPoolSize(Integer.parseInt((String)refS.getContent()));

        if ((refS = (StringRefAddr)ref.get(VirtuosoConnectionPoolDataSource.n_maxIdleTime)) != null)
            ((VirtuosoConnectionPoolDataSource) ds).setMaxIdleTime(Integer.parseInt((String)refS.getContent()));

        if ((refS = (StringRefAddr)ref.get(VirtuosoConnectionPoolDataSource.n_propertyCycle)) != null)
            ((VirtuosoConnectionPoolDataSource) ds).setPropertyCycle(Integer.parseInt((String)refS.getContent()));

        ((VirtuosoConnectionPoolDataSource)ds).fill();

      }
    }

    return ds;
  }
}
