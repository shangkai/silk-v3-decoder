#!/bin/bash
# File: converter.sh
# Date: August 19th, 2016
# Time: 18:56:52 +0800
# Author: kn007 <kn007@126.com>
# Blog: https://kn007.net
# Link: https://github.com/kn007/silk-v3-decoder
# Usage: sh converter.sh silk_v3_file/input_folder output_format/output_folder flag(format)
# Flag: not define   ----  not define, convert a file
#       other value  ----  format, convert a folder, batch conversion support
# Requirement: gcc ffmpeg

# Colors
RED="$(tput setaf 1 2>/dev/null || echo '\e[0;31m')"
GREEN="$(tput setaf 2 2>/dev/null || echo '\e[0;32m')"
YELLOW="$(tput setaf 3 2>/dev/null || echo '\e[0;33m')"
WHITE="$(tput setaf 7 2>/dev/null || echo '\e[0;37m')"
RESET="$(tput sgr 0 2>/dev/null || echo '\e[0m')"

# Main
cur_dir=$(cd `dirname $0`; pwd)

if [ ! -r "$cur_dir/silk/decoder" ]; then
	echo -e "${WHITE}[Notice]${RESET} Silk v3 Decoder is not found, compile it."
	cd $cur_dir/silk
	make && make decoder
	[ ! -r "$cur_dir/silk/decoder" ]&&echo -e "${RED}[Error]${RESET} Silk v3 Decoder Compile False, Please Check Your System For GCC."&&exit
	echo -e "${WHITE}========= Silk v3 Decoder Compile Finish =========${RESET}"
fi

cd $cur_dir

while [ $3 ]; do
	[[ ! -z "$(pidof ffmpeg)" ]]&&echo -e "${RED}[Error]${RESET} ffmpeg is occupied by another application, please check it."&&exit
	[ ! -d "$1" ]&&echo -e "${RED}[Error]${RESET} Input folder not found, please check it."&&exit
	TOTAL=$(ls $1|wc -l)
	[ ! -d "$2" ]&&mkdir "$2"&&echo -e "${WHITE}[Notice]${RESET} Output folder not found, create it."
	[ ! -d "$2" ]&&echo -e "${RED}[Error]${RESET} Output folder could not be created, please check it."&&exit
	CURRENT=0
	echo -e "${WHITE}========= Batch Conversion Start ==========${RESET}"
	# 本次修改之前是在while read循环里调用ffmpeg命令后，虽然ffmpeg命令是在子进程中执行，而且输出也重定向到了/dev/null，
	# 但是还是会影响到本进程while循环下次读取文件名，导致读取的文件名前面缺少2个字符
	# 本次修改是先把文件名读取到数组中，然后再循环数组，这样就不会影响到while循环读取文件名了，
	# 而且【ffmpeg命令也不需要在子进程里执行，本进程循环等待1秒判断子进程状态】。执行速度更快。
	# 我不知道原作者在子进程里执行ffmpeg命令的目的，我猜测是为了不影响到本进程while循环里读取下一个文件名，但是我在Docker里测试发现还是会影响。
	# 我不知道原作者有没有别的考虑，反正我这样改后，简单测试没有发现问题。
	file_index=0
	while read line2
	do
		file_array[ $file_index ]="$line2"
		(( file_index++ ))
	done < <(ls $1)
	# echo ${file_array[@]}
	for line in "${file_array[@]}"
	do
		let CURRENT+=1
		$cur_dir/silk/decoder "$1/$line" "$2/$line.pcm" > /dev/null 2>&1
		if [ ! -f "$2/$line.pcm" ]; then
			ffmpeg -y -i "$1/$line" "$2/${line%.*}.$3" > /dev/null 2>&1
			#ffmpeg_pid=$!
			#while kill -0 "$ffmpeg_pid"; do sleep 1; done > /dev/null 2>&1
			[ -f "$2/${line%.*}.$3" ]&&echo -e "[$CURRENT/$TOTAL]${GREEN}[OK]${RESET} Convert $line to ${line%.*}.$3 success, ${YELLOW}but not a silk v3 encoded file.${RESET}"&&continue
			echo -e "[$CURRENT/$TOTAL]${YELLOW}[Warning]${RESET} Convert $line false, maybe not a silk v3 encoded file."&&continue
		fi
		ffmpeg -y -f s16le -ar 24000 -ac 1 -i "$2/$line.pcm" "$2/${line%.*}.$3" > /dev/null 2>&1
		# ffmpeg_pid=$!
		#while kill -0 "$ffmpeg_pid"; do sleep 1; done > /dev/null 2>&1
		rm "$2/$line.pcm"
		[ ! -f "$2/${line%.*}.$3" ]&&echo -e "[$CURRENT/$TOTAL]${YELLOW}[Warning]${RESET} Convert $line false, maybe ffmpeg no format handler for $3."&&continue
		echo -e "[$CURRENT/$TOTAL]${GREEN}[OK]${RESET} Convert $line To ${line%.*}.$3 Finish."
	done
	echo -e "${WHITE}========= Batch Conversion Finish =========${RESET}"
	exit
done

$cur_dir/silk/decoder "$1" "$1.pcm" > /dev/null 2>&1
if [ ! -f "$1.pcm" ]; then
	ffmpeg -y -i "$1" "${1%.*}.$2" > /dev/null 2>&1
	#ffmpeg_pid=$!
	#while kill -0 "$ffmpeg_pid"; do sleep 1; done > /dev/null 2>&1
	[ -f "${1%.*}.$2" ]&&echo -e "${GREEN}[OK]${RESET} Convert $1 to ${1%.*}.$2 success, ${YELLOW}but not a silk v3 encoded file.${RESET}"&&exit
	echo -e "${YELLOW}[Warning]${RESET} Convert $1 false, maybe not a silk v3 encoded file."&&exit
fi
ffmpeg -y -f s16le -ar 24000 -ac 1 -i "$1.pcm" "${1%.*}.$2" > /dev/null 2>&1
#ffmpeg_pid=$!
#while kill -0 "$ffmpeg_pid"; do sleep 1; done > /dev/null 2>&1
rm "$1.pcm"
[ ! -f "${1%.*}.$2" ]&&echo -e "${YELLOW}[Warning]${RESET} Convert $1 false, maybe ffmpeg no format handler for $2."&&exit
echo -e "${GREEN}[OK]${RESET} Convert $1 To ${1%.*}.$2 Finish."
exit