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


How it works
-------------------

1. CREATE docker network `shmig-net`

2. FOR each line in test_runner.conf.

   a. WRITE docker file for shmig client image.

   b. START the database server docker image and give it the hostname
   `db`.

   c. RUN shmig_test.sh in the client image.

   d. UPDATE test result report.

   e. DELETE the Docker host `db`.

   f. ADD return for this line to over all return code.

3. DELETE docker network `shmig-net`

4. RETURN over all return code.


Notes

  * SQLite does not need to start up a database server.

  * Both database server (if needed) and database client are attached
  to the Docker network `shmig-net`.

  * The database client image mounts the directory holding this
  file at `/shmigtest`.

  * A log is created for each line in `test_runner.conf` in the
  `logs` directory.

  * If you need more information, run tests with the DEBUG variable
  set:

      $ DEBUG=1 ./test_runner.sh

  * Each database is tested against the same set of shmig commands,
  which are stored in the file `test_shmig_commands.txt`.  The
  output of all commands is collected in a file, the contents of
  which are compared against the expected output.  If the files
  match, the test passes.
