NAME = init
TARGET = zig-out/bin/$(NAME)

# KERNEL_NAME = linux-6.6.76
# KERNEL_DIR = kernel.$(KERNEL_NAME)
# KERNEL_TAR = $(KERNEL_NAME).tar.xz
# KERNEL_URL = https://cdn.kernel.org/pub/linux/kernel/v6.x/$(KERNEL_TAR)
# KERNEL = $(KERNEL_DIR)/arch/x86/boot/bzImage

INITRAMFS = initramfs.cpio

all: $(NAME)

$(NAME): $(TARGET)

$(TARGET):
	zig build

initramfs: $(INITRAMFS)

$(INITRAMFS): $(NAME)
	echo $(NAME) | cpio -H newc -o > $@

# kernel: $(KERNEL)

# $(KERNEL_DIR):
# 	wget $(KERNEL_URL)
# 	tar xf $(KERNEL_TAR)
# 	rm -rf $(KERNEL_TAR)
# 	mv $(KERNEL_NAME) $(KERNEL_DIR)
#
# $(KERNEL): $(KERNEL_DIR)
# 	make -C $(KERNEL_DIR) defconfig
# 	make -C $(KERNEL_DIR) -j$(shell nproc)

# TTY ?= 1
# TERM_WRAPPER = gnome-terminal --
# run: $(KERNEL) $(INITRAMFS)
# ifeq ($(TTY), 0)
# 	qemu-system-x86_64 -kernel $(KERNEL) -initrd $(INITRAMFS)
# else
# 	$(TERM_WRAPPER) qemu-system-x86_64 -nographic -kernel $(KERNEL) -initrd $(INITRAMFS) -append "console=ttyS0"
# endif

clean:
	rm -rf .zig-cache

fclean: clean
	rm -f $(TARGET) $(INITRAMFS)

re: fclean all
	
.PHONY: all clean fclean re
