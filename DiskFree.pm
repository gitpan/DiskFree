#
#
#
# Copyright (c) 1998 Alan R. Barclay. All rights reserved. This program
# is free software; you can redistribute it and/or modify it under
# the same terms as Perl itself.

package Filesystem::DiskFree;

use Carp;
use strict;

#qw();

use vars qw($VERSION $Format %Df);

$VERSION = 0.01;

%Df = (
    'linux' => {
	'blocks' => "df -P",
	'inodes' => "df -Pi",
	'format' => "svish",
    },
    'solaris' =>  {
	'blocks' => "df -k",
	'inodes' => "df -ki",
	'format' => "svish",
    },
    'bsdos' => {
	'blocks' => "df -i",
	'inodes' => "df -i",
	'format' => 'bsdish',
    }
);

use strict;

BEGIN    {
    $Format = $^O;
}

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {
    	FORMAT       => $Format,
    	DEVICES	     => undef,
    	MOUNTS	     => undef,
    	MODE	     => 'blocks'
    };

    bless ($self, $class);
    return $self;
}

sub set(){
    my $self=shift;
    my @return;

    return undef if(defined $self->{'DEVICES'});

    if(@_){
	if($_[0] =~ m/format/i){
	    push(@return,$self->{'FORMAT'});
	    $self->{'FORMAT'}=$_[1] if(defined $_[1]);
	}

	if($_[0] =~ m/mode/i){
	    push(@return,$self->{'MODE'});
	    $self->{'MODE'}='blocks' if($_[1] =~ m/block/i and defined $_[1]);
	    $self->{'MODE'}='inodes' if($_[1] =~ m/inode/i and defined $_[1]);
	}
    }
    return @return;
}

sub command () {
	my $self=shift;
	return $Df{"\L".$self->{'FORMAT'}."\E"}{$self->{'MODE'}};
}
sub df(){
    my $self=shift;
    my $cmd="df";
    
    $cmd=$self->command() or
    	croak "No df command known for format ".$self->{'FORMAT'};
    open(HANDLE,"$cmd|") or croak("Cannot fork $!");
    return $self->load(\*HANDLE);
    close(HANDLE) or croak("Cannot df $!");
}

