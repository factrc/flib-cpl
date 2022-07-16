pam-auth-update --force --package sss
pam-auth-update --force --package mkhomedir
systemctl enable winbind smbd nmbd sssd
systemctl restart sssd smbd nmbd winbind
