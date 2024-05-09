# Build Recipie Spec
This document defines the build recepie spec.


a recepie for the main app may look like this.
```
target: hello
inputs: src/main.c hi.o
cmd: gcc INPUTS -o TARGET
```
an input may be a path or the name of another target
the recipie for hi.o may look like this
```
target: hi.o
inputs: src/hi.c (src/hi.h src/common.h) multi.o
cmd: gcc INPUTS -c -o TARGET
```
anything between '(' ')' in not included in the INPUTS replacament
inputs can be multi line too
```
target: multi.o
inputs: {
src/multi.c,
src/multi2.c,
(src/multi.h,
src/multi2.h),
}
cmd: gcc INPUTS -c -o TARGET
```
files that are to be installed along side the binary should be surrounded with [].
a : may be placed to indicate a path replacement.
```
[src/multi.h:src:INST/usr/lib]
```
would mean the target depends on `src/multi.h` and 'src/multi.h' would be installed to /usr/lib/multi.h if INST was not set.

a special target called AUX is defined to represent files that are not depended on but must be installed anyway (like documentation or completion scripts)

another specal target in COMMON. it is incluluded as a dependency for all targets but is not included as an INPUT. if you wish to remove COMMON as a dependency you can add NOCOM to the inputs list.

All specal targets are optional. they must be created using there generic name
