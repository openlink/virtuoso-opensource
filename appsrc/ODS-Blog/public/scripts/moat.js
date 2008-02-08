function moat_init ()
{
  var tags = $("post_tags").value;
  var moat = $("tb_moat");
  var msg = OAT.Dom.text ("Associate your tags, in the current context, with one or more of the following things or concepts:");
  var arr = tags.split (",");
  var nodes = 0;
  OAT.Dom.clear (moat);
  for (var i = 0; i < arr.length; i++)
    {
      var tag = arr[i].trim();
      if (tag.length < 1)
	continue;
      if (0 == i) 
	moat.appendChild (msg);
      var fset = OAT.Dom.create("fieldset",{});
      var div = OAT.Dom.create("div",{});
      var legend = OAT.Dom.create("legend",{});
      var text = OAT.Dom.text (tag, {});
      var a = OAT.Dom.create ("a", {});

      a.appendChild (text);
      assign_cl (a, div);
      a.href="javascript:void(0)";
      legend.appendChild (a);
      fset.appendChild (legend);
      fset.appendChild (div);
      toggleTag (a, div);
      moat_get_meanings (tag, div);
      moat.appendChild (fset);
      nodes ++;
    }
  if (0 == nodes)
    {
      msg = OAT.Dom.text ("You don't appear to have any tags defined in this context, please define tags first.");
      moat.appendChild (msg);	  
    }
}

function panel_init ()
{
  var pb = new OAT.Tab ("tb_cont");
  pb.add ("tags","tb_tags");
  pb.add ("category","tb_cat");
  pb.add ("moat","tb_moat");
  pb.add ("trackback","tb_tab");
  pb.go (0);
  moat_init ();
}

function toggleTag (a, div)
{
  if (div.style.display == "none")
    {
      OAT.Dom.show (div);
      a.className = "collapsible";
    }
  else
    { 
      OAT.Dom.hide (div);
      a.className = "collapsed";
    }
}

function assign_cl (a, div)
{
  var ref = function() {
    toggleTag (a, div);
  }
  OAT.Dom.attach(a, "click", ref);
}

function moat_get_meanings (tag, par)
{
  function tags_cb (text)
    {
      var div;
      var a;
      var cb;

      eval ('var obj = ' + text);
      var arr = obj.results.bindings;
      for (var i = 0; i < arr.length; i++)
	{
	  if (null == arr[i])
	    break;
	  var url = arr[i].uri.value;
	  div = OAT.Dom.create("div", {});
	  a = OAT.Dom.create("a", {});
	  cb = OAT.Dom.create("input");
	  cb.type = "checkbox";
	  cb.name = 'tag_' + escape (tag);
	  cb.value = url;
	  cb.checked = cb.defaultChecked = arr[i].uri.checked;
	  a.innerHTML = url;
	  a.href = url;
	  div.appendChild (cb);
	  div.appendChild (a);
	  par.appendChild (div);
	}
      div = OAT.Dom.create("div", {});
      a = OAT.Dom.create("input", { "width":"240px" }, "textbox");
      a.type = "text";
      a.name = "tag_" +escape (tag);
      cb = OAT.Dom.create("input");
      cb.type = "checkbox";
      cb.name = "new_tag_" +escape (tag);
      div.appendChild (cb);
      div.appendChild (a);
      par.appendChild (div);
    }
  OAT.AJAX.GET ("/ods_services/Http/tag_meanings?tag="+ escape(tag)+"&inst="+inst_id+"&post="+post_id,
		false, tags_cb, {type:OAT.AJAX.TYPE_TEXT, onstart:function(){}, onerror:function(){}});
}


