#!/usr/bin/env bash
# Run ON the bastion (ec2-user@<bastion public IP, see AWS console>). Creates a locked-down "hex" OS user
# that can ONLY port-forward to the prod read replica on 5432. No shell, no pty.
#
#   scp -i ~/.ssh/solstice-bastion.pem 01_bastion_add_hex_user.sh ec2-user@<bastion public IP, see AWS console>:/tmp/
#   ssh -i ~/.ssh/solstice-bastion.pem ec2-user@<bastion public IP, see AWS console> \
#       'bash /tmp/01_bastion_add_hex_user.sh "<HEX WORKSPACE SSH PUBLIC KEY>"'
#
# The public key is in Hex: Settings -> Data sources -> bottom of page under "Workspace".
set -euo pipefail
HEX_PUBKEY="${1:?usage: 01_bastion_add_hex_user.sh '<hex workspace ssh public key>'}"
REPLICA="solstice-prod-read-replica.cvyw1tfyd0vl.us-east-1.rds.amazonaws.com"

id hex >/dev/null 2>&1 || sudo useradd --create-home --shell /sbin/nologin hex
sudo install -d -m 700 -o hex -g hex /home/hex/.ssh

# authorized_keys options: "restrict" disables pty/agent/X11/forwarding, then we
# re-enable only port-forwarding and only to the replica endpoint on 5432.
echo "restrict,port-forwarding,permitopen=\"${REPLICA}:5432\" ${HEX_PUBKEY}" \
  | sudo tee /home/hex/.ssh/authorized_keys >/dev/null
sudo chmod 600 /home/hex/.ssh/authorized_keys
sudo chown hex:hex /home/hex/.ssh/authorized_keys

# Belt and braces at the sshd level for this user only.
if ! sudo grep -q "^Match User hex" /etc/ssh/sshd_config; then
  printf '\nMatch User hex\n    AllowTcpForwarding yes\n    PermitTTY no\n    X11Forwarding no\n    AllowAgentForwarding no\n    ForceCommand /bin/false\n' \
    | sudo tee -a /etc/ssh/sshd_config >/dev/null
  sudo sshd -t && sudo systemctl reload sshd
fi
echo "OK. In Hex use SSH host <bastion public IP, see AWS console>, port 22, user hex."
