authselect select sssd
# mkhomedir required oddjobd 
authselect enable-feature with-mkhomedir
systemctl enable winbind smb nmb sssd oddjobd 
systemctl restart sssd smb nmb winbind oddjobd 

se=$(sestatus | sed -ne 's/Current mode:\s\+\(.\+\).*/\1/p')
if [ "$se" = "enforcing" ]; then
    echo -e "\nSELinux detected. Enable samba_home_dir access. Please wait..."
   	semanage permissive -a winbind_t
    setsebool -P samba_enable_home_dirs=1
    setsebool -P use_samba_home_dirs 1
    echo 'SELinux ok'
fi
