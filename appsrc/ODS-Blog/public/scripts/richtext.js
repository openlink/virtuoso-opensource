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
// Cross-Browser Rich Text Editor
// http://www.kevinroth.com/rte/demo.htm
// Written by Kevin Roth (kevin@NOSPAMkevinroth.com - remove NOSPAM)
// Visit the support forums at http://www.kevinroth.com/forums/index.php?c=2

//init variables
var isRichText = false;
var rng;
var currentRTE;
var allRTEs = "";

var isIE;
var isGecko;
var isSafari;
var isKonqueror;

var imagesPath;
var includesPath;
var cssFile;
var enclosure;


function initRTE(imgPath, incPath, css, enclosureFld) {
  //set browser vars
  var ua = navigator.userAgent.toLowerCase();
  isIE = ((ua.indexOf("msie") != -1) && (ua.indexOf("opera") == -1) && (ua.indexOf("webtv") == -1)); 
  isGecko = (ua.indexOf("gecko") != -1);
  isSafari = (ua.indexOf("safari") != -1);
  isKonqueror = (ua.indexOf("konqueror") != -1);
  
  //check to see if designMode mode is available
  if (document.getElementById && document.designMode && !isSafari && !isKonqueror) {
    isRichText = true;
  }
  
  if (isIE) {
    document.onmouseover = raiseButton;
    document.onmouseout  = normalButton;
    document.onmousedown = lowerButton;
    document.onmouseup   = raiseButton;
  }
  
  //set paths vars
  imagesPath = imgPath;
  includesPath = incPath;
  cssFile = css;
  enclosure = enclosureFld;
  
  if (isRichText) document.writeln('<style type="text/css">@import "' + includesPath + 'rte.css";</style>');
  
  //for testing standard textarea, uncomment the following line
  //isRichText = false;
}

