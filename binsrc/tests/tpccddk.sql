--
--  tpccddk.sql
--
--  $Id$
--
--  TPC-C Benchmark
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
--

-- use tpcc;

create table warehouse (
    w_id		integer,
    w_name		character (10),
    w_street_1		character (20),
    w_street_2		character (20),
    w_city		character (20),
    w_state		character (2),
    w_zip		character (9),
    w_tax		numeric (4,2),
    w_ytd		numeric,
    primary key (w_id)
)
alter index WAREHOUSE on WAREHOUSE partition (W_ID int);


create table district (
    d_id		integer,
    d_w_id		integer,
    d_name		character (10),
    d_street_1		character (20),
    d_street_2		character (20),
    d_city		character (20),
    d_state		character (2),
    d_zip		character (9),
    d_tax		numeric (4,2),
    d_ytd		numeric,
    d_next_o_id		integer,
    primary key (d_w_id, d_id)
)
alter index DISTRICT on DISTRICT partition (D_W_ID int);

create table customer (
    c_id		integer,
    c_d_id		integer,
    c_w_id		integer,
    c_first		character (16),
    c_middle		character (2),
    c_last		varchar,
    c_street_1		character (20),
    c_street_2		character (20),
    c_city		character (20),
    c_state		character (2),
    c_zip		character (9),
    c_phone		character (16),
    c_since		datetime,
    c_credit		character (2),
    c_credit_lim	numeric,
    c_discount		numeric,
    c_balance		numeric,
    c_ytd_payment	numeric,
    c_cnt_payment	integer ,
    c_cnt_delivery	integer ,
    c_data_1		character (250),
    c_data_2		character (250),
    primary key (c_w_id, c_d_id, c_id)
)
alter index CUSTOMER on CUSTOMER partition (C_W_ID int);

create index c_by_last on customer (c_w_id, c_d_id, c_last, c_first) partition (C_W_ID int);

create table history (
    h_c_id		integer,
    h_c_d_id		integer,
    h_c_w_id		integer,
    h_d_id		integer,
    h_w_id		integer,
    h_date		datetime,
    h_amount		numeric,
    h_data		character (24)
)
alter index HISTORY on HISTORY partition (H_W_ID int);

create table new_order (
    no_o_id		integer,
    no_d_id		integer,
    no_w_id		integer,
    primary key (no_w_id, no_d_id, no_o_id)
)
alter index NEW_ORDER on NEW_ORDER partition (NO_W_ID int);

create table orders (
    o_id		integer,
    o_d_id		integer,
    o_w_id		integer,
    o_c_id		integer ,
    o_entry_d		date,
    o_carrier_id	integer  ,
    o_ol_cnt		integer  ,
    o_all_local		integer  ,
    primary key (o_w_id, o_d_id, o_id)
)
alter index ORDERS on ORDERS partition (O_W_ID int);

create index o_by_c_id on orders (o_w_id, o_d_id, o_c_id, o_id) partition (O_W_ID int);

create table order_line (
    ol_o_id		integer,
    ol_d_id		integer,
    ol_w_id		integer,
    ol_number		integer,
    ol_i_id		integer,
    ol_supply_w_id	integer,
    ol_delivery_d	date,
    ol_quantity		integer,
    ol_amount		numeric,
    ol_dist_info	character (24),
    primary key (ol_w_id, ol_d_id, ol_o_id, ol_number)
)
alter index ORDER_LINE on ORDER_LINE partition (OL_W_ID int);

create table item (
    i_id		integer,
    i_im_id		integer,
    i_name		character (24),
    i_price		numeric,
    i_data		character (50),
    primary key (i_id)
)
alter index ITEM on ITEM partition cluster replicated;

create table stock (
    s_i_id		integer,
    s_w_id		integer,
    s_quantity		integer ,
    s_dist_01		character (24),
    s_dist_02		character (24),
    s_dist_03		character (24),
    s_dist_04		character (24),
    s_dist_05		character (24),
    s_dist_06		character (24),
    s_dist_07		character (24),
    s_dist_08		character (24),
    s_dist_09		character (24),
    s_dist_10		character (24),
    s_ytd		numeric,
    s_cnt_order		integer  ,
    s_cnt_remote	integer  ,
    s_data		character (50),
    primary key (s_i_id, s_w_id)
)
alter index STOCK on STOCK partition (S_W_ID int);

