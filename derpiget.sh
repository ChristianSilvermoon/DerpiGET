#!/bin/bash
version="19.9.16"
script="$(dirname "$0")/$(basename "$0")"

stderr() {
	cat - 1>&2
}

checkDepends() {

	local depends='wget jq'
	local missing=""

	for dep in $depends; do
		if [ "$(command -v "$dep")" = "" ]; then
			missing+="$dep "
		fi
	done

	if [ "$missing" != "" ]; then
		echo -e "\e[1mYou are missing dependencies:\e[0m"
		echo "$missing" | tr ' ' '\n'
		return 1
	else
		return 0
	fi

}

setDerpiFilter() {
	case "$1" in
		"default")
			derpiFilter="100073"
			;;
		"legacy")
			derpiFilter="37431"
			;;
		"everything"|"")
			derpiFilter="56027"
			;;
		"dark")
			derpiFilter="37429"
			;;
		"r34")
			derpiFilter="37432"
			;;
		*)
			if [ "$(grep -E "^[0-9]+$" <<< "$1")" != "" ]; then
				derpiFilter="$1"
			else
				echo "Invalid Derpibooru Filter: $1" | stderr
				echo "Use default, legacy, everything, dark, r34, or a numeric ID" | stderr
				exit 1
			fi
			;;
		esac
}

defaultConf() {
	# Initialize XDG Vars if unset
	[ "$XDG_DATA_HOME" = "" ] && XDG_DATA_HOME="$HOME/.local/share"
	[ "$XDG_CONFIG_HOME" = "" ] && XDG_CONFIG_HOME="$HOME/.config"

	# Load config
	unset CONF
	unset CONF_DATA
	protocol="https"
	domain="derpibooru.org"
	setDerpiFilter "default"
}


loadConf() {
	# Initialize XDG Vars if unset
	[ "$XDG_DATA_HOME" = "" ] && XDG_DATA_HOME="$HOME/.local/share"
	[ "$XDG_CONFIG_HOME" = "" ] && XDG_CONFIG_HOME="$HOME/.config"

	# Load config
	if [ "$1" != "" ]&&[ -e "$1" ]; then
		CONF="$1"
	elif [ -e "$HOME/.derpigetrc" ]; then
		CONF="$HOME/.derpigetrc"
	elif [ -e "$XDG_CONFIG_HOME/derpiget.conf" ]; then
		CONF="$XDG_CONFIG_HOME/derpiget.conf"
	elif [ -e "$XDG_DATA_HOME/derpiget/derpiget.conf" ]; then
		CONF="$XDG_DATA_HOME/derpiget/derpiget.conf"
	elif [ -e "/etc/derpiget.conf" ]; then
		CONF="/etc/derpiget.conf"
	fi

	# Actually DO the loading
	if [ "$CONF" != "" ]; then
		CONF_DATA="$(cat "$CONF")"

		# HTTP or HTTPS
		if [ "$(grep "^protocol" <<< "$CONF_DATA" | cut -d = -f 2)" != "" ]; then
			protocol="$(grep "^protocol" <<< "$CONF_DATA" | cut -d = -f 2)"

			if [ "$protocol" != "http" ]&&[ "$protocol" != "https" ]; then
				echo "Invalid Protocol: $protocol" | stderr
				exit 1
			fi
		fi

		# Target Domain
		if [ "$(grep "^domain" <<< "$CONF_DATA" | cut -d = -f 2)" != "" ]; then
			domain="$(grep "^domain" <<< "$CONF_DATA" | cut -d = -f 2)"
		fi

		# Filter ID
		if [ "$(grep "^filter" <<< "$CONF_DATA" | cut -d = -f 2)" != "" ]; then
			setDerpiFilter "$(grep "^filter" <<< "$CONF_DATA" | cut -d = -f 2)"
		fi
	fi
}

log() {
	if [ "$opt_quiet" != "true" ]; then
		echo $@
	fi
}

helpMsg() {
	echo -e "DerpiGET, version: $version"
	echo -e "USAGE: derpiget [opt] <id|post link> \n"

	printf "  %-26s %s\n" "-?, --help" "Display this message"
	printf "  %-26s %s\n" "-c, --config" "Print Configuration to stdout"
	printf "  %-26s %s\n" "--config=<file>" "Use a config file; empty forces default config"
	printf "  %-26s %s\n" "--domain=<domain>" "Set Target Domain"
	printf "  %-26s %s\n" "-h, --http" "Don't use HTTPS"
	printf "  %-26s %s\n" "-H, --https" "Use HTTPS"
	printf "  %-26s %s\n" "--filter=<ID>" "Set Derpibooru filter ID"
	printf "  %-26s %s\n" "-m, --meta" "Save Meta Data to file"
	printf "  %-26s %s\n" "-M, --meta-only" "Save Meta Data to file, don't download post"
	printf "  %-26s %s\n" "-n, --no-save" "Don't save anything"
	printf "  %-26s %s\n" "-q, --quiet" "Run silently and non-intractively"
	printf "  %-26s %s\n" "-p, --print-meta" "Print Meta Data to stdout"
	printf "  %-26s %s\n" "--search=<query>" "Return list of matching post URLs"
	printf "  %-26s %s\n" "-s, --short-name" "Name files after their ID numbers"
	exit
}

