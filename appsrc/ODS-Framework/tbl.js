/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2010 OpenLink Software
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
 */

var TBL = new Object();
TBL.createRow = function (prefix, No, optionObject)
{
  if (No != null)
  {
    OAT.Dom.unlink(prefix+'_tr_'+No);
    var No = parseInt($(prefix+'_no').value);
    for (var N = 0; N < No; N++)
    {
      if ($(prefix+'_tr_'+N))
        return;
    }
    OAT.Dom.show (prefix+'_tr_no');
  }
  else
  {
    var tbl = $(prefix+'_tbl');
    if (tbl)
    {
      var options = {btn_1: {mode: 2}};
      for (var p in optionObject) {options[p] = optionObject[p]; }

      No = optionObject.No;
      if (!No) {
        if (!$(prefix+'_no')) {
        	var fld = OAT.Dom.create("input");
          fld.type = 'hidden';
          fld.name = prefix+'_no';
          fld.id = fld.name;
          fld.value = '0';
          tbl.appendChild(fld);
        }
        No = $v(prefix+'_no');
      }
      No = parseInt(No)

      OAT.Dom.hide (prefix+'_tr_no');

      var tr = OAT.Dom.create('tr');
      tr.id = prefix+'_tr_' + No;
      tbl.appendChild(tr);

      // fields
      for (var fld in options)
      {
        if (fld.indexOf('fld') == 0)
        {
          var fldOptions = options[fld];
          var td = OAT.Dom.create('td');
          td.id = prefix+'_td_'+ No+'_'+fld.replace(/fld_/, '');
          if (fldOptions.tdCssText)
            td.style.cssText = fldOptions.tdCssText;
          tr.appendChild(td);
          var fldName = prefix + '_' + fld + '_' + No;
          var fn = TBL["createCell"+fldOptions.mode];
          if (fn)
        	  fn(td, prefix, fldName, No, fldOptions);
        }
      }

      // actions
      var td = OAT.Dom.create('td');
      td.id = prefix+'_td_'+ No+'_btn';
      td.style.whiteSpace = 'nowrap';
      tr.appendChild(td);
      for (var btn in options)
      {
        if (btn.indexOf('btn') == 0)
        {
          var fldOptions = options[btn];
          if (fldOptions.tdCssText)
            td.style.cssText = fldOptions.tdCssText;
          var fldName = prefix + '_' + btn + '_' + No;
          var fn = TBL["createButton"+fldOptions.mode];
          if (fn)
          {
        	  var btn = fn(td, prefix, fldName, No, fldOptions);
            if (btn) {
              if (fldOptions.cssText)
                btn.style.cssText = fldOptions.cssText;
              if (fldOptions.className)
                btn.className = fldOptions.className;
            }
          }
        }
      }
      $(prefix+'_no').value = No + 1;
    }
  }
}

TBL.createViewRow = function (prefix, options)
{
  var tbl = $(prefix+'_tbl');
  if (tbl)
  {
    OAT.Dom.hide (prefix+'_tr_no');

    var tr = OAT.Dom.create('tr');
    tbl.appendChild(tr);

    // fields
    for (var fld in options)
    {
      if (fld.indexOf('fld') == 0)
      {
        var fldOptions = options[fld];
        var td = OAT.Dom.create('td');
        if (fldOptions.tdCssText)
          td.style.cssText = fldOptions.tdCssText;
        tr.appendChild(td);

        if (fldOptions.mode) {
          fldName = prefix + '_' + fld + '_0';
          var fn = TBL["viewCell"+fldOptions.mode];
          if (fn)
        	  fn(td, prefix, fldName, 0, fldOptions);
      	} else {
          td.innerHTML = fldOptions.value;
        }
      }
    }
  }
}

TBL.createCell0 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = OAT.Dom.create('input');
  fld.type = (fldOptions.type)? (fldOptions.type): 'text';
  fld.id = fldName;
  fld.name = fld.id;
  if (fldOptions.value) {
    fld.value = fldOptions.value;
    fld.defaultValue = fld.value;
  }
  if (fldOptions.className)
    fld.className = fldOptions.className;
  if (fldOptions.onblur)
    fld.onblur = fldOptions.onblur;
  fld.style.width = '95%';
  if (fldOptions.cssText)
    fld.style.cssText = fldOptions.cssText;
  if (fldOptions.readOnly)
    fld.readOnly = fldOptions.readOnly;

  td.appendChild(fld);
  return fld;
}

