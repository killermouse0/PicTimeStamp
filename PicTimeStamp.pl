#!/usr/bin/env perl

# Author : Stephane KATTOOR

use strict;
use warnings;

use Image::ExifTool qw(:Public);
use Data::Dumper;
use Getopt::Long;

my $src;
my $dst;
my $rej;

my %inodes;
my %knownTypes = (
	"JPEG"		=> { 'ext' => '.jpg'},
	"3GP"		=> { 'ext' => '.3gp'},
	"MP4"		=> { 'ext' => '.mp4'},
);

GetOptions("src=s" => \$src,
	"dst=s"	=> \$dst,
	"rej=s" => \$rej);

if (not(defined($src) and defined($dst) and defined($rej))) {
	die "Use --src, --dst and --rej to set directories";
}

opendir SRC, $src
	or die "Couldn't open the src directory, killed myself";

FILE: while (readdir(SRC)) {
	my $filename = "$src/".$_;
	my $rejFilename = "$rej/".$_;

	if (not &fileExists($filename)) {
		# not a file
		next FILE;
	}
	my $info = ImageInfo($filename);

	if (not exists($info->{CreateDate})) {
		print "$filename doesn't have a creation date, *sadface*, moving on\n";
	} else {
		if ($info->{CreateDate} =~ /(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})/) {
			my ($year, $month, $day, $hour, $min, $sec) = ($1, $2, $3, $4, $5, $6);
			my $baseName = "$dst/$year-$month-$day $hour.$min.$sec";
			if (exists($knownTypes{$info->{FileType}})) {
				my $ext = $knownTypes{$info->{FileType}}->{'ext'};
				my $newName = $baseName . $ext;
				my $idx = 0;
				while (&fileExists($newName)) {
					if (sameInode($newName, $filename)) {
						# file is already linked, no need to do it
						print $newName, " is already present in target directory\n";
						next FILE;
					}
					$idx++;
					$newName = $baseName . "-$idx$ext";
				}
				link("$filename", $newName)
					or die "$filename : Couldn't link into destination directory as $newName, killed myself";
				next FILE;
			} else {
				print "$filename is of unknown type\n";
			}
		} else {
			print "$filename : Couldn't decode timestamp\n";
		}
	}
	# Can't process the file
	if (fileExists($rejFilename)) {
		if (sameInode($filename, $rejFilename)) {
		# Good, nothing to do
		} else {
			print "$rejFilename already exists but doesn't point to $filename... I'll do nothing !\n";
		}
	} else {
		link("$filename", "$rejFilename")
			or die "$filename : Couldn't link into destination directory as $rejFilename, killed myself";
	}
}

sub sameInode {
	my $file1 = shift;
	my $file2 = shift;

	if (getInode($file1) == getInode($file2)) {
		return 1;
	}
	return 0;
}

sub fileExists {
	my $file = shift;

	if (-f $file) {
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat(_)
			or die "$file : Couldn't stat, killed myself";
		$inodes{$file} = $ino;
		return 1;
	}
	return 0;
}

sub getInode {
	my $file = shift;

	return $inodes{$file} if (exists $inodes{$file});

	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($file)
		or die "$file : Couldn't stat, killed myself";

	$inodes{$file} = $ino;

	return $ino;
}