function writeRichText(rte, html, width, height, buttons, readOnly) {
  if (isRichText) {
    if (allRTEs.length > 0) allRTEs += ";";
    allRTEs += rte;
  
  if (readOnly) buttons = false;
  
  //adjust minimum table widths
  if (isIE) {
    if (buttons && (width < 600)) width = 400;
    var tablewidth = width;
  } else {
    if (buttons && (width < 500)) width = 400;
    var tablewidth = width + 4;
  }
  
  document.writeln('<div class="rteDiv">');
  if (buttons == true) {
    document.writeln('<table class="rteBack" cellpadding=2 cellspacing=0 id="Buttons1_' + rte + '" width="' + tablewidth + '">');
    document.writeln('  <tr>');
    document.writeln('    <td>');
      document.writeln('      <select id="formatblock_' + rte + '" onchange="selectFont(\'' + rte + '\', this.id);">');
    document.writeln('        <option value="">[Style]</option>');
      document.writeln('        <option value="<p>">Paragraph &lt;p&gt;</option>');
      document.writeln('        <option value="<h1>">Heading 1 &lt;h1&gt;</option>');
      document.writeln('        <option value="<h2>">Heading 2 &lt;h2&gt;</option>');
      document.writeln('        <option value="<h3>">Heading 3 &lt;h3&gt;</option>');
      document.writeln('        <option value="<h4>">Heading 4 &lt;h4&gt;</option>');
      document.writeln('        <option value="<h5>">Heading 5 &lt;h5&gt;</option>');
      document.writeln('        <option value="<h6>">Heading 6 &lt;h6&gt;</option>');
      document.writeln('        <option value="<address>">Address &lt;ADDR&gt;</option>');
      document.writeln('        <option value="<pre>">Formatted &lt;pre&gt;</option>');
    document.writeln('      </select>');
    document.writeln('    </td>');
    document.writeln('    <td>');
      document.writeln('      <select id="fontname_' + rte + '" onchange="selectFont(\'' + rte + '\', this.id)">');
    document.writeln('        <option value="Font" selected>[Font]</option>');
    document.writeln('        <option value="Arial, Helvetica, sans-serif">Arial</option>');
    document.writeln('        <option value="Courier New, Courier, mono">Courier New</option>');
    document.writeln('        <option value="Times New Roman, Times, serif">Times New Roman</option>');
    document.writeln('        <option value="Verdana, Arial, Helvetica, sans-serif">Verdana</option>');
    document.writeln('      </select>');
    document.writeln('    </td>');
    document.writeln('    <td>');
      document.writeln('      <select unselectable="on" id="fontsize_' + rte + '" onchange="selectFont(\'' + rte + '\', this.id);">');
    document.writeln('        <option value="Size">[Size]</option>');
    document.writeln('        <option value="1">1</option>');
    document.writeln('        <option value="2">2</option>');
    document.writeln('        <option value="3">3</option>');
    document.writeln('        <option value="4">4</option>');
    document.writeln('        <option value="5">5</option>');
    document.writeln('        <option value="6">6</option>');
    document.writeln('        <option value="7">7</option>');
    document.writeln('      </select>');
    document.writeln('    </td>');
    document.writeln('    <td width="100%">');
    document.writeln('    </td>');
    document.writeln('  </tr>');
    document.writeln('</table>');
    document.writeln('<table class="rteBack" cellpadding="0" cellspacing="0" id="Buttons2_' + rte + '" width="' + tablewidth + '">');
    document.writeln('  <tr>');
      document.writeln('    <td><img id="bold" class="rteImage" src="' + imagesPath + 'bold.gif" width="25" height="24" alt="Bold" title="Bold" onClick="rteCommand(\'' + rte + '\', \'bold\', \'\')"></td>');
      document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'italic.gif" width="25" height="24" alt="Italic" title="Italic" onClick="rteCommand(\'' + rte + '\', \'italic\', \'\')"></td>');
      document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'underline.gif" width="25" height="24" alt="Underline" title="Underline" onClick="rteCommand(\'' + rte + '\', \'underline\', \'\')"></td>');
    document.writeln('    <td><img class="rteVertSep" src="' + imagesPath + 'blackdot.gif" width="1" height="20" border="0" alt=""></td>');
      document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'left_just.gif" width="25" height="24" alt="Align Left" title="Align Left" onClick="rteCommand(\'' + rte + '\', \'justifyleft\', \'\')"></td>');
      document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'centre.gif" width="25" height="24" alt="Center" title="Center" onClick="rteCommand(\'' + rte + '\', \'justifycenter\', \'\')"></td>');
      document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'right_just.gif" width="25" height="24" alt="Align Right" title="Align Right" onClick="rteCommand(\'' + rte + '\', \'justifyright\', \'\')"></td>');
      document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'justifyfull.gif" width="25" height="24" alt="Justify Full" title="Justify Full" onclick="rteCommand(\'' + rte + '\', \'justifyfull\', \'\')"></td>');
    document.writeln('    <td><img class="rteVertSep" src="' + imagesPath + 'blackdot.gif" width="1" height="20" border="0" alt=""></td>');
      document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'hr.gif" width="25" height="24" alt="Horizontal Rule" title="Horizontal Rule" onClick="rteCommand(\'' + rte + '\', \'inserthorizontalrule\', \'\')"></td>');
    document.writeln('    <td><img class="rteVertSep" src="' + imagesPath + 'blackdot.gif" width="1" height="20" border="0" alt=""></td>');
      document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'numbered_list.gif" width="25" height="24" alt="Ordered List" title="Ordered List" onClick="rteCommand(\'' + rte + '\', \'insertorderedlist\', \'\')"></td>');
      document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'list.gif" width="25" height="24" alt="Unordered List" title="Unordered List" onClick="rteCommand(\'' + rte + '\', \'insertunorderedlist\', \'\')"></td>');
    document.writeln('    <td><img class="rteVertSep" src="' + imagesPath + 'blackdot.gif" width="1" height="20" border="0" alt=""></td>');
      document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'outdent.gif" width="25" height="24" alt="Outdent" title="Outdent" onClick="rteCommand(\'' + rte + '\', \'outdent\', \'\')"></td>');
      document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'indent.gif" width="25" height="24" alt="Indent" title="Indent" onClick="rteCommand(\'' + rte + '\', \'indent\', \'\')"></td>');
      document.writeln('    <td><div id="forecolor_' + rte + '"><img class="rteImage" src="' + imagesPath + 'textcolor.gif" width="25" height="24" alt="Text Color" title="Text Color" onClick="dlgColorPalette(\'' + rte + '\', \'forecolor\', \'\')"></div></td>');
      document.writeln('    <td><div id="hilitecolor_' + rte + '"><img class="rteImage" src="' + imagesPath + 'bgcolor.gif" width="25" height="24" alt="Background Color" title="Background Color" onClick="dlgColorPalette(\'' + rte + '\', \'hilitecolor\', \'\')"></div></td>');
    document.writeln('    <td><img class="rteVertSep" src="' + imagesPath + 'blackdot.gif" width="1" height="20" border="0" alt=""></td>');
      document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'hyperlink.gif" width="25" height="24" alt="Insert Link" title="Insert Link" onClick="insertLink(\'' + rte + '\')"></td>');
      document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'image.gif" width="25" height="24" alt="Add Image" title="Add Image" onClick="addImage(\'' + rte + '\')"></td>');
      document.writeln('    <td><div id="table_' + rte + '"><img class="rteImage" src="' + imagesPath + 'insert_table.gif" width="25" height="24" alt="Insert Table" title="Insert Table" onClick="dlgInsertTable(\'' + rte + '\', \'table\', \'\')"></div></td>');

      document.writeln('    <td><div id="emotion_' + rte + '"><img class="rteImage" src="' + imagesPath + 'tb_smiley_1.gif" width="25" height="24" alt="Insert Emotion" title="Insert Emotion" onClick="dlgEmotion(\'' + rte + '\', \'emotion\', \'\')"></div></td>');

      if (enclosure != null)
        {  
          document.writeln('    <td><div id="media_' + rte + '"><img class="rteImage" src="' + imagesPath + 'quicktime.gif" width="20" height="20" alt="Insert Media" title="Insert Media" onClick="openWebDAV(\'' + rte + '\')"></div></td>');
        }

    if (isIE) {
      document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'spellcheck.gif" width="25" height="24" alt="Spell Check" title="Spell Check" onClick="checkspell()"></td>');
    }
