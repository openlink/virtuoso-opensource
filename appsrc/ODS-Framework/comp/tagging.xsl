<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2012 OpenLink Software
 -
 -  This project is free software; you can redistribute it and/or modify it
 -  under the terms of the GNU General Public License as published by the
 -  Free Software Foundation; only version 2 of the License, dated June 1991.
 -
 -  This program is distributed in the hope that it will be useful, but
 -  WITHOUT ANY WARRANTY; without even the implied warranty of
 -  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 -  General Public License for more details.
 -
 -  You should have received a copy of the GNU General Public License along
 -  with this program; if not, write to the Free Software Foundation, Inc.,
 -  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 -
-->
<!-- Content Tagging management -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:v="http://www.openlinksw.com/vspx/"
    xmlns:vm="http://www.openlinksw.com/vspx/ods/">
    <xsl:template match="vm:tag-settings">
	<h3>Rule sets enabled for content tagging <?V self.u_full_name ?>'s applications</h3>
	<table class="listing">
	    <tr class="listing_header_row">
		<th>Rule Name</th>
		<th>Action</th>
	    </tr>
	    <v:data-set
		name="ds_actrules"
		sql="select trs_id, trs_name, trs_owner from tag_user, tag_rule_set where trs_id = tu_trs and tu_u_id = :uid order by tu_order"
		nrows="1000"
		cursor-type="dynamic"
		scrollable="1"
		editable="1"
		>
		<v:param name="uid" value="--self.u_id"/>
		<v:template type="repeat" name="dse_rep">
		    <v:template name="no_rows2" type="if-not-exists">
			<tr><td colspan="2">No rules activated</td></tr>
		    </v:template>
		    <v:template type="browse" name="dse_brows">
			<tr  class="<?V case when mod(control.te_ctr, 2) = 0 then 'listing_row_odd' else 'listing_row_even' end ?>">
			    <td>
				<!-- active="-#-equ((control.vc_parent as vspx_row_template).te_rowset[2], self.u_id)" -->
				<v:url name="eerul" value="--(control.vc_parent as vspx_row_template).te_rowset[1]"
				    url="--sprintf ('edit_rule.vspx?rid=%d', (control.vc_parent as vspx_row_template).te_rowset[0])"
				    />
				 &amp;nbsp;
				 <v:url name="lown1"
				     value="-- sprintf ('shared by %s', (select U_NAME from SYS_USERS where U_ID = (control.vc_parent as vspx_row_template).te_rowset[2]))"
				     url="-- sprintf ('/dataspace/%s/%s#this',wa_identity_dstype((control.vc_parent as vspx_row_template).te_rowset[2]), (select U_NAME from SYS_USERS where U_ID = (control.vc_parent as vspx_row_template).te_rowset[2]))"
				     enabled="--neq((control.vc_parent as vspx_row_template).te_rowset[2], self.u_id)" />
			    </td>
			    <td>
				<v:button name="earul" value="Remove" action="simple" style="url">
				    <v:on-post>
					delete from tag_user where tu_trs = (control.vc_parent as vspx_row_template).te_rowset[0];
					self.vc_data_bind (e);
				    </v:on-post>
				</v:button>
				<v:button name="earul1" value="Up" action="simple" style="url">
				    <v:on-post><![CDATA[
					declare to_move, to_swap, mv_ord, sw_ord int;
					if (not self.vc_is_valid)
					  return;
					to_swap := null;
					to_move := (control.vc_parent as vspx_row_template).te_rowset[0];
					for select trs_id, trs_name, tu_order from tag_user, tag_rule_set
					  where trs_id = tu_trs and tu_u_id = self.u_id order by tu_order do
					  {
					    if (trs_id = to_move)
					      {
					        mv_ord := tu_order;
					        goto swapit;
					      }
					    to_swap := trs_id;
					    sw_ord := tu_order;
					  }
					swapit:
					if (to_swap is not null)
					  {
					    update tag_user set tu_order = -1 where tu_u_id = self.u_id and tu_trs = to_swap;
					    update tag_user set tu_order = sw_ord where tu_u_id = self.u_id and tu_trs = to_move;
					    update tag_user set tu_order = mv_ord where tu_u_id = self.u_id and tu_trs = to_swap;
					  }
					self.vc_data_bind (e);
				]]></v:on-post>
				</v:button>
				<v:button name="earul2" value="Down" action="simple" style="url">
				    <v:on-post><![CDATA[
					declare to_move, to_swap, mv_ord, sw_ord int;
					if (not self.vc_is_valid)
					  return;
					to_swap := null;
					to_move := (control.vc_parent as vspx_row_template).te_rowset[0];
					mv_ord := null;
					for select trs_id, trs_name, tu_order from tag_user, tag_rule_set
					  where trs_id = tu_trs and tu_u_id = self.u_id order by tu_order do
					  {
					    if (trs_id = to_move)
					      {
					        mv_ord := tu_order;
					      }
					    else if (mv_ord is not null)
					      {
					        to_swap := trs_id;
						sw_ord := tu_order;
						goto swapit;
					      }
					  }
					swapit:
					if (to_swap is not null)
					  {
					    update tag_user set tu_order = -1 where tu_u_id = self.u_id and tu_trs = to_swap;
					    update tag_user set tu_order = sw_ord where tu_u_id = self.u_id and tu_trs = to_move;
					    update tag_user set tu_order = mv_ord where tu_u_id = self.u_id and tu_trs = to_swap;
					  }
					self.vc_data_bind (e);
				]]></v:on-post>
				</v:button>
			    </td>
			</tr>
		    </v:template>
		</v:template>
	    </v:data-set>
	</table>
	<h3>Rule sets owned by <?V self.u_full_name ?></h3>
	<table class="listing">
	    <tr class="listing_header_row">
		<th>Rule Name</th>
		<th>
		    <v:url name="add_new_rule_set" value="Add New Rule" url="add_rule.vspx"/>
		</th>
	    </tr>
	    <v:data-set
		name="ds_rules"
		sql="select trs_id, trs_name, trs_is_public from tag_rule_set where trs_owner = :uid order by trs_id"
		nrows="1000"
		cursor-type="dynamic"
		scrollable="1"
		editable="1"
		>
		<v:param name="uid" value="--self.u_id"/>
		<v:template type="repeat" name="ds_rep">
		    <v:template name="no_rows1" type="if-not-exists">
			<tr><td colspan="2">No rules defined</td></tr>
		    </v:template>
		    <v:template type="browse" name="ds_brows">
			<tr class="<?V case when mod(control.te_ctr, 2) = 0 then 'listing_row_odd' else 'listing_row_even' end ?>">
			    <td>
				<v:url name="erul" value="--(control.vc_parent as vspx_row_template).te_rowset[1]"
				    url="--sprintf ('edit_rule.vspx?rid=%d', (control.vc_parent as vspx_row_template).te_rowset[0])"
				    />
			    </td>
			    <td>
				<v:button name="arul" value="Enable" action="simple" style="url">
				    <v:before-render>
					if (exists (select 1 from tag_user where
					tu_trs = (control.vc_parent as vspx_row_template).te_rowset[0] and tu_u_id = self.u_id))
				          {
					    control.vc_enabled := 0;
					    control.ufl_value := 'Enabled';
			  		  }
				    </v:before-render>
				    <v:on-post>
					declare ord int;
					ord := coalesce ((select top 1 tu_order from tag_user
						where tu_u_id = self.u_id
						order by tu_order desc), 0);
				        ord := ord + 1;
					if (exists (select 1 from tag_user
						where tu_u_id = self.u_id and
						tu_trs = (control.vc_parent as vspx_row_template).te_rowset[0]))
				          {
					    self.vc_is_valid := 0;
					    self.vc_error_message := 'The tag ruleset is already enabled.';
					    return;
			                  }

					insert into tag_user (tu_u_id, tu_trs, tu_order) values
					(self.u_id, (control.vc_parent as vspx_row_template).te_rowset[0], ord);
					self.vc_data_bind (e);
				    </v:on-post>
				</v:button>
				<v:label name="enbl1" value="Enabled">
				    <v:before-render>
					declare bt vspx_control;
					bt := control.vc_parent.vc_find_control ('arul');
					control.vc_enabled := case when bt.vc_enabled then 0 else 1 end;
				    </v:before-render>
				</v:label>
				<v:button name="drul" value="Delete" action="simple" style="url">
				    <v:on-post>
					delete from SYS_ANN_PHRASE where AP_APS_ID =
					(select trs_aps_id from tag_rule_set
						where trs_id = (control.vc_parent as vspx_row_template).te_rowset[0]);
					delete from SYS_ANN_PHRASE_SET where APS_ID =
					(select trs_aps_id from tag_rule_set
						where trs_id = (control.vc_parent as vspx_row_template).te_rowset[0]);
					delete from tag_rule_set
						where trs_id = (control.vc_parent as vspx_row_template).te_rowset[0];
					self.vc_data_bind (e);
				    </v:on-post>
				</v:button>
				<!--[CDATA[&nbsp;]]>
				<v:url name="moat2" url="-#-sprintf ('moat_ruleset_tags.vspx?trs_id=%d', (control.vc_parent as vspx_row_template).te_rowset[0])" value="MOAT" /-->
			    </td>
			</tr>
		    </v:template>
		</v:template>
	    </v:data-set>
	</table>
	<br/>
	<v:button action="simple" name="trs_btn3" value="Export"
	    xhtml_onclick="--sprintf ('javascript: window.open (\'trs_export_all.xml?:u=%d&amp;contenttype=application/octet-stream&amp;content-filename=tagging_rules.xml\', \'export\', \'\'); return false', self.u_id)"
		    enabled="--coalesce ((select top 1 1 from tag_user where tu_u_id = self.u_id), 0)">
	</v:button>
	<v:form action="POST" name="impform" type="simple" xhtml_enctype="multipart/form-data">
	    <v:text type="file" name="trs_file" value=""
		>
	    </v:text>
	    <v:button action="simple" name="trs_btn4" value="Import">
		<v:on-post>
		    declare f, xt, xp, dat, _trs_aps_id, _trs_apc_id, _trs_id any;
		    declare rule_name, is_shared, tmp, moat, muri any;

		    f := self.trs_file.ufl_value;

		    declare exit handler for sqlstate '*'
		    {
		      rollback work;
		      self.vc_is_valid := 0;
		      self.vc_error_message := 'The file to import is not specified or does not contains ruleset data.';
		      return;
		    };

		    _trs_apc_id := coalesce (
		      (select top 1 APC_ID from DB.DBA.SYS_ANN_PHRASE_CLASS where APC_OWNER_UID = self.u_id),
		      ANN_GETID ('C'));

                    insert soft DB.DBA.SYS_ANN_PHRASE_CLASS
	 	  	(APC_ID, APC_NAME, APC_OWNER_UID, APC_READER_GID, APC_CALLBACK, APC_APP_ENV)
 		        values (_trs_apc_id, self.u_name || '\'s Tagging Rule Class', self.u_id, http_nogroup_gid (), null, null);

		    xt := xtree_doc (f);

		    tmp := xpath_eval ('/tagging-rules/rule-set', xt, 0);

		    self.vc_is_valid := 1;
		    foreach (any rul in tmp) do
		      {
		        declare pref, ord, inx int;
			pref := rule_name := cast (xpath_eval ('@name', rul) as varchar);
			inx := 1;
			while (exists (select 1 from tag_rule_set where trs_owner = self.u_id and trs_name = rule_name))
		          {
			    rule_name := pref || sprintf (' (%d)', inx);
                            inx := inx + 1;
			  }

			is_shared := cast (xpath_eval ('@shared', rul) as int);
			_trs_aps_id := ANN_GETID ('S');
			insert into tag_rule_set (trs_name, trs_owner, trs_is_public, trs_apc_id, trs_aps_id)
			   values (rule_name, self.u_id, is_shared, _trs_apc_id, _trs_aps_id);
			_trs_id := identity_value ();
                        ord := coalesce ((select top 1 tu_order from tag_user where tu_u_id = self.u_id order by tu_order desc), 0);
			ord := ord + 1;
			insert soft tag_user (tu_u_id, tu_trs, tu_order) values
			(self.u_id, _trs_id, ord);


			insert soft DB.DBA.SYS_ANN_PHRASE_SET (APS_ID, APS_NAME, APS_OWNER_UID, APS_READER_GID,
				APS_APC_ID, APS_LANG_NAME, APS_APP_ENV, APS_SIZE, APS_LOAD_AT_BOOT)
				values (_trs_aps_id, self.u_name || '\'s ' || rule_name,
					self.u_id, http_nogroup_gid (), _trs_apc_id, 'x-any', null, 10000, 1);

			dat := vector ();
			xp := xpath_eval ('rule', rul, 0);
			foreach (any r in xp) do
			  {
			    declare q, t, is_p any;
			    q := cast (xpath_eval ('string(pattern)', r) as varchar);
			    t := cast (xpath_eval ('string(tags)', r) as varchar);
			    is_p := cast (xpath_eval ('string(is-phrase)', r) as int);
			    dat := vector_concat (dat, vector ( vector (q, t, is_p) ));
			    insert into tag_rules (rs_trs, rs_query, rs_tag, rs_is_phrase)
			    	values (_trs_id, q, t, is_p);
			    if (is_p = 1)
			      {
				ap_add_phrases (_trs_aps_id, vector ( vector (q, t) ));
			      }
			    else
			      {
				tt_query_tag_content (q, self.u_id, '', '', serialize (vector (_trs_id, t, is_p)));
			      }
			    moat := xpath_eval ('meaning', r, 0);
			    foreach (any m in moat) do
			      {
				muri := xpath_eval ('string(.)', m);
				insert replacing moat.DBA.moat_user_meanings (mu_tag, mu_trs_id, mu_url)
				    values (t, _trs_id, muri);
			      }
			  }
		      }
		    self.vc_redirect ('tags.vspx');
		</v:on-post>
	    </v:button>
	</v:form>
	<h3>Rule sets offered for use by other users</h3>
	<table class="listing">
	    <tr class="listing_header_row">
		<th>Rule Name</th>
		<th>Owner</th>
		<th>
		    Action
		</th>
	    </tr>
	    <v:data-set
		name="ds_sh_rules"
		sql="select trs_id, trs_name, u_name from tag_rule_set, sys_users where trs_owner = u_id and trs_owner <> :uid and trs_is_public = 1 order by trs_id"
		nrows="1000"
		cursor-type="dynamic"
		scrollable="1"
		editable="1"
		>
		<v:param name="uid" value="--self.u_id"/>
		<v:template type="repeat" name="ds_sh_rep">
		    <v:template name="no_rows3" type="if-not-exists">
			<tr><td colspan="2">No rules available</td></tr>
		    </v:template>
		    <v:template type="browse" name="ds_sh_brows">
			<tr class="<?V case when mod(control.te_ctr, 2) = 0 then 'listing_row_odd' else 'listing_row_even' end ?>">
			    <td>
				<v:url name="srul" value="--(control.vc_parent as vspx_row_template).te_rowset[1]"
				    url="--sprintf ('edit_rule.vspx?rid=%d', (control.vc_parent as vspx_row_template).te_rowset[0])"
				    />
			    </td>
			    <td>
				<v:label name="srul2" value="--(control.vc_parent as vspx_row_template).te_rowset[2]"

				    />
			    </td>
			    <td>
				<v:button name="srul3" value="Enable" action="simple" style="url">
				    <v:before-render>
					if (exists (select 1 from tag_user where
					tu_trs = (control.vc_parent as vspx_row_template).te_rowset[0] and tu_u_id = self.u_id))
				          {
					    control.vc_enabled := 0;
					    control.ufl_value := 'Enabled';
			  		  }
				    </v:before-render>
				    <v:on-post>
					declare ord int;
					ord := coalesce ((select top 1 tu_order from tag_user
						where tu_u_id = self.u_id
						order by tu_order desc), 0);
				        ord := ord + 1;
					if (exists (select 1 from tag_user
						where tu_u_id = self.u_id and
						tu_trs = (control.vc_parent as vspx_row_template).te_rowset[0]))
				          {
					    self.vc_is_valid := 0;
					    self.vc_error_message := 'The tag ruleset is already enabled.';
					    return;
			                  }
					insert into tag_user (tu_u_id, tu_trs, tu_order) values
					(self.u_id, (control.vc_parent as vspx_row_template).te_rowset[0], ord);
					self.vc_data_bind (e);
				    </v:on-post>
				</v:button>
				<v:label name="enbl2" value="Enabled">
				    <v:before-render>
					declare bt vspx_control;
					bt := control.vc_parent.vc_find_control ('srul3');
					control.vc_enabled := case when bt.vc_enabled then 0 else 1 end;
				    </v:before-render>
				</v:label>
			    </td>
			</tr>
		    </v:template>
		</v:template>
	    </v:data-set>
	</table>
    </xsl:template>
    <xsl:template match="vm:tag-rule">
	<v:variable name="trs_id" type="int" default="-1" param-name="rid" />
	<v:variable name="trs_aps_id" type="int" default="-1" />
	<v:variable name="trs_apc_id" type="int" default="-1" />
	<v:variable name="trs_data" type="any" default="null" />
	<v:variable name="filt" type="any" default="null" />
	<v:variable name="page_mode" type="int" default="1" /> <!-- 1 - edit, 0 - view -->
      <script type="text/javascript">
  <![CDATA[
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


]]>
</script>
		    <v:method name="upd_rule" arglist="inout control vspx_button, inout e vspx_event, in flag int" ><![CDATA[
		       declare r vspx_row_template;
		       declare o, dt, inx any;
		       declare expr varchar;
		       r := control.vc_parent;
		       --dbg_vspx_control (r);
		       o := r.te_ctr + self.dsr_rules.ds_rows_offs;
		       dt := self.trs_data;
		       if ((r.vc_find_control ('drull3') as vspx_field).ufl_selected = 0)
		       {
			 declare exit handler for sqlstate '*'
			 {
			   self.vc_is_valid := 0;
			   self.vc_error_message := sprintf ('The expression "%V" is not valid text query', expr);
			   return;
			 };
			 expr := (r.vc_find_control ('drull1') as vspx_field).ufl_value;
			 vt_parse (expr);
		       }
		       dt[o][0] := trim((r.vc_find_control ('drull1') as vspx_field).ufl_value);
		       dt[o][1] := trim((r.vc_find_control ('drull2') as vspx_field).ufl_value);

		       inx := 0;
		       foreach (any d in dt) do
			{
			if (  o <> inx and
			      d[0] = dt[o][0] and
			      d[1] = dt[o][1])
			      {
				self.vc_is_valid := 0;
				self.vc_error_message :=
				  'The expression for this tag is already defined';
				return;
			      }
			  inx := inx + 1;
			}

		       if (not length (dt[o][0])
			or not length (dt[o][1]))
			{
			  self.vc_is_valid := 0;
			  self.vc_error_message := 'The query and tag cannot be empty';
			  return;
			}

		       dt[o][2] := (r.vc_find_control ('drull3') as vspx_field).ufl_selected;
		       self.trs_data := dt;
		       if (flag)
		         {
			   self.dsr_rules.vc_data_bind (e);
			 }
		       ]]></v:method>
	<v:form action="POST" name="trform" type="simple" xhtml_enctype="multipart/form-data">
	    <v:before-data-bind><![CDATA[
		declare trs_owner int;

		trs_owner := (select trs_owner from tag_rule_set where trs_id = self.trs_id);
		if (trs_owner is not null and trs_owner <> self.u_id)
		  self.page_mode := 0;

		if (not e.ve_is_post and self.trs_data is null)
		  {
		    declare dat any;
		    dat := vector ();
		    for select rs_query, rs_tag, rs_is_phrase from tag_rules where rs_trs = self.trs_id do
		      {
		        dat := vector_concat (dat, vector (vector (rs_query, rs_tag, rs_is_phrase)));
		      }
		    if (self.trs_id >= 0)
	      	      {
		        declare exit handler for not found { signal ('22023', 'No such rule defined');  };
		        select trs_apc_id, trs_aps_id into self.trs_apc_id, self.trs_aps_id
			from tag_rule_set where trs_id = self.trs_id;
		      }
		    self.trs_data := dat;
		  }
		  ]]></v:before-data-bind>
	      <v:before-render>
		  --## there is a phenomenon which allows forms to be nested
		  control.vc_top_form.vc_add_attribute ('enctype', 'multipart/form-data');
	      </v:before-render>

	    <v:template name="edit_rule_tmpl" type="simple" enabled="--self.page_mode">
	    <table class="ctl_grp">
		<tr>
		    <th>Ruleset Name</th>
		    <td>
			<v:text name="trs_name" value=""  xhtml_size="50" fmt-function="wa_utf8_to_wide" cvt-function="wa_trim" error-glyph="*">
			    <v:validator test="regexp" regexp=".+" message="Ruleset name cannot be empty"/>
			    <v:after-data-bind><![CDATA[
				if (self.trs_id >= 0 and not e.ve_is_post)
				  {
				     select trs_name, trs_is_public
				     	into self.trs_name.ufl_value, self.trs_is_public.ufl_selected
				  	from tag_rule_set where trs_id = self.trs_id;
				  }
			  ]]></v:after-data-bind>
			</v:text>
		    </td>
		</tr>
		<tr>
		    <td>
			<v:check-box name="trs_is_public" value="1" xhtml_id="trs_is_public"/>
		    </td>
		    <td><label for="trs_is_public">Public</label></td>
		</tr>
		<tr>
		    <td colspan="2">
			<h4>Tagging Rules</h4>
			<table width="100%" class="listing">
					<tr class="listing_header_row">
					    <th>Query</th>
					    <th>Tag</th>
					    <th>Is phrase</th>
					    <th>Action</th>
					</tr>
			    <v:data-set
				name="dsr_rules"
				data="--self.trs_data"
				meta="--vector ()"
				nrows="1000"
				scrollable="1"
				edit="1"
				>
				<v:param name="uid" value="--self.u_id"/>
				<v:template type="repeat" name="dsr_rep">
				    <v:template type="browse" name="dsr_brows">
					<tr>
					    <td>
						<v:text name="drull1" value="--(control.vc_parent as vspx_row_template).te_rowset[0]"  fmt-function="wa_utf8_to_wide"/>
					    </td>
					    <td>
						<v:text name="drull2" value="--(control.vc_parent as vspx_row_template).te_rowset[1]"  fmt-function="wa_utf8_to_wide">
						</v:text>
					    </td>
					    <td>
						<v:check-box name="drull3" value="1" initial-checked="--(control.vc_parent as vspx_row_template).te_rowset[2]">
						    <v:after-data-bind>
							control.ufl_selected :=
							    	(control.vc_parent as vspx_row_template).te_rowset[2];
							if (e.ve_is_post and e.ve_button is not null and
								e.ve_button.vc_name in ('urul', 'trs_btn'))
							  {
							    if (get_keyword (control.vc_instance_name, e.ve_params) = '1')
							      control.ufl_selected := 1;
							    else
							      control.ufl_selected := 0;
							  }
						    </v:after-data-bind>
						</v:check-box>
					    </td>
					    <td>
						<v:button name="drul" value="Delete" action="simple">
						    <v:on-post><![CDATA[
							declare r vspx_row_template;
							declare dt, f, t, l, o, lef, rig any;
							dt := self.trs_data;
							r := control.vc_parent;
							l := length (dt);
							o := r.te_ctr + self.dsr_rules.ds_rows_offs;
							lef := null; rig := null;
							if (o > 0)
							  lef := subseq (dt, 0, o);
							if (o < l-1)
							  rig := subseq (dt, o+1, l);
							self.trs_data := vector_concat (lef, rig);
						        self.dsr_rules.vc_data_bind (e);
						  ]]></v:on-post>
						</v:button>
						<v:button name="urul" value="Update" action="simple">
						    <v:on-post><![CDATA[
							self.upd_rule (control, e, 1);
							]]></v:on-post>
						</v:button>
						<v:button name="moatbt1" value="MOAT" action="simple">
						    <v:on-post><![CDATA[
							self.save_rule (e);
							self.vc_redirect (sprintf ('moat_tags.vspx?trs_id=%d&edit=%U',
							self.trs_id, (control.vc_parent as vspx_row_template).te_rowset[1]));
							]]></v:on-post>
						</v:button>
					    </td>
					</tr>
				    </v:template>
				<v:template name="dsr_add" type="add">
				    <v:form type="update" name="dsr_add_f" method="POST">
					<tr>
					    <td>
						<v:text name="drult1" value=""  fmt-function="wa_utf8_to_wide" cvt-function="wa_trim" error-glyph="*">
						    <v:validator test="regexp" regexp=".+" message="Query cannot be empty"/>
						</v:text>
					    </td>
					    <td>
						<v:text name="drult2" value=""  fmt-function="wa_utf8_to_wide" cvt-function="wa_trim" error-glyph="*">
						    <v:validator test="regexp" regexp=".+" message="Tag cannot be empty"/>
						</v:text>
					    </td>
					    <td>
						<v:check-box name="drult3" value="1"/>
					    </td>
					    <td>
						<v:button name="arul" value="Add" action="simple">
						    <v:on-post>
						       declare dt any;
						       if (not self.vc_is_valid)
						         return;

						       if (self.drult3.ufl_selected = 0)
						       {
						         declare exit handler for sqlstate '*'
							 {
							   self.vc_is_valid := 0;
							   self.vc_error_message := 'The expression is not valid text query';
							   return;
							 };
							 vt_parse (self.drult1.ufl_value);
					               }

					               dt := self.trs_data;

						       foreach (any d in dt) do
						        {
						          if (d[0] = self.drult1.ufl_value and
							      d[1] = self.drult2.ufl_value)
							      {
							   	self.vc_is_valid := 0;
							   	self.vc_error_message := 'The expression for this tag is already defined';
							   	return;
							      }
							}

					               self.drult1.ufl_value := trim (self.drult1.ufl_value);
						       self.drult2.ufl_value := trim (self.drult2.ufl_value);

						       if (not length (self.drult1.ufl_value)
						       	or not length (self.drult2.ufl_value))
							{
							  self.vc_is_valid := 0;
							  self.vc_error_message := 'The query and tag cannot be empty';
							  return;
							}

						       dt := vector_concat ( dt, vector (
							vector (
								trim(self.drult1.ufl_value),
								trim(self.drult2.ufl_value),
								self.drult3.ufl_selected
								)));
						       self.trs_data := dt;

						       self.drult1.ufl_value := '';
						       self.drult2.ufl_value := '';
						       self.drult3.ufl_selected := 0;

						       self.dsr_rules.vc_data_bind (e);
						    </v:on-post>
						</v:button>
					    </td>
					</tr>
				    </v:form>
				</v:template>
				</v:template>
			    </v:data-set>
			</table>
		    </td>
		</tr>
		<v:template name="src_phrases" type="simple" instantiate="0">
		<tr>
		    <td colspan="2">
			<h4>Search Phrases</h4>
			<v:form name="pf1" type="simple" method="POST">
			    <v:text name="pattrn" value="" />
			    <v:button name="filt1" value="Filter" action="simple">
				<v:on-post>
				    if (not self.vc_is_valid)
				      return;
				    self.filt := self.pattrn.ufl_value;
				    self.dsr_phrase.vc_data_bind (e);
				</v:on-post>
			    </v:button>
			    <div class="<?V case when self.dsr_phrase.ds_rows_fetched &gt; 10 then 'scroll_area' else '' end ?>">
			<table width="100%" class="listing">
					<tr class="listing_header_row">
					    <th>
			<input type="checkbox" value="Select All" onclick="selectAllCheckboxes(this.form, this, 'cbp1')"/>
						Phrase
					    </th>
					</tr>
			    <v:data-set
				name="dsr_phrase"
				sql="select AP_TEXT from SYS_ANN_PHRASE where AP_TEXT like :filt"
				nrows="1000"
				scrollable="1"
				edit="1"
				>
				<v:param name="filt" value="--self.filt" />
				<v:template type="repeat" name="dsp_rep">
		    <v:template name="no_rows4" type="if-not-exists">
			<tr><td>No phrase(s) matching the search criteria</td></tr>
		    </v:template>
				    <v:template type="browse" name="dsp_brows">
					<tr>
					    <td>
						<v:check-box name="cbp1" group-name="cbp1" value="--(control.vc_parent as vspx_row_template).te_rowset[0]">
						    <v:before-render>
							if (get_keyword (control.ufl_value, self.vc_event.ve_params) is not null)
							  control.ufl_selected := 1;
						    </v:before-render>
						</v:check-box>
						<v:label name="cbl1"
						    value="--(control.vc_parent as vspx_row_template).te_rowset[0]"
						    fmt-function="wa_utf8_to_wide"/>
					    </td>
					</tr>
				    </v:template>
				</v:template>
				<v:template name="ds_foot" type="simple">
					<tr>
					    <td>
						<vm:ds-navigation data-set="dsr_phrase"/>
					    </td>
					</tr>
				</v:template>
			    </v:data-set>
			</table>
		    </div>
		    <v:button name="use_sel" value="Use selected" action="simple">
			<v:on-post><![CDATA[
			   declare dta any;
			   declare ph, inx any;

			   dta := self.trs_data;
			   inx := 0;
			   while ((ph := adm_next_keyword ('cbp1', e.ve_params, inx)) <> 0)
			     {
			       foreach (any d in dta) do
			        {
			          if (d[0] = ph and d[1] = ph)
				      {
				   	self.vc_is_valid := 0;
				   	self.vc_error_message := 'The expression for this tag is already defined';
				   	return;
				      }
				}

			       dta := vector_concat (dta, vector (vector (ph,ph,1)));
		             }
			   self.trs_data := dta;
			   self.dsr_rules.vc_data_bind (e);
		     ]]></v:on-post>
		</v:button>
		</v:form>
		    </td>
		</tr>
	    </v:template>
	    <tr><td colspan="2">
		<span class="fm_ctl_btn">
		    <!--td colspan="2"-->
			<v:button action="simple" name="trs_btn2" value="Cancel">
			    <v:on-post>
				self.vc_redirect ('tags.vspx');
			    </v:on-post>
			</v:button>
			<v:method name="save_rule" arglist="inout e vspx_event"><![CDATA[
				declare id int;
				if (not self.vc_is_valid)
				  return;

				declare ds vspx_data_set;
				declare chil vspx_control;
				declare ubtn vspx_button;
				declare cb vspx_check_box;
				declare inx int;
				inx := 0;
				ds := self.dsr_rules;
				while ((chil := ds.ds_iterate_rows (inx)) is not null)
				  {
				    chil.vc_focus := 1;
				    chil.vc_set_childs_focus (1,e);
				    cb := chil.vc_find_control ('drull3');
				    chil.vc_post (e);
				    cb.vc_data_bind (e);
				    ubtn := chil.vc_find_control ('urul');
				    self.upd_rule (ubtn, e, 0);
				    if (not self.vc_is_valid)
				      return;
			          }


				self.trs_name.ufl_value := trim (self.trs_name.ufl_value);
			        if (length (self.trs_name.ufl_value) = 0)
		                  {
				    self.vc_is_valid := 0;
				    self.vc_error_message := 'The ruleset name cannot be empty';
				    return;
		                  }

				if (self.trs_id >= 0 )
				  {
				    update tag_rule_set set trs_name = self.trs_name.ufl_value,
				      trs_is_public = self.trs_is_public.ufl_selected
				      where trs_id = self.trs_id;
				    id := self.trs_id;
				  }
				else
				  {
				    self.trs_aps_id := ANN_GETID ('S');
				    self.trs_apc_id := coalesce (
				     (select top 1 APC_ID from DB.DBA.SYS_ANN_PHRASE_CLASS where APC_OWNER_UID = self.u_id),
				     ANN_GETID ('C')
				    );

				    declare exit handler for sqlstate '23000'
				    {
				      rollback work;
				      self.vc_is_valid := 0;
				      self.vc_error_message := 'The ruleset name is already used, please enter unique rule name';
				      return;
				    };

				    insert into tag_rule_set (trs_name, trs_owner, trs_is_public, trs_apc_id, trs_aps_id)
				    values (self.trs_name.ufl_value, self.u_id, self.trs_is_public.ufl_selected,
				      self.trs_apc_id, self.trs_aps_id);
				    id := identity_value ();
				    self.trs_id := id;
				    declare ord int;
				    ord := coalesce ((select top 1 tu_order from tag_user
						where tu_u_id = self.u_id
						order by tu_order desc), 0);
				    ord := ord + 1;
				    insert into tag_user (tu_u_id, tu_trs, tu_order) values (self.u_id, id, ord);
				  }

				delete from tag_content_tc_text_query where tt_tag_set = id;
				delete from SYS_ANN_PHRASE where AP_APS_ID = self.trs_aps_id;

				insert soft DB.DBA.SYS_ANN_PHRASE_CLASS
				  (APC_ID, APC_NAME, APC_OWNER_UID, APC_READER_GID, APC_CALLBACK, APC_APP_ENV)
				values (self.trs_apc_id, self.u_name || '\'s Tagging Rule Class', self.u_id, http_nogroup_gid (), null, null);

				insert soft DB.DBA.SYS_ANN_PHRASE_SET (APS_ID, APS_NAME, APS_OWNER_UID, APS_READER_GID,
				APS_APC_ID, APS_LANG_NAME, APS_APP_ENV, APS_SIZE, APS_LOAD_AT_BOOT)
				values (self.trs_aps_id, self.u_name || '\'s ' || self.trs_name.ufl_value,
					self.u_id, http_nogroup_gid (), self.trs_apc_id, 'x-any', null, 10000, 1);

			        declare moat_save any;
			        moat_save := vector ();
		                foreach (any r in self.trs_data) do
		                  {
				     for select mu_url from moat.DBA.moat_user_meanings where mu_trs_id = id and mu_tag = r[1] do
				        {
					  moat_save := vector_concat (moat_save, vector (vector (r[1], mu_url)));
					}
		  	          }		  

				delete from tag_rules where rs_trs = id;
				foreach (any r in self.trs_data) do
				  {
				    insert into tag_rules (rs_trs, rs_query, rs_tag, rs_is_phrase)
				    	values (id, r[0], r[1], r[2]);
				    if (r[2] = 1)
		                      {
				        ap_add_phrases (self.trs_aps_id, vector ( vector (r[0], r[1]) ));
				      }
				    else
				      {
				        tt_query_tag_content (r[0], self.u_id, '', '', serialize (vector (id, r[1], r[2])));
				      }
				  }
				foreach (any r in moat_save) do
				  {
				    insert soft moat.DBA.moat_user_meanings (mu_trs_id, mu_tag, mu_url) values (id, r[0], r[1]);
			          }	  
			    ]]></v:method>
			<v:button action="simple" name="trs_btn" value="Save">
			    <v:on-post><![CDATA[
				self.save_rule (e);
				self.vc_redirect ('tags.vspx');
				]]></v:on-post>
			</v:button>
			<v:button action="simple" name="trs_btn3" value="Export"
			    xhtml_onclick="--sprintf ('javascript: window.open (\'trs_export.xml?:r=%d&amp;contenttype=application/octet-stream&amp;content-filename=%U.xml\', \'export\', \'\'); return false', self.trs_id, self.trs_name.ufl_value)"
			    enabled="--gte (self.trs_id, 0)">
			</v:button>
			<v:form action="POST" name="impform" type="simple" xhtml_enctype="multipart/form-data">
			    <v:text type="file" name="trs_file" value=""
				>
			    </v:text>
			    <v:button action="simple" name="trs_btn4" value="Import">
				<v:on-post>
				    declare f, xt, xp, dat any;
				    f := self.trs_file.ufl_value;

				    declare exit handler for sqlstate '*'
				    {
				      rollback work;
				      self.vc_is_valid := 0;
				      self.vc_error_message := 'The file to import is not specified or does not contains ruleset data.';
				      return;
				    };

				    xt := xtree_doc (f);
				    self.vc_is_valid := 1;
				    self.trs_name.ufl_value := xpath_eval ('/rule-set/@name', xt);

				    if (self.trs_name.ufl_value is null)
				      signal ('22023', 'No rules');


				    self.trs_is_public.ufl_selected := cast (xpath_eval ('/rule-set/@shared', xt) as int);
				    dat := vector ();

				    xp := xpath_eval ('/rule-set/rule', xt, 0);

				    foreach (any r in xp) do
				      {
				        declare q, t, is_p any;
					q := xpath_eval ('string(pattern)', r);
					t := xpath_eval ('string(tags)', r);
					is_p := cast (xpath_eval ('string(is-phrase)', r) as int);
					dat := vector_concat (dat, vector ( vector (q, t, is_p) ));
				      }

				    self.trs_data := dat;
				    self.vc_data_bind (e);
				</v:on-post>
			    </v:button>
			</v:form>
		    <!--/td-->
		</span>
	    </td>
	</tr>
    </table>
