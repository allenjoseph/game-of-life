#!/bin/bash
# Author: Allen Joseph

# Documentation Commands: https://ss64.com/bash/
# Commands used:
# tput: Set terminal-dependent capabilities, color, position
# declare: Declare variables and give them attributes
# unset: Remove variable or function names

declare -i GENERATION=-1
declare -i CROWDING=0

declare -i GRID_START_ROW=2
declare -i GRID_START_COL=0

declare -i GRID_HEIGHT=25
declare -i GRID_WIDTH=100

declare -a CELLS
declare -i CELL_INDEX=0
declare -A CELLS_VERSION_2

declare -a TRASH
declare -i TRASH_INDEX=0

declare -a NEWS
declare -i NEWS_INDEX=0

declare -a NEIGHBUORS
declare -A NEIGHBUORS_VERSION_2
declare -i NEIGHBUORS_INDEX=0

printLine() {
    printf "%*s\n" $(tput cols) | tr ' ' -
}

addCell() {
    # Parameters:
    # each cell contains "x|y|index" positions
    x=$1
    y=$2

    # CELLS[$CELL_INDEX]="$x|$y|$CELL_INDEX"
    # let CELL_INDEX++

    CELLS_VERSION_2["$x|$y"]="X"
}

addCellsSeed() {
    # Num of lines, cols of seed
    declare -i lines=$(awk 'END { print NR }' seed.txt)
    declare -i cols=$(awk '{ if (length > L) {L=length} } END { print L }' seed.txt)

    # center seed
    declare -i CENTERED_LEFT=$(( (GRID_WIDTH - cols) / 2 ))
    declare -i CENTERED_TOP=$(( (GRID_HEIGHT - lines) / 2 ))

    # initials cells is in seed.txt
    # IFS: Internal Field Separator
    # read -r: do not allow backslashes to escape any characters
    while IFS= read -r line; do

        let CENTERED_TOP++

        for(( i=0; i<=${#line}; i++ )); do

            if [[ "${line:$i:1}" == "X" ]]; then
                addCell $(( CENTERED_LEFT+i )) $CENTERED_TOP
            fi
        done
    done < seed.txt
}

printGrid() {

    # add new cells
    for cell in ${NEWS[*]}; do
        IFS='|' read -ra positions <<< "$cell"
        x=${positions[0]}
        y=${positions[1]}

        findCell "$x|$y"
        if [ $? != 1 ]; then
            addCell $x $y
        fi
    done
    NEWS=
    let NEWS_INDEX=0

    # each cell contains "x|y" positions
    for cell in ${CELLS[*]}; do

        if [ ${#cell} -gt 0 ]; then

            IFS='|' read -ra positions <<< "$cell"
            x=${positions[0]}
            y=${positions[1]}

            tput cup $y $x
            printf "X"
        fi
    done

    # delete cells in trash
    for cell in ${TRASH[*]}; do

        IFS='|' read -ra positions <<< "$cell"
        x=${positions[0]}
        y=${positions[1]}
        index=${positions[2]}

        unset CELLS[$index]
        tput cup $y $x
        printf " "
    done
    TRASH=
    let TRASH_INDEX=0

    let GENERATION++
}

findCell() {
    case "${CELLS[*]}" in  *"$1"*) return 1 ;; esac
}

findNeighbuor() {
    case "${NEIGHBUORS[*]}" in  *"$1"*) return 1 ;; esac
}

evaluateNeighbuors() {
    # Parameters:
    # each cell contains "x|y" positions
    declare -i x=$1
    declare -i y=$2

    # u: up
    # d: down
    u="$x|$((y-1))"
    d="$x|$((y+1))"

    # l: left
    # lu: left up
    # ld: left down
    l="$((x-1))|$y"
    lu="$((x-1))|$((y-1))"
    ld="$((x-1))|$((y+1))"

    # r: right
    # ru: right up
    # rd: right down
    r="$((x+1))|$y"
    ru="$((x+1))|$((y-1))"
    rd="$((x+1))|$((y+1))"

    # index of cell
    declare -i index=$3

    count=0
    for neighbuor in $u $ru $r $rd $d $ld $l $lu; do

        if [[ ${CELLS_VERSION_2["$neighbuor"]} ]]; then

            if [[ $index -eq 1 ]]; then
                NEIGHBUORS[$count]="$neighbuor"
            fi

            let count++
        fi
    done

    # for neighbuor in $u $ru $r $rd $d $ld $l $lu; do
    #     findCell $neighbuor
    #     if [ $? == 1 ]; then
    #         let count++
    #     elif [ $index -ge 0 ]; then
    #         findNeighbuor $neighbuor
    #         if [ $? != 1 ]; then
    #             NEIGHBUORS[$NEIGHBUORS_INDEX]="$neighbuor"
    #             let NEIGHBUORS_INDEX++
    #         fi
    #     fi
    # done

    # Rules:
    # cell with two or three live neighbours lives
    # cell with fewer than two live neighbours dies
    # cell with more than three live neighbours dies
    # cell with exactly three live neighbours becomes a live

    # TODO: continuos here!!!
    if [[ $index == -1 ]]; then
        if [ $count -lt 2 ] || [ $count -gt 3 ]; then
            TRASH[$TRASH_INDEX]=${CELLS[$index]}
            let TRASH_INDEX++
        fi
    fi

    if [ $index == -1 ] && [ $count == 3 ]; then
        NEWS[$NEWS_INDEX]="$x|$y"
        let NEWS_INDEX++
    fi
}

evaluateLife() {

    NEIGHBUORS=
    let NEIGHBUORS_INDEX=0

    for cell in ${CELLS[*]}; do

        IFS='|' read -ra positions <<< "$cell"
        x=${positions[0]}
        y=${positions[1]}
        index=${positions[2]}

        evaluateNeighbuors $x $y $index
    done

    temp_neighbuors=(${NEIGHBUORS[*]})
    NEIGHBUORS=
    let NEIGHBUORS_INDEX=0

    for neighbuor in ${temp_neighbuors[*]}; do

        IFS='|' read -ra positions <<< "$neighbuor"
        x=${positions[0]}
        y=${positions[1]}
        index=-1

        evaluateNeighbuors $x $y $index
    done

    printGrid

    # FOOTER
    tput cup $((GRID_START_ROW + GRID_HEIGHT + 1)) 0
    printf "Generación: $GENERATION Población: ${#CELLS[*]}"
    tput cup $((GRID_START_ROW + GRID_HEIGHT + 3)) 0
}

# HEADER
clear
printf "El Juego de la Vida\n"; printLine

# BODY
# sprint 0
addCellsSeed
printGrid

# FOOTER
tput cup $((GRID_START_ROW + GRID_HEIGHT)) 0; printLine
printf "\nGeneración: $GENERATION Población: ${#CELLS[*]}"
tput cup $((GRID_START_ROW + GRID_HEIGHT + 1)) 0
printf "\nPress 'n' to next generation \n"

while :
do
    # read -s: do not echo input coming from a terminal.
    # read -n: return after reading NCHARS characters rather than waiting
    #          for a newline, but honor a delimiter if fewer than
    #          NCHARS characters are read before the delimiter.
    read -s -n 1 key
    case "$key" in
        n) 
            evaluateLife
            ;;
    esac
done
