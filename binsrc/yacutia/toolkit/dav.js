/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
 *  
*/
/*
	temporary solution, waiting for some more sophisticated dav client
*/

var Dav = {
	getDir:function(dir) {
		var ld = (dir ? dir : ".");
		return prompt("Choose a directory",ld);
	},
	
	getFile:function(dir,file) {
		var ld = (dir ? dir : ".");
		var lf = (file ? ld+"/"+file : ld+"/");
		return prompt("Choose a file name",lf);
	},
	
	getNewFile:function(dir,file,filters) {
		var ld = (dir ? dir : ".");
		var str = (file ? dir+"/"+file : dir+"/");
		return prompt("Choose a file name"+(filters ? " ("+filters+")" : ""),str);
	}
}
