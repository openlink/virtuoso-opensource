--
--  $Id: tspotlight.sql,v 1.5.10.1 2013/01/02 16:15:27 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

echo BOTH "STARTED: SPOTLIGHT test\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

select DAV_ADD_GROUP ('sp', 'dav', 'dav');

select DAV_ADD_USER ('user1', 'pass1', 'sp', '110100000RR', 0,  '/DAV/u1/', 'User 1', 'u1@localhost', 'dav', 'dav');

select DAV_RES_UPLOAD ('/DAV/u1/Image.jpg', file_to_string ('Image.jpg'), auth_uid=>'user1', auth_pwd=>'pass1', uid=>'user1');

select DAV_RES_UPLOAD ('/DAV/u1/Goro.jpg', file_to_string ('Goro.jpg'), auth_uid=>'user1', auth_pwd=>'pass1', uid=>'user1');

select DAV_RES_UPLOAD ('/DAV/u1/ring ring ring.mp3', file_to_string ('ring ring ring.mp3'), auth_uid=>'user1', auth_pwd=>'pass1', uid=>'user1');

create procedure check_res (in dav_path varchar, in _what varchar)
{

   declare _id, i int;
   declare _all, find any;

   if (__proc_exists ('SPOTLIGHT_METADATA',2) is null)
	return 1;


   select RES_ID into _id from WS.WS.SYS_DAV_RES where RES_FULL_PATH = dav_path;

   select xml_tree_doc (deserialize (PROP_VALUE)) into _all from WS.WS.SYS_DAV_PROP where PROP_PARENT_ID = _id;

   _all := xpath_eval ('//value/text()', _all, 0);
   dbg_obj_print (_all);
   for (i := 0; i < length (_all); i := i + 1)
	if (cast (_all[i] as varchar) = _what)
	   return 1;

   return 0;
}

select check_res ('/DAV/u1/Image.jpg', 'JPEG image');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": /DAV/u1/Image.jpg : JPEG Image $LAST[1]=" $LAST[1] " MESSAGE=" $MESSAGE "\n";

select check_res ('/DAV/u1/Image.jpg', '640.000000');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": /DAV/u1/Image.jpg : 640.000000 $LAST[1]=" $LAST[1] " MESSAGE=" $MESSAGE "\n";

select check_res ('/DAV/u1/Goro.jpg', 'public.jpeg');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": /DAV/u1/Goro.jpg : public.jpeg $LAST[1]=" $LAST[1] " MESSAGE=" $MESSAGE "\n";

--select check_res ('/DAV/u1/Goro.jpg', 'BlaBla');
--ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": /DAV/u1/Goro.jpg : BlaBla $LAST[1]=" $LAST[1] " MESSAGE=" $MESSAGE "\n";

select check_res ('/DAV/u1/ring ring ring.mp3', 'MP3 Audio File');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": /DAV/u1/ring ring ring.mp3 : MP3 Audio File $LAST[1]=" $LAST[1] " MESSAGE=" $MESSAGE "\n";

select check_res ('/DAV/u1/ring ring ring.mp3', 'Ring ring ring');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": /DAV/u1/ring ring ring.mp3 : Ring ring ring $LAST[1]=" $LAST[1] " MESSAGE=" $MESSAGE "\n";

select check_res ('/DAV/u1/ring ring ring.mp3', '22050.000000');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": /DAV/u1/ring ring ring.mp3 : 22050.000000 $LAST[1]=" $LAST[1] " MESSAGE=" $MESSAGE "\n";
