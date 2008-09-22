! Copyright (C) 2005, 2008 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: alien.c-types arrays kernel kernel.private math
namespaces sequences stack-checker.known-words system layouts
combinators command-line io vocabs.loader accessors init
compiler compiler.units compiler.constants compiler.codegen
compiler.cfg.builder compiler.alien compiler.codegen.fixup
cpu.x86 compiler.backend compiler.backend.x86 ;
IN: compiler.backend.x86.32

! We implement the FFI for Linux, OS X and Windows all at once.
! OS X requires that the stack be 16-byte aligned, and we do
! this on all platforms, sacrificing some stack space for
! code simplicity.

M: x86.32 machine-registers
    {
        { int-regs { EAX ECX EDX EBP EBX } }
        { double-float-regs { XMM0 XMM1 XMM2 XMM3 XMM4 XMM5 XMM6 XMM7 } }
    } ;

M: x86.32 ds-reg ESI ;
M: x86.32 rs-reg EDI ;
M: x86.32 stack-reg ESP ;
M: x86.32 stack-save-reg EDX ;
M: x86.32 temp-reg-1 EAX ;
M: x86.32 temp-reg-2 ECX ;

M: x86.32 %alien-global 0 [] MOV rc-absolute-cell rel-dlsym ;

M: x86.32 %alien-invoke (CALL) rel-dlsym ;

M: x86.32 struct-small-enough? ( size -- ? )
    heap-size { 1 2 4 8 } member?
    os { linux netbsd solaris } member? not and ;

! On x86, parameters are never passed in registers.
M: int-regs return-reg drop EAX ;
M: int-regs param-regs drop { } ;
M: int-regs push-return-reg return-reg PUSH ;
: load/store-int-return ( n reg-class -- src dst )
    return-reg stack-reg rot [+] ;
M: int-regs load-return-reg load/store-int-return MOV ;
M: int-regs store-return-reg load/store-int-return swap MOV ;

M: float-regs param-regs drop { } ;

: FSTP ( operand size -- ) 4 = [ FSTPS ] [ FSTPL ] if ;

M: float-regs push-return-reg
    stack-reg swap reg-size [ SUB  stack-reg [] ] keep FSTP ;

: FLD ( operand size -- ) 4 = [ FLDS ] [ FLDL ] if ;

: load/store-float-return ( n reg-class -- op size )
    [ stack@ ] [ reg-size ] bi* ;
M: float-regs load-return-reg load/store-float-return FLD ;
M: float-regs store-return-reg load/store-float-return FSTP ;

: align-sub ( n -- )
    dup 16 align swap - ESP swap SUB ;

: align-add ( n -- )
    16 align ESP swap ADD ;

: with-aligned-stack ( n quot -- )
    swap dup align-sub slip align-add ; inline

M: x86.32 fixnum>slot@ 1 SHR ;

M: x86.32 prepare-division CDQ ;

M: x86.32 load-indirect
    0 [] MOV rc-absolute-cell rel-literal ;

M: object %load-param-reg 3drop ;

M: object %save-param-reg 3drop ;

: box@ ( n reg-class -- stack@ )
    #! Used for callbacks; we want to box the values given to
    #! us by the C function caller. Computes stack location of
    #! nth parameter; note that we must go back one more stack
    #! frame, since %box sets one up to call the one-arg boxer
    #! function. The size of this stack frame so far depends on
    #! the reg-class of the boxer's arg.
    reg-size neg + stack-frame* + 20 + ;

: (%box) ( n reg-class -- )
    #! If n is f, push the return register onto the stack; we
    #! are boxing a return value of a C function. If n is an
    #! integer, push [ESP+n] on the stack; we are boxing a
    #! parameter being passed to a callback from C.
    over [ [ box@ ] keep [ load-return-reg ] keep ] [ nip ] if
    push-return-reg ;

M: x86.32 %box ( n reg-class func -- )
    over reg-size [
        >r (%box) r> f %alien-invoke
    ] with-aligned-stack ;
    
: (%box-long-long) ( n -- )
    #! If n is f, push the return registers onto the stack; we
    #! are boxing a return value of a C function. If n is an
    #! integer, push [ESP+n]:[ESP+n+4] on the stack; we are
    #! boxing a parameter being passed to a callback from C.
    [
        int-regs box@
        EDX over stack@ MOV
        EAX swap cell - stack@ MOV 
    ] when*
    EDX PUSH
    EAX PUSH ;

M: x86.32 %box-long-long ( n func -- )
    8 [
        [ (%box-long-long) ] [ f %alien-invoke ] bi*
    ] with-aligned-stack ;

: struct-return@ ( size n -- n )
    [ stack-frame* cell + + ] [ \ stack-frame get swap - ] ?if ;

M: x86.32 %box-large-struct ( n c-type -- )
    ! Compute destination address
    heap-size
    [ swap struct-return@ ] keep
    ECX ESP roll [+] LEA
    8 [
        ! Push struct size
        PUSH
        ! Push destination address
        ECX PUSH
        ! Copy the struct from the C stack
        "box_value_struct" f %alien-invoke
    ] with-aligned-stack ;

