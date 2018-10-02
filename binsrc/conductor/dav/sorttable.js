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
var image_path = '/conductor/dav/image/';
var image_up = 'orderup_16.png';
var image_down = 'orderdown_16.png';
var image_none = 'c.gif';

OAT.SortTable = {};

OAT.SortTable.init = function (tbl) {
  var tbl = $(tbl);
	if (!tbl) return;
	if (!OAT.Dom.isClass(tbl, '_sortable')) return;

  OAT.SortTable.table = tbl;
  var thead = tbl.tHead;

  var ths = thead.getElementsByTagName('th');
	for (var i=0; i< ths.length; i++) {
		var th = ths[i];
	  if (!OAT.Dom.isClass(th, '_sortable')) continue;

		var txt = OAT.SortTable.innerText(th);
		OAT.Dom.addClass(th, 'pointer');
		th.onclick = function(p, i){p.col = i; return function (){OAT.SortTable.resort(p);}}(th, i);
		th.innerHTML = txt+'&nbsp;<img src="'+ image_path + image_none + '" alt="&darr;" />';
	}
	DAVSTATE.readState();
  OAT.SortTable.resort($(DAVSTATE.state.column), true);
}

OAT.SortTable.resort = function (th, init) {
  var col = parseInt(th.col);
	DAVSTATE.readState();
  if (!init) {
    DAVSTATE.state.direction = (DAVSTATE.state.direction == 'desc')? 'asc': 'desc';
    if (DAVSTATE.state.column != th.id)
      DAVSTATE.state.direction = 'asc';
  }

  // clean old sort
  var thSrt = $$('_sorted', OAT.SortTable.table, 'th');
  if (thSrt.length) {
    OAT.Dom.removeClass(thSrt[0], '_sorted');
    OAT.Dom.removeClass(thSrt[0], '_reversed');
    var img = thSrt[0].getElementsByTagName('img')[0];
    img.src = image_path + image_none;
  }

  OAT.Dom.addClass(th, '_sorted');
  var img = th.getElementsByTagName('img')[0];
  if (DAVSTATE.state.direction == 'asc') {
    img.src = image_path + image_up;
  } else {
    OAT.Dom.addClass(th, '_reversed');
    img.src = image_path + image_down;
  }

  // build an array to sort.
  var tbl = OAT.SortTable.table;
  var tbody = tbl.getElementsByTagName('tbody')[0];
  var row_array = [];
  var rows = tbody.rows;
  for (var j=1; j<rows.length; j++) {
    if (rows[j].cells[col].value) {
      row_array[row_array.length] = [rows[j].cells[col].value, rows[j]];
    } else {
      row_array[row_array.length] = [OAT.SortTable.innerText(rows[j].cells[col]), rows[j]];
    }
  }
  if (DAVSTATE.state.direction == 'asc') {
    row_array.sort(OAT.SortTable.sort_alpha);
  } else {
    row_array.sort(OAT.SortTable.sort_alpha_reversed);
  }
  for (var j=0; j<row_array.length; j++) {
    tbody.appendChild(row_array[j][1]);
  }
  delete row_array;

  DAVSTATE.state.column = th.id;
  DAVSTATE.writeState();
}

OAT.SortTable.reverse = function () {
  // reverse the rows in a tbody
  var tbl = OAT.SortTable.table;
  var tbody = tbl.getElementsByTagName('tbody')[0];

  var row_array = [];
  for (var i=0; i < tbody.rows.length; i++) {
    if (!OAT.Dom.isClass(tbody.rows[i], '_unsortable'))
      row_array[row_array.length] = tbody.rows[i];
  }
  for (var i=row_array.length-1; i >= 0; i--) {
    tbody.appendChild(row_array[i]);
  }
  delete row_array;
}

OAT.SortTable.innerText = function (obj) {
	if (typeof obj == "string") return obj;
	if (typeof obj == "undefined") { return obj };
	if (obj.innerText) return obj.innerText;	//Not needed but it is faster

	var str = "";
	var cs = obj.childNodes;
	for (var i = 0; i < cs.length; i++) {
		switch (cs[i].nodeType) {
			case 1: //ELEMENT_NODE
				str += OAT.SortTable.innerText(cs[i]);
				break;
			case 3:	//TEXT_NODE
				str += cs[i].nodeValue;
				break;
		}
	}
	return str;
}

OAT.SortTable.sort_alpha = function(a, b) {
  if (a[0] == b[0]) return 0;
  if (a[0] < b[0]) return -1;
  return 1;
}

OAT.SortTable.sort_alpha_reversed = function(a, b) {
  if (a[0] == b[0]) return 0;
  if (a[0]  < b[0]) return 1;
  return -1;
}
