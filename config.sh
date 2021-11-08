#!/bin/bash

set -euo pipefail

Println()
{
    printf '%b' "\n$1\n"
}

inquirer()
{
    inquirer:print() {
        tput el
        printf '%b' "$1"
    }

    inquirer:join() {
        local var=("$1"[@])
        if [[ -z ${!var:-} ]] 
        then
            return 0
        fi
        local join_list=("${!var}") first=true item
        for item in "${join_list[@]}"
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

    inquirer:on_default() {
        return 0
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
        break_keypress=false
        while IFS="" read -rsn1 key
        do
            case "$key" in
                $'\x1b')
                    read -rsn1 key
                    if [ "$key" == "[" ]
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
                $'\x7f') $on_backspace "$key";;
                '') $on_enter "$key";;
                *[$'\x80'-$'\xFF']*) $on_not_ascii "$key";;
                # [^ -~]
                *) $on_ascii "$key";;
            esac
            if [ "$break_keypress" = true ]
            then
                break
            fi
        done
        IFS=$OLD_IFS
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

    inquirer:remove_instructions() {
        if [ "$first_keystroke" = true ]
        then
            tput cuu $((current_index+1))
            tput cub "$(tput cols)"
            tput cuf $((prompt_width+3))
            tput el
            tput cud $((current_index+1))
            first_keystroke=false
        fi
    }

    inquirer:on_checkbox_input_up() {
        inquirer:remove_instructions
        tput cub "$(tput cols)"

        if [ "${checkbox_selected[current_index]}" = true ]
        then
            inquirer:print " ${green}${checked}${normal} ${checkbox_list[current_index]}"
        else
            inquirer:print " ${unchecked} ${checkbox_list[current_index]}"
        fi

        if [ $current_index = 0 ]
        then
            current_index=$((${#checkbox_list[@]}-1))
            tput cud $((${#checkbox_list[@]}-1))
        else
            current_index=$((current_index-1))
            tput cuu1
        fi

        tput cub "$(tput cols)"

        if [ "${checkbox_selected[current_index]}" = true ]
        then
            inquirer:print "${cyan}${arrow}${green}${checked}${normal} ${checkbox_list[current_index]}"
        else
            inquirer:print "${cyan}${arrow}${normal}${unchecked} ${checkbox_list[current_index]}"
        fi
    }

    inquirer:on_checkbox_input_down() {
        inquirer:remove_instructions
        tput cub "$(tput cols)"

        if [ "${checkbox_selected[current_index]}" = true ]
        then
            inquirer:print " ${green}${checked}${normal} ${checkbox_list[current_index]}"
        else
            inquirer:print " ${unchecked} ${checkbox_list[current_index]}"
        fi

        if [ $current_index = $((${#checkbox_list[@]}-1)) ]
        then
            current_index=0
            tput cuu $((${#checkbox_list[@]}-1))
        else
            current_index=$((current_index+1))
            tput cud1
        fi

        tput cub "$(tput cols)"

        if [ "${checkbox_selected[current_index]}" = true ]
        then
            inquirer:print "${cyan}${arrow}${green}${checked}${normal} ${checkbox_list[current_index]}"
        else
            inquirer:print "${cyan}${arrow}${normal}${unchecked} ${checkbox_list[current_index]}"
        fi
    }

    inquirer:on_checkbox_input_enter() {
        local i

        for i in "${!checkbox_list[@]}"
        do
            if [ "${checkbox_selected[i]}" = true ] && [ "$i" -ne "$checkbox_list_count" ]
            then
                checkbox_selected_indices+=("$i")
                checkbox_selected_options+=("${checkbox_list[i]}")
            fi
        done

        tput cub "$(tput cols)"

        if [ -z "${checkbox_selected_indices:-}" ] 
        then
            tput sc
            failed_count=$((failed_count+1))
            tput cuu $((current_index+1))
            tput cuf $((prompt_width+3))
            inquirer:print "${red}${checkbox_input_failed_msg}${normal}"
            tput rc
        else
            tput cud $((${#checkbox_list[@]}-current_index))

            for i in $(seq $((${#checkbox_list[@]}+1)))
            do
                tput el
                tput cuu1
            done

            tput cuf $((prompt_width+3))
            inquirer:print "${cyan}$(inquirer:join checkbox_selected_options)${normal}\n"

            break_keypress=true
        fi
    }

    inquirer:on_checkbox_input_space() {
        local i

        inquirer:remove_instructions
        tput cub "$(tput cols)"
        tput el

        if [ "$current_index" -eq "$checkbox_list_count" ] 
        then
            if [ "${checkbox_selected[current_index]}" = true ]
            then
                tput cuu $current_index
                for i in "${!checkbox_list[@]}"
                do
                    if [ "$i" -eq "$current_index" ]
                    then
                        inquirer:print "${cyan}${arrow}${normal}${unchecked} ${checkbox_list[i]}"
                    else
                        inquirer:print " ${unchecked} ${checkbox_list[i]}\n"
                    fi
                done
                for i in "${!checkbox_list[@]}"
                do
                    checkbox_selected[i]=false
                done
            else
                tput cuu $current_index
                for i in "${!checkbox_list[@]}"
                do
                    if [ "$i" -eq "$current_index" ]
                    then
                        inquirer:print "${cyan}${arrow}${green}${checked}${normal} ${checkbox_list[i]}"
                    else
                        inquirer:print " ${green}${checked}${normal} ${checkbox_list[i]}\n"
                    fi
                done
                for i in "${!checkbox_list[@]}"
                do
                    checkbox_selected[i]=true
                done
            fi
        else
            if [ "${checkbox_selected[current_index]}" = true ]
            then
                checkbox_selected[current_index]=false
                inquirer:print "${cyan}${arrow}${normal}${unchecked} ${checkbox_list[current_index]}"
            else
                checkbox_selected[current_index]=true
                inquirer:print "${cyan}${arrow}${green}${checked}${normal} ${checkbox_list[current_index]}"
            fi
        fi
    }

    inquirer:on_checkbox_input_ascii() {
        local key=$1
        case "$key" in
            "w" ) inquirer:on_checkbox_input_up;;
            "s" ) inquirer:on_checkbox_input_down;;
        esac
    }

    inquirer:_checkbox_input() {
        local i var=("$2"[@])
        checkbox_list=("${!var}")
        checkbox_list_count=${#checkbox_list[@]}

        if [ "$checkbox_list_count" -eq 1 ] 
        then
            checkbox_selected_options=("${checkbox_list[@]}")
            checkbox_selected_indices=(0)

            return 0
        fi

        checkbox_selected=()
        checkbox_selected_indices=()
        checkbox_selected_options=()
        checkbox_list+=("$(gettext 全选)")
        checkbox_input_failed_msg=${4:-$(gettext "选择不能为空")}
        current_index=0
        failed_count=0
        first_keystroke=true

        trap inquirer:control_c SIGINT EXIT

        stty -echo
        tput civis

        inquirer:print "${green}?${normal} ${bold}${prompt}${normal} ${dim}`gettext \"(按 <space> 选择, <enter> 确认)\"`${normal}\n"

        for i in "${!checkbox_list[@]}"
        do
            checkbox_selected[i]=false
        done

        if [ -n "${3:-}" ]
        then
            var=("$3"[@])
            if [[ -n ${!var:-} ]] 
            then
                checkbox_selected_indices=("${!var}")
                for i in "${checkbox_selected_indices[@]}"
                do
                    checkbox_selected[i]=true
                done
                checkbox_selected_indices=()
            fi
        fi

        for i in "${!checkbox_list[@]}"
        do
            if [ $i = 0 ]
            then
                if [ "${checkbox_selected[i]}" = true ]
                then
                    inquirer:print "${cyan}${arrow}${green}${checked}${normal} ${checkbox_list[i]}\n"
                else
                    inquirer:print "${cyan}${arrow}${normal}${unchecked} ${checkbox_list[i]}\n"
                fi
            else
                if [ "${checkbox_selected[i]}" = true ]
                then
                    inquirer:print " ${green}${checked}${normal} ${checkbox_list[i]}\n"
                else
                    inquirer:print " ${unchecked} ${checkbox_list[i]}\n"
                fi
            fi
        done

        tput cuu ${#checkbox_list[@]}

        inquirer:on_keypress inquirer:on_checkbox_input_up inquirer:on_checkbox_input_down inquirer:on_checkbox_input_space inquirer:on_checkbox_input_enter inquirer:on_default inquirer:on_default inquirer:on_checkbox_input_ascii
    }

    inquirer:checkbox_input() {
        var_name=$3

        inquirer:_checkbox_input "$1" "$2"

        read -r -a ${var_name?} <<< "${checkbox_selected_options[@]}"

        inquirer:cleanup
    }

    inquirer:checkbox_input_indices() {
        var_name=$3

        inquirer:_checkbox_input "$1" "$2" "$var_name"

        read -r -a ${var_name?} <<< "${checkbox_selected_indices[@]}"

        inquirer:cleanup
    }

    inquirer:on_sort_up() {
        if [ "${#sort_options[@]}" -eq 1 ]
        then
            return 0
        fi

        tput cub "$(tput cols)"

        inquirer:print "  ${sort_options[current_index]}"

        if [ $current_index = 0 ]
        then
            current_index=$((${#sort_options[@]}-1))
            tput cud $((${#sort_options[@]}-1))
        else
            current_index=$((current_index-1))
            tput cuu1
        fi

        tput cub "$(tput cols)"

        inquirer:print "${cyan}${arrow} ${sort_options[current_index]} ${normal}"
    }

    inquirer:on_sort_down() {
        if [ "${#sort_options[@]}" -eq 1 ]
        then
            return 0
        fi

        tput cub "$(tput cols)"

        inquirer:print "  ${sort_options[current_index]}"

        if [ $current_index = $((${#sort_options[@]}-1)) ]
        then
            current_index=0
            tput cuu $((${#sort_options[@]}-1))
        else
            current_index=$((current_index+1))
            tput cud1
        fi

        tput cub "$(tput cols)"

        inquirer:print "${cyan}${arrow} ${sort_options[current_index]} ${normal}"
    }

    inquirer:on_sort_move_up() {
        if [ "${#sort_options[@]}" -eq 1 ]
        then
            return 0
        fi

        local i

        tput cub "$(tput cols)"

        if [ $current_index = 0 ]
        then
            for((i=1;i<${#sort_options[@]};i++));
            do
                inquirer:print "  ${sort_options[i]}\n"
            done
            inquirer:print "${cyan}${arrow} ${sort_options[current_index]} ${normal}"
            current_index=$((${#sort_options[@]}-1))
            sort_options=( "${sort_options[@]:1}" "${sort_options[@]:0:1}" )
            sort_indices=( "${sort_indices[@]:1}" "${sort_indices[@]:0:1}" )
        else
            inquirer:print "  ${sort_options[current_index-1]}"
            tput cuu1
            tput cub "$(tput cols)"
            inquirer:print "${cyan}${arrow} ${sort_options[current_index]} ${normal}"
            local tmp="${sort_options[current_index]}"
            sort_options[current_index]="${sort_options[current_index-1]}"
            sort_options[current_index-1]="$tmp"
            tmp="${sort_indices[current_index]}"
            sort_indices[current_index]="${sort_indices[current_index-1]}"
            sort_indices[current_index-1]="$tmp"
            current_index=$((current_index-1))
        fi
    }

    inquirer:on_sort_move_down() {
        if [ "${#sort_options[@]}" -eq 1 ]
        then
            return 0
        fi

        local i

        tput cub "$(tput cols)"

        if [ $current_index = $((${#sort_options[@]}-1)) ]
        then
            tput cuu $((${#sort_options[@]}-1))
            inquirer:print "${cyan}${arrow} ${sort_options[current_index]} ${normal}\n"
            for((i=0;i<current_index;i++));
            do
                inquirer:print "  ${sort_options[i]}\n"
            done
            tput cuu ${#sort_options[@]}
            sort_options=( "${sort_options[@]:current_index}" "${sort_options[@]:0:current_index}" )
            sort_indices=( "${sort_indices[@]:current_index}" "${sort_indices[@]:0:current_index}" )
            current_index=0
        else
            inquirer:print "  ${sort_options[current_index+1]}"
            tput cud1
            tput cub "$(tput cols)"
            inquirer:print "${cyan}${arrow} ${sort_options[current_index]} ${normal}"
            local tmp="${sort_options[current_index]}"
            sort_options[current_index]="${sort_options[current_index+1]}"
            sort_options[current_index+1]="$tmp"
            tmp="${sort_indices[current_index]}"
            sort_indices[current_index]="${sort_indices[current_index+1]}"
            sort_indices[current_index+1]="$tmp"
            current_index=$((current_index+1))
        fi
    }

    inquirer:on_sort_ascii() {
        case "$1" in
            "w" ) inquirer:on_sort_move_up;;
            "s" ) inquirer:on_sort_move_down;;
        esac
    }

    inquirer:on_sort_enter_space()
    {
        local i

        tput cud $((${#sort_options[@]}-current_index))
        tput cub "$(tput cols)"

        for i in $(seq $((${#sort_options[@]}+1)))
        do
            tput el
            tput cuu1
        done

        tput cuf $((prompt_width+3))
        inquirer:print "${cyan}$(inquirer:join sort_options)${normal}\n"

        break_keypress=true
    }

    inquirer:_sort_input() {
        local i var=("$2"[@])
        sort_options=("${!var}")
        sort_indices=("${!sort_options[@]}")

        current_index=0

        trap inquirer:control_c SIGINT EXIT

        stty -echo
        tput civis

        inquirer:print "${green}?${normal} ${bold}${prompt}${normal} ${dim}`gettext \"(上下箭头选择, 按 <w> <s> 上下移动)\"`${normal}\n"

        for i in "${!sort_options[@]}"
        do
            if [ $i = 0 ]
            then
                inquirer:print "${cyan}${arrow} ${sort_options[i]} ${normal}\n"
            else
                inquirer:print "  ${sort_options[i]}\n"
            fi
        done

        tput cuu ${#sort_options[@]}

        inquirer:on_keypress inquirer:on_sort_up inquirer:on_sort_down inquirer:on_sort_enter_space inquirer:on_sort_enter_space inquirer:on_default inquirer:on_default inquirer:on_sort_ascii
    }

    inquirer:sort_input() {
        var_name=$3

        inquirer:_sort_input "$1" "$2"

        read -r -a ${var_name?} <<< "${sort_options[@]}"

        inquirer:cleanup
    }

    inquirer:sort_input_indices() {
        var_name=$3

        inquirer:_sort_input "$1" "$2"

        read -r -a ${var_name?} <<< "${sort_indices[@]}"

        inquirer:cleanup
    }

    inquirer:on_list_input_up() {
        inquirer:remove_instructions

        if [ "${#list_options[@]}" -eq 1 ]
        then
            return 0
        fi

        tput cub "$(tput cols)"

        inquirer:print "  ${list_options[current_index]}"

        if [ $current_index = 0 ]
        then
            current_index=$((${#list_options[@]}-1))
            tput cud $((${#list_options[@]}-1))
        else
            current_index=$((current_index-1))
            tput cuu1
        fi

        tput cub "$(tput cols)"

        inquirer:print "${cyan}${arrow} ${list_options[current_index]}${normal}"
    }

    inquirer:on_list_input_down() {
        inquirer:remove_instructions

        if [ "${#list_options[@]}" -eq 1 ]
        then
            return 0
        fi

        tput cub "$(tput cols)"

        inquirer:print "  ${list_options[current_index]}"

        if [ $current_index = $((${#list_options[@]}-1)) ]
        then
            current_index=0
            tput cuu $((${#list_options[@]}-1))
        else
            current_index=$((current_index+1))
            tput cud1
        fi

        tput cub "$(tput cols)"

        inquirer:print "${cyan}${arrow} ${list_options[current_index]} ${normal}"
    }

    inquirer:on_list_input_enter_space() {
        local i

        tput cud $((${#list_options[@]}-current_index))
        tput cub "$(tput cols)"

        for i in $(seq $((${#list_options[@]}+1)))
        do
            tput el
            tput cuu1
        done

        tput cuf $((prompt_width+3))
        inquirer:print "${cyan}${list_options[current_index]}${normal}\n"

        break_keypress=true
    }

    inquirer:on_list_input_ascii() {
        case "$1" in
            "w" ) inquirer:on_list_input_up;;
            "s" ) inquirer:on_list_input_down;;
        esac
    }

    inquirer:_list_input() {
        local i var=("$2"[@])
        list_options=("${!var}")
        current_index=0

        if [ "${#list_options[@]}" -eq 1 ] 
        then
            return 0
        fi

        first_keystroke=true

        trap inquirer:control_c SIGINT EXIT

        stty -echo
        tput civis

        inquirer:print "${green}?${normal} ${bold}${prompt}${normal} ${dim}`gettext \"(使用上下箭头选择)\"`${normal}\n"

        for i in "${!list_options[@]}"
        do
            if [ $i = 0 ]
            then
                inquirer:print "${cyan}${arrow} ${list_options[i]} ${normal}\n"
            else
                inquirer:print "  ${list_options[i]}\n"
            fi
        done

        tput cuu ${#list_options[@]}

        inquirer:on_keypress inquirer:on_list_input_up inquirer:on_list_input_down inquirer:on_list_input_enter_space inquirer:on_list_input_enter_space inquirer:on_default inquirer:on_default inquirer:on_list_input_ascii
    }

    inquirer:list_input() {
        var_name=$3

        inquirer:_list_input "$1" "$2"

        read -r ${var_name?} <<< "${list_options[current_index]}"

        inquirer:cleanup
    }

    inquirer:list_input_index() {
        var_name=$3

        inquirer:_list_input "$1" "$2"

        read -r ${var_name?} <<< "$current_index"

        inquirer:cleanup
    }

    inquirer:on_text_input_left() {
        if [[ $current_pos -gt 0 ]]
        then
            local current=${text_input:$current_pos:1} current_width
            current_width=$(inquirer:display_length "$current")

            tput cub $current_width
            current_pos=$((current_pos-1))
        fi
    }

    inquirer:on_text_input_right() {
        if [[ $((current_pos+1)) -eq ${#text_input} ]] 
        then
            tput cuf1
            current_pos=$((current_pos+1))
        elif [[ $current_pos -lt ${#text_input} ]]
        then
            local next=${text_input:$((current_pos+1)):1} next_width
            next_width=$(inquirer:display_length "$next")

            tput cuf $next_width
            current_pos=$((current_pos+1))
        fi
    }

    inquirer:on_text_input_enter() {
        text_input=${text_input:-$text_default_value}

        tput civis
        tput cub "$(tput cols)"
        tput el

        if $text_input_validator "$text_input"
        then
            tput sc
            tput cuu $((1+failed_count*3))
            tput cuf $((prompt_width+3))
            inquirer:print "${cyan}${text_input}${normal}"
            tput rc
            break_keypress=true
        else
            failed_count=$((failed_count+1))
            tput cud1
            inquirer:print "${red}${text_input_regex_failed_msg}${normal}"
            tput cud1
            if [ "$text_input" == "$text_default_value" ] 
            then
                text_input=""
                current_pos=0
            else
                inquirer:print "${text_input}"
                current_pos=${#text_input}
            fi
        fi

        tput cnorm
    }

    inquirer:on_text_input_ascii() {
        local c=${1:- }
        local rest=${text_input:$current_pos} rest_width
        local current=${text_input:$current_pos:1} current_width

        rest_width=$(inquirer:display_length "$rest")
        current_width=$(inquirer:display_length "$current")
        text_input="${text_input:0:$current_pos}$c$rest"
        current_pos=$((current_pos+1))

        tput civis

        [[ $current_width -gt 1 ]] && tput cub $((current_width-1))

        inquirer:print "$c$rest"

        if [[ $rest_width -gt 0 ]]
        then
            tput cub $((rest_width-current_width+1))
        fi

        tput cnorm
    }

    inquirer:on_text_input_not_ascii() {
        local c=$1
        local rest="${text_input:$current_pos}" rest_width
        local current=${text_input:$current_pos:1} current_width

        rest_width=$(inquirer:display_length "$rest")
        current_width=$(inquirer:display_length "$current")
        text_input="${text_input:0:$current_pos}$c$rest"
        current_pos=$((current_pos+1))

        tput civis

        [[ $current_width -gt 1 ]] && tput cub $((current_width-1))

        inquirer:print "$c$rest"

        if [[ $rest_width -gt 0 ]]
        then
            tput cub $((rest_width-current_width+1))
        fi

        tput cnorm
    }

    inquirer:on_text_input_backspace() {
        if [ $current_pos -gt 0 ] || { [ $current_pos -eq 0 ] && [ "${#text_input}" -gt 0 ]; }
        then
            local start rest rest_width del del_width next next_width offset
            local current=${text_input:$current_pos:1} current_width
            current_width=$(inquirer:display_length "$current")

            tput civis
            if [ $current_pos -eq 0 ] 
            then
                rest=${text_input:$((current_pos+1))}
                next=${text_input:$((current_pos+1)):1}
                rest_width=$(inquirer:display_length "$rest")
                next_width=$(inquirer:display_length "$next")
                offset=$((current_width-1))
                [[ $offset -gt 0 ]] && tput cub $offset
                inquirer:print "$rest"
                offset=$((rest_width-next_width+1))
                [[ $offset -gt 0 ]] && tput cub $offset
                text_input="$rest"
            else
                rest=${text_input:$current_pos}
                start=${text_input:0:$((current_pos-1))}
                del=${text_input:$((current_pos-1)):1}
                rest_width=$(inquirer:display_length "$rest")
                del_width=$(inquirer:display_length "$del")
                current_pos=$((current_pos-1))
                if [[ $current_width -gt 1 ]] 
                then
                    tput cub $((del_width+current_width-1))
                    inquirer:print "$rest"
                    tput cub $((rest_width-current_width+1))
                else
                    tput cub $del_width
                    inquirer:print "$rest"
                    [[ $rest_width -gt 0 ]] && tput cub $((rest_width-current_width+1))
                fi
                text_input="$start$rest"
            fi
            tput cnorm
        fi
    }

    inquirer:text_input_default_validator() {
        return 0
    }

    inquirer:text_input() {
        var_name=$2
        text_default_value=${3:-}
        text_input=""
        current_pos=0
        failed_count=0
        local text_default_tip

        if [ -n "$text_default_value" ] 
        then
            text_default_tip=" ${bold}${dim}($text_default_value)${normal}"
        else
            text_default_tip=""
        fi

        text_input_regex_failed_msg=${4:-$(gettext "输入验证错误")}
        text_input_validator=${5:-inquirer:text_input_default_validator}

        inquirer:print "${green}?${normal} ${prompt}${text_default_tip}\n"

        trap inquirer:control_c SIGINT EXIT

        stty -echo
        tput cnorm

        inquirer:on_keypress inquirer:on_default inquirer:on_default inquirer:on_text_input_ascii inquirer:on_text_input_enter inquirer:on_text_input_left inquirer:on_text_input_right inquirer:on_text_input_ascii inquirer:on_text_input_backspace inquirer:on_text_input_not_ascii
        read -r ${var_name?} <<< "$text_input"

        inquirer:cleanup
    }

    inquirer:date_pick_default_validator() {
        if ! date +%s -d "$1" > /dev/null 2>&1
        then
            return 1
        fi
        return 0
    }

    inquirer:remove_date_instructions() {
        if [ "$first_keystroke" = true ]
        then
            tput sc
            tput civis
            tput cuu 1
            tput cub "$(tput cols)"
            tput cuf $((prompt_width+3))
            tput el
            tput rc
            tput cnorm
            first_keystroke=false
        fi
    }

    inquirer:on_date_pick_ascii() {
        case "$1" in
            "w" ) inquirer:on_date_pick_up;;
            "s" ) inquirer:on_date_pick_down;;
            "a" ) inquirer:on_date_pick_left;;
            "d" ) inquirer:on_date_pick_right;;
        esac
    }

    inquirer:on_date_pick_up() {
        inquirer:remove_date_instructions
        case $current_pos in
            3)  date_pick="$((${date_pick:0:4}+1))${date_pick:4}"
            ;;
            6) 
                local month=$((10#${date_pick:5:2}+1))
                [ "$month" -eq 13 ] && month=1
                date_pick="${date_pick:0:5}$(printf %02d "$month")${date_pick:7}"
            ;;
            9) 
                local day=$((10#${date_pick:8:2}+1))
                [ "$day" -eq 32 ] && day=1
                date_pick="${date_pick:0:8}$(printf %02d "$day")${date_pick:10}"
            ;;
            12) 
                local hour=$(((10#${date_pick:11:2}+1)%24))
                date_pick="${date_pick:0:11}$(printf %02d "$hour")${date_pick:13}"
            ;;
            15) 
                local min=$(((10#${date_pick:14:2}+1)%60))
                date_pick="${date_pick:0:14}$(printf %02d "$min")${date_pick:16}"
            ;;
            18) 
                local sec=$(((10#${date_pick:17:2}+1)%60))
                date_pick="${date_pick:0:17}$(printf %02d "$sec")${date_pick:19}"
            ;;
        esac

        tput sc
        tput civis
        tput cub $current_pos
        inquirer:print "$date_pick"
        tput rc
        tput cnorm
    }

    inquirer:on_date_pick_down() {
        inquirer:remove_date_instructions
        case $current_pos in
            3)  
                local year=$((${date_pick:0:4}-1))
                [ "$year" -eq 2020 ] && return 0
                date_pick="$year${date_pick:4}"
            ;;
            6) 
                local month=$((10#${date_pick:5:2}-1))
                [ "$month" -eq 0 ] && month=12
                date_pick="${date_pick:0:5}$(printf %02d "$month")${date_pick:7}"
            ;;
            9) 
                local day=$((10#${date_pick:8:2}-1))
                [ "$day" -eq 0 ] && day=31
                date_pick="${date_pick:0:8}$(printf %02d "$day")${date_pick:10}"
            ;;
            12) 
                local hour=$(((10#${date_pick:11:2}+23)%24))
                date_pick="${date_pick:0:11}$(printf %02d "$hour")${date_pick:13}"
            ;;
            15) 
                local min=$(((10#${date_pick:14:2}+59)%60))
                date_pick="${date_pick:0:14}$(printf %02d "$min")${date_pick:16}"
            ;;
            18) 
                local sec=$(((10#${date_pick:17:2}+59)%60))
                date_pick="${date_pick:0:17}$(printf %02d "$sec")${date_pick:19}"
            ;;
        esac

        tput sc
        tput civis
        tput cub $current_pos
        inquirer:print "$date_pick"
        tput rc
        tput cnorm
    }

    inquirer:on_date_pick_left() {
        inquirer:remove_date_instructions
        if [[ $current_pos -gt 3 ]] 
        then
            tput cub 3
            current_pos=$((current_pos-3))
        fi
    }

    inquirer:on_date_pick_right() {
        inquirer:remove_date_instructions
        if [[ $current_pos -lt 18 ]] 
        then
            tput cuf 3
            current_pos=$((current_pos+3))
        fi
    }

    inquirer:on_date_pick_enter_space() {
        tput civis
        tput cub $current_pos
        tput el

        if $date_pick_validator "$date_pick"
        then
            tput sc
            tput cuu $((1+failed_count*3))
            tput cuf $((prompt_width+3))
            inquirer:print "${cyan}${date_pick}${normal}"
            tput rc
            break_keypress=true
        else
            failed_count=$((failed_count+1))
            tput cud1
            inquirer:print "${red}${date_pick_regex_failed_msg}${normal}\n"
            tput cud1
            inquirer:print "${date_pick}"
            tput cub $((19-current_pos))
        fi

        tput cnorm
    }

    inquirer:date_pick() {
        var_name=$2
        date_pick_regex_failed_msg=${3:-$(gettext "时间验证错误")}
        date_pick_validator=${4:-inquirer:date_pick_default_validator}
        date_pick=$(printf '%(%Y-%m-%d %H:%M:%S)T' -1)
        current_pos=12
        failed_count=0
        first_keystroke=true

        inquirer:print "${green}?${normal} ${bold}${prompt}${normal} ${dim}`gettext \"(使用箭头选择)\"`${normal}\n"
        inquirer:print "$date_pick"
        tput cub 7

        trap inquirer:control_c SIGINT EXIT

        stty -echo
        tput cnorm

        inquirer:on_keypress inquirer:on_date_pick_up inquirer:on_date_pick_down inquirer:on_date_pick_enter_space inquirer:on_date_pick_enter_space inquirer:on_date_pick_left inquirer:on_date_pick_right inquirer:on_date_pick_ascii
        read -r ${var_name?} <<< $(date +%s -d "$date_pick")

        inquirer:cleanup
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
        done <<< "${1:-}"

        echo "$display_length"
    }

    local option=$1 var_name \
    prompt=${2:-} \
    prompt_width \
    break_keypress \
    first_keystroke \
    current_index \
    checkbox_list \
    checkbox_list_count \
    checkbox_selected \
    checkbox_selected_indices \
    checkbox_selected_options \
    checkbox_input_failed_msg \
    sort_options \
    sort_indices \
    list_options \
    current_pos \
    failed_count \
    text_default_value \
    text_input \
    text_input_regex_failed_msg \
    text_input_validator \
    date_pick \
    date_pick_regex_failed_msg \
    date_pick_validator \
    arrow checked unchecked red green blue cyan bold normal dim

    prompt_width=$(inquirer:display_length "$prompt")

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

    shift
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
inquirer checkbox_input_indices "Choose targets" archs selected_indices

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