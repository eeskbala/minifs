
# check for dependencies
function check_host_commands() {
	local allok=1
	#echo "*** Checking for $NEEDED_HOST_COMMANDS"
	for de in $NEEDED_HOST_COMMANDS ; do
		if ! path=$(which "$de"); then
			echo "#### Missing '$de' host command"
			allok=0
		fi
	done
	if [ "$allok" -eq "0" ]; then
		echo "##### Please install the missing host commands"
		exit 1
	fi
}

function hostcheck_commands() {
	for name in $*; do 
		local cmd=$(which $name)
		if [ ! -x "$cmd" ]; then
			echo "### ERROR $PACKAGE needs $name"
			HOSTCHECK_FAILED=1
		fi
	done
}

# split the MINIFS_PATH evn and return all existing directories
# also adding the first parameter to the path
function minifs_path_split() {
	for pd in $(echo "$MINIFS_PATH"| tr ":" "\n") ; do
		if [ -d "$pd/$1" ]; then
			echo "$pd/$1"
		fi
	done
}

# calls an optional function(s)
function optional() {
	for f in $*; do
		if declare -F $f >/dev/null; then
			$f "$@"
		fi
	done
}

function optional_one_of () {
	for f in $*; do
		if declare -F $f >/dev/null; then
			# echo optional-one-of running $f
			$f
			return
		fi
	done
}

function hset() {
	local ka="${1//-/}"
	local kb="${2//-/}"
	eval "$ka$kb"='$3'
}

function hget() {
	local ka="${1//-/}"
	local kb="${2//-/}"
	# echo GET  $1 $2 1>&2
	eval echo '${'"$ka$kb"'#hash}'
}

function package() {
	export MINIFS_PACKAGE="$1"
	export PACKAGE="$1"
	export PACKAGE_DIR="$2"
	local prefix=$(hget $PACKAGE prefix)
	export PACKAGE_PREFIX=${prefix:-/usr}
	pushd "$BUILD/$PACKAGE_DIR" >/dev/null
}
function end_package() {
	#echo "#### Building $PACKAGE DONE"
	PACKAGE=""
	LOGFILE="._stray.log"
	popd  >/dev/null
}

function configure() {
	local turd="._conf_$PACKAGE"
	LOGFILE="$turd.log"
	if [ ! -f $turd ]; then
		echo "     Configuring $PACKAGE"
		rm -f $turd
		echo "$@" >$LOGFILE
		if "$@" >>$LOGFILE 2>&1 ; then
			touch $turd
		else
			echo "#### ** ERROR ** Configuring $PACKAGE"
			echo "     Check $(pwd)/$LOGFILE"
			exit 1
		fi
	fi
}

function compile() {
	local turd="._compile_$PACKAGE"
	LOGFILE="$turd.log"
	if [ ! -f $turd -o "._conf_$PACKAGE" -nt $turd ]; then
		echo "     Compiling $PACKAGE"
		rm -f $turd
		echo "$@" >$LOGFILE
		if "$@" >>$LOGFILE 2>&1 ; then
			touch $turd
		else
			echo "#### ** ERROR ** Compiling $PACKAGE"
			echo "     Check $(pwd)/$LOGFILE"
			exit 1
		fi
	fi
}

function log_install() {
	local turd="._install_$PACKAGE"
	LOGFILE="$turd.log"
	if [ ! -f $turd -o "._compile_$PACKAGE" -nt $turd ]; then
		echo "     Installing $PACKAGE"
		rm -f $turd
		echo "$@" >$LOGFILE
		if "$@" >>$LOGFILE 2>&1 ; then
			touch $turd
		else
			echo "#### ** ERROR ** Installing $PACKAGE"
			echo "     Check $(pwd)/$LOGFILE"
			exit 1
		fi
	fi
}

