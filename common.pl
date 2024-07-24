#!/bin/perl -W

# common.pl
#
# Common utility functions for the ImageForge system.
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


sub GetRootFilesystems
{
    opendir DIR, $config_firmware_root."/rootfs" or 
	die "cannot open ".$config_firmware_root."/rootfs:"." $!";
    my @filesystems=readdir DIR;
    closedir DIR;
    return @filesystems;
}


sub RootFilesystemExists
{
    my $filesystem=$_[0];
    my @filesystems=&GetRootFilesystems();
    for(my $i=0;$i<@filesystems;$i++) {
	if($filesystems[$i] eq $filesystem) {
	    return 1;
	}
    }
    return 0;
}


sub GetRootFilesystemSize
{
    $fs_name=$_[0];

    my $cmd="du -s --block-size 512 ".$config_firmware_root."/rootfs/".$fs_name;
    my @f0=split " ",`$cmd`;

    return $f0[0];
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


sub GetImages
{
    opendir DIR, $config_firmware_root."/images" or
	die "cannot open ".$config_firmware_root."/images: $!";
    my @images=readdir DIR;
    closedir DIR;
    return @images;
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
    my @args=("xz -cd ".$config_firmware_root."/images/".$image.
	      " | dd of=".$dest." bs=4M");
    system @args;    
    system "sync";
    system "partprobe";
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
