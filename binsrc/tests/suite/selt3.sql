--
--  selt3.sql
--
--  $Id: selt3.sql,v 1.3.10.1 2013/01/02 16:14:56 source Exp $
--
--  checkpoint errors #3.

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
--  

--  (C)Copyright 2005 OpenLink Software.
--  All Rights Reserved.
--
--  The copyright above and this notice must be preserved in all
--  copies of this source code.  The copyright above does not
--  evidence any actual or intended publication of this source code.
--
--  This is unpublished proprietary trade secret of OpenLink Software.
--  This source code may not be copied, disclosed, distributed, demonstrated
--  or licensed except as authorized by OpenLink Software.
--
set autocommit manual;
select * from t1 order by fi2;
commit work;