function deploy() {
	local turd="._deploy_$PACKAGE"
	LOGFILE="$turd.log"
	if [ -f "._install_$PACKAGE" ]; then
		local deployme=$(hget $PACKAGE deploy)
		if ! ${deployme:=true} ; then return 0; fi
		echo "     Deploying $PACKAGE"
		{
			rm -f $turd
			echo "$@" >$LOGFILE
			"$@" && touch $turd 
		} >>$LOGFILE 2>&1 || {
			echo "#### ** ERROR ** Deploying $PACKAGE"
			echo "     Check $BUILD/$PACKAGE/$LOGFILE"
			exit 1
		}
	fi
}

function remove_package() {
	pack=$1
	if [ ! -d "$BUILD"/$pack ]; then
		echo Not removing $pack - was not installed anyway
		return
	fi
	if [ -f "$BUILD/$pack/._dist_$pack.log" ]; then
		echo $pack was installed in staging, trying to remove
		cat "$BUILD/$pack/._dist_$pack.log" | \
			awk -v pp="$STAGING" \
'
{
	if ($2=="open" && match($3,pp)) print $3;
	if ($2=="rename" && match($4,pp)) print $4;
}' | 	xargs rm -f
	fi
	rm -rf "$BUILD"/$pack
	echo Looks like $pack was removed. good luck.
}

# This parses the ,_dist file generated by installwatch
# and return all pathnames that contains $1 as a regexp, while
# removing any occurance of $2 from them, if present
function get_installed_stuff() {
	local dir=$(hget $pack dir)
	dir=${dir:-$pack}
	if [ -f "$BUILD/$dir/._dist_$PACKAGE.log" ]; then
		cat "$BUILD/$dir/._dist_$PACKAGE.log" | \
		awk -v pp="$1" -v ss="$2" \
'
function ppr(s) {
	if (substr(s, length(s)) == "#") return;
	if (ss != "") gsub(ss,"",s); 
	print s;
}
{
	if ($2=="open" && match($3,pp)) l[$3]=$3;
	if ($2=="rename" && match($4,pp)) { delete l[$3]; l[$4]=$4; }
}
END { for (p in l) ppr(p); }
' 
	fi
}

function get_installed_binaries() {
	get_installed_stuff "^$STAGING.*/s?bin/"
}
# same as previous, without the STAGING path at the front
function get_installed_short_binaries() {
	get_installed_stuff "^$STAGING.*/s?bin/" "^$STAGING/?"
}
function get_installed_etc() {
	get_installed_stuff "^$STAGING.*/etc/"
}

deploy_binaries() {
	local tmpf="/tmp/minifs-$MINIFS_BOARD/install-$PACKAGE.lst"
	{
		mkdir -p /tmp/minifs-$MINIFS_BOARD/
		get_installed_short_binaries >$tmpf
		(cd $STAGING; rsync -av --files-from=$tmpf ./ $ROOTFS/ ) >"$tmpf.log"
	} || {
		echo $0 $PACKAGE failed; exit 1
	}
}

function deploy_staging_path() {
	local src=$1
	local param=$2
	local usr=${param:-/usr}
	echo usr=$usr
	shift 2
	mkdir -p "$ROOTFS/$src/"
	rsync "$@" --delete -av "$STAGING$usr/$src/" "$ROOTFS/$src/"
}

function dump_depends() {
	{
	echo 'digraph G { rankdir=LR; node [shape=rect]; '
	local all="$PACKAGES crosstools"
	for pack in $all; do
		deps=$(hget $pack depends)
		echo \"$pack\"
		for d in $deps; do 
			echo "\"$pack\" -> \"$d\""
		done
	done	
	echo '}'
	} >minifs_deps.dot
	dot -Tpdf -ominifs_deps.pdf minifs_deps.dot
}

function package_set_group() {
	local v=$1
	PACKAGE_ORDER=$((v * 1000))
#	echo GROUP $PACKAGE_ORDER
}

function package_register() {
	PACKAGES+=" $1"
	hset $1 order $PACKAGE_ORDER
	echo $1 $PACKAGE_ORDER
	let PACKAGE_ORDER=PACKAGE_ORDER+1
}
