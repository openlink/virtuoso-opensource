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
var serviceList = [
  ["twelveseconds.jpg", "http://12seconds.tv/", "12seconds"],
  ["amazon.jpg", "http://www.amazon.com/", "Amazon.com"],
  ["ameba.jpg", "http://www.ameba.jp/", "Ameba"],
  ["backtype.jpg", "http://www.backtype.com/", "Backtype"],
  ["blog.jpg", "http://en.wikipedia.org/wiki/Blog/", "Blog"],
  ["brightkite.jpg", "http://brightkite.com/", "brightkite.com"],
  ["feed.jpg", "http://en.wikipedia.org/wiki/Web_feed/", "Custom RSS/Atom"],
  ["dailymotion.jpg", "http://www.dailymotion.com/", "Dailymotion"],
  ["delicious.jpg", "http://del.icio.us/", "Del.icio.us"],
  ["digg.jpg", "http://www.digg.com/", "Digg"],
  ["diigo.jpg", "http://www.diigo.com/", "Diigo"],
  ["disqus.jpg", "http://www.disqus.com/", "Disqus"],
  ["facebook.jpg", "http://www.facebook.com/", "Facebook"],
  ["flickr.jpg", "http://www.flickr.com/", "Flickr"],
  ["fotolog.jpg", "http://www.fotolog.com/", "Fotolog"],
  ["friendfeed.jpg", "http://www.friendfeed.com/", "FriendFeed"],
  ["furl.jpg", "http://www.furl.net/", "Furl"],
  ["googletalk.jpg", "http://talk.google.com/", "Gmail/Google Talk"],
  ["goodreads.jpg", "http://www.goodreads.com/", "Goodreads"],
  ["googlereader.jpg", "http://reader.google.com/", "Google Reader"],
  ["googleshared.jpg", "http://www.google.com/s2/sharing/stuff/", "Google Shared Stuff"],
  ["identica.jpg", "http://identi.ca/", "identi.ca"],
  ["ilike.jpg", "http://www.ilike.com/", "iLike"],
  ["intensedebate.jpg", "http://www.intensedebate.com/", "Intense Debate"],
  ["jaiku.jpg", "http://www.jaiku.com/", "Jaiku"],
  ["joost.jpg", "http://www.joost.com/", "Joost"],
  ["lastfm.jpg", "http://www.last.fm/user/", "Last.fm"],
  ["librarything.jpg", "http://www.librarything.com/", "LibraryThing"],
  ["linkedin.jpg", "http://www.linkedin.com/in/", "LinkedIn"],
  ["livejournal.jpg", "http://www.livejournal.com/", "LiveJournal"],
  ["magnolia.jpg", "http://ma.gnolia.com/", "Ma.gnolia"],
  ["meneame.jpg", "http://meneame.net/", "meneame"],
  ["misterwong.jpg", "http://www.mister-wong.com/", "Mister Wong"],
  ["mixx.jpg", "http://www.mixx.com/", "Mixx"],
  ["myspace.jpg", "http://www.myspace.com/", "MySpace"],
  ["netflix.jpg", "http://www.netflix.com/", "Netflix"],
  ["netvibes.jpg", "http://www.netvibes.com/", "Netvibes"],
  ["pandora.jpg", "http://www.pandora.com/", "Pandora"],
  ["photobucket.jpg", "http://www.photobucket.com/", "Photobucket"],
  ["picasa.jpg", "http://picasaweb.google.com/", "Picasa Web Albums"],
  ["plurk.jpg", "http://www.plurk.com/", "Plurk"],
  ["polyvore.jpg", "http://www.polyvore.com/", "Polyvore"],
  ["pownce.jpg", "http://pownce.com/", "Pownce"],
  ["reddit.jpg", "http://reddit.com/", "Reddit"],
  ["seesmic.jpg", "http://www.seesmic.com/", "Seesmic"],
  ["skyrock.jpg", "http://www.skyrock.com/", "Skyrock"],
  ["slideshare.jpg", "http://www.slideshare.net/", "SlideShare"],
  ["smotri.jpg", "http://smotri.com/", "Smotri.com"],
  ["smugmug.jpg", "http://www.smugmug.com/", "SmugMug"],
  ["stumbleupon.jpg", "http://www.stumbleupon.com/", "StumbleUpon"],
  ["tipjoy.jpg", "http://tipjoy.com/", "tipjoy"],
  ["tumblr.jpg", "http://www.tumblr.com/", "Tumblr"],
  ["twine.jpg", "http://www.twine.com/", "Twine"],
  ["twitter.jpg", "http://twitter.com/", "Twitter"],
  ["upcoming.jpg", "http://upcoming.yahoo.com/", "Upcoming"],
  ["vimeo.jpg", "http://www.vimeo.com/", "Vimeo"],
  ["wakoopa.jpg", "http://wakoopa.com/", "Wakoopa"],
  ["yahoo.jpg", "http://www.yahoo.com/", "Yahoo"],
  ["yelp.jpg", "http://www.yelp.com/", "Yelp"],
  ["youtube.jpg", "http://www.youtube.com/", "YouTube"],
  ["zooomr.jpg", "http://www.zooomr.com/", "Zooomr"]
]
var TBL = new Object();
TBL.setServiceUrl = function(fld)
{
  for (N = 0; N < serviceList.length; N = N + 1)
  {
    if (fld.value == serviceList[N][2])
    {
      if (fld.input) {fld = fld.input;}

      $(fld.name.replace(/fld_1_/, 'fld_2_')).value = serviceList[N][1]+$v('c_nick');

      var S = '/ods/api/user.onlineAccounts.uri?url='+encodeURIComponent(serviceList[N][1]+$v('c_nick'));
      var x = function(data) {
        $(fld.name.replace(/fld_1_/, 'fld_3_')).value = data;
      }
      OAT.AJAX.GET(S, '', x);
      return;
    }
  }
}

