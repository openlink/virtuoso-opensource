#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2014 OpenLink Software
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
package VIRT::Embed::Persistent;

 my $stdout_ref;
 my $stdin_ref;
 my $stderr_ref;
#use strict;
 our %Cache;
 use Symbol qw(delete_package);

 # static
 sub valid_package_name {
     my($string) = @_;
     $string =~ s/([^A-Za-z0-9\/])/sprintf("_%2x",unpack("C",$1))/eg;
     # second pass only for words starting with a digit
     $string =~ s|/(\d)|sprintf("/_%2x",unpack("C",$1))|eg;

     # Dress it up as a real package name
     $string =~ s|/|::|g;
     return "Embed" . $string;
 }

 sub set_env_vars {
   my $v_options = shift;
   $$stderr_ref->{'html_mode'} = 0;

   if ($$v_options{'__VIRT_CGI'} == '1')
     {
       foreach my $key (keys %$v_options)
	 {
	   if ($key !~ /__VIRT.*/)
	     {
	       my $val = $$v_options{$key};
#	       print STDERR "set_env_vars [$key]=[$val]\n";
	       $ENV{$key} = $val;
	     }
	 }
     }
   else
     {
        $$stdout_ref->{'html_mode'} = 0;
     }
 }

 # static
 sub eval_file {
     my($filename, $delete, $v_options, $v_params, $v_lines) = @_;
     #print STDERR "filename=[$filename] delete=[$delete] v_options=".$v_options." v_params=".$v_params." v_lines=".$v_lines."\n";
     my $package = valid_package_name($filename);
     my $mtime = -M $filename;
     $stdout_ref->text_reset;
     $stderr_ref->text_reset;
     $stdin_ref->setouttext ($v_params);
#    foreach my $xx2 ( keys %$v_options ) 
#       {
#	 print STDERR "key1=[$xx2]\n";
#	 print STDERR "data1=[",$v_options->{$xx2},"]\n";
#       }
     set_env_vars ($v_options);
     if(defined $Cache{$package}{mtime}
        &&
        $Cache{$package}{mtime} <= $mtime)
     {
        # we have compiled this subroutine already,
        # it has not been updated on disk, nothing left to do
        print STDERR "already compiled $package->handler\n";
     }
     else {
        local *FH;
        open FH, $filename or die "open '$filename' $!";
        local($/) = undef;
        my $sub = <FH>;
        close FH;

        #wrap the code into a subroutine inside our unique package
        my $eval = qq{package $package; sub handler { $sub; }};
        {
            # hide our variables within this block
            my($filename,$mtime,$package,$sub);
            eval $eval;
        }
        die $@ if $@;

        #cache it unless we're cleaning out each time
        $Cache{$package}{mtime} = $mtime unless $delete;
     }

     eval {$package->handler;};
     die $@ if ($@ && $@ != '');

     delete_package($package) if $delete;

     return ($stdout_ref->getintext, $stdout_ref->getinhdr, $stderr_ref->getintext);
 }

 # static
 sub eval_string {
     my($filename, $content, $delete, $mtime, $v_options, $v_params, $v_lines) = @_;
     #print STDERR "filename=[$filename] content=[$content] delete=[$delete] mtime=[$mtime] v_options=%v_options v_params=%v_params v_lines=",@v_lines,"\n";
     my $package = valid_package_name($filename);
     #my $mtime = -M $filename;
     $stdout_ref->text_reset;
     $stderr_ref->text_reset;
     $stdin_ref->setouttext ($v_params);
     set_env_vars ($v_options);
     if(0)
     {
        # we have compiled this subroutine already,
        # it has not been updated on disk, nothing left to do
        #print STDERR "already compiled $package->handler\n";
     }
     else {
        local($/) = undef;
        my $sub = $content;
        close FH;

        #wrap the code into a subroutine inside our unique package
        my $eval = qq{package $package; sub handler { $sub; }};
        {
            # hide our variables within this block
            my($filename,$mtime,$package,$sub);
            eval $eval;
        }
        die $@ if $@;

        #cache it unless we're cleaning out each time
        #$Cache{$package}{mtime} = $mtime unless $delete;
     }

     eval {$package->handler;};
     die $@ if ($@ && $@ != '');

     delete_package($package) if $delete;

     return ($stdout_ref->getintext, $stdout_ref->getinhdr, $stderr_ref->getintext);
 }

 # instance:  tie members
 sub TIEHANDLE { 
   #print STDERR "<shout>\n"; 
   my $i = {}; 
   text_reset (\$i);
   bless \$i, shift
 }  

 sub WRITE {
   my($self, $buf,$len,$offset) = @_;
   my $txt = substr (''.$buf, $len, $offset);
   #print STDERR "\n\n\n\n\n\nWRITE:\n";
   $$self->{'inbuffer'} .= $txt;
 }

 sub PRINT { 
   my $self = shift;
   my $txt = join ('', @_);
   #print STDERR "\n\n\n\n\n\nPRINT\n";
   $$self->{'inbuffer'} .= $txt;
 }  
 
 sub PRINTF {
   my $self = shift;
   my $fmt = shift;
   my $txt = sprintf($fmt, @_);
   #print STDERR "\n\n\n\n\n\nPRINTF\n";
   $$self->{'inbuffer'} .= $txt;
 }  
 
