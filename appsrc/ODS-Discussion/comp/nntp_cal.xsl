<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:vm="http://www.openlinksw.com/vspx/weblog/" version="1.0">
  <xsl:template match="vm:nntp-cal">
  <img id="cal_anchor" src="images/spacer.png" />
      <script type="text/javascript">
       <![CDATA[
           
           var divLT=document.getElementById('LT');
           if(divLT.offsetHeight<170)
           {
            divLT.style.height='170px';
           }
           
           var nntpCal = new Object;
           
           function calendarInit()
           {
           

           nntpCal = new OAT.Calendar();
           
//           if(typeof($('show_tagsblock'))!='undefined' && $('show_tagsblock').value==1) return;
           
           showCalendar();

           }

           function showCalendar()
           {
             var anchorTopLeft=OAT.Dom.position('cal_anchor');

             
             if (!OAT.Browser.isIE)
              nntpCal.show(anchorTopLeft[0]+10, anchorTopLeft[1]+12, clickCal);
           else
              nntpCal.show(anchorTopLeft[0]+10, anchorTopLeft[1]+2, clickCal);
          };

           function clickCal(_date)
           {

            var sid='<?Vself.sid?>';
            var realm='<?Vself.realm?>';
            var loginParams=(sid.length?'sid='+sid:'')+(realm.length?'&realm='+realm:'');
            var searchStr;
            
            var next_day = new Date(_date[0],_date[1]-1,_date[2]+1);

//            '?'+(loginParams.length ? loginParams+'&' : '') +
            searchStr  = '?'+loginParams +
                         '&ontype=nntpf' +
                         '&date_d_after='+_date[2]+'&date_m_after='+_date[1]+'&date_y_after='+_date[0] +
                         '&date_d_before='+next_day.getDate()+'&date_m_before='+(next_day.getMonth()+1)+'&date_y_before='+next_day.getFullYear();

            document.location='<?V sprintf ('%ssearch.vspx', self.odsbar_ods_gpath) ?>'+searchStr;
   
            nntpCal.show(nntpCal.div.style.left, nntpCal.div.style.top, clickCal);
           }

        ]]>
      </script>

  </xsl:template>

  <xsl:template match="vm:nntp-cal-old">
    <v:form name="nntp_cal_form" method="POST" type="simple">
    <v:calendar name="nntp_cal" initial-date="--coalesce (self.nntp_cal_day, now ())">
      <v:on-post>
          <![CDATA[
	    if (not control.vc_focus or e.ve_button.vc_name like '_mon')
	      return;
	    self.fordate := self.nntp_cal.cal_selected;
	    if (udt_defines_field (self, 'ds_list_message'))
	      {
--		 dbg_obj_print ('+ + + comp/nntp_cal.xs self.fordate = ', self.fordate);
		 declare h vspx_data_set;
		 declare x vspx_data_source;
		 x := udt_get (self, 'dss');
		 x.ds_rows_offs := 0;
		 x.vc_data_bind (e);
		 h := udt_get (self, 'ds_list_message');
		 h.vc_reset ();
		 h.ds_rows_offs := 0;
		 h.vc_data_bind (e);
	      }
	    else if (udt_defines_field (self, 'ds_list_thread'))
	      {
		 declare h vspx_control;
		 h := udt_get (self, 'ds_list_thread');
		 h.vc_data_bind (e);
	      }
	    else if (udt_defines_field (self, 'thread_tree'))
	      {
		 declare h vspx_control;
		 h := udt_get (self, 'thread_tree');
		 h.vc_data_bind (e);
	      }
          ]]>
      </v:on-post>
      <v:before-data-bind><![CDATA[

	set isolation = 'committed';
	declare ndays any;
	declare m, y int;
	declare dt date;
	declare sel_group, is_thr varchar;

	if (not self.vc_is_postback)
	  control.cal_date := coalesce (self.nntp_cal_day, now ());

	self.nntp_cal_day := control.cal_date;

	dt := coalesce (control.cal_date, self.fordate);

	m := month (dt);
	y := year (dt);

	ndays := vector ();

	sel_group := atoi (get_keyword ('group', params, NULL));
	is_thr := atoi (get_keyword ('thr', params, NULL));

--	dbg_obj_print ('+++ nntp_cal.xsl params = ', params);

	if (sel_group is NULL)
	  for (select distinct dayofmonth (FTHR_DATE) DDAY from NNFE_THR
		where year (FTHR_DATE) = y and month (FTHR_DATE) = m) do
		     ndays := vector_concat (ndays, vector (cast (DDAY as varchar)));
	else if (is_thr)
	  for (select distinct dayofmonth (FTHR_DATE) DDAY from NNFE_THR
		where year (FTHR_DATE) = y and month (FTHR_DATE) = m and FTHR_GROUP= sel_group and FTHR_TOP = 1) do
		     ndays := vector_concat (ndays, vector (cast (DDAY as varchar)));
	else
	  for (select distinct dayofmonth (FTHR_DATE) DDAY from NNFE_THR
		where year (FTHR_DATE) = y and month (FTHR_DATE) = m and FTHR_GROUP= sel_group) do
		     ndays := vector_concat (ndays, vector (cast (DDAY as varchar)));

--	dbg_obj_print ('ndays = ', ndays);

	self.ndays := ndays;

      ]]></v:before-data-bind>
      <v:template type="simple" name="chead1" name-to-remove="table" set-to-remove="bottom">
      <table border="0" cellpadding="0" cellspacing="0">
        <tr>
         <td align="center">
	  <v:button name="pmon" value="--sprintf('%V', '<')" action="simple" style="url">
	    <!--v:before-render>
	    declare cal vspx_calendar;
	    cal := control.vc_parent.vc_parent;
	    control.ufl_value := substring (monthname (dateadd ('month', -1, cal.cal_date)), 1, 3);
	    </v:before-render-->
	    <v:on-post>
	    declare cal vspx_calendar;
	    declare ctrl vspx_control;
	    cal := control.vc_parent.vc_parent;
	    cal.cal_date := dateadd ('month', -1, cal.cal_date);
	    ctrl := cal;
	    ctrl.vc_data_bind (e);
	    </v:on-post>
	  </v:button>
	 </td>
 	 <td colspan="5" align="center">
           <?V monthname((control.vc_parent as vspx_calendar).cal_date) ?>
	   <?V year((control.vc_parent as vspx_calendar).cal_date) ?>
	 </td>
         <td align="center">
	  <!--v:button name="nmon" value="--sprintf('%V', '>')" action="simple" style="url"-->
	  <v:button name="nmon" value=">" action="simple" style="url">
	    <!--v:before-render>
	    declare cal vspx_calendar;
	    cal := control.vc_parent.vc_parent;
	    control.ufl_value := substring (monthname (dateadd ('month', 1, cal.cal_date)), 1, 3);
	    </v:before-render-->
	    <v:on-post>
	    declare cal vspx_calendar;
	    declare ctrl vspx_control;
	    cal := control.vc_parent.vc_parent;
	    cal.cal_date := dateadd ('month', 1, cal.cal_date);
	    ctrl := cal;
	    ctrl.vc_data_bind (e);
	    </v:on-post>
	  </v:button>
	 </td>
	 </tr>
        <tr><td>Sun</td><td>|Mon</td><td>|Tue</td><td>|Wed</td><td>|Thu</td><td>|Fri</td><td>|Sat</td></tr>
      </table>
      </v:template>
      <v:template type="repeat" name="cbody1" name-to-remove="" set-to-remove="">
      <v:template type="browse" name="crow1" name-to-remove="table" set-to-remove="both">
      <table>
      <tr>
       <td align="center" class="&lt;?V nntpf_cell_fmt((control as vspx_row_template).te_rowset[0], self.ndays, self.fordate, self.nntp_cal.cal_date) ?>">
	<v:button style="url" active="--position(control.ufl_value, self.ndays)" action="simple" name="b1" value="--nntpf_cal_icell(control, 0)" /></td>
       <td align="center" class="&lt;?V nntpf_cell_fmt((control as vspx_row_template).te_rowset[1], self.ndays, self.fordate, self.nntp_cal.cal_date) ?>">
	<v:button style="url" active="--position(control.ufl_value, self.ndays)" action="simple" name="b2" value="--nntpf_cal_icell(control, 1)" /></td>
       <td align="center" class="&lt;?V nntpf_cell_fmt((control as vspx_row_template).te_rowset[2], self.ndays, self.fordate, self.nntp_cal.cal_date) ?>">
	<v:button style="url" active="--position(control.ufl_value, self.ndays)" action="simple" name="b3" value="--nntpf_cal_icell(control, 2)" /></td>
       <td align="center" class="&lt;?V nntpf_cell_fmt((control as vspx_row_template).te_rowset[3], self.ndays, self.fordate, self.nntp_cal.cal_date) ?>">
	<v:button style="url" active="--position(control.ufl_value, self.ndays)" action="simple" name="b4" value="--nntpf_cal_icell(control, 3)" /></td>
       <td align="center" class="&lt;?V nntpf_cell_fmt((control as vspx_row_template).te_rowset[4], self.ndays, self.fordate, self.nntp_cal.cal_date) ?>">
	<v:button style="url" active="--position(control.ufl_value, self.ndays)" action="simple" name="b5" value="--nntpf_cal_icell(control, 4)" /></td>
       <td align="center" class="&lt;?V nntpf_cell_fmt((control as vspx_row_template).te_rowset[5], self.ndays, self.fordate, self.nntp_cal.cal_date) ?>">
	<v:button style="url" active="--position(control.ufl_value, self.ndays)" action="simple" name="b6" value="--nntpf_cal_icell(control, 5)" /></td>
       <td align="center" class="&lt;?V nntpf_cell_fmt((control as vspx_row_template).te_rowset[6], self.ndays, self.fordate, self.nntp_cal.cal_date) ?>">
	<v:button style="url" active="--position(control.ufl_value, self.ndays)" action="simple" name="b7" value="--nntpf_cal_icell(control, 6)" /></td>
      </tr>
      </table>
      </v:template>
      </v:template>
      <v:template type="simple" name="cbott1" name-to-remove="table" set-to-remove="top">
      <table>
      </table>
      </v:template>
      <!--v:before-render>
--      dbg_vspx_control (control);
--        dbg_obj_print ('v:before-render');
      </v:before-render-->
    </v:calendar>
    </v:form>
  </xsl:template>
</xsl:stylesheet>
