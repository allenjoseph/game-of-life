#!/bin/bash
# Author: Allen Joseph
#
# Bash version 4 is required
#
# Documentation Commands: https://ss64.com/bash/
#
# Commands used:
# tput: Set terminal-dependent capabilities, color, position
# declare: Declare variables and give them attributes
# unset: Remove variable or function names
# printf: Format and print data
# awk: Find and Replace text
# IFS: internal field separator, It is used by the shell to determine how to do word splitting

declare -i GENERATION=-1

declare -i GRID_START_ROW=2
declare -i GRID_START_COL=0

declare -i GRID_HEIGHT=25
declare -i GRID_WIDTH=$(tput cols)

declare -A CELLS
declare -A NEIGHBORS

declare -A TEMP_CELLS

SEED_SELECTED="oscillator"
declare -a SEEDS

# Methods for the game processing
addCell() {
    # Parameters:
    # each cell contains "x|y|index" positions
    local x=$1
    local y=$2

    if [[ ! ${CELLS["$x|$y"]} ]]; then
        CELLS["$x|$y"]="$x|$y"
    fi
}
addSeed() {

    file="seeds/$SEED_SELECTED.txt"
    if [[ "$1" ]]; then
        file="$1"
    fi

    # Num of lines, cols in $file
    declare -i lines=$(awk 'END { print NR }' $file)
    declare -i cols=$(awk '{ if (length > L) {L=length} } END { print L }' $file)

    # center cells
    declare -i CENTERED_LEFT=$(( (GRID_WIDTH - cols) / 2 ))
    declare -i CENTERED_TOP=$(( (GRID_HEIGHT - lines) / 2 ))


    # initials cells
    # IFS: Internal Field Separator
    # read -r: do not allow backslashes to escape any characters
    while IFS= read -r line; do

        let CENTERED_TOP++

        for(( i=0; i<=${#line}; i++ )); do

            if [[ "${line:$i:1}" == "x" ]]; then
                addCell $(( CENTERED_LEFT+i )) $CENTERED_TOP
            fi
        done
    done < "$file"
}
evaluateNeighbors() {
    # Parameters:
    # each cell contains "x|y" positions
    declare -i x=$1
    declare -i y=$2

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

    # Value to know if it is evaluating a neighbor
    local comesFromNeighbor=$3

    local count=0
    for neighbor in $u $ru $r $rd $d $ld $l $lu; do

        # if cell exists increse counter
        if [[ ${CELLS["$neighbor"]} ]]; then
            let count++

        # else evaluate neighbor to create a new life
        elif [[ ! $comesFromNeighbor ]]; then
            if [[ ! ${NEIGHBORS["$neighbor"]} ]]; then
                NEIGHBORS["$neighbor"]="$neighbor"
            fi
        fi
    done

    # Rules:
    # cell with fewer than two live neighbors dies
    # cell with more than three live neighbors dies
    if [[ "$comesFromNeighbor" == "" && ($count -lt 2 ||  $count -gt 3) ]]; then
        TEMP_CELLS["$x|$y"]="$x|$y|0"
    fi

    # cell with exactly three live neighbors becomes a live
    if [[ "$comesFromNeighbor" == "comesFromNeighbor" && $count -eq 3 ]]; then
        TEMP_CELLS["$x|$y"]="$x|$y|1"
    fi

    # cell with two or three live neighbors lives
    # TO NOTHING
}
evaluateLife() {
    TEMP_CELLS=
    for cell in ${CELLS[*]}; do

        if [[ $cell ]]; then

            IFS='|' read -ra positionsCell <<< "$cell"
            local -i x=${positionsCell[0]}
            local -i y=${positionsCell[1]}

            evaluateNeighbors $x $y ""
        fi
    done

    NEIGHBORS=
    for neighbor in ${NEIGHBORS[*]}; do

        if [[ $neighbor ]]; then

            IFS='|' read -ra positionsNeighbor <<< "$neighbor"
            local -i x=${positionsNeighbor[0]}
            local -i y=${positionsNeighbor[1]}

            evaluateNeighbors $x $y "comesFromNeighbor"
        fi
    done
}

# Methods to print cells and info game
printLine() {
    printf "\n%*s\n" $GRID_WIDTH | tr ' ' - >> ${buffer}
}
printHeader() {
    printf "El Juego de la Vida" >> ${buffer}
    printLine
}
printFooter() {
    tput cup $((GRID_START_ROW + GRID_HEIGHT)) 0 >> ${buffer}
    printLine
    printf "Generación: $GENERATION Población: ${#CELLS[*]}" >> ${buffer}
    printf "\nPress 'n' to next generation" >> ${buffer}
    printf "\nPress 'p' to play a generation per second" >> ${buffer}
    printf "\nDefault grid size x:${GRID_WIDTH} y:${GRID_HEIGHT}" >> ${buffer}
    printLine
}
printBody() {

    for tempCell in ${TEMP_CELLS[*]}; do

        IFS='|' read -ra positionsTempCell <<< "$tempCell"
        declare -i tempCellX=${positionsTempCell[0]}
        declare -i tempCellY=${positionsTempCell[1]}
        declare -i tempCellLife=${positionsTempCell[2]}


        if [[ $tempCellLife -ge 0 ]]; then
            
            if [[ $tempCellLife -eq 1 ]]; then
                addCell $tempCellX $tempCellY
            else
                tput cup $tempCellX $tempCellY >> ${buffer}
                # print empty space
                printf " " >> ${buffer}
                unset CELLS["$tempCellX|$tempCellY"]
            fi
        fi
    done

    # add cells
    for cell in ${CELLS[*]}; do

        if [[ $cell ]]; then

            IFS='|' read -ra positionsCell <<< "$cell"
            cellX=${positionsCell[0]}
            cellY=${positionsCell[1]}

            # print cell
            tput cup $cellY $cellX >> ${buffer}
            printf "x" >> ${buffer}
        fi
    done

    # increase generation
    let GENERATION++
}
printGeneration() {
    printHeader
    printBody
    printFooter
}

# Methods to play the game
initGame() {
    # init buffer
    buffer="/tmp/buffer-${RANDOM}"
    printf "" > ${buffer}
    
    CELLS=
    addSeed $1

    clear >> ${buffer}
    printGeneration

    cat "${buffer}"
    printf "" > ${buffer}
}
iterateGame() {
    evaluateLife

    clear >> ${buffer}
    printGeneration
    cat "${buffer}"
    printf "" > ${buffer}
}

# Init game
initGame $1

while :
do
    # read -s: do not echo input coming from a terminal.
    # read -n: return after reading NCHARS characters rather than waiting
    #          for a newline
    read -s -n 1 key
    case "$key" in
        n) iterateGame;;
        p)
            while :
            do
                iterateGame
                sleep 0.1
            done
            ;;
    esac
done