M: x86.32 %prepare-box-struct ( size -- )
    ! Compute target address for value struct return
    EAX ESP rot f struct-return@ [+] LEA
    ! Store it as the first parameter
    ESP [] EAX MOV ;

M: x86.32 %box-small-struct ( c-type -- )
    #! Box a <= 8-byte struct returned in EAX:EDX. OS X only.
    12 [
        heap-size PUSH
        EDX PUSH
        EAX PUSH
        "box_small_struct" f %alien-invoke
    ] with-aligned-stack ;

M: x86.32 %prepare-unbox ( -- )
    #! Move top of data stack to EAX.
    EAX ESI [] MOV
    ESI 4 SUB ;

: (%unbox) ( func -- )
    4 [
        ! Push parameter
        EAX PUSH
        ! Call the unboxer
        f %alien-invoke
    ] with-aligned-stack ;

M: x86.32 %unbox ( n reg-class func -- )
    #! The value being unboxed must already be in EAX.
    #! If n is f, we're unboxing a return value about to be
    #! returned by the callback. Otherwise, we're unboxing
    #! a parameter to a C function about to be called.
    (%unbox)
    ! Store the return value on the C stack
    over [ store-return-reg ] [ 2drop ] if ;

M: x86.32 %unbox-long-long ( n func -- )
    (%unbox)
    ! Store the return value on the C stack
    [
        dup stack@ EAX MOV
        cell + stack@ EDX MOV
    ] when* ;

: %unbox-struct-1 ( -- )
    #! Alien must be in EAX.
    4 [
        EAX PUSH
        "alien_offset" f %alien-invoke
        ! Load first cell
        EAX EAX [] MOV
    ] with-aligned-stack ;

: %unbox-struct-2 ( -- )
    #! Alien must be in EAX.
    4 [
        EAX PUSH
        "alien_offset" f %alien-invoke
        ! Load second cell
        EDX EAX 4 [+] MOV
        ! Load first cell
        EAX EAX [] MOV
    ] with-aligned-stack ;

M: x86 %unbox-small-struct ( size -- )
    #! Alien must be in EAX.
    heap-size cell align cell /i {
        { 1 [ %unbox-struct-1 ] }
        { 2 [ %unbox-struct-2 ] }
    } case ;

M: x86.32 %unbox-large-struct ( n c-type -- )
    #! Alien must be in EAX.
    heap-size
    ! Compute destination address
    ECX ESP roll [+] LEA
    12 [
        ! Push struct size
        PUSH
        ! Push destination address
        ECX PUSH
        ! Push source address
        EAX PUSH
        ! Copy the struct to the stack
        "to_value_struct" f %alien-invoke
    ] with-aligned-stack ;

M: x86.32 %prepare-alien-indirect ( -- )
    "unbox_alien" f %alien-invoke
    cell temp@ EAX MOV ;

M: x86.32 %alien-indirect ( -- )
    cell temp@ CALL ;

M: x86.32 %alien-callback ( quot -- )
    4 [
        EAX load-indirect
        EAX PUSH
        "c_to_factor" f %alien-invoke
    ] with-aligned-stack ;

M: x86.32 %callback-value ( ctype -- )
    ! Align C stack
    ESP 12 SUB
    ! Save top of data stack
    %prepare-unbox
    EAX PUSH
    ! Restore data/call/retain stacks
    "unnest_stacks" f %alien-invoke
    ! Place top of data stack in EAX
    EAX POP
    ! Restore C stack
    ESP 12 ADD
    ! Unbox EAX
    unbox-return ;

M: x86.32 %cleanup ( alien-node -- )
    #! a) If we just called an stdcall function in Windows, it
    #! cleaned up the stack frame for us. But we don't want that
    #! so we 'undo' the cleanup since we do that in %epilogue.
    #! b) If we just called a function returning a struct, we
    #! have to fix ESP.
    {
        {
            [ dup abi>> "stdcall" = ]
            [ alien-stack-frame ESP swap SUB ]
        } {
            [ dup return>> large-struct? ]
            [ drop EAX PUSH ]
        }
        [ drop ]
    } cond ;

M: x86.32 %unwind ( n -- ) RET ;

os windows? [
    cell "longlong" c-type (>>align)
    cell "ulonglong" c-type (>>align)
    4 "double" c-type (>>align)
] unless

: (sse2?) ( -- ? ) "Intrinsic" throw ;

<<

\ (sse2?) [
    { EAX EBX ECX EDX } [ PUSH ] each
    EAX 1 MOV
    CPUID
    EDX 26 SHR
    EDX 1 AND
    { EAX EBX ECX EDX } [ POP ] each
    JE
] { } define-if-intrinsic

\ (sse2?) { } { object } define-primitive

>>

: sse2? ( -- ? ) (sse2?) ;

"-no-sse2" cli-args member? [
    "Checking if your CPU supports SSE2..." print flush
    [ optimized-recompile-hook ] recompile-hook [
        [ sse2? ] compile-call
    ] with-variable
    [
        " - yes" print
        "compiler.backend.x86.sse2" require
        [
            sse2? [
                "This image was built to use SSE2, which your CPU does not support." print
                "You will need to bootstrap Factor again." print
                flush
                1 exit
            ] unless
        ] "compiler.backend.x86" add-init-hook
    ] [
        " - no" print
    ] if
] unless