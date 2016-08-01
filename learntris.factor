! Copyright (C) 2016 Corey Taylor.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors arrays ascii columns combinators command-line
io kernel locals math math.parser namespaces prettyprint
sequences splitting strings system vectors ;
IN: learntris

<PRIVATE

SYMBOL: game
SYMBOL: score
SYMBOL: cleared
SYMBOL: active-tetr
SYMBOL: continue?
SYMBOL: position

TUPLE: matrix grid ;
C: <matrix> matrix

GENERIC: get-grid-at ( y x matrix -- elem )
M: matrix get-grid-at
    grid>> [ swap ] dip nth nth ;

GENERIC: print-grid ( matrix -- )
M: matrix print-grid
    grid>> [ [ " " write ] [ write ] interleave "\n" write ] each flush ;

TUPLE: game-grid < matrix ;
C: <game> game-grid

TUPLE: tetramino < matrix start orientation ;
C: <tetramino> tetramino

GENERIC: get-offset-left ( tetramino -- num )
GENERIC: get-offset-right ( tetramino -- num )
GENERIC: get-offset-bottom ( tetramino -- num )

TUPLE: shape-i < tetramino ;
: <shape-i> ( -- tetramino ) V{ V{ "." "." "." "." }
                                V{ "c" "c" "c" "c" }
                                V{ "." "." "." "." }
                                V{ "." "." "." "." } }
    { 0 3 } 0 shape-i boa ;
! 0 is no rotation. 1 is 90 degrees, 2 is 180, 3 is 270
M: shape-i get-offset-left
    orientation>>
    { { 0 [ 0 ] }
      { 1 [ 2 ] }
      { 2 [ 0 ] }
      { 3 [ 1 ] } } case ;
M: shape-i get-offset-right
    orientation>>
    { { 0 [ 0 ] }
      { 1 [ 1 ] }
      { 2 [ 0 ] }
      { 3 [ 2 ] } } case ;
M: shape-i get-offset-bottom
    orientation>>
    { { 0 [ 2 ] }
      { 1 [ 0 ] }
      { 2 [ 3 ] }
      { 3 [ 0 ] } } case ;

      
TUPLE: shape-o < tetramino ;
: <shape-o> ( -- tetramino ) V{ V{ "y" "y" }
                                V{ "y" "y" } }
    { 0 4 } 0 shape-o boa ;
M: shape-o get-offset-left drop 0 ;
M: shape-o get-offset-right drop 0 ;
M: shape-o get-offset-bottom drop 2 ;

TUPLE: shape-z < tetramino ;
: <shape-z> ( -- tetramino ) V{ V{ "r" "r" "." }
                                V{ "." "r" "r" }
                                V{ "." "." "." } }
    { 0 3 } 0 shape-z boa ;

TUPLE: shape-s < tetramino ;
: <shape-s> ( -- tetramino ) V{  V{ "." "g" "g" }
                                 V{ "g" "g" "." }
                                 V{ "." "." "." } }
    { 0 3 } 0 shape-s boa ;

TUPLE: shape-j < tetramino ;
: <shape-j> ( -- tetramino ) V{ V{ "b" "." "." }
                                V{ "b" "b" "b" }
                                V{ "." "." "." } }
    { 0 3 } 0 shape-j boa ;

TUPLE: shape-l < tetramino ;
: <shape-l> ( -- tetramino ) V{ V{ "." "." "o" }
                                V{ "o" "o" "o" }
                                V{ "." "." "." } }
    { 0 3 } 0 shape-l boa ;

TUPLE: shape-t < tetramino ;
: <shape-t> ( -- tetramino ) V{ V{ "." "m" "." }
                                V{ "m" "m" "m" }
                                V{ "." "." "." } }
    { 0 3 } 0 shape-t boa ;

UNION: bottom-empty-wide-tetr shape-l shape-j shape-z shape-s shape-t ;
M: bottom-empty-wide-tetr get-offset-left
    orientation>>
    { { 0 [ 0 ] }
      { 1 [ 1 ] }
      { 2 [ 0 ] }
      { 3 [ 0 ] } } case ;
M: bottom-empty-wide-tetr get-offset-right
    orientation>>
    { { 0 [ 0 ] }
      { 1 [ 0 ] }
      { 2 [ 0 ] }
      { 3 [ 1 ] } } case ;
M: bottom-empty-wide-tetr get-offset-bottom
    orientation>>
    0 = [ 2 ] [ 3 ] if ;

! we can rotate by first transposing, then reversing each row.
: rotate ( -- )
    active-tetr dup get dup grid>>
    dup first [ swap drop ] map-index ! create an array of numbers 0-n
    [ [ dup ] dip <column> >vector ] map >vector ! transpose
    [ drop ] dip ! get rid of original
    V{ } swap [ reverse suffix ] each
    >>grid set

    ! now we want to update the orientation
    active-tetr dup get dup orientation>>
    dup 3 < [ 1 + ] [ drop 0 ] if
    >>orientation set ;

