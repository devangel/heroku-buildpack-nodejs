
warn() {
    echo -e >&2 "${YELLOW} !     $@${NC}"
}

step() {
    echo "$steptxt $@"
}

start() {
    echo -n "$steptxt $@... "
}

finished() {
    echo "done"
}

# Go releases have moved to a new URL scheme
# starting with Go version 1.2.2. Return the old
# location for known old versions and the new
# location otherwise.
urlfor() {
    ver=$1
    file=$2
    case $ver in
    go1.0*|go1.1beta*|go1.1rc*|go1.1|go1.1.*|go1.2beta*|go1.2rc*|go1.2|go1.2.1)
        echo http://go.googlecode.com/files/$file
        ;;
    *)
        echo https://storage.googleapis.com/golang/$file
        ;;
    esac
}

# Expand to supported versions of Go, (e.g. expand "go1.5" to latest release go1.5.2)
# All specific or other versions, take as is.
expand_ver() {
  case $1 in
    go1.6)
      echo "go1.6beta1"
      ;;
    go1.5)
      echo "go1.5.2"
      ;;
    go1.4)
      echo "go1.4.3"
      ;;
    *)
      echo "$1"
      ;;
  esac
}

# Report deprecated versions to user
# Use after expand_ver
report_ver() {
  case $1 in
    go1.6beta1|go1.5.2|go1.4.3)
      # Noop
    ;;
    *)
      warn ""
      warn "Deprecated version of go ($1)"
      warn "See https://devcenter.heroku.com/articles/go-support#go-versions for supported version information."
      warn ""
    ;;
  esac
}

installGo() {
  #set -e            # fail fast
  #set -o pipefail   # don't ignore exit codes when piping output
  # set -x          # enable debugging

  YELLOW='\033[1;33m'
  NC='\033[0m' # No Color

  mkdir -p "$build_dir" "$cache_dir" 
  build=$(cd "$build_dir/" && pwd)
  cache=$(cd "$cache_dir/" && pwd)
  buildpack=$(cd "$(dirname $0)/.." && pwd)
  arch=$(uname -m|tr A-Z a-z)
  if test $arch = x86_64
  then arch=amd64
  fi
  plat=$(uname|tr A-Z a-z)-$arch

  #GOVERSION="1.3.3"
  PLATFORMS="darwin/386 darwin/amd64 linux/386 linux/amd64 linux/arm windows/386 windows/amd64"
  BUILD_HOST_OS=$(uname|tr A-Z a-z)
  BUILD_HOST_ARCH=$arch

  ver=$(expand_ver $GOVERSION)

  file=${GOFILE:-$ver.linux-amd64.tar.gz}
  url=${GOURL:-$(urlfor $ver $file)}

  go_url=url

  if test -e $build/bin && ! test -d $build/bin
  then
      warn ""
      warn "File bin exists and is not a directory."
      warn ""
      exit 1
  fi

  report_ver $ver

  if test -d $cache/$ver/go
  then
      step "Using $ver"
      ls -l $cache/$ver/go
  else
      rm -rf $cache/* # be sure not to build up cruft
      mkdir -p $cache/$ver
      cd $cache/$ver
      start "Installing $ver"
          curl -s $url | tar zxf -
      finished
      cp -r go "$buld_dir/vendor"
      mkdir -p $build_dir/work/src
      cd - >/dev/null
  fi 

  export GOROOT="${build_dir}/vendor/go"
  export GOPATH="${build_dir}/work/src"
  export PATH="${GOROOT}/bin:$PATH"

  #cd $build_dir
  #echo "-----> Tarballing linux-amd64-go-cc-build.tar.gz go..."
  #tar -zcf go${GOVERSION}-${BUILD_HOST_OS}-${BUILD_HOST_ARCH}-go-cc-build.tar.gz go
  #mv $build_dir/go $build_dir/vendor/lib/go

  export PATH="vendor/bin:$PATH"
  export S3_ACCESS_KEY_ID="${AWS_ACCESS}"
  echo -n $AWS_SECRET > secretkey.txt
  export S3_SECRET_ACCESS_KEY=$(cat secretkey.txt)

  #echo "-----> Uploading tarball to gobuilds/go${GOVERSION}-${BUILD_HOST_OS}-${BUILD_HOST_ARCH}cc.tar.gz..."
  #$bp_dir/vendor/bin/s3 put "force-cli" "gobuilds/go${GOVERSION}-${BUILD_HOST_OS}-${BUILD_HOST_ARCH}cc.tar.gz" $build_dir/go${GOVERSION}-${BUILD_HOST_OS}-${BUILD_HOST_ARCH}-go-cc-build.tar.gz

  $rm -rf $build_dir/go${GOVERSION}-${BUILD_HOST_OS}-${BUILD_HOST_ARCH}-go-cc-build.tar.gz
  #echo "-----> Crosscompile build complete for go ${GOVERSION}"
  #echo "-----> Binaries have been saved to S3 force-cli/gobuilds/go${GOVERSION}-${BUILD_HOST_OS}-${BUILD_HOST_ARCH}-go-cc.tar.gz"

  #exitcode=$?
}
