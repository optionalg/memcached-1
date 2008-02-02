%module rlibmemcached
%{
#include <libmemcached/memcached.h>
%}

%warnfilter(SWIGWARN_RUBY_WRONG_NAME) memcached_st;
%warnfilter(SWIGWARN_RUBY_WRONG_NAME) memcached_server_st;
%warnfilter(SWIGWARN_RUBY_WRONG_NAME) memcached_stat_st;
%warnfilter(SWIGWARN_RUBY_WRONG_NAME) memcached_string_st;
%warnfilter(SWIGWARN_RUBY_WRONG_NAME) memcached_result_st;

%include "typemaps.i"

// Input maps
%apply unsigned short { uint8_t };
%apply unsigned int { uint16_t };
%apply unsigned long { uint32_t flags, uint32_t offset };

%typemap(in) (void *data) {
  int value = FIX2INT($input);
  if (value == 0 || value == 1) {
    $1 = (void *) value;
  } else {
    // Only pass by reference for :distribution and :hash 
    value = value - 2; 
    $1 = &value;
  }
};

%typemap(in) (char *str, size_t len) {
 $1 = STR2CSTR($input);
 $2 = (size_t) RSTRING($input)->len;
};

%apply (char *str, size_t len) {
  (char *key, size_t key_length), 
  (char *value, size_t value_length)
};

// Output maps
%apply unsigned short *OUTPUT {memcached_return *error}
%apply unsigned int *OUTPUT {uint32_t *flags}
%apply size_t *OUTPUT {size_t *value_length}
%apply unsigned long long *OUTPUT {uint64_t *value}

%typemap(out) (char **) {
  int i;  
  VALUE ary = rb_ary_new();
  $result = rb_ary_new();
  
  for(i=0; $1[i] != NULL; i++) {
    rb_ary_store(ary, i, rb_str_new2($1[i]));
  }
  rb_ary_push($result, ary);
  free($1);
};

%include "/opt/local/include/libmemcached/memcached.h"

// Manual wrappers

// SWIG likes to use SWIG_FromCharPtr instead of SWIG_FromCharPtrAndSize because of the
// retval/argout split, so it truncates return values with \0 in them. Also, don't leak memory.
VALUE memcached_get_ruby_string(memcached_st *ptr, char *key, size_t key_length, uint32_t *flags, memcached_return *error);
%{
VALUE memcached_get_ruby_string(memcached_st *ptr, char *key, size_t key_length, uint32_t *flags, memcached_return *error) {
  char *str;
  VALUE ret;
  size_t *value_length;
  str = memcached_get(ptr, key, key_length, value_length, flags, error);
  ret = rb_str_new(str, *value_length);
  free(str);
  return ret;
};
%}

// We need to wrap this so it doesn't leak memory. SWIG doesn't want to automatically free.
VALUE memcached_stat_get_ruby_value(memcached_st *ptr, memcached_stat_st *stat, char *key, memcached_return *error);
%{
VALUE memcached_stat_get_ruby_value(memcached_st *ptr, memcached_stat_st *stat, char *key, memcached_return *error) {
  char *str;
  VALUE ret;
  str = memcached_stat_get_value(ptr, stat, key, error);
  ret = rb_str_new2(str);
  free(str);
  return ret;
};
%}

// Ruby isn't aware that the pointer is an array... there is probably a better way to do this
memcached_server_st *memcached_select_server_at(memcached_st *in_ptr, int index);
%{
memcached_server_st *memcached_select_server_at(memcached_st *in_ptr, int index) {
  return &(in_ptr->hosts[index]);
};
%}

// Same, but for stats
memcached_stat_st *memcached_select_stat_at(memcached_st *in_ptr, memcached_stat_st *stat_ptr, int index);
%{
memcached_stat_st *memcached_select_stat_at(memcached_st *in_ptr, memcached_stat_st *stat_ptr, int index) {
  return &(stat_ptr[index]);
};
%}
