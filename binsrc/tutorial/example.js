/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2014 OpenLink Software
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
function Show(objid){
  var obj = document.getElementById(objid);
  obj.style.display="";
  obj.visible = true;
}

function Hide(objid){
  var obj = document.getElementById(objid);
  obj.style.display="none";
  obj.visible = false;
}

var InitialCheck = 0;
var HaveInitialState = 1;

function toggle_tab(div_id,no_init_load){
	var obj = document.getElementById('tab_'+div_id);
	var ul_obj = document.getElementById('ex_navlist');
	var nodeList = returnListOfNodes(ul_obj.childNodes);
  for(var i=0;i<nodeList.length;i++){
    returnListOfNodes(nodeList[i].childNodes)[0].className = "";
  };
  obj.className = "current";
  
  var ContentDivs = Array(document.getElementById('info'),
  												 document.getElementById('initial_state'),
  												 document.getElementById('view_source'),
  												 document.getElementById('run'));
  for(var i=0;i<ContentDivs.length;i++){
  	if (ContentDivs[i].id == div_id && ContentDivs[i].style.display == 'none')
  	  Show(ContentDivs[i].id);
  	else if (ContentDivs[i].id != div_id && ContentDivs[i].style.display != 'none')
  		Hide(ContentDivs[i].id);
  };
  if (div_id == 'initial_state' && InitialCheck == 0) {
  	if (HaveInitialState)
  		CheckStatus();
  	else
			document.getElementById('initial_state').innerHTML = '<p>This example doesn\'t have initial state.</p>';
    InitialCheck = 1;
  };
  if (div_id == 'view_source' || div_id == 'initial_state') {
		//Patch for f..g IE not properly shows and resizes the div, it also hides the texts.
		if (navigator.userAgent.toLowerCase().indexOf('msie') > 0 && navigator.userAgent.indexOf('Opera') == -1 && window.onresize == null) {
			window.onresize = function(){
				var filesource = document.getElementById('filesource');
				if (filesource.offsetWidth > 0) {
					var filecontent = filesource.innerHTML;
					filesource.innerHTML = '';
					filesource.style.width = '78%';
					var div_width = filesource.offsetWidth;
					filesource.style.width = div_width - 2 + 'px';
					filesource.innerHTML = filecontent;
				};

				var content = document.getElementById('initial_state_content');
				if (content.offsetWidth > 0) {
					var res_content = content.innerHTML;
					content.innerHTML = '';
					content.style.width = '100%';
					var div_width = content.offsetWidth;
					content.style.width = div_width - 2 + 'px';
					content.innerHTML = res_content;
				};
			};
		};
		if (div_id == 'initial_state' && window.onresize != null)
			window.onresize();
  }
  
  if (div_id == 'view_source' && !no_init_load && Files.length) {
    var checked_vs = 0;
  	var filelist_ul = document.getElementById('filelist_nav');
  	for(i in Files){
  		if (filelist_ul.childNodes[i].firstChild.className == 'current') {
  		  checked_vs = 1;
  		}
  	}
  	if (!checked_vs) {
  	  LoadFile(Files[0]);
  	}
  }

  if (div_id == 'run' && !no_init_load && RunFiles.length) {
    var checked_vs = 0;
  	var runfilelist_ul = document.getElementById('runfilelist_nav');
  	for(i in RunFiles){
  		if (runfilelist_ul.childNodes[i].firstChild.className == 'current') {
  		  checked_vs = 1;
  		}
  	}
  	if (!checked_vs) {
  	  RunFile(RunFiles[0][0]);
  	  document.getElementById('run_frame').src = RunFiles[0][0];
  	}
  }
}

function InitialStateLink() {
	var content = document.getElementById('initial_state_content');
	content.innerHTML = '<p>Initializing, please wait...</p>';
	InitialCheck = 1;
	toggle_tab('initial_state');
	SetInitialState();
}

