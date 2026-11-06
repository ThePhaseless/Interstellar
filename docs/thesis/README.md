# Praca inżynierska

Wzór: [lchmiel/SGGW-Thesis-LaTeX](https://github.com/lchmiel/SGGW-Thesis-LaTeX) (klasa `SGGW-thesis` 1.091, commit `7c04710`). Poradnik pisania pracy jest w `main.pdf` tego repozytorium (Dodatek A).

Budowanie:

TinyTeX razem z potrzebnymi pakietami LaTeX-a instaluje mise z `docs/.mise.toml`:

```bash
cd docs
mise trust && mise install
mise run thesis        # buduje thesis/main.pdf
```

Rozdziały są w `rozdzialy/`, obrazy w `obrazy/`, bibliografia w `bibliografia.bib`.
