#!/usr/bin/env bash
# Copyright (C) Sergey Loskutov
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>. 

if [ -n "$(readlink -fq $0)" ]; then
 . $(dirname $(readlink -fq $0))/function
else
. $(dirname $0)/function
fi


background='Подключение ресурса с помощью pam_mount'

action.dialog.pammount.InstallRequiredPackages() {
	local packages=("$@")
	local status=0
	local ret=0
	local arr=()
	local text=''

	lib.misc.IsExistPackageBatchMode ${packages[@]} || status=$?
	[ $status -eq 0 ] && return 0

	if [ -n "$DIALOG_NONE" ]; then 
		lib.misc.InstallPackages ${packages[@]}
		return $?
	fi

	text="Пакеты программ необходимых для монтирования сетевых ресурсов Windows(cifs) под правами пользователя\n
	\Z1 [При отказе установки пакетов, дальнейшая работа прервется]\Zn\n
	\Zb Установить необходимые пакеты в систему?\Zn\n
	"
	lib.misc.DialogWrapper ret status --backtitle "$background" --no-items --cancel-label 'Нет' --ok-label 'Да' --menu "$text" 15 80 6 "${RET[@]}"
	if [ $status -eq 0 ]; then 
		status=0
		lib.misc.InstallPackages ${RET[@]} || status=$?
		if [ $status -ne 0 ]; then 
			arr=()
			for _i in ${!RET[@]}; do arr+=(${RET[$_i]} "код ошибки : ${RET1[$_i]}"); done
			text="При установке пакетов, возникли ошибки:\n"
			lib.misc.DialogWrapper ret status --backtitle "$background" --no-cancel --ok-label 'Ok' --menu "$text" 15 80 6 "${arr[@]}"
			status=1
		fi
	fi
	return $status
}

#########
# INPUT:  <?[~]username | ?%group > 
# RESULT: in $RET
#########
action.dialog.pammount.SearchUserOrGroup() {
	local search="$1"
	local ret=''
	local status=0
	local arr=()

	if [ "${search:0:1}" = "?" ]; then 
		if [ "${search:1:1}" = "%" ]; then 
			lib.pammount.SearchGroup arr "${search:2}"
		else
			if [ "${search:1:1}" = "~" ]; then 
				lib.pammount.SearchUsername arr "${search:2}"
			else
				lib.pammount.SearchUsername arr "${search:1}"
			fi	
		fi
		if [ "${arr[0]}" != "none" ]; then
			lib.misc.DialogWrapper ret status --backtitle "$background" --no-cancel --menu 'Результаты поиска' 0 0 0 "${arr[@]}"
		fi
	fi    
	if [ "$ret" = "none" ]; then return 1; fi 
	RET=$ret
  return 0
}

action_processmount() {

	local param1=''
	local param2=''
	local param3=''
	local param4=''
	local status=0
	local user=''
	local result=''
	local text=''

	IFS='|' read param1 param2 param3 param4 <<< $(echo $1)

	if [[ -z "$param1" || -z "$param2" || -z "$param3" || -z "$param4" ]]; then 
		lib.misc.DialogWrapper val status --backtitle "$background" --title " Статус подключения ресурса " --msgbox "Неверно указаны параметры подключения" 0 0
	 	return 255
	fi
	
	case "${param1:0:1}" in
	    '~') user="${param1:1}" ;;
	    '%') user="${param1:1}" ;;
	    '@') user='Все пользователи' ;;
	    *) user=$param1 ;;
	esac
