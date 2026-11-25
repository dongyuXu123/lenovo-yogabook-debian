obj-m += bq27xxx_battery.o
obj-m += bq27xxx_battery_i2c.o
obj-m += bq25890_charger.o
obj-m += ybkbdbl.o

KDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

ccflags-y += -I$(src)/include

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