TBL.No = function (tbl, prefix, options)
{
  var No = options.No;
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
  return parseInt(No)
}

TBL.parent = function (obj, tag) {
  var obj = obj.parentNode;
  if (obj.tagName.toLowerCase() == tag)
    return obj;
  return TBL.parent(obj, tag);
}

TBL.createRow = function (prefix, No, optionObject, viewMode) {
  if (No != null)
  {
    TBL.deleteRow(prefix, No);
  }
  else if (viewMode)
  {
    TBL.createViewRow(prefix, optionObject);
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

      No = TBL.No(tbl, prefix, options);
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
          var fn = TBL["createCell"+((fldOptions.mode)? fldOptions.mode: "0")];
          if (fn)
        	  fn(td, prefix, fldName, No, fldOptions);
        }
      }

      // actions
      var td = OAT.Dom.create('td');
      td.id = prefix+'_td_'+ No+'_btn';
      td.style.cssText = 'white-space: nowrap; vertical-align: top;';
      tr.appendChild(td);
      if (options.id) {
      	var fld = OAT.Dom.create("input");
        fld.type = 'hidden';
        fld.name = prefix + '_fld_0_' + No;
        fld.id = fld.name;
        fld.value = options.id;
        td.appendChild(fld);
      }
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
  var tbl = $(prefix+'_tbody');
  if (!tbl)
    tbl = $(prefix+'_tbl');
  if (tbl)
  {
    var No = TBL.No(tbl, prefix, options);
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
        if (fldOptions.tdCssText)
          td.style.cssText = fldOptions.tdCssText;
        tr.appendChild(td);

        if (fldOptions.mode) {
          fldName = prefix + '_' + fld + '_' + No;
          var fn = TBL["viewCell"+fldOptions.mode];
          if (fn)
        	  fn(td, prefix, fldName, 0, fldOptions);
      	} else {
          td.innerHTML = fldOptions.value;
        }
      }
      $(prefix+'_no').value = No + 1;
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
  for (var N = 0; N < No; N++) {
      if ($(prefix+'_tr_'+N))
        return;
    }
    OAT.Dom.show(prefix+'_tr_no');
  return true;
}

TBL.clean = function (prefix) {
  var No = parseInt($(prefix+'_no').value);
  for (var N = 0; N < No; N++)
    OAT.Dom.unlink(prefix+'_tr_'+N);

  OAT.Dom.show(prefix+'_tr_no');
  return true;
}

TBL.createCellOptions = function (fld, fldOptions) {
  if (fldOptions) {
    if (fldOptions.className)
      fld.className = fldOptions.className;
    if (fldOptions.onblur)
      fld.onblur = fldOptions.onblur;
    if (fldOptions.cssText)
      fld.style.cssText = fldOptions.cssText;
    if (fldOptions.readOnly)
      fld.readOnly = fldOptions.readOnly;
  }
}

