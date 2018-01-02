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
 *  
*/
//   XMLHTTP Request common functions

if (window.ActiveXObject && !window.XMLHttpRequest) 
{
  window.XMLHttpRequest = function() 
  {
	   try {
	     return new ActiveXObject("Msxml2.XMLHTTP");
	   } catch (e) { 
	    try 
	      {
	        return new ActiveXObject('Microsoft.XMLHTTP');
	      } 
	    catch (e) 
	      {
	      }
	   }
		
    return null;
  };
}

function soap_error_alert (req)
{
  if (req.status == 500 && req.responseXML != null)
    {
      var respXML = req.responseXML;
      var elms = respXML.getElementsByTagName("Fault");
      var err = req.statusText + '\r\n';
      if (elms.length != 0)
        {
          var i;
          var elms = respXML.getElementsByTagName("faultstring");
          if (elms.length)
	    {
	      var nodes = elms[0].childNodes 
	       for (i = 0; i < nodes.length; i++)
		 {
		   if (nodes[i].nodeType == 3)
		     err = err + nodes[i].nodeValue; 
		 }  
	    }
        }
      alert (err);   
    }
  else
    {
      alert ('Error: ' + req.statusText);
    }
}

function fill_inner (results, tag_name)
{
  var str = "";
  if (!results || results.length != 1)
    {
      str = 'No result is returned.';
    }
  else
    {  
      var nodes = results[0].childNodes;

      if (!nodes || nodes.length == 0)
        {
          str = 'No result is returned.';
        }
      else
        {
          var i;
          for (i = 0; i < nodes.length; i++)
             {
	       if (nodes[i].nodeType == 3)
		 str = str + nodes[i].nodeValue;
             }
        }
     }
  document.getElementById(tag_name).innerHTML = str;
}
