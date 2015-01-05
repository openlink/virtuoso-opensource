<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2015 OpenLink Software
#  
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#  
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#  
#  
?>
<SCRIPT LANGUAGE="JavaScript">
<!--
// The following code is used to support the small popups that
// give the full description of an event when the user move the
// mouse over it.

// Developer's note:
// I (Benoit Maisonny <benoit@synclude.com>) tested this code with Mozilla 0.8.1 (on Linux),
// with IE5.5 SP1 (on WinNT4) and with Netscape Communicator 4.74 (on Linux).
// Netscape 6.0 and 6.01 seem to have a bug related to the visibility attribute.
// I suppose it will be corrected as soon as they release a new version, based on
// a more recent Mozilla source code.
// I'm not able to test this javascript code with IE4. It'd be glad to know if it works.

NS4 = (document.layers) ? 1 : 0;
IE4 = (document.all) ? 1 : 0;
W3C = (document.getElementById) ? 1 : 0;	
// W3C stands for the W3C standard, implemented in Mozilla (and Netscape 6) and IE5

// Function show(evt, name)
//	evt is a pointer to the Event object passed when the event occurs
//	name is the ID attribute of the element to show
function show ( evt, name ) {
  if (IE4) {
    evt = window.event;  //is it necessary?
  }

  var currentX,		//mouse position on X axis
      currentY,		//mouse position on X axis
      x,		//layer target position on X axis
      y,		//layer target position on Y axis
      docWidth,		//width of current frame
      docHeight,	//height of current frame
      layerWidth,	//width of popup layer
      layerHeight,	//height of popup layer
      ele;		//points to the popup element

  // First let's initialize our variables
  if ( W3C ) {
    ele = document.getElementById(name);
    currentX = evt.clientX,
    currentY = evt.clientY;
    docWidth = document.width;
    docHeight = document.height;
    layerWidth = ele.style.width;
    layerHeight = ele.style.height;

  } else if ( NS4 ) {
    ele = document.layers[name];
    currentX = evt.pageX,
    currentY = evt.pageY;
    docWidth = document.width;
    docHeight = document.height;
    layerWidth = ele.clip.width;
    layerHeight = ele.clip.height;

  } else {	// meant for IE4
    ele = document.all[name];
    currentX = evt.clientX,
    currentY = evt.clientY;
    docHeight = document.body.offsetHeight;
    docWidth = document.body.offsetWidth;
    //var layerWidth = document.all[name].offsetWidth;
    // for some reason, this doesn't seem to work... so set it to 200
    layerWidth = 200;
    layerHeight = ele.offsetHeight;
  }

  // Then we calculate the popup element's new position
  if ( ( currentX + layerWidth ) > docWidth ) {
    x = ( currentX - layerWidth );
  }
  else {
    x = currentX;
  }
  if ( ( currentY + layerHeight ) >= docHeight ) {
     y = ( currentY - layerHeight - 20 );
  }
  else {
    y = currentY + 20;
  }
  if ( IE4 ) {
    x += document.body.scrollLeft;
    y += document.body.scrollTop;
  } else if ( NS4)  {
  } else {
    x += window.pageXOffset;
    y += window.pageYOffset;
  }
// (for debugging purpose) alert("docWidth " + docWidth + ", docHeight " + docHeight + "\nlayerWidth " + layerWidth + ", layerHeight " + layerHeight + "\ncurrentX " + currentX + ", currentY " + currentY + "\nx " + x + ", y " + y);

  // Finally, we set its position and visibility
  if ( NS4 ) {
    //ele.xpos = parseInt ( x );
    ele.left = parseInt ( x );
    //ele.ypos = parseInt ( y );
    ele.top = parseInt ( y );
    ele.visibility = "show";
  } else {  // IE4 & W3C
    ele.style.left = parseInt ( x );
    ele.style.top = parseInt ( y );
    ele.style.visibility = "visible";
  }
}

function hide ( name ) {
  if (W3C) {
    document.getElementById(name).style.visibility = "hidden";
  } else if (NS4) {
    document.layers[name].visibility = "hide";
  } else {
    document.all[name].style.visibility = "hidden";
  }
}

function unhide ( name ) {
  if (W3C) {
    document.getElementById(name).style.visibility = "visible";
  } else if (NS4) {
    document.layers[name].visibility = "show";
  } else {
    document.all[name].style.visibility = "visible";
  }
}

//-->

</SCRIPT>

