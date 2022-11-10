#include <stdio.h>
#include <stdint.h>

#include <proto/exec.h>

#define NUMRUNS (10)
#define NUMITERATIONS (10000)

uint32_t runAsmCode(__reg("d0") uint32_t iterations);
uint32_t getCpuCycle() = 
	"\tmoveq.l\t#0,d0\n"
	"\trept 100\n"
	"\tsub.l\t$40400000,d0\t;read CPU clock\n"
	"\tadd.l\t$40400000,d0\n"
	"\tendr\n";

static uint32_t sample()
{
	return getCpuCycle();
}

int main()
{
	uint32_t result[NUMRUNS];

	// Calibrate the cost of reading the cycle counter
	Disable();
	for (int i = 0; i < NUMRUNS; ++i)
		result[i] = sample();
	Enable();
	for (int i = 0; i < NUMRUNS; ++i)
		printf("REPT 100 took %d cycles\n", (int)result[i]);

	// Measure the 5c/7instr loop
	Disable();
	for (int i = 0; i < NUMRUNS; ++i)
		result[i] = runAsmCode(NUMITERATIONS);
	Enable();
	for (int i = 0; i < NUMRUNS; ++i)
		printf("%d iterations took %d cycles\n", NUMITERATIONS, (int)result[i]);

	return 0;
}