TBL.createCellSelect = function (fldName, fldOptions) {
	var fld = OAT.Dom.create("select");
  fld.name = fldName;
  fld.id = fldName;
  TBL.createCellOptions(fld, fldOptions);

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

TBL.createCell0 = function (td, prefix, fldName, No, fldOptions, disabled) {
  var fld = OAT.Dom.create('input');
  fld.type = (fldOptions.type)? (fldOptions.type): 'text';
  fld.id = fldName;
  fld.name = fld.id;
  if (fldOptions.value) {
    fld.value = fldOptions.value;
    fld.defaultValue = fld.value;
  }
  TBL.createCellOptions(fld, fldOptions);
  fld.style.width = '95%';

  if (disabled)
    fld.disabled = disabled;

  td.appendChild(fld);
  return fld;
}

TBL.viewCell0 = function (td, prefix, fldName, No, fldOptions) {
  td.innerHTML = fldOptions.value;
}

TBL.createCell1 = function (td, prefix, fldName, No, fldOptions) {
  var fld = TBL.createCell0 (td, prefix, fldName, No, fldOptions)
  if (document.forms[0].elements['sid']) {
  td.appendChild(OAT.Dom.text(' '));
  var img = OAT.Dom.create('img');
  img.src = '/ods/images/select.gif';
  img.className = "pointer";

    var frm = TBL.parent(fld, 'form');
    var F = '&form='+frm.name;
    var M = (fldOptions.formMode)? '&mode='+fldOptions.formMode: '';
    var N = (fldOptions.nrows)? '&nrows='+fldOptions.nrows: '';
    img.onclick = function (){TBL.windowShow('/ods/users_select.vspx?dst=mc&params='+fldName+':s1;'+F+M+N, 'ods_select_users')};

  td.appendChild(img);
  }
  return fld;
}

TBL.createCell2 = function (td, prefix, fldName, No, fldOptions) {
  var fld = TBL.createCellCombolist(td, fldOptions.value, {name: fldName});
  fld.addOption('rdfs:seeAlso');
  fld.addOption('foaf:made');
  fld.addOption('foaf:maker');

  return fld.input;
}

TBL.createCell3 = function (td, prefix, fldName, No, fldOptions) {
  var fld = TBL.createCell0 (td, prefix, fldName, No, fldOptions)
  fld.onclick = function(){datePopup(fldName);};
  return fld;
}

TBL.createCell4 = function (td, prefix, fldName, No, fldOptions) {
	var fld = TBL.createCellSelect(fldName);
  TBL.selectOption(fld, fldOptions.value, 'public', '1');
  TBL.selectOption(fld, fldOptions.value, 'acl', '2');
  TBL.selectOption(fld, fldOptions.value, 'private', '3');

  td.appendChild(fld);
  return fld;
}

TBL.createCell10 = function (td, prefix, fldName, No, fldOptions) {
  var fld = TBL.createCellCombolist(td, fldOptions.value, {name: fldName, onchange: TBL.setServiceUrl});
  fld.input.setAttribute("autocomplete", "off");
  for (N = 0; N < serviceList.length; N = N + 1)
    fld.addOption('<img src="/ods/images/services/'+serviceList[N][0]+'"/> '+serviceList[N][2], serviceList[N][2]);

	var ta = new TypeAhead(fld.input.id, 'onlineAccounts');
	fld.input.onchange = TBL.setServiceUrl;
	fld.input.form.onsubmit = CheckSubmit;
	fld.input.setAttribute('autocomplete', 'off');
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

	fld.addOption('foaf:knows');
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
  if (fldValue == optionValue) {
		o.selected = true;
    o.defaultSelected = true;
  }
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
  function selectOption46(options, fldValue, ontologyClassName)
  {
    var ontologyClass = RDF.getOntologyClass(ontologyClassName);
    if (ontologyClass && ontologyClass.properties)
    {
      var properties = ontologyClass.properties;
      if (!properties)
        return;

      for (i = 0; i < properties.length; i++)
        options.push(properties[i].name);

      if (ontologyClass.subClassOf instanceof Array)
        for (var i=0; i<ontologyClass.subClassOf.length; i++)
          selectOption46(options, fldValue, ontologyClass.subClassOf[i]);
    }
  }

  var fldValue = '';
  if (fldOptions.value && fldOptions.value.name)
    fldValue = fldOptions.value.name;
  var fld = TBL.createCellCombolist(td, fldValue, {name: fldName, onchange: RDF.changePropertyValue});
  var fldInput = fld.input;
  fldInput.setAttribute("autocomplete", "off");
  fldInput.onchange = RDF.changePropertyValue;
  fldInput.item = fldOptions.item;

  var options = [];
  selectOption46(options, null, fldInput.item.className);
  options.sort();
  for (i = 0; i < options.length; i++)
    fld.addOption(options[i]);

  return fldInput;
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
  } else {
    if (ontologyClassProperty && ontologyClassProperty.datatypeProperties)
    propertyType = ontologyClassProperty.datatypeProperties;

    var fldClassName = '';
    if ((propertyType == 'xsd:byte')    ||
        (propertyType == 'xsd:short')   ||
        (propertyType == 'xsd:int')     ||
        (propertyType == 'xsd:integer') ||
        (propertyType == 'xsd:long')) {
      fldClassName = '_validate_ _int_';
    } else if (propertyType == 'xsd:float') {
      fldClassName = '_validate_ _float_';
    } else if (propertyType == 'xsd:date') {
      fldClassName = '_validate_ _date_';
    } else if (propertyType == 'xsd:dateTime') {
      fldClassName = '_validate_ _dateTime_';
    } else if (propertyType == 'xsd:string') {
    } else if (propertyType == 'xsd:boolean') {
    } else if (propertyType == 'rdfs:Literal') {
    } else {
      propertyType = 'data';
    }
  	var fld;
    if (propertyType == 'xsd:boolean') {
    	fld = TBL.createCellSelect(fldName);
      TBL.selectOption(fld, property.value, 'Yes', 'true');
      TBL.selectOption(fld, property.value, 'No', 'false');
    } else {
      fld = OAT.Dom.create('input');
    fld.type = 'text';
    fld.id = fldName;
    fld.name = fld.id;
    if (property.value) {
      fld.value = property.value;
      fld.defaultValue = fld.value;
    }
    fld.style.width = '95%';
      if ((propertyType == 'xsd:date') || (propertyType == 'xsd:dateTime')) {
        fld.onclick = function(){datePopup(fldName);};
      }
      if (fldClassName != '')
        fld.className = fldClassName;
    }
    td.appendChild(fld);
  }
  var fld = OAT.Dom.create('input');
  fld.type = 'hidden';
  fld.id = fldName.replace('fld_3', 'fld_2');
  fld.name = fld.id;
  fld.value = propertyType;
  td.appendChild(fld);
}

