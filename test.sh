#!/bin/bash





if [ -n "$(readlink -fq $0)" ]; then
 . $(dirname $(readlink -fq $0))/function
else
. $(dirname $0)/function
fi

status=0
vals=''

while [ $status -eq 0 ]; do
    arr=( 
	'1' 'Регистрация в Active Directory' "This is registration in active directory script!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n!!!!!!!!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" 
	'2' 'Подключения сетевых дисков в Active Directory под учеткой пользователя' "Pammount helper" 
	'3' 'Подключения сетевых дисков Microsoft под учеткой другого пользователя ( autofs )' "AUTOFS script" 
    )
    lib.misc.DialogWrapper vals status --clear --item-help --title 'Функциональная панель для работы с Active Directory' --menu 'Выбор скрипта:' 20 100 5 "${arr[@]}"
    echo $vals
done