//    document.writeln('    <td><img class="rteVertSep" src="' + imagesPath + 'blackdot.gif" width="1" height="20" border="0" alt=""></td>');
  //    document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'cut.gif" width="25" height="24" alt="Cut" title="Cut" onClick="rteCommand(\'' + rte + '\', \'cut\')"></td>');
  //    document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'copy.gif" width="25" height="24" alt="Copy" title="Copy" onClick="rteCommand(\'' + rte + '\', \'copy\')"></td>');
  //    document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'paste.gif" width="25" height="24" alt="Paste" title="Paste" onClick="rteCommand(\'' + rte + '\', \'paste\')"></td>');
//    document.writeln('    <td><img class="rteVertSep" src="' + imagesPath + 'blackdot.gif" width="1" height="20" border="0" alt=""></td>');
  //    document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'undo.gif" width="25" height="24" alt="Undo" title="Undo" onClick="rteCommand(\'' + rte + '\', \'undo\')"></td>');
  //    document.writeln('    <td><img class="rteImage" src="' + imagesPath + 'redo.gif" width="25" height="24" alt="Redo" title="Redo" onClick="rteCommand(\'' + rte + '\', \'redo\')"></td>');
    document.writeln('    <td width="100%"></td>');
    document.writeln('  </tr>');
    document.writeln('</table>');
  }
  document.writeln('<iframe id="' + rte + '" name="' + rte + '" width=99%" height="' + height + 'px" src="' + includesPath + 'blank.htm"></iframe>');
  if (!readOnly) document.writeln('<br /><input type="checkbox" id="chkSrc' + rte + '" onclick="toggleHTMLSrc(\'' + rte + '\');" />&nbsp;<label for="chkSrc'+ rte +'">View Source</label>');
    document.writeln('<iframe width="154" height="104" id="cp' + rte + '" src="' + includesPath + 'palette.htm" marginwidth="0" marginheight="0" scrolling="no" style="visibility:hidden; position: absolute;"></iframe>');
    document.writeln('<iframe width="106" height="176" id="em' + rte + '" src="' + includesPath + 'smiley.htm" marginwidth="0" marginheight="0" scrolling="no" style="visibility:hidden; position: absolute;"></iframe>');
  document.writeln('<input type="hidden" id="hdn' + rte + '" name="' + rte + '" value="">');
  document.writeln('</div>');
  
  document.getElementById('hdn' + rte).value = html;
  enableDesignMode(rte, html, readOnly);
  } else {
    if (!readOnly) {
      document.writeln('<textarea name="' + rte + '" id="' + rte + '" style="width: ' + width + 'px; height: ' + height + 'px;">' + html + '</textarea>');
    } else {
      document.writeln('<textarea name="' + rte + '" id="' + rte + '" style="width: ' + width + 'px; height: ' + height + 'px;" readonly>' + html + '</textarea>');
    }
  }
}

