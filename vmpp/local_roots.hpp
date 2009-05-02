/* If a runtime function needs to call another function which potentially
allocates memory, it must store any local variable references to Factor
objects on the root stack */
extern F_SEGMENT *gc_locals_region;
extern CELL gc_locals;

DEFPUSHPOP(gc_local_,gc_locals)

template <typename T>
class gc_root : public tagged<T>
{
	void push() { gc_local_push((CELL)this); }
public:
	explicit gc_root(CELL value_) : tagged<T>(value_) { push(); }
	explicit gc_root(T *value_) : tagged<T>(value_) { push(); }
	gc_root(const gc_root<T>& copy) : tagged<T>(copy.untag()) {}
	~gc_root() { CELL old = gc_local_pop(); assert(old == (CELL)this); }
};

#define REGISTER_ROOT(obj) \
	{ \
		if(!immediate_p(obj))	 \
			check_data_pointer(obj); \
		gc_local_push((CELL)&(obj));	\
	}
#define UNREGISTER_ROOT(obj) \
	{ \
		if(gc_local_pop() != (CELL)&(obj))			\
			critical_error("Mismatched REGISTER_ROOT/UNREGISTER_ROOT",0); \
	}

/* Extra roots: stores pointers to objects in the heap. Requires extra work
(you have to unregister before accessing the object) but more flexible. */
extern F_SEGMENT *extra_roots_region;
extern CELL extra_roots;

DEFPUSHPOP(root_,extra_roots)

#define REGISTER_UNTAGGED(obj) root_push(obj ? RETAG(obj,OBJECT_TYPE) : 0)
#define UNREGISTER_UNTAGGED(type,obj) obj = (type *)UNTAG(root_pop())

/* We ignore strings which point outside the data heap, but we might be given
a char* which points inside the data heap, in which case it is a root, for
example if we call unbox_char_string() the result is placed in a byte array */
INLINE bool root_push_alien(const void *ptr)
{
	if(in_data_heap_p((CELL)ptr))
	{
		F_BYTE_ARRAY *objptr = ((F_BYTE_ARRAY *)ptr) - 1;
		if(objptr->header == tag_header(BYTE_ARRAY_TYPE))
		{
			root_push(tag_object(objptr));
			return true;
		}
	}

	return false;
}

#define REGISTER_C_STRING(obj) \
	bool obj##_root = root_push_alien((const char *)obj)
#define UNREGISTER_C_STRING(type,obj)			\
	if(obj##_root) obj = (type *)alien_offset(root_pop())

#define REGISTER_BIGNUM(obj) if(obj) root_push(tag_bignum(obj))
#define UNREGISTER_BIGNUM(obj) if(obj) obj = (untag_bignum_fast(root_pop()))