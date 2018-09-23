/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

package virtuoso.jdbc4;

import java.sql.*;
import java.net.*;
import java.io.*;
import java.util.*;
#undef sun
import java.security.*;
import java.security.cert.*;
import javax.net.ssl.*;
import openlink.util.*;
import java.util.Vector;
import openlink.util.OPLHeapNClob;
import java.util.Map;
import java.util.HashMap;
import java.util.Iterator;

/**
 * The VirtuosoConnection class is an implementation of the Connection interface
 * in the JDBC API which represents a database connection. A connection to the
 * Virtuoso DBMS can be made with :
 * <pre>
 *   <code>Connection connection = DriverManager.getConnection(url,username,userpassword)</code>
 * </pre>
 * , in the case you use a URL like <code>jdbc:virtuoso://<i>host</i>:<i>port</i></code> or
 * <pre>
 *   <code>Connection connection = DriverManager.getConnection(url)</code>
 * </pre>
 * , in the case you use a URL like
 * <code>jdbc:virtuoso://<i>host</i>:<i>port</i>/UID=<i>username</i>/PWD=<i>userpassword</i></code>
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 * @see java.sql.Connection
 * @see java.sql.DriverManager#getConnection
 * @see virtuoso.jdbc4.VirtuosoStatement
 * @see virtuoso.jdbc4.VirtuosoPreparedStatement
 * @see virtuoso.jdbc4.VirtuosoCallableStatement
 * @see virtuoso.jdbc4.VirtuosoDatabaseMetaData
 */
public class VirtuosoConnection implements Connection
{
   // Buffered TCP socket stream
   private Socket socket;

   private VirtuosoInputStream in;

   private VirtuosoOutputStream out;

   // Hash table from future id to the VirtuosoFuture instance
   private Hashtable<Integer,VirtuosoFuture> futures;

   // Serial number of last issued future, 0 is first
   private int req_no, con_no;
   private static int global_con_no = 0;

   // String sent by server as answer to "SCON" RPC
   protected String qualifier;
   private String version;
   private int _case;
   protected openlink.util.Vector client_defaults;
   protected openlink.util.Vector client_charset;
   protected Hashtable<Character,Byte> client_charset_hash;
   protected SQLWarning warning = null;

   // String sent by server as answer to "caller_identification" RPC
   private String peer_name;

   // Flag which represent if transactions are in auto-commit mode
   private boolean auto_commit = true;

   // Flag is set if the connection participates in a global transaction.
   private boolean global_transaction = false;

   // The url of the database which the connection is associated
   private String url;

   // The login used to connect to the database.
   private String user, password, pwdclear;

   // The SSL parameters
   private String cert_alias;
   private String keystore_path, keystore_pass;
   private String truststore_path, truststore_pass;
   private String ssl_provider;
   private boolean use_ssl;
   private String con_delegate;

   // The transaction isolation
   private int trxisolation = Connection.TRANSACTION_REPEATABLE_READ;

   // The read mode
   private boolean readOnly = false;

   // The timeout for I/O
   protected int timeout_def = 60*1000;
   protected int timeout = 0;
   protected int txn_timeout = 0;

   protected int fbs = VirtuosoTypes.DEFAULTPREFETCH;

   // utf8_encoding for statements
   protected boolean utf8_execs = false;

   // timezoneless datetimes setting
   protected int timezoneless_datetimes = 0;


   // set if the connection is managed through VirtuosoPooledConnection;
   protected VirtuosoPooledConnection pooled_connection = null;
   protected VirtuosoXAConnection xa_connection = null;

   protected String charset;
   protected boolean charset_utf8 = false;


   protected Hashtable<Integer,String> rdf_type_hash = null;
   protected Hashtable<Integer,String> rdf_lang_hash = null;
   protected Hashtable<String,Integer> rdf_type_rev = null;
   protected Hashtable<String,Integer> rdf_lang_rev = null;

  private LRUCache<String,VirtuosoPreparedStatement> pStatementCache;
  private boolean  useCachePrepStatements = false;
  private Vector<VhostRec> hostList = new Vector<VhostRec>();
   protected boolean rdf_type_loaded = false;
   protected boolean rdf_lang_loaded = false;

#if JDK_VER >= 17
   private static final SQLPermission SET_NETWORK_TIMEOUT_PERM = new SQLPermission("setNetworkTimeout");
   private static final SQLPermission ABORT_PERM = new SQLPermission("abort");
#endif

  private boolean useRoundRobin;
  // The pingStatement to know if the connection is still available
  private Statement pingStatement = null;


   protected class VhostRec
   {
     protected String host;
     protected int port;

     protected VhostRec(String _host, String _port)  throws VirtuosoException
     {
       host = _host;
       try {
         port = Integer.parseInt(_port);
       } catch(NumberFormatException e) {
         throw new VirtuosoException("Wrong port number : " + e.getMessage(),VirtuosoException.BADFORMAT);
       }
     }

     protected VhostRec(String _host, int _port)  throws VirtuosoException
     {
       host = _host;
       port = _port;
     }
   }


   protected Vector<VhostRec> parse_vhost(String vhost, String _host, int _port) throws VirtuosoException
   {
     Vector<VhostRec> hostlist =  new Vector<VhostRec>();

     String port = Integer.toString(_port);
     String attr = null;
     StringBuffer buff = new StringBuffer();

     for (int i = 0; i < vhost.length(); i++) {
       char c = vhost.charAt(i);

       switch (c) {
         case ',':
           String val = buff.toString().trim();
           if (attr == null) {
             attr = val;
             val  = port;
           }
	   if (attr != null && attr.length() > 0)
              hostlist.add(new VhostRec(attr, val));
	   attr = null;
	   buff.setLength(0);
	   break;
         case ':':
	   attr = buff.toString().trim();
	   buff.setLength(0);
	   break;
         default:
	   buff.append(c);
	   break;
       }
     }

     String val = buff.toString().trim();
     if (attr == null) {
       attr = val;
       val  = port;
     }
     if (attr != null && attr.length() > 0) {
       hostlist.add(new VhostRec(attr, val));
     }

     if (hostlist.size() == 0)
       hostlist.add(new VhostRec(_host, _port));

     return hostlist;
   }


   private synchronized int getNextRoundRobinHostIndex()
   {
     int indexRange = hostList.size();
     return (int)(Math.random() * indexRange);
   }


   /**
    * Constructs a new connection to Virtuoso database and makes the
    * connection.
    *
    * @param url	The JDBC URL for the connection.
    * @param host	The name of the host on which the database resides.
    * @param port The port number on which Virtuoso is listening.
    * @param prop The properties to use for making the connection (user, password).
    * @exception	virtuoso.jdbc4.VirtuosoException	An error occurred during the
    * connection.
    */
   VirtuosoConnection(String url, String host, int port, Properties prop) throws VirtuosoException
   {
      int sendbs = 32768;
      int recvbs = 32768;

      hostList = parse_vhost(prop.getProperty("_vhost", ""), host, port);

      // Set some variables
      this.req_no = 0;
      this.url = url;
      this.con_no = global_con_no++;
      // Check properties
      if (prop.get("charset") != null)
      {
	charset = (String)prop.get("charset");
	//System.out.println ("VirtuosoConnection " + charset);
	if (charset.toUpperCase().indexOf("UTF-8") != -1) // special case all will go as UTF-8
	{
	    this.charset = null;
	    this.charset_utf8 = true;
	    //utf8_execs = true;
	}
      }
      user = (String)prop.get("user");
      if(user == null || user.equals(""))
         user = "anonymous";
      password = (String)prop.get("password");
      if (password == null)
         password = "";

      timeout = getIntAttr(prop, "timeout", timeout)*1000;
      pwdclear = (String)prop.get("pwdclear");

      sendbs = getIntAttr(prop, "sendbs", sendbs);
      if (sendbs <= 0)
          sendbs = 32768;

      recvbs = getIntAttr(prop, "recvbs", recvbs);
      if (recvbs <= 0)
          recvbs = 32768;

      fbs = getIntAttr(prop, "fbs", fbs);
      if (fbs <= 0)
          fbs = VirtuosoTypes.DEFAULTPREFETCH;;
      //System.err.println ("3PwdClear is " + pwdclear);
      truststore_path = (String)prop.get("truststorepath");
      truststore_pass = (String)prop.get("truststorepass");
      keystore_pass = (String)prop.get("keystorepass");
      keystore_path = (String)prop.get("keystorepath");
      ssl_provider = (String)prop.get("provider");
      cert_alias = (String)prop.get("cert");
      use_ssl = getBoolAttr(prop, "ssl", false);
      con_delegate = (String)prop.get("delegate");
      if(pwdclear == null)
         pwdclear = "0";
      //System.err.println ("4PwdClear is " + pwdclear);
      // Create the hash table
      futures = new Hashtable<Integer,VirtuosoFuture>();
      // RDF box type & lang
      rdf_type_hash = new Hashtable<Integer,String> ();
      rdf_lang_hash = new Hashtable<Integer,String> ();
      rdf_type_rev = new Hashtable<String,Integer> ();
      rdf_lang_rev = new Hashtable<String,Integer> ();

      useCachePrepStatements = getBoolAttr(prop, "usepstmtpool", false);
      int poolSize = getIntAttr(prop, "pstmtpoolsize", 25);
      createCaches(poolSize);

      useRoundRobin = getBoolAttr(prop, "roundrobin", false);
      if (hostList.size() <= 1)
        useRoundRobin = false;

      // Connect to the database
      connect(host,port,(String)prop.get("database"), sendbs, recvbs, (prop.get("log_enable") != null ? (Integer.parseInt(prop.getProperty("log_enable"))) : -1));

      pingStatement = createStatement();
   }

   public synchronized boolean isConnectionLost(int timeout_sec)
   {
     ResultSet rs = null;
     try{
	pingStatement.setQueryTimeout(timeout_sec);
        rs = pingStatement.executeQuery("select 1");
        return false;
     } catch (Exception e ) {
        return true;
     } finally {
       if (rs!=null)
         try{
           rs.close();
         } catch(Exception e){}
     }
   }

   protected int getIntAttr(java.util.Properties info, String key, int def)
   {
     int ret = def;
     String val = info.getProperty(key);

     try {
	if (val != null && val.length() > 0)
	  ret = Integer.parseInt(val);
     } catch (NumberFormatException e) {
	ret = def;
     }
     return ret;
   }

   protected boolean getBoolAttr(java.util.Properties info, String key, boolean def)
   {
     boolean ret = def;

     String val = info.getProperty(key);
     if (val != null && val.length() > 0) {
       char c = val.charAt(0);
       return (c == 'Y' || c == 'y' || c == '1');
     } else {
       return def;
     }
   }

