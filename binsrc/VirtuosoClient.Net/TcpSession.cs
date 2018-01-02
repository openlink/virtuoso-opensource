//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2018 OpenLink Software
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
using System.Diagnostics;
using System.IO;
using System.Net.Sockets;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
#if DEBUG_IO
	internal class DebugStream : Stream
	{
		private Stream stream;

		private static BooleanSwitch ioSwitch;

		static DebugStream ()
		{
			ioSwitch = new BooleanSwitch ("VirtuosoClient.IO", "Socket IO");
			Debug.AutoFlush = true; // work around web.config ignoring autoflush
		}

		internal DebugStream (Stream stream)
		{
			Debug.Assert (stream != null);
			this.stream = stream;
		}

		public override bool CanRead
		{
			get { return stream.CanRead; }
		}

		public override bool CanSeek
		{
			get { return stream.CanSeek; }
		}

		public override bool CanWrite
		{
			get { return stream.CanWrite; }
		}

		public override long Length
		{
			get { return stream.Length; }
		}

		public override long Position
		{
			get { return stream.Position; }
			set { stream.Position = value; }
		}

		public override void Close ()
		{
		  Debug.WriteLineIf (CLI.FnTrace.Enabled, "DebugStream.Close ()");
			stream.Close ();
		}

		public override void Flush ()
		{
		        Debug.WriteLineIf (ioSwitch.Enabled, "DebugStream.Flush ()");
			stream.Flush ();
		}

		public override int Read (byte[] buffer, int offset, int count)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "DebugStream.Read (, " + offset + ", " + count + ")");
			count = stream.Read (buffer, offset, count);
			if (ioSwitch.Enabled)
			{
				Debug.Write ("Bytes: { ");
				WriteDebug (buffer, offset, count);
				Debug.WriteLine (" }, " + count);
			}
			return count;
		}

		public override int ReadByte ()
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "DebugStream.ReadByte ()");
			int rc = stream.ReadByte ();
			if (ioSwitch.Enabled)
			{
				Debug.Write ("rc: ");
				WriteReturnByteDebug (rc);
				Debug.WriteLine ("");
			}
			return rc;
		}

		public override long Seek (long offset, SeekOrigin origin)
		{
			return stream.Seek (offset, origin);
		}

		public override void SetLength (long value)
		{
			stream.SetLength (value);
		}

		public override void Write (byte[] buffer, int offset, int count)
		{
			if (ioSwitch.Enabled)
			{
				Debug.Write ("DebugStream.Write ({ ");
				WriteDebug (buffer, offset, count);
				Debug.WriteLine (" }, " + offset + ", " + count + ")");
			}
			stream.Write (buffer, offset, count);
		}

		public override void WriteByte (byte value)
		{
			if (ioSwitch.Enabled)
			{
				Debug.Write ("DebugStream.WriteByte (");
				WriteByteDebug (value);
				Debug.WriteLine (")");
			}
			stream.WriteByte (value);
		}

		private char[] hex = {'0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'};

		[Conditional ("DEBUG")]
		private void WriteByteDebug (byte value)
		{
			Debug.Write (hex[value / 16]);
			Debug.Write (hex[value % 16]);
		}

		[Conditional ("DEBUG")]
		private void WriteDebug (byte[] buffer, int offset, int count)
		{
			int i = offset;
			if (i < buffer.Length && i < offset + count)
			{
				WriteByteDebug (buffer[i]);
				for (i++; i < buffer.Length && i < offset + count; i++)
				{
					Debug.Write (' ');
					WriteByteDebug (buffer[i]);
				}
			}
		}

		[Conditional ("DEBUG")]
		private void WriteReturnByteDebug (int rc)
		{
			if (rc < 0)
				Debug.Write (rc);
			else
				WriteByteDebug ((byte) rc);
				
		}
	}