TBL.createCell48 = function (td, prefix, fldName, No, fldOptions) {
  if (!td) {return;}

  td.style.width = '1%';
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
    td.innerHTML = 'URI';
  }
  else if (ontologyClassProperty && ontologyClassProperty.datatypeProperties)
  {
    if (ontologyClassProperty.datatypeProperties == 'xsd:byte')  {
      td.innerHTML = 'Byte';
    } else if (ontologyClassProperty.datatypeProperties == 'xsd:short')  {
      td.innerHTML = 'Short';
    } else if ((ontologyClassProperty.datatypeProperties == 'xsd:int') ||
               (ontologyClassProperty.datatypeProperties == 'xsd:integer')) {
      td.innerHTML = 'Integer';
    } else if (ontologyClassProperty.datatypeProperties == 'xsd:long') {
      td.innerHTML = 'Long';
    } else if (ontologyClassProperty.datatypeProperties == 'xsd:float') {
      td.innerHTML = 'Float';
    } else if (ontologyClassProperty.datatypeProperties == 'xsd:date') {
      td.innerHTML = 'Date';
    } else if (ontologyClassProperty.datatypeProperties == 'xsd:dateTime') {
      td.innerHTML = 'DateTime';
    } else if (ontologyClassProperty.datatypeProperties == 'xsd:boolean') {
      td.innerHTML = 'Logical';
    } else {
    td.innerHTML = 'Literal';
  }
  } else {
    td.innerHTML = 'Literal';
}

}

TBL.createCell49 = function (td, prefix, fldName, No, fldOptions) {
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
  var ontologyClassProperty = RDF.getOntologyClassProperty(item.className, property.name);
  if (ontologyClassProperty && ontologyClassProperty.datatypeProperties) {
    var propertyType = ontologyClassProperty.datatypeProperties;
    if ((propertyType != 'xsd:byte')    &&
        (propertyType != 'xsd:short')   &&
        (propertyType != 'xsd:int')     &&
        (propertyType != 'xsd:integer') &&
        (propertyType != 'xsd:long')    &&
        (propertyType != 'xsd:float')   &&
        (propertyType != 'xsd:date')    &&
        (propertyType != 'xsd:dateTime')&&
        (propertyType != 'xsd:boolean'))
    {
      var property = fldOptions.value;
      fldOptions.value = null;
      var fld = TBL.createCell0 (td, prefix, fldName, No, fldOptions)
      if (property.language) {
        fld.value = property.language;
      } else {
        fld.value = '';
      }
      fld.defaultValue = fld.value;
      fld.title = 'Language';
      fld.style.width = '20px';
    }
  }
}

TBL.changeCell50 = function (srcFld) {
  var srcValue = $v(srcFld.name);
  var dstName = srcFld.name.replace('fld_1', 'fld_2');
  var dstFld = $(dstName);
  var dstImg = $(dstName+'_img');
  if (srcValue == 'advanced') {
    OAT.Dom.hide(dstFld);
    OAT.Dom.hide(dstImg);
    OAT.Dom.removeClass(dstFld, '_validate_');
    var td = TBL.parent(dstFld, 'td');
    TBL.showCell51Tbl(td, dstName);
  } else {
    OAT.Dom.show(dstFld);
    OAT.Dom.addClass(dstFld, '_validate_');
  if (srcValue == 'public') {
    dstFld.value = 'foaf:Agent';
    dstFld.readOnly = true;
  } else {
    if (dstFld.value == 'foaf:Agent')
      dstFld.value = '';
    dstFld.readOnly = false;
  }
  if (srcValue == 'public') {
    OAT.Dom.hide(dstImg);
  } else {
    OAT.Dom.show(dstImg);
  }
    var dstTbl = $(dstName.replace('_fld', '_tbl'));
    OAT.Dom.hide(dstTbl);
  }
}

TBL.viewCell50 = function (td, prefix, fldName, No, fldOptions) {
  TBL.createCell50(td, prefix, fldName, No, fldOptions, true);
}

