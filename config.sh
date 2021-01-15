#!/bin/bash

set -euo pipefail

Println()
{
    printf '%b' "\n$1\n"
}

# based on https://raw.githubusercontent.com/tanhauhau/Inquirer.sh/master/dist/inquirer.sh
inquirer()
{
    local arrow checked unchecked red green blue cyan bold normal dim
    arrow=$(echo -e '\xe2\x9d\xaf')
    checked=$(echo -e '\xe2\x97\x89')
    unchecked=$(echo -e '\xe2\x97\xaf')
    red=$(tput setaf 1)
    green=$(tput setaf 2)
    blue=$(tput setaf 4)
    cyan=$(tput setaf 6)
    bold=$(tput bold)
    normal=$(tput sgr0)
    dim=$'\e[2m'

    inquirer:print() {
        echo "$1"
        tput el
    }

    inquirer:join() {
        local IFS=$'\n'
        local var=("$1"[@])
        local _join_list=("${!var}")
        local first=true
        for item in "${_join_list[@]}"
        do
            if [ "$first" = true ]
            then
                printf "%s" "$item"
                first=false
            else
                printf "${2-, }%s" "$item"
            fi
        done
    }

    inquirer:gen_env_from_options() {
        local IFS=$'\n'
        local var=("$1"[@])
        local _indices=("${!var}")
        var=("$2"[@])
        local _env_names=("${!var}")
        local _checkbox_selected

        for i in $(inquirer:gen_index ${#_env_names[@]})
        do
            _checkbox_selected[i]=false
        done

        for i in "${_indices[@]}"
        do
            _checkbox_selected[i]=true
        done

        for i in $(inquirer:gen_index ${#_env_names[@]})
        do
            printf "%s=%s\n" "${_env_names[i]}" "${_checkbox_selected[i]}"
        done
    }

    inquirer:on_default() {
        true;
    }

    inquirer:on_keypress() {
        local OLD_IFS=$IFS
        local key
        local on_up=${1:-inquirer:on_default}
        local on_down=${2:-inquirer:on_default}
        local on_space=${3:-inquirer:on_default}
        local on_enter=${4:-inquirer:on_default}
        local on_left=${5:-inquirer:on_default}
        local on_right=${6:-inquirer:on_default}
        local on_ascii=${7:-inquirer:on_default}
        local on_backspace=${8:-inquirer:on_default}
        local on_not_ascii=${9:-inquirer:on_default}
        _break_keypress=false
        while IFS="" read -rsn1 key
        do
            case "$key" in
                $'\x1b')
                    read -rsn1 key
                    if [[ "$key" == "[" ]]
                    then
                        read -rsn1 key
                        case "$key" in
                        'A') $on_up;;
                        'B') $on_down;;
                        'D') $on_left;;
                        'C') $on_right;;
                        esac
                    fi
                ;;
                $'\x20') $on_space;;
                $'\x7f') $on_backspace $key;;
                '') $on_enter $key;;
                *[$'\x80'-$'\xFF']*) $on_not_ascii $key;;
                # [^ -~]
                *) $on_ascii $key;;
            esac
            if [ "$_break_keypress" = true ]
            then
                break
            fi
        done
        IFS=$OLD_IFS
    }

    inquirer:gen_index() {
        local k=$1
        local l=0
        for((l=0;l<k;l++));
        do
            echo $l
        done
    }

    inquirer:cleanup() {
        # Reset character attributes, make cursor visible, and restore
        # previous screen contents (if possible).
        tput sgr0
        tput cnorm
        stty echo
    }

    inquirer:control_c() {
        inquirer:cleanup
        exit $?
    }

    inquirer:select_indices() {
        local var=("$1"[@])
        local _select_list
        read -r -a _select_list <<< "${!var}"
        var=("$2"[@])
        local _select_indices
        read -r -a _select_indices <<< "${!var}"
        local _select_var_name=$3
        declare -a new_array
        for i in $(inquirer:gen_index ${#_select_indices[@]})
        do
            new_array+=("${_select_list[${_select_indices[i]}]}")
        done
        read -r -a ${_select_var_name?} <<< "${new_array[@]}"
        unset new_array
    }

    inquirer:on_checkbox_input_up() {
        inquirer:remove_checkbox_instructions
        tput cub "$(tput cols)"

        if [ "${_checkbox_selected[$_current_index]}" = true ]
        then
            printf '%s' " ${green}${checked}${normal} ${_checkbox_list[$_current_index]} ${normal}"
        else
            printf '%s' " ${unchecked} ${_checkbox_list[$_current_index]} ${normal}"
        fi
        tput el

        if [ $_current_index = 0 ]
        then
            _current_index=$((${#_checkbox_list[@]}-1))
            tput cud $((${#_checkbox_list[@]}-1))
            tput cub "$(tput cols)"
        else
            _current_index=$((_current_index-1))

            tput cuu1
            tput cub "$(tput cols)"
            tput el
        fi

        if [ "${_checkbox_selected[$_current_index]}" = true ]
        then
            printf '%s' "${cyan}${arrow}${green}${checked}${normal} ${_checkbox_list[$_current_index]} ${normal}"
        else
            printf '%s' "${cyan}${arrow}${normal}${unchecked} ${_checkbox_list[$_current_index]} ${normal}"
        fi
    }

    inquirer:on_checkbox_input_down() {
        inquirer:remove_checkbox_instructions
        tput cub "$(tput cols)"

        if [ "${_checkbox_selected[$_current_index]}" = true ]
        then
            printf '%s' " ${green}${checked}${normal} ${_checkbox_list[$_current_index]} ${normal}"
        else
            printf '%s' " ${unchecked} ${_checkbox_list[$_current_index]} ${normal}"
        fi

        tput el

        if [ $_current_index = $((${#_checkbox_list[@]}-1)) ]
        then
            _current_index=0
            tput cuu $((${#_checkbox_list[@]}-1))
            tput cub "$(tput cols)"
        else
            _current_index=$((_current_index+1))
            tput cud1
            tput cub "$(tput cols)"
            tput el
        fi

        if [ "${_checkbox_selected[$_current_index]}" = true ]
        then
            printf '%s' "${cyan}${arrow}${green}${checked}${normal} ${_checkbox_list[$_current_index]} ${normal}"
        else
            printf '%s' "${cyan}${arrow}${normal}${unchecked} ${_checkbox_list[$_current_index]} ${normal}"
        fi
    }

    inquirer:on_checkbox_input_enter() {
        local OLD_IFS=$IFS
        _checkbox_selected_indices=()
        _checkbox_selected_options=()
        IFS=$'\n'

        for i in $(inquirer:gen_index ${#_checkbox_list[@]})
        do
            if [ "${_checkbox_selected[i]}" = true ]
            then
                _checkbox_selected_indices+=("$i")
                _checkbox_selected_options+=("${_checkbox_list[i]}")
            fi
        done

        tput cud $((${#_checkbox_list[@]}-_current_index))
        tput cub "$(tput cols)"

        for i in $(seq $((${#_checkbox_list[@]}+1)))
        do
            tput el1
            tput el
            tput cuu1
        done
        tput cub "$(tput cols)"

        tput cuf $((prompt_width+3))
        printf '%s' "${cyan}$(inquirer:join _checkbox_selected_options)${normal}"
        tput el

        tput cud1
        tput cub "$(tput cols)"
        tput el

        _break_keypress=true
        IFS=$OLD_IFS
    }

    inquirer:on_checkbox_input_space() {
        inquirer:remove_checkbox_instructions
        tput cub "$(tput cols)"
        tput el
        if [ "${_checkbox_selected[$_current_index]}" = true ]
        then
            _checkbox_selected[$_current_index]=false
        else
            _checkbox_selected[$_current_index]=true
        fi

        if [ "${_checkbox_selected[$_current_index]}" = true ]
        then
            printf '%s' "${cyan}${arrow}${green}${checked}${normal} ${_checkbox_list[$_current_index]} ${normal}"
        else
            printf '%s' "${cyan}${arrow}${normal}${unchecked} ${_checkbox_list[$_current_index]} ${normal}"
        fi
    }

    inquirer:remove_checkbox_instructions() {
        if [ "$_first_keystroke" = true ]
        then
            tput cuu $((_current_index+1))
            tput cub "$(tput cols)"
            tput cuf $((prompt_width+3))
            tput el
            tput cud $((_current_index+1))
            _first_keystroke=false
        fi
    }

    inquirer:on_checkbox_input_ascii() {
        local key=$1
        case $key in
            "w" ) inquirer:on_checkbox_input_up;;
            "s" ) inquirer:on_checkbox_input_down;;
        esac
    }

    inquirer:_checkbox_input() {
        local i j var=("$2"[@])
        _checkbox_list=("${!var}")
        _current_index=0
        _first_keystroke=true

        trap inquirer:control_c SIGINT EXIT

        stty -echo
        tput civis

        inquirer:print "${green}?${normal} ${bold}${prompt}${normal} ${dim}(按 <space> 选择, <enter> 确认)${normal}"

        for i in $(inquirer:gen_index ${#_checkbox_list[@]})
        do
            _checkbox_selected[i]=false
        done

        if [ -n "${3:-}" ]
        then
            var=("$3"[@])
            _selected_indices=("${!var}")
            for i in "${_selected_indices[@]}"
            do
                _checkbox_selected[i]=true
            done
        fi

        for i in $(inquirer:gen_index ${#_checkbox_list[@]})
        do
            tput cub "$(tput cols)"
            if [ $i = 0 ]
            then
                if [ "${_checkbox_selected[i]}" = true ]
                then
                    inquirer:print "${cyan}${arrow}${green}${checked}${normal} ${_checkbox_list[i]} ${normal}"
                else
                    inquirer:print "${cyan}${arrow}${normal}${unchecked} ${_checkbox_list[i]} ${normal}"
                fi
            else
                if [ "${_checkbox_selected[i]}" = true ]
                then
                    inquirer:print " ${green}${checked}${normal} ${_checkbox_list[i]} ${normal}"
                else
                    inquirer:print " ${unchecked} ${_checkbox_list[i]} ${normal}"
                fi
            fi
            tput el
        done

        for j in $(inquirer:gen_index ${#_checkbox_list[@]})
        do
            tput cuu1
        done

        inquirer:on_keypress inquirer:on_checkbox_input_up inquirer:on_checkbox_input_down inquirer:on_checkbox_input_space inquirer:on_checkbox_input_enter inquirer:on_default inquirer:on_default inquirer:on_checkbox_input_ascii
    }

    inquirer:checkbox_input() {
        inquirer:_checkbox_input "$1" "$2"
        _checkbox_input_output_var_name=$3
        inquirer:select_indices _checkbox_list _checkbox_selected_indices $_checkbox_input_output_var_name

        unset _checkbox_list
        unset _break_keypress
        unset _first_keystroke
        unset _current_index
        unset _checkbox_input_output_var_name
        unset _checkbox_selected_indices
        unset _checkbox_selected_options

        inquirer:cleanup
    }

    inquirer:checkbox_input_indices() {
        inquirer:_checkbox_input "$1" "$2" "$3"
        _checkbox_input_output_var_name=$3

        declare -a new_array
        for i in $(inquirer:gen_index ${#_checkbox_selected_indices[@]})
        do
            new_array+=("${_checkbox_selected_indices[i]}")
        done
        read -r -a ${_checkbox_input_output_var_name?} <<< "${new_array[@]}"
        unset new_array

        unset _checkbox_list
        unset _break_keypress
        unset _first_keystroke
        unset _current_index
        unset _checkbox_input_output_var_name
        unset _checkbox_selected_indices
        unset _checkbox_selected_options

        inquirer:cleanup
    }

    inquirer:on_list_input_up() {
        inquirer:remove_list_instructions
        tput cub "$(tput cols)"

        printf '%s' "  ${_list_options[$_list_selected_index]}"
        tput el

        if [ $_list_selected_index = 0 ]
        then
            _list_selected_index=$((${#_list_options[@]}-1))
            tput cud $((${#_list_options[@]}-1))
            tput cub "$(tput cols)"
        else
            _list_selected_index=$((_list_selected_index-1))

            tput cuu1
            tput cub "$(tput cols)"
            tput el
        fi

        printf "${cyan}${arrow} %s ${normal}" "${_list_options[$_list_selected_index]}"
    }

    inquirer:on_list_input_down() {
        inquirer:remove_list_instructions
        tput cub "$(tput cols)"

        printf '%s' "  ${_list_options[$_list_selected_index]}"
        tput el

        if [ $_list_selected_index = $((${#_list_options[@]}-1)) ]
        then
            _list_selected_index=0
            tput cuu $((${#_list_options[@]}-1))
            tput cub "$(tput cols)"
        else
            _list_selected_index=$((_list_selected_index+1))
            tput cud1
            tput cub "$(tput cols)"
            tput el
        fi
        printf "${cyan}${arrow} %s ${normal}" "${_list_options[$_list_selected_index]}"
    }

    inquirer:on_list_input_enter_space() {
        local OLD_IFS=$IFS
        IFS=$'\n'

        tput cud $((${#_list_options[@]}-_list_selected_index))
        tput cub "$(tput cols)"

        for i in $(seq $((${#_list_options[@]}+1)))
        do
            tput el1
            tput el
            tput cuu1
        done
        tput cub "$(tput cols)"

        tput cuf $((prompt_width+3))
        printf '%s' "${cyan}${_list_options[$_list_selected_index]}${normal}"
        tput el

        tput cud1
        tput cub "$(tput cols)"
        tput el

        _break_keypress=true
        IFS=$OLD_IFS
    }

    inquirer:on_list_input_input_ascii()
    {
        local key=$1
        case $key in
            "w" ) inquirer:on_list_input_up;;
            "s" ) inquirer:on_list_input_down;;
        esac
    }

    inquirer:remove_list_instructions() {
        if [ "$_first_keystroke" = true ]
        then
            tput cuu $((_list_selected_index+1))
            tput cub "$(tput cols)"
            tput cuf $((prompt_width+3))
            tput el
            tput cud $((_list_selected_index+1))
            _first_keystroke=false
        fi
    }

    inquirer:_list_input() {
        local i j var=("$2"[@])
        _list_options=("${!var}")

        _list_selected_index=0
        _first_keystroke=true

        trap inquirer:control_c SIGINT EXIT

        stty -echo
        tput civis

        inquirer:print "${green}?${normal} ${bold}${prompt}${normal} ${dim}(使用上下箭头选择)${normal}"

        for i in $(inquirer:gen_index ${#_list_options[@]})
        do
            tput cub "$(tput cols)"
            if [ $i = 0 ]
            then
                inquirer:print "${cyan}${arrow} ${_list_options[i]} ${normal}"
            else
                inquirer:print "  ${_list_options[i]}"
            fi
            tput el
        done

        for j in $(inquirer:gen_index ${#_list_options[@]})
        do
            tput cuu1
        done

        inquirer:on_keypress inquirer:on_list_input_up inquirer:on_list_input_down inquirer:on_list_input_enter_space inquirer:on_list_input_enter_space inquirer:on_default inquirer:on_default inquirer:on_list_input_input_ascii
    }

    inquirer:list_input() {
        inquirer:_list_input "$1" "$2"
        var_name=$3
        read -r ${var_name?} <<< "${_list_options[$_list_selected_index]}"
        unset _list_selected_index
        unset _list_options
        unset _break_keypress
        unset _first_keystroke

        inquirer:cleanup
    }

    inquirer:list_input_index() {
        inquirer:_list_input "$1" "$2"
        var_name=$3
        read -r ${var_name?} <<< "$_list_selected_index"
        unset _list_selected_index
        unset _list_options
        unset _break_keypress
        unset _first_keystroke

        inquirer:cleanup
    }

    inquirer:on_text_input_left() {
        inquirer:remove_regex_failed
        if [[ $_current_pos -gt 0 ]]
        then
            local current=${_text_input:$_current_pos:1} current_width
            current_width=$(inquirer:display_length "$current")

            tput cub $current_width
            _current_pos=$((_current_pos-1))
        fi
    }

    inquirer:on_text_input_right() {
        inquirer:remove_regex_failed
        if [[ $((_current_pos+1)) -eq ${#_text_input} ]] 
        then
            tput cuf1
            _current_pos=$((_current_pos+1))
        elif [[ $_current_pos -lt ${#_text_input} ]]
        then
            local next=${_text_input:$((_current_pos+1)):1} next_width
            next_width=$(inquirer:display_length "$next")

            tput cuf $next_width
            _current_pos=$((_current_pos+1))
        fi
    }

    inquirer:on_text_input_enter() {
        inquirer:remove_regex_failed

        _text_input=${_text_input:-$_text_default_value}

        if [[ $($_text_input_validator "$_text_input") = true ]]
        then
            tput cuu 1
            tput cub "$(tput cols)"
            tput cuf $((prompt_width+3))
            printf '%s' "${cyan}${_text_input}${normal}"
            tput el
            tput cud1
            tput cub "$(tput cols)"
            tput el
            read -r ${var_name?} <<< "$_text_input"
            _break_keypress=true
        else
            _text_input_regex_failed=true
            tput civis
            tput cuu1
            tput cub "$(tput cols)"
            tput cuf $((prompt_width+3))
            tput el
            tput cud1
            tput cub "$(tput cols)"
            tput el
            tput cud1
            tput cub "$(tput cols)"
            printf '%b' "${red}$_text_input_regex_failed_msg${normal}"
            tput el
            _text_input=""
            _current_pos=0
            tput cnorm
        fi
    }

    inquirer:on_text_input_ascii() {
        inquirer:remove_regex_failed
        local c=${1:- }

        local rest=${_text_input:$_current_pos} rest_width
        local current=${_text_input:$_current_pos:1} current_width
        rest_width=$(inquirer:display_length "$rest")
        current_width=$(inquirer:display_length "$current")

        _text_input="${_text_input:0:$_current_pos}$c$rest"
        _current_pos=$((_current_pos+1))

        tput civis
        [[ $current_width -gt 1 ]] && tput cub $((current_width-1))
        printf '%s' "$c$rest"
        tput el

        if [[ $rest_width -gt 0 ]]
        then
            tput cub $((rest_width-current_width+1))
        fi
        tput cnorm
    }

    inquirer:display_length() {
        local display_length=0 byte_len
        local oLC_ALL=${LC_ALL:-} oLANG=${LANG:-} LC_ALL=${LC_ALL:-} LANG=${LANG:-}

        while IFS="" read -rsn1 char
        do
            case "$char" in
                '')
                ;;
                *[$'\x80'-$'\xFF']*) 
                    LC_ALL='' LANG=C
                    byte_len=${#char}
                    LC_ALL=$oLC_ALL LANG=$oLANG
                    if [[ $byte_len -eq 2 ]] 
                    then
                        display_length=$((display_length+1))
                    else
                        display_length=$((display_length+2))
                    fi
                ;;
                *) 
                    display_length=$((display_length+1))
                ;;
            esac
        done <<< "$1"

        echo "$display_length"
    }

    inquirer:on_text_input_not_ascii() {
        inquirer:remove_regex_failed
        local c=$1

        local rest="${_text_input:$_current_pos}" rest_width
        local current=${_text_input:$_current_pos:1} current_width
        rest_width=$(inquirer:display_length "$rest")
        current_width=$(inquirer:display_length "$current")

        _text_input="${_text_input:0:$_current_pos}$c$rest"
        _current_pos=$((_current_pos+1))

        tput civis
        [[ $current_width -gt 1 ]] && tput cub $((current_width-1))
        printf '%s' "$c$rest"
        tput el

        if [[ $rest_width -gt 0 ]]
        then
            tput cub $((rest_width-current_width+1))
        fi
        tput cnorm
    }

    inquirer:on_text_input_backspace() {
        inquirer:remove_regex_failed
        if [ $_current_pos -gt 0 ] || { [ $_current_pos -eq 0 ] && [ "${#_text_input}" -gt 0 ]; }
        then
            local start rest rest_width del del_width next next_width offset
            local current=${_text_input:$_current_pos:1} current_width
            current_width=$(inquirer:display_length "$current")

            tput civis
            if [ $_current_pos -eq 0 ] 
            then
                rest=${_text_input:$((_current_pos+1))}
                next=${_text_input:$((_current_pos+1)):1}
                rest_width=$(inquirer:display_length "$rest")
                next_width=$(inquirer:display_length "$next")
                offset=$((current_width-1))
                [[ $offset -gt 0 ]] && tput cub $offset
                printf '%s' "$rest"
                tput el
                offset=$((rest_width-next_width+1))
                [[ $offset -gt 0 ]] && tput cub $offset
                _text_input=$rest
            else
                rest=${_text_input:$_current_pos}
                start=${_text_input:0:$((_current_pos-1))}
                del=${_text_input:$((_current_pos-1)):1}
                rest_width=$(inquirer:display_length "$rest")
                del_width=$(inquirer:display_length "$del")
                _current_pos=$((_current_pos-1))
                if [[ $current_width -gt 1 ]] 
                then
                    tput cub $((del_width+current_width-1))
                    printf '%s' "$rest"
                    tput el
                    tput cub $((rest_width-current_width+1))
                else
                    tput cub $del_width
                    printf '%s' "$rest"
                    tput el
                    [[ $rest_width -gt 0 ]] && tput cub $((rest_width-current_width+1))
                fi
                _text_input="$start$rest"
            fi
            tput cnorm
        fi
    }

    inquirer:remove_regex_failed() {
        if [ "$_text_input_regex_failed" = true ]
        then
            _text_input_regex_failed=false
            tput sc
            tput cud1
            tput el1
            tput el
            tput rc
        fi
    }

    inquirer:text_input_default_validator() {
        echo true;
    }

    inquirer:text_input() {
        var_name=$2
        if [ -n "$_text_default_value" ] 
        then
            _text_default_tip=" $dim($_text_default_value)"
        else
            _text_default_tip=""
        fi
        _text_input_regex_failed_msg=${4:-"输入验证错误"}
        _text_input_validator=${5:-inquirer:text_input_default_validator}
        _text_input_regex_failed=false

        inquirer:print "${green}?${normal} ${bold}${prompt}$_text_default_tip${normal}"

        trap inquirer:control_c SIGINT EXIT

        stty -echo
        tput cnorm

        inquirer:on_keypress inquirer:on_default inquirer:on_default inquirer:on_text_input_ascii inquirer:on_text_input_enter inquirer:on_text_input_left inquirer:on_text_input_right inquirer:on_text_input_ascii inquirer:on_text_input_backspace inquirer:on_text_input_not_ascii
        read -r ${var_name?} <<< "$_text_input"

        inquirer:cleanup
    }

    local option=$1
    shift
    local var_name prompt=${1:-} prompt_width _text_default_value=${3:-} _current_pos=0 _text_input="" _text_input_regex_failed_msg _text_input_validator _text_input_regex_failed
    prompt_width=$(inquirer:display_length "$prompt")
    inquirer:$option "$@"
}

archs=(
    arm_arm1176jzf-s_vfp
    arm_arm926ej-s
    arm_cortex-a15_neon-vfpv4
    arm_cortex-a5_vfpv4
    arm_cortex-a7_neon-vfpv4
    arm_cortex-a8_vfpv3
    arm_cortex-a9
    arm_cortex-a9_neon
    arm_cortex-a9_vfpv3-d16
    arm_fa526
    arm_mpcore
    arm_mpcore_vfp
    arm_xscale
    i386_pentium
    i386_pentium4
    mips64_octeonplus
    mipsel_24kc
    mipsel_24kc_24kf
    mipsel_74kc
    mipsel_mips32
    mips_24kc
    mips_mips32
    arc_arc700
    arc_archs
    powerpc_464fp
    powerpc_8540
    aarch64_cortex-a72
    aarch64_cortex-a53
    aarch64_generic
    x86_64
)

for arch in "${archs[@]}"
do
    target_path=".github/targets/$arch/"
    if [ ! -d "$target_path" ] 
    then
        mkdir -p "$target_path"
        ln action.yml "$target_path"
        ln build.sh "$target_path"
        echo "# Container image that runs your code
FROM openwrtorg/sdk:$arch-snapshot

# Copies your code file from your action repository to the filesystem path / of the container
COPY build.sh /build.sh

# Code file to execute when the docker container starts up
ENTRYPOINT [\"/build.sh\"]" > "$target_path/Dockerfile"
    fi
done

echo
selected_indices=( 27 28 29 )
set +u
inquirer checkbox_input_indices "Choose targets" archs selected_indices
set -u

if [ -z "${selected_indices:-}" ] 
then
    Println "Canceled...\n"
    exit 1
fi

yn_options=( 'yes' 'no' )

echo
inquirer list_input "Compress executable files with UPX" yn_options compress_upx
compress_upx=${compress_upx:0:1}

yn_options=( 'no' 'yes' )

echo
inquirer list_input "Compiling with GOPROXY proxy" yn_options compress_goproxy
compress_goproxy=${compress_goproxy:0:1}

echo
inquirer list_input "Exclude geoip.dat & geosite.dat" yn_options exclude_assets
exclude_assets=${exclude_assets:0:1}

echo
inquirer list_input "V2ray Compatibility mode(v2ray soft connection Xray)" yn_options compatibility_mode
compatibility_mode=${compatibility_mode:0:1}

indices_last=${selected_indices[${#selected_indices[@]}-1]}
steps=""

for index in "${selected_indices[@]}"
do
    if [ "$index" -eq "$indices_last" ] 
    then
        steps="$steps
      - name: Build for ${archs[index]}
        env:
          WORKSPACE: \${{ github.workspace }}
        uses: woniuzfb/openwrt-xray/.github/targets/${archs[index]}@v1
        id: last_build
        with:
          compress-goproxy: '$compress_goproxy'
          exclude-assets: '$exclude_assets'
          compress-upx: '$compress_upx'
          compatibility-mode: '$compatibility_mode'"
    else
        steps="$steps
      - name: Build for ${archs[index]}
        env:
          WORKSPACE: \${{ github.workspace }}
        uses: woniuzfb/openwrt-xray/.github/targets/${archs[index]}@v1
        with:
          compress-goproxy: '$compress_goproxy'
          exclude-assets: '$exclude_assets'
          compress-upx: '$compress_upx'
          compatibility-mode: '$compatibility_mode'"
    fi
done

echo "name: Build and Release

on:
  push:
    tags:
      - \"v*.*.*\"

jobs:
  build_release:
    runs-on: ubuntu-latest
    name: Build openwrt-xray
    steps:$steps
      - name: Release
        uses: softprops/action-gh-release@v1
        with:
          files: '*.ipk'
        env:
          GITHUB_TOKEN: \${{ secrets.GITHUB_TOKEN }}
      - name: Done
        run: echo \"Build complete - \${{ steps.last_build.outputs.date }}\"" > ".github/workflows/build-release.yml"

Println "Done.\n"