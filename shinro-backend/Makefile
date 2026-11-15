# Build de shinro-backend.
#
# Uso:
#   make            compila los dos binarios
#   make test       tests (con detector de carreras)
#   make vet        análisis estático
#   make fmt        formatea el código
#   make clean      borra los binarios
#
# GOAMD64 está fijado a v3 a propósito:
#
#   Go 1.27.4 usa GOAMD64=v4 por defecto, y v4 exige AVX-512. Los
#   binarios así compilados NO arrancan en CPUs anteriores a AVX-512
#   (por ejemplo, AMD Zen 3 o Intel anteriores a Sapphire Rapids), que
#   fallan con:
#
#       This program can only be run on AMD64 processors with v4
#       microarchitecture support.
#
#   v3 es el nivel de las CPUs actuales (Haswell en adelante, Zen 1 en
#   adelante) y da rendimiento de AVX2/BMI2 sin exigir AVX-512.
#
#   Para máxima compatibilidad (cualquier CPU de los últimos 15 años):
#
#       make GOAMD64=v2
#
#   Para binarios universales (sin instrucciones extra):
#
#       make GOAMD64=v1

GOAMD64 ?= v3
export GOAMD64

GO      ?= go
BINS     = shinro-backend shinro-shell
PKG      = ./...

.PHONY: all build test race vet fmt clean check

all: build

build: $(BINS)

# El Makefile es una dependencia: al cambiar el nivel de microarquitectura
# (o cualquier otra variable de este fichero) los binarios se reconstruyen.
# Para cambiar GOAMD64 desde la línea de órdenes, usar "make clean" primero.
shinro-backend: $(shell find . -name '*.go' -not -path './vendor/*') go.mod Makefile
	$(GO) build -o $@ ./cmd/shinro-backend

shinro-shell: $(shell find . -name '*.go' -not -path './vendor/*') go.mod Makefile
	$(GO) build -o $@ ./cmd/shinro-shell

test:
	$(GO) test $(PKG)

race:
	$(GO) test -race $(PKG)

vet:
	$(GO) vet $(PKG)

fmt:
	gofmt -w $(shell find . -name '*.go' -not -path './vendor/*')

# check: todo lo que debería pasar antes de tocar un commit.
check: vet race build
	@echo "todo correcto (GOAMD64=$(GOAMD64))"

clean:
	rm -f $(BINS)
