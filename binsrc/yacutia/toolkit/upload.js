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
	u = new Upload(method,action,target)
	document.body.appendChild(u.div);
	
	CSS: .upload .upload_add .upload_submit
*/

function Upload(method,action,target) {
	var obj = this;
	this.content = Dom.create("div");
	this.div = Dom.create("div");
	this.div.className = "upload";
	this.form = Dom.create("form");
	this.form.setAttribute("method",method);
	this.form.setAttribute("action",action);
	this.form.setAttribute("target",target);
	this.divs = [];
	
	this.remove = function(div) {
		var index = -1;
		for (var i=0;i<this.divs.length;i++) if (this.divs[i] == div) { index = i; }
		Dom.unlink(this.divs[index]);
		this.divs.splice(index,1);
	}
	
	this.add = function() {
		var index = this.divs.length-1;
		var div = Dom.create("div");
		var input = Dom.create("input");
		var del = Dom.create("input");
		input.setAttribute("type","file");
		del.setAttribute("type","button");
		del.value = "Remove";
		Dom.attach(del,"click",function(){obj.remove(div);});
		div.appendChild(input);
		div.appendChild(Dom.text(" "));
		div.appendChild(del);
		this.content.appendChild(div);
		this.divs.push(div);
	}
	
	this.addBtn = Dom.create("input");
	this.addBtn.setAttribute("type","button");
	this.addBtn.className = "upload_add";
	this.addBtn.value = "Add file";
	Dom.attach(this.addBtn,"click",function(){obj.add();});
	
	this.submitBtn = Dom.create("input");
	this.submitBtn.setAttribute("type","submit");
	
	this.form.appendChild(this.content);
	this.form.appendChild(this.addBtn);
	this.form.appendChild(Dom.text(" "));
	this.form.appendChild(this.submitBtn);
	this.div.appendChild(this.form);
	
	this.add();
}
