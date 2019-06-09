#! /bin/sh
# Run tests for all platform combinations.
#
# shfmt -i 2 -sr -ci -w test_runner.sh

Results=results.md

Img="https://raw.githubusercontent.com/mbucc/shmig_test/master"

__ok() {
  echo "$1 [PASS]"
}

__fail() {
  echo "$1 [FAIL]" >&2
  return 1
}

_date_u() {
  date -u +"%a, %d %b %Y %T %Z"
}

_info() {
  if [ -z "$2" ]; then
    echo "[$(date)] $1"
  else
    echo "[$(date)] $1"="'$2'"
  fi
}

_err() {
  _info "$@" >&2
  return 1
}

_debug() {
  if [ -z "$DEBUG" ]; then
    return
  fi
  _err "$@"
  return 0
}

#alpine:3.8-bash-mysql:8
_normalizeFilename() {
  _nplat="$1"
  printf "%s" "$_nplat" | tr ':/ \\' '----'
}

#alpine:3.8-bash-mysql:8
_getOutfile() {
  _gnplat="$1"
  statusfile="$(_normalizeFilename "$_gnplat")"
  mkdir -p logs
  printf "%s" "logs/$statusfile.out"
}

# alpine:3.8|apk update|apk add|bash,sqlite|/bin/bash|sqlite
update_results() {

  code="$1"
  platname="$2"
  shell="$3"
  db="$4"
  dockerimg="$5"

  if [ "$code" = "0" ]; then
    __ok "$platname"
  else
    __fail "$platname"
  fi

  if [ "$CI" = "1" ]; then
    if ! git pull > /dev/null 2>&1; then
      _err "git pull error"
    fi
    badge="badges/$platname.png"
    if [ "$code" = "0" ]; then
      cat "badges/ok.png" > "$badge"
    else
      cat "badges/ng.png" > "$badge"
    fi

    git add "$badge" > /dev/null 2>&1

    badgeurl="$Img/${badge}?$(date +%s)"
    logurl="$Img/logs/$platname.out?$(date +%s)"
    echo "| $dockerimg | $shell | $db | ![]($badgeurl) | $(date) ([log]($logurl)) |" >> "$Results"

  fi
}

_writeShmigConfig() {
  dbimg="$1"

  echo MIGRATIONS=./sql > shmig.conf

  case $(imgtodb "$dbimg") in
    SQLITE)
      echo TYPE=sqlite3 >> shmig.conf
      echo DATABASE=./sql/test.db >> shmig.conf
      ;;
    MYSQL)
      echo TYPE=mysql >> shmig.conf
      echo DATABASE=mysql >> shmig.conf
      echo LOGIN=root >> shmig.conf
      echo HOST=db >> shmig.conf
      ;;
    POSTGRES)
      echo TYPE=postgresql >> shmig.conf
      echo DATABASE=postgres >> shmig.conf
      echo LOGIN=postgres >> shmig.conf
      echo PASSWORD=postgres >> shmig.conf
      echo HOST=db >> shmig.conf
      ;;
    *)
      _err "invalid database $dbimg"
      return 1
      ;;
  esac

  return 0

}



imgtodb() {
  dbimg="$1"
  if echo "$dbimg" | grep -i "sqlite" > /dev/null ; then
    echo "SQLITE"
  elif echo "$dbimg" | grep -i "mysql" > /dev/null ; then
    echo "MYSQL"
  elif echo "$dbimg" | grep -i "psql" > /dev/null ; then
    echo "POSTGRES"
  elif echo "$dbimg" | grep -i "postgres" > /dev/null ; then
    echo "POSTGRES"
  else
    echo "UKNOWN"
  fi
}

