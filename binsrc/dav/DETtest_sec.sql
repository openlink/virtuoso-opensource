--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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

set echo on;
set verbose off;

#delete from WS.WS.SYS_DAV_PROP;
#delete from WS.WS.SYS_DAV_RES where (not (RES_FULL_PATH like '%/TDAV%')) and not (RES_FULL_PATH like '%/VAD%');
#set triggers off;
#delete from WS.WS.SYS_DAV_COL where COL_ID is null;
#set triggers on;
#delete from WS.WS.SYS_DAV_COL a where COL_PARENT and not (COL_NAME like 'TDAV%') and not exists (select 1 from WS.WS.SYS_DAV_COL b where b.COL_PARENT = a.COL_ID) and not exists (select 1 from WS.WS.SYS_DAV_RES r where r.RES_COL = a.COL_ID);
#delete from WS.WS.SYS_DAV_COL a where COL_PARENT and not (COL_NAME like 'TDAV%') and not exists (select 1 from WS.WS.SYS_DAV_COL b where b.COL_PARENT = a.COL_ID) and not exists (select 1 from WS.WS.SYS_DAV_RES r where r.RES_COL = a.COL_ID);
#delete from WS.WS.SYS_DAV_COL a where COL_PARENT and not (COL_NAME like 'TDAV%') and not exists (select 1 from WS.WS.SYS_DAV_COL b where b.COL_PARENT = a.COL_ID) and not exists (select 1 from WS.WS.SYS_DAV_RES r where r.RES_COL = a.COL_ID);
#delete from WS.WS.SYS_DAV_COL a where COL_PARENT and not (COL_NAME like 'TDAV%') and not exists (select 1 from WS.WS.SYS_DAV_COL b where b.COL_PARENT = a.COL_ID) and not exists (select 1 from WS.WS.SYS_DAV_RES r where r.RES_COL = a.COL_ID);
#delete from WS.WS.SYS_DAV_COL a where COL_PARENT and not (COL_NAME like 'TDAV%') and not exists (select 1 from WS.WS.SYS_DAV_COL b where b.COL_PARENT = a.COL_ID) and not exists (select 1 from WS.WS.SYS_DAV_RES r where r.RES_COL = a.COL_ID);

select DAV_ADD_GROUP ('g1', 'dav', 'dav');
select DAV_ADD_GROUP ('g2', 'dav', 'dav');
select DAV_ADD_USER ('u1g1', 'u1g1_pwd', 'g1', '110100000T', 0, '/DAV/home/u1g1/', 'User 1 of group 1', 'u1g1@localhost', 'dav', 'dav');
select DAV_ADD_USER ('u2g1', 'u2g1_pwd', 'g1', '110100000T', 0, '/DAV/home/u2g1/', 'User 2 of group 1', 'u2g1@localhost', 'dav', 'dav');
select DAV_ADD_USER ('u1g2', 'u1g2_pwd', 'g2', '110100000T', 0, '/DAV/home/u1g2/', 'User 1 of group 2', 'u1g2@localhost', 'dav', 'dav');
select DAV_ADD_USER ('u2g2', 'u2g2_pwd', 'g2', '110100000T', 0, '/DAV/home/u2g2/', 'User 2 of group 2', 'u2g2@localhost', 'dav', 'dav');

select DAV_COL_CREATE ('/DAV/home/u1g1/', '110100000R', 'u1g1', 'g1', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/home/u2g1/', '110100000R', 'u2g1', 'g1', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/home/u1g2/', '110100000R', 'u1g2', 'g2', 'dav', 'dav');
select DAV_COL_CREATE ('/DAV/home/u2g2/', '110100000R', 'u2g2', 'g2', 'dav', 'dav');

select DAV_RES_UPLOAD ('/DAV/home/u1g1/DETtest_u1g1.htm', '<html>This is /DAV/u1g1_home/DETtest_u1g1.htm</html>', '', '110100000R', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u2g1/DETtest_u2g1.htm', '<html>This is /DAV/u1g1_home/DETtest_u2g1.htm</html>', '', '110100000R', 'u2g1', 'g1', 'u2g1', 'u2g1_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u1g2/DETtest_u1g2.htm', '<html>This is /DAV/u1g1_home/DETtest_u1g2.htm</html>', '', '110100000R', 'u1g2', 'g2', 'u1g2', 'u1g2_pwd' );
select DAV_RES_UPLOAD ('/DAV/home/u2g2/DETtest_u2g2.htm', '<html>This is /DAV/u1g1_home/DETtest_u2g2.htm</html>', '', '110100000R', 'u2g2', 'g2', 'u2g2', 'u2g2_pwd' );

create function DAV_TESTED_MASKS ()
{
  return vector (
    '100000000',
    '010000000',
    '001000000',
    '000100000',
    '000010000',
    '000001000',
    '000000100',
    '000000010',
    '000000001',
    '110000000',
    '111000000',
    '111100000',
    '111110000',
    '111111000',
    '111111100',
    '111111110',
    '111111111',
    '110100000',
    '110100100',
    '110110100',
    '110110110',
    '000000000' );
}
;

create procedure DAV_RES_GAMMA (in path_pattern varchar)
{
  declare masks any;
  masks := DAV_TESTED_MASKS();
  foreach (varchar mask in masks) do
    {
      declare path varchar;
      path := sprintf (path_pattern, mask);
      DAV_RES_UPLOAD (path, '<html>This is ' || path || '</html>', '', mask || 'R', 'u1g1', 'g1', 'u1g1', 'u1g1_pwd' );
      DAV_PROP_SET_INT (path, 'http://local.virt/DAV-RDF',
        DAV_RDF_PREPROCESS_RDFXML (
	  xtree_doc (
	    '<N3 N3S="http://local.virt/this" N3P="http://purl.org/rss/1.0/link">' || path || '</N3>' ),
          N'http://local.virt/this', 1 ),
        'dav', 'dav', 0, 0, 1 );
    }
}
;

create procedure DAV_COL_GAMMA (in path_pattern varchar)
{
  declare masks any;
  masks := DAV_TESTED_MASKS();
  foreach (varchar mask in masks) do
    {
      declare path varchar;
      declare c_id integer;
      path := sprintf (path_pattern, mask);
      c_id := DAV_COL_CREATE (path, '111111111R', 'u1g1', 'g1', 'dav', 'dav');
      DAV_RES_GAMMA (path || '%s.html');
      update WS.WS.SYS_DAV_COL set COL_PERMS = mask || 'R' where COL_ID = c_id;
    }
}
;

select DAV_COL_CREATE ('/DAV/gamma/', '111111111R', 'u1g1', 'g1', 'dav', 'dav');
DAV_COL_GAMMA ('/DAV/gamma/%s/');
