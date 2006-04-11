//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2006 OpenLink Software
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
		};

		private sealed class StringOption : Option
		{
			internal override void Set (string settingString)
			{
				setting = settingString;
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

			internal bool setting;
                    public override string ToString()
                    {
                        return setting.ToString ();
                    }

		}

		private const int DEFAULT_CONN_TIMEOUT = 15;
		private const int DEFAULT_CONN_LIFETIME = 0;
		private const int DEFAULT_MIN_POOL_SIZE = 0;
		private const int DEFAULT_MAX_POOL_SIZE = 100;

		private BooleanOption odbc;
		private StringOption host;
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
			host = new StringOption ();
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
			Reset ();

			options = CollectionsUtil.CreateCaseInsensitiveHashtable (23);
			options.Add ("ODBC", odbc);
			options.Add ("HOST", host);
			options.Add ("Data Source", host);
			options.Add ("Server", host);
			options.Add ("Address", host);
			options.Add ("Network Address", host);
			options.Add ("UID", uid);
			options.Add ("User ID", uid);
			options.Add ("PWD", pwd);
			options.Add ("Password", pwd);
			options.Add ("DATABASE", database);
			options.Add ("Initial Catalog", database);
			options.Add ("Charset", charset);
			options.Add ("Encrypt", encrypt);
			options.Add ("Persist Security Info", persistSecurityInfo);
			options.Add ("Connect Timeout", connectionTimeout);
			options.Add ("Connection Timeout", connectionTimeout);
			options.Add ("Connection Lifetime", connectionLifetime);
			options.Add ("Min Pool Size", minPoolSize);
			options.Add ("Max Pool Size", maxPoolSize);
			options.Add ("Pooling", pooling);
			options.Add ("Enlist", enlist);
		}

		internal void Reset ()
		{
#if ODBC_CLIENT || CLIENT
			odbc.setting = true;
#else
			odbc.setting = false;
#endif
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
#if ADONET2
            // .NET Beta will throw NotImplementedExpcetion on Pool
			pooling.setting = false;
#else
            pooling.setting = true;
#endif
            enlist.setting = Platform.HasDtc ();
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
