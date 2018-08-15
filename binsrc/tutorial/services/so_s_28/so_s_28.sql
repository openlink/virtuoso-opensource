--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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
create procedure Demo.demo.Customers_ext_table_create(){
  declare stm,msg varchar;
  
  exec('
    CREATE TABLE  Demo.demo.Customers_ext(
      Longitude   REAL NULL,
      Latitude     REAL NULL,
      PosCheckSum CHAR(32), 
    
      UNDER Demo.demo.Customers
    )
  ',stm,msg);
};

Demo.demo.Customers_ext_table_create();

INSERT REPLACING Demo.demo.Customers_ext (CustomerID, CompanyName, ContactName, ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax)
 SELECT CustomerID, CompanyName, ContactName, ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax
    FROM Demo.demo.Customers
   WHERE Country = 'USA';

create procedure Demo.demo.Customer_map_point (
                 in street VARCHAR := '',
                 in city VARCHAR := '',
                 in state VARCHAR := '',
                 in zip  INT := 0)
{
  declare res,hdr,ret any;
  declare tmp1, tmp2 any;
  declare lat, lng double precision;
  
  declare exit handler for SQLSTATE '*' {
     return vector(null,null);
  };
  
   hdr := null;
   ret := string_output();
   res := http_get (sprintf ('http://api.local.yahoo.com/MapsService/V1/geocode?appid=YahooDemo&street=%U&city=%U&state=%U&zip=%d',
     street,city,state,zip), hdr);
     
   ret := xtree_doc (res);
   tmp1 := cast(xpath_eval ('//Longitude/text()', ret) as varchar);
   tmp2 := cast(xpath_eval ('//Latitude/text()', ret) as varchar);
   
   if (tmp1 is null)
     lng := null;
   else
      lng := cast (tmp1 as double precision);

   if (tmp2 is null)
     lat := null;
   else
      lat := cast (tmp2 as double precision);
     
   return vector(lng,lat);
};

create procedure Demo.demo.Customers_fill_map_point(){
  declare pos any;
  for(SELECT CustomerID as CID, Address, City, Region, PostalCode from Demo.demo.Customers_ext
       WHERE Longitude is null or Latitude is null or PosCheckSum <> md5(Address, City, Region, PostalCode))do
  {
    pos := Demo.demo.Customer_map_point(Address, City, Region, cast(regexp_match('[0-9]{4,5}',PostalCode) as integer));
    UPDATE Demo.demo.Customers_ext
       SET Longitude = pos[0],
            Latitude = pos[1],
            PosCheckSum = md5(Address, City, Region, PostalCode)
     WHERE CustomerID = CID;
  };
  
};

Demo.demo.Customers_fill_map_point();
