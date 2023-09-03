#!/bin/zsh
# made on cygwin

[ $# -eq 0 -o "$1" = "-?" ] && {
	echo "oh-ex-oh - 0x0.st file uploader and manager"
	echo;echo "usage: oxo file [options]"
	echo "options:"
	echo "    -e T        delete the file in T hours or delete"
	echo "                on T (date/epoch timestamp*) after uploading"
	echo "    -s          make accessing the uploaded file"
	echo "                require a more secret link"
	echo "    -d          don't save upload's management token"
	echo "    -H,         change 0x0.st host (default: https://0x0.st)"
	echo "    host=...    in oxocfg"
	echo "    -i          interactive mode (ignores all other"
	echo "                                  options besides host)"
	echo "    -?          display this help page"
	echo "special filenames:"
	#echo "    -           upload data from stdin"
	echo "    http://...  upload from URL"
	echo "    ?****       manage 0x0 upload, where **** is the ID"
	echo "                of the upload (ignores all above options"
	echo "management options:"
	echo "    these will only work if you didn't use -d for the"
	echo "    file you uploaded and are going to manage"
	echo "    -t T        manually input token T"
	echo "    -e [T]      set the upload to be deleted in T hours"
	echo "                or delete on T (date/epoch timestamp*),"
	echo "                or don't specify T to get the expiry date"
	echo "    -d          delete the upload immediately"
	echo "(*timestamp in seconds)"
	echo
	echo "made for https://0x0.st"
	exit
}
argcheck() {
	[ $1 -lt 2 ] && { echo "Missing value for $2"; exit }
}
alias checkfile='[ -n "$file" ] && {
	echo "Ignoring stray argument $1"
	shift
	continue
}'
nul=/dev/null
{
	host=
	mode=0
	secret=0
	dswitch=0
	intrctv=0
	token=
	exp=
	file=
	while (($#)); do
		case "$1" in
			#-) # pipe
			#	checkfile
			#	file=/dev/stdin
			#	;;
			-*)
				case "$1" in
					# this has to be optimized
					"-e") # expire argument
						argcheck $# "$1"
						exp="$2"
						shift
					;;
					"-s") # secret link
						secret=1
					;;
					"-d") # don't save token or delete upload
						dswitch=1
					;;
					"-H") # custom host
						[ -n "$host" ] && {
							echo "Ignoring stray host argument ${2:-2}"
							shift 2 2>$nul
							continue
						}
						argcheck $# "$1"
						host="$2"
						shift
					;;
					"-i") # interactive
						intrctv=1
					;;
					"-t") # token
						argcheck $# "$1"
						token="$2"
						shift
					;;
					*)
						echo "Invalid switch $1"
						exit
				esac
				;;
			# don't know if order matters here
			# so leaving this as is
			\?*)
				checkfile
				mode=1
				file="${1:1}"
				;;
			*)
				checkfile
				mode=0
				file="$1"
		esac
		shift
	done
	[ -n "$token" -a $mode -eq 0 ] && {
		echo "Warning: Token argument specified in wrong mode"
	}
	[ -z "$file" ] && {
		echo "Missing file argument"
		exit
	}
}