: empty-row ( -- vector ) V{ } 10 [ "." suffix ] times ;

: init-grid ( -- ) V{ } 22 [ empty-row suffix ] times <game> game set ;

: init ( -- )
    init-grid
    0 score set
    0 cleared set
    t continue? set ;

: use-given-grid ( -- )
    game dup get
    V{ } 22 [ readln suffix ] times ! get the first 22 lines (a game)
    [ " " split >vector ] map
    >>grid set ;

: print-score ( -- ) score get number>string print ;

: increment-score ( -- ) score get 100 + score set ;

: increment-cleared ( -- ) cleared get 1 + cleared set ;

: print-cleared ( -- ) cleared get number>string print ;

: simulate-step ( -- )
    game dup get dup grid>> [
        dup 0 [ "." = [ 1 + ] [ 0 + ] if ] accumulate drop ! count empty
        0 = [ drop empty-row ] [ ] if ! if it's full, replace, count score
    ] map
    >>grid set ;

: move-left ( -- )
    position get second
    active-tetr get get-offset-left +
    0 > [
        position get second
        1 -
        1 position get remove-nth 1 swap insert-nth position set
    ] [ ] if ;

: move-right ( -- )
    position get second
    active-tetr get get-offset-right -
    active-tetr get grid>> first length +
    10 < [
        position get second
        1 +
        1 position get remove-nth 1 swap insert-nth position set
    ] [ ] if ;

: move-down ( -- )
    position get first
    active-tetr get get-offset-bottom +
    22 < [
        position get first
        1 +
        0 position get remove-nth 0 swap insert-nth position set
    ] [ ] if ;

: set-active ( tetramino -- )
    dup active-tetr set
    start>> position set ;

: print-active ( -- ) active-tetr get print-grid ;

: in-range? ( x a b -- t/f ) ! is x between a and b?
    rot dup -rot ! a x b x
    > -rot <= and ;

: intersect-with-active? ( y x -- t/f )
    position get second ! y x @x
    dup active-tetr get grid>> length + ! y x @x @dx
    in-range?
    swap ! t/f y
    position get first
    dup active-tetr get grid>> length +
    in-range? and ;

: get-active-at-game-coords ( y x -- char )
    [ position get first - ] dip
    position get second -
    active-tetr get get-grid-at ;

: tetr-at-empty? ( y x -- t/f )
    get-active-at-game-coords "." = ;

:: print-matrix-with-active ( -- )
    game get grid>>
    [ :> y
      [ :> x
        y x intersect-with-active?
        [
            y x tetr-at-empty?
            [ drop y x game get get-grid-at ]
            [ drop y x get-active-at-game-coords >upper ] if
        ]
        [ drop y x game get get-grid-at ] if
      ] map-index
    ] map-index <matrix>
    print-grid ;

: get-a-command ( input -- input char )
    dup first 1string dup ! commands char char
    [ dup ?second dup [ 1string ] [ ] if ] 2dip ! 2char 1char 1char
    "?" = ! 2char 1char
    [ swap append [ 1 tail ] dip ]
    [ [ drop ] dip ] if ;

: parse-commands ( commands input -- x )
    get-a-command
    swap [ suffix ] dip ! commands input
    dup length 1 > not [ drop ] [ 1 tail parse-commands ] if ;

: get-commands ( -- commands )
    V{ } readln parse-commands ;

: command ( str/f -- )
    { { f [ f continue? set ] }
      { "q" [ f continue? set ] }
      { "p" [ game get print-grid ] }
      { "P" [ print-matrix-with-active ] }
      { "g" [ use-given-grid ] }
      { "c" [ init-grid ] }
      { "?s" [ print-score ] }
      { "?n" [ print-cleared ] }
      { "s" [ simulate-step increment-score increment-cleared ] }
      { "I" [ <shape-i> set-active ] }
      { "O" [ <shape-o> set-active ] }
      { "Z" [ <shape-z> set-active ] }
      { "S" [ <shape-s> set-active ] }
      { "J" [ <shape-j> set-active ] }
      { "L" [ <shape-l> set-active ] }
      { "T" [ <shape-t> set-active ] }
      { "t" [ print-active ] }
      { ";" [ nl flush ] }
      { ")" [ rotate ] }
      { "(" [ rotate rotate rotate ] }
      { "<" [ move-left ] }
      { ">" [ move-right ] }
      { "v" [ move-down ] }
      [ drop ] } case ;

PRIVATE>

: learntris-main ( -- )
    init
    [ get-commands [ command ] each continue? get ] loop ;

MAIN: learntris-main
