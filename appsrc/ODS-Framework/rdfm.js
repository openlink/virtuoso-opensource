var graphIRI = false;
function RDFMInit ()
{
  var head=document.getElementsByTagName("head")[0];
  var cssNode = document.createElement('link');
  var div = $("dock_content");
  var r = new OAT.RDFMini(div,{showSearch:false});
  cssNode.type = 'text/css';
  cssNode.rel = 'stylesheet';
  cssNode.href = "rdfm.css";
  head.appendChild(cssNode);
  if (graphIRI)
   r.open(graphIRI);
}
