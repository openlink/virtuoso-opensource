/*
 *  $Id$
 *
 *  Tag definitions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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
 */

/* header tags */
#define tag_ID3v22 0x49443302 /*'ID3\x02'*/
#define tag_ID3v23 0x49443303 /*'ID3\x03'*/
#define tag_ID3v24 0x49443304 /*'ID3\x04'*/

/* ID3v2.2 tags */
#define tag_COM 0x00434F4D /*'COM'*/
#define tag_IPL 0x0049504C /*'IPL'*/
#define tag_TAL 0x0054414C /*'TAL'*/
#define tag_TBP 0x00544250 /*'TBP'*/
#define tag_TCM 0x0054434D /*'TCM'*/
#define tag_TCO 0x0054434F /*'TCO'*/
#define tag_TCP 0x00544350 /*'TCP'*/
#define tag_TCR 0x00544352 /*'TCR'*/
#define tag_TDA 0x00544441 /*'TDA'*/
#define tag_TDY 0x00544459 /*'TDY'*/
#define tag_TEN 0x0054454E /*'TEN'*/
#define tag_TFT 0x00544654 /*'TFT'*/
#define tag_TIM 0x0054494D /*'TIM'*/
#define tag_TKE 0x00544B45 /*'TKE'*/
#define tag_TLA 0x00544C41 /*'TLA'*/
#define tag_TLE 0x00544C45 /*'TLE'*/
#define tag_TMT 0x00544D54 /*'TMT'*/
#define tag_TOA 0x00544F41 /*'TOA'*/
#define tag_TOF 0x00544F46 /*'TOF'*/
#define tag_TOL 0x00544F4C /*'TOL'*/
#define tag_TOR 0x00544F52 /*'TOR'*/
#define tag_TOT 0x00544F54 /*'TOT'*/
#define tag_TP1 0x00545031 /*'TP1'*/
#define tag_TP2 0x00545032 /*'TP2'*/
#define tag_TP3 0x00545033 /*'TP3'*/
#define tag_TP4 0x00545034 /*'TP4'*/
#define tag_TPA 0x00545041 /*'TPA'*/
#define tag_TPB 0x00545042 /*'TPB'*/
#define tag_TRC 0x00545243 /*'TRC'*/
#define tag_TRD 0x00545244 /*'TRD'*/
#define tag_TRK 0x0054524B /*'TRK'*/
#define tag_TSI 0x00545349 /*'TSI'*/
#define tag_TSS 0x00545353 /*'TSS'*/
#define tag_TT1 0x00545431 /*'TT1'*/
#define tag_TT2 0x00545432 /*'TT2'*/
#define tag_TT3 0x00545433 /*'TT3'*/
#define tag_TXT 0x00545854 /*'TXT'*/
#define tag_TXX 0x00545858 /*'TXX'*/
#define tag_TYE 0x00545945 /*'TYE'*/
#define tag_ULT 0x00554C54 /*'ULT'*/
#define tag_WAF 0x00574146 /*'WAF'*/
#define tag_WAR 0x00574152 /*'WAR'*/
#define tag_WAS 0x00574153 /*'WAS'*/
#define tag_WCM 0x0057434D /*'WCM'*/
#define tag_WCP 0x00574350 /*'WCP'*/
#define tag_WPB 0x00575042 /*'WPB'*/

/* not used currently */
#define tag_BUF 0x00425546 /*'BUF'*/
#define tag_CNT 0x00434E54 /*'CNT'*/
#define tag_CRA 0x00435241 /*'CRA'*/
#define tag_ETC 0x00455443 /*'ETC'*/
#define tag_EQU 0x00455155 /*'EQU'*/
#define tag_GEO 0x0047454F /*'GEO'*/
#define tag_LNK 0x004C4E4B /*'LNK'*/
#define tag_MCI 0x004D4349 /*'MCI'*/
#define tag_MLL 0x004D4C4C /*'MLL'*/
#define tag_PIC 0x00504943 /*'PIC'*/
#define tag_POP 0x00504F50 /*'POP'*/
#define tag_REV 0x00524556 /*'REV'*/
#define tag_RVA 0x00525641 /*'RVA'*/
#define tag_SLT 0x00534C54 /*'SLT'*/
#define tag_STC 0x00535443 /*'STC'*/
#define tag_UFI 0x00554649 /*'UFI'*/

