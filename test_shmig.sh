#! /bin/sh

#
# 		Run shmig commands one-by-one.
#

F=1.out
E=2.out
rm -f $F
rm -f $E
while IFS= read -r cmd; do

  printf "\n%s\n---------------\n" "$cmd" >>$F

  ./shmig -c ./shmig.conf "$cmd" >>$F 2>>$E

done < test_shmig_commands.txt


#
#		In output, replace time stamps with the string "*now*".
#
#               Also, change tabs to '|' in MySQL output so we can
#		use the same expected files for each database.
#

sed 's/20..-[012].-[0123]. ..:..:..\(\.[0-9]*\)*/*now*/' $F \
  | sed 's/	/|/g' \
  > stdout.actual

mv $E stderr.actual

#
#		Check stdout and stderr against expected values.
#


rval=0
if diff -uw test_shmig_stdout.expected stdout.actual >/dev/null; then
  printf "		stdout: PASS\n"
else
  printf "		stdout: FAIL\n"
  diff -uw test_shmig_stdout.expected stdout.actual
  rval=1
fi

if diff -uw test_shmig_stderr.expected stderr.actual >/dev/null; then
  printf "		stderr: PASS\n"
else
  printf "		stderr: FAIL\n"
  diff -uw test_shmig_stderr.expected stderr.actual
  rval=1
fi

exit $rval
