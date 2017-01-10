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

var layout_mode = "thin";
var sc_old_border_style;
var shift_init = "true";

function shift_contents() {
    if (! document.getElementById) { return false; }
    var infobox = document.getElementById("infobox");
    var column_one = document.getElementById("column_one_td");
    var column_two = document.getElementById("column_two_td");
    var column_one_table = document.getElementById("column_one_table");
    var column_two_table = document.getElementById("column_two_table");

    var shifting_rows = new Array();

    if (shift_init == "true") {
        shift_init = "false";
        bsMacIE5Fix = document.createElement("tr");
        bsMacIE5Fix.style.display = "none";
        sc_old_border_style = column_one.style.borderRight;
    }

    var width;
    if (self.innerWidth) {       
        width = self.innerWidth;
    } else if (document.documentElement && document.documentElement.clientWidth) {
  width = document.documentElement.clientWidth;
    } else if (document.body) {
        width = document.body.clientWidth;
    }

    if (width < 1000) {
        if (layout_mode == "thin" && shift_init == "true") { return true; }

        layout_mode = "thin";
        column_one.style.borderRight = "0";
        column_two.style.display = "none";

        infobox.style.display = "none";
        column_two_table.lastChild.appendChild(bsMacIE5Fix);

        column_one_table.lastChild.appendChild(document.getElementById("backdate_row"));
        column_one_table.lastChild.appendChild(document.getElementById("comment_settings_row"));
        column_one_table.lastChild.appendChild(document.getElementById("comment_screen_settings_row"));
        if (document.getElementById("userpic_list_row")) {
            column_one_table.lastChild.appendChild(document.getElementById("userpic_list_row"));
        }
    } else {
        if (layout_mode == "wide") { return false; }
        layout_mode = "wide";
        column_one.style.borderRight = sc_old_border_style;
        column_two.style.display = "block";
        
        infobox.style.display = "block";
        column_one_table.lastChild.appendChild(bsMacIE5Fix);

        column_two_table.lastChild.appendChild(document.getElementById("backdate_row"));
        column_two_table.lastChild.appendChild(document.getElementById("comment_settings_row"));
        column_two_table.lastChild.appendChild(document.getElementById("comment_screen_settings_row"));
        if (document.getElementById("userpic_list_row")) {
            column_two_table.lastChild.appendChild(document.getElementById("userpic_list_row"));
        }
    }
}

function enable_rte () {
    if (! document.getElementById) return false;
    
    f = document.page_form;
    if (! f) return false;
    f.switched_rte_on.value = 1;
    f.submit();
    return false;
}
// Maintain entry through browser navigations.
// IE does this onBlur, Gecko onUnload.
function save_entry () {
    if (! document.getElementById) return false;
    
    f = document.page_form;
    if (! f) return false;
    rte = document.getElementById('rte');
    if (! rte) return false;
    content = document.getElementById('rte').contentWindow.document.body.innerHTML;
    f.saved_entry.value = content;
    return false;
}

// Restore saved_entry text across platforms.
// This is only used for IE, Gecko browser support is in the RTE library.
function restore_entry () {
    if (! document.getElementById) return false;
    f = document.page_form;
    if (! f) return false;
    rte = document.getElementById('rte');
    if (! rte) return false;
    if (document.page_form.saved_entry.value == "") return false;
    setTimeout(
               function () {
                   document.getElementById('rte').contentWindow.document.body.innerHTML = 
                       document.page_form.saved_entry.value;
               }, 100);
    return false;
}

function pageload (dotime) {
    restore_entry();

    if (dotime) settime();
    if (!document.getElementById) return false;

    var remotelogin = document.getElementById('remotelogin');
    if (! remotelogin) return false;
    var remotelogin_content = document.getElementById('remotelogin_content');
    if (! remotelogin_content) return false;
    remotelogin_content.onclick = altlogin;

    f = document.page_form;
    if (! f) return false;

    var userbox = f.user;
    if (! userbox) return false;
    if (userbox.value) altlogin();

    return false;
}

function customboxes (e) {
    if (! e) var e = window.event;
    if (! document.getElementById) return false;
    
    f = document.page_form;
    if (! f) return false;
    
    var custom_boxes = document.getElementById('custom_boxes');
    if (! custom_boxes) return false;
    
    if (f.security.selectedIndex != 3) {
        custom_boxes.style.display = 'none';
        return false;
    }

    var altlogin_username = document.getElementById('altlogin_username');    
    if (altlogin_username != undefined && (altlogin_username.style.display == 'table-row' ||
                                           altlogin_username.style.display == 'block')) {
        f.security.selectedIndex = 0;
        custom_boxes.style.display = 'none';
        alert("Custom security is only available when posting as the logged in user.");
    } else {
        custom_boxes.style.display = 'block';
    }
    
    if (e) {
        e.cancelBubble = true;
        if (e.stopPropagation) e.stopPropagation();
    }
    return false;
}

function altlogin (e) {
    var agt   = navigator.userAgent.toLowerCase();
    var is_ie = ((agt.indexOf("msie") != -1) && (agt.indexOf("opera") == -1));

    if (! e) var e = window.event;
    if (! document.getElementById) return false;
    
    var altlogin_username = document.getElementById('altlogin_username');
    if (! altlogin_username) return false;
    if (is_ie) { altlogin_username.style.display = 'block'; } else { altlogin_username.style.display = 'table-row'; }

    var altlogin_password = document.getElementById('altlogin_password');
    if (! altlogin_password) return false;
    if (is_ie) { altlogin_password.style.display = 'block'; } else { altlogin_password.style.display = 'table-row'; }
    
    var remotelogin = document.getElementById('remotelogin');
    if (! remotelogin) return false;
    remotelogin.style.display = 'none';
    
    var usejournal_list = document.getElementById('usejournal_list');
    if (! usejournal_list) return false;
    usejournal_list.style.display = 'none';
    
    var userpic_list = document.getElementById('userpic_list_row');
    if (! userpic_list) return false;
    userpic_list.style.display = 'none';

    var userpic_preview = document.getElementById('userpic_preview');
    userpic_preview.style.display = 'none';

    var mood_preview = document.getElementById('mood_preview');
    mood_preview.style.display = 'none';
    
    f = document.page_form;
    if (! f) return false;
    f.action = 'update.bml?altlogin=1';
    
    var custom_boxes = document.getElementById('custom_boxes');
    if (! custom_boxes) return false;
    custom_boxes.style.display = 'none';
    f.security.selectedIndex = 0;
    f.security.removeChild(f.security.childNodes[3]);

    if (e) {
        e.cancelBubble = true;
        if (e.stopPropagation) e.stopPropagation();
    }

    return false;    
}
function settime() {
    function twodigit (n) {
        if (n < 10) { return "0" + n; }
        else { return n; }
    }
    
    now = new Date();
    if (! now) return false;
    f = document.page_form;
    if (! f) return false;
    
    f.date_ymd_yyyy.value = now.getYear() < 1900 ? now.getYear() + 1900 : now.getYear();
    f.date_ymd_mm.selectedIndex = twodigit(now.getMonth());
    f.date_ymd_dd.value = twodigit(now.getDate());
    f.hour.value = twodigit(now.getHours());
    f.min.value = twodigit(now.getMinutes());
    
    return false;
}
