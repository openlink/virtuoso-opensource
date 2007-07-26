var OATG_LANG = {};
OATG_LANG['DAYS'] = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"];
OATG_LANG['MONTHS'] = ["January","February","March","April","May","June","July","August","September","October","November","December"];

var Settings = { /* user-settable */
	monthWidth:160
}

var TL = {
		obj:false,
		scrollTo:function(event) {
			var tl = TL.obj;
			var dims = OAT.Dom.getWH(tl.port);
			var left = tl.position;
			var right = left + dims[0];
			var pos = event.x1 - Math.round(dims[0]/2)
			
			if (pos > left && pos+10 < right) { return; }
			
			var limit = tl.slider.options.maxValue;
			if (pos < 0) { pos = 0; }
			if (pos > limit) { pos = limit; }
			tl.scrollTo(pos);
			tl.slider.slideTo(pos);
		},
		options: {
			formatter:false,
			resize:false,
			timeStepOverride:"_months",
			lineHeight:18,
			noIntervals:true,
			timeTitleOverride:function(date) {
				return date.format("j.n.Y");
			},
			timeLabelOverride:function(date) {
				var result = "";
				var m = date.getMonth();
				if (!m) { result += date.getFullYear()+"<br/>"; }
				result += OATG_LANG['MONTHS'][m];
				return result;
			}
		},
		attach:function(elm,album) {
			OAT.Dom.attach(elm,"mouseover",function() {
//				for (var i=0;i<album.parts.length;i++) {
//					var part = album.parts[i];
//					if (part.marker) { part.marker.setImage("http://ondras.praha12.net/marker_green.png"); }
//				}
			});
			OAT.Dom.attach(elm,"mouseout",function() { 
//				for (var i=0;i<album.parts.length;i++) {
//					var part = album.parts[i];
//					if (part.marker) { part.marker.setImage("http://www.google.com/intl/en_ALL/mapfiles/marker.png"); }
//				}
			});
		},
		draw:function() {
		  TL.clear();
			OAT.TlScale.defWidth = Settings.monthWidth;
			var tl = new OAT.Timeline("timeline",TL.options);
			TL.obj = tl;
			tl.addBand(0,false,false);
			for (var i=0;i< ds_albums.list.length ;i++) {
				var album = ds_albums.list[i];
				if (album.obsolete==1) { continue; }
				var d = OAT.Dom.create("div",{},"timeline_item");
				var ball = OAT.Dom.create("div",{},"timeline_ball");
				var a = OAT.Dom.create("a");
				a.href = "#/"+album.name+'/';
				a.innerHTML = album.name;
				a.id = 'tl_showalbum_idx_'+i;
        var tlAlbumClick = function(e){
            var id_arr=e.target.id.split('_');
            OAT.Dom.hide('timeline');
            OAT.Dom.hide('map');
            var album_idx = id_arr[id_arr.length-1];
            gallery.setCurrent(album_idx);
            gallery.ajax.load_images(album_idx);
        };
        var tlAlbumOnMouseOver = function(e){
            var id_arr=e.target.id.split('_');
            var album_idx = id_arr[id_arr.length-1];
            var infoWinContent=preview_collection_4_map(ds_albums.list[album_idx],album_idx);
            var marker_idx=map.findMarkerIndexByGroup(album_idx);
            map.markerArr[marker_idx].openInfoWindow(infoWinContent);
            if (!e) var e = window.event
            var el = (e.target) ? e.target : e.srcElement
            OAT.Dom.addClass((ds_albums.list[album_idx]).event.elm,"event_active");

        }
        var tlAlbumOnMouseOut = function(e){
            var id_arr=e.target.id.split('_');
            var album_idx = id_arr[id_arr.length-1];
            map.obj.closeInfoWindow();
            if (!e) var e = window.event
            var el = (e.target) ? e.target : e.srcElement
            OAT.Dom.removeClass((ds_albums.list[album_idx]).event.elm,"event_active"); 
        }
        OAT.Dom.attach(a,'click',tlAlbumClick); 
        if(album.geolocation[2]=='true')
        {
          OAT.Dom.attach(a,'mouseover',tlAlbumOnMouseOver); 
          OAT.Dom.attach(a,'mouseout',tlAlbumOnMouseOut); 
        }

				OAT.Dom.append([d, ball, a]);
				album.event = tl.addEvent(0,album.start_date,album.end_date,d,"#ddd");
				TL.attach( a,album);
			}
			
			var bl = OAT.Dom.create("span");
			var last = tl.addEvent(0,new Date(),false,bl,"");
			tl.draw();
			TL.scrollTo(last);
		},
		
    clear:function() {
      if(TL.obj)
      {
        var _div = TL.obj.elm.parentNode.parentNode;
        TL.obj.clear();
        OAT.Dom.clear(_div);

      }
		}

	}
	
