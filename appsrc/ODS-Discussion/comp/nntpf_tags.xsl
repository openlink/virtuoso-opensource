<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2018 OpenLink Software
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
<!-- news group list control; two states in main page and on the other pages -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/"
                version="1.0">

  <xsl:template match="vm:tags-block">
              <div id="tags_div" style="display: none;height:72px;">
               <input type="hidden" name="curr_ngroup" id="curr_ngroup" value=""/>
               <input type="hidden" name="curr_post" id="curr_post" value=""/>

               <?vsp if(length(self.u_name))
               {
               ?>
               <input type="text" id="new_tag" style="width:140px"/>
               <a href="javascript:void(0)" onClick="doTag( $v('curr_ngroup'),$v('curr_post'),$v('new_tag'),'add'); return false"><img src="images/add_10.png" alt="Add Tag" title="Add Tag" border="0" /></a>
               <?vsp
      } else {
               ?>
                 <img src="images/spacer.png" style="height:10px;width:170px;"/>
               <?vsp
               }
               ?>
               <a href="javascript: void(0);" onClick="hideTagsDiv()">close</a>
               <br/>
               <div id="tagslist_div">
               </div>
               <br/>
              </div>
<script type="text/javascript">
    <![CDATA[
    function genTagsList(ngroupId,postId)
    {
      var wsdl = "<?VWA_LINK(0, '/')?>ods_services/services.wsdl";
      var serviceName = "discussions_taglist";
      var inputObject = {
            discussions_taglist: {ngroup_id:ngroupId,
                               post_id:postId,
                               u_id:<?V(case when length(self.u_name)>0 then (select U_ID from DB.DBA.SYS_USERS where U_NAME=self.u_name) else '-1' end)?>
          }  
      }     

     OAT.WS.invoke(wsdl,  serviceName, genTagsListSeponceProcessor, inputObject);
    }
    
        function genTagsListSeponceProcessor(outputObject)
        {
        if(typeof(outputObject.discussions_taglistResponse.CallReturn) != 'undefined')
        {
           res=outputObject.discussions_taglistResponse.CallReturn;
           var listHTML='';
           var isAdminTag=0;
           if(res.length>0)
           {
            var tagsArr=res.split(',');
            if(tagsArr.length>0)
            {
              for(i=0;i<tagsArr.length;i++)
              {        
              if(tagsArr[i].length)
              {          
                if(tagsArr[i]=='###')
                {
                 isAdminTag=1;
                 listHTML=listHTML+'<br/>';
                    } else {
                      listHTML=listHTML+'<span style="float:left;"><a href="javascript:void(0)" onClick="showTag(\''+tagsArr[i]+'\');" title="Show items with tag '+tagsArr[i]+'"><b>'+tagsArr[i]+'</b></a>';
              <?vsp
               if(length(self.u_name))
               {
              ?>
                 if(!isAdminTag)
                 {
                        listHTML=listHTML+'<a href="javascript:void(0)" onclick="doTag( $v(\'curr_ngroup\'),$v(\'curr_post\'),\''+tagsArr[i]+'\',\'del\'); return false"><img src="images/del_10.png" alt="Delete Tag" title="Delete Tag" border="0"/></a>';
                 }
              <?vsp
               }
              ?>
                 }
              if(i<tagsArr.length-1)
                  listHTML=listHTML+'&nbsp;';

              listHTML=listHTML+'</span>';
                }
              }
            }
            else
            {
            listHTML='<a href="javascript:void(0)" onClick="showTag(\''+res+'\');" title="Show items with tag '+res+'"><b>'+res+'</b></a>'+
                     '<a href="javascript:void(0)" onclick="doTag( $v(\'curr_ngroup\'),$v(\'curr_post\'),\''+res+'\',\'del\'); return false"><img src="images/del_10.png" alt="Delete Tag" title="Delete Tag" border="0"/></a>';
            }
           }
           $('tagslist_div').innerHTML=listHTML;
        }
    }
    function tagsInit()
    { 
     genTagsList($v('curr_ngroup'),$v('curr_post'));
               if(typeof($('show_tagsblock'))!='undefined' && $('show_tagsblock').value==1)
                  showTagsDiv('<?Vself.grp_sel_thr?>','<?Vself.cur_art?>',$('curr_a'));
                 }
    function doTag(_ngroupId,_postId,_tag,_tagAction)
    {
      var wsdl = "<?VWA_LINK(0, '/')?>ods_services/services.wsdl";
      var serviceName = "discussions_dotag";
      var inputObject = {
          discussions_dotag:{
                            ngroup_id:_ngroupId,
                            post_id:_postId,
                            tag:_tag,
                            do_action:_tagAction,
                            user_name:'<?Vself.u_name?>',
                            user_pass:'<?V(case when length(self.u_name)>0 then (select md5(U_PASSWORD) from DB.DBA.SYS_USERS where U_NAME=self.u_name) else '' end)?>'
          }
      }
          function callback(outputObject)
          {
        genTagsList(_ngroupId,_postId);
        updateTagsCount(_ngroupId,_postId);
      }
      OAT.WS.invoke(wsdl,  serviceName, callback, inputObject);
    }
    function updateTagsCount(ngroupId,_postId)
    {
      var wsdl = "<?VWA_LINK(0, '/')?>ods_services/services.wsdl";
      var serviceName = "discussions_tagscount";
      var inputObject = {
          discussions_tagscount:{
                            ngroup_id:ngroupId,
                            post_id:_postId,
                            u_id:<?V(case when length(self.u_name)>0 then (select U_ID from DB.DBA.SYS_USERS where U_NAME=self.u_name) else '0' end)?>
          }
      }
          function callback(outputObject)
          {
        $('tags_div').curr_a_elm.innerHTML='tags ('+outputObject.discussions_tagscountResponse.CallReturn+')';
      }
      OAT.WS.invoke(wsdl,  serviceName, callback, inputObject);
    }
    function showTagsDiv(ngroupId,postId,curr_a_elm)
    {
     $('curr_ngroup').value=ngroupId;
     $('curr_post').value=postId;
     genTagsList(ngroupId,postId);

     var calendarH=0;
     if(typeof(nntpCal.div)!='undefined')
        calendarH=nntpCal.div.scrollHeight;

      var myDiv=$('tags_div');
      myDiv.curr_a_elm=curr_a_elm;
          var anchorTopLeft=OAT.Dom.position('cal_anchor');

          if (!OAT.Browser.isIE)
           {
              myDiv.style.left = (anchorTopLeft[0]+10)+'px';     
         myDiv.style.top = (anchorTopLeft[1]+20+calendarH)+'px';
          } else {
              myDiv.style.left = (anchorTopLeft[0]+10)+'px';     
         myDiv.style.top = (anchorTopLeft[1]+12+calendarH)+'px';
           }
      OAT.Dom.show('tags_div');
          if (!OAT.Browser.isIE)
      {
         if($('LT').offsetHeight<(calendarH+16+$('tags_div').offsetHeight))
         {
           $('LT').style.height=(calendarH+25+$('tags_div').offsetHeight)+'px';
         }
          } else {
         if($('LT').offsetHeight<(calendarH+6+$('tags_div').offsetHeight))
         {
           $('LT').style.height=(calendarH+15+$('tags_div').offsetHeight)+'px';
         }
      }
    }
    function hideTagsDiv()
    {
      OAT.Dom.hide('tags_div');
          if (typeof($('show_tagsblock'))!='undefined' && $('show_tagsblock').value==1)
            showCalendar();
      nntpCal.div.style.display="block";
    }
    function showTag(tag)
    {
      var sid='<?Vself.sid?>';
      var realm='<?Vself.realm?>';
      var loginParams=(sid.length?'sid='+sid:'')+(realm.length?'&realm='+realm:'');
      var searchStr;
 
      searchStr  = '?'+loginParams +'&q_tags='+tag;

      document.location='<?V sprintf ('%ssearch.vspx', self.odsbar_ods_gpath) ?>'+searchStr;
     
      return false;
    }
    ]]>
</script>
  </xsl:template>
</xsl:stylesheet>