_startdb() {
  dbimg="$1"
  logfile="$2"

  _debug "_startdb($dbimg)"

  case $(imgtodb "$dbimg") in
    SQLITE)
      _debug "no need to turn Docker for sqlite3"
      rm -f ./sql/test.db
      mkdir -p ./sql
      ;;
    MYSQL)
      _debug "starting Docker instance $dbimg"
      docker run --rm \
        --net=shmig-net \
        -l info \
        -d \
        --name db \
        -e MYSQL_ALLOW_EMPTY_PASSWORD=True \
        "$dbimg" \
        >> "$logfile" 2>&1
      if [ $? -ne 0 ]; then
        _err "Docker failed to start $dbimg"
        return 1
      fi

      # Wait for it ...

      _debug "Waiting for $dbimg database to start ..."
      attempts_left=100
      until docker run --rm --net shmig-net "$dbimg" mysqladmin -h db ping >> "$logfile" 2>&1 ;
      do
        attempts_left=$(( attempts_left - 1 ))
	if [ $attempts_left -lt 1 ] ; then
	  break
	fi
        sleep 1
      done
      ;;

    POSTGRES)
      _debug "starting Docker instance $dbimg"
      docker run --rm \
        --net=shmig-net \
        -d \
        -l info \
        --name db \
        -e POSTGRES_PASSWORD=postgres \
        "$dbimg" \
        > "$logfile" 2>&1
      if [ $? -ne 0 ]; then
        _err "Docker failed to start $dbimg"
        return 1
      fi

      # Wait for it ...

      _debug "Waiting for $dbimg to start ..."
      attempts_left=15
      until docker run --rm --net shmig-net "$dbimg" pg_isready -h db -t 3 >> "$logfile" 2>&1 ;
      do
        attempts_left=$(( attempts_left - 1 ))
	if [ $attempts_left -lt 1 ] ; then
	  break
	fi
        sleep 1
      done
      ;;

    *)
      _err "Invalid Docker image $dbimg"
      return 1
      ;;
  esac

  return 0

}

# alpine:3.8-bash-mysql:8|apk update_cmd -f|apk --no-cache add -f|bash,mysql-client|/bin/bash
_writeDockerFile() {

  platname="$1"
  dockerimg="$2"
  update_cmd="$3"
  install_cmd="$4"
  pkgs="$5"

  buildq="2>&1"
  if [ "$DEBUG" ] || [ "$DEBUGING" ]; then
    buildq=""
  fi

  echo "FROM $dockerimg" > "$platname/ClientDockerfile"

  if [ "$install_cmd" ]; then

    echo "RUN ${update_cmd:+$update_cmd $buildq &&} $install_cmd \\" \
      >> "$platname/ClientDockerfile"

    if [ "$pkgs" ]; then
      pkgsline=$(echo "$pkgs" | tr ',' ' ')

      if [ "$pkgsline" ]; then
        echo "$pkgsline  $buildq" >> "$platname/ClientDockerfile"
      fi

    fi
  fi

  if [ "$DEBUG" ]; then
    cat "$platname/ClientDockerfile"
  fi

}

# alpine:3.8|apk update|apk add|bash,sqlite|/bin/bash|sqlite
clientimg() {
  echo "$1" | cut -d '|' -f 1
}
update() {
  echo "$1" | cut -d '|' -f 2
}
install() {
  echo "$1" | cut -d '|' -f 3
}
pkgs() {
  echo "$1" | cut -d '|' -f 4
}
shell() {
  echo "$1" | cut -d '|' -f 5
}
dbimg() {
  echo "$1" | cut -d '|' -f 6
}
shellbasename() {
  basename "$(echo "$1" | cut -d '|' -f 5)"
}
platname() {
  echo "$(clientimg "$1")-$(shellbasename "$1")-$(dbimg "$1")"
}

