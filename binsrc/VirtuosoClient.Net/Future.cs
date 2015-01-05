//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2015 OpenLink Software
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
using System.Threading;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal class Future
	{
		internal readonly static BooleanSwitch Switch = 
		    new BooleanSwitch ("VirtuosoClient.Future", "Marshaling");

		private Service service;
		private object[] arguments;
		private int requestNo;
		private int timeout;
		private long endOfTime;
		private ArrayList results = null;
		private bool isComplete = false;
		private object error = null;

		private static int lastRequestNo = 0;

		internal Future (Service service, params object[] arguments)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "Future.ctor()");
			Debug.WriteLineIf (Switch.Enabled, "service: " + service.name);
			Debug.WriteLineIf (Switch.Enabled, "arguments: " + (arguments == null ? "null" : arguments.ToString ()));

			this.service = service;
			this.arguments = arguments;
			this.requestNo = System.Threading.Interlocked.Increment (ref lastRequestNo);
		}

		internal int RequestNo
		{
			get { return requestNo; }
		}

		internal bool IsAnswered
		{
			get { return results != null; }
		}

		internal void SendRequest (ISession session)
		{
			SendRequest (session, 0);
		}

		internal void SendRequest (ISession session, int timeout)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "Future.SendRequest (timeout = " + timeout + ")");
			Debug.Assert (session != null);

			object[] request = new object[RpcMessageLayout.DA_FRQ_LENGTH];
			request[RpcMessageLayout.DA_MESSAGE_TYPE] = (int) RpcTag.DA_FUTURE_REQUEST;
			request[RpcMessageLayout.FRQ_COND_NUMBER] = (int) requestNo;
			request[RpcMessageLayout.FRQ_ANCESTRY] = null;
			request[RpcMessageLayout.FRQ_SERVICE_NAME] = service.name;
			request[RpcMessageLayout.FRQ_ARGUMENTS] = arguments;

			if (timeout == 0)
			{
				endOfTime = 0;
				this.timeout = Timeout.Infinite;
			}
			else
			{
				endOfTime = DateTime.Now.Ticks + timeout * Values.TicksPerSec;
				this.timeout = timeout * Values.MillisPerSec;
			}
			Debug.WriteLineIf (Switch.Enabled, "requestNo: " + requestNo);

			lock (session)
			{
				session.Write (request);
				session.Flush ();
			}
		}

		// This can only be used in a naturally serialized context
		// that is when there is no chance to get a response to other
		// future request before this one. This is the case while
		// establishing the connection.
		internal object GetResultSerial (ISession session)
		{
			object[] answer = ReadAnswer (session, true);
			if (answer == null)
				return null;

			if (requestNo != (int) answer[RpcMessageLayout.RRC_COND_NUMBER])
				throw new SystemException ("Invalid future answer number.");

			error = Values.NullIfZero (answer[RpcMessageLayout.RRC_ERROR]);

			object value = answer[RpcMessageLayout.RRC_VALUE];
			if (value is object[])
				return ((object[]) value) [0];
			return value;
		}

		internal object GetResult (ISession session, FutureList futures)
		{
			return GetResult (session, futures, false);
		}

		internal object GetNextResult (ISession session, FutureList futures)
		{
			return GetResult (session, futures, true);
		}

		internal object GetResult (ISession session, FutureList futures, bool remove)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "Future.GetResult ()");

			bool locked = false;
			bool check_timeout = false;
			try
			{
				for (;;)
				{
					if (!locked)
					{
						Monitor.Enter (this);
						locked = true;
					}

					if (results != null && results.Count > 0)
					{
						object result = results[0];
						if (remove)
							results.RemoveAt (0);
						return result;
					}
					if (error != null)
					{
						if (error is bool && (bool) error)
							throw new SystemException ("Timeout expired.");
						throw new SystemException (error.ToString ());
					}
					if (isComplete)
						return null;

					if (endOfTime != 0)
					{
						if (check_timeout)
						{
							long now = DateTime.Now.Ticks;
							if (endOfTime > now)
							{
								timeout = (int) ((endOfTime - now) / Values.TicksPerSec);
							}
							else
							{
								Debug.WriteLineIf (Switch.Enabled, "future timed out: " + requestNo);
								error = true;
								
								Future cancel = new Future (Service.Cancel);
								cancel.SendRequest (session);

								throw new SystemException ("Timeout expired.");
							}
						}
						else
						{
							check_timeout = true;
						}
					}

					if (futures.ReadLock ())
					{
						try
						{
							bool read = session.PollRead (timeout);
							if (read)
							{
								object[] answer = ReadAnswer (session, false);
								if (answer != null)
								{
									int id = (int) answer[RpcMessageLayout.RRC_COND_NUMBER];
									Debug.WriteLineIf (Switch.Enabled, "RRC_COND_NUMBER: " + id);
									Future future = (Future) futures[id];
									if (future != null)
										future.HandleAnswer (answer);
								}
							}
						}
						finally
						{
							futures.ReadUnlock ();
						}
					}
					else
					{
						// Unlock so that HandleAnswer for this future
						// can be called from another thread.
						Monitor.Exit (this);
						locked = false;

						futures.ReadWait (timeout);
					}
				}
			}
			finally
			{
				if (locked)
				{
					Monitor.Exit (this);
				}
			}
		}

		private static object[] ReadAnswer (ISession session, bool blocking)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "Future.ReadAnswer ()");
			Debug.Assert (session != null);

			object response = null;
			if (blocking)
			{
				response = session.Read ();
			}
			else
			{
				try
				{
					response = session.ReadNonBlocking ();
				}
				catch (System.Net.Sockets.SocketException e)
				{
					if (e.ErrorCode == 10035) // WSAEWOULDBLOCK
						return null;
					throw;
				}
			}

			if (!(response is object[]))
				throw new SystemException ("Invalid future answer.");

			object[] answer = (object[]) response;
			if (answer.Length != RpcMessageLayout.DA_ANSWER_LENGTH)
				throw new SystemException ("Invalid future answer size.");

			RpcTag tag = (RpcTag) answer[RpcMessageLayout.DA_MESSAGE_TYPE];
			if (tag != RpcTag.DA_FUTURE_ANSWER && tag != RpcTag.DA_FUTURE_PARTIAL_ANSWER)
				throw new SystemException ("Invalid future answer type.");

			return answer;
		}

		private void HandleAnswer (object[] answer)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "Future.HandleAnswer (" + answer + ")");

			lock (this)
			{
				Debug.Assert (!isComplete);

				if ((RpcTag) answer[RpcMessageLayout.DA_MESSAGE_TYPE] == RpcTag.DA_FUTURE_ANSWER)
				{
					error = Values.NullIfZero (answer[RpcMessageLayout.RRC_ERROR]);
					isComplete = true;
				}

				object value = answer[RpcMessageLayout.RRC_VALUE];
				if (value is object[])
					value = ((object[]) value) [0];

				if (results == null)
					results = new ArrayList ();
				results.Add (value);
			}
		}
	}
}
