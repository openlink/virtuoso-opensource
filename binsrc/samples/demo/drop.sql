--  
--  $Id$
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
create procedure drop_old_doc ()
{

  delete from WS.WS.SYS_DAV_RES
  where RES_FULL_PATH like '/DAV/doc/html/%';

  delete from WS.WS.SYS_DAV_RES
  where RES_FULL_PATH like '/DAV/doc/images/%';

}
;


create procedure exec_no_error (in expr varchar) {
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
}
;

drop_old_doc();
exec_no_error ('drop procedure drop_old_doc');
exec_no_error ('DROP TABLE document_search_d_txt_WORDS');
exec_no_error ('DROP TABLE document_search');
