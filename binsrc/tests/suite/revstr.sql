--
--  revstr.sql
--
--  $Id$
--
--  Stored Procedure to reverse a string argument
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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

create procedure revstr(in str varchar)
{ --  revstr('loop') -> 'pool' -- does this in place and modifies str arg!
    declare len,inx1,inx2,tmp integer;
    if(str is null) return(str);
    len := length(str);
    if(len < 2) return(str); -- '' and 'Q' remain same when reversed.
    inx1 := 0;     -- Index beginning from the left.
    inx2 := len-1; -- Index coming from the right (the end of the string).
    len  := len/2; -- Set the upper limit for inx1, pointing to middle.
    while(inx1 < len)
     {
       tmp := aref(str,inx1);
       aset(str,inx1,aref(str,inx2));
       aset(str,inx2,tmp);
       inx1 := inx1 + 1;
       inx2 := inx2 - 1;
     }
    return(str);
}
