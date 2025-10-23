let
  taxborn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOf8rn+JzRmVc6/4xKOJ4MrmId4xxpYPEgvbCrK18U+N yubikey";
  users = [ taxborn ];

  uranium = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK2Bj6eF8CLcdxFQZZc7pxpSf/53mbPKRqjJQnK2SXiA root@uranium";
  systems = [ uranium ];
in
{
}
