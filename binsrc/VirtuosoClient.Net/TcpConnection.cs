//  
// $Id$
//
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2013 OpenLink Software
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
using System.Net;
using System.Net.Sockets;
using System.Text;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal class TcpConnection : ManagedConnection
	{
		private static byte[] thePass = Encoding.ASCII.GetBytes ("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
		private static Random rnd = new Random(unchecked((int) (DateTime.Now.Ticks)));

		private TcpSession session = null;

		internal override ISession Session
		{
			get { return session; }
		}

		public override bool IsValid ()
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "TcpConnection.IsValid ()");

			if (session == null || session.IsBroken)
				return false;
			return true;
		}

		public override void Open (ConnectionOptions options)
		{
			Socket socket = new Socket (AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
			bool useRoundRobin = options.RoundRobin;
			int hostIndex = 0;
			int startIndex = 0;

	                charset_utf8 = (options.Charset != null && options.Charset.ToUpper() == "UTF-8");

			ArrayList ds_list = options.DataSourceList;
			if (ds_list != null)
			{
				if (ds_list.Count <= 1)
					useRoundRobin = false;

				if (ds_list.Count > 1 && useRoundRobin)
					startIndex = hostIndex = rnd.Next(ds_list.Count);

				while(true)
				{
			        	try {
			        		if (ds_list.Count == 0)
			        		{
							socket.Connect (GetEndPoint (null));
						}
						else
						{
							socket.Connect (GetEndPoint ((string)ds_list[hostIndex]));
						}
			        	        break;
			        	} catch (SocketException e) {
			        		hostIndex++;
			        		if (useRoundRobin)
			        		{
			        			if (ds_list.Count == hostIndex)
			        				hostIndex = 0;
			        			if (hostIndex == startIndex)
			        				throw e;
			        		}
			        		else if (ds_list.Count == hostIndex) // Failover mode last rec
			        		{
			        			throw e;
			        		}
			        	}
				}
			}

			try
			{
				session = new TcpSession (this, socket);
                		socket.NoDelay = true;

#if MONO
				Future future = new Future (Service.CallerId, new object[] { null });
#else
				Future future = new Future (Service.CallerId, (object) null); // not object[]
#endif
				future.SendRequest (session, options.ConnectionTimeout);
				object[] results = (object[]) future.GetResultSerial (session);
				peer = (string) results[1];

				object[] idOpts = null;
				if (results.Length > 2)
					idOpts = (object[]) results[2];
				int pwdClearCode = GetConnectionOption (idOpts, "SQL_ENCRYPTION_ON_PASSWORD", -1);
				Debug.WriteLineIf (Switch.Enabled, "pwdClearCode: " + pwdClearCode);

				string user = options.UserId;
				string password = null;
				if (pwdClearCode == 1)
					password = options.Password;
				else if (pwdClearCode == 2)
					password = MagicEncrypt (user, options.Password);
				else
					password = Digest (user, options.Password, peer);

				object[] info = new object[6];
				info[0] = ".NET Application";
				info[1] = 0;
				info[2] = Environment.MachineName;
				info[3] = ".NET";
				info[4] = options.Charset != null ? options.Charset.ToUpper () : "";
				info[5] = 0;
				future = new Future (Service.Connect, user, password, Values.VERSION, info);
				future.SendRequest (session, options.ConnectionTimeout);
				results = future.GetResultSerial (session) as object[];
				if (results == null)
					throw new SystemException ("Login failed.");
				switch ((AnswerTag) results[0])
				{
				case AnswerTag.QA_LOGIN:
					SetConnectionOptions (results);
					break;

				case AnswerTag.QA_ERROR:
					throw new SystemException (results[1].ToString () + " " + results[2].ToString ());

				default:
					throw new SystemException ("Bad login response.");
				}

				if (options.Database != null
					&& options.Database != String.Empty
					&& options.Database != currentCatalog)
					SetCurrentCatalog (options.Database);
			}
			catch (Exception)
			{
				Close ();
				throw;
			}
		}

		public override void Close ()
		{
			if (session != null)
			{
				session.Close ();
				session = null;
			}
			base.Close ();
		}

		private IPEndPoint GetEndPoint (string ds)
		{
			string host;
			int port;

			if (ds == null || ds == String.Empty)
			{
				host = Values.DEFAULT_HOST;
				port = Values.DEFAULT_PORT;
			}
			else
			{
				int colonIndex = ds.IndexOf (':');
				if (colonIndex < 0)
				{
					host = ds;
					port = Values.DEFAULT_PORT;
				}
				else
				{
					host = ds.Substring (0, colonIndex);
					port = Int32.Parse (ds.Substring (colonIndex + 1));
				}
			}
#if !ADONET2
			IPAddress address = Dns.Resolve (host).AddressList[0];
#else			
			IPAddress address = Dns.GetHostEntry (host).AddressList[0];
#endif			
			if (IPAddress.IsLoopback (address) || address.IsIPv6LinkLocal)
				address = IPAddress.Loopback;
			return new IPEndPoint (address, port);
		}

		internal static string Digest (string username, string password, string peername)
		{
			Encoding encoding = Encoding.GetEncoding ("iso-8859-1");
			if (encoding == null)
				throw new SystemException ("Cannot get iso-8859-1 encoding.");

			byte[] usernameBytes = encoding.GetBytes (username == null ? "" : username);
			byte[] passwordBytes = encoding.GetBytes (password == null ? "" : password);
			byte[] peernameBytes = encoding.GetBytes (peername == null ? "" : peername);

			MD5 md5 = new MD5 ();
			md5.Update (peernameBytes);
			md5.Update (usernameBytes);
			md5.Update (passwordBytes);

			byte[] digest = md5.Final ();
			return encoding.GetString (digest);
		}

		internal static string MagicEncrypt (string username, string password)
		{
			Encoding encoding = Encoding.GetEncoding ("iso-8859-1");
			if (encoding == null)
				throw new SystemException ("Cannot get iso-8859-1 encoding.");

			byte[] usernameBytes = encoding.GetBytes (username);
			byte[] passwordBytes = encoding.GetBytes (password);

			byte[] passwordBytes_1 = new byte[passwordBytes.Length + 1];
			passwordBytes_1[0] = 0;
			Array.Copy (passwordBytes, 0, passwordBytes_1, 1, passwordBytes.Length);
			XX_Encrypt (passwordBytes_1, 1, usernameBytes);

			return encoding.GetString (passwordBytes_1);
		}

		private static void XX_Encrypt (byte[] thing, int offset, byte[] username)
		{
			lock (thePass)
			{
				if (thePass[0] == 'x')
				{
					String s1 = "7rLrT7iG3kWWLuSDYdS/KIXO8JF86h12KyCTG1Mh0qxWdSZ6ezHRST0UuGl6xkbMgsXj4+eZbXNyYijRmoaaJm+hQCWSOW+0OHGCnYWB4upxi0Fogdu0gb+q4VFzyUFknEpZPg==";
					String s2 = "PCuJhpWX5eApg2mRs0bvSIdfwSDUa0kjiSdd76ORgXYyhtLbHm4Uq6afLbfROLi5pDpjKVS9Vr9aZo+F3IpyZ6Zn6m/Xf1PRtq3jdseJht4VSduxHrpocKVdRh3LixXKr6Ue6A==";
					byte[] pass1 = Encoding.ASCII.GetBytes (s1);
					byte[] pass2 = Encoding.ASCII.GetBytes (s2);
					for (int inx = 0; inx < pass2.Length; inx++)
					{
						thePass[inx] = (byte) (pass1[inx] ^ pass2[inx]);
						if (thePass[inx] == 0)
							thePass[inx] = pass1[inx];
					}
					thePass[136] = 0;
				}
			}

			MD5 md5 = new MD5();
			if (username != null && username[0] != 0)
				md5.Update (username);
			md5.Update (thePass);

			byte[] md5Bytes = md5.Final ();
			for (int thingIndex = offset, md5Index = 0; thingIndex < thing.Length; thingIndex++, md5Index++)
				thing[thingIndex] = (byte) (thing[thingIndex] ^ md5Bytes[md5Index % md5Bytes.Length]);
		}
	}
}
