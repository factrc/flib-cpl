echo "execute $0 with \"$1\""
[ -z "$1" ] && exit 0
echo 'append to astra sssd.conf allowed_uids + fly-dm + www-data + sshd'
append=", $( id -u fly-dm) , $(id -u www-data)"
sshd=$(id -u sshd)
[ -n "$sshd" ] && append+=" , $sshd"
grep -qE "allowed_uids.*=.*" $1 && sed -i -e "s|allowed_uids.*=.*|allowed_uids = 0 $append|" $1
