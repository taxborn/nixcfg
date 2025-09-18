# Tungsten backup configuration
#
# rsync: ./borg-repos/tungsten
# helium-01: ./borg-repos/tungsten
# local: /var/lib/backups/tungsten
#
# include
#  - /home/taxborn/Documents
#  - /home/taxborn/Media
#
# ssh is managed by the yubikey, /run/user/1000/gnupg/S.gpg-agent.ssh
# > ssh -o IdentityFile=/run/user/1000/gnupg/S.gpg-agent.ssh
{ }
