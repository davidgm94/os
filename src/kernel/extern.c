#include <stdint.h>

typedef struct RNG
{
    uint64_t s[4];
    // @Spinlock
} RNG;

void random_add_entropy(RNG* self, uint64_t x)
{
    // @Spinlock

	for (uintptr_t i = 0; i < 4; i++) {
		x += 0x9E3779B97F4A7C15;

		uint64_t result = x;
		result = (result ^ (result >> 30)) * 0xBF58476D1CE4E5B9;
		result = (result ^ (result >> 27)) * 0x94D049BB133111EB;
		self->s[i] ^= result ^ (result >> 31);
	}

    // @Spinlock
}
