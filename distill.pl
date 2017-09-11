#!/bin/perl -Wall

# distill.pl
#
# Create an installation image.
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

do "/etc/imageforge_conf.pl";

do "common.pl";

sub AppendFilesystem
{
    my $fs_size=$_[0];
    my @ret;

    my $cmd="parted ".$config_card_reader." unit s print";
    my @output=`$cmd`;
    my $max_partnum=0;
    my $max_end=0;
    my $size;
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
		    $max_end=substr($f0[2],0,length($f0[2])-1);
		}
	    }
	}
    }
    system "parted ".$config_card_reader." mkpart primary ext4 ".
	($max_end+1)."s ".($fs_size+$max_end+1)."s";
    system "partprobe";
    system "sync";
    system "sleep 10";
    system "mkfs.ext4 -b 4096 -j ".$config_card_reader.($max_partnum+1);

    $ret[0]=$config_card_reader.($max_partnum+1);
    $ret[1]=$fs_size+$max_end+1;

    return @ret;
}


my $USAGE="distill.pl [--list-images] [--list-roots] [output-image boot-image rootfs]";

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

if($ARGV[0] eq "--list-roots") {
    my @filesystems=&GetRootFilesystems();
    for(my $i=0;$i<@filesystems;$i++) {
	if(substr($filesystems[$i],-7) eq "-rootfs") {
	    print $filesystems[$i];
	}
    }
    exit 0;
}
if(@ARGV!=3) {
    print $USAGE;
    exit 256;
}

#
# Check that boot image exists
#
if(!&ImageExists($ARGV[1])) {
    print STDERR "distill.pl: no such image";
    exit 256;
}

#
# Check that root filesystems exists
#
if(!&RootFilesystemExists($ARGV[2])) {
    print STDERR "distill.pl: no such rootfs";
    exit 256;
}

#
# Get filesystem size
#
my $fs_size=int(120*&GetRootFilesystemSize($ARGV[2])/100);

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
# Transfer boot image
#
&WriteImage($config_card_reader,$ARGV[1]);

#
# Append new partition
#
my $newpart_name;
my $final_size;
($newpart_name,$final_size)=&AppendFilesystem($fs_size);

#
# Copy root filesystem
#
printf("Copying filesystem (may take a few minutes)...");
system "mount ".$newpart_name." /mnt";
system "cp -a ".$config_firmware_root."/rootfs/".$ARGV[2]."/* /mnt/";
system "umount ".$newpart_name;
system "sync";
print "done.";

#
# Copy distilled image
#
printf("Distilling final image (may take a few minutes)...");
system "dd if=".$config_card_reader." bs=4M count=".(int($final_size/8192)+1).
    " | xz > ".$config_firmware_root."/images/".$ARGV[0];
print "done.";


print "";
print "Done!";
print "";
exit 0;