TBL.createCell50 = function (td, prefix, fldName, No, fldOptions, disabled) {
	var fld = OAT.Dom.create("select");
	fld.name = fldName;
	fld.id = fldName;
	TBL.selectOption(fld, fldOptions.value, "Personal", "person");
	TBL.selectOption(fld, fldOptions.value, "Group", "group");
	TBL.selectOption(fld, fldOptions.value, "Public", "public");
  if (!fldOptions.noAdvanced)
    TBL.selectOption(fld, fldOptions.value, "Advanced", "advanced");
  if (fldOptions.onchange)
    fld.onclick = fldOptions.onchange;

  if (disabled)
    fld.disabled = disabled;

  td.appendChild(fld);
  td.style.verticalAlign = 'top';
  return fld;
}

TBL.createCell51 = function (td, prefix, fldName, No, fldOptions) {
  var fld = TBL.createCell0 (td, prefix, fldName, No, fldOptions)
  var srcFld = $(fld.name.replace('fld_2', 'fld_1'));

  td.appendChild(OAT.Dom.text(' '));
  var img = OAT.Dom.image('/ods/images/select.gif');
  img.id = fldName+'_img';
  img.className = "pointer";
    img.onclick = function (){TBL.webidShow(fld, fldOptions)};
  if (fldOptions.imgCssText)
    img.style.cssText = fldOptions.imgCssText;

  td.appendChild(img);
  td.style.verticalAlign = 'top';

  var ta = new TypeAhead(fld.id, 'webIDs', {checkMode: 1, userParams: TBL.typeheadProperty});
  fld.setAttribute('autocomplete', 'off');
  fld.form.onsubmit = CheckSubmit;
  taVars[taVars.length] = ta;

  if (srcFld.value == 'advanced') {
    OAT.Dom.hide(fld);
    OAT.Dom.hide(img);
    OAT.Dom.removeClass(fld, '_validate_');
    TBL.showCell51Tbl(td, fldName, fldOptions);
  }
  if (srcFld.value == 'public')
    OAT.Dom.hide(img);

  return fld;
}

TBL.showCell51Tbl = function (td, fldName, fldOptions, disabled) {
  OAT.Loader.load(["ajax", "json"], function(){TBL.showCell51TblInternal (td, fldName, fldOptions, disabled);});
}

TBL.showCell51TblInternal = function (td, fldName, fldOptions, disabled) {
  var tblName = fldName.replace ('_fld', '_tbl');
  var tbl = $(tblName);
  if ($(tbl)) {
    OAT.Dom.show(tbl);
  } else {
    if (!disabled) {
      tbl = OAT.Dom.create('table', {width: '100%', id: tblName});
    } else {
      tbl = OAT.Dom.create('table', {width: '95%', id: tblName});
    }
    td.appendChild(tbl);
    var tr = OAT.Dom.create('tr');
    tbl.appendChild(tr);
    var td = OAT.Dom.create('td', {width: '95%', style: 'padding: 0'});
    tr.appendChild(td);
    var tbl2 = OAT.Dom.create('table', {width: '100%', className: 'ODS_formList'});
    td.appendChild(tbl2);
    var tbody2 = OAT.Dom.create('tbody', {id: fldName+'_tbody'});
    tbl2.appendChild(tbody2);
    var tr2 = OAT.Dom.create('tr', {id: fldName+'_tr_no'});
    tbody2.appendChild(tr2);
    var td2 = OAT.Dom.create('td', {colspan: '3'});
    tr2.appendChild(td2);
    var S = '<b>No Criteria</b>';
    td2.innerHTML = S.replace(/-TBL-/g, fldName);
    if (!disabled) {
      var td2 = OAT.Dom.create('td');
      td2.style.cssText = 'white-space: nowrap; vertical-align: top;';
      tr.appendChild(td2);
      S = '<img src="/ods/images/icons/add_16.png" border="0" class="button pointer" onclick="javascript: TBL.createRow(\'-TBL-\', null, {fld_1: {mode: 55, tdCssText: \'width: 33%; vertical-align: top;\', className: \'_validate_\'}, fld_2: {mode: 56, tdCssText: \'width: 33%; vertical-align: top;\', cssText: \'display: none;\', className: \'_validate_\'}, fld_3: {mode: 57, tdCssText: \'width: 33%; vertical-align: top;\', cssText: \'display: none;\', className: \'_validate_\'}, btn_1: {mode: 55}});" alt="Add Condition" title="Add Condition" />';
      td2.innerHTML = S.replace(/-TBL-/g, fldName);
    }
    if (fldOptions && fldOptions.value) {
      for (var i = 0; i < fldOptions.value.length; i = i + 1) {
        if (disabled) {
          TBL.createViewRow(fldName, {fld_1: {mode: 55, value: fldOptions.value[i][1], valueExt: fldOptions.value[i][4], tdCssText: 'width: 33%;'}, fld_2: {mode: 56, value: fldOptions.value[i][2], tdCssText: 'width: 33%; vertical-align: top;'}, fld_3: {mode: 57, value: fldOptions.value[i][3], tdCssText: 'width: 33%; vertical-align: top;'}});
        } else {
          TBL.createRow(fldName, null, {fld_1: {mode: 55, value: fldOptions.value[i][1], valueExt: fldOptions.value[i][4], tdCssText: 'width: 33%;', className: '_validate_'}, fld_2: {mode: 56, value: fldOptions.value[i][2], tdCssText: 'width: 33%; vertical-align: top;', className: '_validate_'}, fld_3: {mode: 57, value: fldOptions.value[i][3], tdCssText: 'width: 33%; vertical-align: top;', className: '_validate_'}, btn_1: {mode: 55}});
        }
      }
    }
  }
  return tbl;
}

