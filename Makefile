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
	${CROSS_PREFIX}${CC} -o ${BIN_DIR}/nhu shellcode_${ARCH_SEL}sc.c nhu.c

%${ARCH_SEL}sc.c: %${ARCH_SEL}sc.s
	@mkdir -p ${OBJ_DIR} ${BIN_DIR}
	${CROSS_PREFIX}as -o ${OBJ_DIR}/$*.sc.o $<
	${CROSS_PREFIX}objcopy -O binary ${OBJ_DIR}/$*.sc.o ${BIN_DIR}/$*.sc.bin
	stat --printf="%s\n" ${BIN_DIR}/$*.sc.bin | sed -r 's/(.*)/#define INJECTED_CODE_SZ  \1\n/' > $(patsubst %.c,%.h,$@)
	@echo "unsigned char injected_code[INJECTED_CODE_SZ];" >> $(patsubst %.c,%.h,$@)
	@echo "#include \"$(patsubst %.c,%.h,$@)\"" >$@
	@echo "#include \"$(patsubst %.c,%.h,$@)\"" >shellcode.h
	hexdump -v -e '1/1 "0x%02x, "' ${BIN_DIR}/$*.sc.bin | sed -r 's/(.*), $$/unsigned char injected_code[INJECTED_CODE_SZ] = { \1 };\n/' >> $@

helpers: ${BIN_DIR}/counter ${BIN_DIR}/sig ${BIN_DIR}/sig2 ${BIN_DIR}/xx

${BIN_DIR}/counter: helpers/counter.c
	${CROSS_PREFIX}${CC} -o ${BIN_DIR}/counter helpers/counter.c

${BIN_DIR}/sig2: helpers/sig2.c
	${CROSS_PREFIX}${CC} -o ${BIN_DIR}/sig2 helpers/sig2.c -Wno-incompatible-pointer-types

${BIN_DIR}/sig: helpers/sig.c
	${CROSS_PREFIX}${CC} -o ${BIN_DIR}/sig helpers/sig.c

${BIN_DIR}/xx: helpers/xx.s
	${CROSS_PREFIX}as -o ${OBJ_DIR}/xx.o helpers/xx.s
	${CROSS_PREFIX}ld -o ${BIN_DIR}/xx ${OBJ_DIR}/xx.o

clean:
	rm -f ${OBJ_DIR}/*.o
	rm -f ${BIN_DIR}/*.bin
	rm -f ${BIN_DIR}/counter
	rm -f ${BIN_DIR}/nhu
	rm -f ${BIN_DIR}/sig
	rm -f ${BIN_DIR}/sig2
	rm -f ${BIN_DIR}/xx
	rm -f *-sc.h
	rm -f *-sc.c
	rm -f shellcode.h
