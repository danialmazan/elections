project <- normalizePath(file.path(getwd(), "source/madrid_elections_2023"), mustWork = TRUE)
x <- readRDS(file.path(project, "data/derived/prepared.rds"))

expected_turnout <- c(local=69.21, regional=69.42, national=73.39)
expected_winners <- list(local=c(PP=2148, MM=159, PSOE=143),
                         regional=c(PP=2204, MM=140, PSOE=106),
                         national=c(PP=1603, PSOE=795, SUMAR=52))
expected_parties <- list(local=c("PP","MM","PSOE","VOX"),
                         regional=c("PP","MM","PSOE","VOX","PODEMOS"),
                         national=c("PP","PSOE","SUMAR","VOX"))
checks <- character()
for (e in names(x$elections)) {
  a <- x$elections[[e]]
  article <- x$article[[e]]
  stopifnot(nrow(a)==2450, length(unique(a$cusec))==2450, nrow(article)==2450)
  stopifnot(all(a$valid == a$candidate_total + a$blank))
  stopifnot(all(a$cast == a$valid + a$null))
  turnout <- round(100*sum(a$cast)/sum(a$census), 2)
  stopifnot(identical(unname(turnout), unname(expected_turnout[[e]])))
  winners <- sort(table(article$winner), decreasing=TRUE)
  expected <- expected_winners[[e]]
  stopifnot(all(winners[names(expected)] == expected))
  observed <- x$summary$party[x$summary$election==e & x$summary$share >= 5]
  # Local Podemos is deliberately excluded just below 5%; every locked party is checked separately.
  stopifnot(identical(x$summary$party[x$summary$election==e], expected_parties[[e]]))
  checks <- c(checks, sprintf("%s: 2450 unique sections; vote identities balanced; turnout %.2f%%; winners %s", e, turnout,
                              paste(names(expected), expected, sep="=", collapse=", ")))
}
stopifnot(nrow(x$income)==2450, length(unique(x$income$cusec))==2450)
missing_income <- sum(is.na(x$income$income))
stopifnot(file.info(file.path(getwd(), "assets/madrid-elections-2023/sections.geojson"))$size > 0)
atlas_assets <- c(
  "sections-2023.pmtiles" = "1ebc8ad307c3f5c5b7fda26d178bc3f7e659d1142b075bd7fee49c9ab2ae81ed",
  "maplibre-gl.js" = "45a9b07a9189ce56054c620a947ccf41e291e58c95e9b61533b740aaa65ee5cb",
  "pmtiles.js" = "36bcbe1ba97cc07b3fc90cee9cba11729b04e25ec8790cf65a0787d5b38e091b"
)
for (asset in names(atlas_assets)) {
  path <- file.path(getwd(), "assets/madrid-elections-2023", asset)
  stopifnot(file.exists(path))
  observed <- unname(tools::md5sum(path))
  sha256 <- system2("shasum", c("-a", "256", path), stdout=TRUE)
  sha256 <- strsplit(sha256, " ", fixed=TRUE)[[1]][1]
  stopifnot(identical(sha256, unname(atlas_assets[[asset]])), nzchar(observed))
}
report <- c("Madrid Elections 2023 validation", format(Sys.time(), tz="Europe/Madrid"), checks,
            sprintf("Income/geometry join: 2450/2450; suppressed or missing income: %d", missing_income),
            "Madrid Atlas PMTiles and pinned map libraries: checksums verified")
dir.create(file.path(project, "validation"), showWarnings=FALSE)
writeLines(report, file.path(project, "validation/summary.txt"))
cat(paste(report, collapse="\n"), "\n")
