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

DB.DBA.DAV_COL_CREATE ('/DAV/test/', '110100000R', 'dav', 'administrators', 'dav', 'dav');

-- Test file system DET
DB.DBA.DAV_COL_CREATE ('/DAV/test/fs/', '110100000R', 'dav', 'administrators', 'dav', 'dav');
update WS.WS.SYS_DAV_COL set COL_DET='HostFs' where COL_ID = DAV_SEARCH_ID ('/DAV/test/fs/', 'C');

-- Test file system DET
DB.DBA.DAV_COL_CREATE ('/DAV/test/pf/', '110100000R', 'dav', 'administrators', 'dav', 'dav');
DB.DBA.DAV_COL_CREATE ('/DAV/test/pf/orig/', '110100000R', 'dav', 'administrators', 'dav', 'dav');
DB.DBA.DAV_COL_CREATE ('/DAV/test/pf/orig/sub1/', '110100000R', 'dav', 'administrators', 'dav', 'dav');
DB.DBA.DAV_COL_CREATE ('/DAV/test/pf/orig/sub2/', '110100000R', 'dav', 'administrators', 'dav', 'dav');
DB.DBA.DAV_COL_CREATE ('/DAV/test/pf/filter/', '110100000R', 'dav', 'administrators', 'dav', 'dav');
DB.DBA.DAV_PROP_SET ('/DAV/test/pf/filter/', 'virt:PropFilter-SearchPath', '/DAV/test/pf/orig/', 'dav', 'dav');
DB.DBA.DAV_PROP_SET ('/DAV/test/pf/filter/', 'virt:PropFilter-PropName', 'WikiV:ClusterName', 'dav', 'dav');
DB.DBA.DAV_PROP_SET ('/DAV/test/pf/filter/', 'virt:PropFilter-PropValue', 'Main', 'dav', 'dav');
update WS.WS.SYS_DAV_COL set COL_DET='PropFilter' where COL_ID = DAV_SEARCH_ID ('/DAV/test/pf/filter/', 'C');

DB.DBA.DAV_RES_UPLOAD ('/DAV/test/pf/orig/hit1.htm',
 '<html>This is /DAV/test/pf/orig/hit1.htm</html>',
 'text/html', '110100000R', 'dav', 'administrators', 'dav', 'dav' );

DB.DBA.DAV_RES_UPLOAD ('/DAV/test/pf/orig/hit2.htm',
 '<html>This is /DAV/test/pf/orig/hit2.htm</html>',
 'text/html', '110100000R', 'dav', 'administrators', 'dav', 'dav' );

DB.DBA.DAV_RES_UPLOAD ('/DAV/test/pf/orig/hit3.htm',
 '<html>This is /DAV/test/pf/orig/hit3.htm</html>',
 'text/html', '110100000R', 'dav', 'administrators', 'dav', 'dav' );

DB.DBA.DAV_RES_UPLOAD ('/DAV/test/pf/orig/sub1/hit2.htm',
 '<html>This is /DAV/test/pf/orig/sub1/hit2.htm</html>',
 'text/html', '110100000R', 'dav', 'administrators', 'dav', 'dav' );

DB.DBA.DAV_RES_UPLOAD ('/DAV/test/pf/orig/sub2/hit2.htm',
 '<html>This is /DAV/test/pf/orig/sub2/hit2.htm</html>',
 'text/html', '110100000R', 'dav', 'administrators', 'dav', 'dav' );

DB.DBA.DAV_RES_UPLOAD ('/DAV/test/pf/orig/miss1.htm',
 '<html>This is /DAV/test/pf/orig/miss1.htm</html>',
 'text/html', '110100000R', 'dav', 'administrators', 'dav', 'dav' );

DB.DBA.DAV_RES_UPLOAD ('/DAV/test/pf/orig/miss2.htm',
 '<html>This is /DAV/test/pf/orig/miss1.htm</html>',
 'text/html', '110100000R', 'dav', 'administrators', 'dav', 'dav' );

DB.DBA.DAV_PROP_SET ('/DAV/test/pf/orig/hit1.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');
DB.DBA.DAV_PROP_SET ('/DAV/test/pf/orig/hit2.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');
DB.DBA.DAV_PROP_SET ('/DAV/test/pf/orig/hit3.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');
DB.DBA.DAV_PROP_SET ('/DAV/test/pf/orig/sub1/hit2.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');
DB.DBA.DAV_PROP_SET ('/DAV/test/pf/orig/sub2/hit2.htm', 'WikiV:ClusterName', 'Main', 'dav', 'dav');

DB.DBA.DAV_PROP_SET ('/DAV/test/pf/orig/miss1.htm', 'WikiV:ClusterName', 'Wrong', 'dav', 'dav');
DB.DBA.DAV_PROP_SET ('/DAV/test/pf/orig/miss2.htm', 'WikiV:WrongName', 'Main', 'dav', 'dav');

-- Test RDF
DB.DBA.DAV_COL_CREATE ('/DAV/test/rdf/', '110110110R', 'dav', 'administrators', 'dav', 'dav');
DB.DBA.DAV_RES_UPLOAD ('/DAV/test/rdf/test.mp3',
 'This is not mp3 file!',
 'audio/mpeg', '110100000R', 'dav', 'administrators', 'dav', 'dav' );
DB.DBA.DAV_RES_UPLOAD ('/DAV/test/rdf/test.doc',
 'This is not mp3 file!',
 'application/msword', '110100000R', 'dav', 'administrators', 'dav', 'dav' );

