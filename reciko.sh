#!/usr/bin/bash

#保存箇所の指定
recDIR=./

station=$1 #radkioのAPI参照
stream_url="https://f-radiko.smartstream.ne.jp/${station}/_definst_/simul-stream.stream/playlist.m3u8"
tmp_recfile=$(date '+%Y%m%d-%H%M%S')_${station}.m4a

title_keyword=$2

#今日の日付
date_today=$(date '+%Y%m%d')

wh_url=$(cat ./webhook)

if [ -z "$1" ] || [ -z "$2" ] ; then
	echo "Please fill in values."
	exit 1
fi

#キーをゲットして認証を済ませておく
function get_auth() {
	api_auth1=$(curl -s \
	-H 'X-Radiko-App: pc_html5' \
	-H 'X-Radiko-App-Version: 0.0.1' \
	-H 'X-Radiko-User: dummy_user' \
	-H 'X-Radiko-Device: pc' \
	-I -L https://radiko.jp/v2/api/auth1) \

	authToken=$(echo "${api_auth1}" | grep -i 'X-Radiko-AuthToken:' | sed -e 's/X-Radiko-AuthToken: //i' | sed -e 's/\r//')
	pkey_length=$(echo "${api_auth1}" | grep 'X-Radiko-KeyLength:' | sed -e 's/X-Radiko-KeyLength: //' | sed -e 's/\r//')
	pkey_offset=$(echo "${api_auth1}" | grep 'X-Radiko-KeyOffset:' | sed -e 's/X-Radiko-KeyOffset: //' | sed -e 's/\r//')

	pkey=$(echo -n "bcd151073c03b352e1ef2fd66c32209da9ca0afa" | cut -c $((pkey_offset + 1))-$((pkey_offset + pkey_length)) | base64 | sed -e 's/o=/==/')

	curl -f -H "X-Radiko-AuthToken: ${authToken}" \
	-H "X-Radiko-PartialKey: ${pkey}" \
	-H 'X-Radiko-User: dummy_user' \
	-H 'X-Radiko-Device: pc' \
	-I -L https://radiko.jp/v2/api/auth2

	if [ -z "$authToken" ] || [ "$?"! = 0 ] ; then
    	echo "Failed to access to APIs..."
        exit 1
	fi
}

#番組表を拾いに行って抽出
function get_metas() {
	metadatas=$(curl http://radiko.jp/v3/program/station/date/$date_today/$station.xml)
	
	title_meta=$(echo "${metadatas}" | \
	grep -3 "${title_keyword}" | \
	grep "<title>" | \
	sed -e "s/<title>\(.*\)<\/title>/\1/" | \
	sed -e "s/\?//g" | \
	sed 'y/ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ０１２３４５６７８９　（）/abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \(\)/' | sed -e 's/	//g')
	
	start_meta=$(echo "${metadatas}" | \
	grep -3 ${title_keyword} | \
	grep "prog id" | \
	sed -e 's/<prog id="\(.*\)" master_id="\(.*\)" ft="\(.*\)" to="\(.*\)" ftl="\(.*\)" tol="\(.*\)" dur="\(.*\)">/\5/' | \
	sed -e 's/^[ \t]*//' | sed -e 's/\(..\)\(..\)/\1時\2分/')

	finish_meta=$(echo "${metadatas}" | \
	grep -3 ${title_keyword} | \
	grep "prog id" | \
	sed -e 's/<prog id="\(.*\)" master_id="\(.*\)" ft="\(.*\)" to="\(.*\)" ftl="\(.*\)" tol="\(.*\)" dur="\(.*\)">/\6/' | \
	sed -e 's/^[ \t]*//' | sed -e 's/\(..\)\(..\)/\1時\2分/')

	hlong_meta=$(echo "${metadatas}" | \
	grep -3 ${title_keyword} | \
	grep "prog id" | \
	sed -e 's/<prog id="\(.*\)" master_id="\(.*\)" ft="\(.*\)" to="\(.*\)" ftl="\(.*\)" tol="\(.*\)" dur="\(.*\)">/\7/' | \
	sed -e 's/ //g' | \
	sed -e 's/	//g')

	rec_time=$(printf "%02d" "$((hlong_meta / 3600))"):$(printf "%02d" "$((hlong_meta / 60 % 60))"):$(printf "%02d" "$((hlong_meta % 60 + 20))")
}


#録音開始
function recoding() {
	ffmpeg \
	-headers "X-Radiko-AuthToken: ${authToken}" \
	-i "${stream_url}" \
	-vn \
	-acodec alac \
	-t ${rec_time} \
	${tmp_recfile}

	if [ "$?"! = 0 ] ; then
		echo "Recording failed!!"
		curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"Recording failed!!\"}" $wh_url
		exit 1
	fi

	curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"Done.\"}" $wh_url

}

#ファイル名揃えたり、一時ファイル消したり
function finalization() {
	if [ ! -d ${recDIR}/${tittle_keyword} ] ; then
		mkdir -p ${recDIR}/${tittle_keyword}
	fi

	cp ${tmp_recfile} ${recDIR}/${tittle_keyword}/${title_meta}.m4a

	if [ "$?"! = 0 ] ; then
		echo "finalize failed!! \
		Recording failed or invalid naming?"
		curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"Finalize failed!!!\"}" $wh_url
		exit 1
	fi

	rm ${tmp_recfile}

	#各子ディレクトリに'.series.sh'を設置してる場合はやるよん
	if [ -e ${recDIR}/${PROG_NAME}/.series.sh ];then
	 cd ${recDIR}/${PROG_NAME}
	 ./.series.sh
	fi
}

#録音開始通知
function wh_start() {
	title_4post=$(echo ${title_meta} | sed "s/(/\\(/g" | sed "s/)/\\)/g")
	curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"対象番組:「${title_4post}」\n開始時刻:${start_meta}\n終了時刻:${finish_meta}\n録音時間:${rec_time}\"}" $wh_url
}

if [ "${3}" = "dry" ] ; then
	get_auth; get_metas; echo -e "対象番組:「${title_meta}」\n開始時刻:${start_meta}\n終了時刻:${finish_meta}\n録音時間:${rec_time}"
	exit 0
elif [ "${3}" = "dry-wh" ] ; then
	get_auth; get_metas; wh_start;
	exit 0
fi

get_auth; get_metas; wh_start; recoding; finalization;
