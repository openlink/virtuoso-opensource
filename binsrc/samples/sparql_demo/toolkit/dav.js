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
	temporary solution, waiting for some more sophisticated dav client
*/

OAT.Dav_old = {
	cache:{},

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
		if (filters && filters in OAT.Dav_old.cache) { str = OAT.Dav_old.cache[filters]; }
		var out = prompt("Choose a file name"+(filters ? " ("+filters+")" : ""),str);
		if (!out) return out;
		if (filters) { OAT.Dav_old.cache[filters] = out; }
		return out;
	}
}

/*
	more sophisticated dav client
*/

OAT.Dav = {
	getDir:function(dir) {
		var ld = (dir ? dir : ".");
		return prompt("Choose a directory",ld);
	},

	getFileOld:function(dir,file) {
		var ld = (dir ? dir : ".");
		var lf = (file ? ld+"/"+file : ld+"/");
		return prompt("Choose a file name",lf);
	},

	getNewFile:function(dir,file,filters) {
		var ld = (dir ? dir : ".");
		var str = (file ? dir+"/"+file : dir+"/");
		return prompt("Choose a file name"+(filters ? " ("+filters+")" : ""),str);
	},

  //----------------------------------------------------------------------------
	remove_path:function(path,prefix) {
		if(prefix){
			return path.substring(prefix.length,path.length).replace('/','');
		}else{
			return path.substring(path.lastIndexOf('/')+1,path.length);
		}
	},

	remove_parent:function(path) {
		return path.substring(path.lastIndexOf('/',-1)+1,path.length);
	},

  generate:function() {
		var data = "";
		data += '<?xml version="1.0" encoding="utf'+'-8" ?>' +
		        '<propfind xmlns="DAV:">' +
		        ' <prop>' +
		        '   <creationdate/>' +
		        '   <getlastmodified/>' +
		        '   <displayname/>' +
		        '   <href/>' +
		        '   <resourcetype/>' +
		        '   <getcontentlength/>' +
		        ' </prop>' +
		        '</propfind>';
    //data = '<?xml version="1.0" encoding="utf'+'-8" ?><propfind xmlns="DAV:"><D:allprop/></propfind>';
		return data;
	},

  //----------------------------------------------------------------------------
	command:function(target, data_func, return_func, customHeaders) {
		var ref = function() {
			return OAT.Soap.generate(data_func);
		}
		var h = false;
		if (customHeaders) { h = customHeaders; }
		OAT.Ajax.command(OAT.Ajax.SOAP, target, ref, return_func, customHeaders);
	},

  //----------------------------------------------------------------------------
	list:function(target,responce) {
		var ref = function() {
			return OAT.Dav.generate();
		}
		customHeaders = {Depth:1};
		OAT.Ajax.user = OAT.Dav.user;
		OAT.Ajax.password = OAT.Dav.pass;
		OAT.Ajax.command(OAT.Ajax.PROPFIND + OAT.Ajax.AUTH_BASIC, target, ref, responce,OAT.Ajax.TYPE_XML, customHeaders);

	},

  //----------------------------------------------------------------------------
  create_col:function(current_path,col_name,responce){
    OAT.Ajax.user = OAT.Dav.user;
    OAT.Ajax.password = OAT.Dav.pass;
    // TODO - validation
    var target = current_path+col_name;
		OAT.Ajax.command(OAT.Ajax.MKCOL + OAT.Ajax.AUTH_BASIC, target, function(){}, responce,OAT.Ajax.TYPE_TEXT);
  },

  //----------------------------------------------------------------------------
	getFile:function(dir,file,responce){
	  var ld = (dir ? dir : ".");
		var lf = (file ? ld+file : ld);
    var target = lf + '?'+ new Date().getMilliseconds();
    OAT.Ajax.user = OAT.Dav.user;
    OAT.Ajax.password = OAT.Dav.pass;
		OAT.Ajax.command(OAT.Ajax.GET + OAT.Ajax.AUTH_BASIC, target, function(){return '';}, responce,OAT.Ajax.TYPE_TEXT);
	},

  //----------------------------------------------------------------------------
	saveFile:function(dir,file,ref){
	  var ld = (dir ? dir : ".");
		var lf = (file ? ld+file : ld);
		var target = lf;
    OAT.Ajax.user = OAT.Dav.user;
    OAT.Ajax.password = OAT.Dav.pass;
		OAT.Ajax.command(OAT.Ajax.PUT + OAT.Ajax.AUTH_BASIC, target, ref, function(){},OAT.Ajax.TYPE_TEXT);
	},

  //----------------------------------------------------------------------------
  dom2list:function(data){
    var result = new Object();
    result.list = new Array();
    result.root = null;
    if(typeof data.tagName == 'undefined'){
      data = data.childNodes[0];
    }
    if(data.childNodes.length > 0){
      for(var i=0;i < data.childNodes.length;i++){
        if(data.childNodes[i].nodeType == 1){
          if(result.root == null){
            result.root = new OAT.DavType(data.childNodes[i]);
          }else{
            result.list[result.list.length] = new OAT.DavType(data.childNodes[i],result.root);
          }
        }
      }
    }
    return result;
  }

}

