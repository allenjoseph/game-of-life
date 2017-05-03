#!/bin/bash
# Author: Allen Joseph

# Documentation Commands: https://ss64.com/bash/
# Commands used:
# tput: Set terminal-dependent capabilities, color, position
# declare: Declare variables and give them attributes
# unset: Remove variable or function names

declare -i GENERATION=-1

declare -i GRID_START_ROW=2
declare -i GRID_START_COL=0

declare -i GRID_HEIGHT=25
declare -i GRID_WIDTH=100

declare -A CELLS
declare -A NEIGHBORS

declare -a TRASH
declare -i TRASH_INDEX=0

declare -a NEWS
declare -i NEWS_INDEX=0

printLine() {
    printf "%*s\n" $(tput cols) | tr ' ' -
}

addCell() {
    # Parameters:
    # each cell contains "x|y|index" positions
    local x=$1
    local y=$2

    CELLS["$x|$y"]="$x|$y"
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
    for new in ${NEWS[*]}; do
        IFS='|' read -ra positionsNew <<< "$new"
        newX=${positionsNew[0]}
        newY=${positionsNew[1]}

        addCell $newX $newY
    done

    # each cell contains "x|y" positions
    for cell in ${CELLS[*]}; do

        if [[ $cell ]]; then

            IFS='|' read -ra positionsCell <<< "$cell"
            cellX=${positionsCell[0]}
            cellY=${positionsCell[1]}

            # print cell
            tput cup $cellY $cellX; printf "X"
        fi
    done

    # delete cells in trash
    for junk in ${TRASH[*]}; do

        IFS='|' read -ra positionsJunk <<< "$junk"
        junkX=${positionsJunk[0]}
        junkY=${positionsJunk[1]}

        # print empty space
        tput cup $junkY $junkX; printf " "

        # remove cell
        unset CELLS["$junk"]
    done

    # clean trash array
    unset TRASH
    let TRASH_INDEX=0

    # increase generation
    let GENERATION++
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
        TRASH[$TRASH_INDEX]="$x|$y"
        let TRASH_INDEX++
    fi

    # cell with exactly three live neighbors becomes a live
    if [[ "$comesFromNeighbor" == "comesFromNeighbor" && $count -eq 3 ]]; then
        NEWS[$NEWS_INDEX]="$x|$y"
        let NEWS_INDEX++
    fi

    # cell with two or three live neighbors lives
    # TO NOTHING
}

evaluateLife() {
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
