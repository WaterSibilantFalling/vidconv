#!/usr/bin/perl

# This program runs simple, standard video transcodings.
# It provides a simple, sane interface to the most common transcoding tasks,
# something that ffmpeg spectactually fails to do. 
#
# Hack: assumes a single video track, track 1, so that can subtract 
# 		the number of the audio track by 1 (say, 4th - 1 = 3rd audio track)
# Bug:	The "Delay relative to Video" is NOT the audio delay cf the video
# 		It the delay of the start of the audio cf the start of the video in 
# 		order to have no audio - video offset
# TODO:	Supress the selection of an English soundtrack in a multi-soundtrack file



use common::sense;
use IO::All;
use autodie;
use English; 
use charnames           qw< :full >;

my @OkFormats = ("avi", "mp4", "mkv", "mov", "divx", "wmv", "mpeg", "ogm");  

# --- commandline parametes ---

use Getopt::Long qw(:config no_ignore_case bundling);

my $cmdLineDelayOfAudio; 
my $singleInfile ; 
my $showHelp = 0; 
my $informat ; 
my $outformat = "avi"; 

my $okOptions = GetOptions(	
            "delayAudio:f"	=> \$cmdLineDelayOfAudio,	# -conf 	optional string
			"i:s"		    => \$singleInfile,	# -b 		compulsary int
            "h"             => \$showHelp,      # show the usage help
			"informat=s"	=> \$informat,
			"outformat=s"	=> \$outformat,
			);

# --- Useage message

my $shortProgName = `basename $PROGRAM_NAME`;  
chomp $shortProgName; 
my $usageMsg = <<USAGE;

Usage:

$shortProgName
    [--informat xyz   ]     # which *.xyz files in dir to process
    [-i  inFile.zzz   ]     # transcode a single file

    [--outformat abc  ]     # vids' output format (default: "avi")
    
    [--delayAudio 2.3 ]     # delay or advance ( -2.3s ) the audio
    [ -h              ]     # show this message

This program transcodes videos into other formats, *.avi by default
The formats can be any of: "@OkFormats" 

Either '-i infile.zzz', or '--informat yyy' must be specified. 

USAGE

# --- test the commandline input

if ($showHelp) {
    print $usageMsg;
    exit(0);
}
if (! $okOptions) {
    print $usageMsg;
    exit(0);
}
if (!$informat && !$singleInfile){
	print "either --informat or -i/--infile \n"; 
	print $usageMsg;
	exit(1); 
}
if (!$singleInfile) {				# informat
	if (! (grep(/$informat/i,@OkFormats))){
		print "can not process $informat, only @OkFormats\n"; 
		print $usageMsg;
		exit(1);
	}
}
if (! (grep(/$outformat/i,@OkFormats))){
	print "can not produce $informat files, only @OkFormats\n"; 
	print $usageMsg;
	exit(1);
}
# - test that required external programs are present
my $mediainfoPresent = `which mediainfo`; 
chomp $mediainfoPresent; 
if (! -x $mediainfoPresent ){
	print "an executable copy of mediainfo is required\n";
	print $usageMsg; 
	exit (1); 
}
my $ffprobePresent = `which ffprobe`; 
chomp $ffprobePresent; 
if (! -x $ffprobePresent ){
	print "an executable copy of ffprobe is required\n";
	print $usageMsg; 
	exit (1); 
}
# - Bugs: 
# should test that $delayAudio is a number
# should test that the infile exists



my ($outfile, $audiotrackSelector, $videotrackSelector ); 

# file list to transcode
my @infiles; 
if ($singleInfile) {
	@infiles[0] = $singleInfile; 
} else {
	@infiles = io->dir('.')->glob("*.$informat");  
	@infiles = map{ $_->name } @infiles; 
}

foreach my $thisInFile (@infiles){

# identify any sound - video offset
	my $delayOfAudio = 0; 
	if ($cmdLineDelayOfAudio) {
		$delayOfAudio = $cmdLineDelayOfAudio;
	}
	else {
		my @mediainfoResults = `/usr/bin/mediainfo $thisInFile `; 
		chomp @mediainfoResults; 
		# read a block - ends at an empty line
		my ($englishLine, $delayedLine); 

		foreach my $line (@mediainfoResults){
			chomp $line; 
			$englishLine	= $line
				if ($line =~ /Language\s*: English/);
			$delayedLine	= $line
				if ($line =~ /Delay relative to video/); 
		# at end-of-block : and empty line. Is there are delay noted? 
			if (0 == length($line)) {
				if (($englishLine) && ($delayedLine)) {
					$delayedLine =~ /: (\d*) s (\d*) ms/; 
					$delayOfAudio = $1 + 0.00 + $2/1000;  	
				} else {
					$delayedLine = $englishLine = (); 
				}
			}
		}
	}
	# because need two input files to delay the audio
	my $audioInputFile = $delayOfAudio?1:0; 
	
# identify the english audiotrack
	my @ffprobeData = `/usr/bin/ffprobe $thisInFile 2>&1 `; 
	chomp @ffprobeData; 
	my ($audioline) = grep (/Stream.+\(eng\).+Audio/,@ffprobeData);
	chomp $audioline; 
	my $audiotrack = "a"; 
	if ($audioline) {		# a special "eng" audio line was found
		$audioline =~ /0:(\d)/; 
		$audiotrack = $1 ;		
	}
	$videotrackSelector = "0:0:v"; 	# assume one video track
	$audiotrackSelector = ($audiotrack eq "a") 
						? "$audioInputFile:a" : "$audioInputFile:$audiotrack:a";  


# outfile name
	my $outfile = ($thisInFile =~ s/\.*$/\.avi/r); 
	`rm -f $outfile`; 

	# subcommand for delaying the audio
	# adds the audio as a second copy of the infile
	# itsoffset has to be before the file it refers to
	# HACK - delay to 1 sec
	my $delayAudioCmd 	= 	($delayOfAudio) 
						? 	" -itsoffset $delayOfAudio -i \"$thisInFile\"  "
						:	"  "; 
	
# do transcoding
	my $cmd =" "
	. " /usr/bin/nice -n 20 /usr/bin/ffmpeg -i \"$thisInFile\" "
	. $delayAudioCmd  
	. " -map $videotrackSelector  -map $audiotrackSelector "
	. " -f $outformat -max_muxing_queue_size 4000  "
	. " -filter:v fps=20  -r 20 -c:v libxvid -b:v 2000k "
	. " -vtag xvid "
	. " -c:a  libmp3lame -b:a 100k "
	. " -loglevel error "
	. " \"$outfile\" "; 


	print "\n".`date`;
	print $cmd."\n";
	my $errorVals = `$cmd 2>&1`; 
	print "cmd output: $errorVals \n";  
	print `date`."\n";
	
	sleep 10 ; 

}

#    -g 300 -bf 2 -map 0:m:language:eng? \
# 




