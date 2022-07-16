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

background='Подключение ресурса с помощью autofs'

function action.dialog.autofs.InstallRequiredPackages() {
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
function action.dialog.autofs.mount() {
    local text="Подключение ресурсов через autofs\n
	Имя пользователя:  username, может быть пустым\n
	Пароль пользователя: password, может быть пустым\n 
	Адрес ресурса: //server/share  Пример: //test.other.ru/myshare\n
	Точка монтирования: <имя ресурса>:\n
			имя_ресурса  - используется $FLIB_AUTOFS_DIR/имя_ресурса\n
			/имя_ресурса - точка монтирования используется как абсолютный путь.\n
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
    local dialogopt="--ok-label Подключить --cancel-label Завершить"
	
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
		case $status in
			0 )  # ПОИСК
				local fopt=''
				username=${param[0]}
				password=${param[1]}
				resource=${param[2]}
				point=${param[3]}
				opt=${param[4]}
				if [ -z "$resource" ] || [ -z $point ]; then 
					continue
				fi
				fopt="$opt"
				[ -n "$username" ] && fopt+=",username=$username"
				[ -n "$password" ] && fopt+=",password=$password"
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
action.dialog.autofs.mount $@