sub load()  {
    my $self=shift;
    my $handle=shift;

    if(ref $handle eq "GLOB"){
    	while(<$handle>){
    		$self->readline($_);
    	}
    } else {
    	map { $self->readline($_) } split(/$\//,$handle);
    }
    return 'true';
}

sub readline() {
    my $self=shift;
    my $line=shift;
    my ($device,$btotal,$bused,$bavail,$iused,$iavail,$mount,
	$total,$used,$avail);

    chomp($line);

    $_=$Df{"\L".$self->{'FORMAT'}."\E"}{'format'};

    if(/svish/i){
    	return undef if($line =~ /^Filesystem.*Mounted on/i);
    	($device,$total,$used,$avail,undef,$mount)=split(' ',$line);
	if($self->{'MODE'} eq 'blocks'){
		$total *= 1024;
		$used *= 1024;
		$avail *= 1024;
	}
    } elsif(/bsdish/){
    	return undef if($line =~ /^Filesystem.*Mounted on/i);
    	($device,$btotal,$bused,$bavail,undef,$iused,$iavail,undef,$mount)=
		split(' ',$line);
	if($self->{'MODE'} eq 'blocks'){
		$total=$btotal*512;
		$used=$bused*512;
		$avail=$bavail*512;
	} elsif($self->{'MODE'} eq 'inodes'){
		$total=undef;
		$used=$iused*512;
		$avail=$iavail*512;
	}
    } else {
    	croak "Unknown encoding ".$Df{"\L".$self->{'FORMAT'}."\E"}{'format'}.
    	      " for format ".$self->{'FORMAT'};
    }
    $self->{'MOUNTS'}{$mount}=$device;
    $self->{'DEVICES'}{$device}={};
    $self->{'DEVICES'}{$device}{'device'}=$device;
    $self->{'DEVICES'}{$device}{'total'} =$total;
    $self->{'DEVICES'}{$device}{'used'}  =$used;
    $self->{'DEVICES'}{$device}{'avail'} =$avail;
    $self->{'DEVICES'}{$device}{'mount'} =$mount;
}

sub device() { return extract(@_,'device'); }
sub total()  { return extract(@_,'total');  }
sub used()   { return extract(@_,'used');   }
sub avail()  { return extract(@_,'avail');  }
sub mount()  { return extract(@_,'mount');  }

sub extract () {
    my $self=shift;
    my $device;
    if(@_) {
	my $thingy=shift;
	if(defined($self->{'DEVICES'}{$thingy})){
	    $device=$thingy;
	} else {
	    return undef unless(defined($self->{'MOUNTS'}));
	    while(not defined($self->{'MOUNTS'}{$thingy})){
		return undef if($thingy eq '/');
		$thingy =~ s!/[^/]*?$!!  unless($thingy =~ s!/$!!);
		$thingy = "/" if($thingy eq "");
	    }
	    $device=$self->{'MOUNTS'}{$thingy}
	}
    	return $self->{'DEVICES'}{$device}{$_[0]};
    }
    return undef;
}

sub disks () {
	my $self=shift;
	return undef unless(defined($self->{'MOUNTS'}));
	return keys %{$self->{'MOUNTS'}};
}

1;
__END__


=head1 NAME

Filesystem::DiskFree -- perform the Unix command 'df' in a portable fashion

=head1 SYNOPSIS

    use Filesystem::DiskFree;

    $handle = new Disk:Free;
    $handle->df();
    print "The root device is ".$handle->device("/")."\n";
    print "It has ".$handle->avail("/")." bytes available\n";
    print "It has ".$handle->total("/")." bytes total\n";
    print "It has ".$handle->used("/")." bytes used\n";

=head1 DESCRIPTION

Filesystem::DiskFree does about what the unix command df(1) does, listing
the mounted disks, and the amount of free space used & available.

=head2 Functions

=over 4

=item Filesystem::DiskFree->set('option' => 'value')

Sets various options within the module.

The most common option to change is the mode, which can be either
blocks or inodes. By default, blocks is used.

If reading a file from a 'foreign' OS using the load() function,
format may be used, which takes the name of an OS as set in the $^O
variable.

Returns the previous values of the options.

=item Filesystem::DiskFree->df()

Perfoms a 'df' command, and stores the values for later use.

=item Filesystem::DiskFree->command()

Returns the appropriate command to do a 'df' command, for the current
format.  This is used when you wish to call a df on a remote system.
Use the df() method for local df's.

Returns undef if there isn't an appropriate command.

=item Filesystem::DiskFree->load($line)

Reads in the output of a 'df', $line can be either a scalar or a filehandle.
If $line is a filehandle, then the filehandle is read until EOF. 

Returns undef on failure

=item Filesystem::DiskFree->disks()

Returns all the disks known about

=item Filesystem::DiskFree->device($id)

Returns the device for $id, which is a scalar containing the device name of
a disk or a filename, in which case the disk that filename in stored upon
is used.

=item Filesystem::DiskFree->mount($id)

Returns the mount point for $id, which is a scalar containing the device
name of a disk or a filename, in which case the disk that filename in
stored upon is used.

=item Filesystem::DiskFree->avail($id)

Returns the amount of available space in bytes for $id, which is a scalar
containing the device name of a disk or a filename, in which case the
disk that filename in stored upon is used.

=item Filesystem::DiskFree->total($id)

Returns the amount of total space in bytes for $id, which is a scalar
containing the device name of a disk or a filename, in which case the
disk that filename in stored upon is used.

=item Filesystem::DiskFree->used($id)

Returns the amount of used space in bytes for $id, which is a scalar
containing the device name of a disk or a filename, in which case the
disk that filename in stored upon is used.

=head1 BUGS

It should support more formats, currently only Linux, Solaris & BSD
are supported. Other formats will be added as available. Please
sent the 'best' df options to use, and the output of df with those
options, and the contents of $^O if you have access to a non-supported
format.

=head1 AUTHOR

Alan R. Barclay <gorilla@drink.com>
