--  
--  $Id$
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
insert replacing Demo.demo.Shippers(ShipperID, CompanyName, Phone)
    VALUES(1, 'Speedy Express', '(503) 555-9831');

insert replacing Demo.demo.Shippers(ShipperID, CompanyName, Phone)
    VALUES(2, 'United Package', '(503) 555-3199');

insert replacing Demo.demo.Shippers(ShipperID, CompanyName, Phone)
    VALUES(3, 'Federal Shipping', '(503) 555-9931');

delete from Demo.demo.Shippers where ShipperID not in (1, 2, 3);

REPL_DROP_SNAPSHOT_PUB('Demo.demo.Shippers', 2);

REPL_SNP_SERVER('demoserver2', 'demo', 'demo');

rexecute('demoserver2', 'drop table "Shippers"');

create procedure re_sb_4_init()
{
  REPL_CREATE_SNAPSHOT_PUB('Demo.demo.Shippers', 2);
  declare _server varchar;
  _server := REPL_SERVER_NAME ('demoserver2');
  REPL_CREATE_SNAPSHOT_SUB(_server, 'Demo.demo.Shippers', 2, 'demo', 'demo');
};

re_sb_4_init();
