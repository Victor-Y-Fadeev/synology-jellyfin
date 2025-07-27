# <img src="https://upload.wikimedia.org/wikipedia/commons/9/94/Cloudflare_Logo.png" width="32"/> [Cloudflare](https://one.dash.cloudflare.com/)

```diff
--- /etc/ssh/sshd_config
+++ /etc/ssh/sshd_config
@@ -37 +37,2 @@
-#PubkeyAuthentication yes
+PubkeyAuthentication yes
+TrustedUserCAKeys /etc/ssh/ca.pub
@@ -57 +58 @@
-PasswordAuthentication yes
+PasswordAuthentication no
@@ -82 +83 @@ ChallengeResponseAuthentication no
-UsePAM yes
+UsePAM no
@@ -85 +86 @@ UsePAM yes
-AllowTcpForwarding no
+AllowTcpForwarding yes
@@ -124,0 +126,3 @@ Match User anonymous
+Match User victor
+    AuthorizedPrincipalsCommand /bin/echo 'victor.y.fadeev'
+    AuthorizedPrincipalsCommandUser nobody
```

```diff
--- /etc/passwd
+++ /etc/passwd
@@ -42,0 +43 @@ victor:x:1026:100::/var/services/homes/victor:/bin/sh
+victor.y.fadeev:x:1026:100::/var/services/homes/victor:/bin/sh
```

```diff
--- /etc/group
+++ /etc/group
@@ -2 +2 @@
-administrators:x:101:admin,victor
+administrators:x:101:admin,victor,victor.y.fadeev
```

```shell
$ ln -s ~ ~/../victor.y.fadeev
$ chmod 755 ~/.ssh/authorized_keys
$ sudo vim /etc/ssh/ca.pub
$ sudo chmod 600 /etc/ssh/ca.pub
$ sudo systemctl restart sshd
```
