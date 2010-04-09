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
    TBL.deleteRow(prefix, No);
  }
  else
  {
    var tbl = $(prefix+'_tbody');
    if (!tbl)
      tbl = $(prefix+'_tbl');
    if (tbl)
    {
      var options = {btn_1: {mode: 0}};
      for (var p in optionObject) {options[p] = optionObject[p]; }

      No = options.No;
        if (!$(prefix+'_no')) {
        	var fld = OAT.Dom.create("input");
          fld.type = 'hidden';
          fld.name = prefix+'_no';
          fld.id = fld.name;
          fld.value = '0';
          tbl.appendChild(fld);
        }
      if (No) {
        $(prefix+'_no').value = No;
      } else {
        No = $v(prefix+'_no');
      }
      No = parseInt(No)

      OAT.Dom.hide (prefix+'_tr_no');

      var tr = OAT.Dom.create('tr');
      tr.id = prefix+'_tr_' + No;
      tbl.appendChild(tr);

      if (options.id) {
      	var fld = OAT.Dom.create("input");
        fld.type = 'hidden';
        fld.name = prefix + '_fld_0_' + No;
        fld.id = fld.name;
        fld.value = options.id;
        tr.appendChild(fld);
      }

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
          var fn = TBL["createCell"+((fldOptions.mode)? fldOptions.mode: "0")];
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

TBL.deleteRow = function (prefix, No, ask) {
  if (ask && !confirm('Are you sure that you want to delete this row?'))
    return false;

    OAT.Dom.unlink(prefix+'_tr_'+No);
  OAT.Dom.unlink(prefix+'_tr_'+No+'_items');
  OAT.Dom.unlink(prefix+'_tr_'+No+'_properties');
    var No = parseInt($(prefix+'_no').value);
    for (var N = 0; N < No; N++)
    {
      if ($(prefix+'_tr_'+N))
        return;
    }
    OAT.Dom.show(prefix+'_tr_no');
  return true;
}

TBL.createCellSelect = function (fldName) {
	var fld = OAT.Dom.create("select");
  fld.name = fldName;
  fld.id = fldName;
  return fld;
}

TBL.createCellCombolist = function (td, fldValue, fldOptions) {
  var fld = new OAT.Combolist([], fldValue, fldOptions);
  fld.input.id = fld.input.name;
  fld.input.style.width = "85%";
  td.appendChild(fld.div);

  var dims = OAT.Dom.getWH(td);
  fld.list.style.width = (((dims[0]>250)?dims[0]:250)*0.75)+"px";

  return fld;
}

TBL.createCell0 = function (td, prefix, fldName, No, fldOptions) {
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

TBL.createCell1 = function (td, prefix, fldName, No, fldOptions) {
  var fld = TBL.createCell0 (td, prefix, fldName, No, fldOptions)
  td.appendChild(OAT.Dom.text(' '));
  var img = OAT.Dom.create('img');
  img.src = 'image/select.gif';
  img.className = "pointer";
  img.onclick = function (){windowShow('users_select.vspx?dst=m&params='+fldName+':s1;',520)};

  td.appendChild(img);
  return fld;
}

TBL.createCell2 = function (td, prefix, fldName, No, fldOptions) {
  var fld = TBL.createCellCombolist(td, fldOptions.value, {name: fldName});
  fld.addOption('rdfs:seeAlso');
  fld.addOption('foaf:made');
  fld.addOption('foaf:maker');

  return fld.input;
}

TBL.createCell10 = function (td, prefix, fldName, No, fldOptions) {
  var fld = TBL.createCellCombolist(td, fldOptions.value, {name: fldName, onchange: setServiceUrl});
  fld.input.setAttribute("autocomplete", "off");
  for (N = 0; N < serviceList.length; N = N + 1)
    fld.addOption('<img src="/ods/images/services/'+serviceList[N][0]+'"/> '+serviceList[N][2], serviceList[N][2]);

	var ta = new TypeAhead(fld.input.id, 'onlineAccounts', '');
	fld.input.onchange = setServiceUrl2;
	fld.input.form.onsubmit = CheckSubmit;
	taVars[taVars.length] = ta;

  return fld.input;
}

TBL.createCell11 = function (td, prefix, fldName, No, fldOptions) {
	var fld = TBL.createCellSelect(fldName);
  TBL.selectOption(fld, fldOptions.value, 'bio:Birth', 'bio:Birth');
  TBL.selectOption(fld, fldOptions.value, 'bio:Death', 'bio:Death');
  TBL.selectOption(fld, fldOptions.value, 'bio:Marriage', 'bio:Marriage');

  td.appendChild(fld);
  return fld;
}

TBL.createCell20 = function (td, prefix, fldName, No, fldOptions) {
  var fld = TBL.createCellCombolist(td, fldOptions.value, {name: fldName});

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

  return fld.input;
}

TBL.selectOption = function(fld, fldValue, optionName, optionValue) {
	var o = OAT.Dom.option(optionName, optionValue, fld);
	if (fldValue == optionValue)
		o.selected = true;
}

TBL.createCell30 = function (td, prefix, fldName, No, fldOptions) {
	var fld = TBL.createCellSelect(fldName);
	TBL.selectOption(fld, fldOptions.value, "Person URI", "URI");
	TBL.selectOption(fld, fldOptions.value, "Relationship Property", "Property");

  td.appendChild(fld);
  return fld;
}

TBL.createCell31 = function (td, prefix, fldName, No, fldOptions) {
	var fld = TBL.createCellSelect(fldName);
	TBL.selectOption(fld, fldOptions.value, "Grant", "G");
	TBL.selectOption(fld, fldOptions.value, "Revoke", "R");

  td.appendChild(fld);
  return fld;
}

TBL.createCell40 = function (td, prefix, fldName, No, fldOptions) {
  var fld = OAT.Dom.create('img');
  fld.src = '/ods/images/throbber.gif';
  fld.id = fldName;
  fld.mode = 'show';
  fld.title = 'Show Items';
  fld.onclick = function(){RDF.showItems(this, prefix, No);};
  if (fldOptions.cssText)
    fld.style.cssText = fldOptions.cssText;

  td.appendChild(fld);
  return fld;
}

TBL.createCell41 = function (td, prefix, fldName, No, fldOptions) {
	var fld = OAT.Dom.text(fldOptions.labelValue);
  td.appendChild(fld);

  var fld = TBL.createCellCombolist(td, fldOptions.value, {name: fldName});
	fld.input.style.width = "80%";
  for (var prefix in RDF.ontologies) {
    var ontology = RDF.ontologies[prefix];
    if (!ontology.hidden)
      fld.addOption(ontology.name);
  }
  return fld.input;
}

TBL.createCell42 = function (td, prefix, fldName, No, fldOptions) {
	var fld = OAT.Dom.create("input");
  fld.type = 'hidden';
  fld.name = fldName;
  fld.id = fldName;
  fld.value = fldOptions.value;
  fld.defaultValue = fldOptions.value;
  td.appendChild(fld);

  if (!fldOptions.showValue)
    fldOptions.showValue = fldOptions.value;
	td.appendChild(OAT.Dom.text(fldOptions.showValue));

  return fld;
}

TBL.createCell43 = function (td, prefix, fldName, No, fldOptions) {
  var fld = OAT.Dom.create('img');
  fld.src = '/ods/images/throbber.gif';
  fld.id = fldName;
  fld.mode = 'show';
  fld.title = 'Show Items';
  fld.onclick = function(){RDF.showItems(this, prefix, No);};
  if (fldOptions.cssText)
    fld.style.cssText = fldOptions.cssText;

  td.appendChild(fld);
  return fld;
}

TBL.createCell44 = function (td, prefix, fldName, No, fldOptions) {
	var fld = OAT.Dom.text(fldOptions.labelValue);
  td.appendChild(fld);

	var fld = TBL.createCellSelect(fldName);
  fld.style.width = '80%';
  fld.itemType = fldOptions.itemType;
  var fldValue;
  if (fldOptions.value)
    fldValue = fldOptions.value.name;
  TBL.selectOption(fld, null, '', '');
  var ontology = RDF.getOntologyByName(fld.itemType.ontology);
  if (ontology && ontology.classes)
  {
    var C = ontology.classes;
    for (i = 0; i < C.length; i++)
      TBL.selectOption(fld, null, C[i].name, C[i].name);
  }
  sortSelect (fld);
  fld.value = fldValue;
  if (fld.selectedIndex != -1)
    fld.options[fld.selectedIndex].defaultSelected = true;

  td.appendChild(fld);
  return fld;
}

TBL.createCell45 = function (td, prefix, fldName, No, fldOptions) {
  var fld = OAT.Dom.create('img');
  fld.src = '/ods/images/throbber.gif';
  fld.id = fldName;
  fld.mode = 'show';
  fld.title = 'Show Properties';
  fld.onclick = function(){RDF.showProperties(this, prefix, No);};
  if (fldOptions.cssText)
    fld.style.cssText = fldOptions.cssText;
  td.appendChild(fld);

  if (fldOptions.item)
  {
  	var fld2 = OAT.Dom.create("input");
    fld2.type = 'hidden';
    fld2.name = fldName;
    fld2.value = fldOptions.item.id;
    td.appendChild(fld2);
  }
  return fld;
}

TBL.createCell46 = function (td, prefix, fldName, No, fldOptions) {
  function xSelectOption(fld, fldValue, ontologyClassName)
  {
    var ontologyClass = RDF.getOntologyClass(ontologyClassName);
    if (ontologyClass && ontologyClass.properties)
    {
      var properties = ontologyClass.properties;
      if (!properties) {return;}

      for (i = 0; i < properties.length; i++)
        TBL.selectOption(fld, fldValue, properties[i].name, properties[i].name);
      xSelectOption(fld, fldValue, ontologyClass.subClassOf);
    }
  }

	var fld = TBL.createCellSelect(fldName);
  fld.style.width = '95%';
  fld.item = fldOptions.item;
  var fldValue;
  if (fldOptions.value)
    fldValue = fldOptions.value.name;
  TBL.selectOption(fld, null, '', '');
  xSelectOption(fld, null, fld.item.className);
  fld.onchange = function(){RDF.changePropertyValue(fld);};
  sortSelect (fld);
  fld.value = fldValue;
  if (fld.selectedIndex != -1)
    fld.options[fld.selectedIndex].defaultSelected = true;

  td.appendChild(fld);
  return fld;
}

TBL.createCell47 = function (td, prefix, fldName, No, fldOptions) {
  if (!td) {return;}
  // clear
  td.innerHTML = '';

  // get product
  var item = fldOptions.item;
  if (!item) {return;}

  // get property
  var property = fldOptions.value;
  if (!property) {return;}

  // get property data
  var propertyType;
  var ontologyClassProperty = RDF.getOntologyClassProperty(item.className, property.name);
  if (ontologyClassProperty && ontologyClassProperty.objectProperties) {
    var value;
    var item = RDF.getItem(property.value);
    if (item) {
      value = RDF.getItemName(item);
    } else {
      value = property.value;
    }
    var fld = TBL.createCellCombolist(td, value, {name: fldName});
    fld.input.combolist = fld;
    var classNames = ontologyClassProperty.objectProperties;
    for (var n = 0; n < RDF.itemTypes.length; n++) {
      var itemTypes = RDF.itemTypes[n];
      for (var m = 0; m < itemTypes.items.length; m++) {
        item = itemTypes.items[m];
        for (var j = 0; j < classNames.length; j++) {
          if (RDF.isKindOfClass(item.className, classNames[j]))
            fld.addOption(RDF.getItemName(item));
  	    }
      }
    }
    for (var n = 0; n < RDF.ontologies.length; n++) {
      var ontologyObjects = RDF.ontologies[n].objects;
      if (ontologyObjects) {
        for (var i = 0; i < ontologyObjects.length; i++) {
          for (var j = 0; j < classNames.length; j++) {
            if (RDF.isKindOfClass(ontologyObjects[i].className, classNames[j]))
              fld.addOption(ontologyObjects[i].id);
    	    }
        }
      }
    }
    td.appendChild(fld.div);
    propertyType = 'object';
  }
  else if (ontologyClassProperty && ontologyClassProperty.datatypeProperties) {
    var fld = OAT.Dom.create('input');
    fld.type = 'text';
    fld.id = fldName;
    fld.name = fld.id;
    if (property.value) {
      fld.value = property.value;
      fld.defaultValue = fld.value;
    }
    fld.style.width = '95%';
    td.appendChild(fld);
    propertyType = 'data';
  }
  var fld = OAT.Dom.create('input');
  fld.type = 'hidden';
  fld.id = fldName.replace(/fld_2/, 'fld_3');
  fld.name = fld.id;
  fld.value = propertyType;
  td.appendChild(fld);
}

TBL.createButton0 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = OAT.Dom.create('span');
  fld.id = fldName;
  fld.onclick = function(){TBL.deleteRow(prefix, No);};
  OAT.Dom.addClass(fld, 'button pointer');

  var img = OAT.Dom.create('img');
  img.src = '/ods/images/icons/trash_16.png';
  img.alt = 'Delete row';
  img.title = fld.alt;
  OAT.Dom.addClass(img, 'button');

  fld.appendChild(img);
  fld.appendChild(OAT.Dom.text(' Delete'));

  td.appendChild(fld);
  return fld;
}

TBL.createButton1 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = OAT.Dom.create("input");
  fld.id = fldName;
  fld.type = 'button';
  fld.value = 'Remove';
  fld.onclick = function(){TBL.deleteRow(prefix, No);};

  td.appendChild(fld);
  return fld;
}

TBL.createButton40 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = TBL.createButton0(td, prefix, fldName, No, fldOptions);
  fld.onclick = function(){
      var itemType = RDF.getItemType(No);
      if (itemType) {
        for (var i = 0; i < RDF.itemTypes.length; i++) {
          if (RDF.itemTypes[i].id == itemType.id) {
            RDF.itemTypes.splice(i, 1);
            break;
          }
        }
      }
    TBL.deleteRow(prefix, No);
  };
  return fld;
}

