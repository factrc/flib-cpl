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


action.dialog.ad.GetAdminAccount () { #ref_def_name ref_def_pass
#	declare -n _ref11=$1
#	declare -n _ref22=$2
	local _arg1=$1
	local _arg2=$2
	lib.misc.CopyByName _ref11 $_arg1
	lib.misc.CopyByName _ref22 $_arg2
	shift
	shift
	local text='\Z1Поля обязательны к заполнению\Zn'
	local vals=''
	local status=0
	local farr=(
		'Username: ' 1 0 "$_ref11" 1 15 60 255 0
		'Password: ' 3 0 "$_ref22" 3 15 60 255 1
	)
	[ -n "$DIALOG_NONE" ] && return 0
	lib.misc.DialogWrapper vals status --title 'Учетные данные администратора домена' --insecure --backtitle "$background" --mixedform "$text" 0 0 0 "${farr[@]}"
	read _ref11 _ref22 <<<$(echo $vals)
	lib.misc.Debug "action.dialog.GetAdminAccount" "ref11=\"$_ref11\" ref22=\"$_ref22\""
	lib.misc.CopyByName $_arg1 _ref11
	lib.misc.CopyByName $_arg2 _ref22 
	return $status
}

action.dialog.ad.GetHostnameAndDomain() { # ref_machine_name ref_domain
#	declare -n _ref11=$1
#	declare -n _ref22=$2
	local _arg1=$1
	local _arg2=$2
	lib.misc.CopyByName _ref11 $_arg1
	lib.misc.CopyByName _ref22 $_arg2
	shift
	shift

	[ -n "$DIALOG_NONE" ] && return 0

	_ref22=$(echo $_ref11 | sed -n "s|^\w\+\.\(.\+\)$|\1|p;s/\.$//")

	local vals=''
	local status=0
	local garbage='[\[\],+=\!@#\$\%^&*\(\)\/]{}:;" '
	local text='Имя компьютера в формате(имя_компьютера.домен).\nЕсли не указать домен в имени компьютера, будет подставлен домен регистрации.'
	local farr=(
		'Имя компьютера: '    1 0 "$_ref11" 1 21 80 255
		'Домен регистрации: ' 3 0 "$_ref22" 3 21 80 255
	)
	lib.misc.DialogWrapper vals status --title 'Редактирование имени компьютера и домена' --backtitle "$background" --form "$text" 0 0 0 "${farr[@]}"
	read _ref11 _ref22 <<<$(echo $vals)
	_ref11=$(echo $_ref11 | tr -d $garbage | sed "/^\w\+$/{s|\(\w\+\).*$|\1\.$_ref22|;s/\.$//}")
	_ref22=$(echo $_ref22 | tr [:upper:] [:lower:] | sed "s/\.$//")
	lib.misc.CopyByName $_arg1 _ref11
	lib.misc.CopyByName $_arg2 _ref22 
	return $status
}

#-help- action.dialog.AstraOutdated <version_required>
action.dialog.ad.AstraOutdated() {
	local vals=''
	local status=0
	lib.ad.AstraVersionMatchBetter "$1" && return 0

	[ -n "$DIALOG_NONE" ] && return 0

	local text="\Z1Текущая версия обновления Астры: ${OS_RELEASE_PRETTY_NAME:-$OS_RELEASE_NAME} [Update: ${OS_RELEASE_UPDATE_ID:-none}, Bulletin: ${OS_RELEASE_UPDATE_NAME:-none} ] ниже чем требуется для работы ($1).\Zn"
	if [ -z "$OS_RELEASE_UPDATE_NAME" ]; then
		text+="\nВ базовом дистрибутиве одновременная работа SSSD с ресурсами SAMBA на этом компьютере, некорректна.\nИсправлено с выходом БЮЛЛЕТЕНЯ №20200722SE16\n"
	fi
	text+="\nВы хотите продолжить регистрацию в домен?"
	lib.misc.DialogWrapper vals status --backtitle "$background" --title 'ПРЕДУПРЕЖДЕНИЕ:' --yesno "$text" 15 80
	return $status
}

