/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2009 OpenLink Software
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

function link_change (prop)
{
  var a = $('map_link');
  if (a)
    a.href = a.href + '&location-prop=' + escape (prop);
}

function fct_nav_to (url)
{
  document.location = url;
}

var c_thr;

function fct_uri_ac_get_matches (ac_ctl)
{
    var val = ac_ctl.input.value;
    var parm_name;

    OAT.AJAX.abortAll();

    c_thr = $('new_uri_txt');

    OAT.AJAX.GET("/services/rdf/iriautocomplete.get?uri" + "=" + val, 
                 false, 
                 fct_uri_ac_ajax_handler,{});
}

function fct_lbl_ac_get_matches (ac_ctl)
{
    var val = ac_ctl.input.value;
    var parm_name;

    OAT.AJAX.abortAll();

    c_thr = $('new_lbl_txt');

    OAT.AJAX.GET("/services/rdf/iriautocomplete.get?lbl" + "=" + val, 
                 false, 
                 fct_lbl_ac_ajax_handler,{});
}


function fct_uri_ac_ajax_handler (resp)
{
    ac_hide_thr ();

    uri_ac.clear_opts();

    var resp_obj = OAT.JSON.parse (resp);

    if (resp_obj.results.length == 0)
	{
	    uri_ac.hide_popup ();
	    return;
	}

      if (resp_obj.restype == "single")
	uri_ac.set_opts (resp_obj.results);
      else 
	uri_ac.set_opts (resp_obj.results[0].concat(resp_obj.results[1]));

    uri_ac.show_popup ();
}

function fct_lbl_ac_ajax_handler (resp)
{
    ac_hide_thr ();

    lbl_ac.clear_opts();

    var resp_obj = OAT.JSON.parse (resp);

    if (resp_obj.results.length == 0)
	{
	    lbl_ac.hide_popup ();
	    return;
	}

      if (resp_obj.restype == "single")
	lbl_ac.set_opts (resp_obj.results);
      else 
	lbl_ac.set_opts (resp_obj.results[0].concat(resp_obj.results[1]));

    lbl_ac.show_popup ();
}

function ac_show_thr () 
{
  OAT.Dom.addClass (c_thr, 'thr');
}

function ac_hide_thr () 
{
  OAT.Dom.removeClass (c_thr, 'thr');
}


var lbl_ac; // XXX Global var ugly as sin OAT.AJAX really needs a way of passing arbitrary obj to callback
var uri_ac;

function init()
{
    
    uri_ac = new OAT.Autocomplete('new_uri_txt',
			          'new_uri_val',
                                  'new_uri_btn', 
                                  'new_uri_fm', 
                                  {get_ac_matches: fct_uri_ac_get_matches});

    lbl_ac = new OAT.Autocomplete('new_lbl_txt',
				  'new_lbl_val',
				  'new_lbl_btn',
				  'new_lbl_fm',
                                  {get_ac_matches: fct_lbl_ac_get_matches});
				  

    var tabs = new OAT.Tab ('TAB_CTR', {dockMode: false});

    tabs.add ('TAB_TXT', 'TAB_PAGE_TXT');
    tabs.add ('TAB_URI', 'TAB_PAGE_URI');
    tabs.add ('TAB_URILBL', 'TAB_PAGE_URILBL');

    tabs.go (0);

    OAT.MSG.attach ('*', OAT.MSG.AJAX_START, function () { ac_show_thr () });

    OAT.Dom.show ('main_srch');  
}

// opts = { loader: function  - function gets called when user hits tab or stops entering text
//          timer_interval: timer interval in msec };

