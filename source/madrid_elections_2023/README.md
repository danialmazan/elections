# Madrid Elections 2023

Reproducible source for the bilingual article published as
`/elections/madrid_elections_2023.html`.

## Build

```sh
Rscript source/madrid_elections_2023/scripts/01_download.R
Rscript source/madrid_elections_2023/scripts/02_prepare.R
Rscript source/madrid_elections_2023/scripts/03_validate.R
Rscript source/madrid_elections_2023/scripts/04_render.R
```

The download step retrieves official mesa-level workbooks for the Madrid city
results, the definitive Ministry archives used to cross-check the local and
national elections, and the INE 2023 census-section income layer. Raw downloads
and intermediate files are ignored by Git. The public output is the article
HTML plus compact, deterministic assets under `assets/madrid-elections-2023/`.

The article uses votes for candidatures plus blank ballots as valid votes.
Turnout is votes cast (valid plus null) divided by the electoral census. The
5% rule controls which parties appear in the article; it is not a statement of
the legal threshold for representation.
