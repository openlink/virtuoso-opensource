/*
 *  $Id$
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
 */

var sflag = false;
var def_btn = null;

function checkPageLeaveExt (form, func)
{
  try
  {
    func ();
  }
  catch (e) 
  {
  }
  return checkPageLeave (form);
}

function checkPageLeave (form)
{
  var dirty = false;
  var ret = true;
  var btn = def_btn;
  var i;
  if (sflag == true || btn == null || btn == '' || form.__submit_func.value != '' || form.__event_initiator.value != '')
    return true;
  for (i = 0; i < form.elements.length; i++)
    {
      if (form.elements[i] != null)
        {
          var ctrl = form.elements[i];
          if (!ctrl || !ctrl.type)
            continue;
          if (ctrl.type.indexOf ('select') != -1)
            {
              var j, selections = 0;
    	  for (j = 0; j < ctrl.length; j ++)
    	    {
                  var opt = ctrl.options[j];
    	      if (opt.defaultSelected == true)
    		selections ++;
                  if (opt.defaultSelected != opt.selected)
                    {
                      dirty = true;
                    }
            }
    	  if (selections == 0 && ctrl.selectedIndex == 0)
    	    dirty = false;
    	  if (dirty == true)
    	    {
    	      //alert (ctrl.name+' value=['+ctrl.value+'] default=['+ctrl.defaultValue+']');
    	      break;
    	    }
            }
          else if ((ctrl.type.indexOf ('text') != -1 || ctrl.type == 'password') && ctrl.defaultValue != ctrl.value)
            {
    	      //alert (ctrl.name+' value=['+ctrl.value+'] default=['+ctrl.defaultValue+']');
              dirty = true;
       	      break;
            }
          else if ((ctrl.type == 'checkbox' || ctrl.type == 'radio') &&
    	  ctrl.defaultChecked != ctrl.checked
    	)
            {
    	  //alert (ctrl.name+' value=['+ctrl.checked+'] default=['+ctrl.defaultChecked+']');
              dirty = true;
              break;
            }
        }
    }
  if (dirty == true)
    {
      ret =
confirm ('You are about to leave the page, but there is changed data which is not saved.\r\nDo you wish to save changes ?');
        if (ret == true)
          {
            form.__submit_func.value = '__submit__';
            form.__submit_func.name = btn;
            form.submit ();
          }
    }
   return ret;
}

function getFileName(form, from, to)
{
  var S = from.value;
  var N;
  var fname;
  if (S.lastIndexOf('\\') > 0)
    N = S.lastIndexOf('\\')+1;
  else
    N = S.lastIndexOf('/')+1;
  fname = S.substr(N,S.length);
  to.value = fname;
}


function checkSelected (form, txt, selectionMsq) {
  if ((form != null) && (txt != null)) {
    for (var i = 0; i < form.elements.length; i++) {
      var obj = form.elements[i];
      if (obj != null && obj.type == "checkbox" && obj.name.indexOf (txt) != -1 && obj.checked)
        return true;
    }
    if (selectionMsq != null)
      alert(selectionMsq);
    return false;
  }
  return true;
}


//Bookmark on del.icio.us
function dbt_bookmark(title, tags) {
  //URL of this document
  var loc=location.href;
  //Strip out any anchors
  var apos=loc.indexOf('&sid');
  loc=(apos>0?loc.substring(0,apos):loc);
  //Redirect to del.icio.us
  var ref = 'http://del.icio.us/post?v=2&url='
      + encodeURIComponent(loc)
      +'&title='
      + encodeURIComponent(title);
  location.href = ref;
  //Return false so the link won't be activated. 
  return false;
}

function toggle_comment (id)
{
  if (!document.getElementById)
    return;
  var div = document.getElementById ('msg_' + id);
  var img = document.getElementById ('img_' + id);
  var visb = div.style.visibility;

  if (!div)
    return;

  if (div.style.visibility.indexOf ("hidden") == -1)
    {
      div.style.visibility = "hidden"; 
      img.src = "/weblog/public/images/plus.gif"
    }
  else
    {
      div.style.visibility = "visible";
      img.src = "/weblog/public/images/minus.gif"
    }
}

var ns6 = (document.getElementById)? true:false;

function displayComment (id)
{
      var obj;
      if (!ns6) return;
      obj = document.getElementById ('ct_'+id);
      obj.style.visibility = "visible";
}