function returnListOfNodes(nodeList){
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

var timer = null;

function ResetState(){
	var xmlhttp = null;
  try {
    xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
  } catch (e) { }

  if (xmlhttp == null) {
    try {
      xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
    } catch (e) { }
  } // if

  // Gecko / Mozilla / Firefox
  if (xmlhttp == null)
    xmlhttp = new XMLHttpRequest();

	xmlhttp.open("POST", URL + '?load_scr_reset=1',false);
	xmlhttp.setRequestHeader("Pragma", "no-cache");
	xmlhttp.send("");
}

var req_handle = null;

function SetInitialState(){
	document.getElementById("bt_SetInitialState").disabled=true;
	ResetState();
	var content = document.getElementById('initial_state_content');
	var xmlhttp = null;
  try {
    xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
  } catch (e) { }

  if (xmlhttp == null) {
    try {
      xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
    } catch (e) { }
  } // if

  // Gecko / Mozilla / Firefox
  if (xmlhttp == null)
    xmlhttp = new XMLHttpRequest();

	xmlhttp.open("POST", URL + '?load_scr=1',true);
	xmlhttp.onreadystatechange = function() {
	  if (xmlhttp.readyState == 4) {
	    //content.innerHTML += '<hr/>Finished';
	  }
	};
	xmlhttp.setRequestHeader("Pragma", "no-cache");
	xmlhttp.send("");
	if (timer == null) 
		timer = setTimeout("CheckStatus()",500);
	
	req_handle = xmlhttp;
}

function CancelInitialState(){
	req_handle.abort();
}

function debug(str){
	var debug = document.getElementById('debug');
	debug.innerHTML = str + '<br/>' + debug.innerHTML;
}

function CheckStatus(){
	var content = document.getElementById('initial_state_content');
	var xmlhttp = null;
  try {
    xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
  } catch (e) { }

  if (xmlhttp == null) {
    try {
      xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
    } catch (e) { }
  } // if

  // Gecko / Mozilla / Firefox
  if (xmlhttp == null)
    xmlhttp = new XMLHttpRequest();

	xmlhttp.open("POST", URL + '?load_scr_status=1',true);
	xmlhttp.onreadystatechange = function() {
	  if (xmlhttp.readyState == 4) {
			var inx = xmlhttp.responseText.indexOf(':');
			var completed_val = xmlhttp.responseText.substring(0,inx);
			var content_val = xmlhttp.responseText.substring(inx + 1,xmlhttp.responseText.length)
		
			if (completed_val != 'noinit') {
				document.getElementById("PBcompleted").style.width = completed_val + '%';
				document.getElementById("PBcontent").innerHTML = completed_val + '%';
			}
			content.innerHTML = '<pre>' + content_val + '</pre>';
			content.scrollTop = content.scrollHeight;
			content.scrollTop = content.scrollHeight; // the second time is for IE. 
		
			if (completed_val < 100 && completed_val != null && completed_val != 'noinit') {
				document.getElementById("bt_SetInitialState").disabled=true;
			  timer = setTimeout("CheckStatus()",500);
			} else {
				document.getElementById("bt_SetInitialState").disabled=false;
				timer = null;
			}
	  }
	};
	xmlhttp.setRequestHeader("Pragma", "no-cache");
	xmlhttp.send("");
}

var Files = Array();

function FileListInit(){
	var filelist_ul = document.getElementById('filelist_nav');
	
	filelist_ul.innerHTML = '';
	for(i in Files){
		filelist_ul.innerHTML += '<li><a href="#" onclick="LoadFile(\''+Files[i]+'\')">&nbsp;' + Files[i] + '</a></li>';
	};
	if (Files.length == 0)
	  filelist_ul.innerHTML = '<li>~no files~</li>';
	
}

function LoadFile(in_File) {
	var filelist_ul = document.getElementById('filelist_nav');
	var hilite_btn = document.getElementById('hilite');
	hilite_btn.value = 'Show Syntax Highlight';
	hilite_btn.disabled = true;
	
	for(i in Files){
		filelist_ul.childNodes[i].firstChild.className='';
		if (in_File == Files[i]) {
			filelist_ul.childNodes[i].firstChild.className='current';
		};
	};

	var filesource = document.getElementById('filesource');
	filesource.innerHTML = 'Loading, please wait...';

	var xmlhttp = null;
  try {
    xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
  } catch (e) { }

  if (xmlhttp == null) {
    try {
      xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
    } catch (e) { }
  } // if

  // Gecko / Mozilla / Firefox
  if (xmlhttp == null)
    xmlhttp = new XMLHttpRequest();

	xmlhttp.open("POST", URL + '?src=' + in_File,true);
	xmlhttp.onreadystatechange = function() {
	  if (xmlhttp.readyState == 4) {
	  	var filecontent = xmlhttp.responseText.substring(xmlhttp.responseText.indexOf('<pre>\r\n')+7,xmlhttp.responseText.lastIndexOf('\r\n</pre>'));
			filesource.innerHTML = '<pre>' + filecontent + '</pre>';

			var hilite_btn = document.getElementById('hilite');
			hilite_btn.disabled = false;
	  }
	};
	xmlhttp.setRequestHeader("Pragma", "no-cache");
	xmlhttp.send("");
}

function ViewSourceLink(in_File) {
	toggle_tab('view_source',1);
	LoadFile(in_File);
}

function doSyntax (btn) {
	var filesource = document.getElementById('filesource');
  if (btn.value == 'Show Syntax Highlight') {
  	var lng = getFileLanguage();
  	var filecontent = filesource.innerHTML.substring(filesource.innerHTML.toLowerCase().indexOf('<pre>')+5,filesource.innerHTML.toLowerCase().lastIndexOf('</pre>'));
		filesource.innerHTML = '<textarea id="filesource_highlight" name="filesource_highlight" class="' + lng + ':nogutter:nocontrols">' + filecontent + '</textarea>';

		dp.SyntaxHighlighter.HighlightAll('filesource_highlight', true, false);
		btn.value = 'Hide Syntax Highlight';
	} else {
		var filecontent = document.getElementById('filesource_highlight').value.replace(/</g, '&lt;');;
		filesource.innerHTML = '<pre>' + filecontent + '</pre>';
		btn.value = 'Show Syntax Highlight';
  }
}

function getFileLanguage() {
	var filelist_ul = document.getElementById('filelist_nav');
	var FileExt = null;
	var ret = 'sql';
	
	for(i in Files){
		if(filelist_ul.childNodes[i].firstChild.className == 'current')
			break;
	};
	FileExt = Files[i].substring(Files[i].lastIndexOf('.')+1);
  //('java','pl','pm','bpel', 'xq', 'cpp', 'h')
	if (inArray(FileExt,Array('vsp','sql')))
	  ret = 'sql';
	else if (inArray(FileExt,Array('xsl','xml','html','vspx','wsdl','xslt','aspx')))
	  ret = 'xml';
	else if (inArray(FileExt,Array('cs')))
	  ret = 'c#';
	else if (inArray(FileExt,Array('php')))
	  ret = 'php';
	else if (inArray(FileExt,Array('py')))
	  ret = 'py';
	else if (inArray(FileExt,Array('rb')))
	  ret = 'rb';
	return ret;
}

function inArray(str,arr){
	for(i in arr){
		if (arr[i] == str)
			return 1;
	}
	return 0;
}

var RunFiles = Array();

function RunFileListInit(){
	var runfilelist_ul = document.getElementById('runfilelist_nav');

	runfilelist_ul.innerHTML = '';
	for(i in RunFiles){
		runfilelist_ul.innerHTML += '<li><a target="run_frame" href="'+RunFiles[i][0]+'" onclick="RunFile(\''+RunFiles[i][0].replace(/&#39;/g, "\\\'")+'\')">&nbsp;' + RunFiles[i][1] + '</a></li>';
	};
	if (RunFiles.length == 0)
	  runfilelist_ul.innerHTML = '<li>~no files~</li>';
	
}

function RunLink(in_File) {
	toggle_tab('run',1);
	RunFile(in_File);
}

function RunFile(in_Link) {
	var runfilelist_ul = document.getElementById('runfilelist_nav');
	
	for(i in RunFiles){
		runfilelist_ul.childNodes[i].firstChild.className='';
		if (in_Link == RunFiles[i][0].replace(/&amp;/g,'&').replace(/&#39;/g,'\'')) {
			runfilelist_ul.childNodes[i].firstChild.className='current';
		};
	};

}
