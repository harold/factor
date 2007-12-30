USING: help.markup help.syntax help words definitions classes ;
IN: classes.mixin

ARTICLE: "mixins" "Mixin classes"
"An object is an instance of a union class if it is an instance of one of its members. In this respect, mixin classes are identical to union classes. However, new classes can be made into instances of a mixin class after the original definition of the mixin."
{ $subsection POSTPONE: MIXIN: }
{ $subsection POSTPONE: INSTANCE: }
{ $subsection define-mixin-class }
{ $subsection add-mixin-instance }
"The set of mixin classes is a class:"
{ $subsection mixin-class }
{ $subsection mixin-class? } ;

HELP: mixin-class
{ $class-description "The class of mixin classes." } ;

HELP: define-mixin-class
{ $values { "class" word } }
{ $description "Defines a mixin class. This is the run time equivalent of " { $link POSTPONE: MIXIN: } "." }
{ $notes "This word must be called from inside " { $link with-compilation-unit } "." }
{ $side-effects "class" } ;

HELP: add-mixin-instance
{ $values { "class" class } { "mixin" class } }
{ $description "Defines a class to be an instance of a mixin class. This is the run time equivalent of " { $link POSTPONE: INSTANCE: } "." }
{ $notes "This word must be called from inside " { $link with-compilation-unit } "." }
{ $side-effects "class" } ;

{ mixin-class define-mixin-class add-mixin-instance POSTPONE: MIXIN: POSTPONE: INSTANCE: } related-words

ABOUT: "mixins"
