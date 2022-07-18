#!/bin/bash
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

background='Подключение ресурса с помощью autofs'

action.dialog.autofs.InstallRequiredPackages() {
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
	text="Пакеты программ необходимых для монтирования сетевых ресурсов Windows(cifs) через autofs\n
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
# INPUT:  <username> 
# RESULT: in $RET
#########
action.dialog.autofs.SearchUserOrGroup() {
	local search="$1"
	local ret=''
	local status=0
	local arr=()

	if [ "${search:0:1}" = "?" ]; then 
		if [ "${search:1:1}" = "~" ]; then 
			lib.pammount.SearchUsername arr "${search:2}"
		else
			lib.pammount.SearchUsername arr "${search:1}"
		fi	
		if [ "${arr[0]}" != "none" ]; then
			lib.misc.DialogWrapper ret status --backtitle "$background" --no-cancel --menu 'Результаты поиска' 0 0 0 "${arr[@]}"
		fi
	fi    
	if [ "$ret" = "none" ]; then return 1; fi 
	RET=$ret
  return 0
}


action.dialog.autofs.mount() {
    local text="Подключение ресурсов через autofs\n
	Можно не использовать pammount, для этого путь точки монтирования указывать как ~точка_монтирования\n
	Имя пользователя: может быть пустым, добавляется опция: guest\n
	Пароль пользователя: может быть пустым, если пустой и точка монтирования c ~, добавляются опции sec=krb5,cruid=%USERUID\n 
	Адрес ресурса: //server/share  Пример: //test.other.ru/myshare\n
	Точка монтирования: <имя ресурса>:\n
			имя_ресурса  - используется: $FLIB_AUTOFS_DIR/имя_ресурса\n
			/имя_ресурса - точка монтирования используется как абсолютный путь.\n
			~имя_ресурса - точка монтирования в домашнем каталоге пользователя, username должно быть указано.\n
	Параметры монтирования: name1=value1,name2=value2.\n
	\Z1Для систем с активированным SELinux необходимо создавать правила разрешения в SELinux,\n
	либо глобально в /etc/selinux/config менять на SELINUX=permissive или SELINUX=disabled\Zn"
    local offset=25
    local size=60
    local status=0
    local opt="dir_mode=0600,file_mode=0600,ro,noperm,soft,vers=1.0" #${FLIB_PAMMOUNT_OPT:-"nosuid,nodev"}
    local username=''
    local password=''
    local resource=''
    local point=''
    local ret=''
    local dialogopt="--ok-label Поиск --cancel-label Завершить --extra-button --extra-label Подключить"
	
    while [ $status -eq 0 ]; do
		local form_arr=( 
			"Имя пользователя: " 		2 1  "$username" 	2 	$offset 30 		255 0
			"Пароль пользователя: " 	4 1  "$password" 	4 	$offset 30 		255 1
			"Адрес ресурса: "    		6 1  "$resource"  	6 	$offset $size 	255 0
			"Точка монтирования: " 		8 1  "$point" 		8 	$offset 30 		255 0
			"Параметры монтирования: " 	10 1  "$opt" 		10 	$offset $(($size+30)) 	255 0
		)
		val=''
#		lib.misc.DialogWrapper val status --aspect 9 --backtitle "$background" --title "Подключение ресурса по протоколу SMB:" $dialogopt --mixedform "$text" 0 0 0 "${form_arr[@]}"
		lib.misc.DialogWrapper val status --insecure --separator '|' --backtitle "$background" --title "Подключение ресурса :" $dialogopt --mixedform "$text" 0 0 0 "${form_arr[@]}"
		local param=() ; IFS='|' read -a param <<< $(echo "$val")
		username=${param[0]}
		password=${param[1]}
		resource=${param[2]}
		point=${param[3]}
		opt=${param[4]}
		echo "$username"
		case $status in
			0)  # ПОИСК 
				[ -z "$username" ] && continue
				local mstatus=0
				action.dialog.autofs.SearchUserOrGroup "?$username" || mstatus=$?
				if [ $mstatus -eq 0 ]; then
					username="$RET"
				fi
			;;
			3)
				if [ -z "$resource" ] || [ -z $point ]; then 
					continue
				fi
				local fopt="$opt"
				[ -n "$username" ] && fopt+=",username=$username"
				[ -n "$password" ] && fopt+=",password=$password"
				if [ "${point:0:1}" = '~' ]; then
					local homedir=$(lib.misc.GetUserHomeDir "$username" )	
					if [ -n "$homedir" ]; then 
						point="$homedir/${point:1}"
					fi
					if [ -z "$password" ]; then 
						local cruid=$(lib.misc.GetUserUid "$username" )
						[ -n "$cruid" ] && fopt+=",cruid=$cruid,sec=krb5"
					fi
				fi
				if [ -z "$username" ]; then 
					fopt+=",guest"
				fi
				local mstatus=0				
				result=$(lib.autofs.Process -r "$resource" -p "$point" -o "$fopt") || mstatus=$?
				local mtext=''
				case $mstatus in 
					0) mtext="***OK***\nТочка монтирования для ресурса \"$resource\" создана успешно" ;;
					*) mtext="***ERROR***\nНе удалось подключить ресурс. Код ошибки: $mstatus\nРезультат: $result" ;;
				esac
				lib.misc.DialogWrapper val mstatus --backtitle "$background" --title " Статус подключения ресурса " --msgbox "$mtext" 0 0
				;;
			*) ;;
		esac	
    done
    echo status=$status,val=$val
}
action.dialog.autofs.InstallRequiredPackages $(lib.autofs.GetRequiredPackages) || return 0
action.dialog.autofs.mount
