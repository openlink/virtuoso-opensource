#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2006 OpenLink Software
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

TOP=@TOP@

SUBDIRS = . apps hosting services web xml

if WITH_BPEL_VAD
nodist_vad_DATA = tutorial_filesystem.vad tutorial_dav.vad
endif

CLEANFILES = tutorial_filesystem.vad tutorial_dav.vad

tutorial_filesystem.vad tutorial_dav.vad: make_vad.sh
	PATH="$(TOP)/binsrc/virtuoso:$(TOP)/binsrc/tests:.:$$PATH" PORT=$(PORT) HOME="$(TOP)" HOST=localhost sh ./make_vad.sh

clean-local:
	-rm -rf vad

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST= \
	bin/tabcontrol2.dll \
	bin/tabcontrol.dll \
	*.css \
	*.html \
	images/*.gif \
	images/*.jpg \
	images/*.png \
	images/tree/*.gif \
	images/tree/*.png \
	intprot/*.css \
	intprot/nn_s_1/*.vsp \
	intprot/nn_s_1/*.xml \
	intprot/nn_s_2/*.vsp \
	intprot/nn_s_2/*.xml \
	intprot/sm_s_1/*.vsp \
	intprot/sm_s_1/*.xml \
	intprot/sm_s_2/*.xml \
	intprot/sm_s_3/*.sql \
	intprot/sm_s_3/*.xml \
	intprot/sm_s_4/*.sql \
	intprot/sm_s_4/*.vsp \
	intprot/sm_s_4/*.xml \
	intprot/sm_s_5/*.sql \
	intprot/sm_s_5/*.vsp \
	intprot/sm_s_5/*.xml \
	intprot/sm_s_6/*.vsp \
	intprot/sm_s_6/*.xml \
	intprot/sm_s_7/*.vsp \
	intprot/sm_s_7/*.xml \
	intprot/*.xml \
	*.js \
	make_vad.sh \
	repl/*.css \
	repl/re_ds_1/*.sql \
	repl/re_ds_1/*.vsp \
	repl/re_ds_1/*.xml \
	repl/re_sb_1/*.sql \
	repl/re_sb_1/*.xml \
	repl/re_sb_2/*.sql \
	repl/re_sb_2/*.xml \
	repl/re_sb_3/*.sql \
	repl/re_sb_3/*.xml \
	repl/re_sb_4/*.sql \
	repl/re_sb_4/*.vsp \
	repl/re_sb_4/*.xml \
	repl/re_sd_1/*.sql \
	repl/re_sd_1/*.xml \
	repl/re_sd_2/*.sql \
	repl/re_sd_2/*.xml \
	repl/re_sd_3/*.sql \
	repl/re_sd_3/*.xml \
	repl/re_sm_1/*.xml \
	repl/re_xb_1/*.sql \
	repl/re_xb_1/*.xml \
	repl/re_xb_2/*.sql \
	repl/re_xb_2/*.xml \
	repl/re_xb_3/*.sql \
	repl/re_xb_3/*.xml \
	repl/re_xb_4/*.sql \
	repl/re_xb_4/*.xml \
	repl/*.xml \
	root_filelist \
	semweb/*.xml \
	*.sql \
	syntax/*.css \
	syntax/*.js \
	*.vsp \
	wap/*.css \
	wap/wa_b_1/*.vsp \
	wap/wa_b_1/*.xml \
	wap/wa_b_1/*.xsl \
	wap/wa_b_2/*.vsp \
	wap/wa_b_2/*.xml \
	wap/wa_b_2/*.xsl \
	wap/wa_b_3/*.sql \
	wap/wa_b_3/*.vsp \
	wap/wa_b_3/*.xml \
	wap/*.xml \
	web/*.css \
	web/*.gif \
	web/vs_b_1/*.sql \
	web/vs_b_1/*.xml \
	web/vs_b_2/*.vsp \
	web/vs_b_2/*.xml \
	web/vs_b_3/*.sql \
	web/vs_b_3/*.vsp \
	web/vs_b_3/*.xml \
	web/vs_b_4/*.vsp \
	web/vs_b_4/*.xml \
	web/vs_b_5/*.html \
	web/vs_b_5/*.vsp \
	web/vs_b_5/*.xml \
	web/vs_b_6/*.vsp \
	web/vs_b_6/*.xml \
	web/vs_b_7/*.sql \
	web/vs_b_7/*.vsp \
	web/vs_b_7/*.xml \
	web/vs_b_8/*.sql \
	web/vs_b_8/*.vsp \
	web/vs_b_8/*.xml \
	web/vs_b_9/*.vsp \
	web/vs_b_9/*.xml \
	web/vs_c_1/*.vsp \
	web/vs_c_1/*.xml \
	web/vs_d_1/*.xml \
	web/vs_d_2/*.vsp \
	web/vs_d_2/*.xml \
	web/vs_d_3/*.sql \
	web/vs_d_3/*.xml \
	web/vs_d_4/*.xml \
	web/vs_d_5/*.vsp \
	web/vs_d_5/*.xml \
	web/vs_d_6/*.vsp \
	web/vs_d_6/*.xml \
	web/vs_d_7/*.sql \
	web/vs_d_7/*.xml \
	web/vs_d_8/*.sql \
	web/vs_d_8/*.vsp \
	web/vs_d_8/*.xml \
	web/vs_r_1/*.sql \
	web/vs_r_1/*.vsp \
	web/vs_r_1/*.xml \
	web/vs_s_1/*.xml \
	web/vs_s_2/*.sql \
	web/vs_s_2/*.vsp \
	web/vs_s_2/*.xml \
	web/vs_s_3/*.sql \
	web/vs_s_3/*.xml \
	web/vs_s_4/*.sql \
	web/vs_s_4/*.xml \
	web/vs_s_5/*.sql \
	web/vs_s_5/*.xml \
	web/vs_s_6/*.sql \
	web/vs_s_6/*.xml \
	web/vs_s_7/*.xml \
	web/vs_u_1/*.xml \
	web/vs_u_2/*.sql \
	web/vs_u_2/*.vsp \
	web/vs_u_2/*.xml \
	web/vs_u_3/*.sql \
	web/vs_u_3/*.vsp \
	web/vs_u_3/*.xml \
	web/vs_u_4/*.sql \
	web/vs_u_4/*.vsp \
	web/vs_u_4/*.xml \
	web/vs_u_5/*.sql \
	web/vs_u_5/*.vsp \
	web/vs_u_5/*.xml \
	web/vs_u_7/*.sql \
	web/vs_u_7/*.vsp \
	web/vs_u_7/*.xml \
	web/vs_x_1/*.vsp \
	web/vs_x_1/*.xml \
	web/vs_x_1/*.xsl \
	web/vs_x_2/*.vsp \
	web/vs_x_2/*.xml \
	web/vs_x_2/*.xsl \
	web/vs_x_3/*.vsp \
	web/vs_x_3/*.xml \
	web/vs_x_3/*.xsl \
	web/vs_xr_1/*.vsp \
	web/vs_xr_1/*.xml \
	web/vs_xr_1/*.xsl \
	web/vs_xr_2/*.vsp \
	web/vs_xr_2/*.xml \
	web/vs_xr_2/*.xsl \
	web/vx_s_10/*.sql \
	web/vx_s_10/*.vspx \
	web/vx_s_10/*.xml \
	web/vx_s_11/*.vspx \
	web/vx_s_11/*.xml \
	web/vx_s_12/*.sql \
	web/vx_s_12/*.vspx \
	web/vx_s_12/*.xml \
	web/vx_s_1/*.vspx \
	web/vx_s_1/*.xml \
	web/vx_s_2/*.vspx \
	web/vx_s_2/*.xml \
	web/vx_s_3/*.sql \
	web/vx_s_3/*.vspx \
	web/vx_s_3/*.xml \
	web/vx_s_4/*.sql \
	web/vx_s_4/*.vspx \
	web/vx_s_4/*.xml \
	web/vx_s_5/*.sql \
	web/vx_s_5/*.vspx \
	web/vx_s_5/*.xml \
	web/vx_s_6/*.sql \
	web/vx_s_6/*.vspx \
	web/vx_s_6/*.xml \
	web/vx_s_7/*.vspx \
	web/vx_s_7/*.xml \
	web/vx_s_8/*.vspx \
	web/vx_s_8/*.xml \
	web/vx_s_8/*.xsl \
	web/vx_s_9/*.sql \
	web/vx_s_9/*.vspx \
	web/vx_s_9/*.xml \
	web/*.xml \
	web2/*.xml \
	*.xml \
	xml/*.css \
	xml/rq_s_1/*.xml \
	xmlapps/*.xml \
	xmlsql/*.css \
	xmlsql/ms_a_1/*.sql \
	xmlsql/ms_a_1/*.xml \
	xmlsql/ms_a_1/*.xsd \
	xmlsql/ms_a_2/*.vsp \
	xmlsql/ms_a_2/*.xml \
	xmlsql/ms_a_3a/*.vsp \
	xmlsql/ms_a_3a/*.xml \
	xmlsql/ms_a_3b/*.vsp \
	xmlsql/ms_a_3b/*.xml \
	xmlsql/ms_a_3/*.vsp \
	xmlsql/ms_a_3/*.xml \
	xmlsql/ms_a_4/*.vsp \
	xmlsql/ms_a_4/*.xml \
	xmlsql/ms_a_5/*.vsp \
	xmlsql/ms_a_5/*.xml \
	xmlsql/*.xml \
	xmlsql/xp_v_1/*.sql \
	xmlsql/xp_v_1/*.xml \
	xmlsql/xp_v_2/*.vsp \
	xmlsql/xp_v_2/*.xml \
	xmlsql/xp_v_3/*.xml \
	xmlsql/*.xsl \
	xmlsql/xs_s_1/*.sql \
	xmlsql/xs_s_1/*.vsp \
	xmlsql/xs_s_1/*.xml \
	xmlsql/xs_s_2/*.sql \
	xmlsql/xs_s_2/*.vsp \
	xmlsql/xs_s_2/*.xml \
	xmlsql/xs_s_3/*.vsp \
	xmlsql/xs_s_3/*.xml \
	xmlsql/xs_s_4/*.vsp \
	xmlsql/xs_s_4/*.xml \
	xmlsql/xs_s_5/*.sql \
	xmlsql/xs_s_5/*.vsp \
	xmlsql/xs_s_5/*.xml \
	xmlsql/xs_s_5/*.xsl \
	xmlsql/xs_s_6/*.vsp \
	xmlsql/xs_s_6/*.xml \
	xmlsql/xs_s_7/*.html \
	xmlsql/xs_s_7/*.vsp \
	xmlsql/xs_s_7/*.xml \
	xmlsql/xs_s_7/*.xsl \
	xmlsql/xs_s_8/*.sql \
	xmlsql/xs_s_8/*.vsp \
	xmlsql/xs_s_8/*.xml \
	xmlsql/xs_s_9/*.sql \
	xmlsql/xs_s_9/*.vsp \
	xmlsql/xs_s_9/*.xml \
	xmlsql/xs_u_1/*.sql \
	xmlsql/xs_u_1/*.vsp \
	xmlsql/xs_u_1/*.xml \
	xmlsql/xs_u_1/*.xsl \
	xmlsql/xs_u_2/*.sql \
	xmlsql/xs_u_2/*.vsp \
	xmlsql/xs_u_2/*.xml \
	xmlsql/xs_u_3/*.html \
	xmlsql/xs_u_3/*.sql \
	xmlsql/xs_u_3/*.xml \
	xmlsql/xs_u_3/*.xsl \
	xml/sx_e_0/*.xml \
	xml/sx_e_1/*.vsp \
	xml/sx_e_1/*.xml \
	xml/sx_e_2/*.vsp \
	xml/sx_e_2/*.xml \
	xml/sx_e_3/*.vsp \
	xml/sx_e_3/*.xml \
	xml/sx_e_4/*.vsp \
	xml/sx_e_4/*.xml \
	xml/sx_e_5/*.vsp \
	xml/sx_e_5/*.xml \
	xml/sx_e_6/*.vsp \
	xml/sx_e_6/*.xml \
	xml/sx_e_7/*.vsp \
	xml/sx_e_7/*.xml \
	xml/sx_e_8/*.vsp \
	xml/sx_e_8/*.xml \
	xml/sx_e_9/*.vsp \
	xml/sx_e_9/*.xml \
	xml/sx_f_1/*.vsp \
	xml/sx_f_1/*.xml \
	xml/sx_g_1/*.vsp \
	xml/sx_g_1/*.xml \
	xml/sx_h_1/*.vsp \
	xml/sx_h_1/*.xml \
	xml/*.xml \
	xml/xq_s_1/*.xml \
	xml/xq_s_2a/*.sql \
	xml/xq_s_2a/*.vsp \
	xml/xq_s_2a/*.xml \
	xml/xq_s_2/*.sql \
	xml/xq_s_2/*.vsp \
	xml/xq_s_2/*.xml \
	xml/xq_s_3/*.sql \
	xml/xq_s_3/*.vsp \
	xml/xq_s_3/*.xml \
	xml/xq_s_4/*.gif \
	xml/xq_s_4/*.png \
	xml/xq_s_4/*.sql \
	xml/xq_s_4/*.vsp \
	xml/xq_s_4/*.xml \
	xml/xq_s_4/*.xsl \
	xml/*.xsl \
	xmlxslt/*.xml \
	xmlxslt/xs_d_1/*.vsp \
	xmlxslt/xs_d_1/*.xml \
	xmlxslt/xs_e_1/*.sql \
	xmlxslt/xs_e_1/*.vsp \
	xmlxslt/xs_e_1/*.xml \
	xmlxslt/xs_e_1/*.xsl \
	xmlxslt/xs_f_1/*.vsp \
	xmlxslt/xs_f_1/*.xml \
	xmlxslt/xs_f_1/*.xsl \
	xmlxslt/xs_f_2/*.vsp \
	xmlxslt/xs_f_2/*.xml \
	xmlxslt/xs_l_1/*.vsp \
	xmlxslt/xs_l_1/*.xml \
	xmlxslt/xs_t_1/*.sql \
	xmlxslt/xs_t_1/*.vsp \
	xmlxslt/xs_t_1/*.xml \
	*.xsl
