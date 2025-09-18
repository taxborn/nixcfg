# Uranium backup configuration
#
# rsync: ./borg-repos/uranium
# helium-01: ./borg-repos/uranium
# local: /var/lib/backups/uranium
#
# include
#  - /home/taxborn/Documents
#  - /home/taxborn/Media
#
# ssh is managed by the yubikey, /run/user/1000/gnupg/S.gpg-agent.ssh
# > ssh -o IdentityFile=/run/user/1000/gnupg/S.gpg-agent.ssh
{ }
