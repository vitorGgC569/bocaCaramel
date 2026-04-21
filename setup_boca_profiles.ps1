$phpScript = @'
<?php
putenv('BOCA_DB_HOST=boca-db');
putenv('BOCA_DB_PASSWORD=dAm0HAiC');
require_once '/var/www/boca/src/db.php';
$c = DBConnect();
$contestPass = hash('sha256', 'Ur#t4i@CCAIFG0!2026xZq');
$adminPass = hash('sha256', 'Ur#t4i@CCAIFG0!2026xZq2');
DBExec($c, "ALTER TABLE usertable ALTER COLUMN username TYPE varchar(50)");
DBExec($c, "UPDATE sitetable SET siteautojudge='t'");
DBExec($c, "UPDATE usertable SET username='CCASuperControlContest', userfullname='Systems', userpassword='$contestPass', usersession='', usersessionextra='' WHERE contestnumber=0 AND usersitenumber=1 AND usernumber=1");
DBExec($c, "INSERT INTO usertable (contestnumber, usersitenumber, usernumber, username, userfullname, userdesc, usertype, userenabled, usermultilogin, userpassword, userip, userlastlogin, usersession, usersessionextra, userlastlogout, userpermitip, updatetime, usericpcid, userinfo) VALUES (0, 1, 1000, 'CCASuperControlRuntime', 'Administrator', NULL, 'admin', 't', 't', '$adminPass', NULL, NULL, '', '', NULL, NULL, CAST(EXTRACT(EPOCH FROM now()) AS int), '', '') ON CONFLICT (contestnumber, usersitenumber, usernumber) DO UPDATE SET username=EXCLUDED.username, userfullname=EXCLUDED.userfullname, usertype=EXCLUDED.usertype, userenabled=EXCLUDED.userenabled, usermultilogin=EXCLUDED.usermultilogin, userpassword=EXCLUDED.userpassword, usersession='', usersessionextra='', updatetime=CAST(EXTRACT(EPOCH FROM now()) AS int)");
echo "Perfis aplicados com sucesso!\n";
?>
'@

$tempFile = Join-Path $PSScriptRoot 'inject_profiles.php'
Set-Content -Path $tempFile -Value $phpScript -Encoding UTF8
docker cp $tempFile boca-docker-boca-web-1:/var/www/boca/src/inject.php | Out-Null
$response = docker exec boca-docker-boca-web-1 php /var/www/boca/src/inject.php
docker exec boca-docker-boca-web-1 rm /var/www/boca/src/inject.php | Out-Null
Remove-Item $tempFile -Force
Write-Host $response
