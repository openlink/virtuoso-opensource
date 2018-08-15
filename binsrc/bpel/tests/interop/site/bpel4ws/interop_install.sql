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
create procedure BPWSI.BPWSI.interop_navigation_root (in path varchar)
{
  return xpath_eval ('/interop_menu_tree/*', xml_tree_doc (BPWSI.BPWSI.interop_menu_tree ()), 0);
}
;

create procedure BPWSI.BPWSI.interop_menu_tree ()
{
  return concat (
'<?xml version="1.0" ?>
   <interop_menu_tree>
     <node name="Home" url="home.vspx" id="1" allowed="interop_home">
       <node name="OpenLink BPEL Interoperability Home" url="home.vspx" id="11" allowed="interop_home_view">
         <node name="OpenLink BPEL Interoperability Resources" url="bpelrsc.vspx" id="111" place="left" allowed="interop_home_view"/>
         <node name="OpenLink BPEL Interoperability Use Case Testing" url="bpeluct.vspx" id="112" place="left" allowed="interop_home_view"/>
         <node name="OpenLink BPEL Interoperability WS-I Advocate" url="wsa.vspx" id="113" place="left" allowed="interop_home_view"/>
         <node name="OpenLink BPEL Interoperability About this site" url="about.vspx" id="114" place="left" allowed="interop_home_view"/>
       </node>
     </node>
      <node name="Features Summary" url="mgrsum.vspx" id="2" allowed="interop_mng">
       <node name="OpenLink BPEL Interoperability Features Summary" url="mgrsum.vspx" id="22" allowed="interop_mng_view"/>
     </node>
     <node name="Protocols Support" url="protocols.vspx" id="3" allowed="interop_web">
       <node name="OpenLink BPEL Interoperability Protocols Support" url="protocols.vspx" id="33" allowed="interop_web_view"/>
     </node>
     <node name="Test Results" url="tstsum.vspx" id="4" allowed="interop_tst">
       <node name="OpenLink BPEL Interoperability Test Results" url="tstsum.vspx" id="44" allowed="interop_tst_view">
         <node name="OpenLink BPEL Interoperability Post Test Results" url="post.vspx" id="444" place="left" allowed="interop_tst_view"/>
       </node>
     </node>
     <node name="BPEL Interop Testing" url="intest.vspx" id="5" allowed="interop_rsl">
       <node name="OpenLink BPEL Interoperability Testing" url="intest.vspx" id="55" allowed="interop_rsl_view">
         <node name="OpenLink BPEL Interoperability View Test" url="view.vspx" id="551" place="left" allowed="interop_rsl_view"/>
         <node name="OpenLink BPEL Interoperability View Test Client" url="clients/echoUI.vspx" id="552" place="left" allowed="interop_rsl_view"/>
         <node name="OpenLink BPEL Interoperability View Test Client" url="clients/aechoUI.vspx" id="553" place="left" allowed="interop_rsl_view"/>
       </node>
     </node>
   </interop_menu_tree>');
}
;


create procedure BPWSI.BPWSI.interop_navigation_child (in path varchar, in node any)
{
  path := concat (path, '[not @place]');
  return xpath_eval (path, node, 0);
}
;

create procedure BPWSI.BPWSI.interop_get_page_name ()
{
  declare path, url, elm varchar;
  declare arr any;
  path := http_path ();
  arr := split_and_decode (path, 0, '\0\0/');
  elm := arr [length (arr) - 1];
  url := xpath_eval ('//*[@url = "'|| elm ||'"]', xml_tree_doc (BPWSI.BPWSI.interop_menu_tree ()));
  --dbg_obj_print (url);
  if (url is not null or elm = 'error.vspx')
    return elm;
  else
    return '';
}
;


create procedure BPWSI.BPWSI.check_grants (in user_name  varchar, in role_name varchar) {
  return 1;
}
;
