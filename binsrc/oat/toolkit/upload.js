/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2018 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	u = new OAT.Upload(method,action,target)
	document.body.appendChild(u.div);

	CSS: .upload .upload_add .upload_submit
*/

OAT.Upload = function(method,action,target,inputName) {
	var self = this;
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
		var div = OAT.Dom.create("div");
		var input = OAT.Dom.create("input");
		var del = OAT.Dom.create("input");
		input.setAttribute("type","file");
		input.name = inputName + "_" + self.divs.length;
		del.setAttribute("type","button");
		del.value = "Remove";
		OAT.Event.attach(del,"click",function(){self.remove(div);});
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
	OAT.Event.attach(this.addBtn,"click",function(){self.add();});

	this.submitBtn = OAT.Dom.create("input");
	this.submitBtn.setAttribute("type","submit");

	this.form.appendChild(this.content);
	this.form.appendChild(this.addBtn);
	this.form.appendChild(OAT.Dom.text(" "));
	this.form.appendChild(this.submitBtn);
	this.div.appendChild(this.form);

	this.add();
}