#endif

	internal class TcpStream : Stream
	{
		Socket socket;
		private byte[] input, output;
		private int inputLength, inputOffset, outputLength;
		private bool one_shot_non_blocking = false;

		internal TcpStream (Socket socket)
		{
			this.socket = socket;
			input = new byte[2000];
			output = new byte[2000];
		}

		public override bool CanRead
		{
			get { return true; }
		}

		public override bool CanSeek
		{
			get { return false; }
		}

		public override bool CanWrite
		{
			get { return true; }
		}

		public override long Length
		{
			get { return inputLength - inputOffset; }
		}

		public override long Position
		{
			get { throw new NotSupportedException (); }
			set { throw new NotSupportedException (); }
		}

		public override void Close ()
		{
			//socket.Close ();
		}

		public override void Flush ()
		{
			int outputOffset = 0;
			while (outputLength > 0)
			{
				int n = socket.Send (output, outputOffset, outputLength, SocketFlags.None);
				outputLength -= n;
				outputOffset += n;
			}
		}

		public override int Read (byte[] buffer, int offset, int count)
		{
			int readCount = 0;
			while (count > 0 && offset < buffer.Length)
			{
				if (inputOffset < inputLength)
				{
					buffer[offset++] = input[inputOffset++];
					readCount++;
					count--;
				}
				else if (count > input.Length)
				{
					int n = Receive (buffer, offset, count, SocketFlags.None);
					offset += n;
					readCount += n;
					count -= n;
				}
				else
				{
					inputLength = Receive (input, 0, input.Length, SocketFlags.None);
					inputOffset = 0;
				}
				one_shot_non_blocking = false;
			}
			return readCount;
		}

		public override long Seek (long offset, SeekOrigin origin)
		{
			throw new NotSupportedException ();
		}

		public override void SetLength (long value)
		{
			throw new NotSupportedException ();
		}

		public override void Write (byte[] buffer, int offset, int count)
		{
			while (count > 0 && offset < buffer.Length)
			{
				if (outputLength == output.Length)
					Flush ();
				output[outputLength++] = buffer[offset++];
				count--;
			}
		}

		internal void SetOneShotNonBlocking ()
		{
			one_shot_non_blocking = true;
		}

		private int Receive (byte[] buffer, int offset, int size, SocketFlags flags)
		{
			if (one_shot_non_blocking)
			{
				socket.Blocking = false;
			}
			try
			{
				while (true)
				{
					try
					{
                                                int len = socket.Receive(buffer, offset, size, flags);
                                                if (len == 0 && socket.Blocking)
                                                    throw new EndOfStreamException ();
                                                return len;
					}
					catch (SocketException e)
					{
						if (e.ErrorCode != 10004) // WSAEINTR
							throw;
					}
				}
			}
			finally
			{
				if (one_shot_non_blocking)
				{
					socket.Blocking = true;
				}
			}
		}
	}

	internal class TcpSession : ISession
	{
		private ManagedConnection connection;
		private Socket socket;
#if DEBUG_IO
		private TcpStream tcp_stream;
		private Stream stream;
#else
		private TcpStream stream;
#endif
		private bool written;
		private bool broken;

		internal TcpSession (ManagedConnection connection, Socket socket)
		{
			this.connection = connection;
			this.socket = socket;

#if DEBUG_IO
			tcp_stream = new TcpStream (socket);
			stream = new DebugStream (tcp_stream);
#else
			stream = new TcpStream (socket);
#endif
			written = false;
			broken = false;
		}

		internal bool IsBroken
		{
			get { return stream == null || broken; }
		}

		internal void Close ()
		{
			if (stream != null)
			{
				stream.Close ();
				stream = null;
			}
			socket = null;
		}

		public bool PollRead (int microSeconds)
		{
			if (stream.Length > 0)
				return true;
			try
			{
				return socket.Poll (microSeconds, SelectMode.SelectRead);
			}
			catch
			{
				broken = true;
				throw;
			}
		}

#if false
		/* Never used. */
		public bool PollWrite (int microSeconds)
		{
			try
			{
				return socket.Poll (microSeconds, SelectMode.SelectWrite);
			}
			catch
			{
				broken = true;
				throw;
			}
		}
#endif

#if false
		/* Socket timeout options don't work on Linux. Give it up in favor of Poll. */
		public int Timeout
		{
			get
			{
				return timeout;
			}
			set
			{
				if (socket == null)
					throw new InvalidOperationException ("Cannot set timeout for a closed TcpSession object.");
				if (timeout != value)
				{
					timeout = value;
#if !MONO
					socket.SetSocketOption (
					    SocketOptionLevel.Socket,
					    SocketOptionName.SendTimeout,
					    value);
					socket.SetSocketOption (
					    SocketOptionLevel.Socket,
					    SocketOptionName.ReceiveTimeout,
					    value);
#endif
				}
			}
		}
#endif

		public object Read ()
		{
			if (stream == null)
				throw new InvalidOperationException ("Cannot read from a closed TcpSession object.");
			if (written)
				throw new InvalidOperationException ("The session is not flushed.");
			try
			{
				return Marshaler.Unmarshal (stream, connection);
			}
			catch
			{
				broken = true;
				throw;
			}
		}

		public object ReadNonBlocking ()
		{
			// Make only the first read non-blocking.
			// With current unmarshaling code it will
			// be hard to recover from the case when
			// some data have already been read and then
			// comes a WSAEWOULDBLOCK SocketException.
			// So it won't work if we do just this:
			// socket.Blocking = false;
#if DEBUG_IO
			tcp_stream.SetOneShotNonBlocking ();
#else
			stream.SetOneShotNonBlocking ();
#endif
			return Read ();
		}

		public void Write (object value)
		{
			if (stream == null)
				throw new InvalidOperationException ("Cannot write to a closed TcpSession object.");
			try
			{
				Marshaler.Marshal (stream, connection.charsetMap, value);
			}
			catch
			{
				broken = true;
				throw;
			}
			written = true;
		}

		public void Flush ()
		{
			if (stream == null)
				throw new InvalidOperationException ("Cannot flush a closed TcpSession object.");
			try
			{
				stream.Flush ();
			}
			catch
			{
				broken = true;
				throw;
			}
			written = false;
		}
	}
}
