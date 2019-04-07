<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2019 OpenLink Software
#  
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#  
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#  
#  
?>
<!-- Note: Although we may set the font size in here, we also make heavy
     use of the HTML font tag since many browsers do not properly support 
     style sheet font settings.
-->
<STYLE type="text/css">
<!--
.tablecell {
  font-family: <?php echo $FONTS ?>;
  font-size: 12px;
  width: 80px;
  height: 80px;
}
.tablecelldemo {
  font-family: <?php echo $FONTS ?>;
  font-size: 10px;
  width: 30px;
  height: 30px;
}
.tablecellweekend {
  font-family: <?php echo $FONTS ?>;
  font-size: 12px;
  width: 80px;
  height: 80px;
  background-color: <?php echo ( $WEEKENDBG == "" ? "#E0E0E0" : $WEEKENDBG ); ?> ;
}
.tablecellweekenddemo {
  font-family: <?php echo $FONTS ?>;
  font-size: 10px;
  width: 30px;
  height: 30px;
  background-color: <?php echo ( $WEEKENDBG == "" ? "#E0E0E0" : $WEEKENDBG ); ?> ;
}
.tableheader {
  font-family: <?php echo $FONTS ?>;
  font-size: 14px;
  color: <?php echo ( $THFG == "" ? "#FFFFFF" : $THFG ); ?> ;
  background-color: <?php echo ( $THBG == "" ? "#000000" : $THBG ); ?> ;
}
.tableheadertoday {
  font-family: <?php echo $FONTS ?>;
  font-size: 14px;
  color: <?php echo ( $TABLECELLFG == "" ? "#000000" : $TABLECELLFG ); ?> ;
  background-color: <?php echo ( $TODAYCELLBG == "" ? "#C0C0C0" : $TODAYCELLBG ); ?> ;
}
.dayofmonth {
  font-family: <?php echo $FONTS ?>;
  font-size: 12px;
  color: #000000;
  text-decoration: none;
  background-color: #E7E7E7;
}
.weeknumber {
  font-family: <?php echo $FONTS ?>;
  font-size: 10px;
  color: #B04040;
  text-decoration: none;
}
.monthlink {
  font-family: <?php echo $FONTS ?>;
  font-size: 14px;
  color: #B04040;
  text-decoration: none;
}
.dayofmonthyearview {
  font-family: <?php echo $FONTS ?>;
  font-size: 12px;
  text-decoration: none;
}
.dayofmonthweekview {
  font-family: <?php echo $FONTS ?>;
  font-size: 12px;
  color: #000000;
  text-decoration: none;
}
.entry {
  font-family: <?php echo $FONTS ?>;
  font-size: 12px;
  color: #006000;
  text-decoration: none;
}
.unapprovedentry {
  font-family: <?php echo $FONTS ?>;
  font-size: 12px;
  color: #800000;
  text-decoration: none;
}
.navlinks {
  font-family: <?php echo $FONTS ?>;
  font-size: 14px;
  color: <?php echo ( $TEXTCOLOR == "" ? "#000000" : $TEXTCOLOR ); ?> ;
  text-decoration: none;
}
A {
  font-family: <?php echo $FONTS ?>;
  color: <?php echo ( $TEXTCOLOR == "" ? "#000000" : $TEXTCOLOR ); ?> ;
  text-decoration: none;
}
.aboutinfo {
  font-family: <?php echo $FONTS ?>;
  color: #000000;
  text-decoration: none;
}
.popup {
  font-family: <?php echo $FONTS ?>;
  font-size: 12px;
  color: <?php echo ( $POPUP_FG == "" ? "#000000" : $POPUP_FG ); ?> ;
  text-decoration: none;
}
.layerentry {
  font-family: <?php echo $FONTS ?>;
  color: #006060;
  text-decoration: none;
}
.tooltip {
  cursor: help;
  text-decoration: none;
}
.defaulttext {
  font-family: <?php echo $FONTS ?>;
  font-size: 12px;
  color: <?php echo ( $TEXTCOLOR == "" ? "#000000" : $TEXTCOLOR ); ?> ;
}
h2 {
  font-family: <?php echo $FONTS ?>;
  font-size: 20px;
}
h3 {
  font-family: <?php echo $FONTS ?>;
  font-size: 18px;
}
.pagetitle {
  font-family: <?php echo $FONTS ?>;
  font-size: 18px;
}
body {
  font-family: <?php echo $FONTS ?>;
  font-size: 12px;
}
td {
  font-family: <?php echo $FONTS ?>;
  font-size: 12px;
}
p {
  font-family: <?php echo $FONTS ?>;
  font-size: 12px;
}
input {
  font-family: <?php echo $FONTS ?>;
  font-size: 12px;
}
select {
  font-family: <?php echo $FONTS ?>;
  font-size: 12px;
}
textarea {
  font-family: <?php echo $FONTS ?>;
  font-size: 12px;
}
a:hover {
  font-family: <?php echo $FONTS ?>;
  color: #0000FF;
}
-->
</STYLE>
