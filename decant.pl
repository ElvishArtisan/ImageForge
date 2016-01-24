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

do "common.pl";
do "config.pl";

my $USAGE="decant.pl [--list-images] [image-name]";

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
