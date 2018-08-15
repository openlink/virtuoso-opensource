/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

function selectAllCheckboxes (form, btn)
{
  for (var i = 0;i < form.elements.length;i++)
  {
      var contr = form.elements[i];
      if (contr != null && contr.type == "checkbox")
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

function selectAllCheckboxes_mask (form, btn, txt)
{
  for (var i = 0; i < form.elements.length; i++)
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

function rb_store_type_click_hndlr (radio_btn)
{
  store_type_controls_set_editable_state (radio_btn.id, true);
}

function admin_utils_onload_hndlr ()
{
  var rb_store_type_none = document.getElementById ('choice_store_type_none');
  var rb_store_type_dav = document.getElementById ('choice_store_type_dav');
  var rb_store_type_ldp = document.getElementById ('choice_store_type_ldp');
  var rb_store_type_custom = document.getElementById ('choice_store_type_custom');

  if (rb_store_type_none.checked)
    store_type_controls_set_editable_state ('choice_store_type_none', false);
  else if (rb_store_type_dav.checked)
    store_type_controls_set_editable_state ('choice_store_type_dav', false);
  else if (rb_store_type_ldp.checked)
    store_type_controls_set_editable_state ('choice_store_type_ldp', false);
  else if (rb_store_type_custom.checked)
    store_type_controls_set_editable_state ('choice_store_type_custom', false);
}

function store_type_controls_set_editable_state (store_type_id, store_type_changed)
{
  var el_store_fn, br_store, el_ldp_uid, el_ldp_pwd, el_run_sponger, el_root, el_dav_browser, el_show_cartridge_list;
  var el_ldpr_create_w_put, el_ldpr_create_w_post; 
  var el_folder_tree_recreate, el_folder_tree_collapse; 

  el_store_fn = document.getElementById ('store_fn');
  el_br_store = document.getElementById ('br_store');
  el_ldp_uid = document.getElementById ('tar_ldp_uid');
  el_ldp_pwd = document.getElementById ('tar_ldp_pwd');
  el_run_sponger = document.getElementById ('ask_rdf');
  el_show_cartridge_list = document.getElementById ('get_rdf');
  el_root = document.getElementById ('root');
  el_dav_browser = document.getElementById ('div_dav_browser');
  el_ldpr_create_w_put = document.getElementById ('choice_ldpr_create_w_put');
  el_ldpr_create_w_post = document.getElementById ('choice_ldpr_create_w_post');
  el_folder_tree_recreate = document.getElementById ('choice_folder_tree_recreate');
  el_folder_tree_collapse = document.getElementById ('choice_folder_tree_collapse'); 

  switch (store_type_id)
  {
    case 'choice_store_type_none' :
      el_store_fn.disabled = true;
      el_store_fn.value = "";
      el_br_store.disabled = true;
      el_ldp_uid.value = "";
      el_ldp_pwd.value = "";
      el_ldp_uid.disabled = true;
      el_ldp_pwd.disabled = true;
      el_run_sponger.disabled = false;
      el_show_cartridge_list.disabled = false;
      el_root.disabled = true;
      el_root.value = "";
      el_dav_browser.style.display = 'none';
      el_ldpr_create_w_put.disabled = true;
      el_ldpr_create_w_post.disabled = true;
      el_ldpr_create_w_put.checked = false;
      el_ldpr_create_w_post.checked = false;
      el_folder_tree_recreate.disabled = true;
      el_folder_tree_collapse.disabled = true; 
      el_folder_tree_recreate.checked = false;
      el_folder_tree_collapse.checked = false; 
      break;
    case 'choice_store_type_dav' :
      el_store_fn.disabled = true;
      el_store_fn.value = "";
      el_br_store.disabled = true;
      el_ldp_uid.value = "";
      el_ldp_pwd.value = "";
      el_ldp_uid.disabled = true;
      el_ldp_pwd.disabled = true;
      el_run_sponger.disabled = false;
      el_show_cartridge_list.disabled = false;
      el_root.disabled = false;
      el_ldpr_create_w_put.disabled = true;
      el_ldpr_create_w_post.disabled = true;
      el_ldpr_create_w_put.checked = false;
      el_ldpr_create_w_post.checked = false;
      el_folder_tree_recreate.disabled = true;
      el_folder_tree_collapse.disabled = true; 
      el_folder_tree_recreate.checked = false;
      el_folder_tree_collapse.checked = false; 
      if (store_type_changed)
	el_root.value = "";
      el_dav_browser.style.display = 'inline';
      break;
    case 'choice_store_type_ldp' :
      el_store_fn.disabled = false; // disabled input fields aren't included in POST params.
      el_store_fn.readOnly= true;   // readOnly used instead to fix the value.
      el_store_fn.value = "WS.WS.LDP_STORE";
      el_br_store.disabled = true;
      el_ldp_uid.disabled = false;
      el_ldp_pwd.disabled = false;
      el_run_sponger.disabled = true; // store_hook call doesn't trigger sponger
      el_run_sponger.checked = false;
      el_show_cartridge_list.disabled = true;
      el_show_cartridge_list.checked = false;
      el_root.disabled = false;
      el_ldpr_create_w_put.disabled = false;
      el_ldpr_create_w_post.disabled = false;
      el_folder_tree_recreate.disabled = false;
      el_folder_tree_collapse.disabled = false; 
      if (store_type_changed)
      {
	el_root.value = "";
	el_ldpr_create_w_put.checked = true;
	el_folder_tree_recreate.checked = true;
      }
      el_dav_browser.style.display = 'none';
      break;
    case 'choice_store_type_custom' :
      el_store_fn.disabled = false;
      el_store_fn.readOnly= false;
      el_br_store.disabled = false;
      el_ldp_uid.value = "";
      el_ldp_pwd.value = "";
      el_ldp_uid.disabled = true;
      el_ldp_pwd.disabled = true;
      el_run_sponger.disabled = true;
      el_run_sponger.checked = false;
      el_show_cartridge_list.disabled = true;
      el_show_cartridge_list.checked = false;
      el_root.disabled = false;
      el_ldpr_create_w_put.disabled = true;
      el_ldpr_create_w_post.disabled = true;
      el_ldpr_create_w_put.checked = false;
      el_ldpr_create_w_post.checked = false;
      el_folder_tree_recreate.disabled = true;
      el_folder_tree_collapse.disabled = true; 
      el_folder_tree_recreate.checked = false;
      el_folder_tree_collapse.checked = false; 
      if (store_type_changed)
      {
	el_root.value = "";
	el_store_fn.value = "";
      }
      el_dav_browser.style.display = 'inline';
      break;
  }
}

