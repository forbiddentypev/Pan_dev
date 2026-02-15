# Pan OS – Architecture Specification

> A high-performance 64-bit monolithic kernel for x86_64.

---

## Role & Constraints

**Architecture:** x86_64 only  
**Mode:** Long mode (64-bit)  
**Kernel Type:** Monolithic Modular  
**Language:** C++ (freestanding) + minimal C + Assembly  

- No microkernel architecture  
- No userspace drivers  
- No hybrid model  

**Primary objective:** Performance and deterministic control over hardware.  
**Security:** Secondary to speed in early stages.

---

## Kernel Philosophy

Pan OS is:

- **Monolithic** – Core in kernel space
- **Modular** – Subsystems as cohesive units
- **Cache-aware** – Optimized for locality
- **Minimal abstraction** – Low overhead
- **Low-overhead syscall model** – Fast user–kernel boundary

### Subsystems (all in kernel space)

- Scheduler  
- Memory Manager  
- VFS  
- Drivers  
- Network Stack  

**Rules:**

- No driver runs in user space  
- No IPC message passing between core subsystems  
- Direct function calls preferred  

---

## Global Architecture Rules

- All architecture-specific code: `kernel/arch/x86_64/`
- No dynamic allocation before heap ready  
- No exceptions in kernel  
- No RTTI in kernel  
- STL forbidden inside kernel  
- Every subsystem exposes minimal header interface  
- No abstraction layers unless needed for performance scaling  

**Optimize for:**

- Cache locality  
- Fewer context switches  
- Less memory fragmentation  

---

## Phase 0 – Toolchain Control (MANDATORY)

### Architecture

- Target: `x86_64-elf`

### Compiler flags

- `-ffreestanding`
- `-fno-exceptions`
- `-fno-rtti`
- `-mno-red-zone`
- `-mcmodel=kernel`
- `-O2` (later `-O3`)

### Boot method

- Use **GRUB** multiboot2
- No custom bootloader initially  
- Focus on kernel engineering, not boot complexity

### Deliverable

- Kernel boots via GRUB in 64-bit mode  

---

## Phase 1 – Minimal 64-Bit Entry

**Folder:** `kernel/arch/x86_64/`

### Tasks

1. Define linker script for higher-half kernel  
2. Setup stack  
3. Confirm long mode  
4. Map VGA memory  
5. Print text  

### Verification

- QEMU boot prints:  
  `PAN OS 64 BIT KERNEL INITIALIZED`  
- If fails → stop.

---

## Phase 2 – Memory Subsystem (Performance-Oriented)

**Folder:** `kernel/core/memory/`

### Strict order

1. Physical Memory Manager (bitmap or buddy allocator)  
2. Paging (4-level paging)  
3. Higher-half direct map  
4. Kernel heap (bump allocator first)  
5. Slab allocator (object caching for speed)  

### Performance rules

- Avoid fragmentation  
- Align allocations to cache lines (64 bytes)  
- Keep frequently used structs contiguous  

### Verification

- Allocate, free, stress test in loop  

---

## Phase 3 – Interrupt + Timer Core

**Folder:** `kernel/arch/x86_64/interrupts/`

### Tasks

- IDT setup  
- PIC remap  
- PIT timer  
- Enable interrupts  

### Verification

- Timer interrupt increments counter  
- No scheduler yet  

---

## Phase 4 – Scheduler (Low Latency)

**Folder:** `kernel/core/scheduler/`

### Design

- Preemptive round-robin first  
- Later: priority-based  

### Performance requirements

- Context switch in assembly  
- Save minimal registers  
- Avoid heap allocation in scheduler  

### Verification

- Two kernel threads alternate  

---

## Phase 5 – Syscall Fast Path

- Use **SYSCALL/SYSRET** (not `int 0x80`)  
- Minimal overhead syscall dispatch  

**Folder:** `system/syscall/`

### Verification

- User program prints via syscall  

---

## Phase 6 – Driver Core

- All drivers in kernel space  
- No message-based IPC  
- Direct calls only  

