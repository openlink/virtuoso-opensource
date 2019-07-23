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

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal sealed class BlobHandle
	{
		internal int ask;
		internal int page;
		internal int length;
		internal int keyId;
		internal int fragNo;
		internal int dirPage;
		internal int timeStamp;
		internal object pages;
		internal BoxTag tag;

		internal int current_page;
		internal int current_position;

		internal BlobHandle (
			int ask,
			int page,
			int length,
			int keyId,
			int fragNo,
			int dirPage,
			int timeStamp,
			object pages,
			BoxTag tag)
		{
			this.ask = ask;
			this.page = page;
			this.length = length;
			this.keyId = keyId;
			this.fragNo = fragNo;
			this.dirPage = dirPage;
			this.timeStamp = timeStamp;
			this.pages = pages;
			this.tag = tag;
			Rewind ();
		}

		internal void Rewind ()
		{
			this.current_page = page;
			this.current_position = 0;
		}
	}
}
