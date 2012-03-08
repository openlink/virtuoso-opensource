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
using System.Diagnostics;
using System.IO;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal sealed class ArrayOfLongPacked : IMarshal
	{
		private int[] array;

		internal ArrayOfLongPacked (int size)
		{
			array = new int[size];
		}

		internal int this [ int index ]
		{
			get { return array[index]; }
			set { array[index] = value; }
		}

		public void Marshal (Stream stream)
		{
			stream.WriteByte ((byte) BoxTag.DV_ARRAY_OF_LONG_PACKED);

			Marshaler.MarshalInt (stream, array.Length);
			for (int i = 0; i < array.Length; i++)
				Marshaler.MarshalInt (stream, array[i]);
		}
	}
}