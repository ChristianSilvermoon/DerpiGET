#!/bin/bash
version="19.9.14"
script="$(dirname "$0")/$(basname "$0")"

stderr() {
	cat - 1>&2
}

checkDepends() {

	local depends='jq'
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

log() {
	if [ "$opt_quiet" != "true" ]; then
		echo $@
	fi
}

helpMsg() {
	echo -e "DerpiGET, version: $version"
	echo -e "USAGE: derpiget [opt] <id|post link> \n"

	printf "  %-26s %s\n" "-?, --help" "Display this message"
	printf "  %-26s %s\n" "--filter=<ID>" "Set Derpibooru filter ID"
	printf "  %-26s %s\n" "-m, --meta" "Save Meta Data to file"
	printf "  %-26s %s\n" "-M, --meta-only" "Save Meta Data to file, don't download post"
	printf "  %-26s %s\n" "-n, --no-save" "Don't save anything"
	printf "  %-26s %s\n" "-p, --print-meta" "Print Meta Data to stdout"
	printf "  %-26s %s\n" "-s, --short-name" "Name files after their ID numbers"
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

	# Process piped input (if any) for links/IDs
	if [ -p "/proc/self/fd/0" ]; then
		read -d '' piped

		for id in $piped; do
			if [ "$(grep -E "^http(s|)://derpibooru.org/[0-9]" <<< "$id")" != "" ] || [ "$(grep -E "^[0-9]+$" <<< "$id")" != "" ]; then
				targets+="$(cut -d / -f 4 <<< "$id" | cut -d'?' -f 1) "
			else
				echo "Invalid Derpibooru Post link / Numerical ID: $id" | stderr
				exit 1
			fi
		done
	fi


	for arg in "$@"; do
		if [ "$ignore" -gt 0 ]; then
			((ignore--))
			continue
		fi

		if [ "$noOpt" = "false" ]&&[ "$(grep "^-" <<< "$arg")" != "" ]; then
			case $arg in
				"--quiet"|"-q")
					opt_quiet="true"
					;;
				"--print-meta"|"-p")
					opt_printMeta="true"
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
		if [ "$noTarget" = "false" ] && [ "$(grep -E "^http(s|)://derpibooru.org/[0-9]" <<< "$arg")" != "" ] || [ "$(grep -E "^[0-9]+$" <<< "$arg")" != "" ]; then
			targets+="$(cut -d / -f 4 <<< "$arg" | cut -d'?' -f 1) "
		fi

	done
}

getMeta() {
	wget -qO- "https://derpibooru.org/$1.json"
}

checkDepends || exit 1 # Exit out if dependencies are unsatisfied
parseArgs "$@" || exit 1 # Exit out if invalid args

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
		wget -q "https:$(jq -r ".image" <<< "$META")" -O "$NAME"
		log "Done"
	fi

	log
done

log "All Operations Completed."
