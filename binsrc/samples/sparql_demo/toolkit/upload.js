/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2006 Ondrej Zara and OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	u = new OAT.Upload(method,action,target)
	document.body.appendChild(u.div);
	
	CSS: .upload .upload_add .upload_submit
*/

OAT.Upload = function(method,action,target) {
	var obj = this;
	this.content = OAT.Dom.create("div");
	this.div = OAT.Dom.create("div");
	this.div.className = "upload";
	this.form = OAT.Dom.create("form");
	this.form.setAttribute("method",method);
	this.form.setAttribute("action",action);
	this.form.setAttribute("target",target);
	this.divs = [];
	
	this.remove = function(div) {
		var index = -1;
		for (var i=0;i<this.divs.length;i++) if (this.divs[i] == div) { index = i; }
		OAT.Dom.unlink(this.divs[index]);
		this.divs.splice(index,1);
	}
	
	this.add = function() {
		var index = this.divs.length-1;
		var div = OAT.Dom.create("div");
		var input = OAT.Dom.create("input");
		var del = OAT.Dom.create("input");
		input.setAttribute("type","file");
		del.setAttribute("type","button");
		del.value = "Remove";
		OAT.Dom.attach(del,"click",function(){obj.remove(div);});
		div.appendChild(input);
		div.appendChild(OAT.Dom.text(" "));
		div.appendChild(del);
		this.content.appendChild(div);
		this.divs.push(div);
	}
	
	this.addBtn = OAT.Dom.create("input");
	this.addBtn.setAttribute("type","button");
	this.addBtn.className = "upload_add";
	this.addBtn.value = "Add file";
	OAT.Dom.attach(this.addBtn,"click",function(){obj.add();});
	
	this.submitBtn = OAT.Dom.create("input");
	this.submitBtn.setAttribute("type","submit");
	
	this.form.appendChild(this.content);
	this.form.appendChild(this.addBtn);
	this.form.appendChild(OAT.Dom.text(" "));
	this.form.appendChild(this.submitBtn);
	this.div.appendChild(this.form);
	
	this.add();
}
OAT.Loader.pendingCount--;