# alpine:3.8|apk update|apk add|bash,sqlite|/bin/bash|sqlite
testplat() {

  platline="$1"
  _debug "platline" "$platline"

  platname="$(_normalizeFilename "$(platname "$platline")")"
  clientimg="$(clientimg "$platline")"
  update_cmd="$(update "$platline")"
  install_cmd="$(install "$platline")"
  pkgs="$(pkgs "$platline")"
  dbimg="$(dbimg "$platline")"
  shell="$(shell "$platline")"

  _debug "platname" "$platname"
  _debug "clientimg" "$clientimg"
  _debug "update_cmd" "$update_cmd"
  _debug "install_cmd" "$install_cmd"
  _debug "pkgs" "$pkgs"
  _debug "dbimg" "$dbimg"
  _debug "shell=" "$shell"

  _info "Running $platname, this may take a few minutes, please wait."
  mkdir -p "$platname"

  _writeDockerFile "$platname" "$clientimg" "$update_cmd" "$install_cmd" "$pkgs"

  Log_Out="$(_getOutfile "$platname")"
  _debug "Log_Out" "$Log_Out"

  if ! _startdb "$dbimg" "$Log_Out"; then
    update_results "1" "$platname" "$shell" "$dbimg" "$clientimg"
    return 1
  fi

  _writeShmigConfig "$dbimg"

  if docker build -t "$platname" -f "$platname/ClientDockerfile" "$platname" > "$Log_Out" 2>&1; then

    docker run --net=shmig-net --rm \
      -e DEBUG="$DEBUG" \
      -e DB="$dbimg" \
      -v "$(pwd)":/shmigtest \
      "$platname" "$shell" -c "cd /shmigtest && ./test_shmig.sh" >> "$Log_Out" 2>&1

    code="$?"
    _debug "docker run returned" "$code"

  else
    code="$?"
    _debug "docker build returned" "$code"
    cat "$Log_Out"
  fi

  update_results "$code" "$platname" "$shell" "$dbimg" "$clientimg"

  return $code

}

testall() {
  local testall_rc=0
  docker network create shmig-net
  # The normal behavior, followed by all Bourne/POSIX shells (dash,
  # ksh, pdksh, mksh, bash, zsh even when not in sh emulation mode,
  # BusyBox sh, Bourne shell, …) is that read -r line strips leading
  # and trailing whitespace characters.
  #
  # If you want no stripping, the standard method is to run
  #   IFS= read -r
  # ref: https://unix.stackexchange.com/a/383574
  #
  # Stripping is fine here, so no IFS=
  #
  # Also, posix does not support subprocesses (that is,
  #
  #     done < <(grep -v '^#' test_runner.comf)
  #
  # and mkfifo seemed heavy, so just skip lines that start with comment.
  # ref: https://stackoverflow.com/a/38796342
  while read -r plat; do
    _debug "$plat"
    if echo "$plat" | grep '^#' > /dev/null; then
      continue
    fi
    if [ "$plat" ]; then
      testplat "$plat"
      testall_rc=$((testall_rc + $?))
      docker rm -f db > /dev/null 2>&1
    fi
  done < test_runner.conf

  docker network rm shmig-net > /dev/null 2>&1
  test "$testall_rc" = "0"
  return $?
}

if [ "$CI" = "1" ]; then
  rm -f "$Results"
  echo "| Client | Shell | DB  | Result | Test Date |" > "$Results"
  echo "| ------ | ----- | --- | ------ | --------- |" >> "$Results"
fi

testall

code="$?"

if [ "$CI" = "1" ]; then
  cat head.md "$Results" > README.md
  git add README.md > /dev/null 2>&1
  git add logs/* > /dev/null 2>&1
  git commit -m "CI test run" > /dev/null 2>&1

  # Decode private deploy SSH key
  openssl aes-256-cbc -k "$travis_key_password" -md sha256 -d -a -in travis_key.enc -out ./travis_key
  chmod 400 ./travis_key
  echo "Host github.com" > ~/.ssh/config
  echo "  IdentityFile $(pwd)/travis_key" >> ~/.ssh/config
  git remote set-url origin git@github.com:mbucc/shmig_test.git
  if [ "$DEBUG" ]; then
    cat ~/.ssh/config
    pwd
    ls -l "$(pwd)/travis_key"
    git remote -v
    ssh -T git@github.com
  fi
  echo "github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==" > ~/.ssh/known_hosts

  if ! git push -v; then
    _err "git push error"
  fi
fi

exit "$code"