function enableDesignMode(rte, html, readOnly) {
  var frameHtml = "<html id=\"" + rte + "\">\n";
  frameHtml += "<head>\n";
  //to reference your stylesheet, set href property below to your stylesheet path and uncomment
  if (cssFile.length > 0) {
    frameHtml += "<link media=\"all\" type=\"text/css\" href=\"" + cssFile + "\" rel=\"stylesheet\">\n";
  } else {
    frameHtml += "<style>\n";
    frameHtml += "body {\n";
    frameHtml += "  background: #FFFFFF;\n";
    frameHtml += "  margin: 0px;\n";
    frameHtml += "  padding: 0px;\n";
    frameHtml += "}\n";
    frameHtml += "</style>\n";
  }
  frameHtml += "</head>\n";
  frameHtml += "<body>\n";
  frameHtml += html + "\n";
  frameHtml += "</body>\n";
  frameHtml += "</html>";
  
  if (document.all) {
    var oRTE = frames[rte].document;
    oRTE.open();
    oRTE.write(frameHtml);
    oRTE.close();
    if (!readOnly) oRTE.designMode = "On";
  } else {
    try {
      if (!readOnly) document.getElementById(rte).contentDocument.designMode = "on";
      try {
        var oRTE = document.getElementById(rte).contentWindow.document;
        oRTE.open();
        oRTE.write(frameHtml);
        oRTE.close();
        if (isGecko && !readOnly) {
          //attach a keyboard handler for gecko browsers to make keyboard shortcuts work
          oRTE.addEventListener("keypress", kb_handler, true);
        }
      } catch (e) {
        alert("Error preloading content.");
      }
    } catch (e) {
      //gecko may take some time to enable design mode.
      //Keep looping until able to set.
      if (isGecko) {
        setTimeout("enableDesignMode('" + rte + "', '" + html + "', " + readOnly + ");", 10);
      } else {
        return false;
      }
    }
  }
}

function updateRTEs() {
  var vRTEs = allRTEs.split(";");
  for (var i = 0; i < vRTEs.length; i++) {
    updateRTE(vRTEs[i]);
  }
}