   /**
    * Connect to the Virtuoso database and set streams.
    *
    * @param host	The name of the host on which the database resides.
    * @param port 	The port number on which Virtuoso is listening.
    * @param database 	The database to connect to.
    * @exception	virtuoso.jdbc4.VirtuosoException	An error occurred during the
    * connection.
    */
   private void connect(String host, int port,String db, int sendbs, int recvbs, int log_enable) throws VirtuosoException
   {
      // Connect to the database
      int hostIndex = 0;
      int startIndex = 0;

      if (hostList.size() > 1 && useRoundRobin)
        startIndex = hostIndex = getNextRoundRobinHostIndex();

      while(true)
      {
        try {
          if (hostList.size() == 0) {
            connect(host, port, sendbs, recvbs);
          } else {
            VhostRec v = (VhostRec)hostList.elementAt(hostIndex);
            connect(v.host, v.port, sendbs, recvbs);
          }
          break;
        } catch (VirtuosoException e) {

          int erc = e.getErrorCode();
          if (erc != VirtuosoException.IOERROR && erc != VirtuosoException.NOLICENCE)
            throw e;

          hostIndex++;

          if (useRoundRobin) {
            if (hostList.size() == hostIndex)
              hostIndex = 0;

            if (hostIndex == startIndex)
              throw e;
          }
          else if (hostList.size() == hostIndex) { /* Failover mode last rec*/
            throw e;
          }
        }
      }

      // Set database with statement
      if(db!=null)
        try {
          new VirtuosoStatement(this).executeQuery("use "+db);
        } catch (VirtuosoException ve) {
          throw new VirtuosoException(ve, "Could not execute 'use "+db+"'", VirtuosoException.SQLERROR);
        }

      //System.out.println  ("log enable="+log_enable);
      if (log_enable >= 0 && log_enable <= 3)
        try {
          new VirtuosoStatement(this).executeQuery("log_enable ("+log_enable+")");
        } catch (VirtuosoException ve) {
          throw new VirtuosoException(ve, "Could not execute 'log_enable("+log_enable+")'", VirtuosoException.SQLERROR);
        }
   }


   private long cdef_param (openlink.util.Vector cdefs, String name, long deflt)
     {
       int len = cdefs != null ? cdefs.size() : 0;
       int inx;
       //System.err.println ("cdef_param: Searching " + name + " in " + cdefs.toString());
       for (inx = 0; inx < len; inx += 2)
	 if (name.equals ((String) cdefs.elementAt (inx)))
	   {
	     //System.err.println ("cdef_param: Found value=" + ((Number)cdefs.elementAt (inx + 1)).longValue());
	     return (((Number)cdefs.elementAt (inx + 1)).longValue());
	   }
       //System.err.println ("cdef_param: NOT Found default=" + deflt);
       return deflt;
     }

   private Object[] fill_login_info_array ()
   {
       Object[] ret = new Object[7];
       ret[0] = new String ("JDBC");
       ret[1] = new Integer (0);
       ret[2] = new String ("");
       ret[3] = System.getProperty("os.name");
       ret[4] = new String ("");
       ret[5] = new Integer (0);
       //System.out.println (con_delegate);
       ret[6] = new String (con_delegate != null ? con_delegate : "");
       return ret;
   }


    private Collection getCertificates(InputStream fis)
    	throws CertificateException
    {
        CertificateFactory cf;
        cf = CertificateFactory.getInstance("X.509");
        return cf.generateCertificates(fis);
    }

   /**
    * Connect to the Virtuoso database and set streams.
    *
    * @param host	The name of the host on which the database resides.
    * @param port 	The port number on which Virtuoso is listening.
    * @exception	virtuoso.jdbc4.VirtuosoException	An error occurred during the
    * connection.
    */
  private void connect(String host, int port, int sendbs, int recvbs) throws VirtuosoException
   {
      String fname = null;
      try
      {
         // Establish the connection
        if(use_ssl || truststore_path != null || keystore_path != null)
	  {
	    //System.out.println ("Will do SSL");
               if (ssl_provider != null && ssl_provider.length() != 0) {
		//System.out.println ("SSL Provider " + ssl_provider);
		Security.addProvider((Provider)(Class.forName(ssl_provider).newInstance()));
	      }

               SSLContext ssl_ctx = SSLContext.getInstance("TLS");
               X509TrustManager tm = new VirtX509TrustManager();
		KeyManager []km = null;
               TrustManager[] tma = null;
               KeyStore tks = null;

               if (truststore_path.length() > 0) {
                   InputStream fis = null;
                   String keys_pwd = (truststore_pass != null) ? truststore_pass : "";
                   String alg = TrustManagerFactory.getDefaultAlgorithm();
                   TrustManagerFactory tmf = TrustManagerFactory.getInstance(alg);

                   tks = KeyStore.getInstance("JKS");

                   try {
                     fname = truststore_path;
                     fis = new FileInputStream(truststore_path);

                     if (truststore_path.endsWith(".pem") || truststore_path.endsWith(".crt") || truststore_path.endsWith(".p7b"))
                       {
                         tks.load(null);
                         Collection certs = getCertificates(fis);
                         if (certs!=null)
                           {
                             int i=0;
                             for(Iterator it=certs.iterator(); it.hasNext();)
                             {
                               tks.setCertificateEntry("cert"+i, (java.security.cert.Certificate) it.next());
                               i++;
                             }
                           }
	      }
	    else
                       tks.load(fis, keys_pwd.toCharArray());

                   } finally {
                     if (fis!=null)
                       fis.close();
                   }


                   tmf.init(tks);
                   tma = tmf.getTrustManagers();
               } else {
                   tma = new TrustManager[]{tm};
               }

               if (keystore_path.length() > 0 && keystore_pass.length() > 0) {
                   String keys_file = (keystore_path != null) ? keystore_path : System.getProperty("user.home") + System.getProperty("file.separator");
                   String keys_pwd = (keystore_pass != null) ? keystore_pass : "";

                   fname = keys_file;
                   km = new KeyManager[]{new VirtX509KeyManager(cert_alias, keys_file, keys_pwd, tks)};
	      }

               ssl_ctx.init(km, tma, new SecureRandom());

               socket = ((SSLSocketFactory) ssl_ctx.getSocketFactory()).createSocket(host, port);
	    ((SSLSocket)socket).startHandshake();

	  }
	else
	 socket = new Socket(host,port);

	 if (timeout > 0)
	   socket.setSoTimeout(timeout);
	 socket.setTcpNoDelay(true);
         socket.setReceiveBufferSize(recvbs);
         socket.setSendBufferSize(sendbs);

         // Get streams corresponding to the socket
         in = new VirtuosoInputStream(this,socket, recvbs);
	 out = new VirtuosoOutputStream(this,socket, sendbs);
         // RPC caller identification
	 synchronized (this)
	   {
	     Object [] caller_id_args = new Object[1];
	     caller_id_args[0] = null;
	     VirtuosoFuture future = getFuture(VirtuosoFuture.callerid,caller_id_args, timeout);
	     openlink.util.Vector result_future = (openlink.util.Vector)future.nextResult().firstElement();
	     peer_name = (String)(result_future.elementAt(1));

	     if (result_future.size() > 2)
	       {
		 openlink.util.Vector caller_id_opts = (openlink.util.Vector)result_future.elementAt(2);
		 //System.err.println ("caller_id_opts is " + caller_id_opts.toString());
		 int pwd_clear_code = (int) cdef_param (caller_id_opts, "SQL_ENCRYPTION_ON_PASSWORD", -1);
		 switch (pwd_clear_code)
		   {
		     case 1: pwdclear = "cleartext"; break;
		     case 2: pwdclear = "encrypt"; break;
		     case 0: pwdclear = "digest"; break;
		   }
	       }
	     // Remove the future reference
	     removeFuture(future);
	     // RPC login
	     Object[] args = new Object[4];
	     args[0] = user;
	     //System.err.println ("5PwdClear is " + pwdclear);
	     if (pwdclear != null && pwdclear.equals ("cleartext"))
	       {
		 //System.err.println ("1");
		 args[1] = password;
	       }
	     else if (pwdclear != null && pwdclear.equals ("encrypt"))
	       {
		 //System.err.println ("2");
		 args[1] = MD5.pwd_magic_encrypt (user, password);
	       }
	     else
	       {
		 //System.err.println ("def");
		 args[1] = MD5.md5_digest (user, password, peer_name);
	       }
	     //System.err.println ("pass is " + args[1]);


	     args[2] = VirtuosoTypes.version;
	     args[3] = new openlink.util.Vector (fill_login_info_array ());
	     future = getFuture(VirtuosoFuture.scon,args, this.timeout);
	     result_future = (openlink.util.Vector)future.nextResult();
	     // Check if it is a login answer
	     if(!(result_future.firstElement() instanceof Short))
	       {
		 result_future = (openlink.util.Vector)result_future.firstElement();
		 switch(((Number)result_future.firstElement()).shortValue())
		   {
		     case VirtuosoTypes.QA_LOGIN:
			 // Set some values
			 qualifier = (String)result_future.elementAt(1);
			 version = (String)result_future.elementAt(2);
                         int con_db_gen = Integer.parseInt (version.substring(6));
                         if (con_db_gen < 2303)
	                   {
			     throw new VirtuosoException (
			       "Old server version", VirtuosoException.MISCERROR);
	                   }

			 _case = ((Number)result_future.elementAt(3)).intValue();
			 if (result_future.size() > 3)
			   client_defaults = (openlink.util.Vector)(result_future.elementAt (4));
			 else
			   client_defaults = null;
			 Object obj = null;
			 if (result_future.size() > 4)
			   obj = result_future.elementAt (5);
			 if (obj instanceof openlink.util.Vector)
			   {
			     client_charset = (openlink.util.Vector)obj;
			     String table = (String)client_charset.elementAt (1);
			     client_charset_hash = new Hashtable<Character,Byte> (256);
			     for (int i = 0; i < 255; i++)
			       {
				 if (i < table.length())
				   {
				     //System.err.println ("Mapping1 " + ((int)table.charAt(i)) + "=" + (i + 1));
				     client_charset_hash.put (
					 new Character (table.charAt(i)),
					 new Byte ((byte) (i + 1)));
				   }
				 else
				   {
				     //System.err.println ("Mapping2 " + (i + 1) + "=" + (i + 1));
				     client_charset_hash.put (
					 new Character ((char) (i + 1)),
					 new Byte ((byte) (i + 1)));
				   }
			       }
			   }
			 else
			   client_charset = null;
			 //System.err.println ("LOGIN RPC:");
			 //System.err.println ("qualifier: " + qualifier);
			 //System.err.println ("version: " + version);
			 //System.err.println ("case: " + _case);
			 //System.err.print ("client_defaults: ");
			 //System.err.println (client_defaults.toString());
			 //System.err.print ("client_charset: ");
			 //if (client_charset != null)
			 //  System.err.println (client_charset.elementAt(0).toString());
			 //else
			 //  System.err.println ("<NULL>");

			 if (timeout <= 0) {
			   timeout = (int) (cdef_param (client_defaults, "SQL_QUERY_TIMEOUT", timeout_def));
			   //System.err.println ("timeout = " + timeout);
			 }
                         if (timeout > 0)
			   socket.setSoTimeout(timeout);

			 if (txn_timeout <= 0) {
			   txn_timeout = (int) (cdef_param (client_defaults, "SQL_TXN_TIMEOUT", txn_timeout * 1000)/1000);
			   //System.err.println ("txn timeout = " + txn_timeout);
			 }

			 trxisolation = (int) cdef_param (client_defaults, "SQL_TXN_ISOLATION", trxisolation);
			 //System.err.println ("txn isolation = " + trxisolation);

			 utf8_execs = cdef_param (client_defaults, "SQL_UTF8_EXECS", 0) != 0;
			 //System.err.println ("utf8_execs = " + utf8_execs);
			 if (!utf8_execs && cdef_param (client_defaults, "SQL_NO_CHAR_C_ESCAPE", 0) != 0)
			   throw new VirtuosoException (
			       "Not using UTF-8 encoding of SQL statements, " +
			       "but processing character escapes also disabled",
			       VirtuosoException.MISCERROR);
			 //System.err.println ("version=[" + version + " ver=" + version.substring (6, 10));
			 //if ((new Integer (version.substring (6, 10))).intValue() > 2143)
			 //  utf8_execs = true;

			 timezoneless_datetimes = (int) cdef_param (client_defaults, "SQL_TIMEZONELESS_DATETIMES", 0);
			 //System.err.println ("timezoneless_datetimes = " + timezoneless_datetimes);

			 break;
		     case VirtuosoTypes.QA_ERROR:
			 // Remove the future reference
			 removeFuture(future);
			 // Throw an exception
			 throw new VirtuosoException((String)result_future.elementAt(1) + " " + (String)result_future.elementAt(2),VirtuosoException.NOLICENCE);
		     default:
			 // Remove the future reference
			 removeFuture(future);
			 // Throw an exception
			 throw new VirtuosoException(result_future.toString(),VirtuosoException.UNKNOWN);
		   }
		 ;
	       }
	     else
	       {
		 // Remove the future reference
		 removeFuture(future);
		 throw new VirtuosoException("Bad login.",VirtuosoException.BADLOGIN);
	       }
	     // Remove the future reference
	     removeFuture(future);
	   }
      }
      catch(NoClassDefFoundError e)
      {
         throw new VirtuosoException("Class not found: " + e.getMessage(),VirtuosoException.MISCERROR);
      }
      catch(FileNotFoundException e)
      {
         throw new VirtuosoException("Connection failed: "+ e.getMessage(),VirtuosoException.IOERROR);
      }
      catch(IOException e)
      {
         throw new VirtuosoException("Connection failed: ["+(fname!=null?fname:"")+"] "+e.getMessage(),VirtuosoException.IOERROR);
      }
      catch(ClassNotFoundException e)
      {
         throw new VirtuosoException("Class not found: " + e.getMessage(),VirtuosoException.MISCERROR);
      }
      catch(InstantiationException e)
      {
         throw new VirtuosoException("Class cannot be created: " + e.getMessage(),VirtuosoException.MISCERROR);
      }
      catch(IllegalAccessException e)
      {
         throw new VirtuosoException("Class cannot be accessed: " + e.getMessage(),VirtuosoException.MISCERROR);
      }
      catch(NoSuchAlgorithmException e)
      {
         throw new VirtuosoException("Encryption failed: " + e.getMessage(),VirtuosoException.MISCERROR);
      }
      catch(KeyStoreException e)
      {
         throw new VirtuosoException("Encryption failed: " + e.getMessage(),VirtuosoException.MISCERROR);
      }
      catch(KeyManagementException e)
      {
         throw new VirtuosoException("Encryption failed: " + e.getMessage(),VirtuosoException.MISCERROR);
      }
      catch(CertificateException e)
      {
         throw new VirtuosoException("Encryption failed: " + e.getMessage(),VirtuosoException.MISCERROR);
      }
      catch(UnrecoverableKeyException e)
      {
         throw new VirtuosoException("Encryption failed: ["+(fname!=null?fname:"") +"]" + e.getMessage(),VirtuosoException.MISCERROR);
      }
   }

