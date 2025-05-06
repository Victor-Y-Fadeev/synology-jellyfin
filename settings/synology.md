# <img src="https://fileres.synology.com/images/common/favicon/syno/icon-180x180.png" width="32"/> Synology

```diff
--- /etc/ssh/sshd_config
+++ /etc/ssh/sshd_config
@@ -37 +37,2 @@
-#PubkeyAuthentication yes
+PubkeyAuthentication yes
+TrustedUserCAKeys /etc/ssh/ca.pub
@@ -82 +83 @@ ChallengeResponseAuthentication no
-UsePAM yes
+UsePAM no
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

```shell
$ chmod 755 ~/.ssh/authorized_keys
$ sudo vim /etc/ssh/ca.pub
$ sudo chmod 600 /etc/ssh/ca.pub
$ sudo systemctl restart sshd
```
