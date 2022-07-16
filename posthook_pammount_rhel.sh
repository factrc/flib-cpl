# echo append pam_mount to /etc/pam.d/password-auth
grep -q pam_mount.so /etc/pam.d/* && exit 0
if [ -r /etc/pam.d/password-auth ]; then
    echo -e "session\toptional\tpam_mount.so disable_interactive" >> /etc/pam.d/password-auth
fi
echo -e "\n*************\nIf using SSSD and KRB5, append in pam_mount options: sec=krb5\n*************\n"