### Order

1. VGA  
2. Keyboard  
3. RAMDisk  
4. ATA (PIO first)  
5. PCI (later)  
6. USB (very late)  
7. Network (last)  

---

## Phase 7 – VFS (Direct Call Model)

**Folder:** `fs/vfs/`

### Design

- VFS dispatch via function pointers  
- No message passing  
- No user-mode FS servers  

### Order

1. VFS core  
2. tmpfs  
3. devfs  
4. FAT32  
5. EXT2  

---

## Phase 8 – ELF Loader + Userspace

**Folder:** `kernel/core/loader/`  
**Folders:** `apps/`, `lib/libc/`

### Tasks

- ELF parser  
- Map user program memory  
- Switch to ring 3  
- Syscall interface  

### Verification

- Shell launches app  

---

## Performance Directives

- Kernel compiled with `-O2` minimum  
- Avoid virtual functions in hot paths  
- Use `inline` where necessary  
- No heavy abstraction in drivers  
- Keep structs POD where possible  
- Reduce lock contention  
- Prefer spinlocks over mutex in kernel  

---

## Dependency Order (Development Law)

**Never move upward unless lower layer is stable.**

```
Memory → Interrupts → Scheduler → Syscalls → Drivers → VFS → Userspace
```

---

## Forbidden

- Microkernel architecture  
- Userspace drivers  
- Heavy OOP inside hot kernel paths  
- GUI before scheduler stable  
- Network before VFS stable  

---

## BUILD SYSTEM ARCHITECTURE – OFFICIAL POLICY

Pan OS uses CMake as the official build orchestrator.

CMake is used strictly as:

Target manager

Dependency resolver

Multi-directory coordinator

CMake must NOT:

Control architecture decisions

Override linker script behavior

Inject host system libraries

Enable hosted compilation mode

 Cross Compilation Rules

Pan OS must always be built using a cross compiler:

Target:
x86_64-elf

Host compiler usage is strictly forbidden.

All builds must be freestanding.

 Required Toolchain

x86_64-elf-gcc

x86_64-elf-g++

nasm

ld (cross)

cmake

qemu-system-x86_64

Bootloader:
GRUB (Multiboot2)

 Required Build Structure
pan-os/
├── CMakeLists.txt
├── toolchain-x86_64.cmake
├── linker.ld
├── kernel/
│   └── CMakeLists.txt
├── drivers/
│   └── CMakeLists.txt
├── fs/
│   └── CMakeLists.txt
├── lib/
│   └── CMakeLists.txt
├── system/
│   └── CMakeLists.txt
├── apps/
│   └── CMakeLists.txt
└── build/

 Mandatory Compiler Flags

Kernel flags:

-ffreestanding
-fno-exceptions
-fno-rtti
-mno-red-zone
-mcmodel=kernel
-O2

No standard library allowed.

No libc linking.

 Linker Control

The kernel must be linked using:

Custom linker script:
linker.ld

CMake must explicitly pass:

-T linker.ld
-nostdlib
-static

The linker script defines:

Higher-half mapping

Kernel entry point

Section alignment

Page alignment (4K minimum)

 Build Targets Required

CMake must provide:

kernel (ELF)

iso (bootable ISO)

run (QEMU launch)

clean

debug

The run target must automatically boot using:

QEMU

 ISO Generation Policy

ISO must contain:

/boot/kernel.elf
/boot/grub/grub.cfg

ISO generation must use:

GRUB with Multiboot2

 Stability Law

Every successful build must:

Produce ELF kernel

Produce ISO

Boot in QEMU

Print boot confirmation

If any of these fail → development must stop.

 Growth Policy

As the project scales:

Each subsystem must define its own CMakeLists.txt.

No monolithic CMake file allowed.

Subdirectories must expose only minimal public headers.



## Long-Term Target

Pan OS must:

- Boot in < 1 second (QEMU baseline)  
- Run multitasking  
- Execute native apps  
- Provide direct hardware performance API  
- Support game engine integration  