   /**
    * Send an object to be sent on the output stream.
    *
    * @param obj  The object to send.
    * @exception virtuoso.jdbc4.VirtuosoException An internal error occurred.
    */
   protected void write_object(Object obj) throws IOException, VirtuosoException
   {
     if (VirtuosoFuture.rpc_log != null)
       {
	     VirtuosoFuture.rpc_log.print ("  >> (conn " + hashCode() + ") OUT ");
	     VirtuosoFuture.rpc_log.println (obj != null ? obj.toString() : "<null>");
       }
    try {
        out.write_object(obj);
        out.flush();
    } catch (IOException ex) {
        if (pooled_connection != null) {
            VirtuosoException vex =
                new VirtuosoException(
                    "Connection failed: " + ex.getMessage(),
                    VirtuosoException.IOERROR);
            pooled_connection.sendErrorEvent(vex);
            throw vex;
        } else {
            throw ex;
        }
    } catch (VirtuosoException ex) {
        if (pooled_connection != null) {
            int code = ex.getErrorCode();
            if (code == VirtuosoException.DISCONNECTED
                || code == VirtuosoException.IOERROR) {
            	pooled_connection.sendErrorEvent(ex);
            }
        }
        throw ex;
    }
   }

   protected void write_bytes(byte [] bytes) throws IOException, VirtuosoException
   {
    try {
        for (int k = 0; k < bytes.length; k++)
            out.write(bytes[k]);
        out.flush();
    } catch (IOException ex) {
        if (pooled_connection != null) {
            VirtuosoException vex =
                new VirtuosoException(
                    "Connection failed: " + ex.getMessage(),
                    VirtuosoException.IOERROR);
            pooled_connection.sendErrorEvent(vex);
            throw vex;
        } else {
            throw ex;
        }
    }
   }

   /**
    * Start an RPC function call by sending a VirtuosoFuture request.
    *
    * @param rpcname	The name of the RPC function.
    * @param args		The array of arguments.
    * @return VirtuosoFuture	The future instance.
    * @exception java.io.IOException	An IO error occurred.
    * @exception virtuoso.jdbc4.VirtuosoException An internal error occurred.
    */
   protected VirtuosoFuture getFuture(String rpcname, Object[] args, int timeout)
       throws IOException, VirtuosoException
   {
     VirtuosoFuture fut = null;
     int this_req_no;
     if (futures == null)
       throw new VirtuosoException ("Activity on a closed connection", "IM001", VirtuosoException.SQLERROR);
     synchronized (futures)
       {
	 this_req_no = req_no;
	 req_no += 1;
       }
     // Create a VirtuosoFuture instance
     fut = new VirtuosoFuture(this,rpcname,args,this_req_no, timeout);
     // Set the request id and put it into the hash table
     futures.put(new Integer(this_req_no),fut);
     return fut;
   }

   protected void clearFutures()
   {
     if (futures != null)
        synchronized (futures)
        {
	  futures.clear();
        }
   }

   /**
    * Remove a future from the hashtable.
    *
    * @param fut  The future to remove.
    */
   protected void removeFuture(VirtuosoFuture fut)
   {
     if (futures != null)
       futures.remove(new Integer(fut.hashCode()));
   }

   /**
    * Method uses to read messages and dispatch them between their future owner.
    *
    * @return boolean	True if a message was dispatching.
    * @exception java.io.IOException	A stream error occurred.
    * @exception virtuoso.jdbc4.VirtuosoException An internal error occurred.
    */
   protected boolean read_request() throws IOException, VirtuosoException
   {
     if (futures == null)
       throw new VirtuosoException ("Activity on a closed connection", "IM001", VirtuosoException.SQLERROR);
     //System.out.println ("req start");
     Object _result;
     try {
        _result = in.read_object();
     } catch (IOException ex) {
        if (pooled_connection != null) {
            VirtuosoException vex =
                new VirtuosoException(
                    "Connection failed: " + ex.getMessage(),
                    VirtuosoException.IOERROR);
            pooled_connection.sendErrorEvent(vex);
            throw vex;
        } else {
            throw ex;
        }
     } catch (VirtuosoException ex) {
        if (pooled_connection != null) {
            int code = ex.getErrorCode();
            if (code == VirtuosoException.DISCONNECTED
                || code == VirtuosoException.IOERROR) {
                pooled_connection.sendErrorEvent(ex);
            }
        }
        throw ex;
     }
     //System.out.println ("req end");
     if (VirtuosoFuture.rpc_log != null)
       {
	     VirtuosoFuture.rpc_log.print ("  << (conn " + hashCode() + ") IN ");
	     VirtuosoFuture.rpc_log.println (_result != null ? _result.toString() : "<null>");
       }

     try
       {
	 openlink.util.Vector result = (openlink.util.Vector)_result;
	 Object tag = result.firstElement();

	 // Check the validity of the message
	 //if(!(tag instanceof Short)) return false;
	 if(((Short)tag).shortValue() != VirtuosoTypes.DA_FUTURE_ANSWER && ((Short)tag).shortValue() != VirtuosoTypes.DA_FUTURE_PARTIAL_ANSWER)
	   return false;
	 // Then put the message into the corresponding future queue
	 //System.out.println("---------------> read_reqest for "+((Number)result.elementAt(1)).intValue());
	 VirtuosoFuture fut = (VirtuosoFuture)futures.get(new Integer(((Number)result.elementAt(1)).intValue()));
	 if(fut == null)
	   return false;
	 fut.putResult(result.elementAt(2));
	 // Set the complete status
	 fut.complete(((Short)tag).shortValue() == VirtuosoTypes.DA_FUTURE_ANSWER);
	 return true;
       }
     catch (ClassCastException e)
       {
         if (VirtuosoFuture.rpc_log != null)
           {
                 VirtuosoFuture.rpc_log.println ("  **(conn " + hashCode() + ") **** runtime2 " +
                     e.getClass().getName() + " in read_request");
                 e.printStackTrace(VirtuosoFuture.rpc_log);
           }
         throw new Error (e.getClass().getName() + ":" + e.getMessage());
       }
   }

   /**
    * Method uses to get the url of this connection.
    *
    * @return String	The url.
    */
   protected String getURL()
   {
      return url;
   }

   /**
    * Method uses to get the user name of this connection.
    *
    * @return String	The user name.
    */
   protected String getUserName()
   {
      return user;
   }

   /**
    * Method uses to get the qualifier name of this connection.
    *
    * @return String	The qualifier name.
    */
   protected String getQualifierName()
   {
      return qualifier;
   }

   /**
    * Method uses to get the version of the database.
    *
    * @return String	The version number.
    */
   protected String getVersion()
   {
      return version;
   }

   protected int getVersionNum ()
     {
       try
	 {
	   return (new Integer (version.substring (6, 10))).intValue();
	 }
       catch (Exception e)
	 {
	   return 1619;
	 }
     }

