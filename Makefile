NAME = init

SRC := init.c
OBJ := $(SRC:.c=.o)

CC = clang
CFLAGS = -Wall -Wextra -Werror -g3
LDFLAGS = -static

KERNEL_NAME = linux-6.6.76
KERNEL_DIR = kernel.$(KERNEL_NAME)
KERNEL_TAR = $(KERNEL_NAME).tar.xz
KERNEL_URL = https://cdn.kernel.org/pub/linux/kernel/v6.x/$(KERNEL_TAR)
KERNEL = $(KERNEL_DIR)/arch/x86/boot/bzImage

INITRAMFS = initramfs.cpio

all: $(NAME)

$(NAME): $(OBJ)
	nix-shell -p pkgs.glibc.static --command "$(CC) $(LDFLAGS) -o $@ $^"

initramfs: $(INITRAMFS)

$(INITRAMFS): $(NAME)
	echo $(NAME) | cpio -H newc -o > $@

kernel: $(KERNEL)

$(KERNEL_DIR):
	wget $(KERNEL_URL)
	tar xf $(KERNEL_TAR)
	rm -rf $(KERNEL_TAR)
	mv $(KERNEL_NAME) $(KERNEL_DIR)

$(KERNEL): $(KERNEL_DIR)
	make -C $(KERNEL_DIR) defconfig
	make -C $(KERNEL_DIR) -j$(shell nproc)

GRAPHICS ?= 1
run: $(KERNEL) $(INITRAMFS)
ifeq ($(GRAPHICS), 1)
	qemu-system-x86_64 -kernel $(KERNEL) -initrd $(INITRAMFS)
else
	qemu-system-x86_64 -nographic -kernel $(KERNEL) -initrd $(INITRAMFS) -append "console=ttyS0"
endif

clean:
	rm -f $(OBJ)

fclean: clean
	rm -f $(NAME) $(INITRAMFS)

re: fclean all
	
.PHONY: all clean fclean re