sub FILENO {
   my $self = shift;
   return (undef);
}

 sub READ {
   my $self = shift;
   my $bufref = \$_[0];
   my(undef,$len,$offset) = @_;
   unless (defined $offset) { $offset = 0; }
#   print STDERR "READ called, \$buf=$bufref, \$len=$len, \$offset=$offset\n";

   my $out_len = $$self->{'outlen'};
   my $out_ofs = $$self->{'outofs'};
   if ($out_ofs >= $out_len)
     {
       return 0;
     }
   
   my $to_copy = $len;
   if ($len > $out_len - $out_ofs)
     {
       $to_copy = $out_len - $out_ofs;
     }

   my $tail = substr ($$bufref, $offset, $to_copy);
   my $head = substr ($$bufref, 0, $offset);
   my $chunk = substr ($$self->{'outtext'}, $out_ofs, $to_copy);

#   print STDERR "READ will return $to_copy chars\n";
   $$bufref = $tail.$chunk.$tail;
   $$self->{'outofs'} += $to_copy;
   $to_copy;
 }
 
 sub READLINE { 
   my $self = shift; 
   #print STDERR "READLINE called $$self times\n"; 
   die "READLINE unimplemented";
 }  

 sub GETC { 
   my $self = shift; 
   if ($$self->{'outofs'} < $$self->{'outlen'})
     {
       my $ret = substr ($$self->{'outtext'}, $$self->{'outofs'}, $$self->{'outofs'} + 1);
       $$self->{'outofs'} += 1;
       return $ret;
     }

   return; 
 }  

 sub BINMODE {
   my $self = shift; 
 }
 
 sub CLOSE { 
   #print STDERR "CLOSE called.\n" 
 }  
 
 sub DESTROY { 
 }  
  
 sub tie_all {
   $stdout_ref = tie(*STDOUT,'VIRT::Embed::Persistent');
   $stderr_ref = tie(*STDERR,'VIRT::Embed::Persistent');
   $stdin_ref = tie(*STDIN, 'VIRT::Embed::Persistent');
 }

 sub text_reset {
   my $self = shift;
   $$self->{'intext'} = '';
   $$self->{'inbuffer'} = '';
   $$self->{'inhdr'} = '';
   $$self->{'outtext'} = '';
   $$self->{'outofs'} = 0;
   $$self->{'outlen'} = 0;
   $$self->{'html_mode'} = 1;
 }
 
 sub parseintext {
   my $sel = shift;
   my $txt = $$sel->{'inbuffer'};

   if ($$sel->{'html_mode'} == 0)
     {
       $$sel->{'intext'} = $txt;
       $$sel->{'inhdr'} = '';
       return $$sel->{'intext'};
     }

   my $empty_line_idx = index ($txt, "\n\r\n");
   my $len = 3;
   if ($empty_line_idx == -1)
     {
       $empty_line_idx = index $txt, "\n\n";
       $len = 2;
     }
   if ($empty_line_idx == -1)
     {
        $$sel->{'inhdr'} .= '';
        $$sel->{'intext'} .= $txt;
	return $txt;
     }
   else
      {
        $$sel->{'hdrmode'} = 0;
        my $to_hdr = substr ($txt, 0, $empty_line_idx + $len);
        my $to_txt = substr ($txt, $empty_line_idx + $len);
        #print STDERR "vh: adding [$to_hdr] to hdr, [$to_txt] to txt\n";
        $$sel->{'inhdr'} .= $to_hdr;
        $$sel->{'intext'} .= $to_txt;
	return  $$sel->{'intext'};  
      }
 }

 sub getinhdr {
   my $self = shift;
   if ($$self->{'intext'} == '' && $$self->{'inhdr'} == '')
     {
       $self->parseintext;
     }  
   return $$self->{'inhdr'};
 }

 sub getintext {
   my $self = shift;
   if ($$self->{'intext'} == '' && $$self->{'inhdr'} == '')
     {
       $self->parseintext;
     }  
   return $$self->{'intext'};
 }

 sub setouttext {
   my $self = shift;
   $$self->{'outtext'} = shift;
   $$self->{'outofs'} = 0;
   $$self->{'outlen'} = length ($$self->{'outtext'});
 }
 
  my @virt_env;

  sub TIEHASH {
    my $self = shift;
    my $org_hash = shift;
#    print STDERR "TIEHASH\n";

    my $inst = {
      LIST => {}
    };
    $inst->{LIST} = $org_hash;
  }

  sub FETCH {
    my ($self, $key) = @_;
#    print STDERR "FETCH key=[$key]\n";

    return $self->{LIST}->{$key};
  }
    
  sub STORE {
    my ($self, $key, $value) = @_;
#    print STDERR "STORE key=[$key] val=[$value]\n";

    my $mm2 = $self->{LIST};
    my %mm = %$mm2;
    $self->{LIST}->{$key} = $value;
  }
    
  sub DELETE {
    my ($self, $key) = @_;
#    print STDERR "DELETE\n";

    return delete $self->{LIST}->{$key};
  }

  sub CLEAR {
    my $self = shift;
#    print STDERR "CLEAR\n";
    foreach my $key (keys %{$self->{LIST}}) {
      $self->DELETE ($key);
    }
  }

  sub EXISTS {
    my ($self, $key) = @_;
#    print STDERR "EXISTS key=[$key]\n";
    return exists $self->{LIST}->{$key};  
  }

  sub FIRSTKEY {
    my $self = shift;
#    print STDERR "FIRSTKEY\n";
    my $a = keys %{$self->{LIST}};
    each %{$self->{LIST}};
  }

  sub NEXTKEY {
    my ($self, $lastkey) = @_;
#    print STDERR "NEXTKEY\n";
    each %{$self->{LIST}};
  }

  sub exit {
#    print STDERR "EXIT called\n";
    die "";
  }

  @virt_env = {};
  tie %ENV, 'VIRT::Embed::Persistent', @virt_env;
  tie_all ();
  *CORE::GLOBAL::exit = \&VIRT::Embed::Persistent::exit;
1;

__END__