TBL.viewCell51 = function (td, prefix, fldName, No, fldOptions) {
  var srcFld = $(fldName.replace('fld_2', 'fld_1'));
  if (srcFld && (srcFld.value == 'advanced')) {
    TBL.showCell51Tbl(td, fldName, fldOptions, true);
  } else {
    TBL.viewCell0(td, prefix, fldName, No, fldOptions);
  }
}

TBL.createCell52 = function (td, prefix, fldName, No, fldOptions, disabled) {
  function cb(td, prefix, fldName, No, fldOptions, disabled, ndx) {
  	var fld = OAT.Dom.create("input");
    fld.type = 'checkbox';
    fld.id = fldName;
    fld.name = fld.id;
    fld.value = 1;
    if (fldOptions.value && fldOptions.value[ndx])
      fld.checked = true;
    if (fldOptions.onclick)
      fld.onclick = fldOptions.onclick;
    if (disabled)
      fld.disabled = disabled;
    td.appendChild(fld);
  }
  var suffix = '';
  if (fldOptions.suffix)
    suffix = fldOptions.suffix;
  cb(td, prefix, fldName+'_r'+suffix, No, fldOptions, disabled, 0);
  cb(td, prefix, fldName+'_w'+suffix, No, fldOptions, disabled, 1);
  if (fldOptions.execute)
    cb(td, prefix, fldName+'_x'+suffix, No, fldOptions, disabled, 2);

  td.style.verticalAlign = 'top';
}

TBL.viewCell52 = function (td, prefix, fldName, No, fldOptions) {
  TBL.createCell52(td, prefix, fldName, No, fldOptions, true);
}

TBL.clickCell52 = function (fld)
{
  var fldName = fld.name;
  if (fldName.indexOf('_deny') != -1) {
    fldName = fldName.replace('_deny', '_grant');
    fldName = fldName.replace('fld_4', 'fld_3');
  }
  else if (fldName.indexOf('_grant') != -1) {
    fldName = fldName.replace('_grant', '_deny');
    fldName = fldName.replace('fld_3', 'fld_4');
  }
  $(fldName).checked = false;
}

TBL.changeCell55 = function (obj)
{
  var prefix = obj._prefix;
  var No = obj._No;

  TBL.createCell55Ext(obj);

  var td = $(prefix+'_td_'+No+'_2');
  td.innerHTML = '';
  TBL.createCell56(td, prefix, prefix+'_fld_2_'+No, No, {className: '_validate_'});

  var td = $(prefix+'_td_'+No+'_3');
  td.innerHTML = '';
  TBL.createCell57(td, prefix, prefix+'_fld_3_'+No, No, {className: '_validate_'});
}

TBL.createCell55 = function (td, prefix, fldName, No, fldOptions, disabled) {
  var fld = TBL.createCellSelect(fldName, fldOptions);
  fld._prefix = prefix;
  fld._No = No;
  fld.style.width = '95%';
  OAT.Dom.option('', '', fld);
  if (!TBL.predicates)
    TBL.initValues();
  if (TBL.predicates)
    for (var i = 0; i < TBL.predicates.length; i = i + 2) {
      OAT.Dom.option(TBL.predicates[i+1][0], TBL.predicates[i], fld);
    }

  if (fldOptions.value)
    fld.value = fldOptions.value;

  if (disabled)
    fld.disabled = disabled;

  if (!disabled)
    fld.onchange = function(){TBL.changeCell55(this)};

  td.appendChild(fld);
  TBL.createCell55Ext(fld, fldOptions, disabled)

  return fld;
}

TBL.createCell55Ext = function (obj, fldOptions, disabled) {
  var prefix = obj._prefix;
  var No = obj._No;

  var predicate = TBL.predicateGet(prefix+'_fld_1_'+No);
  if (!predicate)
    return;

  var fldName = prefix+'_fld_0_'+No;
  OAT.Dom.unlink('span_' + fldName);
  if ((predicate[1] != 'sparql') && (predicate[1] != 'triplet'))
    return;

  var td = TBL.parent(obj, 'td');
  var span = OAT.Dom.create('span');
  span.id = 'span_' + fldName;
  if (predicate[1] == 'sparql') {
  if (!fldOptions)
    fldOptions = {valueExt: 'prefix sioc: <http://rdfs.org/sioc/ns#>\nprefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>\nprefix foaf: <http://xmlns.com/foaf/0.1/>\nASK where {^{webid}^ rdf:type foaf:Person}'};

  var fld = OAT.Dom.create('textarea');
  fld.id = fldName;
  fld.name = fld.id;
  fld.style.cssFloat = 'left';
  fld.style.width = '94%';
  fld.style.height = '8em';
  if (fldOptions.valueExt)
    fld.value = fldOptions.valueExt;
  if (disabled)
    fld.disabled = disabled;

    span.appendChild(fld);
  }
  else if (predicate[1] == 'triplet') {
    if (!fldOptions)
      fldOptions = {valueExt: ''};

    var fld = TBL.createCellCombolist(td, fldOptions.valueExt, {name: fldName});
    fld.input.style.width = "95%";

    if (!TBL.triplets)
      TBL.initValues();

    for (i = 0; i < TBL.triplets.length; i++)
      fld.addOption(TBL.triplets[i]);

    span.appendChild(fld.div);
  }
  td.appendChild(span);
}

