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

create procedure ebay_demo_setup ()
{
  if (not exists (select 1 from SYS_USER_TYPES where UT_NAME = 'DB.DBA.eBayAPIInterfaceService'))
    {
      WSDL_IMPORT_UDT ('file:/tutorial/services/so_s_36/eBayTypes.wsdl', null, 1);
      WSDL_IMPORT_UDT ('file:/tutorial/services/so_s_36/eBaySvc.wsdl', null, 1);
    }
  if (not exists (select 1 from SYS_KEYS where KEY_TABLE = 'DB.DBA.ebay_cat_cache'))
    exec ('create table ebay_cat_cache (cat varchar primary key, parent varchar, cat_name varchar, dt long varchar)');
}
;

ebay_demo_setup ()
;

create procedure getCategories (in cat_parent varchar := null, in cat_level int := 1)
{
  declare svc eBayAPIInterfaceService;
  declare req, additem, cred, item soap_parameter;
  declare resp, ret any;
  declare appid, devid, certid, uid, pwd varchar;
  appid := connection_get ('appid');
  devid := connection_get ('devid');
  certid := connection_get ('certid');
  uid := connection_get ('uid');
  pwd := connection_get ('pwd');
  svc := new eBayAPIInterfaceService ();
  svc.debug := 0;
  req := new soap_parameter ();
  additem := new soap_parameter ();
  item := new soap_parameter ();
  req.set_xsd ('urn:ebay:api:eBayAPI:GetCategoriesRequestType');
  req.add_member ('Version', '349');
  req.add_member ('ErrorLanguage', 'en');
  req.add_member ('DetailLevel', vector (composite(), '', 'ReturnAll'));
  req.add_member ('', NULL);
  req.add_member ('CategorySiteID', '0');
  req.add_member ('CategoryParent', cat_parent);
  req.add_member ('LevelLimit', cat_level);
  req.add_member ('ViewAllNodes', soap_boolean(1));
  cred := new soap_parameter ();
  cred.set_xsd ('urn:ebay:apis:eBLBaseComponents:CustomSecurityHeaderType');
  cred.add_member ('eBayAuthToken', null);
  cred.add_member ('HardExpirationWarning', null);
  cred.add_member ('Credentials',
	soap_box_structure ('AppId', appid,'DevId', devid,'AuthCert', certid,'Username', uid,'Password', pwd));
  svc.url := svc.url || sprintf ('?callname=GetCategories&siteid=0&appid=%s&version=349', appid);
  ret := svc.GetCategories (cred.s, req.s, resp);
  return xml_tree_doc (ret);
}
;


create procedure ebay_root_cat (in path varchar)
{
  declare xt, xp any;
  if (exists (select 1 from ebay_cat_cache where cat = parent))
    {
      declare arr any;
      arr := vector ();
      for select dt from ebay_cat_cache where parent = cat order by cat_name do
       {
         arr := vector_concat (arr, vector (xml_tree_doc (dt)));
       }
      return arr;
    }
  xt := getCategories (null, 1);
  xp := xpath_eval ('//Category', xt, 0);
  foreach (any x in xp) do
    {
      declare cate, parent, cate_name any;
      cate := cast (xpath_eval ('//CategoryID/text()', xml_cut (x), 1) as varchar);
      cate_name := cast (xpath_eval ('//CategoryName/text()', xml_cut (x), 1) as varchar);
      parent := cast (xpath_eval ('//CategoryParentID/text()', xml_cut (x), 1) as varchar);
      insert soft ebay_cat_cache values (cate, parent, cate_name, xml_cut(x));
    }
  return xp;
}
;

create procedure ebay_child_cat (in node_name varchar, in node varchar)
{
  declare xt, lev, cate, parent, cate_name any;
  xt := cast (xpath_eval ('//LeafCategory/text()', xml_cut (node), 1) as varchar);
  lev := cast (xpath_eval ('//CategoryLevel/text()', xml_cut (node), 1) as int);
  cate := cast (xpath_eval ('//CategoryID/text()', xml_cut (node), 1) as varchar);
  parent := cast (xpath_eval ('//CategoryParentID/text()', xml_cut (node), 1) as varchar);
  cate_name := cast (xpath_eval ('//CategoryName/text()', xml_cut (node), 1) as varchar);
  if (cate is not null)
    insert soft ebay_cat_cache values (cate, parent, cate_name, node);
  if (xt = 'false' and exists (select 1 from ebay_cat_cache where parent = cate and parent <> cat))
    {
      declare arr any;
      arr := vector ();
      for select dt from ebay_cat_cache where parent = cate and parent <> cat order by cat_name do
       {
         arr := vector_concat (arr, vector (xml_tree_doc (dt)));
       }
      return arr;
    }
  else if (xt = 'false')
   {
      declare xp any;
      xp := xpath_eval ('//Category', getCategories (cate, lev + 1), 0);
      foreach (any x in xp) do
       {
         declare cate, parent, cate_name any;
         cate := cast (xpath_eval ('//CategoryID/text()', xml_cut (x), 1) as varchar);
         cate_name := cast (xpath_eval ('//CategoryName/text()', xml_cut (x), 1) as varchar);
         parent := cast (xpath_eval ('//CategoryParentID/text()', xml_cut (x), 1) as varchar);
         insert soft ebay_cat_cache values (cate, parent, cate_name, xml_cut(x));
       }
      return xp;
   }
  return null;
}
;

