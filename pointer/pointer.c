#include "ruby.h"
#include "extconf.h"
#include <stdio.h>

struct WcPointer {
	struct RBasic basic;
	VALUE value;
	_Bool freed;
};

#define EXTRACT(obj) struct WcPointer *ptr; Data_Get_Struct(obj, struct WcPointer, ptr);

VALUE wc_cPointer;

static VALUE wc_pointer_free(VALUE obj) {
	EXTRACT(obj);

	ptr->freed = true;
	return Qnil;
}

static VALUE wc_pointer_deref(VALUE obj) {
	EXTRACT(obj);

	return ptr->value;
}

#define wc_pointer_initialize wc_pointer_assign
static VALUE wc_pointer_assign(VALUE obj, VALUE value) {
	EXTRACT(obj);

	ptr->value = value;
	ptr->freed = false;

	return value;
}

static VALUE wc_pointer_ref(VALUE obj) {
	return rb_funcall(wc_cPointer, rb_intern("new"), 1, obj);
}

static void wc_pointer_mark(void *raw) {
	struct WcPointer *ptr = (struct WcPointer *) raw;

	if (!ptr->freed)
		rb_gc_mark(ptr->value);
}

VALUE wc_pointer_alloc(VALUE klass) {
	struct WcPointer *pointer = malloc(sizeof(struct WcPointer));
	pointer->freed = true;
	return Data_Wrap_Struct(klass, wc_pointer_mark, free, pointer);
}

void Init_pointer() {
	wc_cPointer = rb_define_class("Pointer", rb_cObject);

   rb_define_alloc_func(wc_cPointer, wc_pointer_alloc);
	rb_define_method(wc_cPointer, "initialize", wc_pointer_initialize, 1);
	rb_define_method(wc_cPointer, "free", wc_pointer_free, 0);
	rb_define_method(wc_cPointer, "+@", wc_pointer_deref, 0);
	rb_define_method(wc_cPointer, "-@", wc_pointer_ref, 0);
	rb_define_method(wc_cPointer, "assign", wc_pointer_assign, 1);
}
