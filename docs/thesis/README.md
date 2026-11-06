# Praca inżynierska

Wzór: [lchmiel/SGGW-Thesis-LaTeX](https://github.com/lchmiel/SGGW-Thesis-LaTeX) (klasa `SGGW-thesis` 1.091, commit `7c04710`). Poradnik pisania pracy jest w `main.pdf` tego repozytorium (Dodatek A).

Budowanie:

```bash
cd docs/thesis
pdflatex main && bibtex main && pdflatex main && pdflatex main
```

Rozdziały są w `rozdzialy/`, obrazy w `obrazy/`, bibliografia w `bibliografia.bib`.
