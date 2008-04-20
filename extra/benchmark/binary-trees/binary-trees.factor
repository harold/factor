USING: kernel math accessors prettyprint io locals sequences
math.ranges ;
IN: benchmark.binary-trees

TUPLE: tree-node item left right ;

C: <tree-node> tree-node

: bottom-up-tree ( item depth -- tree )
    dup 0 > [
        1 -
        [ drop ]
        [ >r 2 * 1 - r> bottom-up-tree ]
        [ >r 2 *     r> bottom-up-tree ] 2tri
    ] [
        drop f f
    ] if <tree-node> ;

GENERIC: item-check ( node -- n )

M: tree-node item-check
    [ item>> ] [ left>> ] [ right>> ] tri [ item-check ] bi@ - + ;

M: f item-check drop 0 ;

: min-depth 4 ; inline

: stretch-tree ( max-depth -- )
    1 + 0 over bottom-up-tree item-check
    [ "stretch tree of depth " write pprint ]
    [ "\t check: " write ] bi* ;

:: long-lived-tree ( max-depth -- )
    0 max-depth bottom-up-tree

    min-depth max-depth 2 <range> [| depth |
        max-depth depth - min-depth + 2^ [
            [1,b] 0 [
                [ depth ] [ depth neg ] bi
                [ bottom-up-tree item-check + ] 2bi@
            ] reduce
        ]
        [ 2 * ] bi
        pprint "\t trees of depth " write depth pprint
        "\t check: " write .
    ] each

    "long lived tree of depth " write max-depth pprint
    "\t check: " write item-check . ;