OAT.Autocomplete = function (_input, _value_input, _button, _form, optObj) {
    var self = this;
    
    this.timer = 0;
    this.value = 0;

    this.options = {
	name:"autocomplete", /* name of input element */
	timer_interval:1000,
	onchange:function() {}
    }
	
    for (var p in optObj) { self.options[p] = optObj[p]; }
    
    this.div = OAT.Dom.create("div", {}, "autocomplete");
    
    this.list = OAT.Dom.create("div",
			       {position:"absolute",left:"0px",top:"0px",zIndex:1001},
			       "autocomplete_list");
    
    self.instant = new OAT.Instant (self.list);
    
    this.submit_form = function() {
	if (self.value) {
	    self.val_inp.value = self.value;
	    self.frm.submit();
	}
	else return 0;
    }

    this.timer_handler = function (e)
    {
	self.value = 0;
	self.options.get_ac_matches(self);
	ac_timer = 0;
    }

    this.key_handler = function (e)
    {
	if (self.timer)
	    window.clearTimeout (self.timer);

	self.val_inp.value = '';

	self.timer = window.setTimeout (self.timer_handler, self.options.timer_interval);
	self.value = self.input.value;

    }

    this.keydown_handler = function (e)
    {
	if ((e.keyCode && e.keyCode == 13) || 
            (e.which && e.which == 13)) {
	    self.val_inp.value = '';
	    if (self.timer)
		window.clearTimeout (self.timer);
	    if (!self.value) {
		self.value = self.input.value = self.list.firstChild.children[1].innerHTML;
		self.submit_form();
	    }
	}
    }

    this.blur_handler = function (e) 
    {
	if (self.timer) {
	    window.clearTimeout (self.timer);
	    self.timer = 0;
	}
    }

    this.btn_handler = function(e) 
    {
	self.submit_form();
    }

    
    this.clear_opts = function() 
    {
	OAT.Dom.clear(self.list);
    }
	
    this.add_option = function(name, value) 
    {
	var n = name;
	var v = name;

	if (value) { v = value; }

	var opt = OAT.Dom.create("div", {}, "ac_list_option");

	var opt_lbl = OAT.Dom.create ("span", {}, "opt_lbl");
        opt_lbl.innerHTML = n;

	var opt_iri = OAT.Dom.create ("span", {}, "opt_iri"); 
	opt_iri.innerHTML = v;

	opt.value = v;
        opt.name = n;

	this.attach(opt);
	OAT.Dom.append ([opt, opt_lbl, opt_iri]);
	self.list.appendChild(opt);
    }

    this.attach = function(option) 
    {
	var ref = function(event) {
	    self.value       = option.value;
	    self.input.value = option.name;

	    self.options.onchange(self);
	    self.instant.hide();
            self.input.focus();
	    self.submit_form();
	}
	OAT.Dom.attach(option, "click", ref);
    }

    this.set_opts = function (opt_list)
    {	
	if (opt_list.length) {
	    for (var i=0;i<opt_list.length;i=i+2) {
		this.add_option(opt_list[i], opt_list[i+1]);
	    }
	    self.btn.disabled = false;
	}
	else
	    self.btn.disabled = true;
    }
	
    this.show_popup = function ()
    {
	self.instant.show();
    }

    this.hide_popup = function ()
    {
	self.instant.hide();
    }
	
    self.instant.options.showCallback = function() 
    {
	var coords = OAT.Dom.position(self.input);
	var dims = OAT.Dom.getWH(self.input);
	self.list.style.left  = (coords[0]+2) +"px";
	self.list.style.top   = (coords[1]+dims[1]+5)+"px";
        self.list.style.width = (dims[0]+"px");
    }

    this.input = $(_input);
    this.btn = $(_button);
    this.frm = $(_form);
    this.val_inp = $(_value_input);

    self.btn.disabled = true;

    OAT.Event.attach (this.input, 'keydown', this.keydown_handler);
    OAT.Event.attach (this.input, 'keyup',   this.key_handler);
    OAT.Event.attach (this.input, 'blur',    this.blur_handler);
    OAT.Event.attach (this.btn,   'click',   this.btn_handler);

    OAT.Dom.append([document.body,self.list]);
}
