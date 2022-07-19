#!/bin/bash

pp=$(readlink -fq $0)
if [ -n "$pp" ]; then
 pp=$(dirname $pp)
else
 pp=$(dirname $0)
fi

. $pp/function

arr_menu=( 
'1' 'Регистрация компьютера в Active Directory' 'Регистрация компьютера в Active Directory используя команду net из пакета Samba.'
'2' 'Подключения сетевых ресурсов Microsoft для пользовательской сессии' 'Используется модуль PAM, а именно pam_mount. Подключает ресурс с правами пользователя'
'3' 'Подключения сетевых ресурсов Microsoft с помощью автоматического монтирования' 'Используется autofs. Доступ к ресурсу задается явно.' 
)

status=0
vals=''
helpfile="$pp/help_cpl"

#tmp=$(mktemp)
while [ $status -eq 0 ]; do
    arr=("${arr_menu[@]}")
    lib.misc.DialogWrapper vals status --clear --hfile "$helpfile" --item-help --title 'Функциональная панель для работы с Active Directory. F1 - help' --menu 'Выбор скрипта:' 20 100 5 "${arr[@]}"
    case $vals in 
        '1')
        $pp/ad.sh
        ;;
        '2')
        $pp/pammount.sh
        ;;
        '3')
        $pp/autofs.sh
        ;;
    esac
#    if [ $? -ne 0 ]; then
#        lib.misc.DialogWrapper v s  --clear --msgbox "Выход с ошибкой" 0 0 
#    fi
done
#rm -f $tmp