   /**
    * Method uses to get the case.
    *
    * @return int The case.
    */
   protected int getCase()
   {
      return _case;
   }

   /**
    * Method uses to get the I/O timeout.
    *
    * @return int	the time out.
    */
   protected int getTimeout()
   {
      return timeout;
   }

   // --------------------------- JDBC 1.0 ------------------------------
   /**
    * Clears all the warnings reported on this Connection object.
    * Virtuoso does not generate warnings, so this function does nothing, but we
    * must declare it to be compliant with the JDBC API.
    *
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection#clearWarnings
    */
   public void clearWarnings() throws VirtuosoException
   {
       warning = null;
   }

   /**
    * Close the current connection previously established with Virtuoso DBMS.
    *
    * @exception virtuoso.jdbc4.VirtuosoException An error occurred during the connection.
    * @see java.sql.Connection#close
    */
   public void close() throws VirtuosoException
   {
      if (isClosed())
        return;

      try
      {
         synchronized(this) {
           // Try to close all about the connection : socket and streams.
           if(!in.isClosed())
           {
             in.close();
             in = null;
           }
           if(!out.isClosed())
           {
             out.close();
             out = null;
           }
           if(socket != null)
           {
             socket.close();
             socket = null;
           }
           pStatementCache.clear();
           // Clear some variables
           user = url = password = null;
           futures = null;
           pooled_connection = null;
           xa_connection = null;
         }
      }
      catch(IOException e)
      {
      }
   }

   /**
    * Makes all changes made since the previous
    * commit/rollback permanent and releases any database locks
    * currently held by the Connection. This method should be
    * used only when auto-commit mode has been disabled.
    *
    * @exception virtuoso.jdbc4.VirtuosoException An internal error occurred.
    * @see java.sql.Connection#commit
    */
   public synchronized void commit() throws VirtuosoException
   {
      if (global_transaction)
	throw new VirtuosoException("Cannot commit while in global transaction.", VirtuosoException.BADPARAM);
      try
      {
	// RPC transaction
	Object[] args = new Object[2];
	args[0] = new Long(VirtuosoTypes.SQL_COMMIT);
	args[1] = null;
	VirtuosoFuture fut = getFuture(VirtuosoFuture.transaction,args, this.timeout);
	openlink.util.Vector trsres = fut.nextResult();
	//System.err.println ("commit returned " + trsres.toString());
	Object _err = (trsres == null) ? null: ((openlink.util.Vector)trsres).firstElement();
	if (_err instanceof openlink.util.Vector)
	  {
	    openlink.util.Vector err = (openlink.util.Vector) _err;
	    throw new VirtuosoException ((String) (err.elementAt (2)),
		(String) (err.elementAt (1)), VirtuosoException.SQLERROR);
	  }
	// Remove the future reference
	removeFuture(fut);
      }
      catch(IOException e)
      {
         throw new VirtuosoException("Connection failed: " + e.getMessage(),VirtuosoException.IOERROR);
      }
   }

   /**
    * Creates a Statement object to send SQL statements to
    * the Virtuoso DBMS. SQL statements without parameters are normally
    * executed using Statement objects. If the same SQL statement
    * is executed many times, it is more efficient to use a PreparedStatement.
    * Result sets created using the returned Statement will have
    * forward-only type, and read-only concurrency, by default.
    *
    * @return Statement  A new Statement object.
    * @exception VirtuosoException  A database access error occurred.
    * @see java.sql.Connection#createStatement
    * @see virtuoso.jdbc4.VirtuosoStatement
    */
   public Statement createStatement() throws VirtuosoException
   {
      return createStatement(VirtuosoResultSet.TYPE_FORWARD_ONLY,VirtuosoResultSet.CONCUR_READ_ONLY);
   }

   /**
    * Returns the current auto-commit state.
    *
    * @return boolean   The current state of auto-commit mode.
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection#setAutoCommit
    */
   public boolean getAutoCommit() throws VirtuosoException
   {
      return auto_commit;
   }

   /**
    * Gets the metadata regarding this connection's database.
    * A Connection's database is able to provide information
    * describing its tables, its supported SQL grammar, its stored
    * procedures, the capabilities of this connection, and so on. This
    * information is made available through a DatabaseMetaData
    * object.
    *
    * @return a DatabaseMetaData object for this Connection
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection#getMetaData
    * @see virtuoso.jdbc4.VirtuosoDatabaseMetaData
    */
   public DatabaseMetaData getMetaData() throws VirtuosoException
   {
      return new VirtuosoDatabaseMetaData(this);
   }

   /**
    * Retrieves the first warning reported by calls on this Connection.
    * Subsequent Connection warnings will be chained to this
    * SQLWarning. Virtuoso does not generate warnings, so this function
    * returns always null.
    *
    * @return SQLWarning   The first SQLWarning or null (must be null for the moment)
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just implementation).
    * @see java.sql.Connection#getWarnings
    */
   public SQLWarning getWarnings() throws VirtuosoException
   {
      return warning;
   }

   /**
    * Attempts to change the transaction isolation level to the one given.
    * The constants defined in the interface <code>Connection</code>
    * are the possible transaction isolation levels.
    *
    * @param level one of the TRANSACTION_* isolation values with the
    * exception of TRANSACTION_NONE; some databases may not support
    * other values
    * @exception virtuoso.jdbc4.VirtuosoException An internal error occurred.
    * @see java.sql.Connection#setTransactionIsolation
    */
   public void setTransactionIsolation(int level) throws VirtuosoException
   {
      // Check and set parameters
      if(level == Connection.TRANSACTION_READ_UNCOMMITTED || level == Connection.TRANSACTION_READ_COMMITTED || level == Connection.TRANSACTION_REPEATABLE_READ || level == Connection.TRANSACTION_SERIALIZABLE)
         trxisolation = level;
      else
         throw new VirtuosoException("Bad parameters.",VirtuosoException.BADPARAM);
   }

   /**
    * Gets this Connection's current transaction isolation level.
    *
    * @return the current TRANSACTION_* mode value
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection#getTransactionIsolation
    */
   public int getTransactionIsolation() throws VirtuosoException
   {
      return trxisolation;
   }

   /**
    * Checks if the connection is closed.
    *
    * @return boolean   True if the connection is closed, false if it is still open.
    */
   public boolean isClosed()
   {
      return
         (socket == null)
         || (in == null || in.isClosed())
         || (out == null || out.isClosed())
         ;
   }

   /**
    * Creates a CallableStatement object to call database stored procedures.
    * Result sets created using the returned CallableStatement will have
    * forward-only type and read-only concurrency, by default.
    *
    * @param sql a SQL statement that may contain one or more '?'
    * parameter placeholders. Typically this  statement is a JDBC
    * function call escape string.
    * @return a new CallableStatement object containing the
    * pre-compiled SQL statement
    * @exception virtuoso.jdbc4.VirtuosoException An internal error occurred.
    * @see java.sql.Connection#prepareCall
    * @see virtuoso.jdbc4.VirtuosoCallableStatement
    */
   public CallableStatement prepareCall(String sql) throws VirtuosoException
   {
      return prepareCall(sql,VirtuosoResultSet.TYPE_FORWARD_ONLY,VirtuosoResultSet.CONCUR_READ_ONLY);
   }

   /**
    * Creates a PreparedStatement object to send parameterized SQL statements to the database.
    * Result sets created using the returned PreparedStatement will have
    * forward-only type and read-only concurrency, by default.
    *
    * @param sql a SQL statement that may contain one or more '?' IN parameter placeholders
    * @return PreparedStatement  A new PreparedStatement object.
    * @exception VirtuosoException  A database access error occurs.
    * @see java.sql.Connection#prepareStatement
    * @see virtuoso.jdbc4.VirtuosoPreparedStatement
    */
   public PreparedStatement prepareStatement(String sql) throws VirtuosoException
   {
      return prepareStatement(sql,VirtuosoResultSet.TYPE_FORWARD_ONLY,VirtuosoResultSet.CONCUR_READ_ONLY);
   }

   /**
    * Drops all changes made since the previous commit/rollback and releases
    * any database locks currently held by this Connection.
    * This method should be used only when auto-commit has been disabled.
    *
    * @exception virtuoso.jdbc4.VirtuosoException An internal error occurred.
    * @see java.sql.Connection#rollback
    */
   public synchronized void rollback() throws VirtuosoException
   {
      if (global_transaction)
	throw new VirtuosoException("Cannot rollback while in global transaction.", VirtuosoException.BADPARAM);
      try
      {
         // RPC transaction
         Object[] args = new Object[2];
         args[0] = new Long(VirtuosoTypes.SQL_ROLLBACK);
         args[1] = null;
         VirtuosoFuture fut = getFuture(VirtuosoFuture.transaction,args, this.timeout);
         openlink.util.Vector trsres = fut.nextResult();
	 //System.err.println ("rollback returned " + trsres.toString());
	 Object _err = (trsres == null) ? null: ((openlink.util.Vector)trsres).firstElement();
	 if (_err instanceof openlink.util.Vector)
	   {
	     openlink.util.Vector err = (openlink.util.Vector) _err;
	     throw new VirtuosoException ((String) (err.elementAt (2)),
		 (String) (err.elementAt (1)), VirtuosoException.SQLERROR);
	   }
         // Remove the future reference
         if(fut!=null) removeFuture(fut);
      }
      catch(IOException e)
      {
         throw new VirtuosoException("Connection failed: " + e.getMessage(),VirtuosoException.IOERROR);
      }
   }

   /**
    * Sets this connection's auto-commit mode.
    * By default, new connections are in auto-commit mode.
    *
    * @param autoCommit True enables auto-commit; false disables it.
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection#setAutoCommit
    */
   public void setAutoCommit(boolean autoCommit) throws VirtuosoException
   {
      if (autoCommit && global_transaction)
	throw new VirtuosoException("Cannot set autocommit mode while in global transaction.", VirtuosoException.BADPARAM);
      this.auto_commit = autoCommit;
   }

   // --------------------------- JDBC 2.0 ------------------------------
   /**
    * Creates a Statement object that will generate ResultSet
    * objects with the given type and concurrency.
    * This method is the same as the createStatement method above, but it
    * allows the default result set type and result set concurrency type
    * to be overridden.
    *
    * @param resultSetType A result set type; see VirtuosoResultSet.TYPE_XXX
    * @param resultSetConcurrency   A concurrency type; see VirtuosoResultSet.CONCUR_XXX
    * @return Statement  A new Statement object.
    * @exception VirtuosoException  A database access error occurs.
    * @see java.Connection#createStatement
    * @see virtuoso.jdbc4.VirtuosoStatement
    */
   public Statement createStatement(int resultSetType, int resultSetConcurrency) throws VirtuosoException
   {
      return new VirtuosoStatement(this,resultSetType,resultSetConcurrency);
   }

