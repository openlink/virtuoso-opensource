document.write("<style>"+
((/^ms/.test(document.documentElement.uniqueID))?"":"#ie7_demo button{display:none;}")+
"#ie7_demo{position:relative;background:"+
((/^ms/.test(document.documentElement.uniqueID)&&location.search!="?ie7_off")?"yellow":"#ccc")+
";color:black;padding:4px 0;margin:0;text-indent:8px;"+
"left:0;top:0;letter-spacing:normal;text-align:left;height:auto;width:200px;border:none;"+
"font:bold 32px/36px Verdana,Arial,Helvetica,sans-serif;text-transform:none;z-index:99;}"+
"#ie7_demo button{margin-left:20px;padding:0;line-height:16px;vertical-align:middle;text-indent:0px;}</style>"+
"<h1 id='ie7_demo'>IE7&nbsp;<button type=button onclick=\"location.replace(location.pathname+'"+
(location.search=="?ie7_off"?"":"?ie7_off")+"')\">"+
(location.search=="?ie7_off"?"Apply":"Remove")+"</button></h1>");
