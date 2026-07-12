# Documentazione FdC Railway Manager

Documentazione tecnica del repository, separata dal codice sorgente.

## Struttura

```
docs/
└── latex/
    ├── main.tex              # Documento principale
    ├── preamble.tex          # Pacchetti e stile
    ├── modules/              # Capitoli per modulo (estesi man mano)
    │   ├── 00-prefazione.tex
    │   ├── 01-architettura.tex
    │   ├── 02-fdcdomain.tex
    │   └── 03-fdcscheduling.tex
    └── Makefile
```

## Compilazione

Con **MacTeX** / `pdflatex`:

```bash
cd docs/latex
make
```

Output: `docs/latex/build/main.pdf`

Con **tectonic** (senza installazione completa TeX):

```bash
cd docs/latex
tectonic main.tex --outdir build
```

## Moduli documentati

| Capitolo | Modulo | Stato |
|----------|--------|-------|
| 1 | Architettura generale | ✅ v0.1 |
| 2 | `FDCDomain` — modelli | ✅ v0.1 |
| 3 | `FDCScheduling` — pipeline | ✅ v0.1 |
| 4 | Pathfinding | ✅ v0.1 |
| 5 | SPM integration | ✅ v0.1 |
| 6 | `Editor` | 🔲 pianificato |
| 7 | `Simulator` | 🔲 pianificato |
| 8 | `RailwayAIService` | 🔲 pianificato |
| 9 | `Infrastructure` / I/O | 🔲 pianificato |

Per aggiungere un modulo: creare `modules/NN-nome.tex`, includerlo in
`main.tex`, aggiornare questa tabella.

## Altri riferimenti

- [`../README.md`](../README.md) — panoramica repository
- [`../CLAUDE.md`](../CLAUDE.md) — regole di codice
- [`../FdC Railway Manager/RailwayAlgorithmDocs.md`](../FdC%20Railway%20Manager/RailwayAlgorithmDocs.md) — algoritmi (legacy)