TBL.createCell1 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = TBL.createCell0 (td, prefix, fldName, No, fldOptions)
  td.appendChild(OAT.Dom.text(' '));
  var img = OAT.Dom.image('image/select.gif');
  img.className = "pointer";
  img.onclick = function (){windowShow('users_select.vspx?dst=m&params='+fldName+':s1;',520)};

  td.appendChild(img);
  return fld;
}

TBL.createCell2 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = new OAT.Combolist([], fldOptions.value, {name: fldName});
  fld.input.name = fldName;
  fld.input.id = fldName;
  fld.input.style.width = "85%";
  fld.addOption('rdfs:seeAlso');
  fld.addOption('foaf:made');
  fld.addOption('foaf:maker');

  td.appendChild(fld.div);
  return fld;
}

TBL.createCell20 = function (td, prefix, fldName, No, fldOptions) {
	var fld = new OAT.Combolist( [], fldOptions.value, {name : fldName});

	fld.input.name = fldName;
	fld.input.id = fldName;
	fld.input.style.width = "85%";
	fld.addOption('rel:acquaintanceOf');
	fld.addOption('rel:ambivalentOf');
	fld.addOption('rel:ancestorOf');
	fld.addOption('rel:antagonistOf');
	fld.addOption('rel:apprenticeTo');
	fld.addOption('rel:childOf');
	fld.addOption('rel:closeFriendOf');
	fld.addOption('rel:collaboratesWith');
	fld.addOption('rel:colleagueOf');
	fld.addOption('rel:descendantOf');
	fld.addOption('rel:employedBy');
	fld.addOption('rel:employerOf');
	fld.addOption('rel:enemyOf');
	fld.addOption('rel:engagedTo');
	fld.addOption('rel:friendOf');
	fld.addOption('rel:grandchildOf');
	fld.addOption('rel:grandparentOf');
	fld.addOption('rel:hasMet');
	fld.addOption('rel:knowsByReputation');
	fld.addOption('rel:knowsInPassing');
	fld.addOption('rel:knowsOf');
	fld.addOption('rel:lifePartnerOf');
	fld.addOption('rel:livesWith');
	fld.addOption('rel:lostContactWith');
	fld.addOption('rel:mentorOf');
	fld.addOption('rel:neighborOf');
	fld.addOption('rel:parentOf');
	fld.addOption('rel:participant');
	fld.addOption('rel:participantIn');
	fld.addOption('rel:siblingOf');
	fld.addOption('rel:spouseOf');
	fld.addOption('rel:worksWith');
	fld.addOption('rel:wouldLikeToKnow');

  td.appendChild(fld.div);
  return fld;
}

TBL.selectOption = function(fld, fldValue, optionName, optionValue) {
	var o = OAT.Dom.option(optionName, optionValue, fld);
	if (fldValue == optionValue)
		o.selected = true;
}

TBL.createCell30 = function (td, prefix, fldName, No, fldOptions) {
	var fld = OAT.Dom.create("select");
	fld.name = fldName;
	fld.id = fldName;
	TBL.selectOption(fld, fldOptions.value, "Person URI", "URI");
	TBL.selectOption(fld, fldOptions.value, "Relationship Property", "Property");

  td.appendChild(fld);
  return fld;
}

TBL.createCell31 = function (td, prefix, fldName, No, fldOptions) {
	var fld = OAT.Dom.create("select");
	fld.name = fldName;
	fld.id = fldName;
	TBL.selectOption(fld, fldOptions.value, "Grant", "G");
	TBL.selectOption(fld, fldOptions.value, "Revoke", "R");

  td.appendChild(fld);
  return fld;
}

TBL.createButton1 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = OAT.Dom.create("input");
  fld.id = fldName;
  fld.type = 'button';
  fld.value = 'Remove';
  fld.onclick = function(){TBL.createRow(prefix, No);};

  td.appendChild(fld);
  return fld;
}

TBL.createButton2 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = OAT.Dom.image('image/del_16.png');
  fld.onclick = function(){TBL.createRow(prefix, No);};
  OAT.Dom.addClass(fld, 'pointer');

  td.appendChild(fld);
  return fld;
}