function updateRTE(rte) {
  if (!isRichText) return;
  
  //set message value
  var oHdnMessage = document.getElementById('hdn' + rte);
  var oRTE = document.getElementById(rte);
  var readOnly = false;
  
  //check for readOnly mode
  if (document.all) {
    if (frames[rte].document.designMode != "On") readOnly = true;
  } else {
    if (document.getElementById(rte).contentDocument.designMode != "on") readOnly = true;
  }
  
  if (isRichText && !readOnly) {
    //if viewing source, switch back to design view
    if (document.getElementById("chkSrc" + rte).checked) {
      document.getElementById("chkSrc" + rte).checked = false;
      toggleHTMLSrc(rte);
    }
    
    if (oHdnMessage.value == null) oHdnMessage.value = "";
    if (document.all) {
      oHdnMessage.value = frames[rte].document.body.innerHTML;
    } else {
      oHdnMessage.value = oRTE.contentWindow.document.body.innerHTML;
    }
    
    //if there is no content (other than formatting) set value to nothing
    if (stripHTML(oHdnMessage.value.replace("&nbsp;", " ")) == "" 
      && oHdnMessage.value.toLowerCase().search("<hr") == -1
      && oHdnMessage.value.toLowerCase().search("<img") == -1) oHdnMessage.value = "";
    //fix for gecko
    if (escape(oHdnMessage.value) == "%3Cbr%3E%0D%0A%0D%0A%0D%0A") oHdnMessage.value = "";
  }
}

function rteCommand(rte, command, option) {
  //function to perform command
  var oRTE;
  if (document.all) {
    oRTE = frames[rte];
  } else {
    oRTE = document.getElementById(rte).contentWindow;
  }
  
  try {
    oRTE.focus();
      oRTE.document.execCommand(command, false, option);
    oRTE.focus();
  } catch (e) {
//    alert(e);
//    setTimeout("rteCommand('" + rte + "', '" + command + "', '" + option + "');", 10);
  }
}

function toggleHTMLSrc(rte) {
  //contributed by Bob Hutzel (thanks Bob!)
  var oRTE;
  if (document.all) {
    oRTE = frames[rte].document;
  } else {
    oRTE = document.getElementById(rte).contentWindow.document;
  }
  
  if (document.getElementById("chkSrc" + rte).checked) {
    showHideElement("Buttons1_" + rte, "hide");
    showHideElement("Buttons2_" + rte, "hide");
    if (document.all) {
      oRTE.body.innerText = oRTE.body.innerHTML;
    } else {
      var htmlSrc = oRTE.createTextNode(oRTE.body.innerHTML);
      oRTE.body.innerHTML = "";
      oRTE.body.appendChild(htmlSrc);
    }
  } else {
    showHideElement("Buttons1_" + rte, "show");
    showHideElement("Buttons2_" + rte, "show");
    if (document.all) {
      //fix for IE
      var output = escape(oRTE.body.innerText);
      output = output.replace("%3CP%3E%0D%0A%3CHR%3E", "%3CHR%3E");
      output = output.replace("%3CHR%3E%0D%0A%3C/P%3E", "%3CHR%3E");
      
      oRTE.body.innerHTML = unescape(output);
    } else {
      var htmlSrc = oRTE.body.ownerDocument.createRange();
      htmlSrc.selectNodeContents(oRTE.body);
      oRTE.body.innerHTML = htmlSrc.toString();
    }
  }
}

function dlgColorPalette(rte, command) {
  //function to display or hide color palettes
  setRange(rte);
  
  //get dialog position
  var oDialog = document.getElementById('cp' + rte);
  var buttonElement = document.getElementById(command + '_' + rte);
  var iLeftPos = getOffsetLeft(buttonElement);
  var iTopPos = getOffsetTop(buttonElement) + (buttonElement.offsetHeight + 4);
  oDialog.style.left = (iLeftPos) + "px";
  oDialog.style.top = (iTopPos) + "px";
    
  if ((command == parent.command) && (rte == currentRTE)) {
    //if current command dialog is currently open, close it
    if (oDialog.style.visibility == "hidden") {
      showHideElement(oDialog, 'show');
    } else {
      showHideElement(oDialog, 'hide');
    }
  } else {
    //if opening a new dialog, close all others
    var vRTEs = allRTEs.split(";");
    for (var i = 0; i < vRTEs.length; i++) {
      showHideElement('cp' + vRTEs[i], 'hide');
      showHideElement('em' + vRTEs[i], 'hide');
    }
    showHideElement(oDialog, 'show');
  }
    
  //save current values
  parent.command = command;
  currentRTE = rte;
  }

