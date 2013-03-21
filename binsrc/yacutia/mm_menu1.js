/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

function mmLoadMenus() {

   if (vsid.length == 0)
     {
	if (window.mm_menu_0429095826_0) return;
        window.mm_menu_0429095826_0 = new Menu("root",240,18,"Verdana, Arial, Helvetica, sans-serif",12,"#000000","#000000","#FFFFFF","#A4BFD5","center","middle",6,0,1000,-5,7,true,true,true,0,true,true);
        mm_menu_0429095826_0.addMenuItem("You are not logged in, please login");
        mm_menu_0429095826_0.hideOnMouseOut=true;
        mm_menu_0429095826_0.bgColor='#999999';
        mm_menu_0429095826_0.menuBorder=1;
        mm_menu_0429095826_0.menuLiteBgColor='#FFFFFF';
        mm_menu_0429095826_0.menuBorderBgColor='#889FB1';
        window.mm_menu_0428155127_0 = window.mm_menu_0429095826_0;
        window.mm_menu_0428165356_0 = window.mm_menu_0429095826_0;
        window.mm_menu_0428193305_0 = window.mm_menu_0429095826_0;
	window.mm_menu_0428193705_0 = window.mm_menu_0429095826_0;
	window.mm_menu_0428193809_0 = window.mm_menu_0429095826_0;
	mm_menu_0429095826_0.writeMenus();
        return;
     }

  if (window.mm_menu_0428155127_0) return;
   window.mm_menu_0428155127_0 = new Menu("root",194,23,"Verdana, Arial, Helvetica, sans-serif",11,"#000000","#000000","#FFFFFF","#A4BFD5","center","middle",6,0,1000,-5,7,true,true,true,0,true,true);
  mm_menu_0428155127_0.addMenuItem("SQL&nbsp;Data&nbsp;Management","window.open('databases.vspx?sid='+vsid+'&realm='+vrealm, '_self');");
  mm_menu_0428155127_0.addMenuItem("XML&nbsp;Data&nbsp;Management","window.open('xquery.vspx?sid='+vsid+'&realm='+vrealm, '_self');");
  mm_menu_0428155127_0.addMenuItem("Web&nbsp;Content&nbsp;Management","window.open('cont_page.vspx?sid='+vsid+'&realm='+vrealm, '_self');");
   mm_menu_0428155127_0.hideOnMouseOut=true;
   mm_menu_0428155127_0.bgColor='#999999';
   mm_menu_0428155127_0.menuBorder=1;
   mm_menu_0428155127_0.menuLiteBgColor='#FFFFFF';
   mm_menu_0428155127_0.menuBorderBgColor='#99B3C5';
  window.mm_menu_0428165356_0 = new Menu("root",258,23,"Verdana, Arial, Helvetica, sans-serif",11,"#000000","#000000","#FFFFFF","#A4BFD5","center","middle",6,0,1000,-5,7,true,true,true,0,true,true);
  mm_menu_0428165356_0.addMenuItem("Virtual&nbsp;Database","window.open('vdb_linked_obj.vspx?sid='+vsid+'&realm='+vrealm, '_self');");
  mm_menu_0428165356_0.addMenuItem("SQLX&nbsp;&&nbsp;SQL-XML&nbsp;Transformation","window.open('xml_sql.vspx?sid='+vsid+'&realm='+vrealm, '_self');");
   mm_menu_0428165356_0.hideOnMouseOut=true;
   mm_menu_0428165356_0.bgColor='#999999';
   mm_menu_0428165356_0.menuBorder=1;
   mm_menu_0428165356_0.menuLiteBgColor='#FFFFFF';
   mm_menu_0428165356_0.menuBorderBgColor='#889FB1';
  window.mm_menu_0428193305_0 = new Menu("root",176,23,"Verdana, Arial, Helvetica, sans-serif",11,"#000000","#000000","#FFFFFF","#A4BFD5","center","middle",6,0,1000,-5,7,true,true,true,0,true,true);
  mm_menu_0428193305_0.addMenuItem("Web&nbsp;Service&nbsp;Publishing","window.open('soap_services.vspx?sid='+vsid+'&realm='+vrealm, '_self');");
  mm_menu_0428193305_0.addMenuItem("Web&nbsp;Application&nbsp;Server","window.open('http_serv_mgmt.vspx?sid='+vsid+'&realm='+vrealm, '_self');");
   mm_menu_0428193305_0.hideOnMouseOut=true;
   mm_menu_0428193305_0.bgColor='#999999';
   mm_menu_0428193305_0.menuBorder=1;
   mm_menu_0428193305_0.menuLiteBgColor='#FFFFFF';
   mm_menu_0428193305_0.menuBorderBgColor='#99B3C5';
   var hgh = 176;
   if (have_bpel == 0)
     hgh = 220;
  window.mm_menu_0428193705_0 = new Menu("root",hgh,23,"Verdana, Arial, Helvetica, sans-serif",11,"#000000","#000000","#FFFFFF","#A4BFD5","center","middle",6,0,1000,-5,7,true,true,true,0,true,true);

  if (have_bpel)
   mm_menu_0428193705_0.addMenuItem("BPEL&nbsp;Process&nbsp;Manager","window.open('/BPELGUI/home.vspx?sid='+vsid+'&realm='+vrealm, '_self');");
  else
   mm_menu_0428193705_0.addMenuItem("Please&nbsp;install&nbsp;the&nbsp;BPEL&nbsp;Process&nbsp;Manager", "");

   mm_menu_0428193705_0.hideOnMouseOut=true;
   mm_menu_0428193705_0.bgColor='#999999';
   mm_menu_0428193705_0.menuBorder=1;
   mm_menu_0428193705_0.menuLiteBgColor='#FFFFFF';
   mm_menu_0428193705_0.menuBorderBgColor='#99B3C5';
  window.mm_menu_0428193809_0 = new Menu("root",252,23,"Verdana, Arial, Helvetica, sans-serif",11,"#000000","#000000","#FFFFFF","#A4BFD5","center","middle",6,0,1000,-5,7,true,true,true,0,true,true);
  if (have_wa)
    mm_menu_0428193809_0.addMenuItem("Virtuoso&nbsp;Based&nbsp;Applications","window.open(wa_link, '_self');");
  mm_menu_0428193809_0.addMenuItem("Discussion,&nbsp;Mail,&nbsp;&&nbsp;Proxy&nbsp;Services","window.open('msg_news_conf.vspx?sid='+vsid+'&realm='+vrealm, '_self');");
   mm_menu_0428193809_0.hideOnMouseOut=true;
   mm_menu_0428193809_0.bgColor='#999999';
   mm_menu_0428193809_0.menuBorder=1;
   mm_menu_0428193809_0.menuLiteBgColor='#FFFFFF';
   mm_menu_0428193809_0.menuBorderBgColor='#99B3C5';

          window.mm_menu_0429095826_0 = new Menu("root",240,18,"Verdana, Arial, Helvetica, sans-serif",12,"#000000","#000000","#FFFFFF","#A4BFD5","center","middle",6,0,1000,-5,7,true,true,true,0,true,true);
  mm_menu_0429095826_0.addMenuItem("Enterprise&nbsp;Integration&nbsp;Conductor&nbsp;");
   mm_menu_0429095826_0.hideOnMouseOut=true;
   mm_menu_0429095826_0.bgColor='#999999';
   mm_menu_0429095826_0.menuBorder=1;
   mm_menu_0429095826_0.menuLiteBgColor='#FFFFFF';
   mm_menu_0429095826_0.menuBorderBgColor='#889FB1';

mm_menu_0429095826_0.writeMenus();
} // mmLoadMenus()

