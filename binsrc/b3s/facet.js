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

    OAT.AJAX.GET("/services/rdf/iriautocomplete.get?uri" + "=" + escape (val), 
                 false, 
                 fct_uri_ac_ajax_handler,{});
}

function fct_lbl_ac_get_matches (ac_ctl)
{
    var val = ac_ctl.input.value;
    var parm_name;

    OAT.AJAX.abortAll();

    c_thr = $('new_lbl_txt');

    OAT.AJAX.GET("/services/rdf/iriautocomplete.get?lbl" + "=" + escape (val), 
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
	uri_ac.set_uri_opts (resp_obj.results);
      else 
	uri_ac.set_uri_opts (resp_obj.results[0].concat(resp_obj.results[1]));

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

// an ugly resize handler overriding CSS size for result
//

function resize_handler ()
{
    var wp_width = OAT.Dom.getViewport ()[0];

    if ($('res')) 
      {
        var _w = (wp_width-230)+'px';
        $('res').style.width = _w;
      }
}

// Handle click in property values

function prop_val_click_h (e) {
}

function prop_a_compare_fun (a, b) {
    return b[1]-a[1];
}

numeric_s = {
    'http://www.w3.org/2001/XMLSchema#double': true,
    'http://www.w3.org/2001/XMLSchema#float': true,
    'http://www.w3.org/2001/XMLSchema#decimal': true,
    'http://www.w3.org/2001/XMLSchema#integer': true,
};

date_s = {
    'http://www.w3.org/2001/XMLSchema#date': true,
    'http://www.w3.org/2001/XMLSchema#dateTime': true,
};

g_dtp_s = {
    'http://www.w3.org/2001/XMLSchema#boolean':  0,
    'http://www.w3.org/2001/XMLSchema#string':   0,
    'http://www.w3.org/2001/XMLSchema#double':   0,
    'http://www.w3.org/2001/XMLSchema#float':    0,
    'http://www.w3.org/2001/XMLSchema#decimal':  0,
    'http://www.w3.org/2001/XMLSchema#integer':  0,
    'http://www.w3.org/2001/XMLSchema#date':     0,
    'http://www.w3.org/2001/XMLSchema#dateTime': 0,
};

function shorten_dt (dt_val) {
    var i = dt_val.indexOf('#')+1;
    if (i == -1 || i >= dt_val.length) return dt_val;
    return dt_val.substring(i);
}

function is_numeric_dt (dt) {
    return (dt in numeric_s);
}

function is_date_dt (dt) {
    return (dt in date_s);
}

// Not great but speedy enough for 20 or so items at a time
//
// Datatype selector with most frequent (on current page) first.
//

function prop_val_dt_sel_init () {
    var xsd_pfx = 'http://www.w3.org/2001/XMLSchema#';

    dt_s = g_dtp_s;

    var dv_v_a = $$('val_dt','result_t');

    var fnd = false;

    // Dear future me: I'm sorry.

    for (var i=0;i<dv_v_a.length;i++) {
	var v = dv_v_a[i].innerHTML;

	if (v in dt_s)
	    dt_s[v]++;
	else 
	    dt_s[v]=1;
    }

    var dt_a = [];

    for (i in dt_s) {
	dt_a.push ([i, dt_s[i]]);
    };

    dt_a.sort(prop_a_compare_fun);

    var opts_a=[];

    for (i=0;i<dt_a.length;i++) {
	opts_a.push(new Option(shorten_dt (dt_a[i][0]), dt_a[i][0], false));
    }

    var num_opt  = new Option ('Numeric', '##numeric', false);
    var none_opt = new Option ('No datatype', '##none', false);

    if (is_numeric_dt (dt_a[0][0])) {
	opts_a.unshift (num_opt);
	opts_a.push (none_opt);
    }
    else {
	opts_a.push (num_opt);
	opts_a.push (none_opt);
    }

    for (i=0;i<opts_a.length;i++)
	$('cond_dt').options[i] = opts_a[i];

    $('cond_dt').options[0].selected = true;

    OAT.Event.attach ('set_val_range','click', function (e) {
	var ct = $v('cond_type');

	var v_l = $v('cond_lo');
	var v_h = $v('cond_hi');

	if (v_l == '') return;

	if (ct == 'cond_range' && (v_h == '' || v_l == '')) return;

	var out_hi = $v('cond_hi');
	var out_lo = $v('cond_lo');

	if ($('cond_dt').value != '##numeric' && $('cond_dt').value != '##none') {
	    out_hi = '"' + out_hi + '"^^<' + $v('cond_dt') + '>';
	    out_lo = '"' + out_lo + '"^^<' + $v('cond_dt') + '>';
	}

	if (ct == 'cond_gt' || ct == 'cond_lt') {
	    out_hi = '';
	}

	if (ct != "select_value") {
	    $("out_iri").value = '';
	    $("out_dtp").value = '';
	    $('out_hi').value = out_hi;
	    $('out_lo').value = out_lo;
	}

	$('valrange_form').submit();
    });

    OAT.Dom.show ('valrange_form');
}

function handle_val_anchor_click (e) {
    var val = decodeURIComponent(e.target.href.split('?')[1].match(/&iri=(.*)/)[1].split('&')[0]);
    var dtp = decodeURIComponent(e.target.href.split('?')[1].match(/&datatype=(.*)/)[1].split('&')[0]);
    var lang = e.target.href.split('?')[1].match(/&lang=(.*)/)[1].split('&')[0];

    switch($('cond_type').value) {
    case "cond_none":
	return;
    case "select_value":
	OAT.Event.prevent(e);
	$('cond_lo').value = val;
	break;
    case "cond_lt":
        OAT.Event.prevent(e);
	$('cond_lo').value = val;
	break;
    case "cond_gt":
        OAT.Event.prevent(e);
	$('cond_lo').value = val;
	break;
    case "cond_range":
        OAT.Event.prevent(e);
	if ($v('cond_lo') != '')
	    $('cond_hi').value = val;
	else 
	    $('cond_lo').value = val;
	break;
    }
    $('out_dtp').value = dtp;
    $('out_iri').value = val;
    $('out_lang').value = lang;
}

function prop_val_anchors_init () {
    var val_a = $$('sel_val','result_t');

    for (var i=0;i<val_a.length;i++) {
	OAT.Event.attach (val_a[i],'click', handle_val_anchor_click);
    }
}

function init()
{
    resize_handler ();
    OAT.Event.attach (window, 'resize', resize_handler);

    if ($('main_srch')) {
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

	OAT.MSG.attach ('*', 'AJAX_START', function () { ac_show_thr () });

    OAT.Dom.show ('main_srch');  
	
        if ((typeof window.external =="object") && 
            ((typeof window.external.AddSearchProvider == "unknown") || 
             (typeof window.external.AddSearchProvider == "function"))) 
          {
              OAT.Event.attach ('opensearch_link', 
                                'click', 
                                function () { window.external.AddSearchProvider(location.protocol+'//'+location.host+'/fct/opensearchdescription.vsp'); });
          }
    }
    if ($('fct_ft')) {
        var ct = $('fct_ft_fm');
	OAT.Anchor.assign ('fct_ft', {content: ct});
    }

    if ($$('list', 'result_t').length > 0) {
	prop_val_dt_sel_init();
	prop_val_anchors_init();

	OAT.Dom.hide('cond_hi_ctr');

	OAT.Event.attach('cond_type', 'change', function (e) {
	    switch (this.selectedIndex) {
	    case 0:
		OAT.Dom.hide ('cond_inp_ctr');
		break;
	    case 1:
		OAT.Dom.show ('cond_inp_ctr');
		OAT.Dom.hide ('cond_hi_ctr');
		break;
	    case 2:
		OAT.Dom.show ('cond_inp_ctr');
		OAT.Dom.hide ('cond_hi_ctr');
		break;
	    case 3:
		OAT.Dom.show ('cond_inp_ctr');
		OAT.Dom.hide ('cond_hi_ctr');
		break;
	    case 4:
		OAT.Dom.show ('cond_inp_ctr');
		OAT.Dom.show ('cond_hi_ctr');
		break;
	    }
        });
    }
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
	OAT.Event.attach(option, "click", ref);
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
	
    this.set_uri_opts = function (opt_list)
    {	
	if (opt_list.length) {
	    for (var i=0;i<opt_list.length;i=i+1) {
		this.add_option(opt_list[i]);
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

function fct_sel_neg (cb)
{
  var a = $('a_' + cb.value);
  if (0 == a.href.length)
    return;
  if (cb.checked == true)
    {
      var pos = a.href.lastIndexOf ('&exclude=yes');
      if (pos > 0)
	a.href.substring (0, pos);
    }
  else
    a.href = a.href + '&exclude=yes';
}

function fct_set_pivot_page_size()
{
  var pg_size = $('pivot_pg_size').value;
  pg_size = parseInt(pg_size);
  if (isNaN(pg_size) || pg_size < 0)
    pg_size = 0;
  else if (pg_size > 1000)
    pg_size = 1000;

  $('pivot_pg_size').value = pg_size.toString();

  var a = $('pivot_a_mpc');
  var href = a.href;
  href = href.replace(/limit=\d+/, 'limit='+pg_size);
  a.setAttribute("href", href);
}

function fct_set_pivot_qrcode_opt()
{
  var qrcode_flag = $('pivot_qrcode').checked ? 1 : 0;
  var a = $('pivot_a_mpc');
  var href = a.href;
  href = href.replace(/qrcodes=\d+/, 'qrcodes='+qrcode_flag);
  a.setAttribute("href", href);
}

function fct_set_pivot_subj_uri_opt()
{
  var opt = $('CXML_redir_for_subjs').value;
  var a = $('pivot_a_mpc');
  var href = a.href;
  href = href.replace(/CXML_redir_for_subjs=[^&]*&/, 'CXML_redir_for_subjs='+opt+'&');
  a.setAttribute("href", href);
}

function fct_set_pivot_href_opt()
{
  var opt = $('CXML_redir_for_hrefs').value;
  var a = $('pivot_a_mpc');
  var href = a.href;
  href = href.replace(/CXML_redir_for_hrefs=[^&]*&/, 'CXML_redir_for_hrefs='+opt+'&');
  a.setAttribute("href", href);
}