function dlgEmotion(rte, command) {
  //function to display or hide color palettes
  setRange(rte);
  
  //get dialog position
  var oDialog = document.getElementById('em' + rte);
  var buttonElement = document.getElementById(command + '_' + rte);
  var iLeftPos = getOffsetLeft(buttonElement);
  var iTopPos = getOffsetTop(buttonElement) + (buttonElement.offsetHeight + 4);
  oDialog.style.left = (iLeftPos) + "px";
  oDialog.style.top = (iTopPos) + "px";
    
  if ((command == parent.command) && (rte == currentRTE))
  {
    //if current command dialog is currently open, close it
    if (oDialog.style.visibility == "hidden")
    {
      showHideElement(oDialog, 'show');
    }
    else
    {
      showHideElement(oDialog, 'hide');
    }
  }
  else
  {
    //if opening a new dialog, close all others
    var vRTEs = allRTEs.split(";");
    for (var i = 0; i < vRTEs.length; i++)
    {
      showHideElement('em' + vRTEs[i], 'hide');
      showHideElement('cp' + vRTEs[i], 'hide');
    }
    showHideElement(oDialog, 'show');
  }    
  //save current values
  parent.command = command;
  currentRTE = rte;
  }
  
function dlgInsertTable(rte, command) {
  //function to open/close insert table dialog
      //save current values
  setRange(rte);
      parent.command = command;
      currentRTE = rte;
  var windowOptions = 'history=no,toolbar=0,location=0,directories=0,status=0,menubar=0,scrollbars=no,resizable=no,width=360,height=200';
  window.open(includesPath + 'insert_table.htm', 'InsertTable', windowOptions);
}
      
function insertLink(rte) {
  //function to insert link
      var szURL = prompt("Enter a URL:", "");
      try {
        //ignore error for blank urls
    rteCommand(rte, "Unlink", null);
    rteCommand(rte, "CreateLink", szURL);
      } catch (e) {
        //do nothing
      }
}

function setColor(color) {
  //function to set color
  var rte = currentRTE;
  var parentCommand = parent.command;
  
  if (document.all) {
    //retrieve selected range
    var sel = frames[rte].document.selection; 
    if (parentCommand == "hilitecolor") parentCommand = "backcolor";
    if (sel != null) {
      var newRng = sel.createRange();
      newRng = rng;
      newRng.select();
    }
  }
    
  rteCommand(rte, parentCommand, color);
  showHideElement('cp' + rte, "hide");
  }

function setEmotion(color) {
  //function to set color
  var rte = currentRTE;
  var parentCommand = parent.command;
  
  if (document.all) {
    //retrieve selected range
    var sel = frames[rte].document.selection; 
    //if (parentCommand == "hilitecolor") parentCommand = "backcolor";
    if (sel != null) {
      var newRng = sel.createRange();
      newRng = rng;
      newRng.select();
    }
  }
    
  rteCommand(rte, 'InsertImage', color);
  showHideElement('em' + rte, "hide");
  }
  
function addImage(rte) {
  //function to add image
  imagePath = prompt('Enter Image URL:', 'http://');        
  if ((imagePath != null) && (imagePath != "")) {
    rteCommand(rte, 'InsertImage', imagePath);
  }
}


function openWebDAV (rte)
{
  var tpath, sid, realm, encl;
  var path, fsid;

  if (enclosure == null)
    return;

  encl  = document.forms[0][enclosure];
  tpath = document.forms[0]['b_home_path'];
  fsid  = document.forms[0]['sid'];

  if (encl == null || tpath == null || fsid == null)
    {
      alert ("Cannot initialize the WebDAV browser");
      return;
    }

  path  = tpath.value;
  sid   = fsid.value;
  realm = 'wa';

  window.encl1 = encl; 
  window.path = tpath;
  window.open ('/weblog/public/popup_browser.vspx'+
   '?sid=' + sid + '&realm=' + realm + 
   '&path='+ escape (path)+ 
   '&list_type=details&flt=yes&browse_type=res&w_title=Briefcase&title=Briefcase&retname=' + enclosure, 
   'media_selection_window', 'scrollbars=auto, resizable=yes, menubar=no, height=600, width=800');
  window.eventHandler = "opener.insertMedia('" + rte + "', false)";
}

