#!/usr/bin/env bash
# vim: noai:ts=4:sw=4:expandtab:cc=100
#
# skirm.sh: The back-end of gw2skirmish.com written in Bash.
# https://github.com/gw2skirmish/skirm.sh

# standalone
get_api() {
  curl "https://api.guildwars2.com/v2/wvw/matches?ids=all" #--silent;
}

# standalone
get_match_data() {
    if      [[ ${#@} -ne 2 ]] ;
    then    >&2 printf "%s\n" "Usage: get_match_data MATCH_ID JSON_FILE"
            return 1
    fi
    id=$1
    file=$2
    read -r start end <<<"$(grep -n -- \""$id"\"'\|^  }' "$file" \
                            | grep id -A1 \
                            | cut -d: -f1 \
                            | tr '\n' ' '
                            )"
    head -"$end" "$file" \
    | tail +"$start" \
    | sed 's/^  },/  }/'
}

# standalone
# works well with get_match_data
get_match_info() {
    # get_match_info 'worlds' matches.json
    grep -A4 '^    '\""$1" "${@:2}";
}

clean_json() {
    grep -v '{' | cut -d: -f2- | tr -d \",\ ;
}

get_match_id() {
    grep \
    '^    "id"' "$@" \
    | clean_json;
}

get_match_start_time() {
    grep \
    '^    "start_time"' "$@" \
    | clean_json;
}

get_match_end_time() {
    grep \
    '^    "end_time"' "$@" \
    | clean_json;
}

get_match_worlds() {
    grep -A3 --no-group-separator \
    '^    "worlds"' "$@" \
    | clean_json;
}

get_match_victory_points() {
    grep -A3 --no-group-separator \
    '^    "victory_points"' "$@" \
    | clean_json;
}

get_match_scores_total() {
    grep -A3 --no-group-separator \
    '^    "scores"' "$@" \
    | clean_json;
}

get_match_scores() {
    grep -B42 \
    '^    "maps"' "$@" \
    | grep -A4 --no-group-separator id \
    | grep -v id \
    | clean_json;
}

get_match_skirmishes_current() {
    grep -B42 --no-group-separator \
    '^    "maps"' "$@" \
    | grep id \
    | clean_json;
}

get_match_skirmishes_completed() {
    for     i in $(get_match_skirmishes_current "$@");
    do      printf "%s\n" $(( i-1 ));
    done;
}

get_match_deaths() {
    grep -A3 --no-group-separator \
    '^    "deaths"' "$@" \
    | clean_json;
}

get_match_kills() {
    grep -A3 --no-group-separator \
    '^    "kills"' "$@" \
    | clean_json;
}

next(){
    # TODO: In case of Tie, the behaviour is unknown:
    #       Maybe it depends on the original placement
    matches_json=${1:-matches.json}
    csv=$(make_csv "$matches_json" | tail +2 | sort -t, -k2,2 -k3,3rn -k4,4nr)
    region_start=0
    printf "%s\n" "1"

    for     ((i = 1; i <= $(( $(printf "%s\n" "${#csv}") / 3 )); i++))
    do      tier=$i
            mycommand() {
                printf "%s\n" "$csv" \
                | head -$(( 2+3*tier )) \
                | tail -4 \
                | cut -d, -f2,3 \
                | tr ',\n-' ' ';
            }
            IFS=$' ' read -r -a array <<< "$(mycommand)"

            # region change
            [[ "${array[3]}" != "${array[6]}" ]] \
            && region_start=$(( tier*3 )) \
            && printf "%s\n" $(( tier*3-1 )) \
            && printf "%s\n" $(( tier*3 )) \
            && printf "%s\n" "1"

            # swap
            [[ "${array[3]}" = "${array[6]}" ]] \
            && [[ "${array[2]}" != "${array[5]}" ]] \
            && [[ "${array[8]}" != "${array[11]}" ]] \
            && [[ "${array[1]}" = "${array[4]}" ]] \
            && printf "%s\n" $(( tier*3-1 - region_start )) \
            && printf "%s\n" $(( tier*3+1 - region_start )) \
            && printf "%s\n" $(( tier*3 - region_start ))

            # tie
            [[ "${array[2]}" = "${array[5]}" ]] \
            || [[ "${array[8]}" = "${array[11]}" ]] \
            && printf "%s\n" $(( tier*3-region_start-1 )) \
            && printf "%s\n" $(( tier*3-region_start )) \
            && printf "%s\n" $(( tier*3+1-region_start ))

            # end of table
            [[ "${array[1]}" != "${array[4]}" ]] \
            && printf "%s\n" $(( tier*3-region_start+2-array[0]-1 )) \
            && printf "%s\n" $(( tier*3-region_start+3-array[0]-1 ))
    done
}

glue_next() {
    matches_json=${1:-matches.json}
    printf  "%s%s\n" \
            "TEAM,MATCH,VP,INIT#,SKIRMISH,WARSCORE,VICTORY%,"\
            "KILLS,DEATHS,KDSUM,KD%,PPK%,HOMESTRETCH,FROZEN,NEXT#,INITCOLOR,"
    mapfile -t nexta < <(next "$matches_json")
    mycommand() {
        make_csv "$matches_json" \
        | tail +2 \
        | sort -t, -k2,2 -k3,3rn -k4,4nr \
        | tr_worlds_teams
    }
    i=0
    while   read -r;
    do      printf "%s\n" "${REPLY//next/${nexta[$i]}}"
            i=$(( i+1 ))
    done    < <(mycommand)
}

triple() {
    while   read -r;
    do      printf "%s\n%s\n%s\n" "$REPLY" "$REPLY" "$REPLY";
    done;
}

tr_worlds_teams() {
    while read -r line
    do  line="${line/#1001,/"Moogooloo,"}"
        line="${line/#1002,/"Rall's Rest,"}"
        line="${line/#1003,/"Domain of Torment,"}"
        line="${line/#1004,/"Yohlon Haven,"}"
        line="${line/#1005,/"Tombs of Drascir,"}"
        line="${line/#1006,/"Hall of Judgment,"}"
        line="${line/#1007,/"Throne of Balthazar,"}"
        line="${line/#1008,/"Dwayna's Temple,"}"
        line="${line/#1009,/"Abaddon's Prison,"}"
        line="${line/#1010,/"Ruined Cathedral of Blood,"}"
        line="${line/#1011,/"Lutgardis Conservatory,"}"
        line="${line/#1012,/"Mosswood,"}"
        line="${line/#1013,/"Mithric Cliffs,"}"
        line="${line/#1014,/"Lagula's Kraal,"}"
        line="${line/#1015,/"De Molish Post,"}"
        line="${line/#2001,/"Skrittsburgh,"}"
        line="${line/#2002,/"Fortune's Vale,"}"
        line="${line/#2003,/"Silent Woods,"}"
        line="${line/#2004,/"Ettin's Back,"}"
        line="${line/#2005,/"Domain of Anguish,"}"
        line="${line/#2006,/"Palawadan,"}"
        line="${line/#2007,/"Bloodstone Gulch,"}"
        line="${line/#2008,/"Frost Citadel,"}"
        line="${line/#2009,/"Dragrimmar,"}"
        line="${line/#2010,/"Grenth's Door,"}"
        line="${line/#2011,/"Mirror of Lyssa,"}"
        line="${line/#2012,/"Melandru's Dome,"}"
        line="${line/#2013,/"Kormir's Library,"}"
        line="${line/#2014,/"Great House Aviary,"}"
        line="${line/#2101,/"Bava Nisos,"}"
        line="${line/#2102,/"Temple of Febe,"}"
        line="${line/#2103,/"Gyala Hatchery,"}"
        line="${line/#2104,/"Grekvelnn Burrows,"}"
        printf "%s\n" "$line"
    done
}

# TODO: INITCOLOR, NEXTCOLOR for colors "Red", "Blue", "Green"
# TODO: Maybe also add a NEXTMOVE with "Up" "Down" "Hold"
make_csv() {
    input=$(mktemp)
    cat "$@" >> "$input"
    printf  "%s%s\n" \
            "TEAM,MATCH,VP,INIT#,SKIRMISH,WARSCORE,VICTORY%," \
            "KILLS,DEATHS,KDSUM,KD%,PPK%,HOMESTRETCH,FROZEN,NEXT#,INITCOLOR,"
    mapfile -t sk < <(get_match_skirmishes_completed "$input" | triple)
    mapfile -t vp < <(get_match_victory_points "$input")
    mapfile -t wo < <(get_match_worlds "$input")
    mapfile -t id < <(get_match_id "$input" | triple)
    mapfile -t sc < <(get_match_scores "$input")
    mapfile -t ki < <(get_match_kills "$input")
    mapfile -t de < <(get_match_deaths "$input")
    mapfile -t st < <(get_match_scores_total "$input")
    for     ((i = 0; i < ${#sk[@]}; i++));
    do      place=$(( i+2*(1+(-i)%3)+1 ))
            tier=$(printf "%s\n" "${id[$i]}" | cut -d- -f2)
            init=$(( (place-1)%3+1+(tier-1)*3 ))
            vpc=$(( (vp[i]-3*sk[i])*50/sk[i] ))%
            kds=$(( ki[i]+de[i] ))
            kdr=$(( ki[i]*100/de[i] ))%
            ppk=$(( ki[i]*200/st[i] ))%
            homestretch="homestretch"
            frozen="frozen"
            next="next"
            [[ $(( i%3 )) -eq 0 ]] && initcolor="Green"
            [[ $(( i%3 )) -eq 1 ]] && initcolor="Blue"
            [[ $(( i%3 )) -eq 2 ]] && initcolor="Red"
            printf  "%s%s%s\n" \
                    "${wo[$i]},${id[$i]},${vp[$i]},$init,${sk[$i]}," \
                    "${sc[$i]},$vpc,${ki[$i]},${de[$i]},$kds,$kdr,$ppk," \
                    "$homestretch,$frozen,$next,$initcolor,"
    done
    rm "$input"
}

make_col() {
    search=${1:--}
    read -r col_names
    col_right=${col_names//TEAM,/}
    col_right=${col_right//MATCH,/}
    col_right=${col_right//INITCOLOR,/}
    grep -i -- "$search" \
    | column  -ts, \
              -N "$col_names" \
              -R "$col_right" \
    | spacer 3 1
}

sort_by_vp() {
    csv_order "MATCH,VP,INIT#" \
    | { read -r;
        printf "%s\n" "$REPLY";
        sort -t, -k1,1 -k2,2nr -k3,3nr;
      }
}

sort_by_init() {
    csv_order "MATCH,INIT#" \
    | { read -r;
        printf "%s\n" "$REPLY";
        sort -t, -k1,1 -k2,2n;
      }
}

sort_by_next() {
    csv_order "MATCH,NEXT#" \
    | { read -r;
        printf "%s\n" "$REPLY";
        sort -t, -k1.1,1.2 -k2,2n;
      }
}

csv_order() {
    read -r; \
    column -ts, -N "$REPLY" -O "$1" \
    | sed 's/   */,/g';
}

# Deprecated
space() {
    i=0;
    while   read -r;
    do      printf "%s\n" "$REPLY";
            if      [[ $(( i%3 )) -eq 0 ]] ;
            then    printf "\n";
            fi;
            i=$(( i+1 ));
    done;
}

spacer() {
    size=${1:-3};
    row=${2:-1};
    while   read -r;
    do      printf "%s\n" "$REPLY";
            row=$(( row-1 ));
            if      [[ "$row" -le 0 ]] ;
            then    printf "\n";
                    row=$size;
            fi;
    done;
}

# TODO
homestretch() {
    :;
}

# TODO
frozen() {
    :;
}

# TODO: Detect INITCOLOR and add a background color for Terminal use.
get_color() {
    while read -r;
    do
        grep -qs ' Green ' <(printf "%s\n" "$REPLY") && \
        printf "%b\n" "\e[1;32m$REPLY\e[0m"
        grep -qs ' Blue ' <(printf "%s\n" "$REPLY") && \
        printf "%b\n" "\e[1;34m$REPLY\e[0m"
        grep -qs ' Red ' <(printf "%s\n" "$REPLY") && \
        printf "%b\n" "\e[1;31m$REPLY\e[0m"
        grep -qsv ' Red \| Blue \| Green ' <(printf "%s\n" "$REPLY") && \
        printf "%b\n" "\e[1;37m$REPLY\e[0m";
    done
}

skirm() {
    [[ "$1" ]] && >&2 printf "%s\n" "Using $1 ..." \
    || >&2 printf "%s\n" "Getting API ..." && get_api > matches.json
    glue_next "${1:-matches.json}" \
    | sort_by_vp \
    | csv_order "MATCH,INIT#,INITCOLOR,TEAM,SKIRMISH,WARSCORE,VP,VICTORY%,NEXT#" \
    | make_col -
}

# TODO: Uncomment for use; Comment for dev.
#skirm "$@"
