#!/bin/bash

# check for mkvextract
command -v mkvextract >/dev/null 2>&1 || { echo >&2 "Requires mkvextract. Aborting."; exit; }

POSITIONAL=();
while [[ $# -gt 0 ]]
do
	key="$1";
	case $key in
		-d|--directory)
			DIRECTORY="$2";
			shift;
			shift;
			;;
		-f|--file)
			FILE="$2";
			shift;
			shift;
			;;
		-t|--track)
			TRACK="$2";
			shift;
			shift;
			;;
		-w|--word)
			WORD="$2";
			shift;
			shift;
			;;
		-m|--merge)
			MERGE=1;
			shift;
			shift;
			;;
	esac
done
set -- "{$POSITIONAL[@]}";

# check if out directory exists
# TODO handle case out exists but other subdirs don't
if [ ! -d "out" ]; then
	echo "making out directory..";
	mkdir out;
	mkdir out/clips;
fi

if ! [[ -z $FILE || -z $DIRECTORY ]]; then
	echo "You have both -d and -f set.. choose one, not both..";
	exit;
fi

if [[ -z $FILE && -z $DIRECTORY ]]; then
	echo "no file or directory provided (use -f [file] or -d [dir])..";
	exit;
fi

if [ -z "$TRACK" ]; then
	#assume subtitle track = 2
	echo "track not set (use -t [truck number]). You kind find the subtitle track number using 'mkvinfo [file]'..";
	exit;
fi

if [ -z "$WORD" ]; then
	echo "no word set, using default word (use -w [word] to set the word)..";
	WORD="idiot"; # baka~
fi

if ! [ -z "$FILE" ]; then
	#echo "using single file..";
	SINGLEFILE=true;
fi

if ! [ -z "$DIRECTORY" ]; then
	#echo "using directory";
	SINGLEFILE=false;
fi

# we're done the boring stuff

x=0;

function getsubs
{
	# $1 = file
	#echo "getting subs for "$1"";
	rm out/subs.srt;
	CFILE=$(basename "$1" .mkv);
	#echo "CFILE is "$CFILE"";
	#echo "extracting subs from $1 track ${TRACK} to out/subs.srt";
	mkvextract tracks "$1" ${TRACK}:out/subs.srt;
	grepsubs "$1" "$CFILE";
}

function grepsubs
{
	# $1 = file $2 = CFILE
	while read -r line; do
		((x++));
		#echo "line in grep ${line}";
		#parselinie $x "$1" $line;
		parseline "$1" "$line" "$2";
	done < <(grep "$WORD" out/subs.srt);
}

function parseline
{

	# $1 = file $2 = line $3 = CFILE
	IFS=',' read -r -a array <<< "$2";
	echo "start time: ${array[1]}";
	echo "end time: ${array[2]}";
	cutvideo "$1" "${array[1]}" "${array[2]}" "$3";
}

function cutvideo
{
	# $1 = file $2 = start time $3 = end time $4 = CFILE
	ffmpeg -i "$1" -ss 0"$2" -to 0"$3" -async 1 -c:v libx264 -preset ultrafast out/clips/clip_"$x"_"$4".mkv < /dev/null
}

function merge
{
	echo "merging mkv's..";
	str=();
	x=0;
	for f in out/clips/*.mkv; do
		if [ $x == 0 ]; then
			str+=""$f"";
		fi
		if [ $x != 0 ]; then
			str+=" +"$f"";
		fi
		((x++));
	done;
	mkvmerge $str -o out/out.mkv
}

# getsubs function will run the chain that does the whole process

if ! [ -z "$MERGE" ]; then
	merge;
	exit;
fi

if [ $SINGLEFILE == true ]; then
	echo "doing one file";
	getsubs "$FILE";
fi

if [ $SINGLEFILE == false ]; then
	for f in "$DIRECTORY"/*.mkv; do
		getsubs "$f";
	done;
fi