function insertMedia(rte, prom) {
  //function to add image
  var encl = enclosure != null ? document.forms[0][enclosure] : null;
  var initialUrl = encl && encl.value.length > 1 ? encl.value : 'http://' ;
  var mediaPath = prom ? prompt ('Enter Media URL:', initialUrl) : initialUrl;        
  var img = 'wmp.jpg';
  var id = '{id}';
  var w = 320, h = 240;
  var type = '{type}';

  if ((mediaPath != null) && (mediaPath != "") && (mediaPath != "http://")) {

     if (mediaPath.lastIndexOf ('.mov') != -1)
       img = 'qt.jpg'; 
     else if (mediaPath.lastIndexOf ('.rm') != -1)
       img = 'rp.jpg'; 
         

     currentRTE = rte;
     insertHTML (  
      '<img src="/weblog/public/images/'+ img +'" title="Play Media" alt="Play Media" border="0" ' + 
      ' id="media_' + id + '" onclick="javascript: playMedia (' + 
      ' \'' + mediaPath + '\', \'media_'+ id +'\' , ' + w + ', ' + h + ', \'' + type + '\' ' +
      '); return false" />' 
      ); 
  }
}

// Ernst de Moor: Fix the amount of digging parents up, in case the RTE editor itself is displayed in a div.
// KJR 11/12/2004 Changed to position palette based on parent div, so palette will always appear in proper location regardless of nested divs
function getOffsetTop(elm) {
  var mOffsetTop = elm.offsetTop;
  var mOffsetParent = elm.offsetParent;
  var parents_up = 6; //the positioning div is 2 elements up the tree
  
  while(parents_up > 0) {
    mOffsetTop += mOffsetParent.offsetTop;
    mOffsetParent = mOffsetParent.offsetParent;
    parents_up--;
  }
  
  return mOffsetTop;
}

// Ernst de Moor: Fix the amount of digging parents up, in case the RTE editor itself is displayed in a div.
// KJR 11/12/2004 Changed to position palette based on parent div, so palette will always appear in proper location regardless of nested divs
function getOffsetLeft(elm) {
  var mOffsetLeft = elm.offsetLeft;
  var mOffsetParent = elm.offsetParent;
  var parents_up = 6;
  
  while(parents_up > 0) {
    mOffsetLeft += mOffsetParent.offsetLeft;
    mOffsetParent = mOffsetParent.offsetParent;
    parents_up--;
  }
  
  return mOffsetLeft;
}

function selectFont(rte, selectname) {
  //function to handle font changes
  var idx = document.getElementById(selectname).selectedIndex;
  // First one is always a label
  if (idx != 0) {
    var selected = document.getElementById(selectname).options[idx].value;
    var cmd = selectname.replace('_' + rte, '');
    rteCommand(rte, cmd, selected);
    document.getElementById(selectname).selectedIndex = 0;
  }
}

function kb_handler(evt) {
  var rte = evt.target.id;
  
  //contributed by Anti Veeranna (thanks Anti!)
  if (evt.ctrlKey) {
    var key = String.fromCharCode(evt.charCode).toLowerCase();
    var cmd = '';
    switch (key) {
      case 'b': cmd = "bold"; break;
      case 'i': cmd = "italic"; break;
      case 'u': cmd = "underline"; break;
    };

    if (cmd) {
      rteCommand(rte, cmd, null);
      
      // stop the event bubble
      evt.preventDefault();
      evt.stopPropagation();
    }
  }
}

