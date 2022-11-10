#pragma once
#ifndef KPRINTF_H
#define KPRINTF_H

#ifdef DEBUG
void kprintf(const char* fmt, ...);
#else // DEBUG
#define kprintf(...) do { } while(0)
#endif // DEBUG

#endif