/* ID3v2.3 and ID3v2.4 tags */
#define tag_COMM 0x434F4D4D /*'COMM'*/
#define tag_TALB 0x54414C42 /*'TALB'*/
#define tag_TBPM 0x5442504D /*'TBPM'*/
#define tag_TCMP 0x54434D50 /*'TCMP'*/
#define tag_TCOM 0x54434F4D /*'TCOM'*/
#define tag_TCON 0x54434F4E /*'TCON'*/
#define tag_TCOP 0x54434F50 /*'TCOP'*/
#define tag_TDAT 0x54444154 /*'TDAT'*/
#define tag_TDEN 0x5444454E /*'TDEN'*/
#define tag_TDLY 0x54444C59 /*'TDLY'*/
#define tag_TDOR 0x54444F52 /*'TDOR'*/
#define tag_TDRC 0x54445243 /*'TDRC'*/
#define tag_TDRL 0x5444524C /*'TDRL'*/
#define tag_TDTG 0x54445447 /*'TDTG'*/
#define tag_TENC 0x54454E43 /*'TENC'*/
#define tag_TEXT 0x54455854 /*'TEXT'*/
#define tag_TFLT 0x54464C54 /*'TFLT'*/
#define tag_TIME 0x54494D45 /*'TIME'*/
#define tag_TIPL 0x5449504C /*'TIPL'*/
#define tag_TIT1 0x54495431 /*'TIT1'*/
#define tag_TIT2 0x54495432 /*'TIT2'*/
#define tag_TIT3 0x54495433 /*'TIT3'*/
#define tag_TKEY 0x544B4559 /*'TKEY'*/
#define tag_TLAN 0x544C414E /*'TLAN'*/
#define tag_TLEN 0x544C454E /*'TLEN'*/
#define tag_TMCL 0x544D434C /*'TMCL'*/
#define tag_TMED 0x544D4544 /*'TMED'*/
#define tag_TMOO 0x544D4F4F /*'TMOO'*/
#define tag_TOAL 0x544F414C /*'TOAL'*/
#define tag_TOFN 0x544F464E /*'TOFN'*/
#define tag_TOLY 0x544F4C59 /*'TOLY'*/
#define tag_TOPE 0x544F5045 /*'TOPE'*/
#define tag_TORY 0x544F5259 /*'TORY'*/
#define tag_TOWN 0x544F574E /*'TOWN'*/
#define tag_TPE1 0x54504531 /*'TPE1'*/
#define tag_TPE2 0x54504532 /*'TPE2'*/
#define tag_TPE3 0x54504533 /*'TPE3'*/
#define tag_TPE4 0x54504534 /*'TPE4'*/
#define tag_TPOS 0x54504F53 /*'TPOS'*/
#define tag_TPRO 0x5450524F /*'TPRO'*/
#define tag_TPUB 0x54505542 /*'TPUB'*/
#define tag_TRCK 0x5452434B /*'TRCK'*/
#define tag_TRDA 0x54524441 /*'TRDA'*/
#define tag_TRSN 0x5452534E /*'TRSN'*/
#define tag_TRSO 0x5452534F /*'TRSO'*/
#define tag_TSIZ 0x5453495A /*'TSIZ'*/
#define tag_TSOA 0x54534F41 /*'TSOA'*/
#define tag_TSOP 0x54534F50 /*'TSOP'*/
#define tag_TSOT 0x54534F54 /*'TSOT'*/
#define tag_TSRC 0x54535243 /*'TSRC'*/
#define tag_TSSE 0x54535345 /*'TSSE'*/
#define tag_TSST 0x54535354 /*'TSST'*/
#define tag_TXXX 0x54585858 /*'TXXX'*/
#define tag_TYER 0x54594552 /*'TYER'*/
#define tag_USLT 0x55534C54 /*'USLT'*/
#define tag_WCOM 0x57434F4D /*'WCOM'*/
#define tag_WCOP 0x57434F50 /*'WCOP'*/
#define tag_WOAF 0x574F4146 /*'WOAF'*/
#define tag_WOAR 0x574F4152 /*'WOAR'*/
#define tag_WOAS 0x574F4153 /*'WOAS'*/
#define tag_WORS 0x574F5253 /*'WORS'*/
#define tag_WPAY 0x57504159 /*'WPAY'*/
#define tag_WPUB 0x57505542 /*'WPUB'*/
#define tag_WXXX 0x57585858 /*'WXXX'*/