function insertHTML(html) {
  //function to add HTML -- thanks dannyuk1982
  var rte = currentRTE;
  
  var oRTE;
  if (document.all) {
    oRTE = frames[rte];
  } else {
    oRTE = document.getElementById(rte).contentWindow;
  }
  
  oRTE.focus();
  if (document.all) {
    oRTE.document.selection.createRange().pasteHTML(html);
  } else {
    oRTE.document.execCommand('insertHTML', false, html);
  }
}

function showHideElement(element, showHide) {
  //function to show or hide elements
  //element variable can be string or object
  if (document.getElementById(element)) {
    element = document.getElementById(element);
  }
  
  if (showHide == "show") {
    element.style.visibility = "visible";
  } else if (showHide == "hide") {
    element.style.visibility = "hidden";
  }
}

function setRange(rte) {
  //function to store range of current selection
  var oRTE;
  if (document.all)
  {
    oRTE = frames[rte];
    var selection = oRTE.document.selection; 
    if (selection != null) rng = selection.createRange();
  }
  else
  {
    oRTE = document.getElementById(rte).contentWindow;
    var selection = oRTE.getSelection();
    rng = selection.getRangeAt(selection.rangeCount - 1).cloneRange();
  }
}

function stripHTML(oldString) {
  //function to strip all html
  var newString = oldString.replace(/(<([^>]+)>)/ig,"");
  
  //replace carriage returns and line feeds
   newString = newString.replace(/\r\n/g," ");
   newString = newString.replace(/\n/g," ");
   newString = newString.replace(/\r/g," ");
  
  //trim string
  newString = trim(newString);
  
  return newString;
}

function trim(inputString) {
   // Removes leading and trailing spaces from the passed string. Also removes
   // consecutive spaces and replaces it with one space. If something besides
   // a string is passed in (null, custom object, etc.) then return the input.
   if (typeof inputString != "string") return inputString;
   var retValue = inputString;
   var ch = retValue.substring(0, 1);
  
   while (ch == " ") { // Check for spaces at the beginning of the string
      retValue = retValue.substring(1, retValue.length);
      ch = retValue.substring(0, 1);
   }
   ch = retValue.substring(retValue.length - 1, retValue.length);
  
   while (ch == " ") { // Check for spaces at the end of the string
      retValue = retValue.substring(0, retValue.length - 1);
      ch = retValue.substring(retValue.length - 1, retValue.length);
   }
  
  // Note that there are two spaces in the string - look for multiple spaces within the string
   while (retValue.indexOf("  ") != -1) {
    // Again, there are two spaces in each of the strings
      retValue = retValue.substring(0, retValue.indexOf("  ")) + retValue.substring(retValue.indexOf("  ") + 1, retValue.length);
   }
   return retValue; // Return the trimmed string back to the user
}

//*****************
//IE-Only Functions
//*****************
function checkspell() {
  //function to perform spell check
  try {
    var tmpis = new ActiveXObject("ieSpell.ieSpellExtension");
    tmpis.CheckAllLinkedDocuments(document);
  }
  catch(exception) {
    if(exception.number==-2146827859) {
      if (confirm("ieSpell not detected.  Click Ok to go to download page."))
        window.open("http://www.iespell.com/download.php","DownLoad");
    } else {
      alert("Error Loading ieSpell: Exception " + exception.number);
    }
  }
}

function raiseButton(e) {
  //IE-Only Function
  var el = window.event.srcElement;
  
  className = el.className;
  if (className == 'rteImage' || className == 'rteImageLowered') {
    el.className = 'rteImageRaised';
  }
}

function normalButton(e) {
  //IE-Only Function
  var el = window.event.srcElement;
  
  className = el.className;
  if (className == 'rteImageRaised' || className == 'rteImageLowered') {
    el.className = 'rteImage';
  }
}

function lowerButton(e) {
  //IE-Only Function
  var el = window.event.srcElement;
  
  className = el.className;
  if (className == 'rteImage' || className == 'rteImageRaised') {
    el.className = 'rteImageLowered';
  }
}
