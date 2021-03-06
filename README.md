SHMIG_TEST
=================

Automated tests for [`shmig`](https://github.com/mbucc/shmig/blob/master/shmig).

To run manually, clone this project, copy shmig into this directory, start
docker, and run ./test_runner.sh.  To test a single platform, comment out
lines in test_runner.conf before running test_runner.sh.  Then check 
stderr.actual and stdout.actual.  You can also use "DEBUG=1 ./test_runner.sh" 
to get more output from the test script.


Latest Results
-----------------

| Client | Shell | DB  | Result | Test Date |
| ------ | ----- | --- | ------ | --------- |
| alpine:3.8 | /bin/bash | sqlite3 | ![](https://raw.githubusercontent.com/mbucc/shmig_test/master/badges/alpine-3.8-bash-sqlite3.png?1560091183) | Sun Jun  9 14:39:43 UTC 2019 ([log](https://raw.githubusercontent.com/mbucc/shmig_test/master/logs/alpine-3.8-bash-sqlite3.out?1560091183)) |
| alpine:3.8 | /bin/bash | mysql:5.7 | ![](https://raw.githubusercontent.com/mbucc/shmig_test/master/badges/alpine-3.8-bash-mysql-5.7.png?1560091208) | Sun Jun  9 14:40:08 UTC 2019 ([log](https://raw.githubusercontent.com/mbucc/shmig_test/master/logs/alpine-3.8-bash-mysql-5.7.out?1560091208)) |
| alpine:3.8 | /bin/bash | postgres:9.6 | ![](https://raw.githubusercontent.com/mbucc/shmig_test/master/badges/alpine-3.8-bash-postgres-9.6.png?1560091222) | Sun Jun  9 14:40:22 UTC 2019 ([log](https://raw.githubusercontent.com/mbucc/shmig_test/master/logs/alpine-3.8-bash-postgres-9.6.out?1560091222)) |
