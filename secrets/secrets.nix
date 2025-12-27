let
  taxborn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOf8rn+JzRmVc6/4xKOJ4MrmId4xxpYPEgvbCrK18U+N yubikey";
  users = [ taxborn ];

  carbon = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhCoSFBNavdXRZ8sH1dzGwLO90BfYLNwbbu0yxVgxjf root@carbon";
  helium-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO3R84Qt7+WC/pplvm+TNLEreIiBQTiAtbLiYYhucvkL root@helium-01";
  tungsten = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFgQtojwvTH5KeMYWNRyIwFtD30Oiepv8qbTUf8kCMLg root@tungsten";
  uranium = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK2Bj6eF8CLcdxFQZZc7pxpSf/53mbPKRqjJQnK2SXiA root@uranium";

  systems = [
    carbon
    helium-01
    tungsten
    uranium
  ];
in
{

}