TBL.createButtonAdd = function (td, prefix, fldName, No, fldOptions)
{
  var fld = OAT.Dom.create('span');
  fld.id = fldName;
  OAT.Dom.addClass(fld, 'button pointer');

  var img = OAT.Dom.create('img');
  img.src = '/ods/images/icons/add_16.png';
  img.alt = 'Add row';
  img.title = fld.alt;
  OAT.Dom.addClass(img, 'button');

  fld.appendChild(img);
  fld.appendChild(OAT.Dom.text(' Add'));

  td.appendChild(fld);
  return fld;
}

TBL.createButton41 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = TBL.createButtonAdd(td, prefix, fldName, No, fldOptions);
  fld.onclick = function(){RDF.addItemType(prefix, No);};

  td.appendChild(fld);
  return fld;
}

TBL.createButton42 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = TBL.createButton0(td, prefix, fldName, No, fldOptions);
  fld.onclick = function(){
    var item = RDF.getItem(No);
    if (item) {
      if (RDF.checkItemInSelects(item)) {
        RDF.removeItemInSelects(item);
        var itemType = RDF.getItemTypeByItem(item);
        for (var i = 0; i < itemType.items.length; i++) {
          if (itemType.items[i].id == item.id) {
            itemType.items.splice(i, 1);
            break;
          }
        }
        TBL.deleteRow(prefix, No);
      }
    } else {
      TBL.deleteRow(prefix, No);
    }
  };
  return fld;
}

TBL.createButton43 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = TBL.createButtonAdd(td, prefix, fldName, No, fldOptions);
  fld.onclick = function(){RDF.addItem(prefix, No);};

  td.appendChild(fld);
  return fld;
}