#   0 = Ok
#   2 = user if not '*' not found
#   3 = mountpoint is exist
#   other = something wrong
	result=$(lib.pammount.Process "$param1" "$param2" "$param3" "$param4") || status=$?
	case $status in 
		0) text="***OK***\nТочка монтирования для ресурса \"$param2\" и пользователя \"$param1\" создана успешно" ;;
		2) text="***ERROR***\nНе удалось найти такого пользователя или группу" ;;
		3) text="***ERROR***\nТочка монтирования \"$param3\" существует для пользователя \"$user\"\nРезультат: $result" ;;
		4) text="***ERROR***\nНеверно указан ресурс: \"$param2\"" ;;
		5) text="***ERROR***\nНет разрешения на редактирования правил монтирования" ;;
		*) text="***ERROR***\nНе удалось подключить ресурс. Код ошибки: $status\nРезультат: $result" ;;
	esac
	lib.misc.DialogWrapper val status --backtitle "$background" --title " Статус подключения ресурса " --msgbox "$text" 0 0
	return 0
}
action.dialog.pammount.mount() {
    local text="\Z1Если необходимо подключить ресурс под правами отдельного пользователя используйте autofs\Zn\n
	Подключение ресурсов осуществляется под правами входящего пользователя.\n
	Имя пользователя(группы): [~%]username | @\n
		<%username> -  интерпретировать <username> как группа через сервис sss\n
		<@>         - все пользователи\n
		<username>  - для пользователя через сервис sss\n
		~ перед username указывает: создать запись о ресурсе в локальном файле pam_mount пользователя\n
	Адрес ресурса: //server/share  Пример: //test.other.ru/myshare\n
	Точка монтирования: <имя ресурса>:\n
			имя_ресурса  - используется $FLIB_PAMMOUNT_DIR/имя_ресурса\n
			~имя_ресурса - точка монтирования в домашнем каталоге. \n
			/имя_ресурса - точка монтирования используется как абсолютный путь.\n
	Параметры монтирования: name1=value1,name2=value2.\n
	\Z1Для систем с активированным SELinux необходимо создавать правила разрешения в SELinux,\n
	либо глобально в /etc/selinux/config менять на SELINUX=permissive или SELINUX=disabled\Zn"
    local offset=25
    local size=60
    local status=0
    local opt=${FLIB_PAMMOUNT_OPT:-"nosuid,nodev"}
    local username=''
    local server=''
    local point=''
    local ret=''
    local dialogopt="--ok-label Поиск --cancel-label Завершить --extra-button --extra-label Подключить"
	
    while [ $status -eq 0 ]; do
		local form_arr=( 
			"Имя пользователя: " 		2 1  "$username" 	2 	$offset 30 		255
			"Адрес ресурса: "    		4 1  "$server" 	 	4 	$offset $size 	255
			"Точка монтирования: " 		6 1  "$point" 		6 	$offset 30 		255
			"Параметры монтирования: " 	8 1  "$opt" 		8 	$offset $size 	255
		)
		val=''
#		lib.misc.DialogWrapper val status --aspect 9 --backtitle "$background" --title "Подключение ресурса по протоколу SMB:" $dialogopt --mixedform "$text" 0 0 0 "${form_arr[@]}"
		lib.misc.DialogWrapper val status --aspect 9 --separator '|' --backtitle "$background" --title "Подключение ресурса по протоколу SMB:" $dialogopt --form "$text" 0 0 0 "${form_arr[@]}"
		local param=() ; IFS='|' read -a param <<< $(echo "$val")
		case $status in
			0 )  # ПОИСК
				[[ -z "${param[0]}" ]] && continue
				username="${param[0]}"
#				if [[  "${param[0]:1}" =~ ^[[:alnum:][:space:]]*$ ]]; then  username="${param[0]}"; fi 
#				if [[ -z $username || "${username:0:1}" = "*" ]]; then continue; fi
				action.dialog.pammount.SearchUserOrGroup "?$username"
				ret="$RET"
				if [ -n "$ret" ]; then
					case "${username:0:1}" in
						"%") username="%$ret";	ret="Группа";;
						"~") username="~$ret";	ret="Пользователь";;
						*) username="$ret";	 	  ret="Пользователь";;
					esac
					ret+=" найден"
				else
					ret+=" не найден"
				fi	    
				[ "${username:0:1}" = "%" ] && ret+="а"
#				username=$( echo $username | sed 's/ /\\ /g')
				;;
			3 ) action_processmount "$val" 
				status=0
				;;# ПОДКЛЮЧИТЬ
			*) ;;
		esac	
    done
    echo status=$status,val=$val
}
action.dialog.pammount.InstallRequiredPackages $(lib.pammount.GetRequiredPackages) || return 0
#echo "$(lib.pammount.GetRequiredPackages)"
#lib.misc.InstallPackages $(lib.pammount.GetRequiredPackages)
action.dialog.pammount.mount $@