//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
OAT.DavType = function(el,root_el) {

  this.returnListOfNodes = function(nodeList){
    list = new Object();
    var x = 0;
    for(var i=0;i<nodeList.length;i++){
      if(nodeList[i].nodeType == 1){
        list[x++] = nodeList[i];
      }
    }
    list.length = x--;
    return list;
  }

  ns = '';
  if (OAT.Dom.isIE()){
    ns = 'D:';
  }
  var propstat = this.returnListOfNodes(el.getElementsByTagName(ns+"propstat")[0].childNodes);

  var t = this.returnListOfNodes(propstat[0].childNodes)[2];

  if(t.childNodes.length == 1 && t.childNodes[0].tagName.indexOf('collection') != -1){
    res_type = 'col'
  }else{
    res_type = 'res';
  }
    this.href = el.getElementsByTagName(ns+"href")[0].firstChild.nodeValue;

  if(root_el){
    this.name = OAT.Dav.remove_path(this.href,root_el.href);
  }else{
    this.name = OAT.Dav.remove_parent(this.href);
  }

  this.name = this.name.replace(/%20/g,' ');

  var prop = this.returnListOfNodes(propstat[0].childNodes);

  this.resourcetype = res_type;
  this.creationdate = OAT.get_prop_value(prop,'lp0:creationdate');
  this.lastmodified  = OAT.get_prop_value(prop,'lp0:getlastmodified');
  this.displayname = null;
  this.contentlength = OAT.get_prop_value(prop,'lp0:getcontentlength');
  //getcontentlengt

}

//----------------------------------------------------------------------------
OAT.get_prop_value = function (propList,propName){
  for(var i=0;i<propList.length;i++){
    if(propList[i].nodeName == propName){
      //alert(propList[i].nodeName);
      return propList[i].firstChild.nodeValue;
    }
  }
  return '';
}