TBL.changeCell56 = function (obj) {
  var prefix = obj._prefix;
  var No = obj._No;

  var td = $(prefix+'_td_'+No+'_3');
  td.innerHTML = '';
  TBL.createCell57(td, prefix, prefix+'_fld_3_'+No, No, {className: '_validate_'});
}

TBL.viewCell55 = function (td, prefix, fldName, No, fldOptions) {
  TBL.createCell55(td, prefix, fldName, No, fldOptions, true);
}

TBL.createCell56 = function (td, prefix, fldName, No, fldOptions, disabled)
{
  var predicate = TBL.predicateGet(prefix+'_fld_1_'+No);
  if (!predicate)
    return;

  var fld = TBL.createCellSelect(fldName, fldOptions);
  fld._prefix = prefix;
  fld._No = No;
  fld.style.width = '95%';
  OAT.Dom.option('', '', fld);
  var predicateType = predicate[1];
  if (TBL.compares)
    for (var i = 0; i < TBL.compares.length; i = i + 2) {
      var compareTypes = TBL.compares[i+1][1];
      for (var j = 0; j < compareTypes.length; j++) {
        if (compareTypes[j] == predicateType)
          OAT.Dom.option(TBL.compares[i+1][0], TBL.compares[i], fld);
      }
    }
  if (fldOptions.value)
    fld.value = fldOptions.value;

  if (disabled)
    fld.disabled = disabled;

  if (!disabled)
    fld.onchange = function(){TBL.changeCell56(this)};

  td.appendChild(fld);
  return fld;
}

TBL.viewCell56 = function (td, prefix, fldName, No, fldOptions) {
  TBL.createCell56(td, prefix, fldName, No, fldOptions, true);
}

TBL.createCell57 = function (td, prefix, fldName, No, fldOptions)
{
  var predicate = TBL.predicateGet(prefix+'_fld_1_'+No);
  if (!predicate)
    return;

  var fld_2 = $(fldName.replace('fld_3', 'fld_2'));
  if (!fld_2)
    return;

  var compare;
  for (var i = 0; i < TBL.compares.length; i = i + 2) {
    if (TBL.compares[i] == fld_2.value)
      compare = TBL.compares[i+1];
  }
  if (!compare || (compare[2] == 0))
    return;

  if ((predicate[1] == 'boolean') || (predicate[1] == 'sparql')) {
    var fld = OAT.Dom.create("select");
    OAT.Dom.option('Yes', '1', fld);
    OAT.Dom.option('No', '0', fld);
  }
  else
  {
    var fld = OAT.Dom.create("input");
    fld.type = 'text';
  }
  fld.id = fldName;
  fld.name = fld.id;
  fld.style.width = '93%';
  if (fldOptions.value)
    fld.value = fldOptions.value;
  if (fldOptions.className)
    fld.className = fldOptions.className;
  td.appendChild(fld);

  for (var i = 0; i < predicate[3].length; i += 2) {
    if (predicate[3][i] == 'size') {
      fld['size'] = predicate[3][i+1];
      fld.style.width = null;
    }

    if (predicate[3][i] == 'class')
      fld.className = predicate[3][i+1];

    if (predicate[3][i] == 'onclick')
      OAT.Event.attach(fld, "click", new Function((predicate[3][i+1]).replace(/-FIELD-/g, fld.id)));

    if (predicate[3][i] == 'button') {
      var span = OAT.Dom.create("span");
      span.innerHTML = ' ' + (predicate[3][i+1]).replace(/-FIELD-/g, fld.id);
      td.appendChild(span);
    }
  }
  return fld;
}

TBL.viewCell57 = function (td, prefix, fldName, No, fldOptions) {
  TBL.createCell0(td, prefix, fldName, No, fldOptions, true);
}