   /**
    * Creates a CallableStatement object that will generate
    * ResultSet objects with the given type and concurrency.
    * This method is the same as the createStatement method above, but it
    * allows the default result set type and result set concurrency type
    * to be overridden.
    *
    * @param resultSetType a result set type; see VirtuosoResultSet.TYPE_XXX
    * @param resultSetConcurrency a concurrency type; see VirtuosoResultSet.CONCUR_XXX
    * @return a new CallableStatement object containing the
    * pre-compiled SQL statement
    * @exception VirtuosoException  A database access error occurs.
    * @see java.sql.Connection#prepareCall
    * @see virtuoso.jdbc4.VirtuosoCallableStatement
    */
   public CallableStatement prepareCall(String sql, int resultSetType, int resultSetConcurrency) throws VirtuosoException
   {
      return new VirtuosoCallableStatement(this,sql,resultSetType,resultSetConcurrency);
   }

   /**
    * Creates a PreparedStatement object that will generate
    * ResultSet objects with the given type and concurrency.
    * This method is the same as the prepareStatement method
    * above, but it allows the default result set
    * type and result set concurrency type to be overridden.
    *
    * @param sql a SQL statement that may contain one or more '?' IN
    *            parameter placeholders
    * @param resultSetType a result set type; see VirtuosoResultSet.TYPE_XXX
    * @param resultSetConcurrency a concurrency type; see VirtuosoResultSet.CONCUR_XXX
    * @return a new CallableStatement object containing the
    * pre-compiled SQL statement
    * @exception VirtuosoException  A database access error occurs.
    * @see java.sql.Connection#prepareCall
    * @see virtuoso.jdbc4.VirtuosoPreparedStatement
    */
   public PreparedStatement prepareStatement(String sql, int resultSetType, int resultSetConcurrency) throws VirtuosoException
   {
     if (useCachePrepStatements) {
       VirtuosoPreparedStatement ps = null;
       synchronized(pStatementCache) {
         ps = pStatementCache.remove(""+resultSetType+"#"
                                       +resultSetConcurrency+"#"
        			       +sql);
         if (ps != null) {
           ps.setClosed(false);
           ps.clearParameters();
         } else {
           ps = new VirtuosoPreparedStatement(this, sql, resultSetType,
           		resultSetConcurrency);
           ps.isCached = true;
         }
       }
       return ps;

     }
     else
     {
       return new VirtuosoPreparedStatement(this,sql,resultSetType,resultSetConcurrency);
     }
   }

   // --------------------------- Object ------------------------------
   /**
    * Returns a hash code value for the object.
    *
    * @return int	The hash code value.
    */
   public int hashCode()
   {
      return con_no;
   }

   /**
    * Method runs when the garbage collector want to erase the object
    */
   public void finalize() throws Throwable
   {
      close();
   }

   // --------------------------- Not yet ------------------------------
   /**
    * Check if the connection is in read-only mode.
    *
    * @return boolean   True if connection is read-only and false otherwise.
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection#isReadOnly
    */
   public boolean isReadOnly() throws VirtuosoException
   {
      return readOnly;
   }

   /**
    * Puts this connection in read-only mode.
    *
    * @param readOnly   True enables read-only mode; false disables it.
    * @exception virtuoso.jdbc4.VirtuosoException An internal error occurred.
    * @see java.sql.Connection#setReadOnly
    */
   public void setReadOnly(boolean readOnly) throws VirtuosoException
   {
     this.readOnly = readOnly;
   }

   /**
    * Converts the given SQL statement into the system's native SQL grammar.
    * A driver may convert the JDBC sql grammar into its system's
    * native SQL grammar prior to sending it; this method returns the
    * native form of the statement that the driver would have sent.
    *
    * @param sql a SQL statement that may contain one or more '?'
    * parameter placeholders
    * @return the native form of this statement
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection#nativeSQL
    */
   public String nativeSQL(String sql) throws VirtuosoException
   {
      return "";
   }

   /**
    * Sets a catalog name in order to select
    * a subspace of this Connection's database in which to work.
    * If the driver does not support catalogs, it will
    * silently ignore this request.
    *
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection#setCatalog
    */
   public void setCatalog(String catalog) throws VirtuosoException
   {
      VirtuosoStatement st = null;
      if (catalog!=null) {
        try {
          st = new VirtuosoStatement(this);
          st.executeQuery("use "+catalog);
          qualifier = catalog;
        } finally {
          if (st!=null) {
            try {
              st.close();
            } catch (Exception e) {}
          }
        }
      }
   }

   /**
    * Returns the Connection's current catalog name.
    *
    * @return the current catalog name or null
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection#getCatalog
    */
   public String getCatalog() throws VirtuosoException
   {
      return qualifier;
   }

   /**
    * Gets the type map object associated with this connection.
    * Unless the application has added an entry to the type map,
    * the map returned will be empty.
    *
    * @return the <code>java.util.Map</code> object associated
    *         with this <code>Connection</code> object
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just implementation).
    * @see java.sql.Connection#getTypeMap
    */
   public java.util.Map<String, Class<?>> getTypeMap() throws VirtuosoException
   {
      return null;
   }

   /**
    * Installs the given type map as the type map for
    * this connection.  The type map will be used for the
    * custom mapping of SQL structured types and distinct types.
    *
    * @param the <code>java.util.Map</code> object to install
    *        as the replacement for this <code>Connection</code>
    *        object's default type map
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just implementation).
    * @see java.sql.Connection#setTypeMap
    */
   public void setTypeMap(java.util.Map<String,Class<?>> map) throws VirtuosoException
   {
   }

   protected void setSocketTimeout (int timeout) throws VirtuosoException
     {
      try
	{
	  //System.err.println ("timeout = " + timeout);
	  if (timeout != -1)
	    socket.setSoTimeout (timeout);
	}
      catch (java.net.SocketException e)
	{
	  throw new VirtuosoException ("Unable to set socket timeout : " + e.getMessage(),
	      "S1000", VirtuosoException.MISCERROR);
	}
     }

   protected VirtuosoExplicitString escapeSQL (String sql) throws VirtuosoException
     {
       VirtuosoExplicitString sql1;
       //System.out.println ("in escapeSQL SQL charset = " + this.charset);
       if (this.charset != null)
	 {
	   //System.out.println ("in escapeSQL SQL len = " + sql.length());
	   //System.out.println ("in escapeSQL SQL aref(15) = " + ((int)sql.charAt(15)));
	   byte [] bytes = charsetBytes(sql);
	   sql1 = new VirtuosoExplicitString (bytes, VirtuosoTypes.DV_STRING);
	   return sql1;
	 }
       if (this.charset_utf8)
       {
	  sql1 = new VirtuosoExplicitString (sql, VirtuosoTypes.DV_STRING, this);
	  return sql1;
       }
       if (this.utf8_execs)
	 {
	   /* use UTF8 encodings */
	   try
	     {
	       byte [] bytes = (new String ("\n--utf8_execs=yes\n" + sql)).getBytes("UTF8");
	       sql1 = new VirtuosoExplicitString (bytes, VirtuosoTypes.DV_STRING);
	     }
	   catch (java.io.UnsupportedEncodingException e)
	     {
	       sql1 = new VirtuosoExplicitString ("\n--utf8_execs=yes\n" + sql,
		   VirtuosoTypes.DV_STRING, this);
	     }
	 }
       else
	 {
           /* use \x encoding */
	   sql1 = new VirtuosoExplicitString ("", VirtuosoTypes.DV_STRING, null);
	   sql1.cli_wide_to_escaped (sql, this.client_charset_hash);
	 }
       return sql1;
     }

   protected VirtuosoExplicitString escapeSQLString (String sql) throws VirtuosoException
     {
       VirtuosoExplicitString sql1;
       //System.out.println ("in escapeSQLString SQL charset = " + this.charset);
       if (this.charset != null)
	 {
	   byte [] bytes = charsetBytes(sql);
	   sql1 = new VirtuosoExplicitString (bytes,  VirtuosoTypes.DV_STRING);
	   return sql1;
	 }
       if (this.utf8_execs)
	 {
	   /* use UTF8 encodings */
	   try
	     {
	       byte [] bytes = sql.getBytes("UTF8");
	       sql1 = new VirtuosoExplicitString (bytes, VirtuosoTypes.DV_STRING);
	     }
	   catch (java.io.UnsupportedEncodingException e)
	     {
	       sql1 = new VirtuosoExplicitString (sql,
		   VirtuosoTypes.DV_STRING, this);
	     }
	 }
       else
	 {
           /* use \x encoding */
	   sql1 = new VirtuosoExplicitString ("", VirtuosoTypes.DV_STRING, null);
	   sql1.cli_wide_to_escaped (sql, this.client_charset_hash);
	 }
       return sql1;
     }

   protected byte[] charsetBytes1(String source, String from, String to) throws VirtuosoException
    {
       byte ans[] = new byte[0];
       //System.err.println ("charsetBytes1(" + from + " , " + to);
       //System.err.println ("charsetBytes1 src len=" + source.length());
       ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream( source.length() );
       try
	 {
	   OutputStreamWriter outputWriter = new OutputStreamWriter(byteArrayOutputStream, from);
	   outputWriter.write(source, 0, source.length());
	   outputWriter.flush();
	   byte[] bytes = byteArrayOutputStream.toByteArray();
	   ans = bytes;
	   //System.err.println ("charsetBytes1 ret len=" + ans.length);
	   /*
	      BufferedReader bufferedReader =
	      (new BufferedReader( new InputStreamReader( new ByteArrayInputStream(bytes), "8859_1")));
	      ans = bufferedReader.readLine();
	    */
	 }
       catch (Exception e)
	 {
	   throw new VirtuosoException (
	       "InternationalizationHelper: UnsupportedEncodingException: " + e,
	       VirtuosoException.CASTERROR);
	 }
       return ans;
    }

   protected byte[] charsetBytes(String source) throws VirtuosoException
     {
       //System.out.println ("In charsetBytes len=" + source.length() + "aref(0)" + ((int)source.charAt (0)));
       if (source == null)
	 return null;
       return charsetBytes1(source, this.charset, "8859_1");
     }

   protected String uncharsetBytes(String source) throws VirtuosoException
     {
       if (source == null)
	 return null;
       //System.err.println ("uncharsetBytes src len=" + source.length());
       ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream( source.length() );
       try
	 {
	   OutputStreamWriter outputWriter = new OutputStreamWriter(byteArrayOutputStream, "8859_1");
	   outputWriter.write(source, 0, source.length());
	   outputWriter.flush();
	   byte[] bytes = byteArrayOutputStream.toByteArray();
	   BufferedReader bufferedReader =
	       (new BufferedReader( new InputStreamReader( new ByteArrayInputStream(bytes), this.charset)));
	   StringBuffer buf = new StringBuffer();
	   char cbuf [] = new char[4096];
	   int read;
	   while (0 < (read = bufferedReader.read (cbuf)))
	     buf.append (cbuf, 0, read);
	   //System.err.println ("uncharsetBytes1 ret len=" + buf.length());
	   return buf.toString();
	 }
       catch (Exception e)
	 {
	   throw new VirtuosoException (
	       "InternationalizationHelper: UnsupportedEncodingException: " + e,
	       VirtuosoException.CASTERROR);
	 }
     }