function hideComment (id)
{
      var obj;
      if (!ns6) return;
      obj = document.getElementById ('ct_'+id);
      obj.style.visibility = "hidden";
}

/*
  JavaScript functions from the pages
*/

function selectAllCheckboxes (form, btn, txt)
{
  var i;
  for (i =0; i < form.elements.length; i++)
    {
      var contr = form.elements[i];
      if (contr != null && contr.type == "checkbox" && contr.name.indexOf (txt) != -1)
        {
    contr.focus();
    if (btn.value == 'Select All')
      contr.checked = true;
    else
            contr.checked = false;
  }
    }
  if (btn.value == 'Select All')
    btn.value = 'Unselect All';
  else
    btn.value = 'Select All';
  btn.focus();
}

function selectAllCheckboxes2 (form, btn, txt, txt2)
{
  var i;
  for (i =0; i < form.elements.length; i++)
    {
      var contr = form.elements[i];
      if (contr != null && contr.type == "checkbox" && contr.name.indexOf (txt)  != -1 && contr.name.indexOf(txt2) != -1)
        {
    contr.focus();
    if (btn.value == 'Select All')
      contr.checked = true;
    else
            contr.checked = false;
  }
    }
  if (btn.value == 'Select All')
    btn.value = 'Unselect All';
  else
    btn.value = 'Select All';
  btn.focus();
}


function
getActiveStyleSheet ()
{
  var i, a;

  for (i=0; (a = document.getElementsByTagName ("link")[i]); i++)
    {
      if (a.getAttribute ("rel").indexOf ("style") != -1
          && a.getAttribute ("title")
          && !a.disabled)
        return a.getAttribute("title");
    }

  return null;
}

function setSelectedStyle()
{
  var a;
  a = document.getElementsByName("style_selector")[0];
  if (a)
  {
    for (i=0; (b=a.options[i]); i++)
    {
      if (b.text==getActiveStyleSheet())
      a.options[i].selected=true;
    }
  }
}

function
setActiveStyleSheet (title, save_cookie)
{
  if (save_cookie == 0)
  {
    var j, b;
    for (j = 0; (b = document.getElementsByName ('save_sticky')[j]); j++)
    {
      if (b.checked == true)
      {
        save_cookie = 1;
    }
    }
  }
  var i, a, main, isset;
  isset = 0;
  for (i = 0; (a = document.getElementsByTagName ("link")[i]); i++)
  {
    if (a.getAttribute ("rel").indexOf ("style") != -1 && a.getAttribute ("title"))
    {
      a.disabled = true;
      if (a.getAttribute ("title") == title)
      {
        isset = 1;
        a.disabled = false;
        if (save_cookie)
        {
          createCookie ("style", title, 365);
        }
      }
    }
  }
  if (isset == 0)
  {
    for (i = 0; (a = document.getElementsByTagName ("link")[i]); i++)
    {
      if (a.getAttribute ("rel").indexOf ("style") != -1 && a.getAttribute ("title"))
      {
        a.disabled = false;
        setSelectedStyle();
        return null;
      }
    }
  }
  else
    setSelectedStyle();
}

function getPreferredStyleSheet ()
{
  var i, a;

  for (i=0; (a = document.getElementsByTagName ("link")[i]); i++)
    {
      if(a.getAttribute ("rel").indexOf ("style") != -1
         && a.getAttribute ("rel").indexOf ("alt") == -1
         && a.getAttribute ("title"))
        return a.getAttribute ("title");
    }

  return null;
}

function createCookie (name, value, days)
{
  if (days)
    {
      var date = new Date();
      date.setTime(date.getTime()+(days*24*60*60*1000));
      var expires = "; expires="+date.toGMTString();
    }
  else expires = "";

  document.cookie = name+"="+value+expires+"; path=/";
}

function readCookie(name) {
  var nameEQ = name + "=";
  var ca = document.cookie.split (';');
  for(var i = 0; i < ca.length; i++) {
    var c = ca[i];
    while (c.charAt(0) == ' ') c = c.substring (1, c.length);
    if (c.indexOf(nameEQ) == 0) return c.substring (nameEQ.length,
c.length);
  }
  return null;
}

function makeSSMenu ()
{
  var x = document.getElementByID ('ss_menu_ctr');
  var ssElems = getSSElems ();
}

