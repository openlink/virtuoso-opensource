--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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



create procedure kwd (in k1 int, inout k2 int, in k3 int)
{
  result_names (k1, k2, k3);
  result (k1, k2, k3);
}


kwd ();
kwd (k2=>1);
kwd (k2=>1+2);
kwd (1,2,3);
kwd (1,1+1,3);
kwd (k3=>3, k1=>1,k2=>1+1);
kwd (1, k2=>1+1);
kwd (1);
kwd (badkey=>2, k2=>2+1);
