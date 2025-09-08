#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct ByteBuffer {
  const uint8_t *ptr;
  uintptr_t len;
  uintptr_t cap;
  const char *err;
} ByteBuffer;

typedef void (*CallbackFn)(const void*, struct ByteBuffer);

typedef struct Callback {
  const void *user_data;
  CallbackFn callback;
} Callback;

/**
 * # Safety
 * totally unsafe
 */
struct ByteBuffer rust_call(const uint8_t *data, uintptr_t len);

/**
 * # Safety
 * totally unsafe
 */
void rust_call_async(const uint8_t *data, uintptr_t len, struct Callback callback);

/**
 * # Safety
 * totally unsafe
 */
void rust_free(struct ByteBuffer byte_buffer);
