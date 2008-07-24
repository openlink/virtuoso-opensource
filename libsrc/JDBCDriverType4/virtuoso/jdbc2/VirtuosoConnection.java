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
/* VirtuosoConnection.java */
package virtuoso.jdbc2;

import java.sql.*;
import java.net.*;
import java.io.*;
import java.util.*;
#ifdef SSL
#undef sun
import java.security.*;
import java.security.cert.*;
import javax.net.ssl.*;
#if JDK_VER < 14
import com.sun.net.ssl.*;
#endif
#endif
import openlink.util.*;

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
 * @see virtuoso.jdbc2.VirtuosoStatement
 * @see virtuoso.jdbc2.VirtuosoPreparedStatement
 * @see virtuoso.jdbc2.VirtuosoCallableStatement
 * @see virtuoso.jdbc2.VirtuosoDatabaseMetaData
 */
public class VirtuosoConnection implements Connection
{
   // Buffered TCP socket stream
   private Socket socket;

   private VirtuosoInputStream in;

   private VirtuosoOutputStream out;

   // Hash table from future id to the VirtuosoFuture instance
   private Hashtable futures;

   // Serial number of last issued future, 0 is first
   private int req_no, con_no;
   private static int global_con_no = 0;

   // String sent by server as answer to "SCON" RPC
   protected String qualifier;
   private String version;
   private int _case;
   protected openlink.util.Vector client_defaults;
   protected openlink.util.Vector client_charset;
   protected Hashtable client_charset_hash;
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

#ifdef SSL
   // The SSL parameters
   private String keystore_pass, keystore_cert, keystore_path;
   private String ssl_provider;
#endif

   // The transaction isolation
   private int trxisolation = Connection.TRANSACTION_REPEATABLE_READ;

   // The read mode
   private boolean readOnly = false;

   // The timeout for I/O
   protected int timeout = 60;
   protected int txn_timeout = 0;

   // utf8_encoding for statements
   protected boolean utf8_execs = false;

   // set if the connection is managed through VirtuosoPooledConnection;
#if JDK_VER >= 14
   protected VirtuosoPooledConnection pooled_connection = null;
#endif

   protected String charset;
   protected boolean charset_utf8 = false;

   protected Hashtable rdf_type_hash = null;
   protected Hashtable rdf_lang_hash = null;
   protected Hashtable rdf_type_rev = null;
   protected Hashtable rdf_lang_rev = null;

