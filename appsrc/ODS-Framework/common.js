/*
 *  $Id$
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
 */

function toggleControl (ctr1, val, ctr2)
{
  if (ctr2 == null)
    return;

  if (ctr1 && ctr1.value == val)
    {
      ctr2.disabled = true; 
    } 
  else
    {
      ctr2.disabled = false; 
    }  
}

function setSelectLists (val, form, pref)
{
  var i;
  if (val == 0 || form == null || pref == null)
    return;
  for (i = 0; i < form.elements.length; i++)
    {
      var contr = form.elements[i];
      if (contr != null && contr.type == "select-one" && contr.name.indexOf (pref) != -1)
        {
          contr.value = val;
        }   
    } 
}

function submitenter(fld, btn, e)
{
  var keycode;

  if (fld == null || fld.form == null)
    return true;

  if (window.event) 
    keycode = window.event.keyCode;
  else if (e) 
    keycode = e.which;
  else 
    return true;

  if (keycode == 13)
    {
      doPost (fld.form.name, btn);
      return false;
    }
  else
    return true;
}

var sflag = false;
var def_btn = null;
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

  dirty_force_global=document.getElementById('dirty_force_global');
  if(dirty_force_global != null){
     if(dirty_force_global.value=='true') dirty_force_global = true;
  }else{
     dirty_force_global = false;
  };

  if (dirty_force_global == true ) {
    dirty_force_global = false ;
    dirty = true;
  };
    
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


function submenuShowHide ()
{
  submenu_div=document.getElementById('submenu_block');
  if (submenu_div.style.display=='none')
    {
      submenu_div.style.display='block'
	  document.getElementById('myods_cell').className='sel';
    }
  else
    {
      submenu_div.style.display='none';
      document.getElementById('myods_cell').className=' ';
    } 
}