searchDerpi() {
	local query=$(echo "$1" |
	sed 's/ /%20/g' |
	sed 's/!/%21/g' |
	sed 's/#/%23/g' |
	sed 's/\$/%24/g' |
	sed 's/&/%26/g' |
	tr "'" '!' |
	sed 's/!/%27/g' |
	sed 's/(/%28/g' |
	sed 's/)/%29/g' |
	sed 's/*/%2A/g' |
	sed 's/+/%2B/g' |
	sed 's/,/%2C/g' |
	sed 's/\//%2F/g' |
	sed 's/:/%3A/g' |
	sed 's/;/%3B/g' |
	sed 's/=/%3D/g' |
	sed 's/?/%3F/g' |
	sed 's/@/%40/g' |
	sed 's/\[/%5B/g' |
	sed 's/\]/%5D/g')

	page="1"
	url="$protocol://$domain/search.json?q=$query&filter_id=$derpiFilter&perpage=50"
	links=""
	surl+="$url&page=$page"
	cur="$(wget -qO- $surl)"

	total="$(jq -r ".total" <<< "$cur")"

	i=0
	until [ "$postsLeft" = "false" ]; do
		id=$(jq -r ".search[$i].id" <<< "$cur")

		if [ "$id" = "null" ]; then
			if [ "$i" -lt 50 ]; then
				postsLeft="false"
				break
			fi
			((page++))
			i=0
			surl+="$url&page=$page"
			cur="$(wget -qO- $surl)"

		else
			links+="$protocol://$domain/$id "
			((i++))
		fi
	done

	echo "$links" | tr ' ' '\n'
	exit
}

parseArgs() {
	local ignore=0
	local noOpt="false"
	local noTarget="false"
	mode="get"


	# Init Defaults
	opt_savePost="true"
	opt_shortName="false"
	opt_saveMeta="false"
	opt_quiet="false"
	targets=""
	targetLimit=""

	for arg in "$@"; do
		if [ "$ignore" -gt 0 ]; then
			((ignore--))
			continue
		fi

		if [ "$noOpt" = "false" ]&&[ "$(grep "^-" <<< "$arg")" != "" ]; then
			case $arg in
				"--config"|"-c")
					echo -e "Derpiget Configuration\n"
					echo "Config File: $CONF"
					echo "Protocol: $protocol"
					echo "Domain: $domain"
					echo "Filter: $derpiFilter"
					exit
					;;
				"--config="*)
					local opt
					opt="$(cut -d'=' -f 2- <<< "$arg")"
					if [ "$opt" = "" ]; then
						defaultConf
					else
						loadConf "$opt"
					fi
					;;
				"--quiet"|"-q")
					opt_quiet="true"
					;;
				"--print-meta"|"-p")
					opt_printMeta="true"
					;;
				"--https"|"-H")
					protocol="https"
					;;
				"--http"|"-h")
					protocol="http"
					;;
				"--domain="*)
					domain="$(cut -d'=' -f 2- <<< "$arg")"
					;;
				"--no-save"|"-n")
					opt_savePost="false"
					opt_saveMeta="false"
					;;
				"--meta"|"-m")
					opt_saveMeta="true"
					;;
				"--meta-only"|"-M")
					opt_saveMeta="true"
					opt_savePost="false"
					;;
				"--short-name"|"-s")
					opt_shortName="true"
					;;
				"--search="*)
					squery="$(cut -d'=' -f 2- <<< "$arg")"
					mode="search"
					;;
				"--filter="*)
					setDerpiFilter "$(cut -d'=' -f 2- <<< "$arg")"
					;;
				"--help"|"-?")
					helpMsg
					;;
				"--")
					noOpt="true"
					echo "No longer parsing opts" | stderr
					;;
				*)
					echo "Invalid Argument: $arg" | stderr
					return 1
					;;
			esac
			continue
		fi

		#Get Target IDs
		if [ "$noTarget" = "false" ] && [ "$(grep -E "^http(s|)://$domain/[0-9]" <<< "$arg")" != "" ] || [ "$(grep -E "^[0-9]+$" <<< "$arg")" != "" ]; then
			targets+="$(cut -d / -f 4 <<< "$arg" | cut -d'?' -f 1) "
		fi

	done

	for id in $piped; do
		if [ "$(grep -E "^http(s|)://$domain/[0-9]" <<< "$id")" != "" ] || [ "$(grep -E "^[0-9]+$" <<< "$id")" != "" ]; then
			targets+="$(cut -d / -f 4 <<< "$id" | cut -d'?' -f 1) "
		else
			echo "Invalid Derpibooru Post link / Numerical ID: $id" | stderr
			exit 1
		fi
	done
}

getMeta() {
	wget -qO- "$protocol://$domain/$1.json"
}

# Process piped input (if any) for links/IDs
if [ -p "/proc/self/fd/0" ]; then
	read -d '' piped
fi

setDerpiFilter "default"
defaultConf # Set Default Config
loadConf # Load Config File if available
checkDepends || exit 1 # Exit out if dependencies are unsatisfied
parseArgs "$@" || exit 1 # Exit out if invalid args

if [ "$mode" = "search" ]; then
	searchDerpi "$squery"
	exit
fi

#Download posts
for id in $targets; do
	log -ne "\e[1m[$id]\e[0m Downloading Meta Data... "
	META="$(getMeta $id)"
	log "Done"

	if [ "$opt_shortName" != "true" ]; then
		NAME="$(echo "$META" | jq -r ".image" | cut -d'/' -f 9)"
	else
		NAME="$id.$(echo "$META" | jq -r ".original_format")"
	fi

	if [ "$opt_printMeta" = "true" ]; then
		echo "$META" | jq
	fi

	if [ "$opt_saveMeta" = "true" ]; then
		echo "$META" > "$NAME.json"
		log -e "\e[1m[$id]\e[0m Saved Meta Data to file. "

	fi

	if [ "$opt_savePost" = "true" ]; then
		log -ne "\e[1m[$id]\e[0m Downloading Post... "
		echo "$protocol:$(jq -r ".image" <<< "$META")"
		wget -q "$protocol:$(jq -r ".image" <<< "$META")" -O "$NAME"
		log "Done"
	fi

	log
done

log "All Operations Completed."
