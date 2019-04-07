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
	/// Parses a connection string.
	/// </summary>
	/// <remarks>
	/// <para>A <c>ConnectionStringParser</c> object parses a connection string obtained from the application
	/// and stores all the connection options taken from the string in a form more convenient for a later use
	/// by the provider.</para>
	///
	/// <para>The syntax of the connection string conforms to the OLE DB Data Link's one as specified by the
	/// OLE DB spec. Certain features of the syntax are never actually employed. For instance, the spec
	/// describes how to use names which contain the equal sign character. However, there are no known names
	/// that really contain it. Despite this, just for the sake of completeness, <c>ConnectionStringParser</c>
	/// supports all the features described in the spec.</para>
	///
	/// <para>The connection string consists of a sequence of settings. Each setting consists of a name and a
	/// value delimited by the equal sign. The pairs are separated by semicolons. Whitespace is ignored on
	/// either side of names and values alike.</para>
	///
	/// <para>The name part may contain any characters including semicolons. However any number of semicolons
	/// that go before any other legal name character is treated as settings separator and therefore is
	/// ignored. Semicolons that go after non-semicolon characters are included in the name. To specify a name
	/// containing an equal sign, the equal sign must be doubled. Names are case insensitive.</para>
	///
	/// <para>The value part may be unquoted or quoted by single or double quote characters. To include a
	/// semicolon, single quote, or double quote character into value, it must me enclosed in either type
	/// of quotes. To include the same quote character that encloses the value the character must be
	/// doubled.</para>
	/// </remarks>
	internal sealed class ConnectionStringParser
	{
		/// <summary>
		/// The connection string to parse.
		/// </summary>
		internal string source;

		/// <summary>
		/// The current position within the source string.
		/// </summary>
		internal int currentPosition;

		internal ConnectionStringParser ()
		{
		}

		/// <summary>
		/// Parse the connection string and fill the ConnectionsOptions object with
		/// the obtained information.
		/// </summary>
		/// <param name="connectionString">the connection string to parse</param>
		/// <param name="connectionOptions">the ConnectionOptions object to fill</param>
		internal void Parse (string connectionString, ConnectionOptions connectionOptions)
		{
			if (connectionString == null)
				throw new ArgumentException ("Null connection string argument.");

			StringBuilder secureConnectionString = new StringBuilder ();

			source = connectionString;
			currentPosition = 0;
			for (;;)
			{
				int start = currentPosition;

				string name = GetName ();
				if (name == null)
					break;

				string value = GetValue ();
				if (value == null)
					break;

				ConnectionOptions.Option option = connectionOptions.GetOption (name);
				if (option == null)
					throw new ArgumentException ("Unknown keyword in the connection string.");
				option.Set (value);

				if (!ConnectionOptions.IsSecuritySensitive (name))
					secureConnectionString.Append (source, start, currentPosition - start);
			}

			connectionOptions.ConnectionString = connectionString;
			connectionOptions.SecureConnectionString = secureConnectionString.ToString ();
		}

		/// <summary>
		/// Get the name part of the next setting.
		/// </summary>
		/// <returns>the name of the setting if any or the null oterwise.</returns>
		private string GetName ()
		{
			// skip leading whitespace and excess semicolons.
			for (;;)
			{
				if (!SkipWhiteSpace ())
					return null;
				if (source[currentPosition] != ';')
					break;
				currentPosition++;
			}

			int start = currentPosition, i = currentPosition;
			StringBuilder sb = new StringBuilder ();
			for (;;)
			{
				if (i == source.Length)
					throw new ArgumentException ("Invalid connection string: '" + source + "'.");

				char c = source[i++];
				if (!Char.IsWhiteSpace (c))
				{
					if (c == '=')
					{
						if (i < source.Length && source[i] == '=')
						{
							sb.Append (source, start, i - start);
							i++;
						}
						else
						{
							if (sb.Length == 0)
								throw new ArgumentException ("Missing keyword in the connection string.");

							currentPosition = i;
							return sb.ToString ();
						}
					}
					else
					{
						sb.Append (source, start, i - start);
					}
					start = i;
				}
			}
		}

		/// <summary>
		/// Get the value part of the next setting.
		/// </summary>
		/// <returns>the value of the setting if any or the null oterwise.</returns>
		private string GetValue ()
		{
			if (!SkipWhiteSpace ())
				return null;

			bool quoted = false;
			char quote = (char) 0;
			int start = currentPosition, i = currentPosition;
			StringBuilder sb = new StringBuilder ();
			for (;;)
			{
				if (quoted)
				{
					if (i == source.Length)
						throw new ArgumentException ("Invalid connection string: '" + source + "'.");

					char c = source[i++];
					if (c == quote)
					{
						if (i < source.Length && source[i] == quote)
						{
							sb.Append (c);
							i++;
						}
						else
						{
							quoted = false;
							start = i;
						}
					}
					else
					{
						sb.Append (c);
					}
				}
				else
				{
					if (i == source.Length)
					{
						currentPosition = i;
						return sb.ToString ();
					}

					char c = source[i++];
					if (!Char.IsWhiteSpace (c))
					{
						if (c == ';')
						{
							currentPosition = i;
							return sb.ToString ();
						}
						else if (c == '\'' || c == '\"')
						{
							if (i - 1 > start)
								sb.Append (source, start, i - start - 1);
							quoted = true;
							quote = c;
						}
						else
						{
							sb.Append (source, start, i - start);
						}
						start = i;
					}
				}
			}
		}

		private bool SkipWhiteSpace ()
		{
			while (currentPosition < source.Length)
			{
				if (!Char.IsWhiteSpace (source, currentPosition))
					return true;
				currentPosition++;
			}
			return false;
		}
	}
}
