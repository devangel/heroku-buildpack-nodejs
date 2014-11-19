error() {
  echo " !     $*" >&2
  exit 1
}

status() {
  echo "-----> $*"
}

protip() {
  echo
  echo "PRO TIP: $*" | indent
  echo "See https://devcenter.heroku.com/articles/nodejs-support" | indent
  echo
}

install_aws() {
  echo "Installing s3 cli......."
  cd $1
  wget https://s3.amazonaws.com/aws-cli/awscli-bundle.zip -nv
  unzip awscli-bundle.zip
  ./awscli-bundle/install -b vendor/bin/aws -i vendor/lib/aws
}

# sed -l basically makes sed replace and buffer through stdin to stdout
# so you get updates while the command runs and dont wait for the end
# e.g. npm install | indent
indent() {
  c='s/^/       /'
  case $(uname) in
    Darwin) sed -l "$c";; # mac/bsd sed: -l buffers on line boundaries
    *)      sed -u "$c";; # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
  esac
}

cat_npm_debug_log() {
  test -f $build_dir/npm-debug.log && cat $build_dir/npm-debug.log
}

export_env_dir() {
  env_dir=$1
  whitelist_regex=${2:-''}
  blacklist_regex=${3:-'^(PATH|GIT_DIR|CPATH|CPPATH|LD_PRELOAD|LIBRARY_PATH)$'}
  if [ -d "$env_dir" ]; then
    for e in $(ls $env_dir); do
      echo "$e" | grep -E "$whitelist_regex" | grep -qvE "$blacklist_regex" &&
      export "$e=$(cat $env_dir/$e)"
      :
    done
  fi
}

type setopt >/dev/null 2>&1 && setopt shwordsplit
#PLATFORMS="darwin/386 darwin/amd64 linux/386 linux/amd64 windows/386 windows/amd64"
PLATFORMS="darwin/amd64"


function go-alias {
	GOOS=${1%/*}
	GOARCH=${1#*/}
	eval "function go-${GOOS}-${GOARCH} { ( GOOS=${GOOS} GOARCH=${GOARCH} go \"\$@\" ) }"
}

function go-crosscompile-build {
	GOOS=${1%/*}
	GOARCH=${1#*/}
	cd $GOROOT/src ; GOOS=${GOOS} GOARCH=${GOARCH} ./make.bash --no-clean 2>&1
}

function go-crosscompile-build-all {
	FAILURES=""
	for PLATFORM in $PLATFORMS; do
		CMD="go-crosscompile-build ${PLATFORM}"
		echo "$CMD"
		$CMD || FAILURES="$FAILURES $PLATFORM"
	done
	if [ "$FAILURES" != "" ]; then
	    echo "*** go-crosscompile-build-all FAILED on $FAILURES ***"
	    return 1
	fi
}

function go-all {
	FAILURES=""
	for PLATFORM in $PLATFORMS; do
		GOOS=${PLATFORM%/*}
		GOARCH=${PLATFORM#*/}
		CMD="go-${GOOS}-${GOARCH} $@"
		echo "$CMD"
		$CMD || FAILURES="$FAILURES $PLATFORM"
	done
	if [ "$FAILURES" != "" ]; then
	    echo "*** go-all FAILED on $FAILURES ***"
	    return 1
	fi
}

function go-build-all {
	FAILURES=""
	for PLATFORM in $PLATFORMS; do
		GOOS=${PLATFORM%/*}
		GOARCH=${PLATFORM#*/}
		SRCFILENAME=`echo $@ | sed 's/\.go//'`
		CURDIRNAME=${PWD##*/}
		OUTPUT=${SRCFILENAME:-$CURDIRNAME} # if no src file given, use current dir name
		CMD="go-${GOOS}-${GOARCH} build -o $OUTPUT-${GOOS}-${GOARCH} $@"
		echo "$CMD"
		$CMD || FAILURES="$FAILURES $PLATFORM"
	done
	if [ "$FAILURES" != "" ]; then
	    echo "*** go-build-all FAILED on $FAILURES ***"
	    return 1
	fi
}

for PLATFORM in $PLATFORMS; do
	go-alias $PLATFORM
done

unset -f go-alias