   /* JDK 1.4 functions */

   /**
    * supports only <code>ResultSet.HOLD_CURSORS_OVER_COMMIT</code> for now
    * @exception virtuoso.jdbc4.VirtuosoException if the holdability is not the supported one
    */
   protected void checkHoldability (int holdability) throws SQLException
     {
       if (holdability == ResultSet.HOLD_CURSORS_OVER_COMMIT)
         throw new VirtuosoException ("Unable to hold cursors over commit", "IM001",
 	   VirtuosoException.NOTIMPLEMENTED);
       else if (holdability != ResultSet.CLOSE_CURSORS_AT_COMMIT)
         throw new VirtuosoException ("Invalid holdability value", "22023",
 	   VirtuosoException.BADPARAM);
     }

   /**
    * calls checkHoldability
    * @see java.sql.Connection#checkHoldability
    */
   public void setHoldability (int holdability) throws SQLException
     {
       checkHoldability (holdability);
     }

   public int getHoldability() throws SQLException
     {
       return ResultSet.CLOSE_CURSORS_AT_COMMIT;
     }

   /**
    * @exception virtuoso.jdbc4.VirtuosoException allways thrown : savepoints not supported
    */
   public Savepoint setSavepoint() throws SQLException
     {
       throw new VirtuosoException ("Savepoints not supported", "IM001",
         VirtuosoException.NOTIMPLEMENTED);
     }

   /**
    * @exception virtuoso.jdbc4.VirtuosoException allways thrown : savepoints not supported
    */
   public Savepoint setSavepoint(String name) throws SQLException
     {
       throw new VirtuosoException ("Savepoints not supported", "IM001",
         VirtuosoException.NOTIMPLEMENTED);
     }

   /**
    * @exception virtuoso.jdbc4.VirtuosoException allways thrown : savepoints not supported
    */
   public void rollback(Savepoint savepoint) throws SQLException
     {
       throw new VirtuosoException ("Savepoints not supported", "IM001",
         VirtuosoException.NOTIMPLEMENTED);
     }

   /**
    * @exception virtuoso.jdbc4.VirtuosoException allways thrown : savepoints not supported
    */
   public void releaseSavepoint(Savepoint savepoint) throws SQLException
     {
       throw new VirtuosoException ("Savepoints not supported", "IM001",
         VirtuosoException.NOTIMPLEMENTED);
     }

   /**
    * calls checkHoldability and then normal createStatement
    * @see java.sql.Connection#checkHoldability
    */
   public Statement createStatement(int resultSetType,
       int resultSetConcurrency,
       int resultSetHoldability) throws SQLException
     {
       checkHoldability (resultSetHoldability);
       return createStatement (resultSetType, resultSetConcurrency);
     }

   /**
    * calls checkHoldability and then normal prepareStatement
    * @see java.sql.Connection#checkHoldability
    */
   public PreparedStatement prepareStatement(String sql,
       int resultSetType,
       int resultSetConcurrency,
       int resultSetHoldability) throws SQLException
     {
       checkHoldability (resultSetHoldability);
       return prepareStatement (sql, resultSetType, resultSetConcurrency);
     }

   /**
    * calls checkHoldability and then normal prepareCall
    * @see java.sql.Connection#checkHoldability
    */
   public CallableStatement prepareCall(String sql,
       int resultSetType,
       int resultSetConcurrency,
       int resultSetHoldability) throws SQLException
     {
       checkHoldability (resultSetHoldability);
       return prepareCall (sql, resultSetType, resultSetConcurrency);
     }

   /**
    * <code>autoGeneratedKeys</code> ignored
    */
   public PreparedStatement prepareStatement(String sql,
       int autoGeneratedKeys) throws SQLException
     {
       return prepareStatement (sql);
     }

   /**
    * <code>columnIndexes ignored</code> ignored
    */
   public PreparedStatement prepareStatement(String sql,
       int[] columnIndexes) throws SQLException
     {
       return prepareStatement (sql);
     }

   /**
    * <code>columnNames ignored</code> ignored
    */
   public PreparedStatement prepareStatement(String sql,
       String[] columnNames) throws SQLException
     {
       return prepareStatement (sql);
     }

   synchronized void checkClosed() throws SQLException
   {
        if (isClosed())
            throw new VirtuosoException("The connection is already closed.",VirtuosoException.DISCONNECTED);
    }

    //------------------------- JDBC 4.0 -----------------------------------
    /**
     * Constructs an object that implements the <code>Clob</code> interface. The object
     * returned initially contains no data.  The <code>setAsciiStream</code>,
     * <code>setCharacterStream</code> and <code>setString</code> methods of
     * the <code>Clob</code> interface may be used to add data to the <code>Clob</code>.
     * @return An object that implements the <code>Clob</code> interface
     * @throws SQLException if an object that implements the
     * <code>Clob</code> interface cannot be constructed, this method is
     * called on a closed connection or a database access error occurs.
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this data type
     *
     * @since 1.6
     */
  public Clob createClob() throws SQLException
  {
    return new VirtuosoBlob();
  }

    /**
     * Constructs an object that implements the <code>Blob</code> interface. The object
     * returned initially contains no data.  The <code>setBinaryStream</code> and
     * <code>setBytes</code> methods of the <code>Blob</code> interface may be used to add data to
     * the <code>Blob</code>.
     * @return  An object that implements the <code>Blob</code> interface
     * @throws SQLException if an object that implements the
     * <code>Blob</code> interface cannot be constructed, this method is
     * called on a closed connection or a database access error occurs.
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this data type
     *
     * @since 1.6
     */
  public Blob createBlob() throws SQLException
  {
    return new VirtuosoBlob();
  }

    /**
     * Constructs an object that implements the <code>NClob</code> interface. The object
     * returned initially contains no data.  The <code>setAsciiStream</code>,
     * <code>setCharacterStream</code> and <code>setString</code> methods of the <code>NClob</code> interface may
     * be used to add data to the <code>NClob</code>.
     * @return An object that implements the <code>NClob</code> interface
     * @throws SQLException if an object that implements the
     * <code>NClob</code> interface cannot be constructed, this method is
     * called on a closed connection or a database access error occurs.
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this data type
     *
     * @since 1.6
     */
  public NClob createNClob() throws SQLException
  {
    return new VirtuosoBlob();
  }

