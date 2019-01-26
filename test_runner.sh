#! /bin/sh
# Run tests for all platform combinations.

Results=results.md

Img="https://cdn.rawgit.com/mbucc/shmig_test/master/badges"

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
  if [ -z "$2" ] ; then
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
  if [ -z "$DEBUG" ] ; then
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

  if [ "$code" = "0" ] ; then
    __ok "$platname"
  else
    __fail "$platname"
  fi

  if [ "$CI" = "1" ] ; then
    if ! git pull >/dev/null 2>&1 ; then
      _err "git pull error"
    fi
    if [ "$code" = "0" ] ; then
      cat "badges/ok.png" > "badges/$statusfile.png"
    else
      cat "badges/ng.png" > "badges/$statusfile.png"
    fi

    git add "badges/$statusfile.png" >/dev/null 2>&1

    url="$Img/$statusfile?$(date +%s)"
    echo "| $shell | $db | ![]($url) | $(date) |" >> "$Results"

  fi
}

_writeShmigConfig() {
  db="$1"

  echo MIGRATIONS=./sql > shmig.conf

  case "$db" in
    sqlite3*)
      echo TYPE=sqlite3           >> shmig.conf
      echo DATABASE=./sql/test.db >> shmig.conf
      ;;
    mysql*)
      echo TYPE=mysql             >> shmig.conf
      echo DATABASE=mysql         >> shmig.conf
      echo LOGIN=root             >> shmig.conf
      echo HOST=db                >> shmig.conf
      ;;
    psql*)
      echo TYPE=postgresql        >> shmig.conf
      echo DATABASE=postgres      >> shmig.conf
      echo LOGIN=postgres         >> shmig.conf
      echo PASSWORD=postgres      >> shmig.conf
      echo HOST=db                >> shmig.conf
      ;;
    *)
      _err "invalid database $db"
      return 1
      ;;
  esac

  return 0

}


_startdb() {
  db="$1"
  logfile="$2"

  _debug "_startdb($db)"

  case "$db" in
    sqlite*)
      _debug "no need to turn Docker for sqlite3"
      rm -f ./sql/test.db
      mkdir -p ./sql
      ;;
    mysql*)
      _debug "starting Docker instance $db"
      docker run --rm \
        -l info \
	-d \
	--name db \
        -e MYSQL_ALLOW_EMPTY_PASSWORD=True \
	"$db" \
         > "$logfile" 2>&1
      if [ $? -ne 0 ]
      then
        _err "Docker failed to start $db"
        return 1
      fi
      ;;
    psql*)
      _debug "starting Docker instance $db"
      docker run --rm \
        -d \
	-l info \
        --name db \
	-e POSTGRES_PASSWORD=postgres \
	"$db" \
         > "$logfile" 2>&1
      if [ $? -ne 0 ]
      then
        _err "Docker failed to start $db"
        return 1
      fi
      ;;
    *)
      _err "Invalid Docker image $db"
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
  if [ "$DEBUG" ] || [ "$DEBUGING" ] ; then
    buildq=""
  fi

  echo "FROM $dockerimg" > "$platname/ClientDockerfile"

  if [ "$install_cmd" ] ; then

    echo "RUN ${update_cmd:+$update_cmd $buildq &&} $install_cmd \\" \
      >> "$platname/ClientDockerfile"

    if [ "$pkgs" ] ; then
      pkgsline=$(echo "$pkgs" |  tr ',' ' ' )

      if [ "$pkgsline" ] ; then
        echo "$pkgsline  $buildq"  >>  "$platname/ClientDockerfile"
      fi

    fi
  fi

  if [ "$DEBUG" ] ; then
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
pkgs()   {
  echo "$1" | cut -d '|' -f 4
}
shell()  {
  echo "$1" | cut -d '|' -f 5
}
shellbasename()  {
  basename "$(echo "$1" | cut -d '|' -f 5)"
}
db()     {
  echo "$1" | cut -d '|' -f 6
}
platname() {
  echo "$(clientimg "$1")-$(shellbasename "$1")-$(db "$1")"
}

# alpine:3.8|apk update|apk add|bash,sqlite|/bin/bash|sqlite
testplat() {

  platline="$1"
  _debug "platline" "$platline"

  platname="$(_normalizeFilename "$(platname "$platline")")"
  dockerimg="$(clientimg "$platline")"
  update_cmd="$(update "$platline")"
  install_cmd="$(install "$platline")"
  pkgs="$(pkgs "$platline")"
  db="$(db "$platline")"
  shell="$(shell "$platline")"


  _debug "platname" "$platname"
  _debug "dockerimg" "$dockerimg"
  _debug "update_cmd" "$update_cmd"
  _debug "install_cmd" "$install_cmd"
  _debug "pkgs" "$pkgs"
  _debug "db" "$db"
  _debug "shell=" "$shell"


  _info "Running $platname, this may take a few minutes, please wait."
  mkdir -p "$platname"

  _writeDockerFile "$platname" "$dockerimg" "$update_cmd" "$install_cmd" "$pkgs"

  Log_Out="$(_getOutfile "$platname")"
  _debug "Log_Out" "$Log_Out"

  if ! _startdb "$db" "$Log_Out" ; then
    update_results "$code" "$platline" "$shell" "$db"
    return "$code"
  fi

  _writeShmigConfig "$db"

  if docker build -t "$platname" -f "$platname/ClientDockerfile" "$platname" > "$Log_Out" 2>&1 ; then

    docker run --net=shmig-net --rm \
      -e DEBUG="$DEBUG" \
      -e DB="$db" \
      -v "$(pwd)":/shmigtest \
      "$platname" "$shell" -c "cd /shmigtest && ./test_shmig.sh" >> "$Log_Out" 2>&1

    code="$?"
    _debug "docker run returned" "$code"

  else
    code="$?"
    _debug "docker build returned" "$code"
    cat "$Log_Out"
  fi

  update_results "$code" "$platline" "$shell" "$db"

  return $code

}

testall() {
  code=0
  docker network create shmig-net
  grep -v '^#' test_runner.conf | while read -r plat
  do
    if [ "$plat" ] ; then
      testplat "$plat"
      code=$(( code + $? ))
    fi
  done
  docker network rm shmig-net
  test "$code" = "0"
  return $?
}


if [ "$CI" = "1" ] ; then
  rm -f "$Results"
  hdr="| Shell | DB  | Result | Test Date |"
  echo "$hdr"  > "$Results"
  echo "| ----- | --- | ------ | --------- |" >> "$Results"
fi

set -x
cat test_runner.conf
grep -v '^#' test_runner.conf
set +x

testall

code="$?"


if [ "$CI" = "1" ] ; then
  cat head.md "$Results" > README.md
  git add README.md >/dev/null 2>&1
  git add logs/* >/dev/null 2>&1
  git commit -m "CI test run" >/dev/null 2>&1
  if ! git push >/dev/null 2>&1 ; then
    _err "git push error"
  fi
fi

exit "$code"
