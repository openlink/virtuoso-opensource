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
using System.Diagnostics;
using System.Runtime.InteropServices;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal sealed class ParameterData : IDisposable
	{
		internal readonly static BooleanSwitch Switch = 
		    new BooleanSwitch ("VirtuosoClient.ManagedConnection", "Marshaling");
		internal VirtuosoParameterCollection parameters;
		internal int[] offset;
		internal int[] length;
		internal MemoryHandle buffer;

		internal ParameterData (VirtuosoParameterCollection parameters)
		{
			this.parameters = parameters;
			Initialize ();
		}

		~ParameterData ()
		{
			Dispose (false);
		}

		public void Dispose ()
		{
			Dispose(true);
			GC.SuppressFinalize(this);
		}

		private void Dispose (bool disposing)
		{
			if (disposing)
			{
				if (buffer != null)
					buffer.Dispose ();
			}
			parameters = null;
			offset = null;
			length = null;
			buffer = null;
		}

		private void Initialize ()
		{
			offset = new int[parameters.Count];
			length = new int[parameters.Count];
			int totalLength = 4 * parameters.Count;
			for (int i = 0; i < parameters.Count; i++)
			{
				VirtuosoParameter param = (VirtuosoParameter) parameters[i];

				object value = param.Value;
				if (param.bufferType == null)
				{
					if (param.paramType != null)
						param.bufferType = param.paramType.bufferType;
					else if (value == null || Convert.IsDBNull (value))
						param.bufferType = VirtuosoParameter.defaultType.bufferType;
					else
					{
						param.bufferType = BufferTypes.InferBufferType (value);
						if (param.bufferType == null)
							throw new InvalidOperationException ("Cannot infer parameter type");
					}
				}
				value = param.bufferType.ConvertValue (value);

				int paramLength = 0;
				if (param.Direction == ParameterDirection.Input)
				{
					if (value == null || Convert.IsDBNull (value))
						continue;

					int valueLength = param.bufferType.GetBufferSize (value);
					if (param.Size == 0)
						paramLength = valueLength;
					else
					{
						paramLength = param.bufferType.GetBufferSize (param.Size);
						if (paramLength > valueLength)
							paramLength = valueLength;
					}
				}
				else
				{
					if (param.Size == 0)
					{
						if (!param.bufferType.isFixedSize)
						{
							if (param.Direction != ParameterDirection.InputOutput
								|| value == null || Convert.IsDBNull (value))
								throw new InvalidOperationException ("Cannot determine the parameter size.");
						}
						paramLength = param.bufferType.GetBufferSize (value);
					}
					else
						paramLength = param.bufferType.GetBufferSize (param.Size);
				}

				if (param.bufferType.alignment > 1)
				{
					totalLength += param.bufferType.alignment - 1;
					totalLength -= totalLength % param.bufferType.alignment;
				}

				offset[i] = totalLength;
				length[i] = paramLength;
				totalLength += paramLength;
			}

			buffer = new MemoryHandle (totalLength);
		}

		internal void SetParameters (VirtuosoConnection connection, IntPtr hstmt)
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ParameterData.SetParameters()");
			for (int i = 0; i < parameters.Count; i++)
			{
				VirtuosoParameter param = (VirtuosoParameter) parameters[i];
				Debug.WriteLineIf (Switch.Enabled, "  param: " + param.paramName);

				CLI.InOutType ioType;
				switch (param.Direction)
				{
					default:
					// case ParameterDirection.Input:
						ioType = CLI.InOutType.SQL_PARAM_INPUT;
						break;
					case ParameterDirection.InputOutput:
						ioType = CLI.InOutType.SQL_PARAM_INPUT_OUTPUT;
						break;
					case ParameterDirection.Output:
					case ParameterDirection.ReturnValue:
						ioType = CLI.InOutType.SQL_PARAM_OUTPUT;
						break;
				}
				Debug.WriteLineIf (Switch.Enabled, "  direction: " + param.Direction);

				IntPtr paramBuffer = buffer.GetAddress (offset[i]);
				int bufferLength = length[i];
				int lengthOffset = 4 * i;

				CLI.SqlType sqlType = (param.paramType != null ? param.paramType.sqlType : CLI.SqlType.SQL_UNKNOWN_TYPE);
				CLI.ReturnCode rc = (CLI.ReturnCode) CLI.SQLBindParameter (
					hstmt, (ushort) (i + 1),
					(short) ioType, (short) param.bufferType.sqlCType, (short) sqlType,
					(IntPtr) param.Size, param.Scale,
					paramBuffer, (IntPtr) bufferLength, buffer.GetAddress (lengthOffset));
				if (rc != CLI.ReturnCode.SQL_SUCCESS)
					Diagnostics.HandleResult (rc, CLI.HandleType.SQL_HANDLE_STMT, hstmt, connection);

				if (param.Direction == ParameterDirection.Input	|| param.Direction == ParameterDirection.InputOutput)
				{
					object value = param.bufferType.ConvertValue (param.Value);
					Debug.WriteLineIf (Switch.Enabled, "  value: " + param.Value);

					int dataLength;
					if (value == null)
						dataLength = (int) CLI.LengthCode.SQL_NULL_DATA;
					else if (Convert.IsDBNull (value))
						dataLength = (int) CLI.LengthCode.SQL_NULL_DATA;
					else
						dataLength = param.bufferType.ManagedToNative (value, paramBuffer, bufferLength);
					Marshal.WriteInt32 (buffer.Handle, lengthOffset, dataLength);
				}
			}
		}

		internal void GetParameters ()
		{
			Debug.WriteLineIf (CLI.FnTrace.Enabled, "ParameterData.GetParameters()");
			for (int i = 0; i < parameters.Count; i++)
			{
				VirtuosoParameter param = (VirtuosoParameter) parameters[i];
				if (param.Direction == ParameterDirection.ReturnValue
					|| param.Direction == ParameterDirection.Output
					|| param.Direction == ParameterDirection.InputOutput)
				{
					int dataLength = Marshal.ReadInt32 (buffer.Handle, 4 * i);
					if (dataLength > length[i])
						dataLength = length[i];

					if (dataLength == (int) CLI.LengthCode.SQL_NULL_DATA)
						param.paramData = DBNull.Value;
					else
						param.paramData = param.bufferType.NativeToManaged (
							buffer.GetAddress (offset[i]), dataLength);
				}
			}
		}
	}
}
