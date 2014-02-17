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
--  

create procedure register_soap (in uri varchar)
{
  declare bkey, skey, tkey varchar;
  declare business, service, tmodel, binding varchar;
  declare ent any;


  business := xml_uri_get (null, TUTORIAL_XSL_DIR () || '/tutorial/services/ud_s_3/be.xml');
  service := xml_uri_get (null, TUTORIAL_XSL_DIR () || '/tutorial/services/ud_s_3/bs.xml');
  tmodel := xml_uri_get (null, TUTORIAL_XSL_DIR () || '/tutorial/services/ud_s_3/tm.xml');
  binding := xml_uri_get (null, TUTORIAL_XSL_DIR () || '/tutorial/services/ud_s_3/bnd.xml');

  ent := uddi..uddi_str_get (uri, business);
  ent := xml_tree_doc (ent);
  bkey := xpath_eval ('//@businessKey', ent, 1);
  service := replace (service, '\$BK', cast (bkey as varchar));


  ent := uddi..uddi_str_get (uri, service);
  ent := xml_tree_doc (ent);
  skey := xpath_eval ('//@serviceKey', ent, 1);


  ent := uddi..uddi_str_get (uri, tmodel);
  ent := xml_tree_doc (ent);
  tkey := xpath_eval ('//@tModelKey', ent, 1);

  binding := replace (binding, '\$BK', cast (bkey as varchar));
  binding := replace (binding, '\$SK', cast (skey as varchar));
  binding := replace (binding, '\$TK', cast (tkey as varchar));


  ent := uddi..uddi_str_get (uri, binding);
}
