CC=gcc
OBJ_DIR=objects
BIN_DIR=bin
#CROSS_PREFIX=aarch64-linux-gnu-
CROSS_PREFIX?=$(shell $(CC) -dumpmachine)-
NATIVE_PREFIX:=$(shell $(CC) -dumpmachine)-
ARCH_SEL:=$(CROSS_PREFIX)
ifeq ($(CROSS_PREFIX),$(NATIVE_PREFIX))
	CROSS_PREFIX=
endif
$(info ARCH_SEL=$(ARCH_SEL))
$(info CROSS_PREFIX=$(CROSS_PREFIX))

nhu: shellcode_${ARCH_SEL}sc.c
	${CROSS_PREFIX}gcc -o nhu shellcode_${ARCH_SEL}sc.c nhu.c

%${ARCH_SEL}sc.c: %${ARCH_SEL}sc.s
	@mkdir -p ${OBJ_DIR} ${BIN_DIR}
	${CROSS_PREFIX}as -o ${OBJ_DIR}/$*.sc.o $<
	${CROSS_PREFIX}objcopy -O binary ${OBJ_DIR}/$*.sc.o ${BIN_DIR}/$*.sc.bin
	stat --printf="%s\n" ${BIN_DIR}/$*.sc.bin | sed -r 's/(.*)/#define INJECTED_CODE_SZ  \1\n/' > $(patsubst %.c,%.h,$@)
	@echo "unsigned char injected_code[INJECTED_CODE_SZ];" >> $(patsubst %.c,%.h,$@)
	@echo "#include \"$(patsubst %.c,%.h,$@)\"" >$@
	@echo "#include \"$(patsubst %.c,%.h,$@)\"" >shellcode.h
	hexdump -v -e '1/1 "0x%02x, "' ${BIN_DIR}/$*.sc.bin | sed -r 's/(.*), $$/unsigned char injected_code[INJECTED_CODE_SZ] = { \1 };\n/' >> $@

clean:
	rm -f ${OBJ_DIR}/*.o
	rm -f ${BIN_DIR}/*.bin
	rm -f *-sc.h
	rm -f *-sc.c
	rm -f shellcode.h