//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
OAT.WebDav = {
  resources:new Array(),
  options: {
      container:'my_browser',
      mode:'browser',
      toolbar:{new_folder:true,change_view:true},
      user_pass_mandatory:false,
      user:'',
      pass:'',
      path:'',
      pathDefault:'/',
      filename:'',
      file_ext:'',
      width:750,
      height:420,
      x:120,
      y:120,
      imagePath:'ajax-tools/toolkit/images/',
      imageExt:'gif',
      onResClick:function(){},
      onOpenClick:function(){},
      onSaveClick:function(){},
      onOKClick:function(){},
      file_list_views:['detailed','icons'],
      file_list_current:0
  	},
  init:function(options){
    OAT.WebDav.options = OAT.WebDav.overwrite(OAT.WebDav.options,options);
    var defaultModes = ['browser','open_dialog','save_dialog'];
		if (defaultModes.find(options.mode) == -1) {
			options.mode = defaultModes[0];
		}
  },

  open:function(options){
    if(OAT.WebDav.is_open){
      return;
    }
    OAT.WebDav.is_open=1;
    OAT.WebDav.options = OAT.WebDav.overwrite(OAT.WebDav.options,options);

		if (OAT.WebDav.options.path == '') {
			OAT.WebDav.options.path = OAT.WebDav.options.pathDefault;
		}
		OAT.WebDav.options.path = OAT.WebDav.options.path.substring(0,OAT.WebDav.options.path.lastIndexOf('/')+1);

  	OAT.Ajax.handleError(function(status,text){
  	  if(status == 404){
  	    var msg = "The user: '"+OAT.Ajax.user+"' doesn't appear to have a valid WebDAV home directory.\nPlease contact your Virtuoso Database Administrator about this problem."
  	    alert(msg);
  	    OAT.WebDav.options.user = "";
  	    OAT.WebDav.options.pass = "";
  	    OAT.WebDav.options.path = "";
  	    OAT.WebDav.close();
  	  }else{
  	    alert('Problem #'+status+': '+text);
  	  }
  	})
    OAT.WebDav.dialog_user_pass();

    var win = new OAT.Window({min:0,max:0,close:1,width:OAT.WebDav.options.width,height:OAT.WebDav.options.height,x:OAT.WebDav.options.x,y:OAT.WebDav.options.y,imagePath:OAT.WebDav.options.imagePath,title:"WebDAV Browser"});
    win.div.style.zIndex=1000;
    win.div.id = "dav_browser";
    win.onclose = OAT.WebDav.close;
    document.body.appendChild(win.div);

    var toolbar = new OAT.Toolbar();
  	if(OAT.WebDav.options.toolbar.new_folder){
    	toolbar.addIcon(0,OAT.WebDav.options.imagePath+"icon_new.gif","Create New Folder",function(){
  	      OAT.WebDav.new_col_name = prompt('Create new folder','New Folder');
  	      if(OAT.WebDav.new_col_name != null){
  	        OAT.Dav.create_col(OAT.WebDav.activeNode.id,OAT.WebDav.new_col_name,function(data){
                var li = {name:OAT.WebDav.new_col_name,href:OAT.WebDav.activeNode.id+OAT.WebDav.new_col_name,resourcetype:'col'}
  	            OAT.WebDav.activeNode.childNodes[1].appendChild(OAT.WebDav.create_tree_node(li));
  	            alert('Succesfull');
  	          });
  	      }
  	    });
    	toolbar.addSeparator();
    }
  	if(OAT.WebDav.options.toolbar.change_view){
    	toolbar.addIcon(0,OAT.WebDav.options.imagePath+"icon_views_details.gif","Change View",function(){
    	  OAT.WebDav.options.file_list_current = 0;
    	  OAT.WebDav.show_resources(OAT.WebDav.activeNode.id);
    	  return;
    	});
    }
  	if(OAT.WebDav.options.toolbar.change_view){
    	toolbar.addIcon(0,OAT.WebDav.options.imagePath+"icon_views_icons.gif","Change View",function(){
    	  OAT.WebDav.options.file_list_current = 1;
    	  OAT.WebDav.show_resources(OAT.WebDav.activeNode.id);
    	  return;
    	});
    }
  	if(OAT.WebDav.options.toolbar){
	    win.content.appendChild(toolbar.div);
    }
    OAT.WebDav.path = OAT.Dom.create('div',{padding:"5px",borderBottom:"1px solid #cccccc"});
    OAT.WebDav.path.id = 'dav_path_div';
    var input = OAT.Dom.create("input",{width:"90%"});
  	input.setAttribute("type","text");
  	input.id = "dav_path";

    OAT.WebDav.path.appendChild(OAT.Dom.text('Location:'));
    OAT.WebDav.path.appendChild(input);

    win.content.appendChild(OAT.WebDav.path);

    OAT.WebDav.table = OAT.Dom.create('div');
    win.content.appendChild(OAT.WebDav.table);

    var left_col  = OAT.Dom.create('div');
    var right_col = OAT.Dom.create('div');
    var tree_cont = OAT.Dom.create('div');
    var spliter   = OAT.Dom.create('div');

    left_col.id  = 'dav_tree';
    right_col.id = 'dav_grid';
    spliter.id   = 'spliter';
    tree_cont.id = OAT.WebDav.options.pathDefault;

    left_col.appendChild(tree_cont);
    //left_col.appendChild(spliter);

    OAT.WebDav.table.appendChild(left_col);
    OAT.WebDav.table.appendChild(spliter);
    OAT.WebDav.table.appendChild(right_col);

  	/* resizing */
		function resizeRestriction(x,y) {
			return (x < 25);
		}
  	OAT.Resize.create("spliter","dav_tree",OAT.Resize.TYPE_X,resizeRestriction);
  	OAT.Resize.create("spliter","dav_grid",-OAT.Resize.TYPE_X,resizeRestriction);
	OAT.Resize.create(win.resize,"dav_tree",OAT.Resize.TYPE_Y);
	OAT.Resize.create(win.resize,"spliter",OAT.Resize.TYPE_Y);
	OAT.Resize.create(win.resize,"dav_grid",OAT.Resize.TYPE_XY);

    OAT.WebDav.buttons = OAT.Dom.create('div');
    OAT.WebDav.buttons.id="action_buttons";
    win.content.appendChild(OAT.WebDav.buttons);

    var ok = OAT.Dom.create('input',{marginLeft:'10px'});
    ok.id = 'dav_ok';
    ok.setAttribute('type','button');

    var cancel = OAT.Dom.create('input',{marginLeft:'10px'});
    cancel.id = 'dav_cancel';
    cancel.setAttribute('type','button');
    cancel.setAttribute('value','  Cancel  ');
    OAT.Dom.attach(cancel,'click',OAT.WebDav.close);

    var filename = OAT.Dom.create('input',{marginLeft:'10px'});
    filename.id = 'dav_filename';
    filename.setAttribute('type','text');

    if(OAT.WebDav.options.mode == "browser"){
      ok.setAttribute('value','  OK  ');
      OAT.Dom.attach(ok,'click',function(){
        var ext = OAT.WebDav.options.file_ext.indexOf('.') == 0 ? OAT.WebDav.options.file_ext.substring(1) : OAT.WebDav.options.file_ext;
        var pattern = eval('/\.'+ ext +'$/');
        if(ext != '' && pattern.exec($v('dav_filename')) == null){
          $('dav_filename').value = $v('dav_filename') + "."+ext;
        }
        var path = $v('dav_path');
        var fname = $('dav_filename').value;
        if(OAT.WebDav.selNode && OAT.WebDav.selNode.resourcetype == 'col'){
          path = OAT.WebDav.selNode.href;
        }
        OAT.WebDav.options.onOKClick(path,fname);
        OAT.WebDav.close();
      });

    }else if(OAT.WebDav.options.mode == "open_dialog"){
      ok.setAttribute('value','  Open  ');
      OAT.Dom.attach(ok,'click',OAT.WebDav.button_open_click);

    }else if(OAT.WebDav.options.mode == "save_dialog"){
      ok.setAttribute('value','  Save  ');
      OAT.Dom.attach(ok,'click',function(){
        if(confirm('Are you sure?')){
          var pattern = eval('/\.'+ OAT.WebDav.options.file_ext +'$/');
          if(OAT.WebDav.options.file_ext != '' && pattern.exec($v('dav_filename')) == null){
            $('dav_filename').value = $v('dav_filename') + "."+OAT.WebDav.options.file_ext;
          }
          OAT.WebDav.options.filename = $v('dav_filename');
          OAT.WebDav.options.path = $v('dav_path');
          OAT.Dav.saveFile($v('dav_path'),$v('dav_filename'),OAT.WebDav.options.onSaveClick);
          OAT.WebDav.close();
        }
      });
    }
    OAT.WebDav.buttons.appendChild(OAT.Dom.text('File name:'));
    OAT.WebDav.buttons.appendChild(filename);
    OAT.WebDav.buttons.appendChild(ok);
    OAT.WebDav.buttons.appendChild(cancel);
    OAT.Dav.user = OAT.WebDav.options.user;
    OAT.Dav.pass = OAT.WebDav.options.pass;
    $('dav_path').value     = OAT.WebDav.options.path;
    $('dav_filename').value = OAT.WebDav.options.filename;
    OAT.WebDav.firstRun   = 1;
    OAT.WebDav.activeNode = tree_cont;
    OAT.WebDav.selNode    = null;
    OAT.WebDav.get_list_first();
  },

  button_open_click:function(){
    if($v('dav_filename') == ''){
      return;
    }
    OAT.Dav.getFile($v('dav_path'),$v('dav_filename'),function(content){
        OAT.WebDav.options.filename = $v('dav_filename');
        OAT.WebDav.options.path = $v('dav_path');
        var path = $v('dav_path');
        var file = $v('dav_filename');
        if(OAT.WebDav.options.onOpenClick(path,file,content)){
          OAT.WebDav.close();
        }
      });
  },

  dialog_user_pass:function(){
    if(OAT.WebDav.options.user_pass_mandatory == 1){
    if(OAT.WebDav.options.user == ''){
        OAT.WebDav.options.user = prompt('Please fill valid Virtuoso user name','');
        OAT.WebDav.options.pass = prompt('Please fill your pass','');
        OAT.WebDav.options.path = '/DAV/home/'+ OAT.WebDav.options.user+'/';
    }
    }
  },

  close:function(){
    OAT.WebDav.clean_resources();
    OAT.WebDav.is_open=0;
    OAT.WebDav.options.filename = $v('dav_filename');
    OAT.WebDav.options.path     = $v('dav_path');
    OAT.Dom.unlink($('dav_browser'));
    OAT.Ajax.handleError(false);
  },



  //---------------------------------
	move:function(event) {
		if (OAT.WebDav.resizing) {
			/* selection removal... */
			var selObj = false;
			if (document.getSelection && !OAT.Dom.isGecko()) { selObj = document.getSelection(); }
			if (window.getSelection) { selObj = window.getSelection(); }
			if (document.selection) { selObj = document.selection; }
			if (selObj) {
				if (selObj.empty) { selObj.empty(); }
				if (selObj.removeAllRanges) { selObj.removeAllRanges(); }
			}
			/* lec gou */
			var obj = OAT.WebDav.resizing;
			var elm = obj.tmp_resize; /* vertical line */
			var offs_x = event.clientX - OAT.WebDav.x; /* offset */
			var new_x = OAT.WebDav.w + offs_x;
			if (new_x >= OAT.WebDav.LIMIT) {
				elm.style.left = new_x + "px";
				OAT.WebDav.w = new_x;
				OAT.WebDav.x = event.clientX;
			} /* if > limit */
		} /* if resizing */
	},

  //---------------------------------
  get_list_first:function(){
    if(OAT.WebDav.options.path != OAT.WebDav.options.pathDefault){
      OAT.WebDav.open_levels = OAT.WebDav.options.path.substring(OAT.WebDav.options.pathDefault.length,OAT.WebDav.options.path.length-1).split('/');
    }else{
      OAT.WebDav.open_levels = new Array();
    }
    OAT.Dav.list(OAT.WebDav.activeNode.id,OAT.WebDav.responce);
    return;
  },

  //---------------------------------
  get_list:function(){
    OAT.Dav.list(OAT.WebDav.activeNode.id,OAT.WebDav.responce);
  },

  //---------------------------------
  responce:function(data){
    $('dav_path').value=OAT.WebDav.activeNode.id.replace(/%20/g,' ');
    if(data.childNodes.length == 2){
		  data = data.childNodes[1];
    }
    data = OAT.Dav.dom2list(data);
    if(OAT.WebDav.firstRun==1){
      OAT.Dom.clear(OAT.WebDav.activeNode);
      OAT.WebDav.root = OAT.Dom.create('div',{cssFloat:"left",styleFloat:"left"});
      OAT.WebDav.root.innerHTML = OAT.WebDav.imagePathHtml("minus");
      OAT.WebDav.root_name = OAT.Dom.create('span',{fontSize:"12px"});
      OAT.WebDav.root_name.innerHTML = 'DAV';
      OAT.Dom.attach(OAT.WebDav.root_name, 'click', OAT.WebDav.col_name_click);
      OAT.WebDav.activeNode.appendChild(OAT.WebDav.root);
      OAT.WebDav.activeNode.appendChild(OAT.WebDav.root_name);
      OAT.WebDav.firstRun=0;
    }

    OAT.WebDav.show_tree(data);
    OAT.WebDav.load_resources(data);
    if(OAT.WebDav.open_levels.length > 0){
      OAT.WebDav.activeNode =  $(OAT.WebDav.activeNode.id+OAT.WebDav.open_levels[0].replace(/ /g,'%20')+"/");
      OAT.Dav.list(OAT.WebDav.activeNode.id,OAT.WebDav.responce);
      OAT.WebDav.open_levels.shift();
    }else{
    OAT.WebDav.show_resources(data.root.href);
    }
  },

  //---------------------------------
  show_tree:function(data){
  	has_col_childs = 0;

    var ul = OAT.Dom.create('ul');
    for(var i=0;i < data.list.length;i++){
      var el = data.list[i];
      if(el.resourcetype == 'col'){
        li = OAT.WebDav.create_tree_node(el)
        ul.appendChild(li);
        has_col_childs = 1;
       }
    }
    if(has_col_childs){
      OAT.WebDav.activeNode.appendChild(ul);
      OAT.WebDav.activeNode.setAttribute('loaded',1);
    }else{
      OAT.WebDav.reset(OAT.WebDav.activeNode);
      OAT.WebDav.activeNode.setAttribute('loaded',-1);
    }
  },

  //---------------------------------
  create_tree_node:function(el){
	  var sign = OAT.Dom.create("div",{"width":"16px","height":"16px","cssFloat":"left","styleFloat":"left"});
		sign.style.backgroundImage = this.imagePath("plus");
		sign.style.backgroundRepeat = "no-repeat";
    OAT.Dom.attach(sign, 'click', OAT.WebDav.col_sign_click);

    var sp = OAT.Dom.create('span',{backgroundImage:OAT.WebDav.imagePath("node"),backgroundRepeat:"no-repeat",padding:"1px",paddingLeft:"17px"});
    sp.innerHTML = el.name;
    OAT.Dom.attach(sp, 'click', OAT.WebDav.col_name_click);

    var li = OAT.Dom.create('li');
    li.appendChild(sign);
    li.appendChild(sp);
    li.id = el.href;
    li.setAttribute('class','collapsed');
    return li;
  },

  //---------------------------------
  load_resources:function(data){
    var new_index = OAT.WebDav.resources.length;
    OAT.WebDav.resources[new_index] = new Object;
    OAT.WebDav.resources[new_index].root = data.root;
    OAT.WebDav.resources[new_index].list = new Array();
    for(var i=0;i<data.list.length;i++){
      if(data.list[i].resourcetype == 'col'){
        OAT.WebDav.resources[new_index].list[OAT.WebDav.resources[new_index].list.length] = data.list[i];
      }
    }
    for(var i=0;i<data.list.length;i++){
      if(data.list[i].resourcetype != 'col'){
        OAT.WebDav.resources[new_index].list[OAT.WebDav.resources[new_index].list.length] = data.list[i];
      }
    }
  },

  //---------------------------------
  clean_resources:function(){
    OAT.WebDav.resources = new Array;
  },

  //---------------------------------
  show_resources:function(id){
    if(OAT.WebDav.options.file_list_current == 0){
      OAT.WebDav.show_resources_details(id);
    }else{
      OAT.WebDav.show_resources_icons(id);
    }
  },

  //---------------------------------
  show_resources_details:function(id){
  	OAT.WebDav.grid = new OAT.Grid("dav_grid",0);
  	var header = ["Name",{value:"Size",align:OAT.Grid.ALIGN_RIGHT},"Type","Modified"];
  	OAT.WebDav.grid.createHeader(header);
    var data = this.find_col_resources(id);
    for(var i=0;i < data.list.length;i++){
      var el = data.list[i];
      if(el.resourcetype == 'col'){
        var ico_type = 'node';
      }else{
        var ico_type = 'leaf';
      }

      var ico = OAT.WebDav.imagePathHtml(ico_type) + el.name;
      var del = OAT.Dom.create('img');
      OAT.WebDav.grid.createRow([{value:ico},{value:el.contentlength},el.resourcetype,el.lastmodified])
      OAT.Dom.attach(OAT.WebDav.grid.rows[i].html,'click',OAT.WebDav.list_click(el,i));
      OAT.Dom.attach(OAT.WebDav.grid.rows[i].html,'dblclick',OAT.WebDav.list_dblclick(el,i));
      OAT.WebDav.grid.rows[i].html.id = 'list_'+el.href;
    }
  },

  //---------------------------------
  show_resources_icons:function(id){
    OAT.WebDav.grid = $('dav_grid');
    OAT.WebDav.grid.innerHTML="";
    var data = this.find_col_resources(id);

    OAT.WebDav.grid.style.padding = "5px";

    for(var i=0;i < data.list.length;i++){
      var el = data.list[i];
      if(el.resourcetype == 'col'){
        var ico_type = 'node';
      }else{
        var ico_type = 'leaf';
      }

      var ico = "<img src='"+OAT.WebDav.options.imagePath+"Tree_"+ico_type+"_big."+OAT.WebDav.options.imageExt+"' >" + '<br>'+el.name;
      var cube = OAT.Dom.create('div',{width:"60px",height:"60px",cssFloat:"left",styleFloat:"left",textAlign:"center",paddingTop:"10px",overflow:"hidden",margin:"5px"});

      cube.innerHTML = ico;
      cube.id = 'list_'+el.href;
      OAT.WebDav.grid.appendChild(cube);
      OAT.Dom.attach(cube,'click',OAT.WebDav.list_click(el,i));
      OAT.Dom.attach(cube,'dblclick',OAT.WebDav.list_dblclick(el,i));
    }
  },


  //---------------------------------
  list_click:function(el,index){
    return function(){
      var node = $(el.href);
      OAT.WebDav.list_sel(el,index);
      if(el.resourcetype == 'res'){
        $('dav_filename').value=OAT.Dav.remove_path(el.href);
      }
    }
  },

  //---------------------------------
  list_dblclick:function(el,index){
    return function(){
      var node = $(el.href);
      if(typeof node == "object"){
        OAT.WebDav.activeNode = node;
        OAT.WebDav.get_list();
      }else{
        $('dav_filename').value=OAT.Dav.remove_path(el.href);
        if(OAT.WebDav.options.mode == 'open_dialog'){
          OAT.WebDav.button_open_click();
        }
      }
    }
  },

  //---------------------------------
  list_sel:function(el,index){
    OAT.WebDav.selNode = el;
    if(OAT.WebDav.options.file_list_current == 1){
      var grid = OAT.WebDav.grid.childNodes;
      for(var i=0;i<grid.length;i++){
        grid[i].style.backgroundColor="";
        grid[i].style.color="";
      }
      var tr = grid[index];
      tr.style.backgroundColor="#0000ff";
      tr.style.color="#fff";

    }
  },


  //---------------------------------
  col_sign_click:function(e){
    if (!e) var e = window.event
    var obj = (e.target) ? e.target : e.srcElement
    var node = obj.parentNode;
    if(node.getAttribute('loaded') != -1){
      OAT.WebDav.toggle(node);
    }
    OAT.WebDav.col_name_click(e);
  },

  //---------------------------------
  col_name_click:function(e){
    if (!e) var e = window.event
    var obj = (e.target) ? e.target : e.srcElement

    var node = obj.parentNode;

    OAT.WebDav.sel_tree_node(node);

    if(!node.getAttribute('loaded')){
      // Loading new childs
      OAT.WebDav.activeNode = node;
      OAT.WebDav.get_list();

    }else {
      OAT.WebDav.show_resources(node.id);
      $('dav_path').value=node.id;
    }

  },

  //---------------------------------
  find_col_resources:function(id){
    for(var i=0;i < OAT.WebDav.resources.length;i++){
      if(OAT.WebDav.resources[i].root.href == id){
        return OAT.WebDav.resources[i];
      }
    }
  },

  //---------------------------------
  sel_tree_node:function(obj){
    var parent = obj.parentNode.parentNode;

    OAT.WebDav.activeNode.childNodes[1].style.backgroundColor="";
    OAT.WebDav.activeNode.childNodes[1].style.color="";

    obj.childNodes[1].style.backgroundColor="#0000ff";
    obj.childNodes[1].style.color="#fff";

  },

  //---------------------------------
  toggle:function(node) {
		this.update(node);
	},


	//---------------------------------
	update:function(node) {
    if (node.childNodes[0].style.backgroundImage == this.imagePath("minus")) {

			if(node.childNodes.length > 2){
  			node.childNodes[2].style.display = "none";
  		}
			node.childNodes[0].style.backgroundImage = this.imagePath("plus");
		}else {
      if(node.childNodes.length > 2){
        node.childNodes[2].style.display = "block";
  		}
			node.childNodes[0].style.backgroundImage = this.imagePath("minus");
		}
	},

  //---------------------------------
  imagePath:function(name) {
		return "url("+OAT.WebDav.options.imagePath+"Tree_"+name+"."+OAT.WebDav.options.imageExt+")";
	},

  //---------------------------------
  imagePathHtml:function(name) {
		return "<img src='"+OAT.WebDav.options.imagePath+"Tree_"+name+"."+OAT.WebDav.options.imageExt+"' align='left'>";
	},

  //---------------------------------
  reset:function(node){
    node.childNodes[0].style.backgroundImage = this.imagePath("blank");
  },

  //---------------------------------
  overwrite:function(options,new_options){
	//var result = options;
	//for (var p in new_options) { result[p] = new_options[p]; }
	//return result;

  	for (var p in options) {
      if (p in new_options) {
    	  if(typeof options[p] == 'object'){
    	    options[p] = OAT.WebDav.overwrite(options[p],new_options[p]);
    	  }else{
    			options[p] = new_options[p];
    		}
  		}
  	}
    return options;
  }
}

//----------------------------------------------------------------------------


OAT.Loader.pendingCount--;