###################################

action.dialog.ad.InstallRequiredPackages() {
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

	text="Пакеты программ необходимых для регистрации компьютера в домен.\n
	\Z1 [При отказе установки пакетов, дальнейшая регистрация прервется]\Zn\n
	\Zb Установить необходимые пакеты в систему?\Zn\n
	"
#	for _i in ${RET[@]}; do arr+=($_i "Обязательный к установке"); done
#	lib.misc.DialogWrapper ret status --backtitle "$background" --cancel-label 'Нет' --ok-label 'Да' --menu "$text" 15 80 6 "${arr[@]}"
	lib.misc.DialogWrapper ret status --backtitle "$background" --no-items --cancel-label 'Нет' --ok-label 'Да' --menu "$text" 15 80 6 "${RET[@]}"
	if [ $status -eq 0 ]; then 
		status=0
		lib.misc.InstallPackages ${RET[@]} || status=$?
		if [ $status -ne 0 ]; then 
			arr=()
			for _i in ${!RET[@]}; do arr+=(${RET[$_i]} "код ошибки : ${RET1[$_i]}"); done
			text="При установке пакетов, возникли ошибки:\n\\Z1 Дальнейшая регистрация компьютера невозможна.\Zn"
			lib.misc.DialogWrapper ret status --backtitle "$background" --no-cancel --ok-label 'Ok' --menu "$text" 15 80 6 "${arr[@]}"
			status=1
		fi
	fi
	return $status
}