   /**
    * Constructs a new connection to Virtuoso database and makes the
    * connection.
    *
    * @param url	The JDBC URL for the connection.
    * @param host	The name of the host on which the database resides.
    * @param port The port number on which Virtuoso is listening.
    * @param prop The properties to use for making the connection (user, password).
    * @exception	virtuoso.jdbc2.VirtuosoException	An error occurred during the
    * connection.
    */
   VirtuosoConnection(String url, String host, int port, Properties prop) throws VirtuosoException
   {
      // Set some variables
      this.req_no = 0;
      this.url = url;
      this.con_no = global_con_no++;
      // Check properties
      if (prop.get("charset") != null)
      {
	charset = (String)prop.get("charset");
	//System.out.println ("VirtuosoConnection " + charset);
	if (charset.indexOf("UTF-8") != -1) // special case all will go as UTF-8
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
      if(password == null)
         password = "";
      if(prop.get("timeout") != null)
		   timeout = ((Number)prop.get("timeout")).intValue();
      pwdclear = (String)prop.get("pwdclear");
      //System.err.println ("3PwdClear is " + pwdclear);
#ifdef SSL
      keystore_cert = (String)prop.get("certificate");
      keystore_pass = (String)prop.get("keystorepass");
      keystore_path = (String)prop.get("keystorepath");
      ssl_provider = (String)prop.get("provider");
#endif
      if(pwdclear == null)
         pwdclear = "0";
      //System.err.println ("4PwdClear is " + pwdclear);
      // Create the hash table
      futures = new Hashtable();
      // RDF box type & lang
      rdf_type_hash = new Hashtable ();
      rdf_lang_hash = new Hashtable ();
      rdf_type_rev = new Hashtable ();
      rdf_lang_rev = new Hashtable ();
      // Connect to the database
      connect(host,port,(String)prop.get("database"), (prop.get("log_enable") != null ? ((Number)prop.get("log_enable")).intValue() : -1));
   }

   /**
    * Connect to the Virtuoso database and set streams.
    *
    * @param host	The name of the host on which the database resides.
    * @param port 	The port number on which Virtuoso is listening.
    * @param database 	The database to connect to.
    * @exception	virtuoso.jdbc2.VirtuosoException	An error occurred during the
    * connection.
    */
   private void connect(String host, int port,String db, int log_enable) throws VirtuosoException
   {
      // Connect to the database
      connect(host,port);
      // Set database with statement
      if(db!=null) new VirtuosoStatement(this).executeQuery("use "+db);
      //System.out.println  ("log enable="+log_enable);
      if (log_enable >= 0 && log_enable <= 3)
        new VirtuosoStatement(this).executeQuery("log_enable ("+log_enable+")"); 
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

   /**
    * Connect to the Virtuoso database and set streams.
    *
    * @param host	The name of the host on which the database resides.
    * @param port 	The port number on which Virtuoso is listening.
    * @exception	virtuoso.jdbc2.VirtuosoException	An error occurred during the
    * connection.
    */
  private void connect(String host, int port) throws VirtuosoException
   {
      try
      {
         // Establish the connection
#ifdef SSL
	if(keystore_cert != null)
	  {
	    //System.out.println ("Will do SSL");
	    if(ssl_provider != null && ssl_provider.length() != 0)
	      {
		//System.out.println ("SSL Provider " + ssl_provider);
		Security.addProvider((Provider)(Class.forName(ssl_provider).newInstance()));
	      }
	    else
	      java.security.Security.addProvider(new com.sun.net.ssl.internal.ssl.Provider());
	    if(keystore_cert.length() == 0)
	      {
		/* Connection without authentication  */
		//System.setProperty ("java.protocol.handler.pkgs", "com.sun.net.ssl.internal.www.protocol");
		/*javax.net.ssl.SSLSocketFactory sf =
		    (javax.net.ssl.SSLSocketFactory) javax.net.ssl.SSLSocketFactory.getDefault();*/
		/*javax.net.ssl.SSLSocket sock = null;*/
		//System.out.println ("init(): Creating derived X509TrustManager");

		X509TrustManager tm = new MyX509TrustManager();
		KeyManager []km = null;
		TrustManager []tma = {
		  tm
		};

		//System.out.println ("init(): Calling SSLContext.getInstance");
		SSLContext sc = SSLContext.getInstance("TLS");
		//System.out.println ("init(): Calling sc.init");
		sc.init(km,tma,new java.security.SecureRandom());
		//System.out.println ("init(): Calling sc.getSocketFactory");
		SSLSocketFactory sf1 = sc.getSocketFactory();
		//System.out.println ("No auth conn");
		socket = sf1.createSocket(host, port);
		//System.out.println ("after create sock");
	      }
	    else
	      {
		//System.out.println ("Auth conn" + keystore_cert);
		/* Connection with authentication  */
		KeyManagerFactory kmf = KeyManagerFactory.getInstance("SunX509");
		SSLContext ssl_ctx = SSLContext.getInstance("TLS");
		KeyStore ks = KeyStore.getInstance("JKS");

		ks.load(new FileInputStream((keystore_path!=null) ? keystore_path : System.getProperty("user.home") + System.getProperty("file.separator") + ".keystore"),
		    (keystore_pass!= null) ? keystore_pass.toCharArray() : new String("").toCharArray());
		kmf.init(ks, (keystore_pass!= null) ? keystore_pass.toCharArray() : new String("").toCharArray());
		ssl_ctx.init(kmf.getKeyManagers(), null, null);

		socket = ((SSLSocketFactory)ssl_ctx.getSocketFactory()).createSocket(host, port);
	      }
	    /* Begin the handshake client/server  */
	    ((SSLSocket)socket).startHandshake();
	  }
	else
#endif
	 socket = new Socket(host,port);
	 socket.setSoTimeout(timeout*1000);
         // Get streams corresponding to the socket
         in = new VirtuosoInputStream(this,socket,4096);
	 out = new VirtuosoOutputStream(this,socket,2048);
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
	     Object[] args = new Object[3];
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
	     future = getFuture(VirtuosoFuture.scon,args, this.timeout);
	     result_future = (openlink.util.Vector)future.nextResult();
	     // Check if it's a login answer
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
			     client_charset_hash = new Hashtable (256);
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
			 timeout = (int) (cdef_param (client_defaults, "SQL_QUERY_TIMEOUT", timeout * 1000) / 1000);
			 //System.err.println ("timeout = " + timeout);
			 socket.setSoTimeout(timeout*1000);
			 txn_timeout = (int) (cdef_param (client_defaults, "SQL_TXN_TIMEOUT", txn_timeout * 1000)/ 1000);
			 //System.err.println ("txn timeout = " + txn_timeout);
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
      catch(IOException e)
      {
         throw new VirtuosoException("Connection failed: " + e.getMessage(),VirtuosoException.IOERROR);
      }
#ifdef SSL
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
         throw new VirtuosoException("Encryption failed: " + e.getMessage(),VirtuosoException.MISCERROR);
      }
#endif
   }

   /**
    * Send an object to be sent on the output stream.
    *
    * @param obj  The object to send.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   protected void write_object(Object obj) throws IOException, VirtuosoException
   {
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.print ("(conn " + hashCode() + ") OUT ");
	     VirtuosoFuture.rpc_log.println (obj != null ? obj.toString() : "<null>");
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
#if JDK_VER >= 14
    try {
        out.write_object(obj);
        out.flush();
    } catch (IOException ex) {
        if (pooled_connection != null) {
            VirtuosoException vex =
                new VirtuosoException(
                    "Connection failed: " + ex.getMessage(),
                    VirtuosoException.IOERROR);
            pooled_connection.notify_error(vex);
            throw vex;
        } else {
            throw ex;
        }
    } catch (VirtuosoException ex) {
        if (pooled_connection != null) {
            int code = ex.getErrorCode();
            if (code == VirtuosoException.DISCONNECTED
                || code == VirtuosoException.IOERROR) {
                pooled_connection.notify_error(ex);
            }
        }
        throw ex;
    }
#else
    out.write_object(obj);
    out.flush();
#endif
   }

   protected void write_bytes(byte [] bytes) throws IOException, VirtuosoException
   {
#if JDK_VER >= 14
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
            pooled_connection.notify_error(vex);
            throw vex;
        } else {
            throw ex;
        }
    }
#else
    for (int k = 0; k < bytes.length; k++)
        out.write(bytes[k]);
    out.flush();
#endif
   }

   /**
    * Start an RPC function call by sending a VirtuosoFuture request.
    *
    * @param rpcname	The name of the RPC function.
    * @param args		The array of arguments.
    * @return VirtuosoFuture	The future instance.
    * @exception java.io.IOException	An IO error occurred.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
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
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   protected boolean read_request() throws IOException, VirtuosoException
   {
     if (futures == null)
       throw new VirtuosoException ("Activity on a closed connection", "IM001", VirtuosoException.SQLERROR);
     //System.out.println ("req start");
     Object _result;
#if JDK_VER >= 14
     try {
        _result = in.read_object();
     } catch (IOException ex) {
        if (pooled_connection != null) {
            VirtuosoException vex =
                new VirtuosoException(
                    "Connection failed: " + ex.getMessage(),
                    VirtuosoException.IOERROR);
            pooled_connection.notify_error(vex);
            throw vex;
        } else {
            throw ex;
        }
     } catch (VirtuosoException ex) {
        if (pooled_connection != null) {
            int code = ex.getErrorCode();
            if (code == VirtuosoException.DISCONNECTED
                || code == VirtuosoException.IOERROR) {
                pooled_connection.notify_error(ex);
            }
        }
        throw ex;
     }
#else
    _result = in.read_object();
#endif
     //System.out.println ("req end");
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.print ("(conn " + hashCode() + ") IN ");
	     VirtuosoFuture.rpc_log.println (_result != null ? _result.toString() : "<null>");
	     VirtuosoFuture.rpc_log.flush();
	   }
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
             synchronized (VirtuosoFuture.rpc_log)
               {
                 VirtuosoFuture.rpc_log.println ("(conn " + hashCode() + ") **** runtime2 " +
                     e.getClass().getName() + " in read_request");
                 e.printStackTrace(VirtuosoFuture.rpc_log);
		 VirtuosoFuture.rpc_log.flush();
               }
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
    * Virtuoso doesn't generate warnings, so this function does nothing, but we
    * must declare it to be compliant with the JDBC API.
    *
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection#clearWarnings
    */
   public void clearWarnings() throws VirtuosoException
   {
       warning = null;
   }

   /**
    * Close the current connection previously established with Virtuoso DBMS.
    *
    * @exception virtuoso.jdbc2.VirtuosoException An error occurred during the connection.
    * @see java.sql.Connection#close
    */
   public void close() throws VirtuosoException
   {
      try
      {
         // Is already closed ?
         if(isClosed())
            throw new VirtuosoException("The connection is already closed.",VirtuosoException.DISCONNECTED);
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
         // Clear some variables
         user = url = password = null;
         futures = null;
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
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
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
    * @see virtuoso.jdbc2.VirtuosoStatement
    */
   public Statement createStatement() throws VirtuosoException
   {
      return createStatement(VirtuosoResultSet.TYPE_FORWARD_ONLY,VirtuosoResultSet.CONCUR_READ_ONLY);
   }

   /**
    * Returns the current auto-commit state.
    *
    * @return boolean   The current state of auto-commit mode.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
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
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection#getMetaData
    * @see virtuoso.jdbc2.VirtuosoDatabaseMetaData
    */
   public DatabaseMetaData getMetaData() throws VirtuosoException
   {
      return new VirtuosoDatabaseMetaData(this);
   }

   /**
    * Retrieves the first warning reported by calls on this Connection.
    * Subsequent Connection warnings will be chained to this
    * SQLWarning. Virtuoso doesn't generate warnings, so this function
    * returns always null.
    *
    * @return SQLWarning   The first SQLWarning or null (must be null for the moment)
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just implementation).
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
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
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
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection#getTransactionIsolation
    */
   public int getTransactionIsolation() throws VirtuosoException
   {
      return trxisolation;
   }

   /**
    * Checks if the connection is closed.
    *
    * @return boolean   True if the connection is closed, false if it's still open.
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
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    * @see java.sql.Connection#prepareCall
    * @see virtuoso.jdbc2.VirtuosoCallableStatement
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
    * @see virtuoso.jdbc2.VirtuosoPreparedStatement
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
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
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
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
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
    * @see virtuoso.jdbc2.VirtuosoStatement
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
    * @see virtuoso.jdbc2.VirtuosoCallableStatement
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
    * @see virtuoso.jdbc2.VirtuosoPreparedStatement
    */
   public PreparedStatement prepareStatement(String sql, int resultSetType, int resultSetConcurrency) throws VirtuosoException
   {
      return new VirtuosoPreparedStatement(this,sql,resultSetType,resultSetConcurrency);
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
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
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
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
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
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
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
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection#setCatalog
    */
   public void setCatalog(String catalog) throws VirtuosoException
   {
   }

   /**
    * Returns the Connection's current catalog name.
    *
    * @return the current catalog name or null
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection#getCatalog
    */
   public String getCatalog() throws VirtuosoException
   {
      return qualifier;
   }

#if JDK_VER >= 12
   /**
    * Gets the type map object associated with this connection.
    * Unless the application has added an entry to the type map,
    * the map returned will be empty.
    *
    * @return the <code>java.util.Map</code> object associated
    *         with this <code>Connection</code> object
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just implementation).
    * @see java.sql.Connection#getTypeMap
    */
   public Map getTypeMap() throws VirtuosoException
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
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just implementation).
    * @see java.sql.Connection#setTypeMap
    */
   public void setTypeMap(Map map) throws VirtuosoException
   {
   }
#endif

   protected void setSocketTimeout (int timeout) throws VirtuosoException
     {
      try
	{
	  //System.err.println ("timeout = " + timeout);
	  if (timeout != -1)
	    socket.setSoTimeout (timeout * 1000);
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
       System.err.println ("charsetBytes1(" + from + " , " + to);
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

#if JDK_VER >= 14
   /* JDK 1.4 functions */

   /**
    * supports only <code>ResultSet.HOLD_CURSORS_OVER_COMMIT</code> for now
    * @exception virtuoso.jdbc2.VirtuosoException if the holdability is not the supported one
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
    * @exception virtuoso.jdbc2.VirtuosoException allways thrown : savepoints not supported
    */
   public Savepoint setSavepoint() throws SQLException
     {
       throw new VirtuosoException ("Savepoints not supported", "IM001",
         VirtuosoException.NOTIMPLEMENTED);
     }

   /**
    * @exception virtuoso.jdbc2.VirtuosoException allways thrown : savepoints not supported
    */
   public Savepoint setSavepoint(String name) throws SQLException
     {
       throw new VirtuosoException ("Savepoints not supported", "IM001",
         VirtuosoException.NOTIMPLEMENTED);
     }

   /**
    * @exception virtuoso.jdbc2.VirtuosoException allways thrown : savepoints not supported
    */
   public void rollback(Savepoint savepoint) throws SQLException
     {
       throw new VirtuosoException ("Savepoints not supported", "IM001",
         VirtuosoException.NOTIMPLEMENTED);
     }

   /**
    * @exception virtuoso.jdbc2.VirtuosoException allways thrown : savepoints not supported
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
#endif

    /* Global XA transaction support */

    boolean getGlobalTransaction() {
	   if (VirtuosoFuture.rpc_log != null)
	   {
	       synchronized (VirtuosoFuture.rpc_log)
	       {
		   VirtuosoFuture.rpc_log.println ("VirtuosoConnection.getGlobalTransaction () (con=" + this.hashCode() + ") :" + global_transaction);
		   VirtuosoFuture.rpc_log.flush();
	       }
	   }
        return global_transaction;
    }

    void setGlobalTransaction(boolean value) {
	   if (VirtuosoFuture.rpc_log != null)
	   {
	       synchronized (VirtuosoFuture.rpc_log)
	       {
		   VirtuosoFuture.rpc_log.println ("VirtuosoConnection.getGlobalTransaction (" + value + ") (con=" + this.hashCode() + ") :" + global_transaction);
		   VirtuosoFuture.rpc_log.flush();
	       }
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
#if JDK_VER >= 14
	    vex.initCause (e);
#endif
	}
	else
	    vex = (VirtuosoException) e;
#if JDK_VER >= 14
        if (pooled_connection != null)
	{
            pooled_connection.notify_error(vex);
	}
#endif
	return vex;
    }
}

#ifdef SSL
class MyX509TrustManager implements X509TrustManager
{

  public boolean isClientTrusted(java.security.cert.X509Certificate[] chain)
    {
      return true;
    }

  public boolean isServerTrusted(java.security.cert.X509Certificate[] chain)
    {
      return true;
    }

#if JDK_VER < 14
  public java.security.cert.X509Certificate[] getAcceptedIssuers()
    {
      return null;
    }
#endif

#if JDK_VER >= 14
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
#endif
}
#endif