TBL.createButton0 = function (td, prefix, fldName, No, fldOptions)
{
  var fld = OAT.Dom.create('span');
  fld.id = fldName;
  fld.title = 'Delete row';
  fld.onclick = function(){TBL.deleteRow(prefix, No);};
  OAT.Dom.addClass(fld, 'button pointer');

  var img = OAT.Dom.create('img');
  img.src = '/ods/images/icons/trash_16.png';
  img.alt = 'Delete row';
  img.title = img.alt;
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
  fld.title = 'Add Element';
  OAT.Dom.addClass(fld, 'button pointer');

  var img = OAT.Dom.create('img');
  img.src = '/ods/images/icons/add_16.png';
  img.alt = 'Add Element';
  img.title = img.alt;
  OAT.Dom.addClass(img, 'button');

  fld.appendChild(img);
  var titleText = fldOptions.title;
  if (!titleText)
    titleText = 'Add';
  fld.appendChild(OAT.Dom.text(' '+titleText));

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

TBL.createButton44 = function (td, prefix, fldName, No, fldOptions)
{
  var enabled = fldOptions["enabled"];

  if (enabled == "0")
    return;

  var fld = OAT.Dom.create('span');
  fld.id = fldName;
  OAT.Dom.addClass(fld, 'button pointer');

  var img = OAT.Dom.create('img');
  var txt;
  if (!fldOptions["oauth_sid"] || !fldOptions["oauth_sid"].length) {
      img.src = '/ods/images/icons/link_16.png';
      img.alt = 'Link';
    img.title = img.alt;
      txt = OAT.Dom.text(' Link');
  } else {
      img.src = '/ods/images/icons/disconnect_16.png';
      img.alt = 'Unlink';
    img.title = img.alt;
      txt = OAT.Dom.text(' Unlink');
    }
  OAT.Dom.addClass(img, 'button');
  fld.appendChild(img);
  fld.appendChild(txt);

  td.appendChild(fld);
  fld.onclick = function() {
      var url, x;
    if (!fldOptions["oauth_sid"] || !fldOptions["oauth_sid"].length) {
	  url = '/ods/api/oauth_connect?uri=' + encodeURIComponent(fldOptions["profile_url"]) + 
	      '&login=1&oauth_sid=' + encodeURIComponent(fldOptions["oauth_sid"]);
      x = function (data) {
        if (data.length) {
          var win = window.open(data, null, "width=700,height=420,top=100,left=100,status=no,toolbar=no,menubar=no,scrollbars=yes,resizable=yes");
		  win.window.focus();
        } else {
		  alert ("This service cannot be linked.");
		}
	    }
    } else {
	  if (!confirm('Please confirm removal of associated session'))
	    return;
	  url = '/ods/api/oauth_disconnect?uri=' + encodeURIComponent(fldOptions["profile_url"]);
      x = function (data) {
	      window.location.reload ();
      }
	}
      OAT.AJAX.GET(url, '', x);
  }
}

TBL.createButton55 = function (td, prefix, fldName, No, fldOptions)
{
  var img = OAT.Dom.create('img');
  img.src = '/ods/images/icons/trash_16.png';
  img.alt = 'Delete row';
  img.title = img.alt;
  img.onclick = function(){TBL.deleteRow(prefix, No);};
  OAT.Dom.addClass(img, 'button');

  td.appendChild(img);
  return img;
}

TBL.webidProperty = function(obj)
{
  var S = 'p';
  if (obj.id.replace('fld_2', 'fld_1') != obj.id)
    S = $v(obj.id.replace('fld_2', 'fld_1'))[0];

  return S;
}

TBL.typeheadProperty = function(obj)
{
  return '&depend=' + TBL.webidProperty(obj);
}

TBL.webidShow = function(obj, fldOptions)
{
  var S = TBL.webidProperty(obj);
  var frm = TBL.parent(obj, 'form');
  var F = '&form='+frm.name;
  var M = '&mode='+((fldOptions.formMode)? fldOptions.formMode: S);
  var N = (fldOptions.nrows)? '&nrows='+fldOptions.nrows: '';

  TBL.windowShow('/ods/webid_select.vspx?params='+obj.id+':s1;'+F+M+N, 'ods_select_webid');
}

TBL.windowShow = function(sPage, sPageName, width, height)
{
  if (!width)
    width = 700;
  if (!height)
    height = 500;
  if (document.forms[0].elements['sid'])
    sPage += '&sid=' + document.forms[0].elements['sid'].value;
  if (document.forms[0].elements['realm'])
    sPage += '&realm=' + document.forms[0].elements['realm'].value;
  win = window.open(sPage, sPageName, "width="+width+",height="+height+",top=100,left=100,status=yes,toolbar=no,menubar=no,scrollbars=yes,resizable=yes");
  win.window.focus();
}

TBL.initValues = function () {
  // load filters data
  var x = function(data) {
    var o = OAT.JSON.parse(data);
    TBL.predicates = o[0];
    TBL.compares = o[1];
    TBL.triplets = o[2];
  }
  OAT.AJAX.GET('/ods/api/filtersData', false, x, {async: false});
}

TBL.predicateGet = function (fldName) {
  var fld = $(fldName)
  if (fld) {
    if (!TBL.predicates)
      TBL.initValues();
    for (var i = 0; i < TBL.predicates.length; i += 2) {
      if (TBL.predicates[i] == fld.value)
        return TBL.predicates[i+1];
    }
  }
  return null;
}
