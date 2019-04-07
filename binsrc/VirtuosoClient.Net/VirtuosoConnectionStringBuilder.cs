//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2019 OpenLink Software
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
using System.Data;
#if ADONET2
using System.Data.Common;
#endif


#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
  public sealed class VirtuosoConnectionStringBuilder : DbConnectionStringBuilder
    {
#region DbConnectionStringBuilder overrides
      public VirtuosoConnectionStringBuilder (string connectionString)
	{
            ConnectionString = connectionString;
            // Get non-string properties to validate any initial values
            // assigned in
            // the connectionString passed to this constructor.
            // e.g. It's possible a bool property like PersistSecurityInfo
            // could be
            // initialized with an invalid string value which doesn't parse to
            // a bool.

            bool b = PersistSecurityInfo;
            b = Enlist;
            b = Pooling;
            b = RoundRobin;
            uint i = ConnectTimeout;
            i = MinPoolSize;
            i = MaxPoolSize;
            i = ConnectionLifetime;
	}

      public VirtuosoConnectionStringBuilder () : base ()
	{
	}

    public bool ODBC
    {
        get
        {
            object value;
            if (base.TryGetValue(ConnectionOptions.ODBC, out value))
            {
                if (value is bool)
                    return (bool)value;

				bool bVal;
				if (!bool.TryParse(value.ToString(), out bVal))
				    bVal = ConnectionOptions.DEFAULT_USE_ODBC;
				// Change the stored value type to bool.
				this[ConnectionOptions.ODBC] = bVal;
				return bVal;
			}
           return ConnectionOptions.DEFAULT_USE_ODBC;
        }
        set { this[ConnectionOptions.ODBC] = value; }
    }

    public string Server
    {
        get
        {
            string key = ConnectionOptions.DATASOURCE;
            if (ContainsKey(ConnectionOptions.SERVER))
               key = ConnectionOptions.SERVER;
            else if (ContainsKey(ConnectionOptions.ADDRESS))
               key = ConnectionOptions.ADDRESS;
            else if (ContainsKey(ConnectionOptions.NETWORKADDRESS))
               key = ConnectionOptions.NETWORKADDRESS;
            else if (ContainsKey(ConnectionOptions.HOST))
               key = ConnectionOptions.HOST;
             
            object value;
            if (base.TryGetValue(key, out value))
                return value.ToString();
            else
                return string.Empty;
        }
        set 
		{ 
            string key = ConnectionOptions.DATASOURCE;
            if (ContainsKey(ConnectionOptions.SERVER))
               key = ConnectionOptions.SERVER;
            else if (ContainsKey(ConnectionOptions.ADDRESS))
               key = ConnectionOptions.ADDRESS;
            else if (ContainsKey(ConnectionOptions.NETWORKADDRESS))
               key = ConnectionOptions.NETWORKADDRESS;
            else if (ContainsKey(ConnectionOptions.HOST))
               key = ConnectionOptions.HOST;

			this[key] = value; 
		}
    }

    public string UserId
    {
        get
        {
            string key = ConnectionOptions.USERID;
            if (ContainsKey(ConnectionOptions.UID))
               key = ConnectionOptions.UID;
            else if (ContainsKey(ConnectionOptions.USER_ID))
               key = ConnectionOptions.USER_ID;
             
            object value;
            if (base.TryGetValue(key, out value))
                return value.ToString();
            else
                return string.Empty;
        }
        set 
		{ 
            string key = ConnectionOptions.USERID;
            if (ContainsKey(ConnectionOptions.UID))
               key = ConnectionOptions.UID;
            else if (ContainsKey(ConnectionOptions.USER_ID))
               key = ConnectionOptions.USER_ID;
             
			this[key] = value; 
		}
    }

    public string Password
    {
        get
        {
            string key = ConnectionOptions.PASSWORD;
            if (ContainsKey(ConnectionOptions.PWD))
               key = ConnectionOptions.PWD;
             
            object value;
            if (base.TryGetValue(key, out value))
                return value.ToString();
            else
                return string.Empty;
        }
        set 
		{ 
            string key = ConnectionOptions.PASSWORD;
            if (ContainsKey(ConnectionOptions.PWD))
               key = ConnectionOptions.PWD;

			this[key] = value; 
		}
    }

    public string Database
    {
        get
        {
            string key = ConnectionOptions.DATABASE;
            if (ContainsKey(ConnectionOptions.INITIALCATALOG))
               key = ConnectionOptions.INITIALCATALOG;

            object value;
            if (base.TryGetValue(key, out value))
                return value.ToString();
            else
                return string.Empty;
        }
        set 
		{ 
            string key = ConnectionOptions.DATABASE;
            if (ContainsKey(ConnectionOptions.INITIALCATALOG))
               key = ConnectionOptions.INITIALCATALOG;

			this[key] = value; 
		}
    }

    public string Charset
    {
        get
        {
            object value;
            if (base.TryGetValue(ConnectionOptions.CHARSET, out value))
                return value.ToString();
            else
                return string.Empty;
        }
        set { this[ConnectionOptions.CHARSET] = value; }
    }

    public string Encrypt
    {
        get
        {
            object value;
            if (base.TryGetValue(ConnectionOptions.ENCRYPT, out value))
                return value.ToString();
            else
                return string.Empty;
        }
        set { this[ConnectionOptions.ENCRYPT] = value; }
    }

    public bool PersistSecurityInfo
    {
        get
        {
            string key = ConnectionOptions.PERSIST_SECURITY_INFO;
            if (ContainsKey(ConnectionOptions.PERSISTSECURITYINFO))
               key = ConnectionOptions.PERSISTSECURITYINFO;

            object value;
            if (base.TryGetValue(key, out value))
            {
                if (value is bool)
                    return (bool)value;

				bool bVal;
				if (!bool.TryParse(value.ToString(), out bVal))
				    bVal = ConnectionOptions.DEFAULT_PERSIST_SECURITY_INFO;
				// Change the stored value type to bool.
				this[key] = bVal;
				return bVal;
			}
           return ConnectionOptions.DEFAULT_PERSIST_SECURITY_INFO;

        }
        set 
		{ 
            string key = ConnectionOptions.PERSIST_SECURITY_INFO;
            if (ContainsKey(ConnectionOptions.PERSISTSECURITYINFO))
               key = ConnectionOptions.PERSISTSECURITYINFO;

			this[key] = value; 
		}
    }

    public uint ConnectTimeout
    {
        get
        {
            string key = ConnectionOptions.CONNECTION_TIMEOUT;
            if (ContainsKey(ConnectionOptions.CONNECTTIMEOUT))
               key = ConnectionOptions.CONNECTTIMEOUT;

            object value;
            if (base.TryGetValue(key, out value))
            {
               if (value is uint)
                   return (uint)value;

               uint uintVal; // Set to 0 if TryParse fails
               if (!uint.TryParse(value.ToString(), out uintVal))
                   uintVal = (uint)ConnectionOptions.DEFAULT_CONN_TIMEOUT;

               // Change the stored value type to uint.
               this[key] = uintVal;
               return uintVal;
            }
            else
               return (uint)ConnectionOptions.DEFAULT_CONN_TIMEOUT;


        }
        set 
		{ 
            string key = ConnectionOptions.CONNECTION_TIMEOUT;
            if (ContainsKey(ConnectionOptions.CONNECTTIMEOUT))
               key = ConnectionOptions.CONNECTTIMEOUT;

			this[key] = value; 
		}
    }

    public uint ConnectionLifetime
    {
        get
        {
            string key = ConnectionOptions.CONNECTION_LIFETIME;
            if (ContainsKey(ConnectionOptions.CONNECTIONLIFETIME))
               key = ConnectionOptions.CONNECTIONLIFETIME;

            object value;
            if (base.TryGetValue(key, out value))
            {
               if (value is uint)
                   return (uint)value;

               uint uintVal; // Set to 0 if TryParse fails
               if (!uint.TryParse(value.ToString(), out uintVal))
                   uintVal = (uint)ConnectionOptions.DEFAULT_CONN_LIFETIME;

               // Change the stored value type to uint.
               this[key] = uintVal;
               return uintVal;
            }
            else
               return (uint)ConnectionOptions.DEFAULT_CONN_LIFETIME;

        }
        set 
        { 
            string key = ConnectionOptions.CONNECTION_LIFETIME;
            if (ContainsKey(ConnectionOptions.CONNECTIONLIFETIME))
               key = ConnectionOptions.CONNECTIONLIFETIME;
            this[key] = value; 
        }
    }

    public uint MinPoolSize
    {
        get
        {
            string key = ConnectionOptions.MIN_POOL_SIZE;
            if (ContainsKey(ConnectionOptions.MINPOOLSIZE))
               key = ConnectionOptions.MINPOOLSIZE;

            object value;
            if (base.TryGetValue(key, out value))
            {
               if (value is uint)
                   return (uint)value;

               uint uintVal; // Set to 0 if TryParse fails
               if (!uint.TryParse(value.ToString(), out uintVal))
                   uintVal = (uint)ConnectionOptions.DEFAULT_MIN_POOL_SIZE;

               // Change the stored value type to uint.
               this[key] = uintVal;
               return uintVal;
            }
            else
               return (uint)ConnectionOptions.DEFAULT_MIN_POOL_SIZE;
        }
        set 
        { 
            string key = ConnectionOptions.MIN_POOL_SIZE;
            if (ContainsKey(ConnectionOptions.MINPOOLSIZE))
               key = ConnectionOptions.MINPOOLSIZE;
            this[key] = value; 
        }
    }

    public uint MaxPoolSize
    {
        get
        {
            string key = ConnectionOptions.MAX_POOL_SIZE;
            if (ContainsKey(ConnectionOptions.MAXPOOLSIZE))
               key = ConnectionOptions.MAXPOOLSIZE;

            object value;
            if (base.TryGetValue(key.ToString(), out value))
            {
               if (value is uint)
                   return (uint)value;

               uint uintVal; // Set to 0 if TryParse fails
               if (!uint.TryParse(value.ToString(), out uintVal))
                   uintVal = (uint)ConnectionOptions.DEFAULT_MAX_POOL_SIZE;

               // Change the stored value type to uint.
               this[key] = uintVal;
               return uintVal;
            }
            else
               return (uint)ConnectionOptions.DEFAULT_MAX_POOL_SIZE;
        }
        set 
        { 
            string key = ConnectionOptions.MAX_POOL_SIZE;
            if (ContainsKey(ConnectionOptions.MAXPOOLSIZE))
               key = ConnectionOptions.MAXPOOLSIZE;
            this[key] = value; 
        }
    }

    public bool Pooling
    {
        get
        {
            object value;
            if (base.TryGetValue(ConnectionOptions.POOLING, out value))
            {
                if (value is bool)
                    return (bool)value;

				bool bVal;
				if (!bool.TryParse(value.ToString(), out bVal))
				    bVal = ConnectionOptions.DEFAULT_POOLING;
				// Change the stored value type to bool.
				this[ConnectionOptions.POOLING] = bVal;
				return bVal;
			}
           return ConnectionOptions.DEFAULT_POOLING;

        }
        set { this[ConnectionOptions.POOLING] = value; }
    }

    public bool Enlist
    {
        get
        {
            object value;
            if (base.TryGetValue(ConnectionOptions.ENLIST, out value))
            {
                if (value is bool)
                    return (bool)value;

				bool bVal;
				if (!bool.TryParse(value.ToString(), out bVal))
				    bVal = ConnectionOptions.DEFAULT_ENLIST;
				// Change the stored value type to bool.
				this[ConnectionOptions.ENLIST] = bVal;
				return bVal;
			}
           return ConnectionOptions.DEFAULT_ENLIST;

        }
        set { this[ConnectionOptions.ENLIST] = value; }
    }

    public bool RoundRobin
    {
        get
        {
            string key = ConnectionOptions.ROUND_ROBIN;
            if (ContainsKey(ConnectionOptions.ROUNDROBIN))
               key = ConnectionOptions.ROUNDROBIN;

            object value;
            if (base.TryGetValue(key, out value))
            {
                if (value is bool)
                    return (bool)value;

				bool bVal;
				if (!bool.TryParse(value.ToString(), out bVal))
				    bVal = ConnectionOptions.DEFAULT_ROUND_ROBIN;
				// Change the stored value type to bool.
				this[key] = bVal;
				return bVal;
			}
           return ConnectionOptions.DEFAULT_ROUND_ROBIN;

        }
        set 
        { 
           string key = ConnectionOptions.ROUND_ROBIN;
           if (ContainsKey(ConnectionOptions.ROUNDROBIN))
               key = ConnectionOptions.ROUNDROBIN;
           this[key] = value; 
        }
    }

#endregion
    }
}
