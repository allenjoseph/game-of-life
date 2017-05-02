#!/bin/bash
# Author: Allen Joseph

# Documentation Commands: https://ss64.com/bash/
# Commands used:
# tput: Set terminal-dependent capabilities, color, position
# declare: Declare variables and give them attributes
# unset: Remove variable or function names

GENERATION=-1
CROWDING=0

GRID_START_ROW=2
GRID_START_COL=0

GRID_HEIGHT=25
GRID_WIDTH=100

declare -a CELLS
CELL_INDEX=0

declare -a TRASH
TRASH_INDEX=0

declare -a NEWS
NEWS_INDEX=0

declare -a NEIGHBUORS
NEIGHBUORS_INDEX=0

printLine() {
    local col=0
     while [ $col -lt $GRID_WIDTH ]; do
        printf %s "-"
        let col=col+1
    done
}

addCell() {
    # Parameters:
    # each cell contains "x|y|index" positions
    local x=$1
    local y=$2

    CELLS[$CELL_INDEX]="$x|$y|$CELL_INDEX"
    let CELL_INDEX++
}

addCellsSeed() {
    # initials cells (seed.txt)
    #    @@
    #     @@
    #     @

    # Num of lines of seed
    local lines=$(awk 'END { print NR }' seed.txt)

    # Num characters of largest line
    local cols=$(awk '{ if (length > L) {L=length} } END { print L }' seed.txt)

    # center seed
    local CENTERED_LEFT=$(((GRID_WIDTH - cols)/2))
    local CENTERED_TOP=$(((GRID_HEIGHT - lines)/2))

    # initial positions
    local x=$CENTERED_LEFT
    local y=$CENTERED_TOP

    # IFS is to count empty spaces
    IFS=''
    while read line; do

        x=$CENTERED_LEFT; i=0

        while [ $i -lt ${#line} ]; do

            if [ ${line:$i:1} == "X" ]; then

                addCell $x $y
            fi

            # increase the counters
            let i++; let x++
        done

         let y++
    done < seed.txt
}

printGrid() {

    # add new cells
    for cell in ${NEWS[*]}; do
        IFS='|' read -ra positions <<< "$cell"
        local x=${positions[0]}
        local y=${positions[1]}

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
            local x=${positions[0]}
            local y=${positions[1]}

            tput cup $y $x
            printf "X"
        fi
    done

    # delete cells in trash
    for cell in ${TRASH[*]}; do

        IFS='|' read -ra positions <<< "$cell"
        local x=${positions[0]}
        local y=${positions[1]}
        local index=${positions[2]}

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
    local x=$1
    local y=$2

    # u: up
    # d: down
    local u="$x|$((y-1))"
    local d="$x|$((y+1))"

    # l: left
    # lu: left up
    # ld: left down
    local l="$((x-1))|$y"
    local lu="$((x-1))|$((y-1))"
    local ld="$((x-1))|$((y+1))"

    # r: right
    # ru: right up
    # rd: right down
    local r="$((x+1))|$y"
    local ru="$((x+1))|$((y-1))"
    local rd="$((x+1))|$((y+1))"

    # index of cell
    local index=$3

    local count=0
    for neighbuor in $u $ru $r $rd $d $ld $l $lu; do
        findCell $neighbuor
        if [ $? == 1 ]; then
            let count++
        elif [ $index -ge 0 ]; then
            findNeighbuor $neighbuor
            if [ $? != 1 ]; then
                NEIGHBUORS[$NEIGHBUORS_INDEX]="$neighbuor"
                let NEIGHBUORS_INDEX++
            fi
        fi
    done

    # Rules:
    # cell with two or three live neighbours lives
    # cell with fewer than two live neighbours dies
    # cell with more than three live neighbours dies
    # cell with exactly three live neighbours becomes a live
    if [ $index != -1 ]; then
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
        local x=${positions[0]}
        local y=${positions[1]}
        local index=${positions[2]}

        evaluateNeighbuors $x $y $index
    done

    local temp_neighbuors=(${NEIGHBUORS[*]})
    NEIGHBUORS=
    let NEIGHBUORS_INDEX=0

    for neighbuor in ${temp_neighbuors[*]}; do

        IFS='|' read -ra positions <<< "$neighbuor"
        local x=${positions[0]}
        local y=${positions[1]}
        local index=-1

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
    read -s -n 1 key
    case "$key" in
        n) 
            evaluateLife
            ;;
    esac
done
