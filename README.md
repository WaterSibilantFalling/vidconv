
# vidconv

vidconv simply runs simple, standard video transcodings. vidconv provides a simple, sane interface to the most common transcoding tasks, something that ffmpeg spectactually fails to do.

vidconv relies on ffmpeg, ffprobe _and_ mediainfo to do its work. 


### execution

```
me > ./vidconv.pl -h

Usage:

vidconv.pl
    [--informat xyz   ]     # which *.xyz files in dir to process
    [-i  inFile.zzz   ]     # transcode a single file

    [--outformat abc  ]     # vids' output format (default: "avi")
    
    [--delayAudio 2.3 ]     # delay or advance ( -2.3s ) the audio
    [ -h              ]     # show this message

This program transcodes videos into other formats, *.avi by default
The formats can be any of: "@OkFormats" 

Either '-i infile.zzz', or '--informat yyy' must be specified. 


```

### using vidconv

vidconv: 

- converts to and from any of the formats handled by ffmpeg: avi, mp4, mkv, mov, divx, wmv, mpeg, and ogm.
- all of the files in a directory of a particular type can be transcoded at once
- alternatively, individual files can be transcoded

Currently, vidconv produces 20 FPS (frame per second) videos accompanied by 100kb/s MP3 sound tracks. 


### Dealing with the sound track

**Handling audio - video desynchronization**

vidconv can detect if the a video's sound track is mis-aligned. If there is audio - video desynchronization, vidconv automatically corrects the mis-alignment during transcoding. Alternativly, if an audio/video offset is specified on the commandline, the user's commandline setting overrides vidconv's autodetection. 


**Selecting the English language soundtrack**

Many videos that 'a friend' downloads from the internet have multiple soundtracks, and quite often the first soundtrack - the track played if no specitic audio track is selected - will be non-English, say Russian. 

vidconv automatically selects the English audiotrack and includes only the English audiotrack in the output file. 




