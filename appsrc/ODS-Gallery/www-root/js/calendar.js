/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

var GCallendar = {
		obj:new OAT.Calendar(),
		current_control:'',
		setCurrent:function(ctrlId){
	    GCallendar.current_control=$(ctrlId);
	  },
		show:function(ctrlId) {
		  GCallendar.setCurrent(ctrlId);
	    var _ctrl=GCallendar.current_control;
      var _ctrlLeftTop=OAT.Dom.position(_ctrl);
      if (OAT.Browser.isIE == false)
        GCallendar.obj.show(_ctrlLeftTop[0]+25, _ctrlLeftTop[1]+0, GCallendar.onClick);
      else
        GCallendar.obj.show(_ctrlLeftTop[0]+25, _ctrlLeftTop[1]+0, GCallendar.onClick);
	
		},
		onClick:function(_date){
		  var trunc_pos=GCallendar.current_control.id.indexOf('selector');
		  var ctrl_base=GCallendar.current_control.id.substr(0,trunc_pos);
      $(ctrl_base+'year').selectedIndex  = Number(String(_date[0]).substring(2,4));
      $(ctrl_base+'month').selectedIndex = Number(_date[1])-1;
      $(ctrl_base+'day').selectedIndex   = Number(_date[2])-1;
		}
};