# gray text overriding other colors is pissing me off (notepad++)
absp() {
	# ensure path has explicit directory defined
	[ ! "$(dirname "$1")" = "." ] && i="$(which "$1")/" || i="$(realpath "$1")/"
	echo "$(dirname "$i")/"
}
p=$(absp "$0")
trim() {
	# trim trailing and leading spaces
	# doesn't work on dash
	i=1
	while [ "${1[$i]}" = " " ]; do
		i=$(($i+1))
	done
	j=-1
	while [ "${1[$j]}" = " " ]; do
		j=$(($j-1))
	done
	echo ${1[$i,$j]}
}
nl=$'\n'
__kv__() {
	# key value getter
	[ -z "$1" ] && { echo "$0: $ll: Missing key">&2; return 1; }
	# pointless condition when the config will be in the same place
	# and there will be no instance where there's another config elsewhere
	# besides maybe tokens
	[ -z "$3" ] && f="${p}oxocfg" || f="$(absp "$3")/$(basename "$3")"
	[ -e "$f" ] && while IFS='=' read -r k v; do
		[ "$(trim "$k")" = "$(trim "$1")" ] && {
			trim "$v"
			return 0
		}
		# doesn't read last keyvalue if there's not a newline after >:(
	done < "$f"
	[ -n "$2" ] && trim "$2"
	return 0
}
__skv__() {
	# setter
	[ -z "$1" ] && { echo "$0: $ll: Missing key">&2; return 1; }
	# delete key if value blank :/
	# [ -z "$2" ] && { echo "$0: $ll: kv: Missing value">&2; return 1; }
	[ -z "$3" ] && f="${p}oxocfg" || f="$(absp "$3")/$(basename "$3")"
	# i'm fully redpilled on [ ] + logic ops, thanks luke
	[ ! -e "$f" ] && {
		echo $1 = $2> "$f"
	} || {
		file=
		got=0
		delete=0
		while IFS='=' read -r k v; do
			[ -n "$k" ] && {
				[ "$(trim "$k")" = "$(trim "$1")" ] && {
					[ -z "$(trim "$2")" ] && delete=1
					v=$(trim "$2")
					got=1
				}
				[ $delete -eq 0 ] &&
					file="${file}$(trim "$k") = $(trim "$v")${nl}" ||
					file="${file[0,-1]}"
			} || file="${file}${nl}" # just because
		done < "$f"
		[ $got -eq 0 -a -n "$2" ] && {
			echo a
			file="${file}$(trim "$1") = $(trim "$2")${nl}"
		}
		echo "${file[0,-2]}" > "$f"
	}
	return 0
}
alias kv='ll=$LINENO;__kv__' # HACK!111!!
alias skv='ll=$LINENO;__skv__'
u_min_age=$(kv host_min_age 30)
u_max_age=$(kv host_max_age 365)
u_max_size=$((512*1024*1024))
retention() {
	echo $(( ${u_min_age} + (-(${u_max_age}) + ${u_min_age}) * (($1.0/${u_max_size} - 1)**3) ))
}

host=${host:-"$(kv host "https://0x0.st")"}

[ -n "$file" ] && {
	typeset -a argbuilder
	argbuilder=()
	[ $secret -eq 1 ] &&
		argbuilder+=(-F\"secret=\")
	[ -n "$exp" ] && {
		hours=0
		# stupid hacks to check time format or hours
		[ $exp -gt 0 ] 2>$nul && {
			[ $exp -gt 1650460320 ] && {
				exp=$(date --date="@$exp")
			} || {
				hours=1
			}
		} || {
			[ $exp -eq 0 ] 2>$nul && {
				exp=
			} && {
				echo $exp
				exp=$(date --date="$exp")
				[ $? -gt 0 ] && exit
			}
		}
		# definitely redundant
		[ $hours -eq 0 ] && exp="$(date --date="$exp" +"%s")"
		argbuilder+=("-F\"expires=$exp\"")
	}
	[ $dswitch -eq 0 ] && {
		argbuilder+=(-D -)
	}
	[ "${file[0,7]}" = "http://" -o "${file[0,8]}" = "https://" ] && {
		argbuilder+=(-F"url=$file")
	#} || [ "$file" = "-" ] && {
	#	#curl -F"file="
	} # why can't i do || with this
	[ -e "$file" -a $? -eq 1 ] && {
		#[ "$file" != "/dev/stdin" ] && {
			argbuilder+=(-F"file=@$file")
		# NOT WORKING
		#} || {
		#	[ -t 0 ] && echo Press Ctrl-D to finish input.
		#	argbuilder+=(--form-string "file=test why isn't this working")
		#}
		(exit 0)
	} || {
		echo "File '$file' does not exist."
	}
	
	(curl -f ${argbuilder[@]} -o - "$host" --progress-bar | grep -E "^(X-Expires|X-Token|$host)" | sed 's/\r$//') | while read -r t; do
		case "${t:0:9}" in
			"X-Expires")
				exp=$(date --date="@$((${t:11} / 1000))")
				;;
			"X-Token: ")
				token=${t:9}
				;;
			"${host:0:9}")
				path=${t}
				;;
		esac
	done
	echo Expires $exp
	echo Token $token
	echo Path $path
}

