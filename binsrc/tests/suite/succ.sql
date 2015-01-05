--
--  succ.sql
--
--  $Id: succ.sql,v 1.3.10.1 2013/01/02 16:14:58 source Exp $
--
--  Stored Procedure to increase the last character of the argument by one.
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

create procedure succ(in str varchar)
{ -- succ(str) - Increment the last character of str by one.
    declare len integer; -- e.g. succ('Beat') -> 'Beau'
    declare new_ending varchar;
    if(str is null) return(str);
    len := length(str);
    if(len = 0) return(str); -- Return empty strings back intact
    new_ending := make_string(1); -- Create a one character long string
    aset(new_ending,0,(aref(str,(len-1))+1)); -- Put a needed char. there
    if(len = 1) return(new_ending); -- No need for concatenation.
    else return(concatenate(subseq(str,0,(len-1)),new_ending));
};
