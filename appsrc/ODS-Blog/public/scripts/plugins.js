/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

//This script detects the following:
//Flash
//Windows Media Player
//Java
//Shockwave
//RealPlayer
//QuickTime
//Acrobat Reader
//SVG Viewer


var isIE;
var isGecko;
var isSafari;
var isKonqueror;
var ua = navigator.userAgent.toLowerCase();

isIE = ((ua.indexOf("msie") != -1) && (ua.indexOf("opera") == -1) && (ua.indexOf("webtv") == -1)); 
isGecko = (ua.indexOf("gecko") != -1);
isSafari = (ua.indexOf("safari") != -1);
isKonqueror = (ua.indexOf("konqueror") != -1);

var win = ((ua.indexOf("win")!=-1) || (ua.indexOf("32bit")!=-1));
var mac = (ua.indexOf("mac")!=-1);



if (isIE && win) {	
   pluginlist = detectIE("Adobe.SVGCtl","SVG Viewer") + 
                detectIE("SWCtl.SWCtl.1","Shockwave Director") + 
                detectIE("ShockwaveFlash.ShockwaveFlash.1","Shockwave Flash") + 
                detectIE("rmocx.RealPlayer G2 Control.1","RealPlayer") + 
                detectIE("QuickTimeCheckObject.QuickTimeCheck.1","QuickTime") + 
                detectIE("MediaPlayer.MediaPlayer.1","Windows Media Player") + 
                detectIE("PDF.PdfCtrl.5","Acrobat Reader"); 
}

if (isGecko || !win) {
		nse = ""; 
                for (var i=0; i < navigator.mimeTypes.length; i++) 
                   nse += navigator.mimeTypes[i].type.toLowerCase();

		pluginlist = detectNS("image/svg-xml","SVG Viewer") + 
                             detectNS("application/x-director","Shockwave Director") + 
                             detectNS("application/x-shockwave-flash","Shockwave Flash") + 
                             detectNS("audio/x-pn-realaudio-plugin","RealPlayer") + 
                             detectNS("video/quicktime","QuickTime") + 
                             detectNS("application/x-mplayer2","Windows Media Player") + 
                             detectNS("application/pdf","Acrobat Reader");
}

function detectIE(ClassID,name) { 
          result = false; 
          document.write('<SCRIPT LANGUAGE=VBScript>\n on error resume next \n result = IsObject(CreateObject("' + ClassID + '"))</SCRIPT>\n'); 
          if (result) 
            return name+','; 
          else return ''; 
}
function detectNS(ClassID,name) { 
	n = ""; 
        if (nse.indexOf(ClassID) != -1) 
          if (navigator.mimeTypes[ClassID].enabledPlugin != null) 
            n = name+","; 
        return n; 
}

pluginlist += navigator.javaEnabled() ? "Java," : "";
if (pluginlist.length > 0) pluginlist = pluginlist.substring(0,pluginlist.length-1);

function playEnclosure (f, id, w, h, type) {	
  var ext = "", dot;
  var str = "";
  var img = "";

  dot = f.lastIndexOf ('.');
  if (dot != -1)
    ext = f.substring (dot + 1);

  if (pluginlist.indexOf ('QuickTime') != -1 && ext == "mov")
    {
      img = "qt.jpg";
    }
  else if (pluginlist.indexOf ('RealPlayer') != -1 && ext == "rm")
    {
      img = "rp.jpg";
    }
  else if (pluginlist.indexOf ('Windows Media Player') != -1)
    {
      img = "wmp.jpg";
    }
  else 
    {	
      img = "wmp.jpg";
    }		

  if (w == null)
    {
      w = 320;
      h = 240; 
    }
  document.write 
     (
      '<div id="media_' + id + '">' +
      '<input type="image" src="/weblog/public/images/'+img+'" value="Play Media" ' +
      ' title="Play Media" alt="Play Media" onclick="javascript: playEnclosure1 (' + 
      ' \'' + f + '\', \'media_'+ id +'\' , ' + w + ', ' + h + ', \'' + type + '\' ' +
      '); return false"/>' +
      '</div>' 
     );
}

function playMedia (f, id, w, h, type)
{
  var str = ""
  var div = null, parent, dnew;

  if (!document.getElementById)
    return;

  div = document.getElementById (id); 

  if (div == null)
    return false;

  str = getPlugin (f, id, w, h, type);

  parent = div.parentNode;
  dnew = document.createElement("div");
  dnew.style.width = w + 'px';
  dnew.style.height = h + 'px';
  parent.replaceChild (dnew, div);
  dnew.innerHTML = str;
  return false;
}

function getPlugin (f, id, w, h, type)
{
  var ext = "", dot, str = "";

  dot = f.lastIndexOf ('.');
  if (dot != -1)
    ext = f.substring (dot + 1);
  if (isIE && win && pluginlist.indexOf ('QuickTime') != -1 && ext == "mov")
    {
      str = 
      '<object width="'+w+'" height="'+h+'" ' +
	  'classid="clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B" ' +
          'standby="Loading QuickTime Player components..." ' +
	  'codebase="http://www.apple.com/qtactivex/qtplugin.cab">' +
	  '<param name="src" value="'+ f +'">' +
	  '<param name="autoplay" value="true">' +
	  '<param name="controller" value="true">' +
      '</object>';
    }
  else if (pluginlist.indexOf ('RealPlayer') != -1 && ext == "rm")
    {
      str = 
            '<embed src="'+ f +'" width="'+w+'" height="'+h+'" ' + 
            ' type="audio/x-pn-realaudio-plugin" autostart="true" controls="imagewindow,controlpanel" ' + 
            ' nojava="true" console="c1136134244899" pluginspage="http://www.real.com/"> </embed>' ; 
    }
  else if (isIE && pluginlist.indexOf ('Windows Media Player') != -1)
    {
      str = 
	  '<object width="'+w+'" height="'+h+'" style="" ' +
	  'classid="CLSID:6BF52A52-394A-11d3-B153-00C04F79FAA6" ' +
          'codebase="http://activex.microsoft.com/activex/controls/mplayer/en/nsmp2inf.cab#Version=5,1,52,701" ' +
          'standby="Loading Microsoft Windows Media Player components..." ' +
	  'type="application/x-oleobject">' +
	  '<param name="URL" value="' + f + '">' +
	  '<param name="SendPlayStateChangeEvents" value="True" >' +
	  '<param name="AutoStart" value="true">' +
	  '</object>';
    }
  else 
    {	
      str = '<embed src="'+ f +'" width="'+w+'" height="'+h+'" ' + 
			'autoplay="true" controller="true"></embed>';
    }		
  return str;
}

function playEnclosure1 (f, id, w, h, type) {	
  var str = ""
  var div = null;

  if (!document.getElementById)
    return;

  div = document.getElementById (id); 

  if (div == null)
    return false;

  str = getPlugin (f, id, w, h, type);

  div.innerHTML = str;
  return false;
}	