action.dialog.ad.SelectOuForComputer() {
#	declare -n _ref="$1"
	local _arg1=$1
	lib.misc.CopyByName _ref $_arg1
	shift
	
	local user="$1"
	local passwd="$2"
	local arr=()
	local output=()
	local ret=''
	local pos=0

	[ -n "$DIALOG_NONE" ] && return 0

	lib.ad.GetOuFromLdap arr "$user" "$passwd"
	lib.misc.Debug "action.dialog.ad.SelectOuForComputer" "return array size: ${#arr[@]} "
	if [ ${#arr[@]} -ne 0 ]; then
		for ((i=0; $i<${#arr[@]}; i=$i + 1)); do
			local p=$(echo ${arr[$i]} | sed -e ':a;/DC=/{s/\(.*\),DC=.*$/\1/;ta};s/OU=//g')
			output+=($(($i + 1)) "$p")
			lib.misc.Debug "action.dialog.ad.SelectOuForComputer" "$(($i + 1)) : $p"
		done
		lib.misc.Debug "action.dialog.ad.SelectOuForComputer" "dialog array must be *2: ${#output[@]}"
		local text="Выбор подразделение: [ <Отмена> - подразделение по умолчанию ]"
		lib.misc.DialogWrapper pos status --backtitle "$background" --menu "$text" -1 -1 0 "${output[@]}"
		pos=$(($pos - 1))
		[[ $pos -le ${#arr[@]} && $pos -ge 0 ]] && _ref="${arr[$pos]}"
		lib.misc.Debug "action.dialog.ad.SelectOuForComputer" "return from dialog: ret value=$_ref"
	fi
	lib.misc.CopyByName $_arg1 _ref 
	return $status
}

action.dialog.ad.ExitInfo() {
	local text="Регистрация прошла успешно. Необходимо перезапустить X11 сервер, либо компьютер"
	if [ "$1" -ne 0 ]; then	
		text="Ошибка при регистрации: $1"
	fi
	local val=0
	local stat=0
	[ -n "$DIALOG_NONE" ] && return 0	
	lib.misc.DialogWrapper val stat --backtitle "$background" --msgbox "$text" 0 0
	return 0
}
##############
# 
##############
action.ad.registration() {
	local background="Регистрация компьютера в Active Directory"
	local req_version="20200722SE16"
	local required_packages=()
	local status=0
	local username="$1"
	local password="$2"
	local domain="$3"
	local machine_name=${4:-"$(cat /etc/hostname)"}
	local ou="$5"

	if [ -n "$DIALOG_NONE" ]; then
		if [[ -z "$username" || -z "$password" || -z "$domain" ]]; then
			echo 'usage: action.ad.registration <username> <password> <domain> [ machine_name ] [ ou ] '
			return 1
		fi
	fi

	if [[ $(id -u) -ne 0 ]]; then
		echo -e "**ОШИБКА**: Для регистрации в Active Directory требуются права привелегированного пользователя\n"
		return 1
	fi

	if [ -z "$DIALOG_NONE" ]; then 
		which dialog
		if [ $? -ne 0 ]; then
			status=0
			lib.misc.InstallPackages dialog || status=$?
			if [ $status -ne 0 ]; then
				echo "**ОШИБКА**: Не удалось поставить пакет dialog для продолжения работы."
				return 255
			fi
		fi
	fi

	echo 'Get required packages for installation' 
	required_packages=( $(lib.ad.GetRequiredPackages) )


	if [[ "$OS_RELEASE_ID" = "astra" && "$OS_RELEASE_VARIANT_ID" = "smolensk" ]]; then
		echo "--- Проверка текущей версии \"$OS_RELEASE_NAME\" для регистрации в Active Directory"
		status=0
		action.dialog.ad.AstraOutdated $req_version || status=$?
		if [ $status -ne 0 ]; then
			echo "**ОШИБКА**: Отказ от дальнейшей регистрации. Текущая версия Астры требует обновления."
			return 2
		fi
		if [ -n "$OS_RELEASE_UPDATE_ID" ]; then
			required_packages+=(astra-ad-sssd-client)
		fi
	fi

	echo "--- Проверка и установка необходимых пакетов для регистрации в AD (auth: SSSD + local share: SAMBA)"
	status=0
	action.dialog.ad.InstallRequiredPackages "${required_packages[@]}"  || status=$?
	if [ $status -ne 0 ]; then
		echo "**ОШИБКА**: Отказ от дальнейшей регистрации. Требуемые пакеты не установлены."
		return 3
	fi

	echo "--- Учетные данные администратора домена"
	while true; do
		[[ -n "$username" && -n "$password" ]] && break
		status=0
		action.dialog.ad.GetAdminAccount username password || status=$?
		if [ $status -ne 0 ]; then
			echo "**ОШИБКА**: Отказ от дальнейшей регистрации. Нет учетных данных администратора домена."
			return 3
		fi
	done

	echo "--- Редактирование имени компьютера и домена Active Directory ----"
	while true; do
		[[ -n "$machine_name" && -n "$domain" ]] && break
		status=0
		action.dialog.ad.GetHostnameAndDomain machine_name domain || status=$?
		if [ $status -ne 0 ]; then
			echo "**ОШИБКА**: Отказ от дальнейшей регистрации. Нет данных по домену."
			return 4
		fi
	done
	echo "--- Имя компьютера: $machine_name"
	echo "--- Домен: $domain"

	echo "--- Читаем информацию по серверам домена \"$domain\" из DNS ----"
	lib.ad.GetFromDnsRecords
	if [ -z "$master_dc" ]; then
		echo "**ОШИБКА**: Проверьте правильность настройки DNS клиента(серверов) или правильность указанного домена [$domain] и повторите регистрацию."
		return 5
	fi

	echo "--- Выбор подразделения для регистрации компьютера ----"
	if [ -z "$ou" ]; then
		status=0
		action.dialog.ad.SelectOuForComputer ou $username $password || status=$?
	fi
	ou="$(lib.ad.ConvertOuFromLdapToNet "$ou")"
	echo -e "\nВыбрано подразделение: \"$ou\""

	status=0
	lib.ad.Process "$username" "$password" "$domain" "$machine_name" "$ou" || status=$?
	action.dialog.ad.ExitInfo $status
	return $status
}

action.ad.registration $@
