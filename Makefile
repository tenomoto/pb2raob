FC = /opt/local/bin/gfortran
#FFLAGS = -O2 -DDEBUG
FFLAGS = -O2
LDFLAGS = -L${HOME}/local/lib -lbufr
TARGET = pb2raob

all : $(TARGET)

$(TAREGET) : $(TARGET).o

clean :
	rm $(TARGET).out.*

distclean :
	rm $(TARGET) $(TARGET).out.*

doc : README.pdf

%.pdf : %.md
	pandoc $< -o $@
