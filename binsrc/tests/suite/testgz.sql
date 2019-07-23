--
--  $Id: testgz.sql,v 1.3.10.1 2013/01/02 16:15:07 source Exp $
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
ECHO BOTH "STARTED: GZ compression test\n";

create procedure test_gz (in pattern varchar, in ntimes integer)
{
  declare ses any;
  declare compressed,decompressed varchar;
  declare compressed_len, decompressed_len integer;

  result_names (compressed_len, decompressed_len);
  compressed := gz_compress (repeat (pattern, ntimes));
  compressed_len := length (compressed);

  ses := string_output();
  gz_uncompress (compressed, ses);
  compressed := null;
  decompressed := string_output_string (ses);
  decompressed_len := length (decompressed);
  ses := null;
  if (decompressed <> repeat (pattern, ntimes))
    signal ('COMP1', '*** ERROR: decompressed and compressed strings differ');

  result (compressed_len, decompressed_len);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": test_gz defined\n";

create procedure test_gz_stream (in pattern varchar, in ntimes integer)
{
  declare ses, out_ses any;
  declare compressed, decompressed varchar;
  declare compressed_len, decompressed_len integer;

  result_names (compressed_len, decompressed_len);
  ses := string_output ();
  out_ses := string_output ();
  http (repeat (pattern, ntimes), ses);
  string_output_gz_compress (ses, out_ses);
  ses := null;
  compressed := string_output_string (out_ses);
  out_ses := null;
  compressed_len := length (compressed);

  ses := string_output();
  gz_uncompress (compressed, ses);
  compressed := null;
  decompressed := string_output_string (ses);
  decompressed_len := length (decompressed);
  ses := null;
  if (decompressed <> repeat (pattern, ntimes))
    signal ('COMP1', '*** ERROR: decompressed and compressed strings differ');

  result (compressed_len, decompressed_len);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": test_gz_stream defined\n";

test_gz ('1234567890', 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": test_gz (1234567890, 1) Compressed len=" $LAST[1] " Decompressed len=" $LAST[2] "\n";

test_gz ('1234567890', 10);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": test_gz (1234567890, 10) Compressed len=" $LAST[1] " Decompressed len=" $LAST[2] "\n";

test_gz ('1234567890', 100);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": test_gz (1234567890, 100) Compressed len=" $LAST[1] " Decompressed len=" $LAST[2] "\n";

test_gz ('1234567890', 1000);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": test_gz (1234567890, 1000) Compressed len=" $LAST[1] " Decompressed len=" $LAST[2] "\n";

test_gz_stream ('1234567890', 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": test_gz_stream (1234567890, 1) Compressed len=" $LAST[1] " Decompressed len=" $LAST[2] "\n";

test_gz_stream ('1234567890', 10);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": test_gz_stream (1234567890, 10) Compressed len=" $LAST[1] " Decompressed len=" $LAST[2] "\n";

test_gz_stream ('1234567890', 100);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": test_gz_stream (1234567890, 100) Compressed len=" $LAST[1] " Decompressed len=" $LAST[2] "\n";

test_gz_stream ('1234567890', 1000);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": test_gz_stream (1234567890, 1000) Compressed len=" $LAST[1] " Decompressed len=" $LAST[2] "\n";

ECHO BOTH "COMPLETED: GZ compression test\n";
