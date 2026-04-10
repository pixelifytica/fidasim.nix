.PHONY: default
default: ./fidasim ./hdf5 ./hdf5-dev

.PHONY: clean
clean:
	-rm fidasim hdf5*

./fidasim: ./hdf5 ./hdf5-dev
	nix build -o fidasim .#fidasim

./hdf5:
	nix build -o hdf5 .#hdf5.out

./hdf5-dev:
	nix build -o hdf5 .#hdf5.dev
