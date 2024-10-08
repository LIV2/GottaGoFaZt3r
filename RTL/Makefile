PROJECT=GottaGoFaZt3r
PART=XC95144XL-10-TQ100
WORKDIR=tmp
SERIAL=$(shell git rev-parse --short=8 HEAD)
SERIAL=0
DEFINES=makedefines autoconfig SERIAL=32'h${SERIAL}
CABLE=usb21

CPLDFITFLAGS=-loc on -slew slow -init low -terminate keeper -unused ground -power std -optimize speed -keepio

.PHONY:	all clean fit

all:	../Binary/$(PROJECT).jed

$(PROJECT).prj: *.v
	-$(shell rm -f $@)
	-$(foreach source,$^,$(shell echo verilog work $(source) >> $@))

$(WORKDIR)/$(PROJECT).ngc:	*.v $(PROJECT).prj
	-@mkdir $(WORKDIR)
	@sed -r "s#^(-ofn).*#\1 ..\/$@#g;s#^(-ifn).*#\1 ../$(PROJECT).prj#g;s#^(-define).*#\1 {$(DEFINES)}#g" template.xst > $@.xst
	cd $(WORKDIR) && xst -ifn ../$@.xst -ofn $(PROJECT)-xst.log

$(WORKDIR)/%.ngd:	$(WORKDIR)/%.ngc $(PROJECT).ucf
	cd $(WORKDIR) && ngdbuild -p $(PART) -uc ../$(PROJECT).ucf ../$< ../$@

$(WORKDIR)/%.vm6:	$(WORKDIR)/%.ngd $(PROJECT).ucf
	cd $(WORKDIR) && cpldfit $(CPLDFITFLAGS) -p $(PART) ../$< | egrep -v "^CS: block|^$$"

%.jed:	$(WORKDIR)/%.vm6
	hprep6 -i $<

../Binary/%.jed:	%.jed
	cp $< ../Binary/

clean:
	-rm -rvf tmp
	-rm *.jed
	-rm *.prj

fit:	$(WORKDIR)/$(PROJECT).vm6

$(WORKDIR)/%.tim:	$(WORKDIR)/%.vm6
	cd $(WORKDIR) && taengine -l ../$@ -f $(PROJECT)

timing:	$(WORKDIR)/$(PROJECT).tim

flash:
	@echo "setMode -bs\n"\
	"setCable -p $(CABLE)\n"\
	"identify\n"\
	"assignfile -p 1 -file ../Binary/$(PROJECT).jed\n"\
	"erase -p 1\n"\
	"program -p 1\n"\
	"verify -p 1\n"\
	"exit\n" > tmp/batch
	LD_PRELOAD=/opt/Xilinx/usb-driver/libusb-driver.so impact -batch tmp/batch
