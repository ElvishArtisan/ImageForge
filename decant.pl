#!/bin/perl -Wall

# decant.pl
#
# Write a finished firmware image to a card.
#
#   (C) Copyright 2016 Fred Gleason <fredg@paravelsystems.com>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License version 2 as
#   published by the Free Software Foundation.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free Software
#   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#

sub Prompt
{
    my $prompt=$_[0];
    printf("%s (y/N)? ",$prompt);
    my $input=lc(<STDIN>);
    chomp $input;
    return ($input eq "y")||($input eq "yes");
}


sub GetImages
{
    opendir DIR, "firmware/images" or die "cannot open firmware/images: $!";
    my @images=readdir DIR;
    closedir DIR;
    return @images;
}


sub ClearAutomounts
{
    my @output=`df`;
    for(my $i=0;$i<@output;$i++) {
	my @part=split " ",$output[$i];
	if($part[0]=~/$config_card_reader/) {
	    my @args=("umount",$part[0]);
	    system @args;
	}
    }
}


sub ImageExists
{
    my $image=$_[0];
    my @images=&GetImages();
    for(my $i=0;$i<@images;$i++) {
	if($images[$i] eq $image) {
	    return 1;
	}
    }
    return 0;
}


sub WriteImage
{
    my $dest=$_[0];
    my $image=$_[1];

    printf("Writing image (may take a few minutes)...");
    my @args=("xz -cd firmware/images/".$image." | dd of=".$dest." bs=4M");
    system @args;    
    system "sync";
    print "done.";
}


sub ExpandFilesystem
{
#
# Get partition info
#
    my $cmd="parted ".$config_card_reader." unit s print";
    my @output=`$cmd`;
    my $size=0;
    my $max_partnum=0;
    my $max_start=0;
    for(my $i=0;$i<@output;$i++) {
	chomp($output[$i]);
	if($output[$i] ne "") {
	    my @f0=split " ",$output[$i];
	    if((@f0==3)&&($f0[0] eq "Disk")&&($f0[1] eq $config_card_reader.":")) {
		$size=substr($f0[2],0,length($f0[2])-1);
	    }
	    if($f0[0]=~m/\A[0-9]+\Z/) {
		if($f0[0]>$max_partnum) {
		    $max_partnum=$f0[0];
		    $max_start=substr($f0[1],0,length($f0[1])-1);
		}
	    }
	}
    }

#
# Alter partition table
#
    system "parted ".$config_card_reader." rm ".$max_partnum;
    system "parted ".$config_card_reader." mkpart primary ".$max_start."s ".
	($size-1)."s";
    system "partprobe";

#
# Resize filesystem
#
    system "fsck -f ".$config_card_reader.$max_partnum;
    system "resize2fs ".$config_card_reader.$max_partnum;
}


my $USAGE="decant.pl [--list-images] [image-name]";

do "config.pl";

if(@ARGV==0) {
    print $USAGE;
    exit 256;
}

#
# Process Options
#
if($ARGV[0] eq "--list-images") {
    my @images=&GetImages();
    for(my $i=0;$i<@images;$i++) {
	if(substr($images[$i],-3) eq ".xz") {
	    print $images[$i];
	}
    }
    exit 0;
}
if(@ARGV!=1) {
    print $USAGE;
    exit 256;
}

#
# Check that image exists
#
if(!&ImageExists($ARGV[0])) {
    print STDERR "decant.pl: no such image";
    exit 256;
}

#
# Prompt for blank card
#
print "";
print "----------------------------------------------------------";
print " Insert blank card in reader ".$config_card_reader.".";
print " WARNING: This will destroy any existing contents of card!";
print "----------------------------------------------------------";
if(!&Prompt("Proceed")) {
    print "Operation cancelled!";
    exit 0;
}

#
# Undo the work of the "helpful" GNOME automounter
#
&ClearAutomounts();

#
# Transfer image
#
&WriteImage($config_card_reader,$ARGV[0]);

#
# Expand Filesystem
#
&ExpandFilesystem();

print "";
print "Done!";
print "";
exit 0;