function MM_swapImgRestore() { //v3.0
  var i,x,a=document.MM_sr; for(i=0;a&&i<a.length&&(x=a[i])&&x.oSrc;i++) x.src=x.oSrc;
}

function MM_preloadImages() { //v3.0
  var d=document; if(d.images){ if(!d.MM_p) d.MM_p=new Array();
    var i,j=d.MM_p.length,a=MM_preloadImages.arguments; for(i=0; i<a.length; i++)
    if (a[i].indexOf("#")!=0){ d.MM_p[j]=new Image; d.MM_p[j++].src=a[i];}}
}

function MM_findObj(n, d) { //v4.01
  var p,i,x;  if(!d) d=document; if((p=n.indexOf("?"))>0&&parent.frames.length) {
    d=parent.frames[n.substring(p+1)].document; n=n.substring(0,p);}
  if(!(x=d[n])&&d.all) x=d.all[n]; for (i=0;!x&&i<d.forms.length;i++) x=d.forms[i][n];
  for(i=0;!x&&d.layers&&i<d.layers.length;i++) x=MM_findObj(n,d.layers[i].document);
  if(!x && d.getElementById) x=d.getElementById(n); return x;
}

function MM_swapImage() { //v3.0
  var i,j=0,x,a=MM_swapImage.arguments; document.MM_sr=new Array; for(i=0;i<(a.length-2);i+=3)
   if ((x=MM_findObj(a[i]))!=null){document.MM_sr[j++]=x; if(!x.oSrc) x.oSrc=x.src; x.src=a[i+2];}
}
