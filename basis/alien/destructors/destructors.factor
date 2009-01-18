! Copyright (C) 2009 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: functors destructors accessors kernel parser words ;
IN: alien.destructors

FUNCTOR: define-destructor ( F -- )

F-destructor DEFINES ${F}-destructor
<F-destructor> DEFINES <${F}-destructor>
&F DEFINES &${F}
|F DEFINES |${F}

WHERE

TUPLE: F-destructor alien disposed ;

: <F-destructor> ( alien -- destructor ) f F-destructor boa ; inline

M: F-destructor dispose* alien>> F execute ;

: &F ( alien -- alien ) dup <F-destructor> execute &dispose drop ; inline

: |F ( alien -- alien ) dup <F-destructor> execute |dispose drop ; inline

;FUNCTOR

: DESTRUCTOR: scan-word define-destructor ; parsing