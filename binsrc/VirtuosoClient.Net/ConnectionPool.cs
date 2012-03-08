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
using System.Diagnostics;
using System.EnterpriseServices;
using System.Threading;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal sealed class ConnectionPool
	{
		internal readonly static BooleanSwitch Switch = 
		    new BooleanSwitch ("VirtuosoClient.ConnectionPool", "Marshaling");
		private IInnerConnection[] pool;
		private int size;
		private int minSize, maxSize;
		private int lifetime;
		private Timer expirationTimer;
		private ResourcePool dtcPool;
		private DateTime lastCleared = DateTime.MinValue;

		private static Hashtable poolMap;

		private ConnectionPool (ConnectionOptions options)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ConnectionPool.ctor ()");

			minSize = options.MinPoolSize;
			maxSize = options.MaxPoolSize;
			lifetime = options.ConnectionLifetime;

			expirationTimer = new Timer (new TimerCallback (ExpireConnections), null, 1000, 1000);

			if (options.Enlist)
				dtcPool = new ResourcePool (new ResourcePool.TransactionEndDelegate (this.DistributedTransactionEnd));
		}

		~ConnectionPool ()
		{
			ClearAllPools();
		}

		internal static ConnectionPool GetPool (ConnectionOptions options)
		{
			string connectionString = options.ConnectionString;

			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ConnectionPool.GetPool (" + connectionString + ")");

			lock (typeof (ConnectionPool))
			{
				if (poolMap == null)
					poolMap = new Hashtable (101);

				ConnectionPool pool = (ConnectionPool) poolMap[connectionString];
				if (pool == null)
				{
					pool = new ConnectionPool (options);
					poolMap[connectionString] = pool;
				}
				return pool;
			}
		}

		internal static void RemovePool (string connectionString)
		{
			lock (typeof (ConnectionPool))
			{
				poolMap.Remove (connectionString);
			}
		}

		internal static void ClearPool (string connectionString)
		{
            lock (typeof(ConnectionPool))
            {
                // Find the pool identified by connectionString
                if (poolMap == null)
                    return;
                ConnectionPool pool = (ConnectionPool)poolMap[connectionString];
                if (pool == null)
                    return;
                pool.ClearPool();
            }
		}

		internal static void ClearAllPools ()
		{
            lock (typeof(ConnectionPool))
            {
                if (poolMap == null)
                    return;

                IDictionaryEnumerator iter = poolMap.GetEnumerator();
                while (iter.MoveNext())
                {
                    ConnectionPool pool = (ConnectionPool) iter.Value;
                    if (pool != null)
                        pool.ClearPool();
                }
            }
		}

		private void ClearPool ()
		{
            lock (this)
            {
                for (int i = --size; i >= 0; i--)
                {
				    pool[i].Close ();
                }
                size = 0;

                // Set lastCleared so that any connections in use at the time
                // of this call, which were drawn from this pool, are closed
                // when they are returned via PutConnection.
                lastCleared = DateTime.Now;
            }
		}

		internal IInnerConnection GetConnection (ConnectionOptions options, VirtuosoConnection connection)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ConnectionPool.GetConnection ()");

			IInnerConnection innerConnection = null;

			if (options.Enlist && ContextUtil.IsInTransaction)
			{
				innerConnection = (IInnerConnection) dtcPool.GetResource ();
				if (innerConnection != null)
				{
					innerConnection.OuterConnectionWeakRef = new WeakReference (connection);
					return innerConnection;
				}
			}

			lock (this)
			{
				if (pool == null)
				{
					pool = new IInnerConnection[maxSize];
					for (int i = 0; i < minSize; i++)
					{
						innerConnection = connection.CreateInnerConnection (options, false);
						innerConnection.TimeStamp = DateTime.Now;
						PutConnection (innerConnection);
					}
				}

				if (size > 0)
					innerConnection = pool[--size];
			}

			if (innerConnection == null)
			{
				innerConnection = connection.CreateInnerConnection (options, true);
				innerConnection.TimeStamp = DateTime.Now;
			}
			else
			{
				innerConnection.OuterConnectionWeakRef = new WeakReference (connection);
#if MTS 
				if (options.Enlist && ContextUtil.IsInTransaction)
					connection.EnlistInnerConnection (innerConnection);
#endif			
			}

			return innerConnection;
		}

		internal void PutConnection (IInnerConnection innerConnection)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ConnectionPool.PutConnection ()");

            // Was connection in use when the pool was last cleared?
            // If so, don't return it to the pool.
            if (innerConnection.TimeStamp < lastCleared)
            {
				innerConnection.Close ();
                return;
            }

			innerConnection.OuterConnectionWeakRef = null;
			if (CanPool (innerConnection))
			{
				if (innerConnection.DistributedTransaction != null
					&& ContextUtil.IsInTransaction
					&& ContextUtil.TransactionId == (Guid) innerConnection.DistributedTransactionId)
					DoDtcPool (innerConnection);
				else
					DoPool (innerConnection);
			}
			else
			{
				innerConnection.Close ();
			}
		}

		private void DistributedTransactionEnd (object resource)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ConnectionPool.DistributedTransactionEnd ()");

			IInnerConnection innerConnection = (IInnerConnection) resource;

			innerConnection.OuterConnectionWeakRef = null;
			if (CanPool (innerConnection))
			{
				DoPool (innerConnection);
			}
			else
			{
				innerConnection.Close ();
			}
		}

		private bool CanPool (IInnerConnection innerConnection)
		{
			if (!innerConnection.IsValid ())
				return false;

			if (lifetime != 0)
			{
				DateTime endOfLifetime = innerConnection.TimeStamp + new TimeSpan (0, 0, lifetime);
				if (endOfLifetime < DateTime.Now)
					return false;
			}

			return true;
		}

		private void DoPool (IInnerConnection innerConnection)
		{
			try
			{
				innerConnection.Pool ();
			}
			catch
			{
				innerConnection.Close ();
				throw;
			}

			lock (this)
			{
				if (size < maxSize)
				{
					pool[size++] = innerConnection;
					return;
				}
			}

			innerConnection.Close ();
		}

		private void DoDtcPool (IInnerConnection innerConnection)
		{
			bool rc;
			try
			{
				rc = dtcPool.PutResource (innerConnection);
			}
			catch
			{
				rc = false;
			}

			if (!rc)
			{
				DoPool (innerConnection);
			}
				
		}

		private void ExpireConnections (object state)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ConnectionPool.ExpireConnections ()");

			IInnerConnection connectionToClose = null;
			lock (this)
			{
				if (pool == null)
					return;
				if (size > minSize)
					connectionToClose = pool[--size];
			}
			if (connectionToClose != null)
			{
				Debug.WriteLineIf (Switch.Enabled, "Closing an expired connection.");
				try
				{
					connectionToClose.Close ();
					connectionToClose.OuterConnectionWeakRef = null;
				}
				catch (Exception e)
				{
					Debug.WriteLineIf (Switch.Enabled, "Error closing expired connections: " + e);
					Trace.WriteLine ("Error closing expired connections: " + e);
				}
			}
		}
	}
}
