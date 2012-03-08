//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2012 OpenLink Software
//  
//  This project is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the
//  Free Software Foundation; only version 2 of the License, dated June 1991.
//  
//  This program is distributed in the hope that it will be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//  General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
//  
//  
//
// $Id$
//

using System;
using System.Collections;
using System.Collections.Specialized;
using System.Text;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	/// <summary>
	/// Summary description for ConnectionOptions.
	/// </summary>
	internal sealed class ConnectionOptions
	{
		internal abstract class Option
		{
			internal abstract void Set (string settingString);
			internal abstract string Get ();
			internal virtual ArrayList GetList () { return null;}
		};

		private sealed class ListOption : Option
		{
			internal override void Set (string settingString)
			{
				setting =  settingString;
				items =  new ArrayList();
				
				StringBuilder buff = new StringBuilder();
				string val;
				for(int i = 0; i < settingString.Length; i++)
				{
					char c = settingString[i];
					if (c == ',')
					{
						val = buff.ToString().Trim();
						if (val != String.Empty)
							items.Add(val);
						buff.Length = 0;
					}
					else if (!Char.IsWhiteSpace(c))
					{
						buff.Append(c);
					}
				}

				val = buff.ToString().Trim();
				if (val != String.Empty)
					items.Add(val);
			}

			internal override string Get ()
			{
				return setting;
			}

			internal override ArrayList GetList ()
			{
				return items;
			}

			internal ArrayList items;
			internal string setting;
                    public override string ToString()
                    {
                        return setting;
                    }

		}

		private sealed class StringOption : Option
		{
			internal override void Set (string settingString)
			{
				setting = settingString;
			}

			internal override string Get ()
			{
				return setting;
			}

			internal string setting;
                    public override string ToString()
                    {
                        return setting;
                    }

		}

		private sealed class IntegerOption : Option
		{
			internal override void Set (string settingString)
			{
				setting = int.Parse (settingString);
			}

			internal override string Get ()
			{
				return setting.ToString();
			}

			internal int setting;
                    public override string ToString()
                    {
                        return setting.ToString ();
                    }

		}

		private sealed class BooleanOption : Option
		{
			internal override void Set (string settingString)
			{
				setting = bool.Parse (settingString);
			}

			internal override string Get ()
			{
				return setting.ToString();
			}

			internal bool setting;
                    public override string ToString()
                    {
                        return setting.ToString ();
                    }

		}

		internal const int DEFAULT_CONN_TIMEOUT = 15;
		internal const int DEFAULT_CONN_LIFETIME = 0;
		internal const int DEFAULT_MIN_POOL_SIZE = 0;
		internal const int DEFAULT_MAX_POOL_SIZE = 100;
#if ODBC_CLIENT || CLIENT
		internal const bool DEFAULT_USE_ODBC = true;
#else
		internal const bool DEFAULT_USE_ODBC = false;
#endif
		internal const bool DEFAULT_PERSIST_SECURITY_INFO = false;
		internal const bool DEFAULT_POOLING = true;
		internal const bool DEFAULT_ENLIST = true;
		internal const bool DEFAULT_ROUND_ROBIN = false;

		internal const string ODBC = "ODBC";
		internal const string HOST = "HOST";
		internal const string DATASOURCE = "Data Source";
		internal const string SERVER = "Server";
		internal const string ADDRESS = "Address";
		internal const string NETWORKADDRESS = "Network Address";
		internal const string UID = "UID";
		internal const string USER_ID = "User ID";
		internal const string USERID = "UserId";
		internal const string PWD = "PWD";
		internal const string PASSWORD = "Password";
		internal const string DATABASE = "Database";
		internal const string INITIALCATALOG = "Initial Catalog";
		internal const string CHARSET = "Charset";
		internal const string ENCRYPT = "Encrypt";
		internal const string PERSISTSECURITYINFO = "PersistSecurityInfo";
		internal const string PERSIST_SECURITY_INFO = "Persist Security Info";
		internal const string CONNECTTIMEOUT = "ConnectTimeout";
		internal const string CONNECT_TIMEOUT = "Connect Timeout";
		internal const string CONNECTIONTIMEOUT = "ConnectionTimeout";
		internal const string CONNECTION_TIMEOUT = "Connection Timeout";
		internal const string CONNECTIONLIFETIME = "ConnectionLifetime";
		internal const string CONNECTION_LIFETIME = "Connection Lifetime";
		internal const string MINPOOLSIZE = "MinPoolSize";
		internal const string MIN_POOL_SIZE = "Min Pool Size";
		internal const string MAXPOOLSIZE = "MaxPoolSize";
		internal const string MAX_POOL_SIZE = "Max Pool Size";
		internal const string POOLING = "Pooling";
		internal const string ENLIST = "Enlist";
		internal const string ROUNDROBIN = "RoundRobin";
		internal const string ROUND_ROBIN = "Round Robin";

		private BooleanOption odbc;
		private ListOption host;
		private StringOption uid;
		private StringOption pwd;
		private StringOption database;
		private StringOption charset;
		private StringOption encrypt;
		private BooleanOption persistSecurityInfo;
		private IntegerOption connectionTimeout;
		private IntegerOption connectionLifetime;
		private IntegerOption minPoolSize;
		private IntegerOption maxPoolSize;
		private BooleanOption pooling;
		private BooleanOption enlist;
		private BooleanOption roundrobin;

		/// <summary>
		/// Contains the original connection string.
		/// </summary>
		private string connectionString;

		/// <summary>
		/// Contains the original connection string excluding the security-sensitive information.
		/// </summary>
		private string secureConnectionString;

		private Hashtable options;

		internal ConnectionOptions ()
		{
			odbc = new BooleanOption ();
			host = new ListOption ();
			uid = new StringOption ();
			pwd = new StringOption ();
			database = new StringOption ();
			charset = new StringOption ();
			encrypt = new StringOption ();
			persistSecurityInfo = new BooleanOption ();
			connectionTimeout = new IntegerOption ();
			connectionLifetime = new IntegerOption ();
			minPoolSize = new IntegerOption ();
			maxPoolSize = new IntegerOption ();
			pooling = new BooleanOption ();
			enlist = new BooleanOption ();
			roundrobin = new BooleanOption ();
			Reset ();

			options = CollectionsUtil.CreateCaseInsensitiveHashtable (23);
			options.Add (ODBC, odbc);
			options.Add (HOST, host);
			options.Add (DATASOURCE, host);
			options.Add (SERVER, host);
			options.Add (ADDRESS, host);
			options.Add (NETWORKADDRESS, host);
			options.Add (UID, uid);
			options.Add (USER_ID, uid);
			options.Add (USERID, uid);
			options.Add (PWD, pwd);
			options.Add (PASSWORD, pwd);
			options.Add (DATABASE, database);
			options.Add (INITIALCATALOG, database);
			options.Add (CHARSET, charset);
			options.Add (ENCRYPT, encrypt);
			options.Add (PERSISTSECURITYINFO, persistSecurityInfo);
			options.Add (PERSIST_SECURITY_INFO, persistSecurityInfo);
			options.Add (CONNECTTIMEOUT, connectionTimeout);
			options.Add (CONNECT_TIMEOUT, connectionTimeout);
			options.Add (CONNECTIONTIMEOUT, connectionTimeout);
			options.Add (CONNECTION_TIMEOUT, connectionTimeout);
			options.Add (CONNECTIONLIFETIME, connectionLifetime);
			options.Add (CONNECTION_LIFETIME, connectionLifetime);
			options.Add (MINPOOLSIZE, minPoolSize);
			options.Add (MIN_POOL_SIZE, minPoolSize);
			options.Add (MAXPOOLSIZE, maxPoolSize);
			options.Add (MAX_POOL_SIZE, maxPoolSize);
			options.Add (POOLING, pooling);
			options.Add (ENLIST, enlist);
			options.Add (ROUNDROBIN, roundrobin);
			options.Add (ROUND_ROBIN, roundrobin);
		}

		internal void Reset ()
		{
			odbc.setting = DEFAULT_USE_ODBC;
			host.setting = null;
			uid.setting = null;
			pwd.setting = null;
			database.setting = null;
			charset.setting = null;
			encrypt.setting = null;
			persistSecurityInfo.setting = false;
			connectionTimeout.setting = DEFAULT_CONN_TIMEOUT;
			connectionLifetime.setting = DEFAULT_CONN_LIFETIME;
			minPoolSize.setting = DEFAULT_MIN_POOL_SIZE;
			maxPoolSize.setting = DEFAULT_MAX_POOL_SIZE;
            		pooling.setting = true;
            		enlist.setting = Platform.HasDtc ();
            		roundrobin.setting = false;
		}

		internal void Verify ()
		{
			if (MinPoolSize < 0)
				throw new ArgumentException ("Invalid Min Pool Size value.");
			if (MaxPoolSize <= 0)
				throw new ArgumentException ("Invalid Max Pool Size value.");
			if (MinPoolSize > MaxPoolSize)
				throw new ArgumentException ("Min Pool Size is greater than Max Pool Size.");
			if (Enlist && !Platform.HasDtc ())
				throw new ArgumentException ("Transaction enlistment is not supported on this platform.");
		}

		internal void Secure ()
		{
			if (PersistSecurityInfo == false)
				connectionString = secureConnectionString;
		}

		internal Option GetOption (string name)
		{
			return (Option) options[name];
		}

		internal bool UseOdbc
		{
			get { return odbc.setting; }
		}

		internal bool PersistSecurityInfo
		{
			get { return persistSecurityInfo.setting; }
		}

		internal string UserId
		{
			get { return uid.setting; }
		}

		internal string Password
		{
			get { return pwd.setting; }
		}

		internal string DataSource
		{
			get { return host.setting; }
		}

		internal ArrayList DataSourceList
		{
			get { return host.GetList(); }
		}

		internal string Database
		{
			get { return database.setting; }
		}

		internal string Charset
		{
			get { return charset.setting; }
		}

		internal string Encrypt
		{
			get { return encrypt.setting; }
		}

		internal int ConnectionTimeout
		{
			get { return connectionTimeout.setting; }
		}

		internal int ConnectionLifetime
		{
			get { return connectionLifetime.setting; }
		}

		internal int MinPoolSize
		{
			get { return minPoolSize.setting; }
		}

		internal int MaxPoolSize
		{
			get { return maxPoolSize.setting; }
		}

		internal bool Pooling
		{
			get
			{
				if (pooling.setting == false)
					return false;
				if (maxPoolSize.setting <= 0)
					return false;
				if (host.setting == null || uid.setting == null || pwd.setting == null)
					return false;
				if (host.setting.StartsWith (":in-process:"))
					return false;
				return true;
			}
		}

		internal bool Enlist
		{
			get { return enlist.setting; }
		}

		internal bool RoundRobin
		{
			get { return roundrobin.setting; }
		}

		internal string ConnectionString
		{
			get { return connectionString; }
			set { connectionString = value; }
		}

		internal string SecureConnectionString
		{
			get { return secureConnectionString; }
			set { secureConnectionString = value; }
		}

		/// <summary>
		/// Checks if a connection option is security-sensitive.
		/// </summary>
		/// <param name="name"></param>
		/// <returns></returns>
		internal static bool IsSecuritySensitive (string name)
		{
			name = name.ToUpper ();
			return name == "PWD" || name == "PASSWORD";
		}
	}
}