    /**
     * Constructs an object that implements the <code>SQLXML</code> interface. The object
     * returned initially contains no data. The <code>createXmlStreamWriter</code> object and
     * <code>setString</code> method of the <code>SQLXML</code> interface may be used to add data to the <code>SQLXML</code>
     * object.
     * @return An object that implements the <code>SQLXML</code> interface
     * @throws SQLException if an object that implements the <code>SQLXML</code> interface cannot
     * be constructed, this method is
     * called on a closed connection or a database access error occurs.
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this data type
     * @since 1.6
     */
  public SQLXML createSQLXML() throws SQLException
  {
     throw new VirtuosoFNSException ("createSQLXML()  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

        /**
	 * Returns true if the connection has not been closed and is still valid.
	 * The driver shall submit a query on the connection or use some other
	 * mechanism that positively verifies the connection is still valid when
	 * this method is called.
	 * <p>
	 * The query submitted by the driver to validate the connection shall be
	 * executed in the context of the current transaction.
	 *
	 * @param timeout -		The time in seconds to wait for the database operation
	 * 						used to validate the connection to complete.  If
	 * 						the timeout period expires before the operation
	 * 						completes, this method returns false.  A value of
	 * 						0 indicates a timeout is not applied to the
	 * 						database operation.
	 * <p>
	 * @return true if the connection is valid, false otherwise
         * @exception SQLException if the value supplied for <code>timeout</code>
         * is less then 0
         * @since 1.6
	 * <p>
	 * @see java.sql.DatabaseMetaData#getClientInfoProperties
	 */
  public boolean isValid(int _timeout) throws SQLException
  {
    if (isClosed())
      return false;

    boolean isLost = true;
    try {
      try {
        isLost = isConnectionLost(_timeout);
      } catch (Throwable t) {
        try {
          abortInternal();
        } catch (Throwable ignoreThrown) {
          // we are dead now anyway
        }

        return false;
      }
    } catch (Throwable t) {
      return false;
    }

    return !isLost;
  }

	/**
	 * Sets the value of the client info property specified by name to the
	 * value specified by value.
	 * <p>
	 * Applications may use the <code>DatabaseMetaData.getClientInfoProperties</code>
	 * method to determine the client info properties supported by the driver
	 * and the maximum length that may be specified for each property.
	 * <p>
	 * The driver stores the value specified in a suitable location in the
	 * database.  For example in a special register, session parameter, or
	 * system table column.  For efficiency the driver may defer setting the
	 * value in the database until the next time a statement is executed or
	 * prepared.  Other than storing the client information in the appropriate
	 * place in the database, these methods shall not alter the behavior of
	 * the connection in anyway.  The values supplied to these methods are
	 * used for accounting, diagnostics and debugging purposes only.
	 * <p>
	 * The driver shall generate a warning if the client info name specified
	 * is not recognized by the driver.
	 * <p>
	 * If the value specified to this method is greater than the maximum
	 * length for the property the driver may either truncate the value and
	 * generate a warning or generate a <code>SQLClientInfoException</code>.  If the driver
	 * generates a <code>SQLClientInfoException</code>, the value specified was not set on the
	 * connection.
	 * <p>
	 * The following are standard client info properties.  Drivers are not
	 * required to support these properties however if the driver supports a
	 * client info property that can be described by one of the standard
	 * properties, the standard property name should be used.
	 * <p>
	 * <ul>
	 * <li>ApplicationName	-	The name of the application currently utilizing
	 * 				the connection</li>
	 * <li>ClientUser	-	The name of the user that the application using
	 * 				the connection is performing work for.  This may
	 * 				not be the same as the user name that was used
	 * 				in establishing the connection.</li>
	 * <li>ClientHostname	-	The hostname of the computer the application
	 * 				using the connection is running on.</li>
	 * </ul>
	 * <p>
	 * @param name		The name of the client info property to set
	 * @param value		The value to set the client info property to.  If the
	 * 			value is null, the current value of the specified
	 * 			property is cleared.
	 * <p>
	 * @throws	SQLClientInfoException if the database server returns an error while
	 * 		setting the client info value on the database server or this method
         * is called on a closed connection
	 * <p>
	 * @since 1.6
	 */
  public void setClientInfo(String name, String value) throws SQLClientInfoException
  {
    Map<String, ClientInfoStatus> fail = new HashMap<String, ClientInfoStatus>();
    fail.put(name, ClientInfoStatus.REASON_UNKNOWN_PROPERTY);
    throw new SQLClientInfoException("ClientInfo property not supported", fail);
  }

   /**
     * Sets the value of the connection's client info properties.  The
     * <code>Properties</code> object contains the names and values of the client info
     * properties to be set.  The set of client info properties contained in
     * the properties list replaces the current set of client info properties
     * on the connection.  If a property that is currently set on the
     * connection is not present in the properties list, that property is
     * cleared.  Specifying an empty properties list will clear all of the
     * properties on the connection.  See <code>setClientInfo (String, String)</code> for
     * more information.
     * <p>
     * If an error occurs in setting any of the client info properties, a
     * <code>SQLClientInfoException</code> is thrown. The <code>SQLClientInfoException</code>
     * contains information indicating which client info properties were not set.
     * The state of the client information is unknown because
     * some databases do not allow multiple client info properties to be set
     * atomically.  For those databases, one or more properties may have been
     * set before the error occurred.
     * <p>
     *
     * @param properties the list of client info properties to set
     * <p>
     * @see java.sql.Connection#setClientInfo(String, String) setClientInfo(String, String)
     * @since 1.6
     * <p>
     * @throws SQLClientInfoException if the database server returns an error while
     * 		setting the clientInfo values on the database server or this method
     * is called on a closed connection
     * <p>
     */
  public void setClientInfo(Properties properties) throws SQLClientInfoException
  {
    if (properties == null || properties.size() == 0)
      return;

    Map<String, ClientInfoStatus> fail = new HashMap<String, ClientInfoStatus>();

    Iterator<String> i = properties.stringPropertyNames().iterator();
    while (i.hasNext()) {
      fail.put(i.next(), ClientInfoStatus.REASON_UNKNOWN_PROPERTY);
    }
    throw new SQLClientInfoException("ClientInfo property not supported", fail);
  }

	/**
	 * Returns the value of the client info property specified by name.  This
	 * method may return null if the specified client info property has not
	 * been set and does not have a default value.  This method will also
	 * return null if the specified client info property name is not supported
	 * by the driver.
	 * <p>
	 * Applications may use the <code>DatabaseMetaData.getClientInfoProperties</code>
	 * method to determine the client info properties supported by the driver.
	 * <p>
	 * @param name		The name of the client info property to retrieve
	 * <p>
	 * @return 			The value of the client info property specified
	 * <p>
	 * @throws SQLException		if the database server returns an error when
	 * 							fetching the client info value from the database
         *or this method is called on a closed connection
	 * <p>
	 * @since 1.6
	 * <p>
	 * @see java.sql.DatabaseMetaData#getClientInfoProperties
	 */
  public String getClientInfo(String name) throws SQLException
  {
    return null;
  }

	/**
	 * Returns a list containing the name and current value of each client info
	 * property supported by the driver.  The value of a client info property
	 * may be null if the property has not been set and does not have a
	 * default value.
	 * <p>
	 * @return	A <code>Properties</code> object that contains the name and current value of
	 * 			each of the client info properties supported by the driver.
	 * <p>
	 * @throws 	SQLException if the database server returns an error when
	 * 			fetching the client info values from the database
         * or this method is called on a closed connection
	 * <p>
	 * @since 1.6
	 */
  public Properties getClientInfo() throws SQLException
  {
    return null;
  }

/**
  * Factory method for creating Array objects.
  *<p>
  * <b>Note: </b>When <code>createArrayOf</code> is used to create an array object
  * that maps to a primitive data type, then it is implementation-defined
  * whether the <code>Array</code> object is an array of that primitive
  * data type or an array of <code>Object</code>.
  * <p>
  * <b>Note: </b>The JDBC driver is responsible for mapping the elements
  * <code>Object</code> array to the default JDBC SQL type defined in
  * java.sql.Types for the given class of <code>Object</code>. The default
  * mapping is specified in Appendix B of the JDBC specification.  If the
  * resulting JDBC type is not the appropriate type for the given typeName then
  * it is implementation defined whether an <code>SQLException</code> is
  * thrown or the driver supports the resulting conversion.
  *
  * @param typeName the SQL name of the type the elements of the array map to. The typeName is a
  * database-specific name which may be the name of a built-in type, a user-defined type or a standard  SQL type supported by this database. This
  *  is the value returned by <code>Array.getBaseTypeName</code>
  * @param elements the elements that populate the returned object
  * @return an Array object whose elements map to the specified SQL type
  * @throws SQLException if a database error occurs, the JDBC type is not
  *  appropriate for the typeName and the conversion is not supported, the typeName is null or this method is called on a closed connection
  * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this data type
  * @since 1.6
  */
  public Array createArrayOf(String typeName, Object[] elements) throws SQLException
  {
      checkClosed();
      if (typeName == null)
          throw new VirtuosoException("typeName is null.",VirtuosoException.MISCERROR);

      if (elements == null)
          return null;
      return new VirtuosoArray(this, typeName, elements);
  }

/**
  * Factory method for creating Struct objects.
  *
  * @param typeName the SQL type name of the SQL structured type that this <code>Struct</code>
  * object maps to. The typeName is the name of  a user-defined type that
  * has been defined for this database. It is the value returned by
  * <code>Struct.getSQLTypeName</code>.

  * @param attributes the attributes that populate the returned object
  *  @return a Struct object that maps to the given SQL type and is populated with the given attributes
  * @throws SQLException if a database error occurs, the typeName is null or this method is called on a closed connection
  * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this data type
  * @since 1.6
  */
  public Struct createStruct(String typeName, Object[] attributes) throws SQLException
  {
    throw new VirtuosoFNSException ("createStruct(typeName, attributes)  not supported", VirtuosoException.NOTIMPLEMENTED);
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
      // This works for classes that are not actually wrapping anything
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
    if(isClosed())
      throw new VirtuosoException("The connection is closed.",VirtuosoException.DISCONNECTED);

    // This works for classes that are not actually wrapping anything
    return iface.isInstance(this);
  }


#if JDK_VER >= 17
   //--------------------------JDBC 4.1 -----------------------------

   /**
    * Sets the given schema name to access.
    * <P>
    * If the driver does not support schemas, it will
    * silently ignore this request.
    * <p>
    * Calling {@code setSchema} has no effect on previously created or prepared
    * {@code Statement} objects. It is implementation defined whether a DBMS
    * prepare operation takes place immediately when the {@code Connection}
    * method {@code prepareStatement} or {@code prepareCall} is invoked.
    * For maximum portability, {@code setSchema} should be called before a
    * {@code Statement} is created or prepared.
    *
    * @param schema the name of a schema  in which to work
    * @exception SQLException if a database access error occurs
    * or this method is called on a closed connection
    * @see #getSchema
    * @since 1.7
    */
  public void setSchema(String schema) throws java.sql.SQLException
  {
    if(isClosed())
      throw new VirtuosoException("The connection is closed.",VirtuosoException.DISCONNECTED);
  }

    /**
     * Retrieves this <code>Connection</code> object's current schema name.
     *
     * @return the current schema name or <code>null</code> if there is none
     * @exception SQLException if a database access error occurs
     * or this method is called on a closed connection
     * @see #setSchema
     * @since 1.7
     */
  public String getSchema() throws java.sql.SQLException
  {
    if(isClosed())
      throw new VirtuosoException("The connection is closed.",VirtuosoException.DISCONNECTED);
    return null;
  }

    /**
     * Terminates an open connection.  Calling <code>abort</code> results in:
     * <ul>
     * <li>The connection marked as closed
     * <li>Closes any physical connection to the database
     * <li>Releases resources used by the connection
     * <li>Insures that any thread that is currently accessing the connection
     * will either progress to completion or throw an <code>SQLException</code>.
     * </ul>
     * <p>
     * Calling <code>abort</code> marks the connection closed and releases any
     * resources. Calling <code>abort</code> on a closed connection is a
     * no-op.
     * <p>
     * It is possible that the aborting and releasing of the resources that are
     * held by the connection can take an extended period of time.  When the
     * <code>abort</code> method returns, the connection will have been marked as
     * closed and the <code>Executor</code> that was passed as a parameter to abort
     * may still be executing tasks to release resources.
     * <p>
     * This method checks to see that there is an <code>SQLPermission</code>
     * object before allowing the method to proceed.  If a
     * <code>SecurityManager</code> exists and its
     * <code>checkPermission</code> method denies calling <code>abort</code>,
     * this method throws a
     * <code>java.lang.SecurityException</code>.
     * @param executor  The <code>Executor</code>  implementation which will
     * be used by <code>abort</code>.
     * @throws java.sql.SQLException if a database access error occurs or
     * the {@code executor} is {@code null},
     * @throws java.lang.SecurityException if a security manager exists and its
     *    <code>checkPermission</code> method denies calling <code>abort</code>
     * @see SecurityManager#checkPermission
     * @see Executor
     * @since 1.7
     */
  public void abort(java.util.concurrent.Executor executor) throws java.sql.SQLException
  {
    SecurityManager sec = System.getSecurityManager();

    if (sec != null)
      sec.checkPermission(ABORT_PERM);

    if (executor == null)
      throw new VirtuosoException ("Executor cannot be null",
                    VirtuosoException.BADPARAM);

    executor.execute(new Runnable()
    {
      public void run() {
        try {
          abortInternal();
        } catch (SQLException e) {
          throw new RuntimeException(e);
        }
      }
    });

  }


    /**
     *
     * Sets the maximum period a <code>Connection</code> or
     * objects created from the <code>Connection</code>
     * will wait for the database to reply to any one request. If any
     *  request remains unanswered, the waiting method will
     * return with a <code>SQLException</code>, and the <code>Connection</code>
     * or objects created from the <code>Connection</code>  will be marked as
     * closed. Any subsequent use of
     * the objects, with the exception of the <code>close</code>,
     * <code>isClosed</code> or <code>Connection.isValid</code>
     * methods, will result in  a <code>SQLException</code>.
     * <p>
     * <b>Note</b>: This method is intended to address a rare but serious
     * condition where network partitions can cause threads issuing JDBC calls
     * to hang uninterruptedly in socket reads, until the OS TCP-TIMEOUT
     * (typically 10 minutes). This method is related to the
     * {@link #abort abort() } method which provides an administrator
     * thread a means to free any such threads in cases where the
     * JDBC connection is accessible to the administrator thread.
     * The <code>setNetworkTimeout</code> method will cover cases where
     * there is no administrator thread, or it has no access to the
     * connection. This method is severe in it is effects, and should be
     * given a high enough value so it is never triggered before any more
     * normal timeouts, such as transaction timeouts.
     * <p>
     * JDBC driver implementations  may also choose to support the
     * {@code setNetworkTimeout} method to impose a limit on database
     * response time, in environments where no network is present.
     * <p>
     * Drivers may internally implement some or all of their API calls with
     * multiple internal driver-database transmissions, and it is left to the
     * driver implementation to determine whether the limit will be
     * applied always to the response to the API call, or to any
     * single  request made during the API call.
     * <p>
     *
     * This method can be invoked more than once, such as to set a limit for an
     * area of JDBC code, and to reset to the default on exit from this area.
     * Invocation of this method has no impact on already outstanding
     * requests.
     * <p>
     * The {@code Statement.setQueryTimeout()} timeout value is independent of the
     * timeout value specified in {@code setNetworkTimeout}. If the query timeout
     * expires  before the network timeout then the
     * statement execution will be canceled. If the network is still
     * active the result will be that both the statement and connection
     * are still usable. However if the network timeout expires before
     * the query timeout or if the statement timeout fails due to network
     * problems, the connection will be marked as closed, any resources held by
     * the connection will be released and both the connection and
     * statement will be unusable.
     *<p>
     * When the driver determines that the {@code setNetworkTimeout} timeout
     * value has expired, the JDBC driver marks the connection
     * closed and releases any resources held by the connection.
     * <p>
     *
     * This method checks to see that there is an <code>SQLPermission</code>
     * object before allowing the method to proceed.  If a
     * <code>SecurityManager</code> exists and its
     * <code>checkPermission</code> method denies calling
     * <code>setNetworkTimeout</code>, this method throws a
     * <code>java.lang.SecurityException</code>.
     *
     * @param executor  The <code>Executor</code>  implementation which will
     * be used by <code>setNetworkTimeout</code>.
     * @param milliseconds The time in milliseconds to wait for the database
     * operation
     *  to complete.  If the JDBC driver does not support milliseconds, the
     * JDBC driver will round the value up to the nearest second.  If the
     * timeout period expires before the operation
     * completes, a SQLException will be thrown.
     * A value of 0 indicates that there is not timeout for database operations.
     * @throws java.sql.SQLException if a database access error occurs, this
     * method is called on a closed connection,
     * the {@code executor} is {@code null},
     * or the value specified for <code>seconds</code> is less than 0.
     * @throws java.lang.SecurityException if a security manager exists and its
     *    <code>checkPermission</code> method denies calling
     * <code>setNetworkTimeout</code>.
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see SecurityManager#checkPermission
     * @see Statement#setQueryTimeout
     * @see #getNetworkTimeout
     * @see #abort
     * @see Executor
     * @since 1.7
     */
  public void setNetworkTimeout(java.util.concurrent.Executor executor,
  			 final int milliseconds) throws java.sql.SQLException
  {
    SecurityManager sec = System.getSecurityManager();

    if (sec != null)
      sec.checkPermission(SET_NETWORK_TIMEOUT_PERM);

    if (executor == null)
      throw new VirtuosoException ("Executor cannot be null",
                    VirtuosoException.BADPARAM);

    if(isClosed())
      throw new VirtuosoException("The connection is closed.",VirtuosoException.DISCONNECTED);

    executor.execute(new Runnable()
    {
      public void run() {
          try {
            setSocketTimeout(milliseconds); // for re-connects
          } catch (SQLException e) {
            throw new RuntimeException(e);
          }
      }
    });
  }

    /**
     * Retrieves the number of milliseconds the driver will
     * wait for a database request to complete.
     * If the limit is exceeded, a
     * <code>SQLException</code> is thrown.
     *
     * @return the current timeout limit in milliseconds; zero means there is
     *         no limit
     * @throws SQLException if a database access error occurs or
     * this method is called on a closed <code>Connection</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #setNetworkTimeout
     * @since 1.7
     */
  public int getNetworkTimeout() throws java.sql.SQLException
  {
    if(isClosed())
      throw new VirtuosoException("The connection is closed.",VirtuosoException.DISCONNECTED);

    return timeout;
  }


#endif


  private void abortInternal() throws java.sql.SQLException
  {
    if (isClosed())
      return;

    try {
        close();
    } catch (Throwable t) {
    }
  }



  private void createCaches(int cacheSize)
  {
    pStatementCache = new LRUCache<String,VirtuosoPreparedStatement>(cacheSize) {
	protected boolean removeEldestEntry(java.util.Map.Entry eldest) {
	  if (this.maxSize <= 1) {
	    return false;
	  }

	  boolean remove = super.removeEldestEntry(eldest);

	  if (remove) {
	    VirtuosoPreparedStatement ps =
	        (VirtuosoPreparedStatement)eldest.getValue();
	    ps.isCached = false;
	    ps.setClosed(false);

	    try {
	      ps.close();
	    } catch (SQLException ex) {
	    }
	  }

	  return remove;
	}
    };
  }


  protected void recacheStmt(VirtuosoPreparedStatement ps) throws SQLException
  {
    if (ps.isPoolable()) {
      synchronized (pStatementCache) {
        pStatementCache.put(""+ps.getResultSetType()+"#"
        		      +ps.getResultSetConcurrency()+"#"
        		      +ps.sql, ps);
      }
    }
  }



    /* Global XA transaction support */

    boolean getGlobalTransaction() {
	   if (VirtuosoFuture.rpc_log != null)
	   {
		   VirtuosoFuture.rpc_log.println ("VirtuosoConnection.getGlobalTransaction () (con=" + this.hashCode() + ") :" + global_transaction);
	   }
        return global_transaction;
    }

    void setGlobalTransaction(boolean value) {
	   if (VirtuosoFuture.rpc_log != null)
	   {
		   VirtuosoFuture.rpc_log.println ("VirtuosoConnection.getGlobalTransaction (" + value + ") (con=" + this.hashCode() + ") :" + global_transaction);
	   }
        global_transaction = value;
    }

    protected void setWarning (SQLWarning warn)
    {
	warn.setNextWarning (warning);
	warning = warn;
    }

    protected VirtuosoException notify_error (Throwable e)
    {
	VirtuosoException vex;
	if (!(e instanceof VirtuosoException))
	{
	    vex = new VirtuosoException(e.getMessage(), VirtuosoException.IOERROR);
	    vex.initCause (e);
	}
	else
	    vex = (VirtuosoException) e;
        if (pooled_connection != null && isCriticalError(vex)) {
            pooled_connection.sendErrorEvent(vex);
	}
	return vex;
    }

    public static boolean isCriticalError(SQLException ex)
    {
      if (ex == null)
        return false;
      String SQLstate = ex.getSQLState();
      if (SQLstate != null && SQLstate.startsWith("08")
          && SQLstate != "08C04"
          && SQLstate != "08C03"
          && SQLstate != "08001"
          && SQLstate != "08003"
          && SQLstate != "08006"
          && SQLstate != "08007"
          )
        return true;

      int vendor = ex.getErrorCode();
      if (vendor == VirtuosoException.DISCONNECTED
          || vendor == VirtuosoException.IOERROR
          || vendor == VirtuosoException.BADLOGIN
          || vendor == VirtuosoException.BADTAG
          || vendor == VirtuosoException.CLOSED
          || vendor == VirtuosoException.EOF
          || vendor == VirtuosoException.NOLICENCE
          || vendor == VirtuosoException.UNKNOWN)
        return true;
      else
        return false;
    }

}

class VirtX509TrustManager implements X509TrustManager
{

  public boolean isClientTrusted(java.security.cert.X509Certificate[] chain)
    {
      return true;
    }

  public boolean isServerTrusted(java.security.cert.X509Certificate[] chain)
    {
      return true;
    }


  /* JDK 1.4 fucntions */
  /**
   * note - ALLWAYS true - means no effective certificate check
   */
  public void checkClientTrusted(X509Certificate[] chain, String authType) throws CertificateException
    {
    }
  /**
   * note - ALLWAYS true - means no effective certificate check
   */
  public void checkServerTrusted(X509Certificate[] chain, String authType) throws CertificateException
    {
    }

  /**
   * note - empty CA list
   */
  public X509Certificate[] getAcceptedIssuers()
    {
      return null;
    }
}


class VirtX509KeyManager extends X509ExtendedKeyManager {

    X509KeyManager defaultKeyManager;
    String defAlias;
    KeyStore tks;
    ArrayList<X509Certificate> certs = new ArrayList<X509Certificate>(32);


    public VirtX509KeyManager(String cert_alias, String keys_file, String keys_pwd, KeyStore tks)
            throws KeyStoreException, NoSuchAlgorithmException, CertificateException, IOException, UnrecoverableKeyException
    {
        KeyManager[] km;
        KeyStore ks;

        if (keys_file.endsWith(".p12") || keys_file.endsWith(".pfx"))
            ks = KeyStore.getInstance("PKCS12");
        else
            ks = KeyStore.getInstance("JKS");

        InputStream is = null;
        try {
          is = new FileInputStream(keys_file);
          ks.load(is, keys_pwd.toCharArray());
        } finally {
          if (is!=null)
            is.close();
        }

        if (cert_alias == null)
          {
            String alias = null;
            Enumeration<String> en = ks.aliases();
            while(en.hasMoreElements()) {
                alias = en.nextElement();
                ks.isKeyEntry(alias);
                break;
            }
            defAlias = alias;
          }
        else
          {
            if (!ks.containsAlias(cert_alias))
              throw new KeyStoreException("Could not found alias:["+cert_alias+"] in KeyStore :"+keys_file);
            defAlias = cert_alias;
          }

        certs.add((X509Certificate) ks.getCertificate(defAlias));

        if (tks!=null) {
            for(Enumeration<String> en = tks.aliases(); en.hasMoreElements(); ) {
                String alias = en.nextElement();
                certs.add((X509Certificate) tks.getCertificate(alias));
            }
        }

        KeyManagerFactory kmf = KeyManagerFactory.getInstance("SunX509");
        kmf.init(ks, keys_pwd.toCharArray());
        defaultKeyManager = (X509KeyManager)kmf.getKeyManagers()[0];
    }


    public String[] getClientAliases(String s, Principal[] principals) {
        return defaultKeyManager.getClientAliases(s, principals);
    }

    public String chooseClientAlias(String[] keyType, Principal[] issuers, Socket socket)
    {
        return defAlias;
/***
      boolean aliasFound=false;

      for (int i=0; i<keyType.length && !aliasFound; i++) {
        String[] validAliases=defaultKeyManager.getClientAliases(keyType[i], issuers);
        if (validAliases!=null) {
          for (int j=0; j<validAliases.length && !aliasFound; j++) {
            if (validAliases[j].equals(alias))
              aliasFound=true;
          }
        }
      }

      if (aliasFound)
        return alias;
      else
        return null;
***/
    }

    public String[] getServerAliases(String s, Principal[] principals) {
        return defaultKeyManager.getServerAliases(s, principals);
    }

    public String chooseServerAlias(String s, Principal[] principals, Socket socket) {
        return defaultKeyManager.chooseServerAlias(s, principals, socket);
    }

    public X509Certificate[] getCertificateChain(String s) {
//        return certs.toArray(new X509Certificate[certs.size()]);
        return defaultKeyManager.getCertificateChain(s);
    }

    public PrivateKey getPrivateKey(String s) {
        return defaultKeyManager.getPrivateKey(s);
    }
}


