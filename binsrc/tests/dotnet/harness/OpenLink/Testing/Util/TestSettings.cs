//
//  $Id$
//
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//
//  Copyright (C) 1998-2016 OpenLink Software
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

using System;
using System.Collections;
using System.Collections.Specialized;
using System.Configuration;

namespace OpenLink.Testing.Util
{
	public sealed class TestSettings
	{
		/// <summary>
		/// Settings specified through the command line or set with the TestSettings.Set() method.
		/// </summary>
		private static HybridDictionary settings;

		/// <summary>
		/// Settings specified in a configuration file (in the "OpenLink.Testing" section).
		/// </summary>
		private static NameValueCollection configSettings;

		static TestSettings ()
		{
			settings = new HybridDictionary (true);
			configSettings = (NameValueCollection) ConfigurationSettings.GetConfig ("OpenLink.Testing");
		}

		private TestSettings ()	{} // disable instance construction

		public static void Set (string name, object value)
		{
			settings[name] = value;
		}

		public static object Get (string name)
		{
			object value = settings[name];
			if (value == null)
			{
				value = Environment.GetEnvironmentVariable (name);
				if (value == null && configSettings != null)
				{
					value = configSettings.Get (name);
				}
			}
			return value;
		}

		public static string GetString (string name)
		{
			return GetString (name, null);
		}

		public static string GetString (string name, string defaultValue)
		{
			object value = Get (name);
			if (value == null)
				return defaultValue;
			if (value is string)
				return (string) value;
			return value.ToString ();
		}

		public static bool GetBoolean (string name)
		{
			return GetBoolean (name, false);
		}

		public static bool GetBoolean (string name, bool defaultValue)
		{
			object value = Get (name);
			if (value == null)
				return defaultValue;
			if (value is bool)
				return (bool) value;
			return Convert.ToBoolean (value);
		}

		public static int GetInt32 (string name)
		{
			return GetInt32 (name, -1);
		}

		public static int GetInt32 (string name, int defaultValue)
		{
			object value = Get (name);
			if (value == null)
				return defaultValue;
			if (value is int)
				return (int) value;
			return Convert.ToInt32 (value);
		}

		public static string[] ProcessArguments (NameValueCollection map, string[] args)
		{
			ArrayList rest = null;
			string name = null;
			foreach (String arg in args)
			{
				if (name == null)
				{
					if (IsOption (arg[0]))
					{
						name = ProcessOption (map, arg);
					}
					else
					{
						if (rest == null)
							rest = new ArrayList ();
						rest.Add (arg);
					}
				}
				else
				{
					if (IsOption (arg[0]))
					{
						SetOption (map, name, "");
						name = ProcessOption (map, arg);
					}
					else
					{
						SetOption (map, name, arg);
						name = null;
					}
				}
			}
			if (name != null)
			{
				SetOption (map, name, "");
			}
			return rest == null ? null : (string[]) rest.ToArray (typeof (string));
		}

		private static string ProcessOption (NameValueCollection map, string arg)
		{
			int n_1 = arg.Length - 1;
			for (int i = 1; i < n_1; i++)
			{
				if (IsOptionValue (arg[i]))
				{
					SetOption (map, arg.Substring (1, i - 1), arg.Substring (i + 1));
					return null;
				}
			}
			if (n_1 > 0)
			{
				if (IsOptionValue (arg[n_1]))
					SetOption (map, arg.Substring (1, n_1 - 1), "");
				else if (IsTrueOptionValue (arg[n_1]))
					SetOption (map, arg.Substring (1, n_1 - 1), true);
				else if (IsFalseOptionValue (arg[n_1]))
					SetOption (map, arg.Substring (1, n_1 - 1), false);
				return null;
			}
			return arg.Substring (1);
		}

		private static void SetOption (NameValueCollection map, string name, object value)
		{
			if (map != null)
			{
				string mapped = map[name];
				if (mapped != null)
					name = mapped;
			}
			Set (name, value);
		}

		private static bool IsOption (char c)
		{
			return c == '-' || c == '/';
		}

		private static bool IsOptionValue (char c)
		{
			return c == '=' || c == ':';
		}

		private static bool IsTrueOptionValue (char c)
		{
			return c == '+';
		}

		private static bool IsFalseOptionValue (char c)
		{
			return c == '-';
		}
	}
}
