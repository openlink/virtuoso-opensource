/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2013 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.WebDav.init(optObj)
	OAT.WebDav.openDialog(optObj)
	OAT.WebDav.saveDialog(optObj)
*/

/**
 * @class Displays a WebDav browser window for file picking/opening/saving.
 */
OAT.WebDav = {
	cache:{}, /* visited directories and their content */
	window:false, /* window object */
	connectDialog:false, /* connection dialog */
	dom:{}, /* shortcuts to various dom elements: path, file, ext, ok, cancel */
	options: { /* defaults */
		user:false,
		pass:false,
		path:false, /* where are we now */
		file:'', /* preselected filename */
		extension:false, /* preselected extension */
		foldersOnly:false,
		silentStart:true, /* don't display our settings dialog on startup */
		pathFallback:false, /* what to offer when dirchange fails */
		pathHome:'/DAV/home/', /* user's home directories path */
		width:760,
		height:450,
		imagePath:OAT.Preferences.imagePath,
		imageExt:'png',
		confirmOverwrite:true,
		isDav:true,
		hiddenPrefixes:'.',
		connectionHeaders:{},
		extensionFilters:[], /* ['id','ext','my extension description','content type'],... */
		callback:function(path,file,content){}, /* what to do after selection */
		dataCallback:function(file,extID){return "";} /* data provider for saving. when false, nothing is saved */
	},
	displayMode:0, /* details / icons */
	mode:0, /* open / save */

/* basic api */

	openDialog:function(optObj) { /* open in browse file mode */
		this.dom.ok.value = "Open";
		this.mode = 0;
		this.commonDialog(optObj);
		OAT.Dom.hide("dav_permissions");
	},

	saveDialog:function(optObj) { /* open in save file mode */
		this.dom.ok.value = "Save";
		this.mode = 1;
		this.commonDialog(optObj);

		var state = [1,1,0,1,0,0,1,0,0];
		this.dom.perms[2].disabled = true;
		this.dom.perms[5].disabled = true;
		this.dom.perms[8].disabled = true;
		for (var i=0;i<9;i++) {
			this.dom.perms[i].checked = (state[i] == 1);
		}
	},

/* standard methods */
	openDirectory:function(newDir,treeOnly,treeNode) { /* try to open a path */
		var dir = newDir;
		if (dir.substring(newDir.length-1) != "/") { dir += "/"; } /* add trailing slash */

		var error = function(xhr) {
			var p = prompt("Cannot change directory to "+dir+". It does not exist or you do not have sufficient privileges.\nPlease specify other directory.",OAT.WebDav.options.pathFallback);
			if (!p) { return; }
			OAT.WebDav.openDirectory(p);
		} /* error callback */

		var callback = function() {
			if (treeOnly) { return; }
			OAT.WebDav.options.path = dir;
			OAT.WebDav.redraw();
		}
		if (dir in this.cache) {
			callback();
		} else {
			var endRef = false;
			if (treeNode) { /* change tree node to throbber */
				var oldI = treeNode._icon.src;
				var oldF = treeNode._icon.style.filter;
				treeNode._icon.src = OAT.WebDav.options.imagePath+"Dav_throbber.gif";
				treeNode._icon.style.filter = "";

				endRef = function() {
					treeNode._icon.src = oldI;
					treeNode._icon.style.filter = oldF;
				}
			}
			this.requestDirectory(dir,callback,error,endRef);
		}
	},

	useFile:function(_path,_file) { /* finish */
		if (_path || _file) {
			var p = _path;
			var f = _file;
		} else {
			var p = this.options.path;
			var f = this.dom.file.value;
		}

		if (this.mode == 0) { /* open */
			if (OAT.WebDav.options.foldersOnly) {
				if (OAT.WebDav.options.callback) {
					OAT.WebDav.window.close();
					OAT.WebDav.options.callback(p,'');
				}
			} else {
				var path = p + f;
				var error = function(xhr) {
					var desc = OAT.WebDav.genericError(xhr,path);
					alert('OAT.WebDav.usefile:\nError while trying to open file.\n'+desc);
				}
				var url = path + '?'+ new Date().getMilliseconds();
				var o = {
					headers:OAT.WebDav.options.connectionHeaders,
					type:OAT.AJAX.TYPE_TEXT,
					onerror:error
				}
				OAT.WebDav.updateOptions(o);
				var response = function(data) {
					OAT.WebDav.window.close();
					if (OAT.WebDav.options.callback) { OAT.WebDav.options.callback(p,f,data); }
				}
				OAT.AJAX.GET(url,false,response,o);
			}
		}

		if (this.mode == 1) { /* save */
			var id = false;
			if (this.options.isDav) {
				var ext = this.options.extensionFilters[this.dom.ext.selectedIndex];
				if (!(f.match(/\./)) && ext[1] != "*") { f += "."+ext[1]; } /* add extension */

				/* does the file exist? */
				var c = true;
				if (this.options.confirmOverwrite && this.fileExists(f)) {
					var c = confirm('Do you want to replace existing file?');
				}
				if (!c) { return; }
				id = ext[0];
			}

			/* ready to save */
			if (!this.options.dataCallback) {
				OAT.WebDav.window.close();
				if (OAT.WebDav.options.callback) { OAT.WebDav.options.callback(p,f); }
				return;
			}
			var data = this.options.dataCallback(f,id);
			var error = function(xhr) {
				var desc = OAT.WebDav.genericError(xhr,p+f);
				alert('OAT.WebDav.usefile:\nError while trying to save file.\n'+desc);
			}
			var o = {
				headers:OAT.WebDav.options.connectionHeaders,
				type:OAT.AJAX.TYPE_TEXT,
				onerror:error
			}
			OAT.WebDav.updateOptions(o);
			var r = f.match(/\.([^\.]+)$/); /* content type */
			if (r) { /* has extension */
				var ext = r[1];
				for (var i=0;i<this.options.extensionFilters.length;i++) {
					var filter = this.options.extensionFilters[i];
					if (filter[1] == ext && filter.length == 4) { o.headers = {"Content-Type":filter[3]}; }
				}
			}

			var response = function() {
				if (OAT.WebDav.options.isDav) { OAT.WebDav.updatePermissions(p+f); }
				OAT.WebDav.window.close();
				if (OAT.WebDav.options.callback) { OAT.WebDav.options.callback(p,f); }
			}

			OAT.AJAX.PUT(p+f,data,response,o);
		} /* save */
	},

	createDirectory:function(newDir) { /* create new directory */
		if (this.fileExists(newDir)) {
			alert("OAT.WebDav.createDirectory:\nAn item with name '"+newDir+"' already exists!");
			return;
		}
		var url = this.options.path+newDir;
		var error = function(xhr) {
			var desc = OAT.WebDav.genericError(xhr,newDir);
			alert('OAT.WebDav.createDirectory:\nError while creating new directory.\n'+desc);
		}
		var o = {
			headers:OAT.WebDav.options.connectionHeaders,
			type:OAT.AJAX.TYPE_TEXT,
			onerror:error
		}
 		OAT.WebDav.updateOptions(o);

		var afterPerms = function() {
			delete OAT.WebDav.cache[OAT.WebDav.options.path];
			OAT.WebDav.openDirectory(OAT.WebDav.options.path); /* refresh current */
		}

		var callback = function() {
			OAT.WebDav.updatePermissions(url,"110100100",afterPerms);
		}
		OAT.AJAX.MKCOL(url,null,callback,o);
	},

	init:function(optObj) { /* to be called once. draw window etc */
		this.applyOptions(optObj);
		if (OAT.Preferences.windowTypeOverride == 2 || OAT.Browser.isMac) {
			this.options.width += 16;
		}

		/* create window */
		var wopts = {
			buttons:"cr",
			outerWidth:this.options.width,
			outerHeight:this.options.height,
			imagePath:this.options.imagePath,
			title:"WebDAV Browser",
			stackGroupBase:998
		}
		this.window = new OAT.Win(wopts);
		var div = this.window.dom.content;
		var content = OAT.Dom.create("div",{paddingLeft:"2px",paddingRight:"5px"});

		this.window.dom.content.appendChild(content);
		div.id = "dav_browser";

		/* create toolbar */
		var toolbarDiv = OAT.Dom.create("div");
		var toolbar = new OAT.Toolbar(toolbarDiv);
		toolbar.addIcon(0,this.options.imagePath+"Dav_new_folder.gif","Create New Folder",function() {
			var nd = prompt('Create new folder','New Folder');
			if (!nd) { return; }
			OAT.WebDav.createDirectory(nd);
		});
		if (!this.options.foldersOnly)
		{
			toolbar.addSeparator();
			toolbar.addIcon(0,this.options.imagePath+"Dav_view_details.gif","Details",function(){
				OAT.WebDav.displayMode = 0;
				OAT.WebDav.redraw();
			});
			toolbar.addIcon(0,this.options.imagePath+"Dav_view_icons.gif","Icons",function(){
				OAT.WebDav.displayMode = 1;
				OAT.WebDav.redraw();
			});
		}
		toolbar.addSeparator();
		toolbar.addIcon(0,this.options.imagePath+"Dav_up.gif","Up one level",function(){
			var nd = OAT.WebDav.options.path.match(/^(.*\/)[^\/]+\//);
			OAT.WebDav.openDirectory(nd[1]);
		});

		/* path */
		var path = OAT.Dom.create('div');
		path.id = "dav_path";
		var input = OAT.Dom.create("input");
		input.size = 60;
		input.type = "text";
		this.dom.path = input;
		var go = OAT.Dom.create("img",{verticalAlign:"middle",cursor:"pointer"});
		go.src = this.options.imagePath+"Dav_go.gif";
		this.dom.go = go;
		OAT.Dom.append([path,OAT.Dom.text('Location: '),input,go]);

		/* main part */
		var h1 = (this.options.height-165)+"px";
		var h2 = (this.options.height-167)+"px";
		var main = OAT.Dom.create('div',{height:h1,position:"relative"});
		main.id = 'dav_main';

		var main_tree = OAT.Dom.create('div',{overflow:"auto",height:h2});
		var main_splitter = OAT.Dom.create('div',{height:"100%"});
		var main_right = OAT.Dom.create('div',{height:"100%",overflow:"auto"});
		var main_content = OAT.Dom.create('div',{height:"100%"});
		main_tree.id = 'dav_tree';
		main_splitter.id = 'dav_splitter';
		main_right.id = 'dav_right';
		main_content.id = 'dav_right_content';
		OAT.Dom.append([main,main_tree,main_splitter,main_right],[main_right,main_content]);

		/* resizing */
		var restrict = function(x,y) { return (x < 25); }
		OAT.Drag.create(main_splitter,main_splitter,{type:OAT.Drag.TYPE_X,restrictionFunction:restrict});
		OAT.Drag.create(main_splitter,main_right,{type:OAT.Drag.TYPE_X});
		OAT.Resize.create(main_splitter,main_tree,OAT.Resize.TYPE_X,restrict);
		OAT.Resize.create(main_splitter,main_right,-OAT.Resize.TYPE_X,restrict);
		OAT.Resize.create(main_splitter,main_content,-OAT.Resize.TYPE_X,restrict);

		this.dom.content = main_content;

		/* bottom part */
		var bottom = OAT.Dom.create('div');
		bottom.id = "dav_bottom";

		this.dom.ok = OAT.Dom.create("input",{type:"button",value:'OK'});
		this.dom.cancel = OAT.Dom.create("input",{type:"button",value:'Cancel'});

		this.dom.file = OAT.Dom.create("input");
		this.dom.file.type = "text";
		this.dom.ext = OAT.Dom.create("select");
		if (OAT.WebDav.options.foldersOnly)
		{
			this.dom.file.style.display = "none";
			this.dom.ext.style.display = "none";
		}

		var label_1 = OAT.Dom.text("File name: ");
		var label_2 = OAT.Dom.text("File type: ");

		var line_1 = OAT.Dom.create("div");
		var line_2 = OAT.Dom.create("div");

		if (OAT.WebDav.options.foldersOnly)
		{
			OAT.Dom.append([line_1,this.dom.file,this.dom.ext,this.dom.ok,this.dom.cancel]);
		} else {
			OAT.Dom.append([line_1,label_1,this.dom.file,this.dom.ok]);
			OAT.Dom.append([line_2,label_2,this.dom.ext,this.dom.cancel]);
		}

		/* connection dialog */
		var connectDiv = OAT.Dom.create("div");
		var ct = OAT.Dom.create("table");
		var ctbody = OAT.Dom.create("tbody");

		var ctrow_user = OAT.Dom.create("tr");
		var ctd_user = OAT.Dom.create("td");
		var ctd_user_label = OAT.Dom.create("td");
		ctd_user_label.innerHTML = "Username: ";

		var ctrow_pass = OAT.Dom.create("tr");
		var ctd_pass = OAT.Dom.create("td");
		var ctd_pass_label = OAT.Dom.create("td");
		ctd_pass_label.innerHTML = "Password: ";

		var ctrow_conntype = OAT.Dom.create("tr");
		var ctd_conntype = OAT.Dom.create("td");
		var ctd_conntype_label = OAT.Dom.create("td");
		ctd_conntype_label.innerHTML = "Web Server type: ";

		var user = OAT.Dom.create("input");
	 	user.setAttribute("type","text");
		user.id = "dav_user";
		user.name = "user";
		user.value = "demo";

		var pass = OAT.Dom.create("input");
	 	pass.setAttribute("type","password");
		pass.id = "dav_pass";
		pass.name = "pass";
		pass.value = "demo";

		var conntype = OAT.Dom.create("select");
		conntype.id = "dav_login_put_type";
		var conntype_basic = OAT.Dom.create("option");
		conntype_basic.value = "0";
		conntype_basic.innerHTML = "HTTP - Basic";
		var conntype_dav = OAT.Dom.create("option");
		conntype_dav.value = "1";
		conntype_dav.innerHTML = "HTTP - WebDAV";
		conntype_dav.selected = "selected";

		OAT.Dom.append([conntype,conntype_basic,conntype_dav]);

		OAT.Dom.append([connectDiv,ct]);
		OAT.Dom.append([ct,ctbody]);

		OAT.Dom.append([ctbody,ctrow_user,ctrow_pass,ctrow_conntype]);
		OAT.Dom.append([ctrow_user,ctd_user_label,ctd_user]);
		OAT.Dom.append([ctd_user,user]);

		OAT.Dom.append([ctrow_pass,ctd_pass_label,ctd_pass]);
		OAT.Dom.append([ctd_pass,pass]);

		OAT.Dom.append([ctrow_conntype,ctd_conntype_label,ctd_conntype]);
		OAT.Dom.append([ctd_conntype,conntype]);

		var cdialog = new OAT.Dialog("Connection Setup",connectDiv,{width:400,modal:1,buttons:1});
		OAT.MSG.attach(cdialog, "DIALOG_OK", function() {
			with(OAT.WebDav.options) {
				user = $v("dav_user");
				pass = $v("dav_pass");
				isDav = ($v("dav_login_put_type") == "1");
				path = pathHome + user + "/";
			}
		});

		this.connectDialog = cdialog;

		/* permissions */
		this.initPermissions(bottom);
		OAT.Dom.append([bottom,line_1,line_2]);
		OAT.Dom.append([content,toolbarDiv,path,main,bottom]);

		/* tree */
		this.tree = new OAT.Tree({onClick:false,ascendSelection:false});
		var ul = OAT.Dom.create("ul",{whiteSpace:"nowrap"});
		main_tree.appendChild(ul);
		this.tree.assign(ul,true);
		this.treeSyncDir(this.options.path);

		this.attachEvents();

		with(this.options) {
			if(user !== false) { path = pathHome + user + "/"; }
			if(!silentStart || (user === false && pass === false)) { this.connectDialog.open(); }
		}

		if (this.options.hiddenPrefixes)
		{
			this.hiddens = this.options.hiddenPrefixes.split(",");
			for (var i = 0; i < this.hiddens.length; i++) {
				this.hiddens[i] = this.hiddens[i].trim();
			}
		} else {
			this.hiddens = [];
		}
	},

	initPermissions:function(parentDiv) { /* draw the permissions table */
		var x = '<table id="dav_permissions"><tbody>'+
				'<tr><td colspan="3">Owner</td><td colspan="3">Group</td><td colspan="3">Others</td></tr>'+
				'<tr><td>R</td><td>W</td><td>X</td><td>R</td><td>W</td><td>X</td><td>R</td><td>W</td><td>X</td></tr>'+
				'<tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr>'+
				'</tbody></table>';
		var d = OAT.Dom.create("div",{cssFloat:"left",styleFloat:"left"});
		d.innerHTML = x;
		var row = d.getElementsByTagName("tr")[2];
		var tds = row.getElementsByTagName("td");
		this.dom.perms = [];
		for (var i=0;i<tds.length;i++) {
			var td = tds[i];
			var ch = OAT.Dom.create("input");
			this.dom.perms.push(ch);
			ch.type="checkbox";
			td.appendChild(ch);
		}
		parentDiv.appendChild(d);
	},

	requestDirectory:function(directory,callback,error,onend) { /* send ajax request */
		/* send a request */
		var data = "";
		data += '<?xml version="1.0" encoding="utf-8" ?>' +
				'<propfind xmlns="DAV:"><prop>' +
				'	<creationdate/><getlastmodified/><href/>' +
				'	<resourcetype/><getcontentlength/><getcontenttype/>' +
				'	<virtpermissions xmlns="http://www.openlinksw.com/virtuoso/webdav/1.0/"/>' +
				'	<virtowneruid xmlns="http://www.openlinksw.com/virtuoso/webdav/1.0/"/>' +
				'	<virtownergid xmlns="http://www.openlinksw.com/virtuoso/webdav/1.0/"/>' +
				' </prop></propfind>';

		var headers = OAT.WebDav.options.connectionHeaders;
		headers.Depth = 1;

		var o = {
			headers:headers,
			type:OAT.AJAX.TYPE_XML,
			onerror:error,
			onend:onend,
			onstart:onend ? function(){} : false
		}
		OAT.WebDav.updateOptions(o);

		var ref = function(data) {
			if (!OAT.WebDav.parse(directory,data)) /* add to cache */
				error();
			OAT.WebDav.treeSyncDir(directory); /* sync with tree */
			if (OAT.Browser.isIE) {
				var x = $("dav_bottom");
				var p = x.parentNode;
				OAT.Dom.unlink(x);
				p.appendChild(x);
			}
			callback();
		}
		OAT.AJAX.PROPFIND(directory,data,ref,o);
	},

	parse:function(directory,xml) { /* parse dav response: update tree, add data to cache */
		var data = xml.documentElement;
		if (OAT.Xml.localName(data) == 'parsererror') {return false;}
		var items = [];
		for (var i=0;i<data.childNodes.length;i++) {
			var node = data.childNodes[i];
			if (node.nodeType != 1) { continue; }
			var item = OAT.WebDav.parseNode(node);
			if (item.fullName != directory) {
				if (OAT.WebDav.hiddenCheck(item.name)) {
					items.push(item);
				}
			}
		}

		var arr = [];
		for (var i=0;i<items.length;i++){
			var item = items[i];
			if (item.dir) {
				arr.push(item);
				this.treeSyncDir(item.fullName);
			} /* dirs first */
		}
		if (!this.options.foldersOnly) {
			for (var i=0;i<items.length;i++){
				var item = items[i];
				if (!item.dir) { arr.push(item); } /* files next */
			}
		}
		OAT.WebDav.cache[directory] = arr; /* add to cache */

		return true;
	},

	redraw:function() { /* redraw view */
		/* this.options.path MUST be in this.cache in this phase */
		var list = this.cache[this.options.path];
		if (!list) {return;}
		this.dom.path.value = this.options.path;
		this.treeOpenCurrent();

		OAT.Dom.clear(this.dom.content);
		function attachClick(elm,item,arr) {
			OAT.Event.attach(elm,"click",function() {
				OAT.WebDav.dom.file.value = item.name;
				if (!arr) { return; }
				for (var i=0;i<arr.length;i++) {
					var e = arr[i];
					OAT.Dom.removeClass(e,"dav_item_selected");
				}
				OAT.Dom.addClass(elm,"dav_item_selected");
			});
		}
		function attachDblClick(elm,item) {
			OAT.Event.attach(elm,"dblclick",function() {
				if (item.dir) { /* xxx */
					var treeNode = OAT.WebDav.treeGetNode(item.fullName);
					OAT.WebDav.openDirectory(OAT.WebDav.options.path+item.name,false,treeNode);
				} else {
					OAT.WebDav.useFile();
				}
			});
		}

		if (this.options.foldersOnly)
		{
			var content = this.dom.content;
			var g = new OAT.Grid(content,{imagePath:this.options.imagePath});
			var header = ["Name"];
			g.createHeader(header);
			var numRows = -1;

			for (var i=0;i<list.length;i++) {
				var item = list[i];
				if (!item.dir && !this.checkExtension(item.name)) { continue; }
				var ico_type = (item.dir ? 'node-collapsed' : 'leaf');
				var ico = this.imagePathHtml(ico_type) + "&nbsp;" + item.name;
				var row = [ico];
				g.createRow(row);
				numRows++;
				attachClick(g.rows[numRows].html,item);
				attachDblClick(g.rows[numRows].html,item);
			}
		} else {
			if (this.displayMode == 0) { /* details */
				var content = this.dom.content;
				var g = new OAT.Grid(content,{imagePath:this.options.imagePath});
				var header = ["Name",{value:"Size",align:OAT.GridData.ALIGN_RIGHT},"Modified","Type","Owner","Group","Perms"];
				g.createHeader(header);
				var numRows = -1;
				var mask = "rwxrwxrwx";

				for (var i=0;i<list.length;i++) {
					var item = list[i];
					if (!item.dir && !this.checkExtension(item.name)) { continue; }
					var ico_type = (item.dir ? 'node-collapsed' : 'leaf');
					var ico = this.imagePathHtml(ico_type) + "&nbsp;" + item.name;
					var date = new Date(item.modificationDate);
					var p = "";
					for (var j=0;j<9;j++) {
						p += (item.permissions.charAt(j) == "1" ? mask.charAt(j) : "-");
					}
					var row = [
						ico,
						{value:item.length,align:OAT.GridData.ALIGN_RIGHT},
						date.format("Y-m-d H:i"),
						item.type,
						item.uid,
						item.gid,
						p
					]
					g.createRow(row);
					numRows++;
					attachClick(g.rows[numRows].html,item);
					attachDblClick(g.rows[numRows].html,item);
				}
			}

			if (this.displayMode == 1) { /* icons */
				var content = this.dom.content;
				var cubez = [];
				for (var i=0;i<list.length;i++) {
					var item = list[i];
					if (!item.dir && !this.checkExtension(item.name)) { continue; }
					var ico_type = (item.dir ? 'folder' : 'file');
					var src = this.options.imagePath+"Dav_"+ico_type+"."+this.options.imageExt;
					var srcB = this.options.imagePath+"Blank.gif";
					var ico = OAT.Dom.image(src,srcB,32,32);
					var cube = OAT.Dom.create('div',{className:"dav_item"});
					OAT.Dom.append([cube,ico,OAT.Dom.create("br"),OAT.Dom.text(item.name)],[content,cube]);
					content.appendChild(cube);
					attachClick(cube,item,cubez);
					attachDblClick(cube,item);
					cubez.push(cube);
				}
			}
		}
	},

/* supplementary routines */

	treeOpenCurrent:function() { /* open & expand current path */
		var p = this.options.path;
		var parts = p.split("/");
		if (parts[0] == "") { parts.shift(); }
		if (parts[parts.length-1] == "") { parts.pop(); }

		var ptr = 0;
		var node = this.tree.tree;
		var currentPath = "/";

		while (ptr < parts.length) { /* walk through whole path */
			currentPath += parts[ptr] + "/";
			var index = -1;
			for (var i=0;i<node.children.length;i++) { /* find child */
				var child = node.children[i];
				if (child.path == currentPath) { index = i; }
			}
			ptr++;
			node = node.children[index];
			node.expand(true);
		}
		if (this.options.foldersOnly) {
			this.dom.file.value = parts[parts.length-1];
		} else {
			//this.dom.file.value = '';
		}
		node.toggleSelect({ctrlKey:false});
	},

	treeSyncDir:function(path) { /* sync tree structure with this directory */
		var parts = path.split("/");
		if (parts[0] == "") { parts.shift(); }
		if (parts[parts.length-1] == "") { parts.pop(); }

		var ptr = 0;
		var node = this.tree.tree;
		var currentPath = "/";

		function attach(node,path) {
			OAT.Event.attach(node._gdElm,"click",function(){
				OAT.WebDav.openDirectory(path,false,node);
			});
		}

		while (ptr < parts.length) { /* walk through whole path */
			currentPath += parts[ptr] + "/";
			var index = -1;
			for (var i=0;i<node.children.length;i++) { /* find child */
				var child = node.children[i];
				if (child.path == currentPath) { index = i; }
			}
			if (index == -1) { /* if not yet in tree -> append */
				var label = parts[ptr];
				var newNode = node.createChild(parts[ptr],true);
				index = node.children.length-1;
				newNode.path = currentPath;
				newNode.collapse();
				attach(newNode,currentPath);
			}
			ptr++;
			node = node.children[index];
		}
		this.tree.walk("sync");
	},

	treeGetNode:function(path) { /* return tree node for a given directory */
		var parts = path.split("/");
		if (parts[0] == "") { parts.shift(); }
		if (parts[parts.length-1] == "") { parts.pop(); }

		var ptr = 0;
		var node = this.tree.tree;
		var currentPath = "/";

		while (ptr < parts.length) { /* walk through whole path */
			currentPath += parts[ptr] + "/";
			var index = -1;
			for (var i=0;i<node.children.length;i++) { /* find child */
				var child = node.children[i];
				if (child.path == currentPath) { index = i; }
			}
			ptr++;
			node = node.children[index];
			node.expand(true);
		}
		return node;
	},

	checkExtension:function(f) {
		var active = this.options.extensionFilters[this.dom.ext.selectedIndex];
		var ext = active[1];

		var r = OAT.WebDav.dom.file.value.match(/^\*\.(.*)$/);
		if (r && r.length == 2) { ext = r[1]; }

		if (ext == "*") { return true;}
		var r = f.match(/\.([^\.]+)$/);
		if (r && r.length == 2 && r[1].toLowerCase() == ext) { return true; }
		return false;
	},

	fileExists:function(f) { /* does the file exist in current directory? */
		var list = this.cache[this.options.path];
		if (!list) { return false; }
		for (var i=0;i<list.length;i++) {
			var item = list[i];
			if (item.name == f) { return item; }
		}
		return false;
	},

	genericError:function(xhr,url) { /* generic error code explanation */
		var status = xhr.getStatus();
		var text = xhr.getResponseText();
		var msg = "";
		if (status == 404) {
			msg = 'HTTP/'+status+': Not found. The requested URL '+url+' was not found on this server.';
		} else if (status == 401){
			msg = 'HTTP/'+status+': Forbidden. You have no access to URL '+url+'.';
		}else{
			msg = 'HTTP/'+status+': '+text+'.';
		}
		return msg;
	},

	attachEvents:function() { /* attach events to dom nodes */
		var useRef = function() {
			var p = OAT.WebDav.options.path;
			var f = $v(OAT.WebDav.dom.file);
			if (!f) { return; }
			var item = OAT.WebDav.fileExists(f);
			if (item && item.dir) { /* existing directory */
				OAT.WebDav.openDirectory(p+f);
				return;
			} else if (f.match(/^\*\.(.*)$/)) { /* extension filter */
				OAT.WebDav.redraw();
				return;
			}
			OAT.WebDav.useFile();
		}
		OAT.Event.attach(this.dom.path,"keypress",function(event) {
			if (event.keyCode != 13) { return; }
			var p = OAT.WebDav.dom.path.value;
			OAT.WebDav.openDirectory(p);
		});
		OAT.Event.attach(this.dom.go,"click",function(event) {
			var p = OAT.WebDav.dom.path.value;
			OAT.WebDav.openDirectory(p);
		});
		OAT.Event.attach(this.dom.file,"keypress",function(event) {
			if (event.keyCode != 13) { return; }
			useRef();
		});
		OAT.Event.attach(this.dom.ok,"click",useRef);
		OAT.Event.attach(this.dom.cancel,"click",function(event) {
			OAT.WebDav.window.close();
		});
		OAT.Event.attach(this.dom.ext,"change",function(event) {
			var ext = OAT.WebDav.options.extensionFilters[OAT.WebDav.dom.ext.selectedIndex];
			var val = OAT.WebDav.dom.file.value;
			var idx = val.lastIndexOf(".");
			if (idx != -1 && ext[1] != "*") {
				OAT.WebDav.dom.file.value = val.substring(0,idx)+"."+ext[1];
			}
			OAT.WebDav.redraw();
		});

		OAT.MSG.attach(this.tree, "TREE_EXPAND", function(tree,msg,node) {
			var path = node.path;
			OAT.WebDav.openDirectory(path,true,node);
		});
	},

	parseNode:function(node) { /* parse one response node */
		var result = {
			length:"",
			type:"",
			dir:false,
			creationDate:"",
			modificationDate:"",
			name:"",
			fullName:"",
			permissions:"",
			uid:"",
			gid:""
		};
		var propstat = OAT.Xml.getElementsByLocalName(node,"propstat")[0]; /* first propstat contains http/200 */
		var prop = OAT.Xml.getElementsByLocalName(propstat,"prop")[0]; /* this contains successful properties */

		/* dir */
		var col = OAT.Xml.getElementsByLocalName(prop,"collection");
		if (col.length) { result.dir = true; }

		/* name */
		var href = OAT.Xml.getElementsByLocalName(node,"href")[0];
		result.fullName = OAT.Xml.textValue(href);
		result.fullName = decodeURIComponent(result.fullName);
		result.name = result.fullName.match(/([^\/]+)\/?$/)[1];

		/* dates */
		var tmp = OAT.Xml.getElementsByLocalName(prop,"creationdate");
		if (tmp.length) { result.creationDate = OAT.Xml.textValue(tmp[0]); }
		var tmp = OAT.Xml.getElementsByLocalName(prop,"getlastmodified");
		if (tmp.length) { result.modificationDate = OAT.Xml.textValue(tmp[0]); }

		/* perms, uid, gid */
		var tmp = OAT.Xml.getElementsByLocalName(prop,"virtpermissions");
		if (tmp.length) { result.permissions = OAT.Xml.textValue(tmp[0]); }
		var tmp = OAT.Xml.getElementsByLocalName(prop,"virtowneruid");
		if (tmp.length) { result.uid = OAT.Xml.textValue(tmp[0]); }
		var tmp = OAT.Xml.getElementsByLocalName(prop,"virtownergid");
		if (tmp.length) { result.gid = OAT.Xml.textValue(tmp[0]); }

		/* type & length */
		var tmp = OAT.Xml.getElementsByLocalName(prop,"getcontenttype");
		if (tmp.length) { result.type = OAT.Xml.textValue(tmp[0]); }
		var tmp = OAT.Xml.getElementsByLocalName(prop,"getcontentlength");
		if (tmp.length) { result.length = parseInt(OAT.Xml.textValue(tmp[0])).toSize(); }

		return result;
	},

	applyOptions:function(optObj) { /* inherit options */
		for (var p in optObj) { this.options[p] = optObj[p]; }
		if (!this.options.path)
			this.options.path = this.options.pathHome;
		if (!this.options.pathFallback)
			this.options.pathFallback = this.options.pathHome;
	},

	commonDialog:function(optObj) { /* common phase for both dialog types */
		this.applyOptions(optObj);
		var allContained = false;
		for (var i=0;i<this.options.extensionFilters.length;i++) {
			var filter = this.options.extensionFilters[i];
			if (filter[1] == "*") { allContained = true; }
		}
		if (!allContained) { /* add *.* filter */
			var f = ["*","*","All files"];
			this.options.extensionFilters.push(f);
		}

		if (!this.options.isDav) { /* simple mode */
			var info = "Please choose a file name.";
			var f = [];
			for (var i=0;i<this.options.extensionFilters.length;i++) {
				var filter = this.options.extensionFilters[i];
				if (filter[1] != "*") { f.push("*."+filter[1]); }
			}
			if (f.length) { info += "\nAvailable extensions: "+f.join(", "); }
			var file = prompt(info,this.options.path+this.options.file);
			if (!file) { return; }
			var r = file.match(/^(.*)([^\/]+)$/);
			if (!r) { return; }
			this.useFile(r[1],r[2]);
			return;
		}

		this.window.open();
		OAT.Dom.center(this.window.dom.container,1,1);
		OAT.Dom.show("dav_permissions");
		this.dom.file.value = this.options.file; /* preselected file name */

		OAT.Dom.clear(this.dom.ext); /* extension select */
		this.dom.ext.style.width = "";
		var index = 0;
		for (var i=0;i<this.options.extensionFilters.length;i++) {
			var f = this.options.extensionFilters[i];
			var label = f[2] + " (*." + f[1] + ")";
			OAT.Dom.option(label,f[0],this.dom.ext);
			if (f[0] == this.options.extension) { index = i; }
		}
		this.dom.ext.selectedIndex = index;
		var w = OAT.Dom.getWH(this.dom.ext)[0]+2;
		this.dom.ext.style.width = (w+4)+"px";
		this.dom.file.style.width = w+"px";

		this.dom.ok.style.width = "";
		this.dom.cancel.style.width = "";
		var w1 = OAT.Dom.getWH(this.dom.ok)[0];
		var w2 = OAT.Dom.getWH(this.dom.cancel)[0];
		var w = Math.max(w1,w2)+2;
		this.dom.ok.style.width = w+"px";
		this.dom.cancel.style.width = w+"px";

		if (this.options.path in this.cache) {
			delete this.cache[this.options.path];
		}
		OAT.WebDav.openDirectory(this.options.path,false,this.tree.tree.children[0]);
	},

	imagePathHtml:function(name) { /* get html code for image */
		var style = "width:16px;height:16px;";
		var path = this.options.imagePath+"Tree_"+name+"."+this.options.imageExt;
		if (OAT.Browser.isIE && this.options.imageExt.toLowerCase() == "png") {
			style += "filter:progid:DXImageTransform.Microsoft.AlphaImageLoader(src='"+path+"', sizingMethod='crop')";
			path = this.options.imagePath+"Blank.gif";
		}
		return '<img src="'+path+'" style="'+style+'" />';
	},

	updatePermissions:function(url,permString,cb) {
		var newPermissions = "";
		if (permString) {
			newPermissions = permString;
		} else {
			for (var i=0;i<this.dom.perms.length;i++) {
				var ch = this.dom.perms[i];
				newPermissions += (ch.checked ? "1" : "0");
			}
		}
		var data = "";
		data += '<?xml version="1.0" encoding="utf-8" ?>' +
				'<propfind xmlns="DAV:"><prop>' +
				'	<virtpermissions xmlns="http://www.openlinksw.com/virtuoso/webdav/1.0/"/>' +
				' </prop></propfind>';

		var headers = OAT.WebDav.options.connectionHeaders;
		headers.Depth = 1;

		var o = {
			headers:headers,
			type:OAT.AJAX.TYPE_XML
		}
		OAT.WebDav.updateOptions(o);
		var ref = function(xmlDoc) {
			/* extract existing, apply new */
			var pnode = OAT.Xml.getElementsByLocalName(xmlDoc.documentElement,"virtpermissions")[0];
			var perms = OAT.Xml.textValue(pnode);
			var end = perms.substring(perms.length-2);
			newPermissions += end;
			var patch = "";
			patch += '<?xml version="1.0" encoding="utf-8" ?>' +
					'<D:propertyupdate xmlns:D="DAV:"><D:set><D:prop>'+
					'<virtpermissions xmlns="http://www.openlinksw.com/virtuoso/webdav/1.0/">'+newPermissions+'</virtpermissions>' +
					'</D:prop></D:set></D:propertyupdate>';
			OAT.AJAX.PROPPATCH(url,patch,function(){
				if (cb) { cb(); }
			},o);
		}
		OAT.AJAX.PROPFIND(url,data,ref,o);
	},

/* backwards compatibility */

	open:function(opts) {
		var o = {};
		if ("user" in opts) { o.user = opts.user; }
		if ("pass" in opts) { o.pass = opts.pass; }
		if ("pathDefault" in opts) { o.path = opts.pathDefault; }
		if ("imagePath" in opts) { o.imagePath = opts.imagePath; }
		if ("imageExt" in opts) { o.imageExt = opts.imageExt; }
		if ("dontDisplayWarning" in opts) { o.confirmOverwrite = !opts.dontDisplayWarning; }
		if ("onConfirmClick" in opts) { o.callback = opts.onConfirmClick; }
		if ("filetypes" in opts) {
			var f = [];
			for (var i=0;i<opts.filetypes.length;i++) {
				var ft = opts.filetypes[i];
				var filter = [ft.ext,ft.ext,ft.label];
				f.push(filter);
			}
			o.extensionFilters = f;
		}

		if (opts.mode == 'open_dialog' || opts.mode == 'browser') {
			OAT.WebDav.openDialog(o);
		} else {
			o.dataCallback = o.callback;
			o.callback = opts.afterSave;
			OAT.WebDav.saveDialog(o);
		}
	},

	getFileName:function(user,pass,path,oEF,button,callback) {
		var o = {
			user:user,
			pass:pass,
			path:path,
			callback:callback
		}
		OAT.WebDav.openDialog(o);
	},

	getFile:function(user,pass,path,oEF,button,callback) {
		var o = {
			user:user,
			pass:pass,
			path:path,
			callback:callback
		}
		OAT.WebDav.openDialog(o);
	},

	saveFile:function(user,pass,path,content,ui,callback) {
		var dataCallback = function() {
			return content;
		}
		var o = {
			user:user,
			pass:pass,
			path:path,
			confirmOverwrite:(ui == false),
			dataCallback:dataCallback,
			callback:callback
		}
		OAT.WebDav.saveDialog(o);
	},

	updateOptions:function(o) {
		if (!o.headers.Authorization)	{
//			o.auth = OAT.AJAX.AUTH_BASIC;
			o.user = OAT.WebDav.options.user;
			o.password = OAT.WebDav.options.pass;
		}
	},

	hiddenCheck:function(name) {
		if (OAT.WebDav.hiddens.length == 0)
			return true;
		for (var i = 0; i < OAT.WebDav.hiddens.length; i++) {
			if (name.indexOf(OAT.WebDav.hiddens[i]) == 0)
				return false;
		}
		return true;
	}
}

OAT.Dav = { /* legacy backwards compatibility! */

	getFile:function(dir,file) { /* no dav prompt */
		var ld = (dir ? dir : ".");
		var lf = (file ? ld+"/"+file : ld+"/");
		return prompt("Choose a file name",lf);
	},

	getNewFile:function(dir,file,filters) { /* no dav prompt */
		var ld = (dir ? dir : ".");
		var str = (file ? dir+"/"+file : dir+"/");
		return prompt("Choose a file name",str);
	}
}

