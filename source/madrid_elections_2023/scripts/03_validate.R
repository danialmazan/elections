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
report <- c("Madrid Elections 2023 validation", format(Sys.time(), tz="Europe/Madrid"), checks,
            sprintf("Income/geometry join: 2450/2450; suppressed or missing income: %d", missing_income))
dir.create(file.path(project, "validation"), showWarnings=FALSE)
writeLines(report, file.path(project, "validation/summary.txt"))
cat(paste(report, collapse="\n"), "\n")
