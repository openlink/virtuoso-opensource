--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
--  
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--  
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--  
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--  
--  
delete from WS.WS.VFS_SITE where VS_HOST = 'www.foo.bar' and VS_ROOT = 'intsite';

delete from WS.WS.VFS_QUEUE where VQ_HOST = 'www.foo.bar' and VQ_ROOT = 'intsite';


insert into WS.WS.VFS_SITE (VS_DESCR,VS_HOST,VS_URL,VS_OWN,VS_ROOT,VS_NEWER,VS_DEL,
	 VS_FOLLOW,VS_NFOLLOW,VS_SRC,VS_OPTIONS,VS_METHOD,VS_OTHER)
	values ('Interesting sites', 'www.foo.bar', '/', 1, 'intsite', '1990-01-01', 'checked',
	 '/%;', '%.zip;%.tar;%.pdf;%.tgz;%.arj;', 'checked', null, null, 'checked');
	
insert into WS.WS.VFS_QUEUE (VQ_HOST,VQ_TS,VQ_URL,VQ_ROOT,VQ_STAT,VQ_OTHER)
        values ('www.foo.bar', now(), '/', 'intsite', 'waiting', null);  

create procedure 
DB.DBA.inthook (in host varchar, in collection varchar, out url varchar, in my_data any)
{
  declare next_url varchar;
  whenever not found goto done;
  declare cr cursor for select VQ_URL from WS.WS.VFS_QUEUE 
      where ((VQ_HOST = host and VQ_ROOT = collection) or VQ_OTHER = 'other') and VQ_STAT = 'waiting' 
      order by VQ_HOST, VQ_ROOT, VQ_TS for update;
  open cr;
  while (1)
    {
      fetch cr into next_url;
      if (get_keyword (host, my_data, null) is not null)
	{
          update WS.WS.VFS_QUEUE set VQ_STAT = 'pending' 
	      where VQ_HOST = host and VQ_ROOT = collection and VQ_URL = next_url;
          url := next_url;
          close cr;
          return 1;
	}
      else
	update WS.WS.VFS_QUEUE set VQ_STAT = 'retrieved' 
	    where VQ_HOST = host and VQ_ROOT = collection and VQ_URL = next_url;
    }
done:    
  close cr;
  return 0;
}
;