</v:template>
	    <v:template name="view_rule_tmpl" type="simple" enabled="--equ (self.page_mode, 0)">
	    <table class="ctl_grp">
		<tr>
		    <th>Ruleset Name</th>
		    <td>
			<v:label name="trs_name1" value="-- (select trs_name from tag_rule_set where trs_id = self.trs_id)"  xhtml_size="50" fmt-function="wa_utf8_to_wide" cvt-function="wa_trim" />
		    </td>
		</tr>
		<tr>
		    <td><label for="trs_is_public1">Public</label></td>
		    <td>
			Yes
		    </td>
		</tr>
		<tr>
		    <td colspan="2">
			<h4>Tagging Rules</h4>
			<table width="100%" class="listing">
					<tr class="listing_header_row">
					    <th>Query</th>
					    <th>Tag</th>
					    <th>Is phrase</th>
					</tr>
			    <v:data-set
				name="dsr_rules_vew1"
				data="--self.trs_data"
				meta="--vector ()"
				nrows="1000"
				scrollable="1"
				edit="1"
				>
				<v:param name="uid" value="--self.u_id"/>
				<v:template type="repeat" name="dsr_rep1">
				    <v:template type="browse" name="dsr_brows1">
					<tr>
					    <td>
						<v:label name="drull11" value="--(control.vc_parent as vspx_row_template).te_rowset[0]"  fmt-function="wa_utf8_to_wide"/>
					    </td>
					    <td>
						<v:label name="drull21" value="--(control.vc_parent as vspx_row_template).te_rowset[1]"  fmt-function="wa_utf8_to_wide"/>
					    </td>
					    <td>

						<v:label name="drull31" value="--case when (control.vc_parent as vspx_row_template).te_rowset[2] then 'Yes' else 'No' end"/>
					    </td>
					</tr>
				    </v:template>
				</v:template>
			    </v:data-set>
			</table>
		    </td>
		</tr>
	    <tr><td colspan="2">
		<span class="fm_ctl_btn">
			<v:button action="simple" name="trs_btn21" value="Back">
			    <v:on-post>
				self.vc_redirect ('tags.vspx');
			    </v:on-post>
			</v:button>
		</span>
	    </td>
	</tr>
    </table>
</v:template>
	</v:form>
    </xsl:template>
</xsl:stylesheet>
