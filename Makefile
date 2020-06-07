
LOG ?= irc.log
PNG := ~/div/irc.png
DOT := irc.dot

all: $(PNG)

.PHONY: $(LOG)

$(LOG):
	ls -tr ~/irc/20*/*/* | tail -10 | xargs grep -h nim: | tail -2000 > $(LOG)

ircgraph: ircgraph.nim Makefile
	nim c $<

$(PNG): $(DOT) Makefile
	dot -Tpng < $< > $@

irc.dot: $(LOG) ircgraph Makefile
	./ircgraph < $< > $@