/* not used currently */
#define tag_AENC 0x41454E43 /*'AENC'*/
#define tag_APIC 0x41504943 /*'APIC'*/
#define tag_ASPI 0x41535049 /*'ASPI'*/
#define tag_COMR 0x434F4D52 /*'COMR'*/
#define tag_ENCR 0x454E4352 /*'ENCR'*/
#define tag_EQU2 0x45515532 /*'EQU2'*/
#define tag_EQUA 0x45515541 /*'EQUA'*/
#define tag_ETCO 0x4554434F /*'ETCO'*/
#define tag_GEOB 0x47454F42 /*'GEOB'*/
#define tag_GRID 0x47524944 /*'GRID'*/
#define tag_IPLS 0x49504C53 /*'IPLS'*/
#define tag_LINK 0x4C494E4B /*'LINK'*/
#define tag_MCDI 0x4D434449 /*'MCDI'*/
#define tag_MLLT 0x4D4C4C54 /*'MLLT'*/
#define tag_OWNE 0x4F574E45 /*'OWNE'*/
#define tag_PCNT 0x50434E54 /*'PCNT'*/
#define tag_POPM 0x504F504D /*'POPM'*/
#define tag_POSS 0x504F5353 /*'POSS'*/
#define tag_PRIV 0x50524956 /*'PRIV'*/
#define tag_RBUF 0x52425546 /*'RBUF'*/
#define tag_RVA2 0x52564132 /*'RVA2'*/
#define tag_RVAD 0x52564144 /*'RVAD'*/
#define tag_RVRB 0x52565242 /*'RVRB'*/
#define tag_SEEK 0x5345454B /*'SEEK'*/
#define tag_SIGN 0x5349474E /*'SIGN'*/
#define tag_SYLT 0x53594C54 /*'SYLT'*/
#define tag_SYTC 0x53595443 /*'SYTC'*/
#define tag_UFID 0x55464944 /*'UFID'*/
#define tag_USER 0x55534552 /*'USER'*/

/* some mp4 tags */
#define tag_CART 0xA9415254 /*'\251ART'*/
#define tag_Calb 0xA9616C62 /*'\251alb'*/
#define tag_Cday 0xA9646179 /*'\251day'*/
#define tag_Ctoo 0xA9746F6F /*'\251too'*/
#define tag_Ccmt 0xA9636D74 /*'\251cmt'*/
#define tag_Ccpy 0xA9637079 /*'\251cpy'*/
#define tag_Cdes 0xA9646573 /*'\251des'*/
#define tag_Cgen 0xA967656E /*'\251gen'*/
#define tag_Cgrp 0xA9677270 /*'\251grp'*/
#define tag_Cnam 0xA96E616D /*'\251nam'*/
#define tag_Cprd 0xA9707264 /*'\251prd'*/
#define tag_Cwrt 0xA9777274 /*'\251wrt'*/
#define tag_Clyr 0xA96C7972 /*'\251lyr'*/
#define tag_aART 0x61415254 /*'aART'*/
#define tag_covr 0x636F7672 /*'covr'*/
#define tag_cpil 0x6370696C /*'cpil'*/
#define tag_cprt 0x63707274 /*'cprt'*/
#define tag_data 0x64617461 /*'data'*/
#define tag_disk 0x6469736B /*'disk'*/
#define tag_ftyp 0x66747970 /*'ftyp'*/
#define tag_gnre 0x676E7265 /*'gnre'*/
#define tag_hdlr 0x68646C72 /*'hdlr'*/
#define tag_ilst 0x696C7374 /*'ilst'*/
#define tag_mdia 0x6D646961 /*'mdia'*/
#define tag_meta 0x6D657461 /*'meta'*/
#define tag_moov 0x6D6F6F76 /*'moov'*/
#define tag_root 0x726F6F74 /*'root'*/
#define tag_rtng 0x72746E67 /*'rtng'*/
#define tag_tmpo 0x746D706F /*'tmpo'*/
#define tag_trkn 0x74726B6E /*'trkn'*/
#define tag_udta 0x75647461 /*'udta'*/
#define tag_apID 0x61704944 /*'apID'*/

/* ogg */
#define tag_OggS 0x4F676753 /*'OggS'*/

/* FLAC */
#define tag_fLaC 0x664C6143 /*'fLaC'*/
